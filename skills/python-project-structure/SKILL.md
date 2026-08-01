---
name: python-project-structure
description: >
  Teaches the backend-engineer the four-layer Clean/Hexagonal Python project
  layout for a FastAPI service — inward-only dependencies enforced by an
  import-linter "Layers" fitness function (Python has no compiler-enforced
  internal/), typing.Protocol ports declared in the domain and implemented at
  the edge, the bootstrap composition root, and the src/ package layout. The
  Python analog of go-project-structure.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, project-structure, clean-architecture, solid, protocols, import-linter]
produces: python-service-skeleton
domain: backend
status: stable
related: [go-project-structure, python-service-skeleton, python-domain-model]
tools: [Bash]
---

# Python Project Structure

## Purpose

Every FastAPI service in this plugin uses the same layered layout so any service is navigable by anyone who has seen one. The layout enforces the Dependency Rule: **dependencies point inward only.** The domain layer at the centre knows nothing of HTTP, SQL, or Kafka — this is what makes the domain testable in isolation and the infrastructure swappable behind a `FakeRepository`.

This skill produces the `src/` package skeleton, the layering conventions, and the standard each generated module must meet. It does not implement the layers' contents — `python-domain-model`, `python-repository-pattern`, `python-service-layer`, and `python-fastapi-handler` do that, against the standard this skill sets. It is the direct Python analog of `go-project-structure`.

---

## The Four Layers and the Dependency Rule

| Layer (package) | May import | Must NOT import |
|---|---|---|
| `domain` | stdlib, `uuid`, `datetime`, `dataclasses`, `typing` only | Any other layer; FastAPI/Starlette; `asyncpg`; `aiokafka`; Pydantic |
| `service_layer` | `domain` | `entrypoints`; concrete `adapters` (only domain Protocol ports) |
| `adapters` | `domain` (to implement its ports) | `entrypoints`; `service_layer` |
| `entrypoints` | `service_layer`, `domain` (types) | `adapters` internals (wired in `bootstrap`) |

This is Robert C. Martin's **Dependency Rule** (Clean Architecture, Ch. 22): source dependencies point only inward, toward higher-level policy. It is the module-scale Dependency Inversion Principle the Cosmic Python book (Percival & Gregory) builds its whole architecture on — the domain and service layers depend only on *abstractions* (`typing.Protocol` ports), and concrete adapters (`asyncpg`, `aiokafka`, FastAPI) depend inward on those abstractions, never the reverse.

The four layers map onto Clean Architecture's four rings: `domain` = Entities, `service_layer` = Use Cases, `adapters` + `entrypoints` = Interface Adapters merged with Frameworks & Drivers (this plugin collapses those last two rings into one package per external system, per Martin's own note that the split is often collapsed in practice).

---

## Enforcement: import-linter Layers (the honest no-`internal/` gap)

**Go has `internal/`: the compiler makes a package unimportable from outside its module.** Python has no equivalent — a leading `_underscore` is convention only, unenforced, and any module can import any other module with zero compiler objection. So the Dependency Rule table above is **not** self-enforcing here the way it is in Go. It has to be enforced by a CI fitness function.

The tool is **import-linter** (`pip install import-linter`), configured with a **`layers` contract** in a `.importlinter` file. The contract lists the four packages top-to-bottom; import-linter fails the build if any lower (more central) package imports a higher (more peripheral) one. This is the Python analog of `go-project-structure`'s `make arch` check — the difference is that in Go the fitness function is defence-in-depth on top of a compiler guarantee, whereas in Python **it is the only line of defence**. If CI does not run it, the layering is unenforced.

Full `.importlinter` config, the `lint-imports` CI wiring, what the check does and does not catch, and a worked DataAsset package layout: `references/layout-and-import-linter.md`.

---

## Canonical `src/` Layout

```
classification-service/
├── src/classification/
│   ├── domain/           # dataasset.py, sensitivity.py, events.py, errors.py, ports.py
│   ├── service_layer/    # commands.py, queries.py, unit_of_work.py
│   ├── adapters/         # postgres.py, messaging.py, telemetry.py, secrets.py
│   ├── entrypoints/      # fastapi_app.py, event_consumer.py
│   └── bootstrap.py      # composition root: wires real adapters (or fakes in tests)
├── tests/                # unit/ (fakes), integration/ (testcontainers)
├── migrations/           # Alembic revisions (python-migration)
├── .importlinter         # the Layers contract (enforcement lives here)
├── pyproject.toml        # deps + tool config (uv, ruff, mypy)
└── Dockerfile
```

The `src/` layout (a real package under `src/`, not a flat top-level package) is the sanctioned Python packaging convention: it forces the code to be *installed* to be importable, so tests run against the installed package exactly as production does, and no accidental top-of-repo import shadows the real module. **Full per-package standard — what belongs in each module and what must never appear there: `references/layout-and-import-linter.md`.**

**Why this generic skeleton is not a Screaming Architecture violation.** The domain screams one level up in the service name (`classification-service`, chosen in `container-diagram`) and one level down in `domain/` file names (`dataasset.py`, not `entity.py`). The `src/<pkg>/{domain,service_layer,adapters,entrypoints}` tree is architecture's plumbing — boringly identical everywhere, precisely so the domain names are free to differ everywhere.

---

## typing.Protocol Ports (consumer-defined, structural)

A port is declared **where it is consumed** (in `domain`/`service_layer`), never beside its implementation. Python's tool for this is `typing.Protocol` — structural typing, the closest Python gets to Go's implicit interface satisfaction. The `asyncpg` adapter **does not inherit from** the port; it just matches its shape:

```python
# src/classification/domain/ports.py — defined by the CONSUMER
from typing import Protocol
from uuid import UUID

class DataAssetRepository(Protocol):
    async def get(self, tenant_id: UUID, asset_id: UUID) -> "DataAsset | None": ...
    async def add(self, tenant_id: UUID, asset: "DataAsset") -> None: ...
```

Prefer `Protocol` over `abc.ABC` for ports: it keeps the dependency arrow pointing inward (the adapter never imports the port) and avoids an inheritance coupling. Reserve `abc.ABC` for when you genuinely want a shared base with helper code.

**The honest gap vs. Go:** a `Protocol` is verified **only if `mypy`/`pyright` runs.** Nothing at runtime stops a wrong-shaped object being injected — unlike Go, where interface satisfaction is a compile error. This makes the static type-check step a **required, CI-enforced gate**, not optional. Ports, adapters, no-inheritance rule, and the DIP worked example: `references/protocols-and-bootstrap.md`.

---

## The Bootstrap Composition Root

`bootstrap.py` is the one place that constructs concrete adapters and injects them into the service layer — the Python analog of Go's `cmd/server/main.go`. It wires **real** adapters for production and **fakes** for tests through the same function, so a database-free unit test and the real service are assembled by identical code:

```python
def bootstrap(uow: UnitOfWork | None = None, ...) -> MessageBus:
    if uow is None:                       # None => production default
        uow = AsyncpgUnitOfWork(pool)     # real adapter
    ...                                   # tests pass FakeUnitOfWork here
```

The composition root only wires — it makes no business decision. Every branch in it is about *which dependency is present*, never about domain state. FastAPI's `lifespan` (see `python-service-skeleton`) calls `bootstrap()` once at startup and shares the result via `Depends()`. Full real-vs-fake wiring and the DIP walk-through: `references/protocols-and-bootstrap.md`.

---

## Package Naming

| Rule | Good | Bad |
|---|---|---|
| Short, lower-case, snake_case module names | `postgres.py`, `unit_of_work.py` | `postgresRepo.py`, `Utils.py` |
| Name the thing, not the pattern | `domain`, `commands` | `models`, `helpers`, `utils`, `common` |
| No stutter | `domain.DataAsset` | `dataasset.DataAssetModel` |

There is no `utils`/`common`/`helpers` module — a "utilities" grab-bag signals something lacks a home. Every package has an `__init__.py` with a one-line docstring naming the layer.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Domain purity | `domain` imports only stdlib/uuid/datetime/dataclasses/typing | Any framework/adapter/other-layer import | `lint-imports` green (`references/layout-and-import-linter.md`) |
| Service-layer boundary | `service_layer` imports `domain` only | Concrete adapter or `entrypoints` import | `lint-imports` |
| Adapter boundary | `adapters` never imports `entrypoints` | Upward import present | `lint-imports` |
| Ports are consumer-defined | `Protocol` port in `domain`/`service_layer` | Port declared beside its implementation in `adapters` | Grep `class .*\(Protocol\)` location against the layer table |
| Adapters do not inherit ports | Adapter matches port structurally, no subclassing | `class Repo(DataAssetRepository)` in `adapters` | Read adapter class bases |
| Static type gate present | `mypy`/`pyright` runs in CI and fails the build | Types unchecked; only Pydantic boundary validated | `pyproject.toml` has a mypy gate; CI runs it |
| Composition-root purity | `bootstrap.py` only wires; no business `if` | An `if` deciding something about the domain | Read `bootstrap.py`; every branch is about a dependency being present |
| No junk packages | No `utils`/`common`/`helpers`/`models` | A grab-bag module | `find src -name utils.py -o -name common.py -o -name helpers.py` — empty |
| `src/` layout used | Code under `src/<pkg>/`, installed to import | Flat top-level package | Directory tree has `src/` |

---

## Anti-Patterns

- **Layer-skipping imports** — an entrypoint reaching into `adapters.postgres` directly. Wiring happens only in `bootstrap.py`. import-linter catches this; nothing else will.
- **Producer-defined ports** — `postgres.py` declaring `DataAssetRepository` beside its implementation inverts ownership; the abstraction ends up shaped by the database, not the use case.
- **Adapter inheriting its port** — `class AsyncpgRepo(DataAssetRepository)` couples the edge to the centre and defeats structural typing. Match the shape; do not subclass.
- **Treating `mypy`/`pyright` as optional** — without it the `Protocol` ports guarantee is fiction; a wrong-shaped adapter is injected silently and fails only at runtime.
- **`utils`/`common`/`helpers` modules** — a landfill every module imports and no one owns.
- **Relying on `_underscore` for privacy** — it is convention, not enforcement. Do not architect as if it stops external access; it does not (see `python-domain-model`'s encapsulation caveat).
- **Business logic in `bootstrap.py`** — the moment it decides anything about the domain, that decision is untestable without booting the app.
- **A flat top-level package instead of `src/`** — invites import-shadowing and lets tests import an uninstalled copy that differs from what ships.

---

## Output Format

`src/` skeleton, `.importlinter`, and `pyproject.toml`, produced against the standard in `references/layout-and-import-linter.md`:

```
src/<pkg>/domain/ports.py
src/<pkg>/{domain,service_layer,adapters,entrypoints}/  (packages, each __init__.py docstring'd)
src/<pkg>/bootstrap.py
.importlinter
pyproject.toml
```

Full per-package standard and the import-linter contract: `references/layout-and-import-linter.md`. Protocol ports, no-inheritance adapters, and the bootstrap DIP example: `references/protocols-and-bootstrap.md`.
