# Testcontainers Setup Standard

Full material for `SKILL.md`'s "Testcontainers Standard" section. Self-contained.
Covers the exact PostgreSQL/Redpanda setup convention, the reuse-vs-fresh-per-test
tradeoff and this repo's chosen strategy, and the startup-time budget that
justifies it.

---

## 1. The Setup Convention

Every package that needs real PostgreSQL or Redpanda gets its containers from a
single shared helper file, `internal/test/containers.go`, so the wait-strategy
and connection-string plumbing is written once and reviewed once:

```go
// internal/test/containers.go
func StartPostgres(t *testing.T) *pgxpool.Pool {
    t.Helper()
    ctx := context.Background()
    pg, err := postgres.Run(ctx, "postgres:16-alpine",
        postgres.WithDatabase("test"), postgres.WithUsername("test"), postgres.WithPassword("test"),
        postgres.BasicWaitStrategies(),   // log + port; a port-only wait races initdb's restart
    )
    require.NoError(t, err)
    t.Cleanup(func() { _ = pg.Terminate(ctx) })

    dsn, _ := pg.ConnectionString(ctx, "sslmode=disable")
    pool, err := pgxpool.New(ctx, dsn)
    require.NoError(t, err)
    t.Cleanup(pool.Close)
    require.NoError(t, runMigrations(dsn))   // real migrations — proves they apply (go-migration)
    return pool
}

func StartRedpanda(t *testing.T) *kgo.Client {
    t.Helper()
    ctx := context.Background()
    rp, err := redpanda.Run(ctx, "redpandadata/redpanda:v24.1.1")
    require.NoError(t, err)
    t.Cleanup(func() { _ = rp.Terminate(ctx) })

    brokers, err := rp.KafkaSeedBroker(ctx)
    require.NoError(t, err)
    client, err := kgo.NewClient(kgo.SeedBrokers(brokers))
    require.NoError(t, err)
    t.Cleanup(client.Close)
    return client
}
```

Two image-specific traps this convention exists to close:

- **PostgreSQL's port-only wait strategy races `initdb`.** The container's port
  opens once during `initdb`'s own internal startup, then Postgres restarts to
  apply configuration — a wait strategy that only checks the port succeeds
  during that transient first open and hands back a connection that then dies
  mid-test. `postgres.BasicWaitStrategies()` (log content + port, occurrence 2)
  waits for the *second* readiness signal.
- **Redpanda's seed-broker address is only valid after the module resolves the
  container's mapped port** — always fetch it via `rp.KafkaSeedBroker(ctx)`
  rather than hand-assembling `localhost:9092`; the mapped host port is
  dynamic (see §3).

## 2. Reuse vs. Fresh-per-Test — the Tradeoff and This Repo's Choice

| Strategy | Isolation | Cost | Verdict |
|---|---|---|---|
| Fresh container per test function | Perfect — no shared state possible | A Postgres container takes ~1–3s to become ready, Redpanda ~3–5s; a 400-test package would add 10–30 minutes of pure container-startup time | Rejected — the isolation is real but bought at a cost the suite cannot afford at scale |
| One shared container per test **package**, via `TestMain` | Container-level isolation is given up; test-level isolation is recovered by the transaction/tenant strategy in `test-isolation-standard.md` | Paid once per package, not once per test — a 400-test package pays the ~1–3s startup cost a handful of times (once per package in the run), not 400 times | **This repo's standard** |
| One shared container for the entire test binary / module | Cheapest — startup cost paid once, period | Cross-package leakage risk if two packages' `TestMain`s assume different container lifecycles, and it blurs package boundaries that otherwise mirror this repo's Bounded Context structure | Rejected — the marginal savings over per-package sharing are small once per-package sharing already amortizes the cost, and it trades away a boundary that is otherwise free |

The chosen strategy — shared container per package, isolation recovered at the
test level — means the container boundary and the isolation boundary are
**deliberately different things**. The container answers "is this a real
Postgres/Redpanda," never "is this test's data private." That second question is
`test-isolation-standard.md`'s job entirely.

## 3. `TestMain` — the Container Lifecycle Anchor

```go
var (
    testPool   *pgxpool.Pool
    testBroker *kgo.Client
)

func TestMain(m *testing.M) {
    flag.Parse()                       // required before testing.Short() — it panics unparsed
    if testing.Short() {
        os.Exit(0)                     // skip container tests entirely in -short mode
    }
    t := &testing.T{}                  // container helpers are t.Helper()-shaped; see note below
    testPool = StartPostgres(dummyT)
    testBroker = StartRedpanda(dummyT)
    os.Exit(m.Run())
}
```

In practice, packages that need `TestMain`-level container sharing use a small
`testing.T`-compatible shim (or call the underlying non-`t.Cleanup` container
start/stop directly in `TestMain` and `defer` the terminate) rather than a real
`*testing.T`, since `TestMain` runs outside any individual test's lifecycle —
the exact shim is an implementation detail of `internal/test/containers.go`, not
a per-package decision.

## 4. Startup-Time Budget

This repo treats container readiness time as a CI budget, not an afterthought:

| Container | Target ready time | Why it matters |
|---|---|---|
| PostgreSQL (`postgres:16-alpine`) | < 3s | Alpine-based image, no unnecessary locales/extensions baked in |
| Redpanda (`redpandadata/redpanda`) | < 5s | Larger image; single-broker dev-mode config, not a multi-broker cluster |
| Combined, per package that needs both | < 8s | Paid once per package under the shared-per-package strategy in §2 |

A package's container-startup time regularly exceeding this budget is a signal
to check the pinned image tag (an unpinned `:latest` can silently grow), not to
abandon the shared-per-package strategy — see `timeout-and-ci-execution-
standard.md` for what to do when startup itself becomes flaky rather than
merely slow.
