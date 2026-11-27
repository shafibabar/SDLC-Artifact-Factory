# Migration Tests

Self-contained. Use when a schema migration is added or changed (`go-migration` owns how migrations are written). Run with goose v3.30.2.

## What to prove

| Proof | How |
|---|---|
| Migrations apply to an empty database | The harness applies them in `StartPostgres`; a broken one fails the package |
| `Down` works | Own database: down to 0, check the tables are gone, up again, check they are back |
| The release now running survives the new schema | Own database: go down to the previous version, run that release's statements, apply the new migration, run them again, then run the new code over old and new rows |

Schema changes go through the same pipeline as code and must work for the current and the previous version, because migration and rollout are not one instant (Humble and Farley).

- Keep the previous release's statements as literal copies in the test. Calling today's repository proves nothing about yesterday's.
- Observed: making the new column `NOT NULL` without a default fails the test at the previous release's insert (`23502`).
- Seed rows **before** applying the migration: an empty table hides backfill and constraint problems.
- A migration with a data backfill asserts the backfilled values.
- A deliberately irreversible `Down` (`go-migration`) is asserted to fail, and the up/down test stops above it.
- Roles and other server-wide objects survive across databases in one container: make their creation tolerate "already exists", including a concurrent creation.
- Every migration test uses its own database. Every other database test keeps rollback.

Lock duration and online index builds on large tables are not proven by an empty test database; state that as unproven.
