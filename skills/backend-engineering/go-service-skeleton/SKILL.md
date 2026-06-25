---
name: go-service-skeleton
description: >
  Teaches how to build the service composition root (cmd/server/main.go) — wiring
  dependencies, the lifecycle of the process, graceful shutdown driven by
  signal.NotifyContext, the root context that every goroutine descends from,
  ordered startup and reverse-ordered shutdown, and readiness gating. This is the
  deterministic-lifecycle backbone the blueprint demands: no orphaned goroutines,
  no work accepted before dependencies are healthy. Used by the backend-engineer
  during Implement.
version: 1.0.0
phase: implement
owner: backend-engineer
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

Dependencies start in order, and each startup failure aborts cleanly with wrapped context. Construct outer-to-inner: telemetry first (so everything is observable), then secrets, then stores, then the broker, then the HTTP server.

```go
    // 1. Telemetry first — so startup itself is traced/logged
    shutdownTel, err := telemetry.Init(ctx, cfg.OTel)
    if err != nil { return fmt.Errorf("init telemetry: %w", err) }
    defer shutdownTel(context.Background()) // flush spans on exit

    // 2. Secrets (Vault Agent file) → DB credentials
    dbURL, err := secrets.DatabaseURL()
    if err != nil { return fmt.Errorf("reading db credentials: %w", err) }

    // 3. Database pool
    pool, err := pgxpool.New(ctx, dbURL)
    if err != nil { return fmt.Errorf("connecting postgres: %w", err) }
    defer pool.Close()
    if err := pool.Ping(ctx); err != nil { return fmt.Errorf("postgres ping: %w", err) }

    // 4. Wire the layers (infrastructure → application → handlers)
    repo := postgres.NewDataAssetRepo(pool)
    publisher := messaging.NewOutboxPublisher(pool)
    classify := commands.NewClassifyDataAssetHandler(repo, publisher, policy)
    router := httptransport.NewRouter(classify, /* queries, middleware ... */)
```

---

## Concurrent Components with errgroup

When the process runs more than one long-lived component (HTTP server + event consumer + outbox relay), supervise them with `errgroup` tied to the root context. If any one fails, the group cancels the rest — coordinated shutdown, no orphans.

```go
    g, gctx := errgroup.WithContext(ctx)

    srv := &http.Server{
        Addr:              cfg.HTTPAddr,
        Handler:           router,
        ReadHeaderTimeout: 5 * time.Second, // slowloris protection
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

---

## Output Format

Produces Go source, not a document:

```
cmd/server/main.go            (run() lifecycle, errgroup supervision, graceful shutdown)
internal/config/config.go     (fail-fast config loader)
```
