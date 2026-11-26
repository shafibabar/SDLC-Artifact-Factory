# Property-Based Tests with Hypothesis

Self-contained. Use for an invariant, a round trip, a parser of untrusted input, or a rule over a very large input space, in addition to derived example cases. Facts from the official documentation; behaviour marked "seen" was run with Hypothesis 6.170.17.

## Writing one

```python
from hypothesis import example, given
from hypothesis import strategies as st

usage = st.integers(min_value=0, max_value=1_000_000)


@given(first=usage, extra=usage)
@example(first=99, extra=2)                      # a known case, always run
def test_more_usage_never_costs_less(first: int, extra: int) -> None:
    assert TARIFF.price(first + extra) >= TARIFF.price(first)   # TARIFF: a value built in this module
```

Good properties: invariants, round trips (`parse(format(x)) == x`), bounds, "a refused input changes nothing". Do not restate the implementation in the assertion. Keep the boundary table: a property is not guaranteed to hit a given boundary.

## Repeatable verdicts

The default run is random and keeps a local example database. For the gate, register one derandomized profile in `tests/conftest.py`:

```python
settings.register_profile("gate", derandomize=True, database=None, deadline=None)
settings.load_profile("gate")
```

Hypothesis also switches to a built-in derandomized profile when it detects CI (seen with `CI=1`). Pin the version: generated inputs may differ between versions (unverified). To explore randomly, do it in a separate, non-blocking run and add each failure found as an `@example`.

## Traps

| Trap | What happens |
|---|---|
| A function-scoped fixture in a `@given` test | Set up once for all generated inputs; Hypothesis fails the test with a health check (seen). Build the object inside the test |
| `deadline` (200 ms by default) on a slow machine | Flaky failures; the gate profile removes it |
| `.hypothesis/` folder | Written during runs; ignore it in git |
| `async def` with `@given` | Ran under pytest-asyncio auto mode (seen) |

For stateful testing of an Aggregate's lifecycle, Hypothesis has `RuleBasedStateMachine` (documented, not run here). A passing property shows only that no generated input failed.
