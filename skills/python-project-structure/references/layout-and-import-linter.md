# The `src/` Layout and the import-linter Layers Fitness Function

Self-contained reference for `SKILL.md`'s "Enforcement" and "Canonical `src/` Layout" sections. It gives the full per-package standard, the exact `.importlinter` contract, the CI wiring, an honest statement of what the check does and does not catch, and a worked DataAsset package layout. This is the Python counterpart to `go-project-structure`'s `references/architecture-fitness-functions.md`.

**Read this first:** Go's `internal/` makes the Dependency Rule a compiler guarantee — a package outside the module physically cannot import the service's guts. Python has **no equivalent at all**. A leading `_underscore` is naming convention, unenforced; nothing in the interpreter stops `domain/dataasset.py` from writing `import asyncpg` or `from ..adapters.postgres import AsyncpgRepo`. So the four-layer table in `SKILL.md` is enforced **only** by the fitness function below. If CI does not run it, the architecture is documentation, not a constraint.

---

## The Full Per-Package Standard

```
src/classification/
├── __init__.py
├── domain/
│   ├── __init__.py        # """Domain layer: pure business model, no I/O."""
│   ├── dataasset.py       # the DataAsset Aggregate root + its Value Objects
│   ├── sensitivity.py     # a frozen-dataclass Value Object
│   ├── events.py          # domain events as frozen dataclasses (Allocated, ...)
│   ├── errors.py          # DomainError base + sentinels (AssetNotFound, ...)
│   └── ports.py           # typing.Protocol ports the outer layers must satisfy
├── service_layer/
│   ├── __init__.py
│   ├── commands.py        # one async function per write use case
│   ├── queries.py         # one async function per read use case
│   └── unit_of_work.py    # UnitOfWork Protocol + its async-context-manager contract
├── adapters/
│   ├── __init__.py
│   ├── postgres.py        # AsyncpgRepo: implements domain.ports structurally
│   ├── messaging.py       # aiokafka producer/consumer adapter
│   ├── telemetry.py       # OpenTelemetry setup
│   └── secrets.py         # secrets-manager adapter
├── entrypoints/
│   ├── __init__.py
│   ├── fastapi_app.py     # FastAPI routes; thin — decode → call service → encode
│   └── event_consumer.py  # aiokafka consumer loop
└── bootstrap.py           # composition root (see references/protocols-and-bootstrap.md)
```

| Package | Contains | Must never contain |
|---|---|---|
| `domain` | Aggregates, Value Objects (`@dataclass(frozen=True)`), domain events, `DomainError` family, `Protocol` ports | Any `import` of FastAPI, Starlette, Pydantic, `asyncpg`, `aiokafka`; any other layer |
| `service_layer` | Use-case functions, the `UnitOfWork` Protocol, idempotency/authorise ordering | Concrete adapters; `entrypoints`; SQL strings; HTTP concepts |
| `adapters` | Concrete `asyncpg`/`aiokafka`/OTel implementations of domain ports | `entrypoints`; `service_layer`; declaring a port (ports live in `domain`) |
| `entrypoints` | FastAPI app, routes, Pydantic request/response models, consumer loop | Reaching into `adapters` internals (only `bootstrap` wires those) |

**Why `src/`, not a flat package.** With the package under `src/`, it must be *installed* (`uv pip install -e .`, or `pip install -e .`) to be importable. Tests then import `classification` exactly as production does — there is no top-of-repo directory on `sys.path` that could shadow the real package with a half-built copy. A flat `classification/` at the repo root is importable by accident from the working directory and routinely causes "works in tests, breaks when packaged" drift. The `src/` layout closes that gap.

---

## The `.importlinter` Layers Contract

`.importlinter` at the repo root (INI-style, the tool's default config file):

```ini
[importlinter]
root_package = classification

[importlinter:contract:layered-architecture]
name = Clean Architecture layers point inward only
type = layers
layers =
    classification.entrypoints
    classification.service_layer
    classification.domain
containers =
    classification
```

The `layers` contract type means: **a layer listed lower may not be imported by... no** — read it precisely. In an import-linter `layers` contract, packages are listed **highest (most peripheral) first, lowest (most central) last**. A higher layer may import a lower one; a **lower layer importing a higher one is a violation.** So with `entrypoints` on top and `domain` at the bottom, `domain` importing `service_layer` or `entrypoints` fails, and `service_layer` importing `entrypoints` fails — exactly the inward-only rule.

`adapters` is deliberately **not** in the `layers` list. It sits at the same ring as `entrypoints` (both are Interface Adapters / Frameworks & Drivers) and must satisfy two rules the single `layers` list cannot express together: it *may* import `domain` (to implement its ports) but must *not* import `service_layer` or `entrypoints`. Encode that with a second, `forbidden` contract:

```ini
[importlinter:contract:adapters-stay-at-the-edge]
name = adapters may implement domain ports but never call inward-consumers
type = forbidden
source_modules =
    classification.adapters
forbidden_modules =
    classification.service_layer
    classification.entrypoints
```

Sibling isolation within a ring (e.g. `adapters.postgres` importing `adapters.messaging` for no reason) is **not** covered by either contract above and is not a Dependency Rule violation — it is an ordinary code-review concern. If a specific isolation is worth enforcing, import-linter offers a separate `independence` contract type for that; this plugin does not add one by default.

---

## CI Wiring

Install and run in CI (and locally before a PR):

```bash
uv pip install import-linter      # or: pip install import-linter
lint-imports                      # reads .importlinter, exits non-zero on any violation
```

Wire it into `pyproject.toml`'s task set alongside `ruff` and `mypy` (see `python-tooling`) so `lint-imports` is one step of the same CI gate that runs the static type check. In GitHub Actions it is one line:

```yaml
      - run: lint-imports
```

`lint-imports` exits `0` when every contract holds and prints each broken contract with the offending import chain when one does not — including the transitive chain, so a violation hiding two hops behind an intermediate module is still reported with the full path that reached the forbidden target.

### `pyproject.toml` wiring

import-linter reads `.importlinter` by default, but its dependency belongs in the project's dev group alongside `ruff` and `mypy` so all three ship as one CI gate (`python-tooling` owns the full task set):

```toml
[project]
name = "classification"
requires-python = ">=3.11"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/classification"]      # the src/ layout, made explicit to the builder

[dependency-groups]
dev = [
    "import-linter>=2.0",
    "mypy>=1.10",
    "ruff>=0.5",
    "pytest>=8",
    "pytest-asyncio>=0.23",
]

[tool.mypy]
strict = true                          # the Protocol ports guarantee is only real under this
packages = ["classification"]
```

The `[tool.mypy] strict = true` line is not decoration: it is what turns the `typing.Protocol` ports in `references/protocols-and-bootstrap.md` from documentation into a checked contract. `lint-imports` guards the *import direction*; `mypy --strict` guards the *port shapes*. Neither substitutes for the other, and both must run in CI — a service that runs `lint-imports` but not `mypy` has enforced layering with unverified port satisfaction, and vice versa.

A local pre-PR sweep runs the same three tools the CI gate runs:

```bash
uv run ruff check . && uv run mypy && uv run lint-imports
```

---

## What It Catches

- **Transitive violations, not just direct ones.** import-linter walks the import graph, so `domain` importing an in-house helper that itself imports `asyncpg` is caught two hops in.
- **Every broken contract in one run**, each with the concrete import chain that violated it — not just the first failure.
- **Both directions of the rule at once** via the two contracts: the inward-only `layers` ordering and the `adapters`-must-not-call-inward `forbidden` rule.

## What It Does NOT Catch — Honest Limitations

- **It is static-import-graph analysis only.** import-linter parses `import` and `from ... import` statements; it never runs the code. A **dynamic import** performed at runtime — `importlib.import_module("classification.adapters.postgres")` from inside a domain module, or a `__import__(...)` call built from a string — is invisible to it and slips past every contract. This is the single most important blind spot: the enforcement is only as strong as the code using static, analysable imports. A dynamic import that reaches across a layer boundary is an architecture violation the fitness function cannot see, and must be caught in review instead.
- **It checks import direction, not interface ownership.** A producer-defined `Protocol` sitting in `adapters` instead of `domain` imports nothing forbidden and passes silently. "Ports are defined by the consumer" (`SKILL.md`) is a structural-review criterion, not something these contracts verify.
- **It sees packages, not behaviour.** `domain` reaching for `os`, `socket`, or opening a file — all stdlib, none forbidden by name — passes cleanly while still violating the spirit of a pure domain layer. Closing this would mean an allow-list of the exact permitted stdlib subset; far more maintenance, not done by default.
- **It depends on importable code.** import-linter must import `root_package` to build the graph; if the package does not import (a syntax error, a missing dependency), the check cannot run. Architecture enforcement is downstream of an importable build, never a substitute for one.
- **The `forbidden` list is hand-maintained and rots.** Adding a new inner package without adding it to the relevant `forbidden_modules`/`layers` entry lets a new cross-layer import slip in undetected — the same deny-list maintenance liability the Go fitness function carries.

---

## Worked DataAsset Layout

For the DataAsset Bounded Context in the `classification-service`:

- `domain/dataasset.py` — the `DataAsset` Aggregate root, owning its `Sensitivity` Value Object and a `version` integer for optimistic concurrency; the only object permitted to mutate its own invariant. Its `reclassify(...)` method appends a `Reclassified` event to `self.events`.
- `domain/ports.py` — `DataAssetRepository(Protocol)` with `get`/`add`, every method taking `tenant_id: UUID` first (this product's per-tenant **physical** isolation means `tenant_id` is threaded through every persistence call — the port makes that non-optional by putting it in the signature).
- `service_layer/commands.py` — `async def reclassify_asset(cmd, uow)`: opens the UoW, loads the Aggregate via the repository, calls `asset.reclassify(...)`, `await uow.commit()`. No SQL, no HTTP.
- `adapters/postgres.py` — `AsyncpgRepo` implementing `DataAssetRepository` structurally (no subclassing), issuing `$1`-positional parameterised SQL with `tenant_id` in every `WHERE`, CAS on `version`, and the outbox insert in the same `conn.transaction()`.
- `entrypoints/fastapi_app.py` — a `POST /assets/{id}/reclassify` route with a Pydantic request model; decodes, calls `reclassify_asset`, encodes the result. A single `@app.exception_handler(DomainError)` maps the domain exception family to HTTP status codes.

Running `lint-imports` against this tree passes only while `domain/` imports nothing but stdlib/`uuid`/`dataclasses`/`typing`, `service_layer/` imports only `domain`, and `adapters/`/`entrypoints/` never point inward at each other's consumers. The moment `dataasset.py` gains an `import asyncpg`, the `layered-architecture` contract fails the build with the offending chain printed.
