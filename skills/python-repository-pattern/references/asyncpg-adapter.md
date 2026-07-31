# The Real asyncpg Adapter

The infrastructure-side implementation of the `DataAssetRepository` port. It is `asyncpg`-direct — no SQLAlchemy ORM — and uses the same `$1`/`$2` positional placeholders as `pgx`, which is why this is one of the closest 1:1 ports from `go-repository-pattern` in the whole roster. This reference gives the full adapter: connection/transaction handling, tenant scoping via `contextvars`, the CAS-on-`version` write, the outbox insert in the same transaction, `reconstitute` on read, the `asyncpg`-error-to-domain-error translation table, and the integration-test note.

---

## 1. Connection and transaction handling — the UoW owns the boundary

The adapter's methods take a caller-supplied `asyncpg.Connection`. They **never** call `pool.acquire()` themselves and **never** open their own transaction. The Unit of Work / service layer (`python-service-layer`) owns the boundary:

```python
# who opens the transaction — the service layer, NOT the adapter
async with pool.acquire() as conn:
    async with conn.transaction():           # replaces pgx pool.Begin + deferred rollback
        repo = DataAssetRepo(conn)
        asset = await repo.get(asset_id)
        asset.reclassify("restricted")       # domain method mutates + bumps version + records event
        await repo.save(asset)               # UPDATE + outbox INSERT, atomic
    # commit on clean exit; rollback on any exception raised inside the block
```

`async with conn.transaction():` is the direct analog of Go's `pool.Begin(ctx)` plus `defer tx.Rollback(ctx)` — the context manager commits when the block exits cleanly and rolls back if any exception propagates out. Because `save`'s `UPDATE` and its outbox `INSERT` are two statements, only running them inside this one shared `conn.transaction()` makes them atomic. Calling `save` on a connection with no surrounding transaction is a code-review defect.

---

## 2. Tenant scoping via `contextvars`

The tenant id is read from a `contextvars.ContextVar` set by auth middleware — never a module-level global (a global leaks state across concurrently-scheduled coroutines on the same event loop). A missing tenant id fails loudly rather than silently widening the query to all tenants.

```python
# infrastructure/tenant_context.py
import contextvars
from uuid import UUID

current_tenant: contextvars.ContextVar[UUID] = contextvars.ContextVar("current_tenant")


def tenant_id() -> UUID:
    try:
        return current_tenant.get()
    except LookupError:
        # A missing tenant must never silently become a cross-tenant query.
        raise RuntimeError("tenant id missing from context — auth middleware did not run")
```

This is the application-layer backstop behind the product's **physical** per-tenant isolation: `tenant_id` is still in every `WHERE` clause, defence in depth, not "optimised away" because the schema is already isolated.

---

## 3. The worked `DataAssetRepo`

```python
# infrastructure/postgres/dataasset_repo.py
from __future__ import annotations
from uuid import UUID

import asyncpg

from domain.data_asset import DataAsset, SensitivityLevel
from domain.errors import NotFoundError, ConcurrentModificationError, AlreadyExistsError
from infrastructure.tenant_context import tenant_id


class DataAssetRepo:
    """asyncpg adapter satisfying domain.ports.DataAssetRepository.
    Constructed per-transaction with the caller's connection."""

    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn

    # ---- reads ---------------------------------------------------------

    async def get(self, asset_id: UUID) -> DataAsset | None:
        row = await self._conn.fetchrow(
            """
            SELECT id, tenant_id, source_id, sensitivity_level, version
              FROM data_assets
             WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL
            """,
            asset_id,
            tenant_id(),
        )
        if row is None:
            return None
        # Reconstitute, NEVER the constructor: re-running invariant checks and
        # re-emitting the creation event on every read would republish a stale
        # DataAssetRegistered into the outbox. See python-domain-model.
        return DataAsset.reconstitute(
            id=row["id"],
            tenant_id=row["tenant_id"],
            source_id=row["source_id"],
            sensitivity_level=SensitivityLevel(row["sensitivity_level"]),
            version=row["version"],
        )

    async def list_by_source(self, source_id: UUID) -> list[DataAsset]:
        rows = await self._conn.fetch(
            """
            SELECT id, tenant_id, source_id, sensitivity_level, version
              FROM data_assets
             WHERE source_id = $1 AND tenant_id = $2 AND deleted_at IS NULL
            """,
            source_id,
            tenant_id(),
        )
        return [
            DataAsset.reconstitute(
                id=r["id"], tenant_id=r["tenant_id"], source_id=r["source_id"],
                sensitivity_level=SensitivityLevel(r["sensitivity_level"]),
                version=r["version"],
            )
            for r in rows
        ]

    # ---- write: CAS + outbox, one transaction --------------------------

    async def save(self, asset: DataAsset) -> None:
        try:
            # CAS on version: the WHERE clause pins the version we loaded.
            # A concurrent write that already bumped version makes this match
            # zero rows. RETURNING lets us read the affected count directly.
            updated = await self._conn.fetchrow(
                """
                UPDATE data_assets
                   SET sensitivity_level = $1,
                       version = version + 1
                 WHERE id = $2 AND tenant_id = $3 AND version = $4
             RETURNING id
                """,
                asset.sensitivity_level.value,
                asset.id,
                tenant_id(),
                asset.version,          # the version we read; CAS pins it
            )
        except asyncpg.PostgresError as exc:
            raise _translate(exc)

        if updated is None:
            # Zero rows updated → someone else won the race. Never last-write-wins.
            raise ConcurrentModificationError(
                f"data_asset {asset.id} was modified concurrently"
            )

        # Outbox insert in the SAME transaction as the state change. The caller's
        # conn.transaction() block commits both together or neither. The relay
        # (python-event-publisher) delivers them to Redpanda later.
        for event in asset.events:
            await self._conn.execute(
                """
                INSERT INTO outbox (id, tenant_id, aggregate_id, event_type, payload)
                VALUES ($1, $2, $3, $4, $5)
                """,
                event.id,
                tenant_id(),
                asset.id,
                type(event).__name__,
                event.to_json(),
            )
        asset.events.clear()
```

Notes:

- `conn.execute(...)` returns a status string like `"UPDATE 1"` / `"INSERT 0 1"` if you need the affected-row count without `RETURNING`; here `fetchrow ... RETURNING id` gives the same signal more directly (a `None` means zero rows, i.e. a lost CAS).
- Every SQL string uses `$1`/`$2` positional placeholders with values passed as separate arguments — `asyncpg` transmits SQL text and parameter values as two distinct protocol messages, so a value can never be re-parsed as SQL. Never build SQL with f-strings or `%`-formatting.
- `asyncpg` has **no named-parameter syntax** (`:name`/`@name` are ORM/driver features `asyncpg` does not provide); positional `$N` is the only form.

---

## 4. Error translation — no `asyncpg` type crosses this edge

Every `asyncpg` exception a method can raise is translated here into a domain exception, so nothing downstream ever inspects a `sqlstate` itself. `asyncpg` exposes both typed exception subclasses and the raw five-character SQLSTATE on `exc.sqlstate`.

```python
# infrastructure/postgres/dataasset_repo.py  (continued)
def _translate(exc: asyncpg.PostgresError) -> Exception:
    """Map an asyncpg error to the domain's failure vocabulary. Lives beside
    the repository that raises it — never a shared infrastructure/errors.py."""
    # Unique violation (e.g. duplicate id / natural key) → already-exists.
    if isinstance(exc, asyncpg.UniqueViolationError):      # SQLSTATE 23505
        return AlreadyExistsError("data_asset already exists") from exc  # type: ignore[misc]
    # Serialization failure under SERIALIZABLE/REPEATABLE READ → retryable.
    if exc.sqlstate == "40001":                            # serialization_failure
        return ConcurrentModificationError("serialization failure; retry") 
    # Foreign-key violation → a referenced row is missing.
    if isinstance(exc, asyncpg.ForeignKeyViolationError):  # SQLSTATE 23503
        return NotFoundError("referenced row does not exist") 
    # Statement timeout (server-side statement_timeout) → surface as timeout.
    if exc.sqlstate == "57014":                            # query_canceled
        return TimeoutError("statement timed out") 
    return exc  # unknown DB error propagates as-is to the transport 500 handler
```

Full SQLSTATE reference for the codes named above:

| Condition | `asyncpg` exception class | SQLSTATE | Domain translation |
|---|---|---|---|
| Unique / primary-key violation | `asyncpg.UniqueViolationError` | `23505` | `AlreadyExistsError` |
| Foreign-key violation | `asyncpg.ForeignKeyViolationError` | `23503` | `NotFoundError` |
| Serialization failure | `asyncpg.SerializationError` | `40001` | `ConcurrentModificationError` (retryable) |
| Statement timeout / cancel | `asyncpg.QueryCanceledError` | `57014` | `TimeoutError` |
| Not-null violation | `asyncpg.NotNullViolationError` | `23502` | domain validation error |

The rule with no exception: **no `asyncpg` type ever crosses out of `infrastructure/postgres/`.** A caller that needs to read `exc.sqlstate` itself is a defect — the translation already happened here. `raise DomainError(...) from exc` preserves the chain via `__cause__`, Python's analog of Go's `%w` wrapping.

`from cause` chaining is omitted in the snippet's `return ...` lines for brevity; in real code use `raise AlreadyExistsError(...) from exc` at the call site so `__cause__` is preserved.

---

## 5. Integration-test note

The adapter is a thin, hard-to-unit-test wrapper (Robert Martin's **Humble Object** applied to persistence) — it is verified by a small **integration** suite against a real PostgreSQL, not by unit tests with a mocked driver. `python-integration-test` owns the harness; this skill only states what must be exercised:

- **Real CAS conflict:** two overlapping transactions load the same Aggregate at the same version; one `save` must raise `ConcurrentModificationError`.
- **Real outbox atomicity:** after a committed `save`, exactly one outbox row exists for the state change; after a rolled-back transaction, zero outbox rows and zero state change.
- **Real tenant isolation:** a `get` under tenant A must not return tenant B's row even with a matching id.
- **Real constraint translation:** inserting a duplicate id surfaces as `AlreadyExistsError`, not a raw `asyncpg.UniqueViolationError`.

```python
# tests/infrastructure/test_dataasset_repo.py  (shape only — see python-integration-test)
@pytest.mark.asyncio
async def test_save_raises_on_concurrent_modification(pg_pool) -> None:
    async with pg_pool.acquire() as c1, pg_pool.acquire() as c2:
        async with c1.transaction():
            a = await DataAssetRepo(c1).get(SEED_ID)   # version 0
        async with c2.transaction():
            b = await DataAssetRepo(c2).get(SEED_ID)   # version 0
            b.reclassify("restricted")
            await DataAssetRepo(c2).save(b)            # wins, bumps to version 1
        with pytest.raises(ConcurrentModificationError):
            async with c1.transaction():
                a.reclassify("public")
                await DataAssetRepo(c1).save(a)        # stale version 0 → 0 rows
```
