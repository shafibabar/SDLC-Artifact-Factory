# pytest Configuration and Dependencies for the End-to-End Suite

Self-contained. Use when adding the suite to a product's `pyproject.toml`, or when asked what `pytest`, `mypy`, `make test` or the coverage gate do with the end-to-end files. `python-makefile` owns `pyproject.toml` and its single pytest table; these are the lines this suite needs in it. Run on 2026-11-28 with Python 3.15.2, uv 0.13.9, pytest 9.2.0 and mypy 2.4.1, with the pytest table of `python-makefile` (`asyncio_mode = "auto"`, `strict = true`, `testpaths = ["tests"]`, `pythonpath = [".", "src"]`).

## Lines to add to `pyproject.toml`

```toml
[dependency-groups]
dev = [
    # ... the product's other development tools ...
    "httpx==0.29.0",                               # the bound client
    "opentelemetry-api==1.45.2",                   # a real trace id
    "opentelemetry-sdk==1.45.2",
    "opentelemetry-instrumentation-httpx==0.66b2", # beta: pin it exactly
]

[[tool.mypy.overrides]]
module = ["asyncpg.*"]          # only when a journey seeds the database directly
ignore_missing_imports = true
```

- **No marker line is needed.** `tests/e2e/conftest.py` registers `e2e` and `smoke` itself, and puts them on tests by folder. Run with `strict = true` (which includes strict markers): no unknown-marker error, and `-m smoke` is accepted.
- **No `addopts` line.** Nothing about the end-to-end suite belongs in `addopts`: the runner clears `addopts` and `PYTEST_ADDOPTS` so that no setting can narrow its selection or add retries.
- **No rerun plugin and no `reruns` setting.** `test-pyramid` allows one retry at the end-to-end layer only; the runner does that retry itself and switches a rerun plugin off (`-p no:rerunfailures`). A `--reruns` flag in `addopts` would retry unit and integration tests too.
- **`pytest-timeout` is optional.** If the product uses it, use the `signal` method. Run: with `signal` the test failed, its teardown ran and the report was written; with `thread` the process ended at once, with no teardown and no report file.
- **Empty `__init__.py` files** in `tests/`, `tests/e2e/`, `tests/e2e/journeys/` and `tests/e2e/smoke/`: the suite imports `tests.e2e.support`, which resolves through `pythonpath = ["."]`.

## What each everyday command does with `tests/e2e/`

| Command | Result (run) |
|---|---|
| `make test`, and so `make ci`: the coverage gate with `--skip-suite e2e` | The folder is left out by path (`--ignore=tests/e2e`). Printed: `suites not run: e2e`. Nothing of the suite is collected and the gate's "no deselection" rule is not touched |
| The coverage gate **without** `--skip-suite e2e` | `NO RESULT: pytest exited 1`: the build is blocked, because every end-to-end test refuses to run |
| A bare `pytest` (it collects `testpaths`, so `tests/e2e` too) | Unit and integration tests run. **Every journey and every smoke test ends as an error that begins `REFUSED:`**, before any request is sent; exit 1. For a quick local run name the folders: `pytest tests/unit tests/integration` |
| `pytest tests/e2e/journeys` by hand, with or without an address variable | The same refusal. `E2E_BASE_URL` and the like are read by nothing |
| `make typecheck` (`mypy` on the package and `tests`) | The end-to-end files are type-checked like any other test code (run: no error under `strict`). The four packages above must therefore be in the `dev` group |
| `make e2e` | The only way the journeys run |

The Go twin keeps its files out of every build with build tags. Python has no such switch, so the suite is kept out of the everyday run by path, and a run that reaches it anyway is refused by the guard instead of being silently skipped.

## Time limits

Three bounds, the inner ones first:

| Bound | Where | Default |
|---|---|---|
| One request | `httpx.Timeout` of the bound client | 15 s |
| One wait | `within=` of `eventually` and `eventually_async` | Set per wait, from what the product promises |
| One selection | `E2E_PY_TIMEOUT` of `run-python-e2e-suite.sh` | 1200 s. At the limit the runner interrupts pytest, which runs teardown and writes its report (run: exit 2, teardown ran, report written); the run counts as broken and nothing is retried |
