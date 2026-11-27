# Database Isolation

Self-contained. Use for any test touching PostgreSQL. The policy belongs to `test-fixture-design`; this file shows how it plays out against a real server. Behaviour marked "observed" was run on PostgreSQL 17.12 with pgx v5.13.0.

## Contents
Choosing; making code testable in a transaction; what rollback cannot show; real commits; leftovers; tenants.

## Choosing

| Order | Isolation | When |
|---|---|---|
| 1 | Roll back the test's transaction | Default |
| 2 | Savepoint inside it | Code under test opens its own transaction and accepts a `pgx.Tx` as the opener with no change to its production shape |
| 3 | Real commit, scoped keys, filtered cleanup | The subject is commit behaviour, or another connection or process must see the rows |
| 3 | Real commit, own database (`NewDatabase`) | The code reads every row (relay, scheduler, consumer), or the test changes the schema |

Never: a container per test, `TRUNCATE`, a schema reset of the shared database. The PostgreSQL module's `Snapshot`/`Restore` is such a reset: it restores the whole configured database, so it suits only a container no other test is using at that moment, never the harness's shared one (observed: it also cuts connections held across it, `57P01`). Write the reason for a real commit as a comment on the test.

## Making code testable in a transaction

The repository takes what both a pool and a transaction satisfy (`go-repository-pattern`: `NewXRepo(pool).WithTx(tx)`). A handler that opens transactions takes an interface with `Begin`; on a `pgx.Tx`, `Begin` creates a savepoint. If code accepts only a pool, that is a production design change to raise, not a reason to switch isolation quietly. One transaction is never shared between goroutines or parallel tests.

## What rollback cannot show (all observed)

| Behaviour | Consequence |
|---|---|
| Other connections never see the writes | Commit, relay and consumer behaviour cannot be proven; absence assertions pass for nothing |
| A failed statement aborts the transaction (`25P02`) | Run the expected failure in a savepoint, then roll that back |
| `DEFERRABLE INITIALLY DEFERRED` constraints are checked at commit | A violation passes; test it with a real commit |
| `now()` stays the same for the whole transaction | Ordering by timestamp is not exercised |
| Sequences are not rolled back | Never assert generated numbers |
| `set_config(..., true)` outlives a released savepoint | A setting made by code under test stays for the rest of the test; set it explicitly before each check |
| A second uncommitted insert of the same unique key waits | Parallel tests use distinct values |

## Real commits

- Register cleanup before the first write (`testdb.Scoped`), one delete per table the test or the code writes, children first, each filtered by the test's key. A failed delete fails the test.
- Derive keys from the test's name (`testdb.ID`), so a failure replays.
- To prove atomicity, make the second write fail for real (in an own database, add a constraint the event insert violates) and assert that **neither** row exists. Observed: calling the repository on the pool instead of the transaction leaves 1 job and 0 events, and the test fails.
- To force two writers to overlap without sleeping: hold the first transaction open, start the second in a goroutine, poll `pg_stat_activity` until it waits on a lock, then commit the first.

## Leftovers

The harness counts rows in every table of the shared database before and after a package and fails the run on a difference. Observed output after a test that committed and did not clean up: `tests changed the shared database: "public"."jobs": 0 rows before, 1 after`. The test itself still shows PASS; the package fails. It cannot see updated rows, changes that net to zero, new empty tables, or other databases, and it does not run if the process panics.

## Tenants

Assume no tenancy model: take it from the tenancy design (`multi-tenancy-design`), and invent no `tenant_id` where there is none. Where tenants share tables, every isolation test seeds two and checks both that each reads its own and that neither reads or writes the other's. Where PostgreSQL row-level security enforces it, switch to the application role first: superusers (the container's default user) and roles with `BYPASSRLS` bypass policies, and a table's owner bypasses them unless row security is forced.
