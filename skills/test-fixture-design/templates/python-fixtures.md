# pytest Fixture Skeletons

Copy into the paths shown; replace `Booking` and table names with the product's. These are synchronous, DB-API style (shown with `sqlite3`-style `execute`). For an async stack (asyncpg), keep the same shape and take engine, loop and container setup from `python-integration-test`.

`connection` is the fixture that skill provides, connected to the throwaway database this run started. Never build it from `DATABASE_URL`.

## tests/integration/conftest.py

```python
import uuid

import pytest

TEST_NAMESPACE = uuid.UUID("6f9c1b4e-0000-4000-8000-000000000001")


@pytest.fixture
def db(connection):
    """Default: everything the test writes is rolled back."""
    connection.execute("BEGIN")
    try:
        yield connection
    finally:
        connection.execute("ROLLBACK")


@pytest.fixture
def test_id(request):
    """Unique per test and label, identical on every run."""
    def make(label: str) -> str:
        return str(uuid.uuid5(TEST_NAMESPACE, f"{request.node.nodeid}/{label}"))
    return make


@pytest.fixture
def scoped(connection):
    """Only when a real commit is needed. Call BEFORE seeding.

    deletes: one statement per owned table, children first, each filtered by the key.
    The connection must not be inside a transaction.
    """
    registered = []

    def register(key: str, *deletes: str) -> None:
        assert deletes, "list every table this test writes"
        registered.append((key, deletes))

    yield register

    errors = []
    for key, deletes in reversed(registered):
        for statement in deletes:
            try:
                connection.execute(statement, (key,))
            except Exception as exc:  # report every failure, then fail
                errors.append(f"{statement}: {exc}")
    connection.commit()
    assert not errors, "cleanup failed: " + "; ".join(errors)
```

The placeholder style (`?`, `%s`, `$1`) follows the product's driver.

## tests/conftest.py (factory fixture)

```python
from datetime import datetime, timezone

import pytest

FIXED_NOW = datetime(2026, 1, 15, 12, 0, tzinfo=timezone.utc)


@pytest.fixture
def make_booking():
    def make(booking_id: str = "00000000-0000-4000-8000-000000000101", seats: int = 1):
        return Booking.new(booking_id, seats=seats, now=FIXED_NOW)  # product's constructor
    return make
```
