# Seeding Straight Into the Database

Self-contained. Use only when a journey needs a state that the product offers **no public way** to create (a row written by a nightly job, a record imported long ago). Everything else is created through the public API (`./python-suite.md`, `journeys/conftest.py`): a journey that writes tables by hand stops proving that the product can reach that state.

Run on Python 3.15.2 with asyncpg 0.32.0 and pytest-asyncio 1.5.0 (`asyncio_mode = "auto"`) against PostgreSQL 17.12 in the throwaway cluster. asyncpg is the driver the Python stack already uses; any driver follows the same rules.

Rules, each enforced by the code below:

- The address comes from the run marker (an endpoint named `db` in `E2E_ENDPOINTS`) and passes `env.require_throwaway`. No address is typed, read from the environment or taken from an option. Seen: `db.staging.example:5432`, `10.0.0.7:5432`, `127.0.0.1:5432` and `localhost:5432` are all refused.
- The credentials are the test-only values of the end-to-end values file. No real credential exists in the suite.
- A plain `INSERT`, never an upsert (`ON CONFLICT ... DO UPDATE`, `MERGE`, `REPLACE`): if the row is already there the test fails instead of overwriting it. Seen: the second `INSERT` of the same row raised `asyncpg.UniqueViolationError`.
- Exactly the rows the fixture wrote are removed after the `yield`, also when the test fails, and a removal that removes nothing fails the test. No `TRUNCATE`, no unfiltered `DELETE` (`test-fixture-design`).
- These files are in `tests/e2e/journeys/`: the smoke selection does not collect them, and the validator fails a smoke file that imports a database driver.

The database is published on a loopback port only for this: add `db|<nodePort>` to `E2E_ENDPOINTS` and set the database chart's Service to that NodePort in its end-to-end values file. asyncpg ships no type information; with mypy in strict mode, add `asyncpg.*` to the recorded `ignore_missing_imports` override in `pyproject.toml` (`python-makefile` owns that table).

### `tests/e2e/journeys/seed_db.py`

```python
"""Seeding straight into the database of this run's throwaway cluster. Only for
state the product offers no public way to create."""

from __future__ import annotations

from collections.abc import AsyncIterator, Awaitable, Callable

import asyncpg
import pytest

from tests.e2e.support import Env


@pytest.fixture
async def throwaway_db(env: Env) -> AsyncIterator[asyncpg.Connection]:
    """A connection to the database of this run's cluster. The address comes from
    the run marker and passes require_throwaway; the credentials are the test-only
    values of tests/e2e/values/postgres.yaml."""
    address = env.addr("db")
    env.require_throwaway(address)
    host, _, port = address.rpartition(":")
    connection = await asyncpg.connect(host=host, port=int(port), user="app", password="e2e-only-not-a-secret", database="app")
    try:
        yield connection
    finally:
        await connection.close()


@pytest.fixture
async def insert_loan_row(throwaway_db: asyncpg.Connection) -> AsyncIterator[Callable[[str, str], Awaitable[None]]]:
    """Writes one row with a plain INSERT, never an upsert: if the row already
    exists the test fails instead of overwriting it. Exactly the rows written here
    are removed afterwards, also when the test fails."""
    made: list[str] = []

    async def insert(loan_id: str, status: str) -> None:
        await throwaway_db.execute("INSERT INTO loans (id, tenant, status, body) VALUES ($1, '', $2, '{}')", loan_id, status)
        made.append(loan_id)

    yield insert
    for loan_id in reversed(made):
        removed = await throwaway_db.execute("DELETE FROM loans WHERE id = $1", loan_id)
        assert removed == "DELETE 1", f"cleanup of loan row {loan_id}: {removed}"
```

### `tests/e2e/journeys/test_journey_returned_loan.py`

```python
from __future__ import annotations

from collections.abc import Awaitable, Callable

import asyncpg
import pytest

from tests.e2e.journeys.seed_db import insert_loan_row, throwaway_db  # noqa: F401  (fixtures)
from tests.e2e.support import Env


async def test_journey_returned_loan_is_still_readable(
    env: Env, insert_loan_row: Callable[[str, str], Awaitable[None]], ref: Callable[[], str]
) -> None:
    """AC-US-5.2: a loan marked returned by the nightly job (no public API creates
    that state) can still be read."""
    loan_id = ref()
    await insert_loan_row(loan_id, "returned")

    async with env.async_client("api") as api:
        reply = await api.get(f"/loans/{loan_id}")
    assert reply.status_code == 200, reply.text
    assert reply.json()["status"] == "returned"

    # A second seed of the same row must fail loudly, not overwrite.
    with pytest.raises(asyncpg.UniqueViolationError):
        await insert_loan_row(loan_id, "pending")
```

In pytest-asyncio's default `strict` mode, decorate the two fixtures with `@pytest_asyncio.fixture` and the test with `@pytest.mark.asyncio` (documented; the run here used `auto`).
