# Enterprise: Parcel Lockers Shared by Several Carriers

The product's tenancy design (assumed here, and only here): carriers share one table, isolated by PostgreSQL row-level security; the service connects as a role subject to it, and the repository also filters by carrier. Couriers claim compartments concurrently. A new column ships while the previous release is running.

Run on 2026-11-27: Python 3.14.4, testcontainers 4.15.0, asyncpg 0.32.0, Alembic 1.20.1, SQLAlchemy 2.1.9, pytest 9.2.0, pytest-asyncio 1.5.0, `postgres:17.12-alpine`.

## Plan

| Behaviour | Isolation and reason |
|---|---|
| A carrier cannot read or collect another's parcel **through the product's repository** | Rollback, as `parcel_app` |
| The policy itself refuses reads, changes and forged inserts; no setting sees nothing | Rollback, as `parcel_app`, statements without a carrier filter |
| Superuser bypasses the policy (guard) | Rollback |
| Two claims on one compartment | Real commit, own database: two connections, lock view |
| Previous release works on the new schema | Own database |

## Production code

Harness files copied unchanged. Unit tests for `domain/` are under `tests/unit/` (not shown).

### `migrations/versions/0001_create_parcels.py`

```python
"""create parcels

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
        "CREATE TABLE parcels (id uuid PRIMARY KEY, carrier_id uuid NOT NULL, "
        "compartment text NOT NULL, state text NOT NULL)"
    )
    op.execute(
        "CREATE UNIQUE INDEX parcels_one_waiting_per_compartment ON parcels (compartment) "
        "WHERE state = 'waiting'"
    )


def downgrade() -> None:
    op.execute("DROP TABLE parcels")
```

### `migrations/versions/0002_isolate_carriers.py`

```python
"""row-level security per carrier

Revision ID: 0002
Revises: 0001
"""
from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Roles belong to the server, not to one database: create only if missing.
    op.execute(
        "DO $$ BEGIN CREATE ROLE parcel_app NOLOGIN; "
        "EXCEPTION WHEN duplicate_object OR unique_violation THEN NULL; END $$"
    )
    op.execute("GRANT SELECT, INSERT, UPDATE ON parcels TO parcel_app")
    op.execute("ALTER TABLE parcels ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE parcels FORCE ROW LEVEL SECURITY")
    op.execute(
        "CREATE POLICY own_carrier ON parcels "
        "USING (carrier_id = NULLIF(current_setting('app.carrier', true), '')::uuid) "
        "WITH CHECK (carrier_id = NULLIF(current_setting('app.carrier', true), '')::uuid)"
    )


def downgrade() -> None:
    op.execute("DROP POLICY own_carrier ON parcels")
    op.execute("ALTER TABLE parcels NO FORCE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE parcels DISABLE ROW LEVEL SECURITY")
    op.execute("REVOKE SELECT, INSERT, UPDATE ON parcels FROM parcel_app")
```

### `migrations/versions/0003_add_size_code.py`

```python
"""expand step: nullable, so the release already running can still insert

Revision ID: 0003
Revises: 0002
"""
from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE parcels ADD COLUMN size_code text")


def downgrade() -> None:
    op.execute("ALTER TABLE parcels DROP COLUMN size_code")
```

### `src/lockers/domain/context.py`

```python
"""The carrier of the current request or message."""

from contextvars import ContextVar
from uuid import UUID

current_carrier: ContextVar[UUID] = ContextVar("current_carrier")
```

### `src/lockers/domain/errors.py`

```python
class ParcelNotFoundError(Exception):
    """No waiting or visible parcel has this id."""


class CompartmentOccupiedError(Exception):
    """The compartment already holds a waiting parcel."""
```

### `src/lockers/adapters/postgres.py`

```python
"""Parcels for several carriers in one table. The carrier filter is the backstop;
PostgreSQL row-level security is the isolation."""

from dataclasses import dataclass
from uuid import UUID

import asyncpg

from lockers.domain.context import current_carrier
from lockers.domain.errors import CompartmentOccupiedError, ParcelNotFoundError


@dataclass(frozen=True)
class Parcel:
    id: UUID
    compartment: str
    size: str | None = None  # None for rows written before size codes existed


class ParcelRepo:
    """Needs the caller's transaction and a connection subject to row-level security."""

    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn

    async def _carrier(self) -> UUID:
        if not self._conn.is_in_transaction():
            raise RuntimeError("the caller's transaction is required")
        carrier = current_carrier.get()  # unset raises: never an unscoped query
        await self._conn.execute("SELECT set_config('app.carrier', $1, true)", str(carrier))
        return carrier

    async def place(self, parcel: Parcel) -> None:
        carrier = await self._carrier()
        try:
            await self._conn.execute(
                "INSERT INTO parcels (id, carrier_id, compartment, state, size_code) "
                "VALUES ($1, $2, $3, 'waiting', $4)",
                parcel.id, carrier, parcel.compartment, parcel.size)
        except asyncpg.UniqueViolationError as exc:
            if exc.constraint_name != "parcels_one_waiting_per_compartment":
                raise
            raise CompartmentOccupiedError(parcel.compartment) from exc

    async def find(self, parcel_id: UUID) -> Parcel:
        carrier = await self._carrier()
        row = await self._conn.fetchrow(
            "SELECT id, compartment, size_code AS size FROM parcels "
            "WHERE id = $1 AND carrier_id = $2", parcel_id, carrier)
        if row is None:
            raise ParcelNotFoundError(parcel_id)
        return Parcel(**dict(row))

    async def collect(self, parcel_id: UUID) -> None:
        carrier = await self._carrier()
        status = await self._conn.execute(
            "UPDATE parcels SET state = 'collected' "
            "WHERE id = $1 AND carrier_id = $2 AND state = 'waiting'", parcel_id, carrier)
        if status == "UPDATE 0":
            raise ParcelNotFoundError(parcel_id)
```

## Tests

### `tests/integration/adapters/test_postgres.py`

```python
"""Tenant isolation through the product's repository and through the policy itself.

Isolation: rollback, as the application role. The concurrency test commits.
"""

import asyncio
from contextlib import contextmanager

import asyncpg
import pytest

from lockers.adapters.postgres import Parcel, ParcelRepo
from lockers.domain.context import current_carrier
from lockers.domain.errors import CompartmentOccupiedError, ParcelNotFoundError
from tests.integration.harness import poll_until


@contextmanager
def acting_as(carrier):
    token = current_carrier.set(carrier)
    try:
        yield
    finally:
        current_carrier.reset(token)


@pytest.fixture
async def app_db(db):
    """The test's transaction, as the role production connects with. A superuser,
    which the container's user is, bypasses row-level security."""
    await db.execute("SET LOCAL ROLE parcel_app")
    return db


@pytest.fixture
async def two_parcels(app_db, test_id):
    """Carrier A and carrier B each place one parcel through the product's code."""
    repo, placed = ParcelRepo(app_db), {}
    for name, compartment in (("a", "c1"), ("b", "c2")):
        carrier, parcel = test_id(f"carrier-{name}"), test_id(f"parcel-{name}")
        with acting_as(carrier):
            async with app_db.transaction():
                await repo.place(Parcel(parcel, compartment))
        placed[name] = (carrier, parcel)
    return placed


async def test_each_carrier_reads_and_collects_only_its_own(app_db, two_parcels):
    repo = ParcelRepo(app_db)
    for own, other in (("a", "b"), ("b", "a")):
        carrier, mine = two_parcels[own]
        theirs = two_parcels[other][1]
        with acting_as(carrier):
            assert (await repo.find(mine)).id == mine  # an allowed read, so refusal means something
            with pytest.raises(ParcelNotFoundError):
                await repo.find(theirs)
            with pytest.raises(ParcelNotFoundError):
                await repo.collect(theirs)
    carrier_b, parcel_b = two_parcels["b"]
    with acting_as(carrier_b):
        await repo.collect(parcel_b)  # still waiting: A changed nothing


async def test_the_policy_itself_refuses_another_carrier(app_db, two_parcels, test_id):
    """No carrier filter in these statements, so only row-level security protects the rows."""
    (carrier_a, parcel_a), (carrier_b, parcel_b) = two_parcels["a"], two_parcels["b"]
    await app_db.execute("SELECT set_config('app.carrier', $1, true)", str(carrier_a))

    visible = [r["id"] for r in await app_db.fetch("SELECT id FROM parcels")]
    assert visible == [parcel_a]
    assert await app_db.execute("UPDATE parcels SET state = 'collected' WHERE id = $1", parcel_b) == "UPDATE 0"
    with pytest.raises(asyncpg.InsufficientPrivilegeError):
        async with app_db.transaction():
            await app_db.execute(
                "INSERT INTO parcels (id, carrier_id, compartment, state) VALUES ($1, $2, 'c3', 'waiting')",
                test_id("forged"), carrier_b)
    # set_config(..., true) outlives a released savepoint: clear it before this check.
    await app_db.execute("SELECT set_config('app.carrier', '', true)")
    assert await app_db.fetch("SELECT id FROM parcels") == []


async def test_a_superuser_bypasses_the_policy(db, test_id):
    """Guard: why the role switch is there."""
    with acting_as(test_id("carrier-a")):
        async with db.transaction():
            await ParcelRepo(db).place(Parcel(test_id("parcel"), "c9"))
    await db.execute("SELECT set_config('app.carrier', $1, true)", str(test_id("carrier-b")))

    assert await db.fetchval("SELECT count(*) FROM parcels WHERE id = $1", test_id("parcel")) == 1


async def test_two_claims_on_one_compartment_leave_one_parcel(postgres_server, own_database, test_id):
    """Real commit: two connections must contend. Own database: it watches the lock view."""
    first, second, watcher = [
        await asyncpg.connect(postgres_server.url(own_database)) for _ in range(3)]
    try:
        await first.execute("SET ROLE parcel_app")
        await second.execute("SET ROLE parcel_app")

        async def claim(conn, label):
            with acting_as(test_id(f"carrier-{label}")):
                async with conn.transaction():
                    await ParcelRepo(conn).place(Parcel(test_id(f"parcel-{label}"), "c1"))

        holding = first.transaction()
        await holding.start()
        await claim(first, "a")  # a savepoint inside `holding`: not yet committed
        contender = asyncio.create_task(claim(second, "b"))

        async def blocked():
            return await watcher.fetchval(
                "SELECT count(*) FROM pg_stat_activity "
                "WHERE datname = current_database() AND wait_event_type = 'Lock'")

        await poll_until(blocked, "second claim waiting on the first", watching=contender)
        await holding.commit()

        async with asyncio.timeout(15):
            with pytest.raises(CompartmentOccupiedError):
                await contender
        rows = await watcher.fetch("SELECT id FROM parcels")
        assert [r["id"] for r in rows] == [test_id("parcel-a")]
    finally:
        for conn in (first, second, watcher):
            await conn.close(timeout=5)


async def test_a_call_outside_a_transaction_is_refused(postgres_server, test_id):
    conn = await asyncpg.connect(postgres_server.url())
    try:
        with acting_as(test_id("carrier")), pytest.raises(RuntimeError, match="transaction"):
            await ParcelRepo(conn).find(test_id("parcel"))
    finally:
        await conn.close()


async def test_a_reused_parcel_id_is_not_reported_as_occupied(app_db, test_id):
    repo = ParcelRepo(app_db)
    with acting_as(test_id("carrier")):
        async with app_db.transaction():
            await repo.place(Parcel(test_id("parcel"), "c4"))
        with pytest.raises(asyncpg.UniqueViolationError):
            async with app_db.transaction():
                await repo.place(Parcel(test_id("parcel"), "c5"))
```

### `tests/integration/test_migrations.py`

```python
"""The release now in production keeps working on the new schema, because migration
and rollout do not happen at one instant. Own database; synchronous test (env.py
calls asyncio.run)."""

import asyncio

import asyncpg

from lockers.adapters.postgres import Parcel, ParcelRepo
from lockers.domain.context import current_carrier

# Copied from the release now in production. Do not update them with the code.
PREVIOUS_INSERT = "INSERT INTO parcels (id, carrier_id, compartment, state) VALUES ($1, $2, $3, 'waiting')"
PREVIOUS_READ = "SELECT id, compartment FROM parcels WHERE id = $1 AND carrier_id = $2"


def test_size_code_keeps_the_previous_release_working(postgres_server, own_database, test_id):
    carrier = test_id("carrier")

    def on_database(work):
        async def go():
            conn = await asyncpg.connect(postgres_server.url(own_database))
            try:
                async with conn.transaction():
                    await conn.execute("SET LOCAL ROLE parcel_app")
                    await conn.execute("SELECT set_config('app.carrier', $1, true)", str(carrier))
                    return await work(conn)
            finally:
                await conn.close()
        return asyncio.run(go())

    def previous_release(label, compartment):
        async def work(conn):
            await conn.execute(PREVIOUS_INSERT, test_id(label), carrier, compartment)
            return await conn.fetchrow(PREVIOUS_READ, test_id(label), carrier)
        assert on_database(work)["compartment"] == compartment

    postgres_server.migrate(own_database, "0002", down=True)
    previous_release("before", "c1")  # seeded before the migration: the table is not empty

    postgres_server.migrate(own_database)
    previous_release("after", "c2")

    async def new_release(conn):
        repo = ParcelRepo(conn)
        token = current_carrier.set(carrier)
        try:
            await repo.place(Parcel(test_id("sized"), "c3", "M"))
            return await repo.find(test_id("before")), await repo.find(test_id("sized"))
        finally:
            current_carrier.reset(token)

    old, sized = on_database(new_release)
    assert old == Parcel(test_id("before"), "c1", None)
    assert sized == Parcel(test_id("sized"), "c3", "M")


def test_every_migration_goes_down_and_up_again(postgres_server, own_database):
    def exists() -> bool:
        return postgres_server.run(own_database, "SELECT to_regclass('parcels') IS NOT NULL AS ok")[0]["ok"]

    postgres_server.migrate(own_database, "base", down=True)
    assert not exists()
    postgres_server.migrate(own_database)
    assert exists()
```

## Output

```text
$ pytest -v
tests/integration/adapters/test_postgres.py::test_each_carrier_reads_and_collects_only_its_own PASSED
tests/integration/adapters/test_postgres.py::test_the_policy_itself_refuses_another_carrier PASSED
tests/integration/adapters/test_postgres.py::test_a_superuser_bypasses_the_policy PASSED
tests/integration/adapters/test_postgres.py::test_two_claims_on_one_compartment_leave_one_parcel PASSED
tests/integration/adapters/test_postgres.py::test_a_call_outside_a_transaction_is_refused PASSED
tests/integration/adapters/test_postgres.py::test_a_reused_parcel_id_is_not_reported_as_occupied PASSED
tests/integration/test_migrations.py::test_size_code_keeps_the_previous_release_working PASSED
tests/integration/test_migrations.py::test_every_migration_goes_down_and_up_again PASSED
8 passed
```

## Broken on purpose

Each change was made in a copy, run, and reverted.

| Broken | Observed |
|---|---|
| Carrier filter removed from the repository, policy kept | All passed: the policy still holds |
| Policy opened to `USING (true) WITH CHECK (true)`, filter kept | Only the policy test failed: the filter hides the hole from the repository test |
| Both removed | Both isolation tests failed (`DID NOT RAISE ParcelNotFoundError`) |
| Role switch removed from `app_db` | The policy test failed |
| Unique index made non-unique | The concurrent claim test failed |
| New column `NOT NULL` with no default | The upgrade failed on the seeded row: `column "size_code" ... contains null values` |

So the two layers need two tests: one through the product's code, one through the policy.

## Coverage and open points

Full gate run (`--source src/lockers`): 8 ran, 0 skipped; line coverage 41/41; branch coverage 8/8; exit 0. The report lists `tests/integration/` support files as test support.

**For the product owner:** confirmation of the tenancy design and of who may bypass row-level security (support, reporting, migrations); the release that makes `size_code` required.

Unproven here: the production login's actual role membership (check it against the deployed environment), lock time of the migration on a large table, several regions, parallel CI shards. A sharded run gives no coverage verdict; the gate runs the full suite. Not run: Ryuk (disabled), CI.
