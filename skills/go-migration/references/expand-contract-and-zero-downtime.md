# Expand/Contract in Full — Deploy Boundaries, Backfill, and the NOT-NULL Sequence

Full worked material referenced from `SKILL.md`'s "Zero-Downtime Standard" and
"Backward-Compatibility Standard" sections. Self-contained — reads without the parent
body already in context. Covers: why expand/contract spans **deploys**, not migration
files; the complete three-step NOT-NULL-column sequence including the `NOT VALID` /
`VALIDATE CONSTRAINT` Postgres optimization; where the backfill job actually runs and
why; and a second, shorter worked example (column rename) applying the same discipline.

---

## 1. Why the Unit Is a Deploy, Not a Migration File

Two migration files applied back-to-back by the same `goose up` invocation are still
just one moment in time from the schema's point of view — nothing about file count
protects anything. What actually creates the danger window is a **rolling deploy**:
Kubernetes brings up new-code pods while old-code pods are still serving traffic (the
window is exactly as long as the deploy's `maxSurge`/`maxUnavailable` settings keep it
open). During that window, both the old and the new application binary are issuing
queries against the *same* schema, concurrently, and neither one can be paused to wait
for the other.

A migration that adds a `NOT NULL` column in one step is only safe if no code that is
`INSERT`-ing rows without that column is running at the moment the constraint takes
effect. Since migrations run once, before the rolling update begins (`SKILL.md`'s
"Running Migrations in the Pipeline"), and the *old* code is still live at that exact
moment, a single-step `NOT NULL` add breaks every `INSERT` the old pods are still
issuing until they are fully drained — a self-inflicted outage during the safest-looking
part of the release. Splitting the same change across **two deploys**, each with its own
migration, guarantees that whichever code is live at any instant — old, new, or the
mixed population mid-rollout — is running against a schema shape it was written to
tolerate. The migration count is incidental; the deploy count is what matters.

---

## 2. The Full NOT-NULL-Column Sequence

Scenario: `data_assets.classification_note` must become mandatory. Three artifacts, two
deploys.

**Deploy 1 — Expand.** Migration adds the column nullable; new application code (already
part of this same deploy) starts writing it on every new/updated row, while still
reading it as optional (a `NULL` from an old row is expected and handled).

```sql
-- 00005_data_assets_add_classification_note.sql
-- +goose Up
ALTER TABLE data_assets ADD COLUMN classification_note text;

-- +goose Down
ALTER TABLE data_assets DROP COLUMN classification_note;
```

This step alone is 100% safe in a single deploy — additive, nullable, no lock beyond a
brief catalog update (Postgres 11+ adds a nullable column without a table rewrite).

**Backfill — an application-level batch job, not a migration.** The rule: a backfill
that touches an unbounded or large number of existing rows runs as an **application-level
job**, never as a bare `UPDATE ... WHERE classification_note IS NULL` inside the
migration transaction. An unthrottled single-statement `UPDATE` against a live table
holds row locks and generates WAL/replication traffic for its entire duration, and a
migration is expected to run and complete in seconds as a blocking pre-deploy step
(`SKILL.md`'s "Running Migrations in the Pipeline") — a multi-minute backfill migration
turns that fast gate into a deploy-blocking outage window of its own. Only a backfill
that is provably small and bounded (a handful of rows, a lookup/reference table) may run
as a plain `UPDATE` inside the migration itself; anything scaling with production data
volume is a job:

```go
// cmd/backfill-classification-note/main.go — run once, after Deploy 1, before Deploy 2.
// Idempotent (safe to re-run: only touches rows still NULL) and batched (bounded lock
// and replication-lag impact per iteration, never one giant transaction).
for {
    tag, err := pool.Exec(ctx, `
        UPDATE data_assets
           SET classification_note = default_note_for(sensitivity_level)
         WHERE id IN (
             SELECT id FROM data_assets
              WHERE classification_note IS NULL
              ORDER BY id
              LIMIT 500
              FOR UPDATE SKIP LOCKED
         )`)
    if err != nil { return fmt.Errorf("backfill batch: %w", err) }
    if tag.RowsAffected() == 0 { break } // done
    time.Sleep(100 * time.Millisecond)    // bound replication lag / lock contention
}
```

`FOR UPDATE SKIP LOCKED` here plays the same role it plays in the outbox relay
(`go-event-publisher`'s `references/transactional-outbox-standard.md` §4): a
concurrently-running second instance of the same job — an operator re-running it, or a
retry after a crash — claims a disjoint set of rows instead of blocking on or
double-processing the first run's in-flight batch.

**Deploy 2 — Contract, later.** Once the backfill job reports zero remaining `NULL`
rows and the application code deployed in step 1 has been live long enough that no
in-flight request could still be writing a `NULL`, a separate, later migration enforces
the constraint:

```sql
-- 00006_data_assets_classification_note_not_null.sql
-- +goose Up
-- A validated CHECK constraint proves the invariant with a SHARE UPDATE EXCLUSIVE
-- lock (blocks other schema changes, not ordinary reads/writes) instead of the
-- ACCESS EXCLUSIVE lock + full-table scan a direct SET NOT NULL would take on an
-- unvalidated column.
ALTER TABLE data_assets
    ADD CONSTRAINT classification_note_not_null
    CHECK (classification_note IS NOT NULL) NOT VALID;

ALTER TABLE data_assets
    VALIDATE CONSTRAINT classification_note_not_null;

-- +goose Down
ALTER TABLE data_assets DROP CONSTRAINT classification_note_not_null;
```

The `NOT VALID` / `VALIDATE CONSTRAINT` split is a real, documented PostgreSQL
optimization: `ADD CONSTRAINT ... NOT VALID` takes only a brief `ACCESS EXCLUSIVE` lock
to register the constraint (no scan), then `VALIDATE CONSTRAINT` scans the table under
`SHARE UPDATE EXCLUSIVE` — a lock level that permits concurrent reads *and* writes,
unlike the full-table-scanning `ALTER COLUMN ... SET NOT NULL` would take on its own.
A validated `CHECK (col IS NOT NULL)` is functionally equivalent to `NOT NULL` for every
purpose the application cares about (Postgres's planner and every INSERT path enforce
it identically); stop here in the common case. If a later need arises for the column to
report `NOT NULL` in catalog/ORM introspection specifically, a final migration's
`ALTER TABLE ... ALTER COLUMN ... SET NOT NULL` is fast rather than a second full scan
— Postgres detects the already-validated CHECK constraint proves the invariant and
skips re-scanning.

---

## 3. Second Worked Example — Renaming a Column

Renaming `file_path` to `source_uri` is a **remove** (of the old name) disguised as a
rename, and gets the same two-deploy treatment:

| Deploy | Migration | Application code |
|---|---|---|
| 1 — Expand | Add `source_uri` (nullable); backfill from `file_path` (batch job, §2's pattern) | New code writes **both** columns on every write; reads `source_uri`, falling back to `file_path` if `NULL` |
| 2 — Contract | Drop `file_path` | Old code (which referenced `file_path`) has been fully drained; only new code remains live |

The write-both-read-new step in Deploy 1's application code is the part a naive
migration-only view of expand/contract misses entirely: the column split protects the
*schema*, but only application code that tolerates the intermediate (both-columns)
state protects the *deploy*. A migration file alone never guarantees this — it is a
code-review obligation on the pull request that ships Deploy 1, not something `goose`
can check.

---

## 4. The Backward-Compatibility Rule, Stated Generally

Generalizing from both examples: at every point between a migration's `goose up` and
the *next* deploy's rollout completing, the schema on disk must be a superset compatible
with both the currently-deployed code and whatever code is about to roll out over it.
A migration is safe to ship inside the deploy that also ships the code depending on its
new shape (adding a nullable column, adding a table, widening a type) — the migration
runs, then the rolling update begins, and the schema was already a superset before any
new pod started. A migration is **not** safe to ship in the same deploy as code that
stops tolerating the *old* shape (a `DROP`, a tightened constraint, a rename) — the old
pods still running during that same rollout are the exact `Backward Compatibility`
concern (`glossary-management`'s canonical term) applied to a schema instead of an API:
newer schema versions must not break the currently-deployed consumer, precisely because
migration apply and application rollout are two separate operations with no shared
transaction between them.
