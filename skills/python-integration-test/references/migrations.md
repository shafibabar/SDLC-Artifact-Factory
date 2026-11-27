# Migration Tests

Self-contained. Use when a schema migration is added or changed (`python-migration` owns how revisions are written). Run with Alembic 1.20.1 on PostgreSQL 17.12.

## What to prove

| Proof | How |
|---|---|
| Revisions apply to an empty database | The harness runs `upgrade head` before any test; a broken revision errors the run |
| `downgrade` works | Own database: down to `base`, check the tables are gone, upgrade, check they are back |
| The release now running survives the new schema | Own database: downgrade to the previous revision, run that release's statements, upgrade, run them again, then run the new code over old and new rows |

Schema changes go through the same pipeline as code and must work for the current and the previous version, because migration and rollout are not one instant (Humble and Farley).

## Rules

- Migration tests are plain `def` tests: `env.py` calls `asyncio.run`, which fails inside an async test. Use `asyncio.run` for the test's own queries (`postgres_server.run` for one statement).
- The URL comes from the harness. `python-migration`'s `env.py` takes a URL set by the caller first; the harness also sets `DATABASE_URL` to the same container for the duration of the call, and then checks the version table exists in that database. Seen: an `env.py` that redirected to another database failed with `migrations did not reach ...`. The check cannot catch a database that already had a version table, so keep `env.py` as the owning skill writes it.
- Keep the previous release's statements as literal copies in the test. Calling today's repository proves nothing about yesterday's.
- Seed rows **before** applying the new revision: an empty table hides backfill and constraint problems. Seen: a new `NOT NULL` column without a default failed the upgrade on the seeded row.
- A revision with a backfill asserts the backfilled values. Backfills run as application jobs (`python-migration`); test the job against the same database.
- A deliberately irreversible `downgrade` (it raises) is asserted to raise, and the round trip stops above it.
- Roles and other server-wide objects survive across databases in one container: make their creation tolerate "already exists".
- Every migration test uses its own database. Every other database test keeps rollback.

Lock duration and `CREATE INDEX CONCURRENTLY` behaviour on large live tables are not proven by a small test database; state that as unproven.
