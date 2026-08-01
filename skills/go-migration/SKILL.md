---
name: go-migration
description: >
  Teaches how to manage PostgreSQL schema migrations for a Go service to a checkable
  engineering standard: the goose migration-tool convention (plain embedded SQL,
  5-digit sequential immutable file numbering — never timestamp-based — and why),
  the up/down reversibility standard and its one real exception (a genuinely
  data-destructive migration, handled via a rename-then-drop-later two-phase pattern
  with a documented manual-rollback runbook, never a Down block that silently
  discards data), the zero-downtime expand/contract pattern spanning two separate
  deploys — not just two migration files — for any breaking schema change (add
  column nullable, backfill via an application-level batch job, add the constraint
  in a later migration), the backward-compatibility standard (a migration must never
  break the currently-deployed application version, since migration apply and
  application rollout are not atomic together), and the index-creation standard
  (CREATE INDEX CONCURRENTLY always, why a blocking CREATE INDEX is unacceptable on
  a live table, and the NO TRANSACTION / invalid-index operational wrinkle
  CONCURRENTLY carries). Full worked NOT-NULL-column and column-rename sequences in
  references/expand-contract-and-zero-downtime.md; the irreversible-migration runbook
  pattern in references/reversibility-and-irreversible-migrations.md; lock modes and
  invalid-index recovery in references/concurrent-index-and-lock-safety.md.
  Implements the data-architect's data-model-design schemas as ordered migration
  files, including the outbox table go-event-publisher's Transactional Outbox
  depends on. Used by the backend-engineer during Implement.
version: 2.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, migration, postgresql, goose, expand-contract, zero-downtime, backward-compatibility, concurrent-index, reversibility]
produces: schema-migration
domain: backend
status: stable
related: [go-repository-pattern, go-event-publisher, go-event-consumer, go-service-layer, multi-tenancy-design, data-model-design, glossary-management]
---

# Go Migration

## Purpose

A schema is code: versioned, applied in order, the same way in every environment —
reproducible and auditable, since anyone rebuilds it from zero by replaying history.
This skill turns the data-architect's `data-model-design` schemas into ordered
migration files and governs how they apply **safely**: reversibly where possible,
without downtime where a change would otherwise break one, and never assuming
migration apply and application deploy are the same atomic event.

---

## Tooling & File-Naming Standard

Default to **goose** (`github.com/pressly/goose`) — plain SQL, embeddable via
`embed.FS`, no ORM DSL. `golang-migrate` is an acceptable alternative; the standard
below applies either way.

**Naming is sequential, not timestamp-based:** 5-digit zero-padded integer,
underscore, lower-`snake_case` imperative description, `.sql` —
`00001_create_data_assets.sql`. Next number = current highest + 1, chosen at
authorship — readable as order in git history, unlike `golang-migrate`'s
`20260725101500_desc.sql` timestamp convention. The tradeoff is a possible
same-number collision across branches; goose's duplicate-version check catches it
the moment both land on `main`, failing CI's fresh-database apply rather than
surfacing as a runtime error. Migrations are embedded so the binary carries its own
history:

```go
//go:embed migrations/*.sql
var migrationsFS embed.FS
```

---

## Up/Down Reversibility Standard

Every migration has both `Up` and `Down`, and **`Down` is exercised in CI** —
`goose up`→`down`→`up` against a fresh database, not merely present and untested;
local resets and `go-integration-test`'s Testcontainers instances depend on it
working. Production itself never runs `Down` — it rolls **forward** only, since
`Down` against live data risks the exact loss the standard prevents (a rollback
`DROP COLUMN` destroys what it protected). To undo a bad production change, write a
new forward migration that corrects it.

**The one real exception: a data-destructive drop cannot be truly inverted** — no SQL
reconstructs rows that are physically gone. The standard never attempts that
impossible inverse in one migration; it splits the change into a reversible archive
step (rename; fully recoverable) and a small, separately reviewed, irreversible drop
whose `Down` fails loudly (`RAISE EXCEPTION`) instead of silently returning an empty
column that looks fine. Full pattern, retention-window discipline, and the production
manual-rollback runbook (always a new forward migration, never a `Down`):
`references/reversibility-and-irreversible-migrations.md`.

---

## Zero-Downtime Standard: Expand/Contract Across Deploys

A breaking schema change spans **two deploys**, not two migration files — the deploy
is the unit that matters, because a rolling update runs old and new application code
concurrently against one schema for the whole rollout window, and only application
code written to tolerate both states protects that window. Minimum sequence for the
common case (adding a required column):

| Step | What | Where |
|---|---|---|
| Expand (Deploy 1) | Add the column nullable | Migration |
| Backfill | Populate existing rows | **App-level batch job** — never a bare `UPDATE` inside the migration; unthrottled, it turns a should-be-seconds migration into a lock-holding, deploy-blocking one |
| Contract (Deploy 2, later) | Add the constraint (`NOT VALID` CHECK + `VALIDATE CONSTRAINT` — light lock, no full scan) | Migration |

| Change | Safe in one deploy? | Approach |
|---|---|---|
| Add nullable column | Yes | Single additive migration |
| Add required column | No | Nullable → app-level backfill → constrain (later deploy) |
| Drop column/table | No | Two-phase reversible-archive-then-drop |
| Rename column | No | Expand (add + dual-write) / Contract (drop old, later deploy) |
| Add index | Yes, with `CONCURRENTLY` | See Index-Creation Standard, below |

Full worked NOT-NULL sequence (incl. the `NOT VALID`/`VALIDATE CONSTRAINT` Postgres
optimization) and column-rename example: `references/expand-contract-and-zero-downtime.md`.

---

## Backward-Compatibility Standard & the Pipeline

Migration apply and application rollout are **not atomic together**: migrations run
as a discrete CD step, a Kubernetes Job (or init step) — never from inside the app's
request path — and only once that Job completes does a separate rolling update begin.

```
deploy:
  1. run migrations (forward)          # schema now compatible with BOTH old and new code
  2. rolling-update the application    # new code takes over
```

A failed migration aborts the deploy before new code serves traffic. Because the two
steps aren't atomic, at every point between a migration landing and the rollout
completing the schema must be a superset compatible with **both** the
currently-deployed code and the code replacing it. Additive changes (nullable column,
new table, new index) are safe in the same deploy as the code that starts using them.
A change that stops tolerating the *old* shape (drop, rename, tightened constraint)
must never land in the same deploy as the code that stops depending on it —
`Backward Compatibility` (`glossary-management`'s canonical term) applied to a
schema, not just an API.

---

## Index-Creation Standard

Unqualified `CREATE INDEX` takes a `SHARE` lock for the build's full duration,
blocking every `INSERT`/`UPDATE`/`DELETE` — not a risk gated behind unusual load, the
default on every table, every time. The standard is therefore `CREATE INDEX
CONCURRENTLY`, always, for any table that can't be proven to stay empty:

```sql
-- +goose NO TRANSACTION
-- +goose Up
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_data_assets_tenant_sensitivity
    ON data_assets (tenant_id, sensitivity_level) WHERE deleted_at IS NULL;
-- +goose Down
DROP INDEX CONCURRENTLY IF EXISTS idx_data_assets_tenant_sensitivity;
```

Two wrinkles: `CONCURRENTLY` **cannot run inside a transaction block**, requiring the
file-scoped `-- +goose NO TRANSACTION` directive (goose otherwise wraps every
migration in one); and an interrupted or failed build leaves an **invalid index** —
space and write overhead, silently skipped by the planner — that must be manually
`DROP INDEX CONCURRENTLY`'d before retrying, never assumed safe to just rerun. Lock
modes and the recovery query in full: `references/concurrent-index-and-lock-safety.md`.

---

## Tenant-Aware Migration

In physical multi-tenancy (`multi-tenancy-design`), the same migration set applies to
**every tenant database**; the control plane iterates tenants and records a
per-tenant schema version. A migration isn't "done" until every tenant is migrated —
partial rollouts are tracked and alertable, not silently left behind.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| File naming | 5-digit sequential, `snake_case`, no timestamp scheme | Mixed numbering or timestamp-prefixed file | `ls migrations/` — one increasing integer sequence |
| Plain SQL, embedded | Reviewable SQL via `embed.FS` | ORM-generated/opaque migration | Read the file; confirm SQL, confirm `//go:embed` |
| Immutable | Merged migrations never edited; corrections are new files | A diff modifying an already-applied migration | `git log -p` on the file shows only its initial commit |
| Down tested in CI | `goose up`→`down`→`up` round-trip runs in the pipeline | `Down` present but never executed | CI config has the round-trip step |
| Irreversible drops two-phased | Archive (reversible) then drop (isolated, `Down` fails loudly), as separate migrations | One migration drops data with a `Down` that "restores" an empty object | Any `DROP COLUMN`/`DROP TABLE` migration has a preceding archive migration |
| Forward-only prod | Production rolls forward; fixes are new migrations | `Down` run against production data | Deploy pipeline has no path invoking `goose down` in prod |
| Expand/contract spans deploys | Breaking change's two halves ship in separate deploys; app code tolerates the intermediate schema | Drop/rename/tighten in the same deploy as the code depending on it | Read both PRs; confirm separate deploys |
| Backfill is app-level | Large/unbounded backfills run as a batch job | Migration's `Up` runs an unbounded `UPDATE` | Read migration for `UPDATE ... WHERE` scaling with table size |
| Concurrent index builds | Any index on a live-eligible table uses `CONCURRENTLY` + `NO TRANSACTION` | Plain `CREATE INDEX` on such a migration | Check every index migration for the directive |
| Pre-deploy application | Migrations run as a Job before rollout | App auto-migrates on startup | Deploy manifest has a migration step preceding rollout |
| Tenant coverage | Every tenant DB migrated; version tracked | Some tenant databases left behind | Control-plane migration-status record shows 100% |

---

## Anti-Patterns

- **Editing an applied migration** — environments that ran it disagree with git about "version N"; rebuild-from-zero diverges.
- **Auto-migrating on app startup** — N replicas race on rollout; failure surfaces as crash-looping, not a clean pre-deploy stop.
- **`Down` as a production rollback plan** — a `DROP COLUMN` "rollback" destroys the data it was meant to protect.
- **Drop/rename in the same deploy as the code change** — old and new code run simultaneously; one is guaranteed broken.
- **A migration-level `UPDATE` as the backfill** — locks a live table for the migration's run instead of a bounded job.
- **Plain `CREATE INDEX` on a live table** — blocks every write for the build's duration; `CONCURRENTLY`, always.
- **Retrying a failed `CONCURRENTLY` build without dropping the invalid index first** — dead overhead accumulates unnoticed.
- **`NOT NULL` with no backfill step** — the constraint add fails or locks existing rows.
- **Migrations that reference application code** — must stay replayable years later; Go domain types couple schema to code history.

---

## Output Format

Every migration file follows the naming standard, carries both `Up` and `Down`; a
`CONCURRENTLY` statement carries `-- +goose NO TRANSACTION` and nothing else in the
file; an irreversible drop is its own migration whose `Down` raises rather than fakes
a restore.

```
migrations/0000N_*.sql                        (Up/Down per change, per the standards above)
internal/infrastructure/postgres/migrate.go   (embed.FS + goose runner)
```

Full standards: `references/expand-contract-and-zero-downtime.md` (deploy-spanning
worked examples), `references/reversibility-and-irreversible-migrations.md`
(irreversible-drop pattern, CI round-trip, production runbook), and
`references/concurrent-index-and-lock-safety.md` (lock modes, invalid-index recovery).
