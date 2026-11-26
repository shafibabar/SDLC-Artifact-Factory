# The Real asyncpg Adapter

The infrastructure-side implementation of the `DataAssetRepository` port. It is `asyncpg`-direct — no SQLAlchemy ORM — and uses the same `$1`/`$2` positional placeholders as `pgx`, which is why this is one of the closest 1:1 ports from `go-repository-pattern` in the whole roster. This reference gives the full adapter: connection/transaction handling, tenant scoping via `contextvars`, the insert and the CAS-on-`version` update, the outbox insert in the same transaction, `reconstitute` on read, the `asyncpg`-error-to-domain-error translation table, and the integration-test note.

---

## 1. Connection and transaction handling — the UoW owns the boundary

The adapter's methods take a caller-supplied `asyncpg.Connection`. They **never** call `pool.acquire()` themselves and **never** open their own transaction. The Unit of Work / service layer (`python-service-layer`) owns the boundary:

```python
# Illustration: who opens the transaction — the Unit of Work, NOT the adapter
async with pool.acquire() as conn:
    async with conn.transaction():           # replaces pgx pool.Begin + deferred rollback
        repo = DataAssetRepo(conn)
        asset = await repo.get(asset_id)
        asset.classify(SensitivityLevel.RESTRICTED, by=user_id, now=now)
        await repo.save(asset)               # UPDATE + outbox INSERT, atomic
    # commit on clean exit; rollback on any exception raised inside the block
```

`async with conn.transaction():` is the direct analog of Go's `pool.Begin(ctx)` plus `defer tx.Rollback(ctx)` — the context manager commits when the block exits cleanly and rolls back if any exception propagates out. Because `save`'s row write and its outbox `INSERT` are separate statements, only running them inside this one shared `conn.transaction()` makes them atomic. Calling `save` on a connection with no surrounding transaction is a code-review defect.

---

## 2. Tenant scoping via `contextvars`

The tenant id is read from the `current_tenant` `ContextVar` in `domain/context.py` (shown in `python-domain-model`), set by the auth middleware or the event consumer. `tenant_id()` raises `RuntimeError` when it is unset, so a missing tenant never silently widens a query. A module-level plain value would instead leak state across concurrently scheduled coroutines.

`tenant_id` stays in every `WHERE` clause whichever isolation model the tenancy design chose; it is a backstop, not the isolation mechanism (a pooled store also needs one enforced by the database, such as row-level security). A single-tenant product drops it.

---

## 3. The worked `DataAssetRepo`

The tables are `data_assets` (`id`, `tenant_id`, `source_id`, `sensitivity_level` `SMALLINT`, `version`, `deleted_at`, …; `python-migration`) and the relay's `outbox` (`id`, `aggregate_id`, `tenant_id`, `event_type`, `payload` `jsonb`, `occurred_at`, `published_at`; `python-event-publisher`). Create the pool with `init=register_codecs` so a `dict` can be passed for the `jsonb` column.

```python
# src/classification/adapters/postgres.py
import json
from dataclasses import asdict
from datetime import datetime
from enum import Enum
from uuid import UUID, uuid4

import asyncpg

from classification.adapters.errors import RepositoryError
from classification.domain.context import tenant_id
from classification.domain.dataasset import DataAsset
from classification.domain.errors import (
    ConflictError, DomainError, NotFoundError, OptimisticConcurrencyError, ValidationError)
from classification.domain.events import DomainEvent
from classification.domain.sensitivity import SensitivityLevel

_COLUMNS = "id, tenant_id, source_id, sensitivity_level, version"
_ENVELOPE_FIELDS = {"aggregate_id", "tenant_id", "occurred_at"}  # columns, not payload


async def register_codecs(conn: asyncpg.Connection) -> None:
    """Pass as asyncpg.create_pool(..., init=register_codecs)."""
    await conn.set_type_codec(
        "jsonb", encoder=json.dumps, decoder=json.loads, schema="pg_catalog")


def _json_value(value: object) -> object:
    if isinstance(value, Enum):
        return value.name
    if isinstance(value, UUID):
        return str(value)
    if isinstance(value, datetime):
        return value.isoformat()
    return value


def _payload(event: DomainEvent) -> dict[str, object]:
    return {k: _json_value(v) for k, v in asdict(event).items() if k not in _ENVELOPE_FIELDS}


class DataAssetRepo:
    """asyncpg adapter satisfying domain.ports.DataAssetRepository.
    Constructed per-transaction with the caller's connection."""

    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn
        self.saved_events: list[DomainEvent] = []

    # ---- reads ---------------------------------------------------------

    async def get(self, asset_id: UUID) -> DataAsset | None:
        try:
            row = await self._conn.fetchrow(
                f"SELECT {_COLUMNS} FROM data_assets "     # constant column list, no values
                "WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL",
                asset_id, tenant_id())
        except asyncpg.PostgresError as exc:
            raise _translate(exc, asset_id, 0) from exc
        return None if row is None else _to_aggregate(row)

    async def list_by_source(self, source_id: UUID) -> list[DataAsset]:
        try:
            rows = await self._conn.fetch(
                f"SELECT {_COLUMNS} FROM data_assets "
                "WHERE source_id = $1 AND tenant_id = $2 AND deleted_at IS NULL",
                source_id, tenant_id())
        except asyncpg.PostgresError as exc:
            raise RepositoryError(f"listing data assets of source {source_id}") from exc
        return [_to_aggregate(r) for r in rows]

    # ---- write: insert or CAS update, plus outbox ----------------------

    async def save(self, asset: DataAsset) -> None:
        if not self._conn.is_in_transaction():
            raise RuntimeError("save() needs the caller's transaction")
        tenant = tenant_id()
        if asset.tenant_id != tenant:
            raise RuntimeError("asset belongs to a different tenant than the context")
        if asset.version_number == asset.persisted_version:
            return                                          # nothing changed
        expected = asset.persisted_version
        events = asset.pull_events()
        try:
            if expected == 0:
                await self._conn.execute(
                    "INSERT INTO data_assets "
                    "(id, tenant_id, source_id, sensitivity_level, version) "
                    "VALUES ($1, $2, $3, $4, $5)",
                    asset.id, tenant, asset.source_id,
                    asset.sensitivity.value, asset.version_number)
            else:
                # CAS: the WHERE clause pins the version we loaded. A concurrent
                # write makes this match zero rows, so RETURNING yields no row.
                updated = await self._conn.fetchrow(
                    "UPDATE data_assets SET sensitivity_level = $1, version = $2 "
                    "WHERE id = $3 AND tenant_id = $4 AND version = $5 "
                    "AND deleted_at IS NULL RETURNING id",
                    asset.sensitivity.value, asset.version_number,
                    asset.id, tenant, expected)
                if updated is None:
                    raise OptimisticConcurrencyError(asset.id, expected)
            # Outbox insert in the SAME transaction as the state change. The row id
            # becomes the event_id; the relay (python-event-publisher) never remakes it.
            for event in events:
                await self._conn.execute(
                    "INSERT INTO outbox "
                    "(id, aggregate_id, tenant_id, event_type, payload, occurred_at) "
                    "VALUES ($1, $2, $3, $4, $5, $6)",
                    uuid4(), event.aggregate_id, tenant,
                    type(event).__name__, _payload(event), event.occurred_at)
        except asyncpg.PostgresError as exc:
            raise _translate(exc, asset.id, expected) from exc
        asset.mark_persisted()
        self.saved_events.extend(events)


def _to_aggregate(row: asyncpg.Record) -> DataAsset:
    # reconstitute, NEVER register: re-running creation on a read would put a stale
    # DataAssetRegistered into the outbox. See python-domain-model.
    return DataAsset.reconstitute(
        id=row["id"], tenant_id=row["tenant_id"], source_id=row["source_id"],
        sensitivity=SensitivityLevel(row["sensitivity_level"]),
        version_number=row["version"])
```

If a transaction rolls back after `save`, discard the Aggregate and the repository with it: `mark_persisted()` has already run on that in-memory copy. The Unit of Work does this by construction.

Notes:

- `conn.execute(...)` returns a status string like `"UPDATE 1"` / `"INSERT 0 1"`; `fetchrow ... RETURNING id` gives the lost-CAS signal more directly (`None`).
- Every value is passed as a separate argument to a `$N` placeholder — `asyncpg` transmits SQL text and parameter values separately, so a value can never be re-parsed as SQL. The only interpolation here is a module constant (the column list). Never format a value into SQL.
- `asyncpg` has **no named-parameter syntax** (`:name`); positional `$N` is the only form.

---

## 4. Error translation — no `asyncpg` type crosses this edge

Every `asyncpg.PostgresError` a method can raise is translated into a domain exception (or `RepositoryError`), so nothing downstream inspects a `sqlstate`. `asyncpg` exposes both typed exception subclasses and the five-character SQLSTATE on `exc.sqlstate`. The caller writes `raise _translate(...) from exc`, which preserves the chain in `__cause__`, Python's analog of Go's `%w`.

```python
# src/classification/adapters/errors.py
from classification.domain.errors import DomainError


class RepositoryError(DomainError):
    """A persistence operation failed for an infrastructure reason."""
```

```python
# src/classification/adapters/postgres.py  (continued)
def _translate(exc: asyncpg.PostgresError, asset_id: UUID,
               expected_version: int) -> DomainError | TimeoutError:
    """Map an asyncpg error to the domain's failure vocabulary."""
    if isinstance(exc, asyncpg.UniqueViolationError):          # SQLSTATE 23505
        return ConflictError(asset_id, "already exists")
    if isinstance(exc, asyncpg.SerializationError):            # SQLSTATE 40001, retryable
        return OptimisticConcurrencyError(asset_id, expected_version)
    if isinstance(exc, asyncpg.ForeignKeyViolationError):      # SQLSTATE 23503
        return NotFoundError(asset_id, tenant_id())
    if isinstance(exc, asyncpg.NotNullViolationError):         # SQLSTATE 23502
        return ValidationError("data_asset", "a required value is missing")
    if isinstance(exc, asyncpg.QueryCanceledError):            # SQLSTATE 57014
        return TimeoutError("statement timed out")
    return RepositoryError(f"data asset {asset_id}: database error {exc.sqlstate}")
```

| Condition | `asyncpg` exception class | SQLSTATE | Translation |
|---|---|---|---|
| Unique / primary-key violation | `asyncpg.UniqueViolationError` | `23505` | `ConflictError` |
| Foreign-key violation | `asyncpg.ForeignKeyViolationError` | `23503` | `NotFoundError` |
| Serialization failure | `asyncpg.SerializationError` | `40001` | `OptimisticConcurrencyError` (retryable) |
| Statement timeout / cancel | `asyncpg.QueryCanceledError` | `57014` | `TimeoutError` |
| Not-null violation | `asyncpg.NotNullViolationError` | `23502` | `ValidationError` |
| Any other database error | `asyncpg.PostgresError` | — | `RepositoryError` |

---

## 5. Integration-test note

The adapter is a thin, hard-to-unit-test wrapper (Robert Martin's **Humble Object** applied to persistence) — it is verified by a small **integration** suite against a real PostgreSQL, not by unit tests with a mocked driver. `python-integration-test` owns the harness; this skill only states what must be exercised:

- **Real CAS conflict:** two overlapping transactions load the same Aggregate at the same version; one `save` must raise `OptimisticConcurrencyError`.
- **Real outbox atomicity:** after a committed `save`, exactly one outbox row exists for the state change; after a rolled-back transaction, zero outbox rows and zero state change.
- **Real tenant isolation:** a `get` under tenant A must not return tenant B's row even with a matching id.
- **Real constraint translation:** inserting a duplicate id surfaces as `ConflictError`, not a raw `asyncpg.UniqueViolationError`.

The pool under test is created with `init=register_codecs`; the fixtures seed one asset (`seeded_id`) and set `current_tenant` to its tenant.

```python
# tests/integration/test_dataasset_repo.py  (shape only — see python-integration-test)
@pytest.mark.asyncio
async def test_save_raises_on_concurrent_modification(pg_pool, seeded_id) -> None:
    async with pg_pool.acquire() as c1, pg_pool.acquire() as c2:
        a = await DataAssetRepo(c1).get(seeded_id)                 # version 1
        b = await DataAssetRepo(c2).get(seeded_id)                 # version 1
        b.classify(SensitivityLevel.RESTRICTED, by=uuid4(), now=NOW)
        async with c2.transaction():
            await DataAssetRepo(c2).save(b)                        # wins: version 2
        a.classify(SensitivityLevel.PUBLIC, by=uuid4(), now=NOW)
        with pytest.raises(OptimisticConcurrencyError):
            async with c1.transaction():
                await DataAssetRepo(c1).save(a)                    # expects 1 → 0 rows
```
