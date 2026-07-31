# Resilience Patterns for Synchronous Dependencies

Reference for `integration-design`. Self-contained: the five patterns that make a
synchronous remote call safe, with concrete numbers, the state machine, and the
Go implementation on this platform (Go + `chi` + `pgx`, OpenTelemetry-
instrumented). A synchronous call to another service is a shared-fate link until
every one of these is in place.

---

## 1. Timeout — every remote call has a deadline

No remote call may block indefinitely. A call with no timeout inherits the
downstream's worst case: if the downstream hangs, your goroutine hangs, your
connection pool fills, and the hang walks up the chain. Every outbound call sets
an explicit, per-call deadline via `context.Context`.

### Timeout budgeting (nesting)

Timeouts nest. A caller's budget **must exceed** its downstream's *full retry
envelope* — every attempt plus every backoff delay — or the caller gives up while
the downstream is still working, then retries on top of it, doubling the load.

Worked budget for a Gateway → Classification → Source Catalog chain:

```
Source Catalog single-attempt timeout:      500ms
Classification retry envelope to Catalog:    500 + (100 backoff) + 500
                                           + (200 backoff) + 500  = 1800ms
Classification's own single-attempt budget: 1800ms  (must exceed the envelope)
Gateway timeout to Classification:          ≥ 2000ms (envelope + margin)
User-facing request budget:                 ≥ 2500ms
```

Propagate the *remaining* deadline downward: pass `ctx` (carrying the deadline)
into every client call so a downstream never works longer than the caller will
wait. In Go, `context.WithTimeout(parent, d)` and the `pgx`/HTTP clients that
honor `ctx` give this for free.

---

## 2. Retry with Backoff and jitter

Transient failures — `503`, `504`, connection reset, a dropped TCP segment — are
worth retrying. Permanent failures (`400`, `404`, `422`) are not: retrying them
just wastes the budget.

```go
type RetryConfig struct {
    MaxAttempts  int           // cap — never unbounded
    InitialDelay time.Duration
    MaxDelay     time.Duration
    Multiplier   float64
    JitterFactor float64       // fraction of delay randomized
}

var DefaultRetry = RetryConfig{
    MaxAttempts:  3,
    InitialDelay: 100 * time.Millisecond,
    MaxDelay:     5 * time.Second,
    Multiplier:   2.0,
    JitterFactor: 0.2, // ±20%
}
```

**Jitter is mandatory.** Without it, every caller that failed at the same instant
retries at the same instant — a synchronized retry storm (thundering herd) that
finishes off the recovering downstream. Full jitter: `delay = random(0,
min(MaxDelay, InitialDelay * Multiplier^attempt))`.

**Idempotency is a precondition of retry.** A timeout is an *unknown* outcome —
the request may have succeeded. Retrying a non-idempotent write (create a
compliance report, charge an account) duplicates the side effect. Rule: retry
`GET`s freely; retry a mutating call only if it carries an `Idempotency-Key` the
provider deduplicates on. Otherwise, do not auto-retry — surface the uncertainty.

---

## 3. Circuit Breaker — the three-state machine

A breaker stops a caller from hammering a downstream that is already down, and
lets threads fail fast instead of piling up on timeouts.

```
        failures ≥ threshold
 ┌────────┐ ───────────────────▶ ┌────────┐
 │ CLOSED │                      │  OPEN  │
 │ (pass  │ ◀─────────────────── │ (fail  │
 │ through)│    probe succeeds    │  fast) │
 └────────┘                      └────────┘
      ▲                              │
      │ probe succeeds     reset timeout elapsed
      │                              ▼
      │        ┌───────────────────────────┐
      └────────│        HALF-OPEN          │
   probe fails │ (allow ONE trial request) │──┐
   → back OPEN └───────────────────────────┘  │ probe fails
                            └──────────────────┘ → OPEN
```

- **Closed** — normal. Requests pass through; the breaker counts failures in a
  rolling window.
- **Open** — the failure threshold was crossed. Every request fails *immediately*
  (returns the fallback) without touching the downstream — no waiting for a
  timeout. Stays open for the **reset timeout**.
- **Half-Open** — after the reset timeout, the breaker lets **one** trial request
  ("probe") through. If it succeeds, the breaker closes (recovered). If it fails,
  the breaker re-opens and waits another reset timeout. This single-probe design
  prevents a flood of traffic from slamming a downstream the instant its window
  expires.

### Concrete configuration (per downstream)

| Downstream | Failure threshold | Rolling window | Reset timeout |
|---|---|---|---|
| Classification Service (internal, hot path) | 5 consecutive failures | 10s | 5s |
| Source Catalog (external, tolerant) | 50% of ≥20 requests | 30s | 30s |
| Google Drive API (external, rate-limited) | 50% of ≥10 requests | 60s | 60s |

Configure **one breaker per downstream** — never a global breaker. A global
breaker opens for healthy dependencies the moment one unrelated dependency fails.

### Go implementation (`sony/gobreaker`)

```go
var catalogBreaker = gobreaker.NewCircuitBreaker(gobreaker.Settings{
    Name:        "source-catalog",
    MaxRequests: 1,                // half-open: single probe
    Interval:    30 * time.Second, // rolling window reset
    Timeout:     30 * time.Second, // open → half-open reset timeout
    ReadyToTrip: func(c gobreaker.Counts) bool {
        return c.Requests >= 20 &&
            float64(c.TotalFailures)/float64(c.Requests) >= 0.5
    },
    OnStateChange: func(name string, from, to gobreaker.State) {
        breakerStateGauge.WithLabelValues(name).Set(stateCode(to)) // Prometheus
    },
})

func (c *CatalogClient) Fetch(ctx context.Context, id string) (Asset, error) {
    v, err := catalogBreaker.Execute(func() (any, error) {
        return c.doFetch(ctx, id) // has its own timeout + retry inside
    })
    if err != nil {
        return c.fallback(id) // breaker open OR call failed → degrade
    }
    return v.(Asset), nil
}
```

Emit the breaker's state as a Prometheus gauge and trace open→half-open→closed
transitions in Tempo — an open breaker is an operational signal that a downstream
is unhealthy, and belongs on the Grafana dashboard.

---

## 4. Bulkhead — isolate resource pools

Named for a ship's watertight compartments: one flooded compartment does not sink
the ship. Each downstream gets its **own connection pool / concurrency limit**, so
a slow dependency can exhaust only its own budget, not the resources every other
call needs. Without bulkheads, one slow downstream saturates a shared pool and
every unrelated call starves behind it.

```go
// Per-downstream semaphore caps concurrent in-flight calls.
type Bulkhead struct{ sem chan struct{} }

func NewBulkhead(max int) *Bulkhead { return &Bulkhead{sem: make(chan struct{}, max)} }

func (b *Bulkhead) Do(ctx context.Context, fn func() error) error {
    select {
    case b.sem <- struct{}{}:
        defer func() { <-b.sem }()
        return fn()
    case <-ctx.Done():
        return ctx.Err() // pool full → fail fast, don't queue unboundedly
    }
}
```

Also applies at the HTTP transport layer: a distinct `http.Client` with its own
`MaxConnsPerHost` per downstream, not one shared client for all of them.

---

## 5. Fallback and graceful degradation

When the breaker is open, the bulkhead is full, or the call ultimately fails, the
caller returns a **defined degraded response** rather than propagating the
failure. Options, in rough order of preference:

- **Cached / last-known-good value** — serve a stale Source Catalog entry with a
  freshness marker rather than failing the whole request.
- **Sensible default** — an empty result set, a "classification pending" status.
- **Queue for later** — accept the request, enqueue the work, return `202`
  (converts a failed sync call into an async one).
- **Explicit partial failure** — return the parts that succeeded plus a typed
  error for the part that did not, so the caller can decide.

A fallback that silently returns wrong data is worse than a failure. Every
fallback must be observably *degraded* (a flag, a metric, a log) so operators know
the system is running on a fallback path.

---

## How the patterns compose (fixed nesting order)

The five patterns wrap in a specific order — outermost first:

```
Bulkhead {              // admission control: is there capacity at all?
  CircuitBreaker {      // is this downstream even worth calling right now?
    Retry {             // transient failure? try again with backoff+jitter
      Timeout {         // this single attempt gets a hard deadline
        remoteCall()
      }
    }
  }
} else Fallback         // any layer refuses/fails → degraded response
```

Order matters. The **timeout is innermost** so it bounds each individual attempt;
**retry sits outside timeout** so each retry gets a fresh deadline; the **breaker
sits outside retry** so a downstream that fails every retry counts as one failure
toward tripping; the **bulkhead is outermost** so the whole retry+breaker sequence
consumes exactly one concurrency slot. Fallback catches whatever the stack throws.

---

## Checklist per synchronous integration

- [ ] Explicit per-call timeout, deadline propagated via `context.Context`.
- [ ] Caller's budget ≥ downstream's full retry envelope.
- [ ] Retry only idempotent calls (or `Idempotency-Key`-bearing), with jitter and
      a capped attempt count.
- [ ] One Circuit Breaker per downstream, thresholds + reset timeout chosen for
      that downstream's tolerance.
- [ ] One connection pool / concurrency limit (Bulkhead) per downstream.
- [ ] A defined, observable Fallback for the open/failed path.
- [ ] Breaker state exported to Prometheus; transitions traced in Tempo.
