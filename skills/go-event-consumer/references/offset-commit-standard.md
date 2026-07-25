# The Offset-Commit Standard — Manual Commit After Success, and the Batching Tradeoff

Full worked material referenced from `SKILL.md`'s "Bounded Worker Pool (Fan-Out /
Fan-In)" section. Self-contained — reads without the parent body already in context.
Covers: why offsets are always committed manually and never on an autocommit timer,
exactly where the commit call sits relative to processing, and the commit-granularity
tradeoff between re-processing window and commit overhead.

---

## 1. Manual Commit, Never Autocommit — Stated as a Rule

The client is constructed with autocommit disabled:

```go
kgo.NewClient(
    kgo.ConsumerGroup(c.group),
    kgo.DisableAutoCommit(), // this consumer commits explicitly, only after a batch is durably processed
    kgo.Balancers(kgo.CooperativeStickyBalancer()),
    // ...
)
```

**Why autocommit is disallowed, precisely.** An autocommit timer advances the
consumer group's committed offset on a fixed interval, independent of whether the
records it covers were actually processed successfully — it knows only that they
were *fetched*, not that `handleRecord` finished, committed its transaction, or even
started. A crash between an autocommit tick and the completion of in-flight
processing silently advances the offset past work that never happened: on restart,
those records are never redelivered, because the broker believes this consumer
group already consumed them. This is not a rare edge case — it is autocommit's
normal behavior under its normal failure mode, and it is a **lost** message, not a
duplicate one, which the idempotent-consumer standard (`references/idempotent-consumer-standard.md`)
has no way to detect or repair, since the record data no longer exists in local
memory once the process restarts. Manual commit closes this by making the commit
itself the last thing that happens, after the work it certifies as done.

---

## 2. Exactly Where the Commit Runs

```go
func (c *Consumer) process(ctx context.Context, fetches kgo.Fetches) {
    g, gctx := errgroup.WithContext(ctx)
    g.SetLimit(c.concurrency)

    fetches.EachPartition(func(p kgo.FetchTopicPartition) {
        for _, rec := range p.Records {
            g.Go(func() error {
                c.handleRecord(gctx, rec) // dedup + business logic, or DLQ — never returns an error to the group
                return nil
            })
        }
    })
    _ = g.Wait() // every record in this batch is either durably processed or DLQ'd before the next line runs

    if err := c.client.CommitUncommittedOffsets(ctx); err != nil {
        slog.ErrorContext(ctx, "offset commit failed", "err", err) // commit itself failed — records are re-delivered next poll; idempotency (§1 of the dedup standard) covers it
    }
}
```

**The commit call is the last statement in `process`, after `g.Wait()` returns.**
`g.Wait()` blocks until every `handleRecord` goroutine in the batch has finished —
which means either its transaction committed (dedup row + business-logic write, or a
duplicate skip) or the record was routed to the DLQ (`references/dead-letter-queue-standard.md`).
A record is never left in a state where the offset advances past it but no outcome —
success or DLQ — was recorded for it.

**If the commit call itself fails** (a transient broker/network issue distinct from
the processing that already succeeded), the batch's records are already durably
processed or DLQ'd — only the *offset* failed to advance. The next poll re-delivers
the same records; the idempotent-consumer dedup insert (§3 of
`references/idempotent-consumer-standard.md`) makes the redundant reprocessing a
no-op rather than a correctness problem. This is the same reasoning
`references/rebalance-handling.md` applies to a rebalance-induced redelivery — a
failed commit and a rebalance both produce the identical, already-handled-safely
outcome: redelivery of already-processed work, absorbed by dedup.

---

## 3. The Commit-Batching Tradeoff

**The commit granularity in this consumer is exactly the fetched batch** — one
`CommitUncommittedOffsets` call per `process` invocation, which covers however many
records `PollRecords(ctx, c.maxPoll)` returned across however many partitions this
instance owns. Three granularities are possible in general; this consumer's default
is the middle one, and the reasoning below states why deviating from it in either
direction is rarely worth it:

| Granularity | Re-processing window on crash | Commit RPC volume | When it's the right call |
|---|---|---|---|
| **Per record** — commit after every single `handleRecord` | Smallest possible: at most one record re-processed | Highest — one commit RPC per record, defeating the purpose of fetching in batches | Only when `maxPoll` is forced very small for an unrelated reason (e.g., extremely large individual payloads); not a general-purpose default |
| **Per batch (this consumer's default)** | Up to one full `maxPoll` batch's worth of already-successfully-processed-but-uncommitted records | One commit RPC per poll cycle — proportional to throughput, not record count | The correct default whenever the dedup standard is in place, because the "cost" of this window is reprocessing work, not lost or duplicated data |
| **Per fixed interval** (a ticker, decoupled from batch boundaries) | Bounded by the interval, independent of batch size | Lower than per-record, but requires tracking "offsets advanced since last commit" across multiple batches — added bookkeeping | Only when `maxPoll` is deliberately large enough that a single batch's processing time would otherwise make the per-batch window unacceptably wide |

**Why per-batch is correct here, stated precisely: because `references/idempotent-consumer-standard.md`
already makes reprocessing *correctness-safe*, the commit-batching choice is purely a
performance/latency tradeoff (how much already-done work might be redundantly
repeated after a crash), never a correctness one.** A system without a durable,
transactional dedup mechanism would need to weigh this choice much more carefully,
since a wider commit-batching window would mean a wider window of *genuinely* at-risk
duplicate side effects. Here, the dedup table absorbs that risk entirely — the only
real cost of a larger `maxPoll`/wider commit window is wasted CPU and I/O
re-doing work whose outcome was already correct and already recorded, bounded by how
large `maxPoll` is configured to be.

**Tune `maxPoll`, not commit frequency, to change this tradeoff.** Because the commit
call is anchored to `g.Wait()` completing (§2), the only lever that changes the
re-processing window is the batch size itself — the same `maxPoll` value that also
governs the bounded worker pool's peak concurrency (`SKILL.md`'s "Bounded Worker Pool"
section) and the per-batch processing time `references/rebalance-handling.md` warns
must stay well under the consumer group's session/rebalance timeouts. All three
concerns — commit-window width, peak fan-out, and rebalance-timeout headroom — are
governed by the one `maxPoll` knob, which is why it is a single, deliberately-tuned
configuration value rather than three independent ones.
