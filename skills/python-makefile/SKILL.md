---
name: python-makefile
description: >
  Teaches the backend-engineer to write the developer task runner for a
  Python service — a Makefile (or Taskfile) with standard targets (install
  via uv, lint via ruff, typecheck via mypy, test via pytest, format, build
  the image, run migrations, local-up), the check-freshness pattern for
  generated artifacts, and the single-entrypoint-for-common-tasks
  discipline. The Python analog of go-makefile.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, makefile, taskfile, task-runner, uv, ruff, mypy, pytest, alembic, ci, ci-parity, freshness, kind, local-up]
related: [go-makefile, python-project-structure, python-unit-test, python-dockerfile]
tools: [Bash]
---

# Python Makefile

## Purpose

The Makefile is the single, memorable interface to every routine task on a Python service — the
exact commands a developer runs on a laptop are the exact commands CI runs, nothing translated,
nothing re-implemented in YAML. It encodes the blueprint's verification gates (lint, type check,
test, coverage, freshness) as first-class targets so "it passes on my machine" and "it passes in
CI" are the same claim. `make ci` is the one command that gates a merge; if it is green, the
change satisfies every standard this plugin holds for this service's backend code.

This skill produces the `Makefile` and the toolchain config it drives (`pyproject.toml` sections
for `uv`, `ruff`, `mypy`, `pytest`). The container image the `build` target produces is
`python-dockerfile`'s domain; the migration files `migrate` applies are `python-migration`'s; the
directory layout `test`/`typecheck` walk is `python-project-structure`'s.

**The one honest divergence from `go-makefile` that shapes everything below:** Go's compiler *is*
the type checker and its toolchain (`go vet`, `-race`, `go test -cover`) ships in one binary.
Python has **no compiler in the default loop and no race detector** — its type hints are
runtime-erased annotations that check *nothing* unless `mypy` is run as a build-breaking gate, and
the GIL means single-threaded pure-Python code has no shared-memory data race to detect. So the
Python `ci` target *adds* a `typecheck` gate Go gets for free, and *drops* the `-race` gate Go
must always run. See "The Standard Target Set" and `references/toolchain-and-ci.md`.

---

## The CI-Parity Principle

Every target must be invocable identically on a developer's machine and inside CI — no target that
only works because a CI-only secret, environment variable, or network path is present. `test`
writes coverage to the same relative path in both places; `lint` reads the same `pyproject.toml`
config in both. The moment a target diverges — a "fast" local variant, a CI-only extra flag —
"passes locally" and "passes in CI" stop being the same claim, and the gap is exactly where
"worked on my machine" bugs live. CI must call `make ci`, never re-list raw `ruff`/`mypy`/`pytest`
commands in YAML — a pipeline that re-implements the targets drifts from them. If a check genuinely
needs CI-only infrastructure (a live staging cluster, a paid scanner), it belongs in a separate,
explicitly-named pipeline stage, not in this Makefile.

---

## One Command Per Common Task

Every routine a developer performs more than once gets exactly one target — `make test`, not a
half-remembered `uv run pytest -xvs tests/ --cov=app --cov-report=term-missing`. The target is the
memory: the flags, paths, and config live inside it, discoverable by `make help`, changed in one
place. A developer who never has to reconstruct a command never reconstructs it *wrong*, and a new
teammate learns the service's whole operational surface from the target list alone. This is the
same discipline `go-makefile` names; the tasks differ, the principle is identical.

---

## The Standard Target Set

`uv` is the sanctioned packaging/venv/runner tool (one tool for what `pip`+`venv`+`pip-tools`
did), `ruff` the sanctioned linter *and* formatter (one tool replacing both `flake8`/`isort` and
`black`), `mypy` the mandatory type-check gate, `pytest` (with `pytest-asyncio`) the test runner.
Full annotated Makefile with every target body: `references/makefile-targets.md`.

| Target | Runs | Notes |
|---|---|---|
| `install` | `uv sync --frozen` | Deterministic install from `uv.lock`; `--frozen` fails if the lock is stale |
| `format` | `ruff format . && ruff check --fix .` | The only target that *writes* — never in `ci` |
| `lint` | `ruff format --check . && ruff check .` | Read-only; the CI form of `format` |
| `typecheck` | `mypy app tests` | The gate Go's compiler gives for free — mandatory, not optional |
| `test` | `pytest` (config in `pyproject.toml`) | `pytest-asyncio` for async handlers; coverage threshold enforced here |
| `migrate` | `alembic upgrade head` | Applies `python-migration`'s revisions; forward-only in production |
| `build` | `docker build` | Thin local wrapper over `python-dockerfile`'s `Dockerfile` |
| `local-up` | `kind` cluster + apply manifests | Local dev stack — Postgres, Redpanda, the service |
| `ci` | `install lint typecheck test freshness` | The one command that gates a merge |

```makefile
.PHONY: ci
ci: install lint typecheck test freshness  ## Everything CI runs — the one command that gates a merge
```

---

## The Gate Order Is Fail-Fast

`install → lint → typecheck → test → freshness` runs each target only after every *cheaper* check
that could already have failed the build has had its chance to, so a developer never waits on a
full `pytest` run to learn about a formatting nit `ruff` catches in milliseconds:

| Order | Target | Relative cost | Why here |
|---|---|---|---|
| 1 | `install` | Seconds (cached lock) | Nothing downstream runs without the resolved venv |
| 2 | `lint` | Milliseconds, no import | `ruff` is a Rust-fast static pass — cheapest real check |
| 3 | `typecheck` | Moderate | `mypy` must resolve and analyze imports — slower than `ruff`, still no execution |
| 4 | `test` | Slowest by far | `pytest` imports and executes the whole suite |
| 5 | `freshness` | Fast | A `git diff` check — only meaningful once everything upstream is green |

`format`, `build`, `local-up`, and `migrate` are intentionally absent from `ci` — `format` *writes*
files (CI must never mutate the tree), and the others need infrastructure or a registry that
CI-parity keeps out of the merge gate. Full reasoning per target: `references/makefile-targets.md`.

---

## `typecheck`: The Gate Go Gets For Free

`mypy app tests` is **mandatory in `ci`, not an optional nicety**. Python's type hints are
runtime-erased — they check nothing unless `mypy` (or `pyright`) runs and its failures break the
build. FastAPI's Pydantic validation covers only the request/response *boundary*; internal domain
code's hints are unchecked without this gate. Skipping it ships a materially weaker static-safety
guarantee than either Go (compiler-enforced) or TypeScript (`tsc` build step). `mypy` runs in
`--strict` mode with per-module opt-outs recorded in `pyproject.toml`, never a blanket
`ignore_errors`. Full config: `references/toolchain-and-ci.md`.

---

## `freshness`: Generated Artifacts Must Be Committed And Current

The `freshness` target regenerates every derived artifact (the OpenAPI client from
`python-openapi-codegen`, the compiled `uv.lock`, any code-genned models) and runs
`git diff --exit-code` — a non-empty diff fails the build. This is the check-generate pattern: a
merge with stale generated code guarantees the next developer's regenerate produces a surprise
diff they didn't write. The Go roster enforces the identical rule with its own `git diff
--exit-code`; only the generators differ. Full pattern with the GitHub Actions wiring:
`references/toolchain-and-ci.md`.

---

## No Race Detector — And Why

`go-makefile` mandates `-race` on every test run; this Makefile deliberately has no equivalent, and
that is correct, not an omission. Under the GIL only one thread executes Python bytecode at a time,
so pure-Python code has no shared-memory data race for a detector to find. The narrower residual
risks — native-extension code and `multiprocessing` shared memory — are not what a Go-style race
detector targets and are out of scope for the `test` target. Claiming a Python race-detector target
would be inventing a check that detects nothing. (Async correctness — forgotten `await`, unawaited
coroutines — *is* checked, but by `ruff`/`mypy` statically, not by a runtime detector.)

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| CI-Parity | Every target runs identically local and in CI; CI calls `make ci` only | A CI-only target, a "fast local" variant, or YAML re-listing raw commands |
| One command per task | Every routine is a single named target; flags live inside it | A README telling developers to type a long `uv run pytest ...` by hand |
| `typecheck` mandatory | `mypy` in `ci`, failures break the build, `--strict` with recorded opt-outs | `mypy` absent, advisory-only, or blanket `ignore_errors` |
| Single CI entry, order preserved | `make ci` runs `install lint typecheck test freshness` in that order | Gates reordered without cost justification, or an ad-hoc CI script |
| Coverage enforced | `test` fails below the `--cov-fail-under` threshold | Coverage printed but not gating |
| Freshness enforced | `make ci` fails on any uncommitted regen/lock diff | Stale generated code or `uv.lock` allowed to merge |
| No phantom race target | No race-detector target; the GIL rationale is stated | A `test-race` target that detects nothing |
| `.PHONY` complete, `help` present | Every task target `.PHONY`; `make help` lists them | A file named like a target silently shadowing it |

---

## Anti-Patterns

- **A "fast" test target that skips coverage or a subset of tests** — the moment a shortcut exists
  it becomes the default and the gate erodes. One `test` target, threshold always enforced.
- **CI YAML re-listing raw `ruff`/`mypy`/`pytest` commands** — the pipeline drifts from the
  Makefile and reintroduces "passes locally, fails in CI." CI calls `make ci`, nothing else.
- **Treating `mypy` as optional** — the single most common way a Python port silently ships weaker
  static safety than Go or TypeScript. `typecheck` is a merge gate, not a suggestion.
- **Inventing a race-detector target** — there is nothing for it to detect under the GIL; it would
  be a green check that guarantees nothing.
- **Skipping `freshness`** — stale generated code or an untidy `uv.lock` merging guarantees the
  next regenerate produces a surprise diff for whoever runs it next.
- **`format` inside `ci`** — a merge gate must never mutate the working tree; CI uses the read-only
  `lint` (`ruff format --check`) form instead.

---

## Output Format

**`Makefile`** — `install`, `format`, `lint`, `typecheck`, `test`, `migrate`, `build`, `local-up`,
`freshness`, and the aggregate `ci` composed exactly as `install lint typecheck test freshness`;
every task target `.PHONY`; a self-documenting `help` target. Full listing:
`references/makefile-targets.md`.

**`pyproject.toml`** (toolchain sections) — `[tool.ruff]`, `[tool.mypy]` (`strict = true`),
`[tool.pytest.ini_options]` (with `--cov-fail-under`), and the `[project]`/`uv` dependency
metadata the targets read. Full config and the GitHub Actions workflow that calls `make ci`:
`references/toolchain-and-ci.md`.
