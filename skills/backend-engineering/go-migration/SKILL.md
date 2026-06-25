---
name: go-migration
description: >
  Teaches how to manage PostgreSQL schema migrations for a Go service — versioned,
  forward-only-in-production, reversible-in-development migrations using goose or
  golang-migrate, the expand/contract pattern for zero-downtime schema change,
  tenant-aware migration in physical multi-tenancy, and how migrations run safely
  in CI/CD ahead of the new code. Implements the data-architect's schemas as
  ordered migration files. Used by the backend-engineer during Implement.
version: 1.0.0
phase: implement
owner: backend-engineer
tags: [implement, go, migration, postgresql, goose, expand-contract, zero-downtime]
---

# Go Migration

## Purpose

A schema is code, and like code it changes over time — under version control, applied in order, the same way in every environment. Migrations make the database schema reproducible and auditable: anyone can rebuild the schema from zero by replaying the migration history, and every change is a reviewed file in git.

This skill turns the data-architect's `data-model-design` schemas into ordered migration files and defines how they apply safely — including without downtime.

---

## Tooling

Default to **goose** (`github.com/pressly/goose`) — plain SQL migrations, embeddable in the Go binary, no heavy runtime. `golang-migrate` is an acceptable alternative. Either way:

- Migrations are **plain SQL** files (reviewable by anyone, including a PM — no ORM DSL).
- Migrations are **embedded** in the binary via `embed.FS` so the deployed artifact carries its own schema history.
- Versioning is **sequential and immutable** — a migration, once merged, is never edited; corrections are new migrations.

```
migrations/
├── 00001_create_data_assets.sql
├── 00002_create_outbox.sql
├── 00003_create_processed_events.sql
└── 00004_add_data_assets_sensitivity_index.sql
```

```go
//go:embed migrations/*.sql
var migrationsFS embed.FS
```

---

## Migration File Shape

Each file has an `Up` and a `Down`. Up is what production applies; Down enables local/dev rollback and keeps changes reversible-by-design.

```sql
-- 00004_add_data_assets_sensitivity_index.sql
-- +goose Up
-- Build the index without locking writes (safe on a live table).
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_data_assets_tenant_sensitivity
    ON data_assets (tenant_id, sensitivity_level)
    WHERE deleted_at IS NULL;

-- +goose Down
DROP INDEX IF EXISTS idx_data_assets_tenant_sensitivity;
```

`CREATE INDEX CONCURRENTLY` avoids holding a write lock on a live table — essential for zero-downtime. (Note: it cannot run inside a transaction, so it lives in its own migration.)

---

## Forward-Only in Production

Production rolls **forward**, never down. A "down" migration on live data risks data loss (dropping a column discards data). To undo a bad change in production, write a new forward migration that corrects it. `Down` exists for development resets and as documentation of reversibility — not as a production rollback button.

---

## Expand / Contract (Zero-Downtime Schema Change)

A breaking schema change is split across **multiple deploys** so the old and new code both work against the intermediate schema. This is the schema analogue of the additive-event-evolution rule (`event-schema-design`).

Example — renaming `file_path` to `source_uri`:

| Phase | Migration | Code |
|---|---|---|
| **Expand** | Add `source_uri`; backfill from `file_path`; keep both | New code writes both columns; reads `source_uri` |
| **Migrate** | (data backfill job if large) | Old code drained out via rolling deploy |
| **Contract** | Drop `file_path` | Only new code remains |

Never rename or drop a column in the same deploy as the code that stops using it — that requires the impossible: old and new code running simultaneously against incompatible schemas.

| Change | Safe in one step? | Approach |
|---|---|---|
| Add nullable column | Yes | Single additive migration |
| Add NOT NULL column | No | Add nullable → backfill → add constraint |
| Drop column | No | Stop using in code (deploy) → drop (later migration) |
| Rename column | No | Expand/contract |
| Add index on large table | Yes, with care | `CREATE INDEX CONCURRENTLY` |

---

## Running Migrations in the Pipeline

Migrations apply as a **discrete CD step before** the new application version is rolled out — because expand/contract guarantees the new schema is compatible with the currently-running (old) code.

```
deploy:
  1. run migrations (forward)         # schema is now compatible with BOTH old and new code
  2. rolling-update the application    # new code takes over
```

Migrations run as a Kubernetes Job (or init step), not from inside the app's request path. A failed migration aborts the deploy before any new code serves traffic.

---

## Tenant-Aware Migration

In physical multi-tenancy (separate database/namespace per tenant — see `multi-tenancy-design`), the same migration set is applied to **every tenant database**. The control plane iterates tenants and runs migrations per tenant, recording per-tenant schema version. A migration is not "done" until every tenant is migrated; partial rollouts are tracked and alertable.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Versioned & immutable | Sequential files; merged migrations never edited | Editing an applied migration |
| Plain SQL, embedded | Reviewable SQL embedded via `embed.FS` | ORM-generated opaque migrations |
| Forward-only prod | Production rolls forward; fixes are new migrations | Running `Down` against production data |
| Zero-downtime | Breaking changes use expand/contract across deploys | Drop/rename in the same deploy as the code change |
| Concurrent index builds | Large-table indexes use `CONCURRENTLY` | Index build locking a live table |
| Pre-deploy application | Migrations run before the new code rolls out | App auto-migrating on startup in the request path |
| Tenant coverage | Every tenant DB migrated; version tracked | Some tenant databases left behind |

---

## Output Format

Produces SQL migration files plus the embed/runner glue:

```
migrations/0000N_*.sql          (Up/Down per change)
internal/infrastructure/postgres/migrate.go   (embed.FS + goose runner)
```
