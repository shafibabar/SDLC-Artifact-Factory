# Standard: Class Booking Cancellation

Self-contained input and output. Settings: `pyproject.toml` as in `../templates/pytest-settings.md`; every folder under `src/` and `tests/` has an empty `__init__.py`. Run on Python 3.14.4, pytest 9.2.0, pytest-asyncio 1.5.0, pytest-cov 7.1.0, coverage 7.17.5, mypy 1.13.0 strict (2026-11-26); gate output is copied from the runs. Package `flexfit`.

## Input

> "Cancel a class booking. Late (under 12 hours) costs £2, or £5 if someone is waiting; premium members pay nothing. Check-in opens 15 minutes before. Text the waitlist. Mock the repository and assert `save` was called once."

## Output

| Part | Kind | Proof |
|---|---|---|
| `Booking` | Domain logic | Decision table (late x premium x waitlisted = 8 rules, none collapsed); each event refused after each finishing event; both sides of the check-in limit. Not tried: longer event sequences |
| `cancel_booking` | Use case | One test per way it can end, with a fake and a mock |
| `tests/fakes.py` | Test support | Outside the measured source; keep it honest with the shared behaviour suite of `mock-generation` (not shown) |

Refused: a repository mock and "`save` was called once". The repository is ours, so the test reads the stored booking and the stored event. The text message leaves the application, so its gateway gets a mock and an awaited-call assertion. `create_autospec` on the Protocol makes its `async` method awaitable and rejects a wrong argument list; a mock that no test asserts verifies nothing.

```python
# file: src/flexfit/domain/booking.py
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum

LATE_WINDOW = timedelta(hours=12)
EARLY_CHECK_IN = timedelta(minutes=15)
LATE_FEE = 200
BLOCKING_FEE = 500


class State(Enum):
    BOOKED = "booked"
    CANCELLED = "cancelled"
    ATTENDED = "attended"


class NotBookedError(Exception):
    def __init__(self, booking_id: str, state: State) -> None:
        super().__init__(f"booking {booking_id} is {state.value}, not booked")
        self.state = state


class TooEarlyError(Exception):
    def __init__(self, booking_id: str, opens_at: datetime) -> None:
        super().__init__(f"check-in for {booking_id} opens at {opens_at.isoformat()}")
        self.opens_at = opens_at


@dataclass(frozen=True)
class BookingCancelled:
    booking_id: str
    fee_pence: int
    occurred_at: datetime


class Booking:
    def __init__(self, booking_id: str, starts_at: datetime, premium: bool) -> None:
        self._id = booking_id
        self._starts_at = starts_at
        self._premium = premium
        self._state = State.BOOKED
        self._events: list[BookingCancelled] = []

    @property
    def id(self) -> str:
        return self._id

    @property
    def state(self) -> State:
        return self._state

    def cancel(self, now: datetime, waitlisted: bool) -> int:
        """Release the slot and return the fee in pence."""
        if self._state is not State.BOOKED:
            raise NotBookedError(self._id, self._state)
        fee = 0
        if self._starts_at - now < LATE_WINDOW and not self._premium:
            fee = BLOCKING_FEE if waitlisted else LATE_FEE
        self._state = State.CANCELLED
        self._events.append(BookingCancelled(self._id, fee, now))
        return fee

    def check_in(self, now: datetime) -> None:
        if self._state is not State.BOOKED:
            raise NotBookedError(self._id, self._state)
        opens_at = self._starts_at - EARLY_CHECK_IN
        if now < opens_at:
            raise TooEarlyError(self._id, opens_at)
        self._state = State.ATTENDED

    def pull_events(self) -> list[BookingCancelled]:
        drained, self._events = self._events, []
        return drained
```

```python
# file: src/flexfit/service_layer/commands.py
from datetime import datetime
from types import TracebackType
from typing import Protocol

from flexfit.domain.booking import Booking


class BookingRepository(Protocol):
    async def get(self, booking_id: str) -> Booking | None: ...

    async def save(self, booking: Booking) -> None: ...


class UnitOfWork(Protocol):
    @property
    def bookings(self) -> BookingRepository: ...

    async def __aenter__(self) -> "UnitOfWork": ...

    async def __aexit__(self, exc_type: type[BaseException] | None,
                        exc: BaseException | None, tb: TracebackType | None) -> None: ...

    async def commit(self) -> None: ...


class SmsGateway(Protocol):
    async def send(self, phone: str, text: str) -> None: ...


class BookingNotFoundError(Exception):
    def __init__(self, booking_id: str) -> None:
        super().__init__(f"booking {booking_id} not found")
        self.booking_id = booking_id


async def cancel_booking(booking_id: str, waitlist_phone: str | None, uow: UnitOfWork,
                         sms: SmsGateway, now: datetime) -> int:
    async with uow:
        booking = await uow.bookings.get(booking_id)
        if booking is None:
            raise BookingNotFoundError(booking_id)
        fee = booking.cancel(now, waitlisted=waitlist_phone is not None)
        await uow.bookings.save(booking)
        await uow.commit()
    if waitlist_phone is not None:
        await sms.send(waitlist_phone, "A place has opened in your class")
    return fee
```

```python
# file: tests/fakes.py
from copy import deepcopy
from types import TracebackType

from flexfit.domain.booking import Booking, BookingCancelled


class FakeBookingRepository:
    def __init__(self) -> None:
        self.stored: dict[str, Booking] = {}
        self.outbox: list[BookingCancelled] = []

    async def get(self, booking_id: str) -> Booking | None:
        return deepcopy(self.stored.get(booking_id))      # a copy: unsaved changes stay unseen

    async def save(self, booking: Booking) -> None:
        self.outbox.extend(booking.pull_events())
        self.stored[booking.id] = deepcopy(booking)


class FakeUnitOfWork:
    def __init__(self, *bookings: Booking) -> None:
        self.bookings = FakeBookingRepository()
        self.bookings.stored = {b.id: deepcopy(b) for b in bookings}
        self.committed = False

    async def __aenter__(self) -> "FakeUnitOfWork":
        self.committed = False
        self._before = (dict(self.bookings.stored), list(self.bookings.outbox))
        return self

    async def __aexit__(self, exc_type: type[BaseException] | None,
                        exc: BaseException | None, tb: TracebackType | None) -> None:
        if exc_type is not None or not self.committed:      # roll back by default
            self.bookings.stored, self.bookings.outbox = self._before
            self.committed = False

    async def commit(self) -> None:
        self.committed = True
```

```python
# file: tests/unit/domain/test_booking.py
from collections.abc import Callable
from datetime import datetime, timedelta, timezone

import pytest

from flexfit.domain.booking import (
    Booking,
    BookingCancelled,
    NotBookedError,
    State,
    TooEarlyError,
)

STARTS = datetime(2026, 3, 4, 18, 0, tzinfo=timezone.utc)
EARLY = STARTS - timedelta(hours=12)                       # exactly 12 hours: not late
LATE = EARLY + timedelta(seconds=1)


def booked(premium: bool = False) -> Booking:
    return Booking("b-1", STARTS, premium)


@pytest.mark.parametrize(
    ("now", "premium", "waitlisted", "fee"),
    [
        pytest.param(EARLY, False, False, 0, id="early-standard-nobody-waiting"),
        pytest.param(EARLY, False, True, 0, id="early-standard-waitlist"),
        pytest.param(EARLY, True, False, 0, id="early-premium-nobody-waiting"),
        pytest.param(EARLY, True, True, 0, id="early-premium-waitlist"),
        pytest.param(LATE, False, False, 200, id="late-standard-nobody-waiting"),
        pytest.param(LATE, False, True, 500, id="late-standard-waitlist"),
        pytest.param(LATE, True, False, 0, id="late-premium-nobody-waiting"),
        pytest.param(LATE, True, True, 0, id="late-premium-waitlist"),
    ],
)
def test_cancel_charges_by_decision_table(
    now: datetime, premium: bool, waitlisted: bool, fee: int
) -> None:
    booking = booked(premium)

    assert booking.cancel(now, waitlisted) == fee

    assert booking.state is State.CANCELLED
    assert booking.pull_events() == [BookingCancelled("b-1", fee, now)]


def cancel(booking: Booking) -> None:
    booking.cancel(EARLY, waitlisted=False)


def check_in(booking: Booking) -> None:
    booking.check_in(STARTS)


@pytest.mark.parametrize("first", [cancel, check_in], ids=["after-cancel", "after-check-in"])
@pytest.mark.parametrize("second", [cancel, check_in], ids=["cancel", "check-in"])
def test_finished_booking_refuses_every_event(
    first: Callable[[Booking], None], second: Callable[[Booking], None]
) -> None:
    booking = booked()
    first(booking)
    state = booking.state
    booking.pull_events()

    with pytest.raises(NotBookedError) as caught:
        second(booking)

    assert caught.value.state is state
    assert booking.state is state
    assert booking.pull_events() == []


OPENS = STARTS - timedelta(minutes=15)


def test_check_in_one_second_early_is_refused() -> None:
    booking = booked()

    with pytest.raises(TooEarlyError) as caught:
        booking.check_in(OPENS - timedelta(seconds=1))

    assert caught.value.opens_at == OPENS
    assert booking.state is State.BOOKED


def test_check_in_succeeds_when_it_opens() -> None:
    booking = booked()

    booking.check_in(OPENS)

    assert booking.state is State.ATTENDED
    assert booking.pull_events() == []
```

```python
# file: tests/unit/service_layer/test_commands.py
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, create_autospec

import pytest

from flexfit.domain.booking import Booking, NotBookedError, State
from flexfit.service_layer.commands import (
    BookingNotFoundError,
    SmsGateway,
    cancel_booking,
)
from tests.fakes import FakeUnitOfWork

STARTS = datetime(2026, 3, 4, 18, 0, tzinfo=timezone.utc)
LATE = STARTS - timedelta(hours=1)


@pytest.fixture
def sms() -> AsyncMock:
    gateway: AsyncMock = create_autospec(SmsGateway, instance=True)
    return gateway


@pytest.fixture
def uow() -> FakeUnitOfWork:
    return FakeUnitOfWork(Booking("b-1", STARTS, premium=False))


async def test_cancel_stores_state_and_event_and_texts_the_waitlist(
    uow: FakeUnitOfWork, sms: AsyncMock
) -> None:
    fee = await cancel_booking("b-1", "+440000000001", uow, sms, LATE)

    assert fee == 500
    assert uow.committed
    stored = await uow.bookings.get("b-1")
    assert stored is not None and stored.state is State.CANCELLED
    assert [event.fee_pence for event in uow.bookings.outbox] == [500]
    sms.send.assert_awaited_once_with("+440000000001", "A place has opened in your class")


async def test_cancel_with_nobody_waiting_sends_nothing(
    uow: FakeUnitOfWork, sms: AsyncMock
) -> None:
    assert await cancel_booking("b-1", None, uow, sms, LATE) == 200

    assert uow.committed
    sms.send.assert_not_awaited()


async def test_unknown_booking_changes_and_sends_nothing(
    uow: FakeUnitOfWork, sms: AsyncMock
) -> None:
    with pytest.raises(BookingNotFoundError):
        await cancel_booking("b-2", "+440000000001", uow, sms, LATE)

    assert not uow.committed
    assert uow.bookings.outbox == []
    sms.send.assert_not_awaited()


async def test_second_cancel_is_refused_and_sends_nothing(
    uow: FakeUnitOfWork, sms: AsyncMock
) -> None:
    await cancel_booking("b-1", None, uow, sms, LATE)

    with pytest.raises(NotBookedError):
        await cancel_booking("b-1", "+440000000001", uow, sms, LATE)

    assert len(uow.bookings.outbox) == 1
    sms.send.assert_not_awaited()
```

`save` moves the events into the fake's `outbox`; asserting that row, not a publish call, is how a product with a Transactional Outbox proves the event.

## The gate and what it showed

The ports have `...` bodies. coverage.py leaves them out; they belong to a class the product owner approved once, so no entry is needed and the run lists them:

```text
excluded src/flexfit/service_layer/commands.py: approved class, "..." placeholder bodies: lines 10, 12, 16, 17, 19, 24, 28
tests: 18 ran, 0 skipped or expected to fail (they prove nothing)
Line coverage: 76/76 statements
Branch coverage: 12/12 branches
PASS: every measured line and branch ran
```

Then, as a trial, a helper marked `# pragma: no cover` was appended to `commands.py`:

```python
def audit_label(booking_id: str) -> str:  # pragma: no cover
    return f"booking:{booking_id}"
```

```text
excluded src/flexfit/service_layer/commands.py: approved class, "..." placeholder bodies: lines 10, 12, 16, 17, 19, 24, 28
tests: 18 ran, 0 skipped or expected to fail (they prove nothing)
Line coverage: 76/76 statements
Branch coverage: 12/12 branches
unapproved exclusion: src/flexfit/service_layer/commands.py lines 51, 52; entry to propose: src/flexfit/service_layer/commands.py | lines 78b16e01de0a | pending | <reason>
NO RESULT: lines are left out without the product owner's approval. The counts above are not a verdict.
```

All tests passed and the counts were complete, yet the run gives no result. Two remedies: remove the pragma and test the helper, or list that entry with a reason for the product owner; it stays pending, and the build blocked, until they approve it. The helper was removed.

Two faults planted by hand, to show the assertions work: deleting `await uow.commit()` failed three tests (the fake rolls back); deleting the `await` before `sms.send` failed the run through the warning filters.

## What the answer says

- What is replaced, by name and why; every other owned dependency keeps a fake, and only the text gateway is mocked.
- Standard size adds the use case, a fake and a mock; the rules are the lean ones.
- Gate counts, as above, from the JSON report; `--cov-fail-under` is not used, because it passes with lines left out. Only generated code is excluded automatically; `...` placeholder bodies and `if TYPE_CHECKING:` blocks are approved as a class and listed (the ports, above); any other exclusion needs its own reason and the product owner's approval. The gate ignores the product's coverage settings; no test was skipped.
- Unmeasured: alternatives inside one line; zero-iteration loops; docstring-only bodies counted as run; child processes; hidden or skipped tests.
- Not run: the real repository, broker or gateway. They belong in `python-integration-test` and `python-contract-test`.
