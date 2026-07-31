# Aggregation, Multi-Document Transactions, and Index Creation — Full Worked Standard

The three mechanics the SKILL.md body points to, in Python against the async `motor` driver: building an aggregation pipeline and decoding it into a domain Read Model, opening a multi-document transaction only when it earns its cost, and creating indexes idempotently at startup. Plus the dict-backed `FakeRepository` and the integration-test note. Everything uses real `motor` / `pymongo` API surface — no invented names.

---

## 1. Aggregation Pipeline from Python

An aggregation pipeline is an ordered list of stages, each transforming the document stream. In Python it is a plain `list[dict]` — one `dict` per stage, in order. Build it in the repository, run it with `collection.aggregate(pipeline)`, decode the cursor, and return a domain Read Model. Never leak a pipeline stage or a raw `dict` upward.

### Stage vocabulary (real MongoDB stages)

| Stage | Purpose |
|---|---|
| `$match` | Filter the stream — put it **first** and on an indexed field so the pipeline scans as few documents as possible. |
| `$group` | Aggregate — `$sum`, `$avg`, `$push`, `$addToSet`, grouped by `_id`. |
| `$lookup` | Left-outer join into another collection — the exception, not the norm. |
| `$project` / `$addFields` | Reshape — include/exclude fields, compute new ones. |
| `$sort` | Order the stream (backed by an index where possible). |
| `$unwind` | Flatten an array field into one document per element. |
| `$facet` | Run several sub-pipelines over the same input in one pass. |

### Worked example — sensitivity counts per source, tenant-scoped

The Read Model is a `@dataclass` (or Pydantic model) — a domain type, never a `dict`.

```python
from dataclasses import dataclass

from infrastructure.mongodb.tenant import _tenant_id


@dataclass(frozen=True)
class SensitivityCount:
    source_id: str
    sensitivity: str
    count: int


async def count_by_sensitivity(self) -> list[SensitivityCount]:
    pipeline = [
        # $match FIRST, tenant-scoped, on an indexed field.
        {"$match": {
            "tenantId": _tenant_id().hex,
            "deletedAt": {"$exists": False},
        }},
        # $group by source + sensitivity, counting.
        {"$group": {
            "_id": {"sourceId": "$sourceId", "sensitivity": "$sensitivity"},
            "count": {"$sum": 1},
        }},
        # $sort for a stable Read Model.
        {"$sort": {"count": -1}},
    ]

    cursor = self._col.aggregate(pipeline)
    rows = await cursor.to_list(length=None)     # materialize the cursor
    return [
        SensitivityCount(
            source_id=r["_id"]["sourceId"],
            sensitivity=r["_id"]["sensitivity"],
            count=r["count"],
        )
        for r in rows
    ]
```

**Rules.** `$match` first, always on an indexed field; verify every pipeline with `explain()` in review and refuse a collection scan. Keep the pipeline entirely inside the repository. Map the raw `dict` rows into a typed Read Model (`list[SensitivityCount]`) at the package edge — a `dict` never escapes. A `$lookup`-heavy pipeline is the signal the workload is join-shaped and might belong in Postgres (`document-data-modeling`).

`collection.aggregate(...)` returns an `AsyncIOMotorCommandCursor`; `to_list(length=None)` drains it in one round-trip, or `async for row in cursor:` streams it. Pass `allowDiskUse=True` only for a genuinely large `$group`/`$sort` that legitimately exceeds the in-memory stage limit.

---

## 2. Multi-Document Transactions

Single-document writes are already atomic, so most repositories never open a transaction. When two documents (or two collections) genuinely must commit together, use a session and `session.with_transaction(callback)`, which runs the callback under snapshot isolation and **retries the whole callback automatically** on a transient error. The transaction boundary is the *application layer's* — a repository method never calls `start_session`.

### Cost — why this is a targeted tool, not a default

- Added latency and lock contention versus a plain write.
- A **60-second default transaction runtime limit** (`transactionLifetimeLimitSeconds`) — long work inside a transaction aborts.
- Requires a **replica set** (transactions are not available on a standalone `mongod`).
- Needing one *frequently* means the Aggregate boundaries are drawn wrong — fix the documents first.

### Worked example — application-layer command handler

The handler owns the session; both repository calls receive the *session-bound* context so their writes join the same transaction. The `motor` idiom is `session.with_transaction(coro)`.

```python
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorClientSession
from pymongo.read_concern import ReadConcern
from pymongo.write_concern import WriteConcern


class ReclassifyHandler:
    def __init__(self, client: AsyncIOMotorClient, assets, audit) -> None:
        self._client = client
        self._assets = assets
        self._audit = audit

    async def handle(self, cmd) -> None:
        async with await self._client.start_session() as session:

            async def _txn(s: AsyncIOMotorClientSession) -> None:
                # Both repository calls take the session, so their writes commit
                # atomically. Raising inside the callback aborts and rolls back.
                await self._assets.save_in_session(cmd.asset, session=s)
                await self._audit.append_in_session(cmd.audit_entry, session=s)

            await session.with_transaction(
                _txn,
                read_concern=ReadConcern("snapshot"),   # snapshot isolation
                write_concern=WriteConcern("majority"),  # durable commit
            )
```

The repository methods accept the `session` and pass it through to each motor call (`update_one(filter, update, session=s)`), so no repository code decides whether it is inside a transaction — exactly how `python-repository-pattern`'s adapter takes a caller-supplied `conn` and stays transaction-agnostic. `w="majority"` + read concern `snapshot` is the standard transaction concern pairing. `with_transaction` retries the callback on `TransientTransactionError` / `UnknownTransactionCommitResult` labels until it commits or the deadline passes.

---

## 3. Index Creation at Startup

MongoDB has no migration DDL — there is no `ALTER TABLE`, so index creation is Python code that runs idempotently on service boot (`python-migration` owns the Postgres migration story; this is the document-store equivalent). `create_indexes` is idempotent: re-creating an index with the same key spec and name is a no-op.

### The ESR rule

Compound-index field order follows **Equality, Sort, Range**: equality-matched fields first, then the field you sort on, then range-matched fields. `tenantId` is always the leading equality field, both for query performance and as the physical expression of tenant scoping.

### Worked example — `indexes.py`

```python
from motor.motor_asyncio import AsyncIOMotorCollection
from pymongo import ASCENDING, IndexModel


async def ensure_indexes(col: AsyncIOMotorCollection) -> None:
    models = [
        # Unique identity per tenant — makes a racing double-insert a DuplicateKeyError.
        IndexModel(
            [("tenantId", ASCENDING), ("assetId", ASCENDING)],
            name="uq_tenant_asset",
            unique=True,
        ),
        # ESR: Equality (tenantId, sensitivity) then Sort (assetId) for list_by_sensitivity.
        IndexModel(
            [("tenantId", ASCENDING), ("sensitivity", ASCENDING), ("assetId", ASCENDING)],
            name="ix_tenant_sensitivity_asset",
        ),
        # Partial index excluding soft-deleted docs — keeps the live-set index small.
        IndexModel(
            [("tenantId", ASCENDING), ("sourceId", ASCENDING)],
            name="ix_tenant_source_live",
            partialFilterExpression={"deletedAt": {"$exists": False}},
        ),
        # TTL index — MongoDB auto-expires ephemeral docs at their own expiresAt value.
        IndexModel(
            [("expiresAt", ASCENDING)],
            name="ttl_expires",
            expireAfterSeconds=0,
        ),
    ]
    await col.create_indexes(models)
```

`expireAfterSeconds=0` with a per-document `expiresAt` date makes each document expire *at* the value in its own field — the native fit for ephemeral scan results, cached extractions, or an expiring audit window, so cleanup is the database's job, not a cron. Call `ensure_indexes` once per collection at startup, after the `ping` succeeds and before the service accepts traffic (e.g. from FastAPI's `lifespan` startup).

---

## 4. The dict-backed `FakeRepository`

The port exists primarily for this fake. Backed by a plain `dict` keyed by `assetId`, it is a real, working implementation of the same Protocol — asserted against by **state and outcome**, never by mock call-expectations (Cosmic Python's fakes-over-mocks discipline). It makes the entire service layer unit-testable with no MongoDB, no `testcontainers`, no event loop bound to a socket.

```python
from uuid import UUID

from domain.data_asset import DataAsset, SensitivityLevel
from domain.errors import ConcurrentModificationError


class FakeDataAssetRepository:
    """In-memory stand-in for MongoDataAssetRepo. Same Protocol; mypy checks it."""

    def __init__(self) -> None:
        self._store: dict[str, DataAsset] = {}

    async def get(self, asset_id: UUID) -> DataAsset | None:
        return self._store.get(str(asset_id))     # a miss is None — same contract as motor

    async def save(self, asset: DataAsset) -> None:
        existing = self._store.get(str(asset.id))
        if existing is not None and existing.version != asset.version:
            raise ConcurrentModificationError      # mirror the real CAS behaviour
        self._store[str(asset.id)] = asset

    async def list_by_sensitivity(self, level: SensitivityLevel) -> list[DataAsset]:
        return [a for a in self._store.values() if a.sensitivity == level]
```

The fake mirrors the two contracts that matter to callers: a miss returns `None` (not an exception, matching motor's `find_one`), and a stale-version `save` raises `ConcurrentModificationError` (matching the real CAS). `mypy` type-checks the fake against `DataAssetRepository` in CI, so it cannot silently drift from the real adapter's method set.

---

## 5. Integration-Test Note

The real adapter is a Humble Object — thin wrapper code verified against a real MongoDB via `testcontainers-python`, not unit-tested with a mocked driver (`python-integration-test` owns the harness; this is what a repository test drives). A `pytest-asyncio` fixture spins up the container, ensures indexes, sets the tenant `ContextVar`, and hands back the repository.

```python
import pytest
import pytest_asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from testcontainers.mongodb import MongoDbContainer

from infrastructure.mongodb.dataasset_repo import MongoDataAssetRepo
from infrastructure.mongodb.indexes import ensure_indexes
from infrastructure.mongodb.tenant import _tenant_ctx
from uuid import uuid4


@pytest_asyncio.fixture
async def repo():
    with MongoDbContainer("mongo:7") as container:
        client = AsyncIOMotorClient(container.get_connection_url())
        db = client["test"]
        await ensure_indexes(db["data_assets"])
        _tenant_ctx.set(uuid4())               # satisfy _tenant_id()
        yield MongoDataAssetRepo(db)
        client.close()
```

What such tests must exercise (real behavior, not mocks): a `get` miss returns `None` (proving the not-found contract); a second insert of the same `{tenantId, assetId}` raises `ConflictError` (proving the `DuplicateKeyError` translation against the real unique index); a stale-version `save` raises `ConcurrentModificationError` (proving the CAS); an aggregation returns the expected typed Read Model; and a filter for one tenant never returns another tenant's documents (proving tenant scoping). Transactions need a replica set — the single-node container must be started as a one-node replica set for `with_transaction` tests to run.
