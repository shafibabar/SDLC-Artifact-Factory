# Expand/Contract Worked Sequences and Tenant Application Order

Reference for `python-migration`. Concrete, deploy-spanning sequences for the changes
that are **not** safe in a single deploy, plus how the control plane rolls a revision
across every tenant database under physical multi-tenancy. All SQL is hand-written and
run through `op.execute()` — no ORM, no autogenerate.

---

## 1. The rule these sequences enforce

A rolling Kubernetes update runs **old and new application code at the same time**
against **one schema** for the whole rollout window. A schema change is only safe in a
single deploy if that intermediate schema is tolerated by both code versions. When it is
not, the change is split across two deploys (Expand, then Contract) with the migration
run as a pre-rollout Job in each. "One deploy" and "one revision" are not the same unit
— Expand and Contract are two revisions *and* two deploys.

---

## 2. Worked: adding a required (`NOT NULL`) column — a non-backward-compatible change

Goal: `data_assets.classification_status` must end up `NOT NULL`. Doing it in one shot
(`ADD COLUMN ... NOT NULL` with no default, or with a default that rewrites the whole
table under an `ACCESS EXCLUSIVE` lock) either fails on existing rows or locks a live
table. Split it into three steps across two deploys.

### Deploy 1 — Expand (nullable add), plus code that writes the column

**Revision** `0002_add_classification_status.py` (additive, nullable — tolerated by old
code that ignores the column and new code that populates it):

```python
revision = "0002"
down_revision = "0001"

def upgrade() -> None:
    op.execute("ALTER TABLE data_assets ADD COLUMN classification_status TEXT")

def downgrade() -> None:
    op.execute("ALTER TABLE data_assets DROP COLUMN classification_status")
```

Application code shipped in the *same* Deploy 1 starts writing `classification_status`
on every new/updated row. Old rows still hold `NULL`; old replicas mid-rollout simply
never set it. Both are fine because the column is nullable.

### Between deploys — the backfill runs as an application-level batch job

Existing rows must be populated **before** the constraint can be added. This is a bounded
batch job, **never** a bare `UPDATE` inside a revision's `upgrade()` — an unthrottled
`UPDATE data_assets SET ...` locks and rewrites the entire table for the migration's
duration, blocking the deploy and every concurrent write. Use `asyncpg` directly with a
keyset-paginated, throttled loop:

```python
# jobs/backfill_classification_status.py — run as a one-shot K8s Job, NOT in a revision
import asyncio
import asyncpg

BATCH = 5_000

async def backfill(dsn: str) -> None:
    conn = await asyncpg.connect(dsn)
    try:
        last_id = "00000000-0000-0000-0000-000000000000"
        while True:
            # Keyset pagination on the primary key — bounded work per statement,
            # no OFFSET scan, no whole-table lock.
            rows = await conn.fetch(
                """
                UPDATE data_assets
                   SET classification_status = 'unclassified'
                 WHERE id IN (
                     SELECT id FROM data_assets
                      WHERE classification_status IS NULL
                        AND id > $1
                      ORDER BY id
                      LIMIT $2
                 )
             RETURNING id
                """,
                last_id, BATCH,
            )
            if not rows:
                break
            last_id = max(r["id"] for r in rows)
            await asyncio.sleep(0.1)   # throttle: yield the DB to live traffic
    finally:
        await conn.close()

if __name__ == "__main__":
    import os
    asyncio.run(backfill(os.environ["DATABASE_URL"]))
```

Idempotent (`WHERE classification_status IS NULL`) and re-runnable. Verify zero NULLs
remain before proceeding: `SELECT count(*) FROM data_assets WHERE
classification_status IS NULL` must return 0.

### Deploy 2 (later) — Contract (add the constraint)

Only now, with every row populated and all replicas writing the column, add the
constraint. Use `NOT VALID` then `VALIDATE CONSTRAINT` so Postgres takes only a brief
lock to add the constraint and validates existing rows **without** an
`ACCESS EXCLUSIVE` full-table scan:

```python
revision = "0004"
down_revision = "0003"

def upgrade() -> None:
    # 1. Add the CHECK as NOT VALID — instant, light lock, not applied to existing rows yet.
    op.execute(
        "ALTER TABLE data_assets "
        "ADD CONSTRAINT data_assets_classification_status_not_null "
        "CHECK (classification_status IS NOT NULL) NOT VALID"
    )
    # 2. VALIDATE separately — scans existing rows under a SHARE UPDATE EXCLUSIVE lock
    #    that does NOT block reads or writes.
    op.execute(
        "ALTER TABLE data_assets "
        "VALIDATE CONSTRAINT data_assets_classification_status_not_null"
    )

def downgrade() -> None:
    op.execute(
        "ALTER TABLE data_assets "
        "DROP CONSTRAINT data_assets_classification_status_not_null"
    )
```

A `CHECK (col IS NOT NULL)` validated this way is the online-safe path to a not-null
guarantee; a direct `ALTER COLUMN ... SET NOT NULL` on older Postgres takes a full-table
`ACCESS EXCLUSIVE` lock and is avoided here for that reason.

---

## 3. Worked: renaming a column (expand + dual-write, then contract)

A rename is never a single `ALTER TABLE ... RENAME COLUMN` on a live table — the instant
it runs, every old replica references a column that no longer exists. Expand/contract it:

| Deploy | Revision | App code |
|---|---|---|
| Deploy 1 (Expand) | Add new column `sensitivity_level` (nullable) | New code **dual-writes**: writes both `sensitivity` (old) and `sensitivity_level` (new); reads prefer new, fall back to old |
| Between | Backfill job copies `sensitivity` → `sensitivity_level` for existing rows | — |
| Deploy 2 (Contract) | Drop old column `sensitivity` | New code reads/writes only `sensitivity_level`; dual-write removed |

Expand revision:

```python
def upgrade() -> None:
    op.execute("ALTER TABLE data_assets ADD COLUMN sensitivity_level TEXT")
def downgrade() -> None:
    op.execute("ALTER TABLE data_assets DROP COLUMN sensitivity_level")
```

Contract revision (a later deploy, after backfill and after all replicas dual-write):

```python
def upgrade() -> None:
    op.execute("ALTER TABLE data_assets DROP COLUMN sensitivity")
def downgrade() -> None:
    # Reversible: re-add the column. Data that was in it is gone — see the
    # irreversible-drop note below if the old data must be recoverable.
    op.execute("ALTER TABLE data_assets ADD COLUMN sensitivity TEXT")
```

If the dropped column's data must remain recoverable for a retention window, make the
Contract a **reversible archive** (`RENAME COLUMN sensitivity TO sensitivity__dropped`)
and schedule a separate, later, irreversible drop whose `downgrade()` raises:

```python
def downgrade() -> None:
    op.execute(
        "DO $$ BEGIN "
        "RAISE EXCEPTION 'sensitivity__dropped was permanently removed; "
        "restore from backup, not from a downgrade'; END $$"
    )
```

---

## 4. Tenant application order under physical multi-tenancy

Physical multi-tenancy (`multi-tenancy-design`) gives every tenant its **own database**.
One revision set applies to all of them; the control plane iterates tenants and records
each tenant's current revision. A migration is not "done" until **every** tenant DB is at
`head`.

### Application order

1. **Canary tenants first.** Apply to a small set of internal/low-risk tenant DSNs, run
   smoke checks, then proceed. A revision that fails on real tenant data fails on the
   canary, not the fleet.
2. **Then the rest, in a bounded-parallelism sweep.** Physical isolation means tenant
   applies are independent — they can run concurrently, but bound the concurrency so a
   shared Postgres cluster is not saturated.
3. **Record per-tenant version and alert on stragglers.** A tenant left behind is a
   tracked, alertable state — never silently skipped.

```python
# control-plane sweep (sketch) — bounded-parallel alembic upgrade per tenant DSN
import asyncio
import asyncpg

async def migrate_tenant(dsn: str, sem: asyncio.Semaphore) -> tuple[str, bool]:
    async with sem:
        proc = await asyncio.create_subprocess_exec(
            "alembic", "upgrade", "head",
            env={"DATABASE_URL": dsn, "PATH": "/usr/bin:/bin"},
        )
        code = await proc.wait()
        return dsn, code == 0

async def sweep(tenant_dsns: list[str], max_parallel: int = 8) -> None:
    sem = asyncio.Semaphore(max_parallel)
    results = await asyncio.gather(*(migrate_tenant(d, sem) for d in tenant_dsns))
    failed = [dsn for dsn, ok in results if not ok]
    if failed:
        # These tenants are stragglers — record + alert, do not swallow.
        raise SystemExit(f"migration incomplete for {len(failed)} tenants: {failed}")
```

Record each tenant's revision in a control-plane table so `heads`-vs-`current` drift is
queryable:

```sql
-- control-plane DB (not a tenant DB)
CREATE TABLE tenant_schema_version (
    tenant_id      UUID PRIMARY KEY,
    current_rev    TEXT NOT NULL,
    target_rev     TEXT NOT NULL,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Alert when any row has current_rev <> target_rev for longer than the SLO window.
```

### Ordering interaction with expand/contract

The two-deploy discipline holds **per tenant**: a Contract revision must not sweep the
fleet until every tenant has completed its Expand deploy *and* its backfill. Track the
phase in the control-plane version table; gate the Contract sweep on all tenants
reporting the Expand `target_rev` plus a "backfill complete" flag.

---

## 5. Checklist

- [ ] Required-column add = nullable add (Deploy 1) → app-level batch backfill →
      `NOT VALID` + `VALIDATE CONSTRAINT` (Deploy 2).
- [ ] Backfill is a throttled, keyset-paginated Job — never an `UPDATE` in `upgrade()`.
- [ ] Rename = add new + dual-write (Deploy 1) → backfill → drop old (Deploy 2).
- [ ] Recoverable drops archived via `RENAME`; the eventual hard drop's `downgrade()` raises.
- [ ] Tenant sweep: canary first, bounded parallelism, per-tenant version recorded, stragglers alerted.
- [ ] Contract sweep gated on all tenants having completed Expand + backfill.
