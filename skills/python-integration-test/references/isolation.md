# Database Isolation

Self-contained. Use for any test touching PostgreSQL. The policy belongs to `test-fixture-design`; this file shows how it plays out with asyncpg. Behaviour marked "seen" was run on PostgreSQL 17.12 with asyncpg 0.32.0.

## Contents
Choosing; making code testable in a transaction; what rollback cannot show; real commits; leftovers; tenants.

## Choosing

| Order | Isolation | Fixture | When |
|---|---|---|---|
| 1 | Roll back the test's transaction | `db` | Default |
| 2 | Savepoint inside it | `db`, `one_pool` | Code under test opens its own transaction and can run nested with no change to its production shape |
| 3 | Real commit, scoped keys, filtered cleanup | `pool` + `scoped` | The subject is commit behaviour, or another connection or process must see the rows |
| 3 | Real commit, own database | `own_database`, `own_pool` | The code reads every row (relay, scheduler, consumer), or the test changes the schema |

Never: a container per test, `TRUNCATE`, an unfiltered `DELETE`, a schema drop of the shared database. Write the reason for a real commit in the test's docstring. One exception in one test changes nothing for the others: they stay on rollback.

## Making code testable in a transaction

- A repository that takes the caller's connection (`python-repository-pattern`) is built on `db`. Its caller's `async with conn.transaction()` nests as a savepoint; releasing it commits nothing.
- A Unit of Work that takes a pool and calls `acquire()` and `release()` (`python-service-layer`) is built on `one_pool`, which hands out the test's connection, so no production change is needed.
- One connection is never used by two coroutines at once. Requests that must overlap need `pool` and real commits.
- Code that creates its own pool internally cannot be rolled back: raise that as a production design change; do not switch isolation quietly.

## What rollback cannot show

| Behaviour (seen) | Consequence |
|---|---|
| Other connections never see the writes | Commit, relay and consumer behaviour cannot be proven; absence assertions pass for nothing |
| A failed statement aborts the transaction (`25P02`) | Run the expected failure inside `async with db.transaction()` (a savepoint), with `pytest.raises` outside it |
| A `DEFERRABLE INITIALLY DEFERRED` violation goes unnoticed | Test it with a real commit |
| `now()` stays the same for the whole transaction | Ordering by timestamp is not exercised |
| Sequences are not rolled back | Never assert generated numbers |
| `set_config(..., true)` outlives a released savepoint | A setting made by code under test stays for the rest of the test; set it explicitly before each check |
| A second uncommitted insert of the same unique key waits | Concurrent runs sharing a database use distinct values |

## Real commits

- Call `scoped(key, ...)` before the first write, once per key, one `DELETE` per table the test or the code writes, children first, each filtered by `$1`. A failed delete fails the test.
- Derive keys from `test_id`, so a failure replays.
- To prove atomicity, make the second write fail for real (in an own database, add a constraint the event insert violates) and assert that **neither** row exists. Seen: with the unit of work opening no transaction, the result was 1 job and 0 events, and the test failed.
- To force two writers to overlap without sleeping: hold the first transaction open, start the second as a task, `poll_until` `pg_stat_activity` shows it waiting on a lock, then commit the first.

## Leftovers

The session fixture counts rows in every table of the shared database before and after, and errors at teardown on a difference. Seen after one cleanup statement was removed: the test showed passed, then `tests changed the shared database: public.idempotency_keys: 0 rows before, 1 after`, and the run failed. It cannot see updated rows, changes that net to zero, new empty tables or other databases, and it does not run if the process dies. Under `pytest-xdist` each worker checks its own container.

## Tenants

Assume no tenancy model: take it from the tenancy design (`multi-tenancy-design`), and invent no `tenant_id` where there is none. Where tenants share tables, seed two and prove, **through the product's own repository or route** acting as each tenant, that it reads its own and neither reads nor changes the other's. A test that runs its own `WHERE tenant_id` query proves only that query.

Where row-level security enforces it:

- switch to the application role first (`SET LOCAL ROLE`): superusers, which the container's user is, and `BYPASSRLS` roles bypass policies;
- keep a second test whose statements have **no** tenant filter. Seen: with the policy opened to `true`, the repository test still passed because of its own filter; only the unfiltered statements caught it. With the filter removed instead, the policy kept both green.

Where each tenant has its own database or schema, run the same product code against two of them and check neither result appears in the other.
