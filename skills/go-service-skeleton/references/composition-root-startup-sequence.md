# Composition Root: Ordered Startup Sequence

The full worked startup sequence referenced from `SKILL.md`'s Ordered Startup section — telemetry, secrets, database pool, then layer wiring, in that order, with each failure aborting cleanly.

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

    // 3. Database pool — sized deliberately, never left at defaults blindly
    poolCfg, err := pgxpool.ParseConfig(dbURL)
    if err != nil { return fmt.Errorf("parsing db config: %w", err) }
    poolCfg.MaxConns = cfg.DBMaxConns             // this replica's share of Postgres max_connections
    poolCfg.MaxConnLifetime = time.Hour           // recycle: credential rotation + connection rebalancing
    poolCfg.MaxConnIdleTime = 5 * time.Minute
    pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
    if err != nil { return fmt.Errorf("connecting postgres: %w", err) }
    defer pool.Close()
    if err := pool.Ping(ctx); err != nil { return fmt.Errorf("postgres ping: %w", err) }

    // 4. Wire the layers (infrastructure → application → handlers)
    repo := postgres.NewDataAssetRepo(pool)
    publisher := messaging.NewOutboxPublisher(pool)
    classify := commands.NewClassifyDataAssetHandler(repo, publisher, policy)
    router := httptransport.NewRouter(classify, /* queries, middleware ... */)
```

**Pool sizing rule:** `MaxConns × replica count` must stay comfortably below Postgres `max_connections` (leave headroom for migrations, the relay, and operators). Too small shows up as request latency while goroutines queue for a connection (`pool.Stat().EmptyAcquireCount` climbing is the tell); too large just moves the queue into Postgres, which degrades *everyone*. Start near `4 × CPU cores of the database` divided across replicas, then tune from acquire-wait metrics — not from folklore.
