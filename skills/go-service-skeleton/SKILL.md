---
name: go-service-skeleton
description: >
  Teaches how to build the service composition root (cmd/server/main.go) — wiring
  dependencies, the lifecycle of the process, graceful shutdown driven by
  signal.NotifyContext, the root context that every goroutine descends from,
  ordered startup and reverse-ordered shutdown, readiness gating, and complete
  http.Server timeout configuration (ReadTimeout/WriteTimeout/IdleTimeout
  alongside ReadHeaderTimeout). This is the deterministic-lifecycle backbone
  the blueprint demands: no orphaned goroutines, no work accepted before
  dependencies are healthy. The full ordered-startup worked example is in
  references/composition-root-startup-sequence.md. Used by the
  backend-engineer during Implement.
version: 2.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, main, lifecycle, graceful-shutdown, context, composition-root]
---

# Go Service Skeleton

## Purpose

The composition root (`cmd/server/main.go`) is the only place that knows the concrete world: which database, which broker, which logger. It wires the layers together, starts them in dependency order, and — critically — shuts them down cleanly. Every goroutine in the process descends from the root context created here, so that one `Ctrl-C` or one Kubernetes `SIGTERM` propagates cancellation everywhere and the process exits with no leaks and no dropped in-flight work.

This is the blueprint's "deterministic lifecycle, bounded lifetime, explicit exit mechanism" applied at the top level.

---

## The Root Context

A single root context, cancelled on shutdown signals, is the parent of all work:

```go
func main() {
    if err := run(); err != nil {
        slog.Error("fatal", "err", err)
        os.Exit(1)
    }
}

func run() error {
    // Root context: cancelled on SIGINT/SIGTERM. Every goroutine derives from this.
    ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
    defer stop()

    cfg, err := config.Load()
    if err != nil {
        return fmt.Errorf("loading config: %w", err)
    }
    ...
}
```

`run()` returns an error instead of calling `log.Fatal` inside helpers: this keeps `defer`s running (so shutdown executes) and keeps `main` a single, testable funnel. `os.Exit` is called in exactly one place.

---

## Ordered Startup

Dependencies start in order, and each startup failure aborts cleanly with wrapped context. Construct outer-to-inner: telemetry first (so everything is observable), then secrets, then stores, then the broker, then the HTTP server. **Pool sizing rule:** `MaxConns × replica count` must stay comfortably below Postgres `max_connections`; start near `4 × CPU cores of the database` divided across replicas, then tune from acquire-wait metrics (`pool.Stat().EmptyAcquireCount`), not folklore. Full worked sequence: `references/composition-root-startup-sequence.md`.

---

## Concurrent Components with errgroup

When the process runs more than one long-lived component (HTTP server + event consumer + outbox relay), supervise them with `errgroup` tied to the root context. If any one fails, the group cancels the rest — coordinated shutdown, no orphans.

```go
    g, gctx := errgroup.WithContext(ctx)

    srv := &http.Server{
        Addr:              cfg.HTTPAddr,
        Handler:           router,
        ReadHeaderTimeout: 5 * time.Second,   // slowloris protection: caps time to send request headers
        ReadTimeout:       10 * time.Second,  // caps time to send the full request body
        WriteTimeout:      10 * time.Second,  // caps time to write the response
        IdleTimeout:       120 * time.Second, // caps idle keep-alive time: bounds connection-pool exhaustion
    }

    // HTTP server
    g.Go(func() error {
        slog.Info("http listening", "addr", cfg.HTTPAddr)
        if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
            return fmt.Errorf("http server: %w", err)
        }
        return nil
    })

    // Graceful HTTP shutdown when the group context is cancelled
    g.Go(func() error {
        <-gctx.Done()
        shutdownCtx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
        defer cancel()
        return srv.Shutdown(shutdownCtx) // drains in-flight requests
    })

    // Event consumer (its own bounded lifecycle — see go-event-consumer)
    g.Go(func() error { return consumer.Run(gctx) })

    // Outbox relay (see go-event-publisher)
    g.Go(func() error { return relay.Run(gctx) })

    if err := g.Wait(); err != nil {
        return fmt.Errorf("component exited with error: %w", err)
    }
    slog.Info("shutdown complete")
    return nil
}
```

**Why this shape:**
- `signal.NotifyContext` cancels `ctx` on `SIGTERM` (Kubernetes sends this before `SIGKILL`).
- `errgroup`'s `gctx` is cancelled when *any* goroutine returns an error, so a failing consumer also stops the HTTP server.
- `srv.Shutdown` drains in-flight requests within a deadline before the process exits.
- The shutdown timeout (25s) is set below Kubernetes' `terminationGracePeriodSeconds` (default 30s) so the process exits cleanly before `SIGKILL`.

**Shutdown ordering is startup in reverse**, and the `defer` stack encodes it for free: `g.Wait()` returns only after every component (HTTP drain, consumer drain, relay) has stopped; then the deferred `pool.Close()` runs — no component is still using a connection — and finally the deferred telemetry shutdown flushes the last spans. Closing the pool while the consumer is mid-transaction, or flushing telemetry before components stop emitting, are the two ordering bugs this shape makes impossible.

---

## Readiness Gating

The process must not report ready until its dependencies are healthy, and must report not-ready as soon as shutdown begins so the load balancer stops sending traffic. (Probe handlers themselves: see observability `health-check-design`.)

```go
    ready := health.NewReadiness()
    ready.AddCheck("postgres", func(ctx context.Context) error { return pool.Ping(ctx) })
    ready.AddCheck("broker", broker.Healthy)
    // mark not-ready immediately on shutdown so traffic drains first
    g.Go(func() error { <-gctx.Done(); ready.SetNotReady(); return nil })
```

---

## Configuration Loading

Config comes from environment for non-secret values and from Vault Agent files for secrets (never secrets in env — see security `secrets-management`). Loading is fail-fast: a missing required value aborts startup.

```go
type Config struct {
    HTTPAddr string        `env:"HTTP_ADDR" default:":8080"`
    OTel     telemetry.Config
    LogLevel slog.Level    `env:"LOG_LEVEL" default:"info"`
}
// Load validates and returns an error listing ALL missing/invalid fields at once.
```

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Single root context | All goroutines derive from one signal-cancelled context | Goroutines using `context.Background()` directly |
| Graceful shutdown | `srv.Shutdown` drains requests; deadline < pod grace period | Hard `os.Exit` that drops in-flight work |
| errgroup supervision | Long-lived components in an errgroup; failure cancels siblings | Independent `go func()`s with no coordinated stop |
| Fail-fast startup | Dependency failures abort with wrapped error before serving | Serving traffic before dependencies are verified |
| One exit point | `os.Exit` only in `main`; `run()` returns errors | `log.Fatal` scattered through wiring |
| Readiness gated | Not-ready until healthy; not-ready on shutdown start | Ready reported before dependencies verified |
| Pool sized deliberately | `MaxConns`/lifetimes set from capacity math | Default pool settings shipped unexamined |
| Complete server timeouts | `ReadTimeout`/`WriteTimeout`/`IdleTimeout` set alongside `ReadHeaderTimeout` | Only `ReadHeaderTimeout` set; slow body/write/idle connections unbounded |

---

## Anti-Patterns

- **`log.Fatal` in helpers** — kills the process mid-wiring, skipping every `defer`: no HTTP drain, no pool close, no telemetry flush. Errors bubble to `run()`; `os.Exit` lives in `main` alone.
- **Un-supervised `go func()` components** — a consumer started with a bare `go` outside the errgroup keeps running (or dies silently) while the rest of the process shuts down.
- **Serving before dependencies are verified** — reporting ready, taking traffic, then discovering Postgres is unreachable turns a slow startup into an error storm.
- **Shutdown timeout ≥ pod grace period** — a 30s drain against a 30s grace period means Kubernetes `SIGKILL`s mid-drain; the deadline must leave margin.
- **Closing the pool before components stop** — `pool.Close()` placed anywhere other than after `g.Wait()` yanks connections out from under an in-flight transaction.
- **Constructing dependencies inside layers** — a repository creating its own pool, or a handler building its own client, bypasses the composition root and makes lifecycle untrackable. All wiring happens in `main`.
- **Incomplete `http.Server` timeout configuration** — setting only `ReadHeaderTimeout` closes the slowloris header-send vector but leaves the body-read, response-write, and idle-keep-alive vectors open; a slow or stalled client can still hold a handler goroutine or a pooled connection indefinitely. Set `ReadTimeout`, `WriteTimeout`, and `IdleTimeout` deliberately, not just the one field that happens to be the most famous.

---

## Output Format

Produces Go source, not a document:

```
cmd/server/main.go            (run() lifecycle, errgroup supervision, graceful shutdown)
internal/config/config.go     (fail-fast config loader)
```

Full ordered-startup worked example: `references/composition-root-startup-sequence.md`.
