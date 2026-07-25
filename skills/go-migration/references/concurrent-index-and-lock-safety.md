# Concurrent Index Builds and Lock Safety — the Full Mechanics

Full worked material referenced from `SKILL.md`'s "Index-Creation Standard" section.
Self-contained. Covers: exactly which lock a plain `CREATE INDEX` takes and why it is
unacceptable on a live table, `CREATE INDEX CONCURRENTLY`'s mechanism and cost, the
`NO TRANSACTION` requirement, and the invalid-index failure mode and its recovery.

---

## 1. What a Plain `CREATE INDEX` Actually Blocks

A plain `CREATE INDEX` takes a `SHARE` lock on the target table for the full duration
of the build. A `SHARE` lock does not block other readers (`SELECT` is unaffected), but
it blocks every writer: `INSERT`, `UPDATE`, and `DELETE` against the table all queue
behind the index build and cannot proceed until it finishes. On a small table this is
invisible — the build takes milliseconds. On a table with real production volume, an
index build is a full sequential scan plus a sort, and can run for minutes; every write
to that table queues for the entire duration. This is not a theoretical risk gated
behind an unusual workload — it is the default behavior of the plain, unqualified
`CREATE INDEX` statement, on every table, every time. **This is why the standard is not
"use `CONCURRENTLY` on large tables" — it is `CONCURRENTLY`, always**, for any table a
migration cannot prove will never carry production rows: the line between "small enough
to not matter" and "large enough to cause an incident" moves as a product grows, and a
migration written when a table was empty does not get rewritten when the table
eventually isn't.

---

## 2. How `CREATE INDEX CONCURRENTLY` Avoids the Lock

`CONCURRENTLY` builds the index in multiple passes instead of one, taking only a
`SHARE UPDATE EXCLUSIVE` lock — a lock level that permits concurrent reads *and*
writes, at the cost of a second full table scan (to catch rows written during the
first pass) and a build that takes meaningfully longer in wall-clock time than the
blocking version. This is the correct tradeoff for a live table without exception:
a slower build that never blocks a write is always preferable to a faster one that
blocks every write for its entire duration — the whole point of the zero-downtime
standard (`SKILL.md`, `references/expand-contract-and-zero-downtime.md`) is that
schema changes are never allowed to cost the product an outage window in exchange for
convenience.

```sql
-- 00004_add_data_assets_sensitivity_index.sql
-- +goose NO TRANSACTION
-- +goose Up
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_data_assets_tenant_sensitivity
    ON data_assets (tenant_id, sensitivity_level)
    WHERE deleted_at IS NULL;

-- +goose Down
DROP INDEX CONCURRENTLY IF EXISTS idx_data_assets_tenant_sensitivity;
```

---

## 3. The Operational Wrinkle: `NO TRANSACTION`

`CREATE INDEX CONCURRENTLY` cannot run inside a transaction block — PostgreSQL rejects
it outright (`ERROR: CREATE INDEX CONCURRENTLY cannot run inside a transaction block`)
because its multi-pass design requires committing intermediate state between passes,
which a single wrapping transaction would prevent. goose wraps every migration in its
own transaction by default, so any migration containing a `CONCURRENTLY` statement
**must** carry the `-- +goose NO TRANSACTION` directive, applied once at the top of the
file (it governs the whole file, `Up` and `Down` alike — see §4 for the consequence of
that scope). A `CONCURRENTLY` statement left inside goose's default transactional
wrapper is not a subtle bug; it fails immediately, every time, on the very first `goose
up` — but it is a mistake worth naming explicitly precisely because the fix (add one
directive) is easy to forget and the error message alone does not explain *why* the
statement needs it.

**A `CONCURRENTLY` migration must also do nothing else.** Because `NO TRANSACTION`
removes the atomicity goose otherwise guarantees, a migration file mixing a
`CONCURRENTLY` index build with an ordinary `ALTER TABLE` in the same file risks a
partial, half-applied state if the process is interrupted between statements — the
index build's own failure mode (§4) is already asymmetric enough without adding a
second unrelated change to the same non-transactional file. One `CONCURRENTLY`
statement per migration file, nothing else in it.

---

## 4. Failure Mode: the Invalid Index

If a `CREATE INDEX CONCURRENTLY` build is interrupted — the migration process is
killed, the connection drops, or the build itself fails (most commonly a uniqueness
violation discovered partway through, for a unique index) — PostgreSQL does **not**
roll the attempt back the way a transactional statement would. It leaves behind an
**invalid index**: a real object in `pg_index` with `indisvalid = false`. An invalid
index is silently skipped by the query planner (it is never used to answer a query) but
still consumes disk space and is still maintained on every subsequent write to the
table — pure overhead with none of the benefit, and left in place indefinitely unless
someone notices and cleans it up.

**Recovery is manual and simple, but it is not automatic:**

```sql
DROP INDEX CONCURRENTLY IF EXISTS idx_data_assets_tenant_sensitivity;
-- then re-run the original CREATE INDEX CONCURRENTLY migration
```

`DROP INDEX CONCURRENTLY` carries the identical `NO TRANSACTION` requirement as the
`CREATE` it undoes — this is precisely why the `Down` block in §2's example already uses
`DROP INDEX CONCURRENTLY IF EXISTS` rather than a plain `DROP INDEX`: the same file's
`NO TRANSACTION` directive governs both directions, and an unqualified `DROP INDEX` in
the `Down` block would be just as rejected inside the (absent) transaction as an
unqualified `CREATE` would be. Operationally, treat any `CONCURRENTLY` migration that
did not cleanly report success as leaving an invalid index until proven otherwise —
check `SELECT indexrelid::regclass, indisvalid FROM pg_index WHERE NOT indisvalid;`
after any interrupted or failed deploy that included one, before assuming a retry is
safe to simply run again.
