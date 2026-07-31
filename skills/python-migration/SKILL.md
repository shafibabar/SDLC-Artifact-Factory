---
name: python-migration
description: >
  Teaches the backend-engineer to manage schema migrations with Alembic — used as a
  migration runner over hand-written SQL (not paired with the SQLAlchemy ORM), the
  expand/contract pattern for backward-compatible changes, tenant-aware migrations,
  and forward-only-in-production discipline. The Python analog of go-migration.
  Alembic is adopted purely as the revision-runner CLI: revisions written with
  op.execute("...raw SQL...") upgrade/downgrade blocks, autogenerate deliberately
  NOT used (it requires SQLAlchemy ORM metadata this repo does not have, since
  python-repository-pattern uses asyncpg directly). Covers the async env.py wiring
  for asyncpg, the down_revision chain that replaces goose's sortable 5-digit
  filename ordering, CREATE INDEX CONCURRENTLY via Alembic's autocommit_block,
  expand/contract across two deploys for a non-backward-compatible column change with
  an application-level backfill, and per-tenant application order under physical
  multi-tenancy. Setup, async env.py, and a worked hand-written revision in
  references/alembic-setup-and-revisions.md; the full expand/contract worked sequence
  and tenant application order in references/expand-contract-patterns.md. Used by the
  backend-engineer during Implement when Python is the selected backend language.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, migration, alembic, asyncpg, postgresql, expand-contract, zero-downtime, backward-compatibility, forward-only, multi-tenancy]
related: [go-migration, python-repository-pattern]
tools: [Bash]
---

# Python Migration

## Purpose

A schema is code: versioned, applied in order, the same way in every environment —
reproducible and auditable, since anyone rebuilds it from zero by replaying history.
This skill governs how Python services evolve their PostgreSQL schema with **Alembic**,
**safely**: reversibly where possible, without downtime where a change would otherwise
break one, and never assuming migration apply and application deploy are the same atomic
event. It is the Python analog of `go-migration` — the *discipline* is identical; only
the runner CLI and revision-file format differ.

---

## Tooling Standard: Alembic as a Runner Over Hand-Written SQL

Default to **Alembic** (`alembic`), used purely as a **migration runner over
hand-written SQL** — the same posture `go-migration` takes toward goose. Alembic ships
paired with SQLAlchemy in the book's default story; this repo rejects that pairing.
`python-repository-pattern` uses `asyncpg` directly with `$1`-style parameterized SQL
and no ORM, so there is **no SQLAlchemy model metadata for Alembic to diff against**.

**Autogenerate is therefore off.** `alembic revision --autogenerate` compares live
schema to declarative ORM `MetaData`; with no ORM models it produces empty diffs and
tempts a team into adding ORM models solely to satisfy it. Author every revision by
hand with `alembic revision -m "..."` and write raw SQL inside `upgrade()` /
`downgrade()` via `op.execute("...")` — reviewable, and coupled to nothing in the
application layer.

**Revision identity differs honestly from goose.** goose orders by a sortable 5-digit
filename (`00001_...sql`) readable straight from `git log`. Alembic instead identifies
each revision by an opaque hash and links them through a `down_revision` pointer that
forms a chain — ordering lives in that chain, *not* in a sortable filename. Two
consequences to own: pin readable ids with `alembic revision --rev-id 0002 -m ...` so
files still sort, and know that two branches each adding a revision create **divergent
heads** requiring an explicit `alembic merge` (goose instead surfaces the analogous
collision as a duplicate-version CI failure). Full `alembic init`, the async `env.py`,
and a worked hand-written revision: `references/alembic-setup-and-revisions.md`.

## Async env.py for asyncpg

Alembic's migration-run core is **synchronous by design**, and `asyncpg` has no sync
mode — so running it requires bridging the async connection into Alembic's sync context,
a genuine wrinkle Go does not have (goose is sync end-to-end). The `env.py` uses
`async_engine_from_config` and hands the live async connection to Alembic's synchronous
migration routine. The exact bridging call and the complete async `env.py` are in
`references/alembic-setup-and-revisions.md` — copy it verbatim.

## Forward-Only-in-Production Standard

Every revision defines both `upgrade()` and `downgrade()`, and the round-trip
(`upgrade` → `downgrade` → `upgrade` against a fresh database) is **exercised in CI** —
`python-integration-test`'s `testcontainers-python` Postgres and local resets depend on
`downgrade()` actually working, not merely being present. **Production rolls forward
only.** `alembic downgrade` is never run against live production data — a downgrade
`DROP COLUMN` destroys exactly what a rollback was meant to protect. To undo a bad
production change, author a *new forward* revision that corrects it.

**The one real exception — a data-destructive drop cannot be truly inverted.** No SQL
reconstructs physically-deleted rows. Split such a change into a reversible archive
revision (rename; recoverable) and a small, separately reviewed, irreversible drop whose
`downgrade()` `op.execute`s a `RAISE EXCEPTION` — failing loudly rather than silently
faking a restore of an empty column.

---

## Zero-Downtime Standard: Expand/Contract Across Deploys

A breaking schema change spans **two deploys**, not two revisions — the deploy is the
unit that matters, because a rolling Kubernetes update runs old and new application
code concurrently against one schema for the whole rollout window. Minimum sequence for
adding a required column:

| Step | What | Where |
|---|---|---|
| Expand (Deploy 1) | Add the column nullable | Revision (`op.execute`) |
| Backfill | Populate existing rows | **App-level batch job** — never a bare `UPDATE` inside `upgrade()`; unthrottled it turns a seconds-long migration into a lock-holding, deploy-blocking one |
| Contract (Deploy 2, later) | Add the constraint (`NOT VALID` CHECK + `VALIDATE CONSTRAINT` — light lock, no full scan) | Revision |

| Change | Safe in one deploy? | Approach |
|---|---|---|
| Add nullable column | Yes | Single additive revision |
| Add required column | No | Nullable → app-level backfill → constrain (later deploy) |
| Drop column/table | No | Two-phase reversible-archive-then-drop |
| Rename column | No | Expand (add + dual-write) / Contract (drop old, later deploy) |
| Add index | Yes, with `CONCURRENTLY` | See Index-Creation Standard |

Full worked non-backward-compatible column change (incl. the `NOT VALID` /
`VALIDATE CONSTRAINT` optimization) and column-rename example:
`references/expand-contract-patterns.md`.

## Backward-Compatibility Standard & the Pipeline

Migration apply and application rollout are **not atomic together**: migrations run as
a discrete CD step — a Kubernetes `Job` running `alembic upgrade head`, never from
inside the app's request path — and only once that Job completes does a separate rolling
update begin.

```
deploy:
  1. run migrations (alembic upgrade head)   # schema now compatible with BOTH old and new code
  2. rolling-update the application          # new code takes over
```

A failed migration aborts the deploy before new code serves traffic. At every point
between a revision landing and the rollout completing, the schema must be a superset
compatible with **both** the currently-deployed code and the code replacing it. A change
that stops tolerating the *old* shape (drop, rename, tightened constraint) must never
land in the same deploy as the code depending on it — `Backward Compatibility`
(`glossary-management`'s canonical term) applied to a schema, not an API.

---

## Index-Creation Standard

Unqualified `CREATE INDEX` takes a `SHARE` lock for the build's full duration, blocking
every write — the default on every table, every time. The standard is `CREATE INDEX
CONCURRENTLY`, always, for any table not provably empty. But `CONCURRENTLY` **cannot run
inside a transaction block**, and Alembic wraps each revision in one by default (its
`transaction_per_migration` behavior — the analog of goose's per-file transaction). The
Python fix is Alembic's `op.get_context().autocommit_block()` context manager (the
counterpart of goose's `-- +goose NO TRANSACTION` directive):

```python
def upgrade() -> None:
    with op.get_context().autocommit_block():
        op.execute(
            "CREATE INDEX CONCURRENTLY IF NOT EXISTS "
            "idx_data_assets_tenant_sensitivity "
            "ON data_assets (tenant_id, sensitivity_level) WHERE deleted_at IS NULL"
        )
```

An interrupted `CONCURRENTLY` build leaves an **invalid index** — write overhead,
silently skipped by the planner — that must be `DROP INDEX CONCURRENTLY`'d before
retrying, never assumed safe to rerun.

---

## Tenant-Aware Migration

In physical multi-tenancy (`multi-tenancy-design`), the same revision set applies to
**every tenant database**; the control plane iterates tenants (`alembic upgrade head`
per tenant DSN) and records a per-tenant schema version. A migration isn't "done" until
every tenant is migrated — partial rollouts are tracked and alertable. Tenant
application order and a control-plane sketch: `references/expand-contract-patterns.md`.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Hand-written SQL, no autogenerate | `op.execute("...SQL...")` revisions | `--autogenerate` output or ORM models added to feed it | Read the revision; confirm raw SQL, no `sa.Column(...)` diffing |
| Readable revision ids | `--rev-id` pins sortable ids; divergent heads merged explicitly | Opaque hashes only; unmerged multiple heads | `alembic heads` shows a single head |
| Immutable | Applied revisions never edited; corrections are new revisions | A diff modifying an already-applied revision | `git log -p` shows only its initial commit |
| Round-trip tested in CI | `upgrade`→`downgrade`→`upgrade` runs in the pipeline | `downgrade()` present but never executed | CI config has the round-trip step |
| Forward-only prod | Production rolls forward; fixes are new revisions | `alembic downgrade` run against production | Deploy pipeline has no `downgrade` path in prod |
| Irreversible drops two-phased | Archive (reversible) then drop (isolated, `downgrade` raises) | One revision drops data with a fake restoring `downgrade` | Any `DROP COLUMN`/`DROP TABLE` has a preceding archive revision |
| Expand/contract spans deploys | Breaking change's halves ship in separate deploys | Drop/rename/tighten in the same deploy as dependent code | Read both PRs; confirm separate deploys |
| Backfill is app-level | Large backfills run as a batch job | `upgrade()` runs an unbounded `UPDATE` | Read revision for `UPDATE ... WHERE` scaling with table size |
| Concurrent index builds | Index on a live-eligible table uses `CONCURRENTLY` inside `autocommit_block()` | Plain `CREATE INDEX`, or `CONCURRENTLY` without the autocommit block | Check every index revision |
| Pre-deploy application | `alembic upgrade head` runs as a Job before rollout | App auto-migrates on startup | Deploy manifest has a migration step preceding rollout |
| Tenant coverage | Every tenant DB migrated; version tracked | Some tenant databases left behind | Control-plane migration-status record shows 100% |

---

## Anti-Patterns

- **Using `--autogenerate`** — pulls the SQLAlchemy ORM back in through the side door; this repo's data-access layer has no ORM metadata to diff, so autogenerate is empty or misleading.
- **Editing an applied revision** — environments that ran it disagree with git about "revision X"; rebuild-from-zero diverges.
- **Auto-migrating on app startup** — N replicas race on rollout; failure surfaces as crash-looping, not a clean pre-deploy stop.
- **`downgrade()` as a production rollback plan** — a `DROP COLUMN` "rollback" destroys the data it was meant to protect.
- **Leaving divergent Alembic heads unmerged** — two branches each add a revision; `upgrade head` becomes ambiguous until an explicit `alembic merge`.
- **Drop/rename in the same deploy as the code change** — old and new code run simultaneously; one is guaranteed broken.
- **A revision-level `UPDATE` as the backfill** — locks a live table for the migration's run instead of a bounded job.
- **`CREATE INDEX CONCURRENTLY` without `autocommit_block()`** — Alembic's wrapping transaction makes Postgres reject it outright.
- **Retrying a failed `CONCURRENTLY` build without dropping the invalid index first** — dead overhead accumulates unnoticed.

---

## Output Format

Every revision carries `upgrade()` and `downgrade()` with hand-written `op.execute` SQL;
a `CONCURRENTLY` statement sits inside an `autocommit_block()`; an irreversible drop is
its own revision whose `downgrade()` raises rather than fakes a restore.

```
alembic.ini                                   (script_location, no sqlalchemy.url secret in git)
migrations/env.py                             (async engine + asyncpg bridge — see references)
migrations/versions/0002_*.py                 (upgrade/downgrade per change, per the standards above)
```

Full standards: `references/alembic-setup-and-revisions.md` (init, async `env.py`, a
worked hand-written revision, the CI/Makefile `upgrade head` command) and
`references/expand-contract-patterns.md` (deploy-spanning column change, app-level
backfill, tenant application order).
