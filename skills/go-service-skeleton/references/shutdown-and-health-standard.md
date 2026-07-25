# Shutdown Ordering, Signal Handling, and the Health-Check Lifecycle Contract

Self-contained — usable without the parent `SKILL.md` body already in context. Picks up exactly where `references/composition-root-startup-sequence.md` leaves off (Stage 4 already complete: pool, broker, and layers wired) and carries through Stages 5–6, the full shutdown sequence, and how to mechanically verify each.

---

## Signal Handling Standard

```go
ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
defer stop()
```

**Exactly these two signals, never more:**

| Signal | Why it is handled | Why the alternative is wrong |
|---|---|---|
| `os.Interrupt` (`SIGINT`) | `Ctrl-C` during local development and manual testing | Omitting it makes local dev unable to trigger the same shutdown path production uses — the two paths would diverge exactly where testing them matters most |
| `syscall.SIGTERM` | Kubernetes sends this first when terminating a pod, after the `preStop` hook completes (see `kubernetes-manifest`) | This is the *only* signal the platform actually sends for a graceful stop; a service that doesn't handle it is relying entirely on `SIGKILL`, which is stage-6 below, not a graceful path |

**Signals deliberately *not* handled, and why:**

- **`SIGKILL`** — cannot be caught, blocked, or ignored by any process; it is the kernel's own backstop, not something this skill "handles." Every budget in this document exists specifically so this signal is never the one that actually stops the process.
- **`SIGHUP`** — conventionally means "reload configuration." This skill's config loading is one-shot and fail-fast (see `SKILL.md`'s Configuration Loading section); there is no live-reload path, so wiring `SIGHUP` here would either do nothing (misleading) or reload half-heartedly (worse). If live config reload is ever built, it is a distinct, deliberate feature — not an accidental side effect of this skill's signal set.
- **`SIGQUIT`** — the Go runtime's default `SIGQUIT` behavior is a stack-trace dump, useful for debugging a wedged process from the outside. Intercepting it here to mean "shut down" would remove that diagnostic capability precisely when an operator needs it most (a process that isn't responding to `SIGTERM`).

**Why `defer stop()` matters, precisely:** `signal.NotifyContext`'s `stop` function does two things — it cancels `ctx` if it hasn't already fired, and it unregisters the underlying `signal.Notify` relay. After `stop()` runs, a *subsequent* `SIGINT`/`SIGTERM` is no longer intercepted; the process reverts to the OS default (immediate termination) for that signal. This is deliberate, not a cleanup formality: if graceful shutdown hangs (a stage below blows its budget), an operator's second `Ctrl-C` — or the platform's own `SIGKILL` at the end of the grace period — must actually be able to stop the process. A signal handler with no `stop()` path would keep absorbing every repeated signal into the same already-cancelled context forever, defeating that escape hatch.

---

## Stages 5–6: Readiness Registration and Serve

Continuing directly from `composition-root-startup-sequence.md`'s Stage 4 (`pool`, `broker`, `router` already constructed):

```go
    // Stage 5: Readiness — register checks; do NOT mark ready yet.
    ready := health.NewReadiness() // health-check-design owns this type's full design
    ready.AddCheck("postgres", func(ctx context.Context) error { return pool.Ping(ctx) })
    ready.AddCheck("broker", broker.Healthy)
    // The aggregator starts not-ready. It is only marked ready once every
    // registered check has been exercised at least once and returned nil —
    // never on construction by default, and never before Stage 6 opens the
    // listener. See "The Health-Check Lifecycle Contract" below.

    // Stage 6: Serve — the listener opens now, not before.
    srv := &http.Server{
        Addr:              cfg.HTTPAddr,
        Handler:           router,
        ReadHeaderTimeout: 5 * time.Second,
        ReadTimeout:       10 * time.Second,
        WriteTimeout:      10 * time.Second,
        IdleTimeout:       120 * time.Second,
    }

    g, gctx := errgroup.WithContext(ctx)

    g.Go(func() error {
        slog.Info("http listening", "addr", cfg.HTTPAddr)
        if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
            return fmt.Errorf("http server: %w", err)
        }
        return nil
    })

    // Shutdown goroutine: reacts to root-context cancellation (SIGINT/SIGTERM).
    g.Go(func() error {
        <-gctx.Done()
        ready.SetNotReady()                                          // 1. FIRST — see shutdown budget table
        shutdownCtx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
        defer cancel()
        return srv.Shutdown(shutdownCtx)                              // 2. drains in-flight requests
    })

    g.Go(func() error { return consumer.Run(gctx) })                 // owns its own 20s drain — see go-event-consumer
    g.Go(func() error { return relay.Run(gctx) })                    // see go-event-publisher

    if err := g.Wait(); err != nil {
        return fmt.Errorf("component exited with error: %w", err)
    }
    slog.Info("shutdown complete")
    return nil
}
```

---

## Shutdown Ordering: Startup in Reverse, With a Timeout Budget

Shutdown is Stage 6 → 5 → 4 → 3 (Stages 1–2, config and the logger, have nothing to tear down). Every number below is a real, load-bearing budget already established across this plugin's Go and platform skills — not illustrative filler — and they must sum to less than `terminationGracePeriodSeconds` or Kubernetes `SIGKILL`s the process mid-shutdown.

| Order | Stage | Where it runs | Budget | Running total | Rationale |
|---|---|---|---|---|---|
| 0 | `preStop` hook | Platform-side, before `SIGTERM` is even sent (`kubernetes-manifest`) | 3s | 3s / 30s | Gives Service/mesh endpoint removal time to propagate *before* the process starts refusing new connections — without this, a small window of requests would hit a pod that's already draining |
| 1 | Mark not-ready | First line of the shutdown goroutine, synchronous | ~0s | 3s / 30s | Must happen *before* the drain step below — a `/readyz` probe hit during the drain window must already see not-ready, or the load balancer keeps sending new traffic into a server that's about to stop accepting it |
| 2 | HTTP drain + component drain (concurrent) | `srv.Shutdown(ctx)` and `consumer.Run`'s internal drain, both reacting to the same `gctx.Done()` inside the errgroup | 25s (HTTP) / 20s (consumer — owned by `go-event-consumer`) — these run *concurrently*, not sequentially, so `g.Wait()` is bound by the larger, 25s | 28s / 30s | In-flight client work is worth the largest share of the budget. Running HTTP and consumer drain concurrently (both are independent errgroup members watching the same signal) rather than sequentially is why 25s + 20s does not sum to 45s here |
| 3 | `pool.Close()` | Deferred (LIFO) — runs immediately after `g.Wait()` returns | ~0s expected | 28s / 30s | Not a network call: by the time every drain step above has completed, no component holds a checked-out connection, so this is bookkeeping, not I/O. If this step visibly consumes budget, a component claimed to have drained but hadn't — that is a bug to fix in that component, not a reason to widen this budget |
| 4 | Telemetry flush | Deferred (LIFO), last to run — bounded via `context.WithTimeout`, **never** `context.Background()` unbounded | ≤1.5s | ≤29.5s / 30s | The lowest-priority step by design: losing the final batch of spans is an acceptable, logged loss; blowing through the grace period and being `SIGKILL`ed mid-request is not. This bounded context is a deliberate correction — an unbounded `shutdownTel(context.Background())` would let one wedged OTel collector consume the entire remaining margin |
| — | `SIGKILL` | Kubelet backstop | — | 30s | Every budget above exists specifically so this line is never reached |

The ~0.5s of margin left is intentionally thin: it reflects a real trade-off, not an oversight — the 25s HTTP-drain figure and the 3s `preStop` figure are both already load-bearing numbers other skills (`go-event-consumer`, `kubernetes-manifest`) depend on, so the remaining budget for `pool.Close()` and telemetry flush had to be found from what was left, not invented independently. **An operator who needs more headroom raises `terminationGracePeriodSeconds` in `kubernetes-manifest`; the correct fix is never to silently shrink the 25s HTTP-drain figure**, since that number's whole purpose is protecting in-flight client requests — the thing this entire ordering exists to protect.

---

## The Health-Check Lifecycle Contract

`health-check-design` owns the full liveness/readiness/startup probe standard end to end: the handler implementations, the three-probe semantics table, the `/healthz`/`/readyz`/`/startupz` endpoints, and the Kubernetes probe-config mapping. This skill does not restate that design — it states only the narrow contract the composition root must uphold when it *wires into* that design, since that wiring is a lifecycle-ordering concern, not a health-endpoint-design concern:

1. **Liveness never depends on anything constructed in Stage 4.** It answers "is the process fundamentally stuck," which must be true or false independent of whether Postgres or the broker are reachable — checking a dependency in the liveness path turns a recoverable dependency blip into a self-inflicted restart storm across every replica simultaneously.
2. **Readiness checks are registered only after Stage 4 succeeds**, because a check closing over a `pool` variable that failed to construct would be checking a nil pointer — Stage 5 cannot run before Stage 4 completes (see `composition-root-startup-sequence.md`'s ordering table).
3. **Every check function registered in Stage 5 is bounded by the same short timeout the aggregator applies to the whole probe** (`health-check-design` currently sets this at 2 seconds for the full check round) — a check with no timeout of its own is fine specifically because it's a thin `Ping`/`Healthy` call, not a deep query; if a future check ever needs its own sub-timeout because it does more than reachability, that timeout must still fit inside the aggregator's own ceiling, never exceed it.
4. **Not-ready is set before any drain step begins** (Order 1 in the shutdown table above), synchronously, with no dependency on any other component having stopped first.
5. **A check function must be read-only and side-effect-free.** `pool.Ping` and a broker liveness call are the only two examples this skill ever wires — never a write, never a query against business data. A check that mutates state or runs a business query turns a health probe into load, and turns probe frequency into an accidental rate limiter on the database.

---

## Verifying No Goroutine Leak on Shutdown

`go-concurrency-patterns` owns the general goroutine-lifecycle discipline (every `go`/`g.Go` has an owner and an exit) and the steady-state, under-load leak check (`pprof`'s goroutine profile — see `go-performance-optimization`). This skill adds the one check specific to *this* artifact: a cheap, CI-runnable, start/stop test of the composition root itself, distinct from both of those and complementary to `go test -race` (which proves absence of data races, not absence of leaked goroutines).

```go
func TestRun_NoGoroutineLeakOnShutdown(t *testing.T) {
    // Let prior tests' background goroutines (GC, etc.) settle before sampling.
    runtime.GC()
    baseline := runtime.NumGoroutine()

    ctx, cancel := context.WithCancel(context.Background())
    done := make(chan error, 1)
    go func() { done <- runTestable(ctx, testConfig(t)) }() // run() refactored to accept ctx + cfg for testability

    waitUntilReady(t, testConfig(t)) // poll /readyz until 200, bounded by a test timeout
    cancel()                          // simulate SIGTERM via context cancellation, not an OS signal

    select {
    case err := <-done:
        require.NoError(t, err)
    case <-time.After(5 * time.Second):
        t.Fatal("run() did not return within the test's shutdown deadline")
    }

    runtime.GC()
    time.Sleep(50 * time.Millisecond) // let already-exited goroutines finish unwinding their stacks
    after := runtime.NumGoroutine()
    require.LessOrEqual(t, after, baseline+2, // small tolerance for the test harness's own goroutines, never for the service's
        "goroutine count grew after shutdown: leaked goroutine(s) in the composition root")
}
```

This test proves the narrow thing `-race` and a load-test's steady-state goroutine graph cannot: that the *specific set* of goroutines this composition root spawns (HTTP server, shutdown watcher, consumer, relay) all actually exit when the root context cancels — not merely that they don't corrupt shared memory while running, and not merely that they're stable under sustained traffic. Run it in the same CI job as `go test -race ./...` (`go-makefile`), not as a substitute for it.
