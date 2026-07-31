# Motor Repository — Full Worked Standard

The complete Python repository the SKILL.md body summarizes: the `typing.Protocol` port, the dict-based bson mapping, CRUD with tenant scoping and CAS, the error-translation table, the `contextvars` tenant helper, and client construction. Every snippet uses the real async driver `motor.motor_asyncio` (which wraps `pymongo`) — `AsyncIOMotorClient`, `AsyncIOMotorDatabase`, `AsyncIOMotorCollection` — and real `pymongo` / `bson` API surface. No invented names.

---

## 1. The Domain Port (lives with the consumer)

The port is declared where it is *used*, in `domain/ports.py`, in domain vocabulary — it names no driver type. As a `typing.Protocol` the `motor` adapter satisfies it *structurally*: the adapter neither imports nor subclasses it.

```python
from typing import Protocol, runtime_checkable
from uuid import UUID

from domain.data_asset import DataAsset, SensitivityLevel


@runtime_checkable
class DataAssetRepository(Protocol):
    async def get(self, asset_id: UUID) -> DataAsset | None: ...
    async def save(self, asset: DataAsset) -> None: ...
    async def list_by_sensitivity(self, level: SensitivityLevel) -> list[DataAsset]: ...
```

`@runtime_checkable` lets a test assert `isinstance(repo, DataAssetRepository)`, but that check verifies only that the *method names* exist — not their signatures. **The real guarantee is `mypy` in CI.** This is the honest divergence from Go: Go's `var _ domain.DataAssetRepository = (*MongoRepo)(nil)` is a compile error the instant a method drifts; Python has no compile step, so the static type-check is a *required* gate (`python-tooling`), not optional.

---

## 2. The Persistence Mapping — Plain `dict`, Explicit Both Ways

`motor` reads and writes plain Python `dict` documents; there are no `bson` struct tags as in Go. The mapping is therefore manual and explicit, in two module-private functions kept beside the adapter. This is deliberate: an explicit mapping is the seam where `reconstitute`-on-decode is enforced.

```python
from datetime import datetime, timezone
from uuid import UUID

from domain.data_asset import DataAsset, SensitivityLevel

CURRENT_SCHEMA_VERSION = 1


def _to_doc(a: DataAsset) -> dict:
    return {
        "assetId": str(a.id),            # domain UUID as canonical string
        "tenantId": a.tenant_id.hex,     # leading field of every index and filter
        "sourceId": str(a.source_id),
        "sensitivity": a.sensitivity.value,
        "version": a.version,            # optimistic-concurrency token
        "schemaVersion": CURRENT_SCHEMA_VERSION,
    }


def _reconstitute(doc: dict) -> DataAsset:
    # Rebuild through reconstitute — NEVER DataAsset(...) / DataAsset.create.
    # The constructor re-runs invariant checks against data Mongo already
    # accepted and re-emits the creation Domain Event on every read.
    return DataAsset.reconstitute(
        asset_id=UUID(doc["assetId"]),
        tenant_id=UUID(doc["tenantId"]),
        source_id=UUID(doc["sourceId"]),
        sensitivity=SensitivityLevel(doc["sensitivity"]),
        version=doc["version"],
    )
```

| Field choice | Why |
|---|---|
| `_id` left unset | Let MongoDB assign its own `bson.ObjectId`; the domain identity lives in `assetId`, so `_id` is never mapped into the domain. |
| `assetId` as `str` | The domain identity is a `UUID`; store its canonical string so queries are human-readable and index-friendly. |
| `tenantId` first | Leading equality field of every compound index (ESR rule) and every filter. |
| `schemaVersion` | The handle-on-read migration hook — `document-data-modeling` owns the upgrade switch. |
| `version` | The CAS token compared in the `save` filter. |

Never leak a `dict`, a `bson.ObjectId`, or a cursor upward — the boundary is `_reconstitute`.

---

## 3. Constructor — Inject the Collection, Never the Client

```python
from motor.motor_asyncio import AsyncIOMotorDatabase, AsyncIOMotorCollection


class MongoDataAssetRepo:
    def __init__(self, db: AsyncIOMotorDatabase) -> None:
        self._col: AsyncIOMotorCollection = db["data_assets"]
```

The adapter holds one `AsyncIOMotorCollection` — never an `AsyncIOMotorClient`, never the `AsyncIOMotorDatabase` beyond `__init__`. A unit test can inject a fake collection; the concrete driver never appears in a method signature.

---

## 4. Tenant and Context Helpers

```python
import contextvars
from uuid import UUID

_tenant_ctx: contextvars.ContextVar[UUID] = contextvars.ContextVar("tenant_id")


def _tenant_id() -> UUID:
    """Pull the authenticated tenant from the request context. A missing tenant
    is a programming error (auth middleware did not run) — raise loudly here,
    never let it silently become a cross-tenant query."""
    try:
        return _tenant_ctx.get()
    except LookupError as exc:
        raise RuntimeError("tenant id missing from context — auth middleware did not run") from exc
```

A `contextvars.ContextVar` (not a module global) is the async-correct carrier: each request/task sees its own value even under `asyncio` interleaving.

---

## 5. Read — `get`, Tenant-Scoped, `None` on Miss

```python
from uuid import UUID

from domain.data_asset import DataAsset


async def get(self, asset_id: UUID) -> DataAsset | None:
    filter = {
        "tenantId": _tenant_id().hex,     # tenant first — defense in depth
        "assetId": str(asset_id),
        "deletedAt": {"$exists": False},
    }
    doc = await self._col.find_one(filter)
    if doc is None:
        return None                       # a miss is None, NOT an exception
    return _reconstitute(doc)             # reconstitute, never DataAsset(...)
```

**The `None`-on-miss divergence from Go, stated plainly.** Go's `col.FindOne(...).Decode(...)` returns the sentinel error `mongo.ErrNoDocuments` on a miss, which the Go skill translates to `domain.ErrNotFound`. Motor's `await find_one(...)` simply **returns `None`** — there is no error to catch or translate on the not-found path. So the not-found contract is a `None` return here; a caller that *requires* the asset to exist raises `NotFoundError` at its own layer. This is a genuine driver-shape difference, not a stylistic choice.

---

## 6. List — `find(...)` + `to_list`, Still Tenant-Scoped

```python
from domain.data_asset import DataAsset, SensitivityLevel


async def list_by_sensitivity(self, level: SensitivityLevel) -> list[DataAsset]:
    filter = {
        "tenantId": _tenant_id().hex,
        "sensitivity": level.value,
        "deletedAt": {"$exists": False},
    }
    cursor = self._col.find(filter).sort("assetId", 1)
    docs = await cursor.to_list(length=None)   # materialize the whole cursor
    return [_reconstitute(d) for d in docs]
```

`cursor.to_list(length=None)` decodes the whole cursor at once — correct for a bounded result set. For an unbounded stream, iterate with `async for doc in cursor:` and reconstitute one document at a time to keep memory flat. `find(...)` itself does no I/O until awaited or iterated; the network round-trip happens inside `to_list`.

---

## 7. Write — `save` with Optimistic Concurrency (single-document, atomic)

A single-document `update_one` is atomic in MongoDB — no session needed. Concurrency is enforced by placing the expected `version` in the *filter* (compare-and-swap): if another writer moved past it, zero documents match and the update is rejected.

```python
from pymongo import ReturnDocument
from pymongo.errors import DuplicateKeyError

from domain.data_asset import DataAsset
from domain.errors import ConflictError, ConcurrentModificationError


async def save(self, asset: DataAsset) -> None:
    doc = _to_doc(asset)
    filter = {
        "tenantId": asset.tenant_id.hex,
        "assetId": str(asset.id),
        "version": asset.version,          # CAS: match the version we loaded
    }
    update = {"$set": {
        "sensitivity": asset.sensitivity.value,
        "version": asset.version + 1,
        "schemaVersion": doc["schemaVersion"],
    }}
    try:
        result = await self._col.update_one(filter, update, upsert=True)
    except DuplicateKeyError as exc:
        raise _translate_mongo_error(exc)   # racing double-insert on the unique index
    if result.matched_count == 0 and result.upserted_id is None:
        raise ConcurrentModificationError   # a concurrent writer won the CAS
```

`upsert=True` lets the first write of a brand-new Aggregate insert it; the CAS still protects every subsequent update. A unique index on `{tenantId, assetId}` makes a racing double-insert surface as a `DuplicateKeyError` rather than two documents. (`ReturnDocument` is imported here only to signal the `find_one_and_update` variant is available when a method must return the post-image; `save` does not need it.)

---

## 8. Error-Translation Table and Helper

Every driver error is classified once, in this private helper beside the repository — never a shared `infrastructure/errors.py`. No `pymongo` or `bson` type crosses out of this package.

| Driver condition | Detected with | Domain outcome |
|---|---|---|
| No document matched a `find_one` | `doc is None` (no exception raised) | `get` returns `None`; caller raises `NotFoundError` if presence required |
| Duplicate key on a unique index | `pymongo.errors.DuplicateKeyError` — server write-error code **11000** | `ConflictError` |
| CAS matched zero rows | `result.matched_count == 0 and result.upserted_id is None` | `ConcurrentModificationError` |
| Operation exceeded its deadline | `pymongo.errors.ExecutionTimeout` / `asyncio.TimeoutError` | `TimeoutError` (domain) |
| Server/connection unavailable | `pymongo.errors.ConnectionFailure`, `ServerSelectionTimeoutError` | `UnavailableError` |
| Anything else | fallthrough | wrapped `InternalError` |

```python
from pymongo.errors import (
    DuplicateKeyError,
    ExecutionTimeout,
    ConnectionFailure,
    ServerSelectionTimeoutError,
    PyMongoError,
)

from domain.errors import ConflictError, TimeoutError as DomainTimeout, UnavailableError, InternalError


def _translate_mongo_error(err: PyMongoError) -> Exception:
    if isinstance(err, DuplicateKeyError):
        # Server duplicate-key write error, code 11000.
        return ConflictError()
    if isinstance(err, ExecutionTimeout):
        return DomainTimeout()
    if isinstance(err, (ConnectionFailure, ServerSelectionTimeoutError)):
        return UnavailableError()
    # Any unclassified pymongo error becomes an opaque internal error — the raw
    # driver type never escapes this package.
    return InternalError(str(err))
```

Note there is no `find_one` branch: the not-found path never produces a `PyMongoError`, so it is handled by the `None`-check in `get`, not by this table. `DuplicateKeyError` subclasses `pymongo.errors.WriteError`/`OperationFailure` and carries `.code == 11000`; match on the type, do not string-match the `E11000` server message, which is not a stable contract.

---

## 9. Timeouts — the Caller's Deadline Reaches the Wire

Every method is `async` and awaits every motor call, so a caller wrapping the call in `asyncio.wait_for(...)` cancels the awaiting coroutine. For a *server-side* cap (the operation stops executing on the server, not just client-side abandonment), pass `max_time_ms` to the driver call:

```python
doc = await self._col.find_one(filter, max_time_ms=2000)
```

`max_time_ms` maps to MongoDB's `maxTimeMS`, surfacing as `pymongo.errors.ExecutionTimeout` when exceeded — translated to the domain `TimeoutError` above. Set the deadline at the application layer; the repository never invents its own.

---

## 10. Client Construction (composition root, not the repository)

The repository receives an `AsyncIOMotorDatabase`; the client is built once at the composition root with read/write concern chosen deliberately, then pinged before use.

```python
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.read_concern import ReadConcern
from pymongo.write_concern import WriteConcern
from pymongo.read_preferences import PrimaryPreferred


async def connect(uri: str) -> AsyncIOMotorClient:
    client = AsyncIOMotorClient(
        uri,
        write_concern=WriteConcern("majority"),   # durable acknowledgement
        read_concern=ReadConcern("majority"),     # read majority-committed data
        read_preference=PrimaryPreferred(),
    )
    await client.admin.command("ping")            # fail fast if unreachable
    return client
```

Read/write concern are per-operation dials too: override on a specific call (e.g. `self._col.with_options(write_concern=WriteConcern("majority"))`) when one operation needs a stronger or weaker guarantee than the client default. `w="majority"` (`WriteConcern("majority")`) is the safe default for state-changing writes in this repo. Under Linkerd the connection is mTLS-wrapped at the mesh layer; the driver URI is unaware of it — no application change.
