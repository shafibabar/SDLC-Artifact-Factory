# Liveness Heartbeat — Full Worked Example

Full worked material referenced from `SKILL.md`'s "Liveness Heartbeat" section.

---

## Why Lag and DLQ Depth Aren't Enough

Consumer lag and DLQ depth both catch a consumer that is *slow* or *failing* — but neither catches a consumer goroutine that is alive, scheduled, and stuck: blocked indefinitely inside `handleRecord` on a call with no timeout, or wedged in a loop. Zero throughput and flat lag look identical to "no work available" until an operator notices lag is *also* flat and misreads a hang as healthy idle — both metrics only move when a message is actually processed, never merely because the goroutine still exists. Cox-Buday's **heartbeat pattern** closes this blind spot: the main loop emits a periodic liveness pulse on its own dedicated channel, distinct from the processing path, so a supervisor can tell "alive and idle" from "stuck" even when zero records are flowing.

## Ticker-Driven Heartbeat

```go
func (c *Consumer) heartbeatLoop(ctx context.Context) {
    ticker := time.NewTicker(c.heartbeatInterval) // independent of message traffic
    defer ticker.Stop()
    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            select {
            case c.alive <- struct{}{}: // non-blocking: an unread pulse must never stall this goroutine
            default:
            }
        }
    }
}
```

Run this as a sibling errgroup member alongside the consume loop (see `go-service-skeleton`), and have a health-check handler or supervisor read `c.alive` with its own timeout: a missed pulse or two is noise, but silence across several intervals means the main loop stopped executing — independent of whether any record happens to be in flight. The send is a non-blocking `select`/`default` specifically so a slow or absent reader on `c.alive` can never itself become the reason the consume loop stalls.
