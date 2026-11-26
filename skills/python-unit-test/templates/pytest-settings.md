# pytest Settings and Pinned Tools

Self-contained. Merge into the product's one `pyproject.toml`; `python-makefile` owns that file, so change settings there, never in a second configuration file (pytest reads the first it finds and does not merge them). Run on Python 3.14.4 with the pinned versions below (2026-11-26); other Python versions are unverified.

```toml
[dependency-groups]
dev = [
    "pytest==9.2.0",
    "pytest-asyncio==1.5.0",
    "pytest-cov==7.1.0",
    "coverage==7.17.5",
    "hypothesis==6.170.17",
]

[tool.pytest.ini_options]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "function"
asyncio_default_test_loop_scope = "function"
testpaths = ["tests"]
pythonpath = [".", "src"]            # "." for "from tests.fakes import ..."
strict = true                        # unknown markers and keys, non-strict xfail, duplicate ids
empty_parameter_set_mark = "fail_at_collect"
filterwarnings = [
    "error::RuntimeWarning",                            # a coroutine never awaited
    "error::pytest.PytestUnraisableExceptionWarning",   # the form that warning arrives in
    "error::pytest.PytestCollectionWarning",            # a test class that is silently not run
    "error::pytest.PytestAssertRewriteWarning",         # assert (x == y, "message")
]
markers = ["integration: needs a real database or broker; not a unit test"]
```

Rules:

- No `--cov` flag and no `fail_under` anywhere in this file: they break subset runs and disturb mutation runs. Only the gate script measures coverage, and it writes its own coverage configuration.
- Settings tests need go in ini keys, not `addopts`: the gate clears `addopts`.
- Register every marker used; `strict` makes an unknown one an error.
- Give each folder under `tests/` an `__init__.py` so two files may share a name.
- Add `.pytest_cache/`, `.hypothesis/` and `.coverage*` to `.gitignore`.
