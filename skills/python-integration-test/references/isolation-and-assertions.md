# Isolation and Assertions — Rollback vs Fresh-Tenant, Worked Round-Trips

Reference for `python-integration-test`. Loaded only when the SKILL body points
here. Self-contained: the per-test rollback fixture and its asyncpg SAVEPOINT
mechanics, the fresh-tenant exception, and three worked integration tests —
repository (CAS + real end-state read-back), outbox (atomicity), and idempotent
consumer (aiokafka publish → poll → redeliver) — plus the tenant-isolation
assertion under physical multi-tenancy.

Assumes the session fixtures from `testcontainers-setup.md` (`pg_pool`,
`bootstrap_servers`) are in scope.

---

## 1. Strategy comparison

| Strategy | Cost | Use when | Cost paid |
|---|---|---|---|
| **Per-test transaction rollback** (default) | microseconds | the code under test does not itself depend on a real COMMIT being visible elsewhere | outer transaction never commits; teardown rolls back |
| **Fresh-tenant, real commit** (exception) | milliseconds | the *subject* is commit/boundary behavior — outbox relay polling, real CAS race across connections, consumer over a committed message | teardown deletes only that tenant's rows |
| Truncate-all-tables per test | milliseconds | avoid — leaks between xdist workers sharing a container, and re-runs no migration | — |
| Fresh container per test | seconds | never — startup dominates runtime | — |

---

## 2. Per-test rollback fixture — the asyncpg SAVEPOINT mechanic

The fixture acquires one connection, opens an **outer** `conn.transaction()` it
**never commits**, and yields that same `conn`. The repository under test opens
its own `async with conn.transaction()` — on an asyncpg connection already inside
a transaction, that inner block is emitted as a **SAVEPOINT**, so the
repository's "commit" only *releases the savepoint*; the outer rollback in
teardown still discards every write. The repository code is exercised verbatim,
yet nothing survives the test.

```python
# tests/integration/conftest.py
import pytest_asyncio


@pytest_asyncio.fixture
async def conn(pg_pool):
    """A connection wrapped in a never-committed outer transaction.

    The repository's inner conn.transaction() nests as a SAVEPOINT, so its commit
    only releases the savepoint; teardown's rollback discards everything.
    """
    async with pg_pool.acquire() as connection:
        tx = connection.transaction()
        await tx.start()
        try:
            yield connection
        finally:
            await tx.rollback()   # discards the whole test's writes, savepoints and all
```

Because asyncpg binds a connection to the running loop, this function-scoped
fixture acquires on the loop the test runs on — do not cache a connection across
tests or loops.

---

## 3. Fresh-tenant fixture — the real-commit exception

Under physical per-tenant isolation, a unique `tenant_id` per test both scopes a
real-commit test and provides the tenant-isolation seed. Teardown deletes only
that tenant's rows, so a real commit leaves the shared container clean.

```python
# tests/integration/conftest.py  (continued)
import uuid
import pytest_asyncio


@pytest_asyncio.fixture
async def fresh_tenant(pg_pool):
    """A unique tenant_id for a REAL-commit test; teardown deletes only its rows."""
    tenant_id = uuid.uuid4()
    yield tenant_id
    async with pg_pool.acquire() as c:
        # Order matters: children before parents under FK constraints.
        await c.execute("DELETE FROM outbox WHERE tenant_id = $1", tenant_id)
        await c.execute("DELETE FROM data_assets WHERE tenant_id = $1", tenant_id)
        await c.execute("DELETE FROM processed_messages WHERE tenant_id = $1", tenant_id)
```

---

## 4. Worked repository test — CAS + real end-state read-back (rollback path)

```python
# tests/integration/test_dataasset_repo.py
import uuid
import pytest

from domain.dataasset import DataAsset
from domain.errors import ConcurrentModificationError
from infrastructure.postgres.dataasset_repo import DataAssetRepo

pytestmark = pytest.mark.integration


async def test_save_persists_real_columns_and_bumps_version(conn):
    tenant_id = uuid.uuid4()
    repo = DataAssetRepo(conn)
    asset = DataAsset.create(tenant_id=tenant_id, name="quarterly.xlsx", source="s3")

    async with conn.transaction():          # nests as a SAVEPOINT under the fixture's outer tx
        await repo.save(asset)

    # Read the real end-state back — not a mock's recorded call.
    row = await conn.fetchrow(
        "SELECT name, source, version FROM data_assets WHERE id = $1 AND tenant_id = $2",
        asset.id, tenant_id,
    )
    assert row["name"] == "quarterly.xlsx"
    assert row["source"] == "s3"
    assert row["version"] == 1


async def test_stale_version_save_raises_concurrent_modification(conn):
    tenant_id = uuid.uuid4()
    repo = DataAssetRepo(conn)
    asset = DataAsset.create(tenant_id=tenant_id, name="a.pdf", source="gdrive")
    async with conn.transaction():
        await repo.save(asset)

    # Two reconstituted copies at the same version — a real CAS race.
    first = await repo.get(asset.id, tenant_id)
    second = await repo.get(asset.id, tenant_id)
    first.rename("a-v2.pdf")
    async with conn.transaction():
        await repo.save(first)              # version 1 -> 2, wins

    second.rename("a-loser.pdf")            # still holds stale version 1
    with pytest.raises(ConcurrentModificationError):
        async with conn.transaction():
            await repo.save(second)         # CAS WHERE version = 1 matches 0 rows
```

The stale-version case proves the CAS predicate actually conflicts on the real
engine — a fake with a Python `dict` cannot exercise the `WHERE ... AND version =
$N` row-count-zero path.

---

## 5. Worked outbox test — atomicity (rollback path)

```python
# tests/integration/test_dataasset_repo.py  (continued)
async def test_save_writes_outbox_row_in_the_same_transaction(conn):
    tenant_id = uuid.uuid4()
    repo = DataAssetRepo(conn)
    asset = DataAsset.create(tenant_id=tenant_id, name="ledger.csv", source="s3")

    async with conn.transaction():
        await repo.save(asset)              # UPDATE + outbox INSERT, one transaction

    rows = await conn.fetch(
        "SELECT event_type, payload FROM outbox "
        "WHERE tenant_id = $1 AND published_at IS NULL",
        tenant_id,
    )
    assert len(rows) == 1                   # exactly one un-relayed event
    assert rows[0]["event_type"] == "DataAssetRegistered"
```

Reading the outbox on the **same** connection (inside the fixture's outer
transaction) proves the outbox INSERT is atomic with the state UPDATE — both are
visible together, both would vanish together on rollback.

---

## 6. Worked consumer test — publish → poll → redeliver → idempotency (fresh-tenant path)

The consumer path needs a **real commit**: the message must genuinely land in
Redpanda and the consumer must genuinely write its projection, so this uses
`fresh_tenant`, not the rollback fixture. Idempotency is proven by redelivering
the *same* message key/offset and asserting the effect happened exactly once.

```python
# tests/integration/test_event_consumer.py
import json
import uuid
import pytest
from aiokafka import AIOKafkaProducer

from infrastructure.consumer.dataasset_consumer import DataAssetConsumer
from tests.integration._poll import poll_until

pytestmark = pytest.mark.integration


async def test_consumer_projects_once_under_redelivery(pg_pool, bootstrap_servers, fresh_tenant):
    tenant_id = fresh_tenant
    asset_id = uuid.uuid4()
    message = {
        "message_id": str(uuid.uuid4()),     # the idempotency key
        "tenant_id": str(tenant_id),
        "asset_id": str(asset_id),
        "event_type": "DataAssetScanned",
    }
    encoded = json.dumps(message).encode()

    consumer = DataAssetConsumer(pool=pg_pool, bootstrap_servers=bootstrap_servers,
                                 topic="data-asset-events")
    await consumer.start()
    producer = AIOKafkaProducer(bootstrap_servers=bootstrap_servers)
    await producer.start()
    try:
        # First delivery.
        await producer.send_and_wait("data-asset-events", encoded, key=asset_id.bytes)

        async def projected():
            async with pg_pool.acquire() as c:
                return await c.fetchrow(
                    "SELECT scanned_at FROM data_asset_projections "
                    "WHERE asset_id = $1 AND tenant_id = $2",
                    asset_id, tenant_id,
                )

        first = await poll_until(projected, timeout=10)
        assert first is not None

        # Redeliver the SAME message_id — a real broker redelivery.
        await producer.send_and_wait("data-asset-events", encoded, key=asset_id.bytes)

        # Assert the effect happened ONCE: the processed-messages ledger has one row.
        async def ledger_count():
            async with pg_pool.acquire() as c:
                n = await c.fetchval(
                    "SELECT count(*) FROM processed_messages "
                    "WHERE message_id = $1 AND tenant_id = $2",
                    uuid.UUID(message["message_id"]), tenant_id,
                )
                return n if n >= 1 else None

        # Give the redelivery a real chance to (wrongly) double-process, then assert exactly one.
        await poll_until(ledger_count, timeout=5)
        async with pg_pool.acquire() as c:
            total = await c.fetchval(
                "SELECT count(*) FROM processed_messages "
                "WHERE message_id = $1 AND tenant_id = $2",
                uuid.UUID(message["message_id"]), tenant_id,
            )
        assert total == 1                    # dedup proven against a real broker
    finally:
        await producer.stop()
        await consumer.stop()
```

The consumer must record each `message_id` in a `processed_messages` ledger
inside the same transaction as its projection write (`python-event-consumer`);
this test proves that ledger actually dedups on a genuine redelivery, which a
mocked broker could only assume.

---

## 7. Tenant-isolation assertion under physical multi-tenancy

Even with physical per-tenant isolation, the application-layer `tenant_id`
filter is the backstop. Seed two tenants into the shared schema and assert a
tenant-scoped query returns exactly one tenant's rows.

```python
# tests/integration/test_dataasset_repo.py  (continued)
async def test_tenant_scoped_query_never_crosses_tenants(conn):
    tenant_a, tenant_b = uuid.uuid4(), uuid.uuid4()
    repo = DataAssetRepo(conn)
    async with conn.transaction():
        await repo.save(DataAsset.create(tenant_id=tenant_a, name="a.pdf", source="s3"))
        await repo.save(DataAsset.create(tenant_id=tenant_b, name="b.pdf", source="s3"))

    a_rows = await conn.fetch("SELECT id FROM data_assets WHERE tenant_id = $1", tenant_a)
    assert len(a_rows) == 1                  # tenant B's row is invisible to a tenant-A query
```

Run this on the rollback fixture: both tenants' rows vanish at teardown, and the
assertion still proves the `WHERE tenant_id = $1` predicate isolates correctly.
