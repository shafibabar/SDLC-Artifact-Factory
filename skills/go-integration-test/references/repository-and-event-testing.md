# Worked Examples: Repository, Outbox/Consumer Round-Trip, Trace Correlation

Full worked examples for `SKILL.md`'s "What Belongs in an Integration Test"
section. Self-contained. These are the concrete instances of quadrant-2/3
wiring integration tests exist to verify — see `SKILL.md` for the boundary
rule these examples are instances of.

---

## 1. The Repository — Real SQL, Real Concurrency Conflicts

The repository is the prime integration target: it is a Humble Object
(`go-repository-pattern`), so its correctness lives entirely in SQL that only a
real database can verify — a mocked driver cannot catch a wrong column name, a
broken migration, or a genuine transaction-isolation surprise.

```go
func TestDataAssetRepo_Save_OptimisticConcurrency(t *testing.T) {
    tx := withTx(t, testPool)                            // test-isolation-standard.md
    repo := postgres.NewDataAssetRepo(tx)
    tenant := freshTenant(t, testPool)
    ctx := withTenant(context.Background(), tenant)

    asset := seedAsset(t, tx, tenant)                     // version 1
    stale := mustLoad(t, repo, ctx, asset.ID())           // also version 1

    require.NoError(t, mutateAndSave(repo, ctx, asset))    // bumps to version 2

    // The stale copy must fail the compare-and-swap — proves real optimistic concurrency.
    err := mutateAndSave(repo, ctx, stale)
    require.ErrorIs(t, err, domain.ErrConcurrentModification)
}
```

This catches what a mock never could: the actual `WHERE version = $N` semantics, real
constraint violations, and the genuine round-trip of types through `pgx`.

## 2. The Outbox + Consumer Round-Trip — the Real-Commit Exception in Practice

The event path spans a transaction, a relay, the broker, and a consumer — by
nature an integration concern, and specifically the class of test that needs
real commits (`test-isolation-standard.md` §3), since the outbox relay's polling
query must see a row that another process actually committed:

```go
func TestClassify_PublishesEvent(t *testing.T) {
    tenant := freshTenant(t, testPool)                    // real-commit exception path
    ctx := withTenant(context.Background(), tenant)
    // ...wire repo, outbox relay, and a consumer against the real broker...

    require.NoError(t, classifyHandler.Handle(ctx, classifyCmd))   // writes state + outbox row (1 tx)
    relay.drainOnce(ctx)                                            // publishes the outbox row

    evt := awaitEvent(t, testBroker, "data-asset-classified", 5*time.Second)
    require.Equal(t, "DataAssetClassified", evt.EventType)

    // Redeliver the same event — the idempotent consumer must process it once.
    publishAgain(t, testBroker, evt)
    require.Equal(t, 1, countProcessed(t, testPool, evt.EventID))    // dedup proven
}
```

The duplicate-delivery assertion is essential: at-least-once delivery *will*
redeliver in production, so the idempotency must be proven against the real
broker, not assumed. `go-event-consumer` treats this exact test shape — real
Postgres + real Redpanda via Testcontainers — as the standard its own
idempotent-consumer and DLQ tests are built on; this file is that standard's
source, not a parallel convention.

## 3. Hermetic Seeding — `freshTenant`

Every integration test on the real-commit exception path seeds exactly the data
it needs and relies on `t.Cleanup` to remove it (`test-fixture-design` owns the
general builder/fixture toolkit this helper is an instance of):

```go
func freshTenant(t *testing.T, pool *pgxpool.Pool) uuid.UUID {
    t.Helper()
    tenant := uuid.New()
    t.Cleanup(func() {
        _, _ = pool.Exec(context.Background(), `DELETE FROM data_assets WHERE tenant_id = $1`, tenant)
    })
    return tenant
}
```

A test that reads data it did not create through this helper is a bug — fail
loudly rather than depend on ambient state left by a sibling test.

## 4. Test-Trace Correlation

Inject a unique **test id** into the context/headers so an integration test's
activity is traceable through the backend's OpenTelemetry spans
(`distributed-tracing-design`). When a test fails, its trace id leads straight to
the exact spans — diagnosis without a debugger:

```go
ctx = withTestID(ctx, t.Name())   // propagates into spans/logs for failure correlation
```

## 5. Polling Instead of Sleeping — `awaitEvent`

Every wait for an asynchronous effect (the outbox relay publishing, a consumer
finishing processing) polls with a bounded deadline rather than sleeping a fixed
duration — see `timeout-and-ci-execution-standard.md` for the full flakiness
rationale:

```go
func awaitEvent(t *testing.T, client *kgo.Client, topic string, deadline time.Duration) domain.Event {
    t.Helper()
    ctx, cancel := context.WithTimeout(context.Background(), deadline)
    defer cancel()
    for {
        evt, ok := pollOnce(ctx, client, topic)
        if ok {
            return evt
        }
        select {
        case <-ctx.Done():
            t.Fatalf("event on topic %q not observed within %s", topic, deadline)
        case <-time.After(50 * time.Millisecond):
        }
    }
}
```
