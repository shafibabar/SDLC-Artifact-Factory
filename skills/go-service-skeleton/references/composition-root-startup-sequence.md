# Composition Root: Ordered Startup Sequence

The full worked startup sequence referenced from `SKILL.md`'s Ordered Startup section. Self-contained — usable without the parent `SKILL.md` body already in context.

---

## The Six Stages, and Why This Exact Order

| # | Stage | Depends on | Why it cannot move earlier |
|---|---|---|---|
| 1 | **Config** | Nothing | Every later stage needs a config value (log level, DSN, ports, timeouts). Nothing can construct before it is parameterized. |
| 2 | **Logger** | Config (log level) | Every stage from here on should be observable through structured logs. A logger built later means earlier failures are diagnosed with `fmt.Println` or silence — exactly the "nil-pointer panic three requests into production" failure mode Edwards' fail-fast chapter warns against. |
| 3 | **Telemetry** | Config, Logger | Tracer/meter providers must exist *before* dependencies are constructed, not after. If telemetry initialized after the database pool, the pool's own construction and first `Ping` — precisely the window where a slow or unreachable database shows up — would be invisible in traces. Telemetry logs its own startup through the logger built in stage 2. |
| 4 | **Dependencies** | Config, Logger, Telemetry | Secrets → connection pool → broker client → layer wiring (repositories, publishers, command/query handlers, router), in that sub-order, each verified synchronously before the next begins. A failure here aborts the process with a wrapped error — it never reaches stage 5. |
| 5 | **Readiness** | Dependencies (already proven constructible) | Registering a health check against a pool that failed to construct would be checking a nil pointer — readiness registration is only meaningful once stage 4 has already succeeded. This stage prepares the readiness surface; it does not yet accept traffic. Full check-function contract and the readiness/liveness distinction: `references/shutdown-and-health-standard.md`. |
| 6 | **Serve** | Readiness | The HTTP listener opens only now. This is the mechanical guarantee behind "no request accepted before readiness" — the socket does not exist until every earlier stage has already succeeded, independent of and in addition to Kubernetes withholding the Service endpoint until `/readyz` first passes. |

Each stage's own dependency call (secrets fetch, pool connect, broker dial) should be bound to a short, sensible connect timeout via `context.WithTimeout` derived from the root context — not left to block forever, and not equal to the root context's own (much longer) lifetime. A startup dependency that cannot connect within a few seconds should fail fast and abort, not hang the process in an unready, unobservable limbo.

---

## Worked Sequence: Stages 1–4

```go
func run() error {
    // Stage 1: Config — fail-fast, aborts before anything else exists.
    cfg, err := config.Load()
    if err != nil {
        return fmt.Errorf("loading config: %w", err)
    }

    // Stage 2: Logger — every stage from here on logs through this.
    logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: cfg.LogLevel}))
    slog.SetDefault(logger)

    // Root context: cancelled on SIGINT/SIGTERM. See "Signal Handling Standard" in SKILL.md
    // and references/shutdown-and-health-standard.md for the full contract.
    ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
    defer stop()

    // Stage 3: Telemetry — so stage 4's dependency construction is itself traced.
    shutdownTel, err := telemetry.Init(ctx, cfg.OTel)
    if err != nil {
        return fmt.Errorf("init telemetry: %w", err)
    }
    defer func() {
        flushCtx, cancel := context.WithTimeout(context.Background(), 1500*time.Millisecond)
        defer cancel()
        if err := shutdownTel(flushCtx); err != nil {
            slog.Error("telemetry flush incomplete", "err", err) // see shutdown budget table: this is a bounded, tolerated loss
        }
    }()

    // Stage 4a: Secrets (Vault Agent file) → DB credentials.
    dbURL, err := secrets.DatabaseURL()
    if err != nil {
        return fmt.Errorf("reading db credentials: %w", err)
    }

    // Stage 4b: Database pool — sized deliberately, never left at defaults blindly.
    poolCfg, err := pgxpool.ParseConfig(dbURL)
    if err != nil {
        return fmt.Errorf("parsing db config: %w", err)
    }
    poolCfg.MaxConns = cfg.DBMaxConns             // this replica's share of Postgres max_connections
    poolCfg.MinConns = cfg.DBMinConns              // keeps a warm floor so a post-quiet-period burst doesn't pay full connection-setup cost simultaneously
    poolCfg.MaxConnLifetime = time.Hour            // recycle: credential rotation + connection rebalancing
    poolCfg.MaxConnIdleTime = 5 * time.Minute
    pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
    if err != nil {
        return fmt.Errorf("connecting postgres: %w", err)
    }
    defer pool.Close() // fast: by the time this runs, no component holds a checked-out connection (see shutdown budget table)
    connectCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()
    if err := pool.Ping(connectCtx); err != nil {
        return fmt.Errorf("postgres ping: %w", err)
    }

    // Stage 4c: Broker client — same fail-fast shape as the pool.
    broker, err := messaging.NewClient(ctx, cfg.Broker)
    if err != nil {
        return fmt.Errorf("connecting broker: %w", err)
    }
    defer broker.Close()

    // Stage 4d: Wire the layers (infrastructure → application → handlers).
    repo := postgres.NewDataAssetRepo(pool)
    publisher := messaging.NewOutboxPublisher(pool)
    classify := commands.NewClassifyDataAssetHandler(repo, publisher, policy)
    router := httptransport.NewRouter(classify, /* queries, middleware ... */)

    // Stages 5 and 6 continue in references/shutdown-and-health-standard.md's
    // worked example, which picks up exactly here with readiness registration,
    // the errgroup, and the graceful-shutdown goroutine.
```

**Pool sizing rule:** `MaxConns × replica count` must stay comfortably below Postgres `max_connections` (leave headroom for migrations, the relay, and operators). Too small shows up as request latency while goroutines queue for a connection (`pool.Stat().EmptyAcquireCount` climbing is the tell); too large just moves the queue into Postgres, which degrades *everyone*. Start near `4 × CPU cores of the database` divided across replicas, then tune from acquire-wait metrics — not from folklore. `MinConns` is `pgxpool`'s closest analogue to `database/sql`'s `SetMaxIdleConns` (Edwards, *Let's Go Further*): a warm floor of already-established connections so a burst of requests after a quiet period doesn't pay full connection-setup latency simultaneously on every one of them.

**Why stage 4's sub-order (secrets → pool → broker → layers) is itself fixed:** each later item in stage 4 is constructed from the previous one's output (the pool needs the DSN secrets produced; the layers need the pool and broker already live) — this is ordinary data-dependency ordering, not a separate rule, but it means a review that finds `messaging.NewOutboxPublisher(pool)` referencing a `pool` variable declared after it is looking at broken code, not a style choice.
