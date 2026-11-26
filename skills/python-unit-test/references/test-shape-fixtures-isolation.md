# Test Shape, Fixtures and Isolation

Self-contained. Use when writing or fixing a Python unit test's structure, fixtures, time or randomness. Mechanics from Okken, *Python Testing with pytest*; behaviour marked "seen" was run with pytest 9.2.0.

## Discovery and assertions

pytest collects `test_*.py` files, `test_*` functions and `Test*` classes. A `Test*` class with `__init__` is **not run**, with only a warning; two functions of one name in a file leave only the second (both seen). The settings template makes the first an error; `validate-python-unit-tests.sh` catches the second.

Use plain `assert`: pytest rewrites it to show both values. No `unittest.TestCase`, `assertEqual` or `setUp`. `assert (x == y, "message")` is always true (seen).

## One behaviour per test

Arrange, act once, assert observable results. Name the behaviour (`test_second_close_is_refused_and_changes_nothing`), not the method. A unit is a unit of behaviour and may span several real classes (Khorikov).

## Tables

`@pytest.mark.parametrize` turns one function into one test per row. Name every row (`pytest.param(..., id="exactly-the-block")` or `ids=`). Stacked decorators give every combination. Rows that need different arrange or assert steps belong in another function, not behind flags. An empty row list is **skipped** by default and the run stays green (seen); the settings template makes it a collection error.

Run one case:

```bash
pytest "tests/unit/domain/test_ticket.py::test_parse_code_rejects[empty]"
pytest -k wrong-prefix
```

A selected run gives no coverage verdict.

## Fixtures

| Need | Use |
|---|---|
| A fresh object per test | Function-scoped fixture (the default) |
| Many configured objects | Factory fixture returning a function |
| Setup and teardown | `yield`; the code after it runs when the test fails too |
| Shared across a folder | `conftest.py`, found automatically; never import a fixture. Nested files layer |
| The same tests under several variants | `@pytest.fixture(params=[...], ids=[...])` |
| An environment variable or attribute for one test | `monkeypatch`, which restores it; not a way to patch the code under test or an owned dependency |

`class`, `module` and `session` scopes share one object between tests: never for anything a test can change. `tmp_path` and real resources belong in integration tests. Data rules (builders, ownership, cleanup) belong to `test-fixture-design`.

## No real world

A unit test touches no file system, network, database, or clock and randomness it does not control, and never sleeps.

| Dependency | Control |
|---|---|
| Current time | Pass `now`, or a `clock: Callable[[], datetime]`; fixed timezone-aware values |
| IDs | Pass them in; fixed constants |
| Randomness | Inject `random.Random(seed)` |
| Waiting and timeouts | Inject the sleeper, or a limit of 0 against an awaitable that never finishes |
| Context variables (tenant, subject) | Set in a synchronous fixture with `token = var.set(...)`, then `var.reset(token)` after `yield` (seen to reach async tests) |

Each test must pass alone and in any order. Running tests in parallel with a plugin was not tried here.

## Skip and expected failure

`skip` runs nothing. `xfail` records a known fault; under `strict = true` an unexpected pass fails the run. Neither proves a behaviour: if a gate or a Must Have criterion then lacks proof, it is not met.
