# Lean: a Choir's Sheet-Music Library

One Python service, one PostgreSQL database, one organisation (no tenant column), no broker. Lean means these few tests and one container, with every fixed rule kept.

Run on 2026-11-27: Python 3.14.4, testcontainers 4.15.0, asyncpg 0.32.0, Alembic 1.20.1, SQLAlchemy 2.1.9, pytest 9.2.0, pytest-asyncio 1.5.0, `postgres:17.12-alpine`.

## Input

> "Test the loan repository against a real database. It is a tiny app."

## Plan

| Behaviour | Isolation and reason |
|---|---|
| Lend, read, give back, give back twice | Rollback |
| Second open loan refused by the index | Rollback, refusal inside a savepoint |
| Another constraint failure is not reported as "on loan" | Rollback, savepoint |
| Migration down and up again | Own database: the test changes the schema |

No relay, consumer or API promise exists, so none is tested and no broker harness is copied. When the service gains an HTTP contract, its documented errors are tested here too.

## Files

`pyproject.toml` pytest settings from `python-unit-test` (the async tests and fixtures need its `asyncio_mode = "auto"`); `alembic.ini` and `migrations/env.py` copied from `python-migration`; `harness.py` and `conftest.py` copied unchanged into `tests/integration/`; empty `__init__.py` files. `domain/errors.py` also needs its own test under `tests/unit/` for the `tdd-gate` hook (`python-unit-test`; not shown).

### `migrations/versions/0001_create_loans.py`

```python
"""create loans

Revision ID: 0001
Revises:
"""
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "CREATE TABLE loans (id uuid PRIMARY KEY, score text NOT NULL, "
        "singer text NOT NULL, returned boolean NOT NULL DEFAULT false)"
    )
    op.execute("CREATE UNIQUE INDEX loans_one_open_per_score ON loans (score) WHERE NOT returned")


def downgrade() -> None:
    op.execute("DROP TABLE loans")
```

### `src/choir/domain/errors.py`

```python
class ScoreOnLoanError(Exception):
    """The score is already on loan."""


class NoOpenLoanError(Exception):
    """There is no open loan with this id."""
```

### `src/choir/adapters/postgres.py`

```python
"""Which singer has which score."""

from uuid import UUID

import asyncpg

from choir.domain.errors import NoOpenLoanError, ScoreOnLoanError


class LoanRepo:
    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn

    async def lend(self, loan_id: UUID, score: str, singer: str) -> None:
        try:
            await self._conn.execute(
                "INSERT INTO loans (id, score, singer) VALUES ($1, $2, $3)", loan_id, score, singer)
        except asyncpg.UniqueViolationError as exc:
            if exc.constraint_name != "loans_one_open_per_score":
                raise
            raise ScoreOnLoanError(score) from exc

    async def give_back(self, loan_id: UUID) -> None:
        status = await self._conn.execute(
            "UPDATE loans SET returned = true WHERE id = $1 AND NOT returned", loan_id)
        if status == "UPDATE 0":
            raise NoOpenLoanError(loan_id)

    async def holder(self, score: str) -> str | None:
        return await self._conn.fetchval(
            "SELECT singer FROM loans WHERE score = $1 AND NOT returned", score)
```

### `tests/integration/adapters/test_postgres.py`

```python
"""LoanRepo against the real engine. Isolation: rollback (the default)."""

import asyncpg
import pytest

from choir.adapters.postgres import LoanRepo
from choir.domain.errors import NoOpenLoanError, ScoreOnLoanError


async def test_lend_then_give_back_frees_the_score(db, test_id):
    repo = LoanRepo(db)
    loan = test_id("loan")

    await repo.lend(loan, "Faure Requiem", "Ines")
    assert await repo.holder("Faure Requiem") == "Ines"

    await repo.give_back(loan)
    assert await repo.holder("Faure Requiem") is None
    with pytest.raises(NoOpenLoanError):
        await repo.give_back(loan)


async def test_a_score_already_out_is_refused_and_the_first_loan_stands(db, test_id):
    repo = LoanRepo(db)
    await repo.lend(test_id("first"), "Messiah", "Ines")

    # A savepoint: the expected database error must not abort the test's transaction.
    with pytest.raises(ScoreOnLoanError):
        async with db.transaction():
            await repo.lend(test_id("second"), "Messiah", "Oto")

    assert await repo.holder("Messiah") == "Ines"


async def test_reusing_a_loan_id_is_not_reported_as_on_loan(db, test_id):
    repo = LoanRepo(db)
    await repo.lend(test_id("loan"), "Elijah", "Ines")

    with pytest.raises(asyncpg.UniqueViolationError):
        async with db.transaction():
            await repo.lend(test_id("loan"), "Creation", "Oto")
```

### `tests/integration/test_migrations.py`

```python
"""Migration round trip. Its own database: the test changes the schema.
A synchronous test, because env.py calls asyncio.run."""


def test_migrations_go_down_and_up_again(postgres_server, own_database):
    def loans_exists() -> bool:
        return postgres_server.run(own_database, "SELECT to_regclass('loans') IS NOT NULL AS ok")[0]["ok"]

    assert loans_exists()
    postgres_server.migrate(own_database, "base", down=True)
    assert not loans_exists()
    postgres_server.migrate(own_database)
    assert loans_exists()
```

## Output

```text
$ pytest -v
tests/integration/adapters/test_postgres.py::test_lend_then_give_back_frees_the_score PASSED
tests/integration/adapters/test_postgres.py::test_a_score_already_out_is_refused_and_the_first_loan_stands PASSED
tests/integration/adapters/test_postgres.py::test_reusing_a_loan_id_is_not_reported_as_on_loan PASSED
tests/integration/test_migrations.py::test_migrations_go_down_and_up_again PASSED
4 passed
```

## Coverage, as measured

`check-python-coverage.sh --source src/choir` (`python-unit-test`) on this full suite: 4 ran, 0 skipped; line coverage 21/21 statements; branch coverage 4/4 branches; exit 0. Test support under `tests/integration/` (`harness.py`, `conftest.py`) is outside the measured source; the report lists it as test support.

## Broken on purpose

Each change was made in a copy, run, and reverted.

| Broken | Observed |
|---|---|
| Repository stops translating the constraint error | `UniqueViolationError: ... "loans_one_open_per_score"`; the refusal test fails |
| `downgrade()` does nothing | The migration test fails: the table is still there |
| `pytest -m "not integration"` | `4 deselected`, no container started, exit 5 because nothing else exists |

## Open points

None for the product owner. Not run: Ryuk (disabled for this run), any CI runner, a unit suite.
