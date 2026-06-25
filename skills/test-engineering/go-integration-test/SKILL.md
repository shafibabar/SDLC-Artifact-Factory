---
name: go-integration-test
description: >
  Teaches how to write integration tests in Go using Testcontainers — verifying
  modules against real PostgreSQL, Redpanda, and other dependencies (not mocks),
  hermetic per-test seeding and cleanup, testing the repository's real SQL and
  optimistic concurrency, the outbox and idempotent consumer round-trips,
  test-trace correlation, and keeping the suite parallel-safe and CI-portable.
  Sits above unit in the pyramid; applied by the backend-engineer. Used during Implement.
version: 1.0.0
phase: implement
owner: test-strategist
tags: [implement, go, integration-test, testcontainers, postgres, redpanda, hermetic]
---

# Go Integration Test

## Purpose

Unit tests prove your logic; integration tests prove it works against the **real** dependencies — that the SQL actually runs on PostgreSQL, the optimistic-concurrency CAS actually conflicts, the outbox row actually publishes to Redpanda, and the idempotent consumer actually dedups on redelivery. Mocks can't catch a wrong column name, a broken migration, or a real transaction-isolation surprise; integration tests can.

This skill is authored by the test-strategist; the backend-engineer applies it for its repositories, publishers, and consumers (`go-repository-pattern`, `go-event-publisher`, `go-event-consumer`). The defining choice: real dependencies, spun up hermetically with Testcontainers.

---

## Testcontainers — Real Dependencies, Hermetically

Testcontainers-go starts a real PostgreSQL (or Redpanda) in a container for the test and tears it down after — so the test runs against the genuine engine, identically on a laptop and in CI, with no shared external database to pollute.

```go
func startPostgres(t *testing.T) *pgxpool.Pool {
    t.Helper()
    ctx := context.Background()
    pg, err := postgres.Run(ctx, "postgres:16-alpine",
        postgres.WithDatabase("test"), postgres.WithUsername("test"), postgres.WithPassword("test"),
        testcontainers.WithWaitStrategy(wait.ForListeningPort("5432/tcp")),
    )
    require.NoError(t, err)
    t.Cleanup(func() { _ = pg.Terminate(ctx) })          // container dies with the test

    dsn, _ := pg.ConnectionString(ctx, "sslmode=disable")
    pool, err := pgxpool.New(ctx, dsn)
    require.NoError(t, err)
    t.Cleanup(pool.Close)
    require.NoError(t, runMigrations(dsn))                // real migrations — proves they apply
    return pool
}
```

Running the real migrations in setup means a broken migration fails an integration test — migrations are verified, not assumed. A shared container per package (via `TestMain`) amortises startup cost while per-test tenant isolation keeps tests independent (see `test-fixture-design`).

---

## Testing the Repository for Real

The repository is the prime integration target — its correctness is in the SQL, which only a real database can verify.

```go
func TestDataAssetRepo_Save_OptimisticConcurrency(t *testing.T) {
    pool := startPostgres(t)
    repo := postgres.NewDataAssetRepo(pool)
    tenant := freshTenant(t, pool)
    ctx := withTenant(context.Background(), tenant)

    asset := seedAsset(t, pool, tenant)                  // version 1
    stale := mustLoad(t, repo, ctx, asset.ID())          // also version 1

    require.NoError(t, mutateAndSave(repo, ctx, asset))   // bumps to version 2

    // The stale copy must fail the compare-and-swap — proves real optimistic concurrency.
    err := mutateAndSave(repo, ctx, stale)
    require.ErrorIs(t, err, domain.ErrConcurrentModification)
}
```

This catches what a mock never could: the actual `WHERE version = $N` semantics, real constraint violations, and the genuine round-trip of types through pgx.

---

## Testing the Outbox + Consumer Round-Trip

The event path is integration by nature — it spans a transaction, a relay, the broker, and a consumer. Test it end to end with real PostgreSQL + Redpanda:

```go
func TestClassify_PublishesEvent(t *testing.T) {
    pool := startPostgres(t); broker := startRedpanda(t)
    // ... wire repo, outbox relay, and a consumer against the real broker ...

    require.NoError(t, classifyHandler.Handle(ctx, classifyCmd))   // writes state + outbox row (1 tx)
    relay.drainOnce(ctx)                                            // publishes the outbox row

    evt := awaitEvent(t, broker, "data-asset-classified", 5*time.Second)
    require.Equal(t, "DataAssetClassified", evt.EventType)

    // Redeliver the same event — the idempotent consumer must process it once.
    publishAgain(t, broker, evt)
    require.Equal(t, 1, countProcessed(t, pool, evt.EventID))       // dedup proven
}
```

The duplicate-delivery assertion is essential: at-least-once delivery *will* redeliver in production, so the idempotency must be proven against the real broker, not assumed.

---

## Hermetic Seeding and Cleanup

Every integration test seeds exactly the data it needs and cleans up (see `test-fixture-design`). With per-test tenant scoping, tests run in parallel against one container without colliding:

```go
tenant := freshTenant(t, pool)   // unique tenant_id; t.Cleanup deletes its rows
```

`onUnhandledRequest`-style strictness applies here too: a test that reads data it didn't create is a bug — fail loudly rather than depend on ambient state.

---

## Test-Trace Correlation

Inject a unique **test id** into the context/headers so an integration test's activity is traceable through the backend's OpenTelemetry spans (`distributed-tracing-design`). When a test fails, its trace id leads straight to the exact spans — diagnosis without a debugger (the valuable, frugal part of the blueprint's §4).

```go
ctx = withTestID(ctx, t.Name())   // propagates into spans/logs for failure correlation
```

---

## Parallel-Safe and CI-Portable

- **Parallel** via per-test tenant isolation; a shared container per package keeps it fast.
- **Portable**: Testcontainers needs only a Docker daemon — the same test runs on a laptop and in the CI runner with no external services to provision or clean.
- **Tagged**: integration tests are behind a build tag or `-short` guard so `go test -short` runs only fast unit tests for the inner loop, and the full suite runs in CI.

```go
func TestMain(m *testing.M) {
    if testing.Short() { os.Exit(0) }   // skip container tests in -short mode
    os.Exit(m.Run())
}
```

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Real dependencies | Testcontainers PostgreSQL/Redpanda | Mocked DB/broker called an "integration" test |
| Migrations verified | Real migrations run in setup | Schema hand-created, bypassing migrations |
| Concurrency proven | Optimistic-concurrency conflict actually tested | CAS assumed, never exercised |
| Idempotency proven | Duplicate delivery tested against real broker | Dedup assumed, not verified |
| Hermetic | Per-test tenant seed + cleanup; shuffle-green | Tests sharing/leaking data |
| Trace-correlated | Test id propagated into telemetry | Failures with no trace to follow |
| CI-portable & tagged | Docker-only; `-short` skips them | Depends on an external shared DB |

---

## Output Format

Produces integration test files and the container harness:

```
internal/infrastructure/postgres/*_integration_test.go
internal/handlers/events/*_integration_test.go
internal/test/containers.go            (startPostgres, startRedpanda helpers)
```
