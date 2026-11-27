# Toolchain Config and CI Wiring

The `pyproject.toml` sections every Makefile target reads, the check-generate freshness pattern in
full, and the GitHub Actions workflow that calls `make ci` — proving the CI-Parity Principle
mechanically rather than by assertion.

The four sanctioned tools and what each one replaces from the fragmented historical Python
landscape:

| Tool | Role | Replaces |
|---|---|---|
| `uv` | Packaging, virtualenv, lockfile, script runner | `pip` + `venv` + `pip-tools` + `pipenv`/`poetry` |
| `ruff` | Linter **and** formatter | `flake8` + `isort` + `pyupgrade` + `black` |
| `mypy` | Static type checker (the mandatory gate) | *(nothing — Go's compiler does this for free)* |
| `pytest` | Test runner (+ `pytest-asyncio`, `pytest-cov`) | `unittest` |

One tool per concern, pinned in `uv.lock`, is this repo's "pick one sanctioned default" pattern —
the same reasoning that chose `chi` over gin/echo and `pgx` over `database/sql`.

---

## `pyproject.toml` — the single config file all targets read

```toml
[project]
name = "dataasset-service"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.115",
    "uvicorn[standard]>=0.32",
    "asyncpg>=0.30",
    "aiokafka>=0.12",
    "pydantic>=2.9",
    "alembic>=1.14",
]

[dependency-groups]
dev = [
    "ruff>=0.8",
    "mypy>=1.13",
    "pytest==9.2.0",          # test tools pinned (python-unit-test)
    "pytest-asyncio==1.5.0",
    "pytest-cov==7.1.0",
    "coverage==7.17.5",
    "hypothesis==6.170.17",
    "testcontainers==4.15.0",   # harness: python-integration-test
]

# ---- ruff: lint + format in one tool ----------------------------------------
[tool.ruff]
target-version = "py312"
line-length = 100

[tool.ruff.lint]
# E,F = pyflakes/pycodestyle; I = isort; UP = pyupgrade; B = bugbear;
# ASYNC = flake8-async (catches blocking calls inside async def — the Python
# analog of Go's noctx/bodyclose static leak checks); RUF = ruff-native rules.
select = ["E", "F", "I", "UP", "B", "ASYNC", "RUF"]
# A bare, reasonless `# noqa` is itself a finding — every suppression names its rule.

[tool.ruff.lint.per-file-ignores]
"tests/*" = ["B011"]  # asserts are the point in tests

# ---- mypy: the mandatory type gate ------------------------------------------
[tool.mypy]
python_version = "3.12"
strict = true                 # the whole strict bundle on by default
warn_unreachable = true
warn_redundant_casts = true
# Per-module opt-outs are RECORDED here, never a blanket ignore_errors. A
# third-party stub gap is scoped to that module and nothing else.
[[tool.mypy.overrides]]
module = ["aiokafka.*"]
ignore_missing_imports = true

# ---- pytest: one table for every suite; no coverage flags here ---------------
[tool.pytest.ini_options]
asyncio_mode = "auto"         # pytest-asyncio drives async test functions
asyncio_default_fixture_loop_scope = "function"
asyncio_default_test_loop_scope = "function"
testpaths = ["tests"]
pythonpath = [".", "src"]     # "." for "from tests.fakes import ..."
strict = true                 # unknown markers and keys, non-strict xfail, duplicate ids
empty_parameter_set_mark = "fail_at_collect"
filterwarnings = [
    "error::RuntimeWarning",  # a coroutine never awaited
    "error::pytest.PytestUnraisableExceptionWarning",
    "error::pytest.PytestCollectionWarning",
    "error::pytest.PytestAssertRewriteWarning",
]
markers = ["integration: needs a real database or broker; not a unit test"]
```

The coverage gate is not configured here. `make test` runs `scripts/check-python-coverage.sh` (copied
from `python-unit-test`), which requires 100% of lines and 100% of branches over the full run, writes
its own coverage configuration and reads the JSON report. There is no `--cov` flag, `fail_under` or
`omit` in `pyproject.toml`: a coverage flag in shared settings fails every subset run, and a single
percentage passes with code hidden. Generated code (marked in the file's leading comments) is
excluded automatically; `...` placeholder bodies and `if TYPE_CHECKING:` blocks are approved as a
class and printed on every run; every other exclusion goes in `coverage-exceptions.txt` once the
product owner approves it. `make ci` and the pipeline run the same target, so there is no second copy to drift.

---

## The check-generate Freshness Pattern

Any artifact derived from a source of truth — the compiled `uv.lock` (from `pyproject.toml`), the
generated OpenAPI client (from the OpenAPI spec) — is regenerated in CI and the build fails if the
result differs from what was committed. The mechanism is `git diff --exit-code`: `git diff` exits
non-zero when the working tree differs from `HEAD`, so if regeneration changed anything, the target
fails.

```makefile
freshness:
	uv lock                       # recompute uv.lock from pyproject.toml
	uv run python -m app.codegen  # regen the OpenAPI client / models
	git diff --exit-code          # non-empty diff => committed artifacts were stale
```

Why this is a merge gate and not a convenience: without it, a developer who edits `pyproject.toml`
but forgets to re-run `uv lock` merges a `uv.lock` that no longer matches the declared
dependencies. The next person to run `make install` (or `uv lock`) gets a surprise diff they did
not author and cannot easily attribute. The freshness gate makes staleness fail *the PR that
introduced it*, where it is cheap to fix, instead of ambushing an unrelated teammate later. This is
the identical rule the Go roster enforces with its own trailing `git diff --exit-code`; only the
generators (`uv lock`, `python -m app.codegen`) differ from Go's (`go mod tidy`, `go generate`).

---

## GitHub Actions — CI Calls `make ci`, Nothing Else

```yaml
# .github/workflows/ci.yml
name: ci
on:
  pull_request:
  push:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Install uv (pinned) — the only tool the runner needs; uv provisions
      # the exact Python version and every dev dependency from uv.lock.
      - name: Install uv
        uses: astral-sh/setup-uv@v4
        with:
          version: "0.5.11"        # pinned, never @latest — an upstream uv
                                   # release must not fail an unrelated PR
          enable-cache: true

      - name: Pin Python
        run: uv python install 3.12

      # The entire quality gate is one line. Every check — ruff, mypy, pytest,
      # coverage gate, freshness — runs through the SAME Makefile targets a developer
      # runs locally. There is no CI-only command here to drift from the Makefile.
      - name: Run the full CI gate
        run: make ci
```

The whole point is the last step. A pipeline that instead wrote `run: ruff check .` then
`run: mypy app` then `run: pytest --cov ...` would be maintaining a *second* definition of the gate
that inevitably drifts from the Makefile — a flag added locally but not in YAML, or vice versa —
and reintroduces exactly the "passes locally, fails in CI" gap the CI-Parity Principle exists to
close. One definition, in the Makefile; CI is a thin caller.

`astral-sh/setup-uv` is pinned to an exact version for the same reason `go-makefile` pins
`golangci-lint`: a floating `@latest` lets an upstream tool release fail a PR that changed nothing,
turning an unrelated dependency's release schedule into a source of red builds.

---

## Honest Python-vs-Go Divergences This Config Encodes

- **`typecheck` is a whole extra gate.** Go's compiler type-checks unconditionally as part of
  every build; Python's hints are runtime-erased, so `mypy --strict` is an *added* CI stage with no
  Go counterpart. Omitting it ships weaker static safety than Go or TypeScript — it is mandatory,
  not advisory.
- **No `-race`, no coverage `atomic` mode.** Go runs every test under `-race` with
  `-covermode=atomic`. Python has neither: under the GIL, pure-Python code has no shared-memory
  data race to detect, so there is nothing for a race flag to find and no atomic-counter concern.
  A `test-race` target would be a green check guaranteeing nothing.
- **`ruff` consolidates more than Go's or Node's linters.** One tool is both linter and formatter,
  replacing `flake8`+`isort`+`black` — more consolidated than Go's `go vet`+`golangci-lint` and far
  more than Node's ESLint+Prettier split. One config block (`[tool.ruff]`), one target.
- **CPU-bound work is out of scope by design.** Nothing in this Makefile provisions a
  `ProcessPoolExecutor` or profiles CPU parallelism — because per this repo's standard, CPU/ML-bound
  document parsing and classification stay a separate, independently-scaled service
  (`data-pipeline-implementation`). This task runner gates an I/O-bound `asyncio` service, where
  the GIL is released during I/O waits and never contends.
