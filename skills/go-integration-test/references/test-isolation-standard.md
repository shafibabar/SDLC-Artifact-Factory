# Test Isolation Standard: Transaction Rollback, Schema Reset, Fresh Container

Full material for `SKILL.md`'s "Test Isolation Standard" section. Self-contained.
States the three candidate isolation strategies, this repo's chosen default, and
the one class of test that cannot use it.

---

## 1. The Three Candidate Strategies

Once `testcontainers-setup-standard.md` establishes one shared container per test
package, something still has to keep test A's writes from being visible to test
B running against that same container. Three strategies exist:

| Strategy | Mechanism | Isolation | Speed | Parallel-safe? |
|---|---|---|---|---|
| **Fresh container per test** | A new Postgres/Redpanda container for every test function | Perfect | ~1–3s per test — rejected in `testcontainers-setup-standard.md` §2 | Yes, trivially — but for the wrong reason (isolation via brute force, not design) |
| **Schema reset per test** | Drop and re-migrate the schema (or `TRUNCATE` every table) between tests | Good, but a reset itself takes tens to hundreds of milliseconds and serializes any test that must wait for a reset in progress | Moderate — cheaper than a fresh container, still the slowest of the two remaining options at real scale | Poor — concurrent tests fighting over one schema's reset either serialize or race |
| **Transaction rollback per test** | Wrap each test in a database transaction; the test's repository calls happen inside it; roll back in `t.Cleanup` — nothing is ever committed | Full — a rolled-back transaction's writes were never visible to any other transaction | Fast — a `BEGIN`/`ROLLBACK` pair costs microseconds, not seconds | Yes — each test holds its own transaction against the one shared container; concurrent transactions don't observe each other's uncommitted writes |

## 2. This Repo's Default: Transaction Rollback Per Test

```go
func withTx(t *testing.T, pool *pgxpool.Pool) pgx.Tx {
    t.Helper()
    ctx := context.Background()
    tx, err := pool.Begin(ctx)
    require.NoError(t, err)
    t.Cleanup(func() { _ = tx.Rollback(ctx) })   // never committed — always rolled back
    return tx
}

func TestDataAssetRepo_Save_OptimisticConcurrency(t *testing.T) {
    tx := withTx(t, testPool)
    repo := postgres.NewDataAssetRepo(tx)   // repo takes a Querier/DBTX interface, not *pgxpool.Pool
    // ...arrange, act, assert as usual — everything this test writes vanishes at t.Cleanup...
}
```

This is the default for every Postgres-backed integration test in this repo. It
requires one structural precondition, already required by `go-repository-pattern`:
a repository constructor accepts a narrow `Querier`/`DBTX` interface (satisfied by
both `*pgxpool.Pool` and `pgx.Tx`) rather than a concrete pool type — the same test
double that lets production code run against the pool and a test run against an
open transaction with zero code change in the repository itself.

**Why this beats schema reset at this repo's scale:** a schema reset pays a fixed
cost *per test*, proportional to schema size and row counts. A transaction rollback
pays a near-zero cost regardless of schema size, because it never touches the
schema at all — it discards uncommitted row versions, which PostgreSQL's MVCC
already tracks for free.

## 3. When It Breaks Down — the Real-Commit Exception

The wrapping-transaction trick has exactly one class of test it cannot serve:
**a test whose entire purpose is verifying commit/transaction-boundary behavior
itself** — for example, an outbox test proving a domain-state write and its outbox
row commit atomically in one transaction (`go-event-publisher`), or a concurrency
test proving two goroutines each see the other's *committed* row. If the test
itself never commits, there is nothing for a second transaction, a second
goroutine, or the outbox relay's own polling query to observe — the behavior under
test cannot occur inside an uncommitted wrapper.

Two exception-path options, in order of preference:

1. **Savepoint-based nested transaction.** The test opens its own outer
   transaction as usual, but the code under test issues its own inner
   transaction via `SAVEPOINT`/`RELEASE SAVEPOINT` rather than a top-level
   `BEGIN`/`COMMIT`. This preserves rollback-per-test at the outer level while
   still exercising real partial-commit/rollback semantics at the inner level.
   Reach for this only when the code under test can be adapted to a savepoint
   without changing its production transaction shape — never restructure
   production code just to make a test's isolation strategy work.
2. **Per-test tenant scoping against real commits.** Fall back to the pattern
   already in this repo's `test-fixture-design`-driven hermetic seeding: a
   `freshTenant(t, pool)` helper issues a unique tenant id, the test commits for
   real against the shared package container, and `t.Cleanup` deletes only that
   tenant's rows afterward. Isolation comes from the tenant boundary, not from an
   uncommitted transaction — genuinely committed data with cleanup, the exception
   path, not the default.

Both options exist specifically for the outbox/consumer round-trip and CAS-conflict
tests already worked in `repository-and-event-testing.md` — reach for them only
when a test's own subject matter is commit behavior, never as a default because
"it seemed safer."

## 4. What Never Changes Regardless of Strategy

- **A test never reads data it did not create.** Whether isolation comes from an
  uncommitted transaction or a tenant-scoped commit, a test asserting against
  ambient rows it never seeded is a bug — it silently depends on execution order
  or a sibling test's leftovers, and fails the moment tests run with
  `-shuffle=on` or in a different package split.
- **Cleanup is always `t.Cleanup`, never a bare `defer` on the test function**,
  because container/tx lifecycle helpers may themselves be called from
  subtests — `t.Cleanup` runs after all of a test's subtests finish; a `defer` in
  the parent does not (see `go-unit-test`'s identical caution about parallel
  subtests and shared teardown).
