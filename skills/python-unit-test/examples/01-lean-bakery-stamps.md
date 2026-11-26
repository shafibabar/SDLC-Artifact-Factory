# Lean: Bakery Stamp Card (one Python package)

Self-contained input and output. Settings: `pyproject.toml` as in `../templates/pytest-settings.md`; every folder under `src/` and `tests/` has an empty `__init__.py`. Run on Python 3.14.4, pytest 9.2.0, pytest-asyncio 1.5.0, pytest-cov 7.1.0, coverage 7.17.5 (2026-11-26); gate output is copied from the runs. Package `crumbcard`.

## Input

> "Add stamps: one per full £5, double on Tuesdays, at most 10 per purchase. It's a tiny app, a couple of tests is plenty."

## Output

**Kind of code:** domain logic, so a parametrized unit test. **Derivation:** boundary value analysis on spend (-1, 0, 499, 500, 4999, 5000, 5500) and two day classes (Tuesday, not Tuesday). Not tried: very large spends; other days beyond the one representative.

```python
# file: src/crumbcard/domain/stamps.py
from datetime import datetime

PENCE_PER_STAMP = 500
MAX_STAMPS = 10
TUESDAY = 1


class NegativeSpendError(ValueError):
    def __init__(self, spend_pence: int) -> None:
        super().__init__(f"spend must not be negative, got {spend_pence}")
        self.spend_pence = spend_pence


def stamps(spend_pence: int, at: datetime) -> int:
    """Stamps one purchase earns. Tuesdays count double."""
    if spend_pence < 0:
        raise NegativeSpendError(spend_pence)
    earned = spend_pence // PENCE_PER_STAMP
    if at.weekday() == TUESDAY:
        earned *= 2
    if earned > MAX_STAMPS:
        earned = MAX_STAMPS
    return earned
```

## First draft: two tests

```python
# draft, replaced below
from datetime import datetime, timezone

import pytest

from crumbcard.domain.stamps import NegativeSpendError, stamps

TUESDAY_MORNING = datetime(2026, 3, 3, 9, 0, tzinfo=timezone.utc)


def test_negative_spend_is_rejected() -> None:
    with pytest.raises(NegativeSpendError) as caught:
        stamps(-1, TUESDAY_MORNING)
    assert caught.value.spend_pence == -1


def test_large_tuesday_spend_is_capped() -> None:
    assert stamps(5500, TUESDAY_MORNING) == 10
```

```text
  src/crumbcard/domain/stamps.py: branch from line 19 to line 21 not taken
  src/crumbcard/domain/stamps.py: branch from line 21 to line 23 not taken
Line coverage: 17/17 statements
Branch coverage: 4/6 branches
FAIL (branch): the gate is 100%. 90% or below: no waiver.
```

Every line ran, yet no test showed an ordinary day or a purchase under the cap.

## The derived tests

```python
# file: tests/unit/domain/test_stamps.py
from datetime import datetime, timedelta, timezone

import pytest

from crumbcard.domain.stamps import NegativeSpendError, stamps

TUESDAY_MORNING = datetime(2026, 3, 3, 9, 0, tzinfo=timezone.utc)
WEDNESDAY_MORNING = TUESDAY_MORNING + timedelta(days=1)


@pytest.mark.parametrize(
    ("spend_pence", "at", "expected"),
    [
        pytest.param(0, WEDNESDAY_MORNING, 0, id="nothing-spent-earns-nothing"),
        pytest.param(499, WEDNESDAY_MORNING, 0, id="one-penny-short-earns-nothing"),
        pytest.param(500, WEDNESDAY_MORNING, 1, id="exactly-one-stamp"),
        pytest.param(4999, WEDNESDAY_MORNING, 9, id="one-below-the-cap"),
        pytest.param(5000, WEDNESDAY_MORNING, 10, id="exactly-the-cap"),
        pytest.param(5500, WEDNESDAY_MORNING, 10, id="above-the-cap-stays-at-the-cap"),
        pytest.param(500, TUESDAY_MORNING, 2, id="tuesday-doubles"),
        pytest.param(3000, TUESDAY_MORNING, 10, id="tuesday-doubling-is-capped"),
    ],
)
def test_stamps_earned(spend_pence: int, at: datetime, expected: int) -> None:
    assert stamps(spend_pence, at) == expected


def test_negative_spend_is_rejected() -> None:
    with pytest.raises(NegativeSpendError) as caught:
        stamps(-1, WEDNESDAY_MORNING)
    assert caught.value.spend_pence == -1
```

```text
tests: 9 ran, 0 skipped or expected to fail (they prove nothing)
Line coverage: 17/17 statements
Branch coverage: 6/6 branches
PASS: every measured line and branch ran
```

## What the answer says

- "A couple of tests" is replaced by the nine derived cases. Small size means one package and one table; the gate stays at 100% of lines and branches.
- The day is passed in as `at`; no test reads the clock.
- The gate is `check-python-coverage.sh`: it reads the JSON report and fails on any line not run or branch not taken. `--cov-fail-under` and any printed percentage check are removed, not kept as an extra step.
- Generated code is excluded automatically; `...` placeholder bodies and `if TYPE_CHECKING:` blocks are approved as a class and listed; anything else needs its own reason and the product owner's approval. The gate ignores the product's coverage settings. Nothing is excluded or skipped here, and there is no waiver.
- Unmeasured: alternatives inside one line; zero-iteration loops; a docstring-only body; child processes. This code has none of them.
- Coverage shows the paths ran; the assertions check the values.
- Run: the gate on both drafts and the file checker. The red step was not re-enacted for this write-up.
