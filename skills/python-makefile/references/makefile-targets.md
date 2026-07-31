# The Full Python Service Makefile

The complete, annotated `Makefile` for a FastAPI + `asyncpg` + `aiokafka` service, plus the
per-target contract (exact command, pass/fail semantics, why it sits where it does). Copy it to the
service root; the toolchain config it reads lives in `pyproject.toml` (`references/toolchain-and-ci.md`).

Every command is prefixed `uv run` so it executes inside the project's locked virtualenv without a
manual `source .venv/bin/activate` — `uv` is the sanctioned runner, and `uv run <cmd>` is
`uv`'s equivalent of `npm run`: it guarantees the tool version is the one pinned in `uv.lock`, not
whatever happens to be on the developer's global `PATH`. This is the mechanism that makes the
CI-Parity Principle real rather than aspirational.

---

## The Complete Makefile

```makefile
# Makefile — the single interface to every routine task on this service.
# Every target runs identically on a laptop and in CI (CI-Parity Principle):
# CI calls `make ci`, nothing else. `uv run` pins every tool to uv.lock.

# ---- Configuration -----------------------------------------------------------
SHELL       := bash
.SHELLFLAGS := -eu -o pipefail -c
PKG         := app                 # the importable application package
TESTS       := tests
IMAGE       := dataasset-service
TAG         ?= dev
KIND_CLUSTER := dataasset-local

# All task targets are phony — none names a file on disk. A source file that
# happened to be named `test` or `build` would otherwise silently shadow the
# target and `make test` would report "up to date" and run nothing.
.PHONY: help install format lint typecheck test migrate build local-up local-down freshness ci

# ---- Self-documenting help (the default target) ------------------------------
help: ## Show this help — one line per target
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
.DEFAULT_GOAL := help

# ---- install: resolve the locked environment --------------------------------
install: ## Install exact locked dependencies (fails if uv.lock is stale)
	uv sync --frozen --all-extras

# ---- format: the ONE target that writes to the tree -------------------------
# Never part of `ci` — a merge gate must not mutate the working tree.
format: ## Auto-format and auto-fix lint findings in place
	uv run ruff format .
	uv run ruff check --fix .

# ---- lint: the read-only CI form of format ----------------------------------
# `ruff format --check` fails if anything is unformatted; `ruff check` is the
# lint pass. One tool replaces flake8 + isort + black — more consolidated than
# Go's vet+golangci-lint split, and far more than Node's ESLint+Prettier.
lint: ## Check formatting and lint rules (read-only)
	uv run ruff format --check .
	uv run ruff check .

# ---- typecheck: the gate Go's compiler gives for free -----------------------
# Mandatory in `ci`. Python's type hints are runtime-erased and check nothing
# unless mypy runs and its failures break the build. Config (strict = true,
# per-module opt-outs) lives in pyproject.toml, never as inline flags here.
typecheck: ## Static type check (mypy --strict, config in pyproject.toml)
	uv run mypy $(PKG) $(TESTS)

# ---- test: the whole suite, coverage threshold enforced ---------------------
# pytest-asyncio drives the async FastAPI handlers, asyncpg pool, and aiokafka
# consumers. --cov-fail-under (in pyproject.toml) makes coverage a gate, not a
# printed number. NO race-detector flag exists or belongs here: under the GIL
# pure-Python code has no shared-memory data race to detect.
test: ## Run the full test suite with coverage gating
	uv run pytest

# ---- migrate: apply Alembic revisions ---------------------------------------
# Alembic is used purely as a migration runner against hand-written SQL (no
# SQLAlchemy ORM models). Forward-only in production — see python-migration.
migrate: ## Apply all pending database migrations
	uv run alembic upgrade head

migrate-new: ## Create a new empty revision: make migrate-new MSG="add data_asset"
	uv run alembic revision -m "$(MSG)"

# ---- build: thin local wrapper over python-dockerfile's Dockerfile ----------
# CI's own image stage calls docker/build-push-action directly for registry
# caching and digest output; this target is the local convenience form.
build: ## Build the service container image locally
	docker build -t $(IMAGE):$(TAG) .

# ---- local-up / local-down: the local dev stack -----------------------------
# A kind cluster running Postgres, Redpanda, and the service — the same
# manifests kubernetes-manifest owns, applied to a throwaway local cluster.
local-up: build ## Create a local kind cluster and deploy the full stack
	kind create cluster --name $(KIND_CLUSTER) || true
	kind load docker-image $(IMAGE):$(TAG) --name $(KIND_CLUSTER)
	kubectl apply -k deploy/local

local-down: ## Tear down the local kind cluster
	kind delete cluster --name $(KIND_CLUSTER)

# ---- freshness: generated artifacts must be committed and current -----------
# Regenerate everything derived, then fail on any diff. A stale uv.lock or a
# stale generated OpenAPI client merging guarantees the next developer's
# regenerate produces a surprise diff they didn't author (check-generate).
freshness: ## Fail if any generated artifact or the lockfile is out of date
	uv lock                       # recompute uv.lock from pyproject.toml
	uv run python -m app.codegen  # regen the OpenAPI client / models
	git diff --exit-code

# ---- ci: the one command that gates a merge ---------------------------------
# Order is a fail-fast cost ordering: cheapest check that can fail runs first.
ci: install lint typecheck test freshness ## Everything CI runs — gates the merge
```

---

## Per-Target Contract

| Target | Exact command | Passes when | Fails when |
|---|---|---|---|
| `install` | `uv sync --frozen --all-extras` | `uv.lock` resolves and installs cleanly | The lock is stale relative to `pyproject.toml` (`--frozen` refuses to update it) |
| `format` | `ruff format .` then `ruff check --fix .` | Always (it mutates to conform) | Only on an internal tool error — never on a style finding, because it fixes them |
| `lint` | `ruff format --check .` then `ruff check .` | Tree is already formatted and lint-clean | Any file unformatted or any lint rule violated |
| `typecheck` | `mypy app tests` | No type error under `strict` | Any type error not covered by a recorded per-module opt-out |
| `test` | `pytest` | All tests pass and coverage ≥ `--cov-fail-under` | A test fails or coverage falls below threshold |
| `migrate` | `alembic upgrade head` | Every pending revision applies | A revision errors or the DB is unreachable |
| `build` | `docker build -t $(IMAGE):$(TAG) .` | The image builds | The `Dockerfile` (python-dockerfile's) fails |
| `local-up` | kind create + load + `kubectl apply -k` | The stack comes up | Cluster creation or manifest apply fails |
| `freshness` | regen + `git diff --exit-code` | Nothing regenerated changed | Any regenerated file or `uv.lock` differs from what's committed |
| `ci` | the five above, in order | All five pass | The first failing gate stops the run |

---

## Why `.PHONY` Is Not Optional

`make` treats a target as a filename by default: if a file named `test` exists, `make test` sees
it is "newer than its prerequisites" and does nothing. A Python service *will* have a `build/`
directory, and may have a `test`-named path; declaring every task target `.PHONY` tells `make`
these are commands, not files, so they always run. A missing `.PHONY` is the classic "why did
`make build` say nothing to do?" bug.

---

## Why the `SHELL` / `.SHELLFLAGS` Header Matters

`make` runs each recipe line in a *fresh* shell, and by default a non-zero exit mid-recipe is only
caught line-by-line. Setting `.SHELLFLAGS := -eu -o pipefail -c` makes every recipe line abort on
the first failing command *and* on any failure inside a pipe (`ruff ... | tee`), so a target can
never report success after a step inside it silently failed. This is the Makefile-level equivalent
of the fail-fast the `ci` ordering gives at the target level.

---

## Taskfile Alternative

Teams that prefer YAML over Make's tab-sensitive syntax may use [Taskfile](https://taskfile.dev)
(`Taskfile.yml`) instead — the target set, order, and CI-Parity rule are identical; only the
syntax differs. The choice is per-service and recorded in `python-project-structure`; whichever is
chosen, CI invokes it (`task ci` or `make ci`) and never re-lists the raw commands.
