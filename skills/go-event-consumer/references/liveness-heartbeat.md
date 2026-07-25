# Liveness Heartbeat — Full Worked Example

Full worked material referenced from `SKILL.md`'s "Liveness Heartbeat" section.
Self-contained — reads without the parent body already in context. Covers: why lag
and DLQ depth both miss a wedged-but-scheduled goroutine, why a heartbeat pulse
emitted by an independent ticker alone is *insufficient* to catch that specific
failure, and the two-signal design (an independent ticker pulse plus an in-loop
progress pulse, each a `sync/atomic` timestamp) that closes the gap correctly.

---

## 1. Why Lag and DLQ Depth Aren't Enough

Consumer lag and DLQ depth both catch a consumer that is *slow* or *failing* — but
neither catches a consumer goroutine that is alive, scheduled, and stuck: blocked
indefinitely inside `handleRecord` on a downstream call with no timeout, or wedged in
a loop. Zero throughput and flat lag look identical to "no work available" until an
operator notices lag is *also* flat and misreads a hang as healthy idle — both metrics
only move when a message is actually processed, never merely because the goroutine
still exists. Cox-Buday's **Heartbeat Pattern** closes this blind spot: a long-running
goroutine emits a periodic liveness pulse distinct from its actual work, so a
supervisor can tell "alive and idle" from "stuck" even when zero records are flowing.

---

## 2. Why an Independent Ticker, by Itself, Does Not Actually Prove the Consume Loop Is Unstuck

A heartbeat implemented as a wholly separate goroutine — its own ticker, decoupled
from `Run`'s own control flow — proves only that the **process and scheduler** haven't
fully hung. It says nothing about whether `Run`'s own goroutine, specifically, is
making progress: an independent ticker goroutine keeps firing on schedule regardless
of whether `handleRecord` is wedged, because nothing about its own execution depends
on `Run` ever reaching any particular line. A stuck `handleRecord` and a healthy one
look identical to a pulse that isn't coupled to either.

**The fix, per Cox-Buday's actual pattern:** the pulse that certifies *this specific
goroutine's* progress must be emitted from a point inside that goroutine's own control
flow — one a stuck blocking call prevents it from ever reaching. This standard keeps
**both** signals, deliberately kept as two separate values, because they answer two
different operational questions:

| Signal | Updated by | Proves | Silence means |
|---|---|---|---|
| `lastTickerPulse` | An independent ticker goroutine, on a fixed interval | The process is scheduled and running at all | The whole process/scheduler is wedged — rare; usually also visible via Go's own runtime deadlock detector or an external liveness probe |
| `lastLoopPulse` | `Run` itself, once per fully-completed loop iteration | *This specific goroutine* made forward progress — polled, dispatched, and finished a full batch | `Run`'s own goroutine is wedged inside a single call somewhere in `c.process`/`handleRecord` — the exact failure this pattern exists to catch |

---

## 3. The Worked Implementation

```go
type Consumer struct {
    // ...
    lastTickerPulse atomic.Int64 // updated by heartbeatLoop's own ticker
    lastLoopPulse   atomic.Int64 // updated once per completed Run iteration
}

// heartbeatLoop runs as a sibling errgroup member alongside Run (go-service-skeleton).
// It proves the scheduler hasn't fully hung — nothing more.
func (c *Consumer) heartbeatLoop(ctx context.Context) error {
    ticker := time.NewTicker(c.heartbeatInterval) // independent of message traffic
    defer ticker.Stop()
    for {
        select {
        case <-ctx.Done():
            return nil
        case <-ticker.C:
            c.lastTickerPulse.Store(time.Now().UnixNano())
        }
    }
}

// Run is unchanged from SKILL.md's Consume Loop except for the one added line at the
// bottom of the loop body: the in-loop pulse, reached only once a full batch —
// including every handleRecord call g.Wait() joined on — has actually finished.
func (c *Consumer) Run(ctx context.Context) error {
    for {
        select {
        case <-ctx.Done():
            return c.drain(ctx)
        default:
        }

        fetches := c.client.PollRecords(ctx, c.maxPoll)
        if errs := fetches.Errors(); len(errs) > 0 {
            for _, e := range errs {
                if errors.Is(e.Err, context.Canceled) {
                    return c.drain(ctx)
                }
                slog.ErrorContext(ctx, "fetch error", "topic", e.Topic, "err", e.Err)
            }
            continue
        }
        c.process(ctx, fetches) // if any handleRecord is wedged, g.Wait() inside process never returns, and the line below is never reached
        c.lastLoopPulse.Store(time.Now().UnixNano())
    }
}

// Healthy is read by an HTTP health-check handler (potentially concurrently, from
// multiple requests) — safe with no locking, since atomic.Int64.Load is exactly the
// single-word, lock-free read this primitive is for (Cox-Buday's sync/atomic: cheaper
// than a Mutex when the guarded state is one word).
func (c *Consumer) Healthy() (ok bool, reason string) {
    now := time.Now()
    if age := now.Sub(time.Unix(0, c.lastTickerPulse.Load())); age > 3*c.heartbeatInterval {
        return false, "scheduler unresponsive: ticker pulse stale"
    }
    if age := now.Sub(time.Unix(0, c.lastLoopPulse.Load())); age > c.maxBatchDuration {
        return false, "consume loop wedged: no batch has completed within the expected window"
    }
    return true, ""
}
```

**`c.maxBatchDuration` is a tuning knob, not a fixed constant** — set it generously
above the p99 duration a legitimate, healthy batch actually takes to fully process
(itself a function of `c.maxPoll` and downstream call latency — see
`references/offset-commit-standard.md` §3's batching tradeoff), so a slow-but-healthy
batch never false-positives as wedged. A reasonable starting point, absent product-specific
tuning data: a small multiple (3–5×) of the consumer group's session timeout, since a
batch already taking that long risks becoming an `OnPartitionsLost` event
(`references/rebalance-handling.md` §4) on its own, independent of this health check.

**A channel-based single-reader variant remains valid** when only one goroutine ever
needs to observe the pulse (e.g., a supervisor goroutine that owns the only consumer
of the signal) — a non-blocking `select`/`default` send on a dedicated channel, as
this consumer's earlier design used, is a legitimate simpler alternative in that
narrower case. The `atomic.Int64` version above is the standard whenever more than one
reader needs to observe liveness concurrently — most concretely, an HTTP health
endpoint that can be scraped or polled multiple times without every read racing to
drain the same channel value.

---

## 4. What This Does and Does Not Catch

This standard catches a goroutine that is **scheduled and technically alive but wedged
inside a single blocking call with no timeout of its own** — the specific failure mode
`SKILL.md`'s Purpose section names. It does **not** catch, and is not meant to catch:

- **A genuinely idle consumer with no traffic** — `lastLoopPulse` simply doesn't update
  during a long `PollRecords` wait for new records, because `Run` never entered
  `c.process` at all; there was no batch to finish. `c.maxBatchDuration` bounds
  *batch* duration, not *idle* duration, and must not be conflated with an
  "unhealthy after N seconds of silence" threshold that would misfire during a
  legitimately quiet period. If the product's traffic pattern includes long idle
  gaps, size `c.maxBatchDuration` around batch-processing time specifically, and feed
  `Healthy()`'s result into a human-reviewed alert rather than an automatic
  pod-restart probe that cannot distinguish "quiet" from "wedged" on this signal
  alone.
- **A full-process deadlock** — Go's own runtime deadlock detector already crashes
  the process outright when every goroutine is blocked simultaneously; this heartbeat
  is for the narrower, more dangerous case where the process keeps running and
  *looks* fine from the outside.
