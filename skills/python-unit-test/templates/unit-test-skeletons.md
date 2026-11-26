# Python Unit Test Skeletons

Copy only what is needed; replace the package, type and rule names. Every block ran together and passed with pytest 9.2.0, pytest-asyncio 1.5.0 and Hypothesis 6.170.17 on Python 3.14.4, using the stand-in code in the first block and the settings in `./pytest-settings.md`. Layout follows `python-project-structure`: `src/<pkg>/{domain,service_layer,...}` and `tests/unit/` mirroring it, a layout `scripts/tdd-gate.sh` accepts. Each `# file:` block is a whole file.

## Stand-in code under test

```python
# file: src/desk/domain/ticket.py
from datetime import datetime


class AlreadyClosedError(Exception):
    def __init__(self, number: int, closed_at: datetime) -> None:
        super().__init__(f"ticket {number} is already closed")
        self.number, self.closed_at = number, closed_at


class Ticket:
    def __init__(self, number: int) -> None:
        self._number = number
        self._closed_at: datetime | None = None

    @property
    def number(self) -> int:
        return self._number

    @property
    def closed_at(self) -> datetime | None:
        return self._closed_at

    def close(self, now: datetime) -> None:
        if self._closed_at is not None:
            raise AlreadyClosedError(self._number, self._closed_at)
        self._closed_at = now


class BadCodeError(ValueError):
    """The text is not "T-<number>"."""


def parse_code(text: str) -> int:
    prefix, _, digits = text.partition("-")
    if prefix != "T" or not (digits.isascii() and digits.isdigit()):
        raise BadCodeError(text)
    return int(digits)
```

```python
# file: src/desk/service_layer/closing.py
import os
import random
from collections.abc import Callable
from datetime import datetime
from typing import Protocol

from desk.domain.ticket import Ticket


class Tickets(Protocol):
    async def get(self, number: int) -> Ticket | None:
        """The stored ticket, or None."""

    async def save(self, ticket: Ticket) -> None:
        """Store the ticket."""


class Mailer(Protocol):
    async def send(self, to: str, subject: str) -> None:
        """Hand one message to the mail provider."""


async def close_ticket(number: int, to: str, tickets: Tickets, mailer: Mailer,
                       clock: Callable[[], datetime]) -> bool:
    ticket = await tickets.get(number)
    if ticket is None:
        return False
    ticket.close(clock())
    await tickets.save(ticket)
    await mailer.send(to, f"Ticket {number} closed")
    return True


def survey_sample(numbers: list[int], size: int, source: random.Random) -> list[int]:
    return source.sample(numbers, size)


def sender_address() -> str:
    return os.environ.get("DESK_SENDER", "desk@example.test")
```

## Fixtures and fake

```python
# file: tests/fakes.py
from copy import deepcopy

from desk.domain.ticket import Ticket


class FakeTickets:
    def __init__(self, *tickets: Ticket) -> None:
        self._rows = {t.number: deepcopy(t) for t in tickets}

    async def get(self, number: int) -> Ticket | None:
        return deepcopy(self._rows.get(number))      # a copy: an unsaved change stays unseen

    async def save(self, ticket: Ticket) -> None:
        self._rows[ticket.number] = deepcopy(ticket)
```

```python
# file: tests/conftest.py
from collections.abc import Callable
from datetime import datetime, timezone

import pytest
from hypothesis import settings

from desk.domain.ticket import Ticket

settings.register_profile("gate", derandomize=True, database=None, deadline=None)
settings.load_profile("gate")

NOW = datetime(2026, 1, 15, 12, 0, tzinfo=timezone.utc)


@pytest.fixture
def now() -> datetime:
    return NOW


@pytest.fixture
def make_ticket() -> Callable[..., Ticket]:
    def make(number: int = 7, closed_at: datetime | None = None) -> Ticket:
        ticket = Ticket(number)
        if closed_at is not None:
            ticket.close(closed_at)
        return ticket

    return make
```

## Domain tests: table, rejection, property

```python
# file: tests/unit/domain/test_ticket.py
from collections.abc import Callable
from datetime import datetime, timedelta

import pytest
from hypothesis import given
from hypothesis import strategies as st

from desk.domain.ticket import AlreadyClosedError, BadCodeError, Ticket, parse_code


@pytest.mark.parametrize(
    ("text", "number"),
    [
        pytest.param("T-0", 0, id="zero"),
        pytest.param("T-42", 42, id="ordinary"),
    ],
)
def test_parse_code_reads_the_number(text: str, number: int) -> None:
    assert parse_code(text) == number


@pytest.mark.parametrize(
    "text",
    ["", "T-", "X-1", "T--1", "T-1.5", "T-²"],
    ids=["empty", "no-digits", "wrong-prefix", "negative", "decimal", "superscript-digit"],
)
def test_parse_code_rejects(text: str) -> None:
    with pytest.raises(BadCodeError):
        parse_code(text)


@given(number=st.integers(min_value=0, max_value=10**12))
def test_parse_code_round_trips(number: int) -> None:
    assert parse_code(f"T-{number}") == number


def test_close_records_the_time(make_ticket: Callable[..., Ticket], now: datetime) -> None:
    ticket = make_ticket()

    ticket.close(now)

    assert ticket.closed_at == now


def test_second_close_is_refused_and_changes_nothing(
    make_ticket: Callable[..., Ticket], now: datetime
) -> None:
    ticket = make_ticket(closed_at=now)

    with pytest.raises(AlreadyClosedError) as caught:
        ticket.close(now + timedelta(hours=1))

    assert caught.value.closed_at == now
    assert ticket.closed_at == now
```

## Use case: fake for the owned store, mock for the outside service

```python
# file: tests/unit/service_layer/test_closing.py
import random
from collections.abc import Iterator
from datetime import datetime
from unittest.mock import AsyncMock, create_autospec

import pytest

from desk.domain.ticket import Ticket
from desk.service_layer.closing import Mailer, close_ticket, sender_address, survey_sample
from tests.fakes import FakeTickets


@pytest.fixture
def mailer() -> AsyncMock:
    mock: AsyncMock = create_autospec(Mailer, instance=True)   # async methods become AsyncMock
    return mock


@pytest.fixture
def tickets() -> Iterator[FakeTickets]:
    store = FakeTickets(Ticket(7))
    yield store                                                # teardown code goes after this


async def test_closing_stores_the_time_and_sends_one_message(
    tickets: FakeTickets, mailer: AsyncMock, now: datetime
) -> None:
    assert await close_ticket(7, "a@example.test", tickets, mailer, lambda: now)

    stored = await tickets.get(7)
    assert stored is not None and stored.closed_at == now
    mailer.send.assert_awaited_once_with("a@example.test", "Ticket 7 closed")


async def test_unknown_ticket_sends_nothing(
    tickets: FakeTickets, mailer: AsyncMock, now: datetime
) -> None:
    assert not await close_ticket(8, "a@example.test", tickets, mailer, lambda: now)

    mailer.send.assert_not_awaited()


def test_survey_sample_repeats_for_the_same_seed() -> None:
    numbers = list(range(20))

    first = survey_sample(numbers, 3, random.Random(1))

    assert first == survey_sample(numbers, 3, random.Random(1))
    assert len(set(first)) == 3 and set(first) <= set(numbers)


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        pytest.param(None, "desk@example.test", id="unset-uses-default"),
        pytest.param("help@example.test", "help@example.test", id="set-wins"),
    ],
)
def test_sender_address(
    monkeypatch: pytest.MonkeyPatch, value: str | None, expected: str
) -> None:
    if value is None:
        monkeypatch.delenv("DESK_SENDER", raising=False)
    else:
        monkeypatch.setenv("DESK_SENDER", value)

    assert sender_address() == expected
```
