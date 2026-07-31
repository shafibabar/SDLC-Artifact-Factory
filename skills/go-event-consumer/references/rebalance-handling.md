# Rebalance Handling — Full Client Configuration and What Must Be Abandoned on a Lost Partition

Full worked material referenced from `SKILL.md`'s "Rebalance Handling" section.
Self-contained — reads without the parent body already in context. Covers: committing
before a graceful revocation, cooperative sticky balancing, and — the standard this
file exists to deepen — the distinction between a partition **revoked** (a graceful
handoff) and a partition **lost** (this instance was already evicted from the group),
and exactly what local state must be abandoned, never committed, in the lost case.

---

## 1. Committing Before Revocation

When the consumer group rebalances (a pod scales, deploys, or dies), partitions are
revoked and reassigned. Register an on-revoked callback so offsets for finished work
are committed before a partition moves to another instance, and pair it with
cooperative sticky balancing (incremental rebalance — untouched partitions keep
flowing) and `BlockRebalanceOnPoll` (no rebalance while a polled batch is still
mid-processing):

```go
kgo.NewClient(
    kgo.ConsumerGroup(c.group),
    kgo.Balancers(kgo.CooperativeStickyBalancer()), // incremental rebalance — untouched partitions keep flowing
    kgo.OnPartitionsRevoked(func(ctx context.Context, cl *kgo.Client, revoked map[string][]int32) {
        if err := cl.CommitUncommittedOffsets(ctx); err != nil {
            slog.ErrorContext(ctx, "commit on revoke failed", "err", err)
        }
    }),
    kgo.OnPartitionsLost(c.onPartitionsLost), // §2 — a structurally different case; never commits
    kgo.BlockRebalanceOnPoll(), // no rebalance while a polled batch is still being processed
)
```

`OnPartitionsRevoked` fires when this instance **gracefully** hands partitions to
another group member — it still owns them at the moment the callback runs, so
committing offsets for finished work here is safe and correct: no other consumer has
started reading from those partitions yet.

---

## 2. `OnPartitionsLost`: A Structurally Different Case, and What Must Be Abandoned

A partition is **lost**, not revoked, when this instance falls out of the consumer
group *before* it could hand partitions off gracefully — a missed heartbeat past the
group's session timeout, a network partition, or a process that was too slow to
respond to a rebalance in time. By the moment `OnPartitionsLost` fires, **this
instance no longer owns the partition** — the group coordinator has already
reassigned it, and another consumer may already be reading from it, possibly
mid-processing a record this instance also fetched but never finished.

```go
func (c *Consumer) onPartitionsLost(ctx context.Context, cl *kgo.Client, lost map[string][]int32) {
    // NEVER call CommitUncommittedOffsets (or any commit) here. This instance does
    // not own these partitions anymore — a commit attempt either fails outright
    // (the broker rejects a commit from a consumer no longer assigned that
    // partition) or, worse, races the new owner's own in-flight commits with no
    // defined ordering between the two.
    for topic, partitions := range lost {
        slog.WarnContext(ctx, "partitions lost — abandoning local state, not committing",
            "topic", topic, "partitions", partitions)
    }
    c.abandonLocalState(lost) // §3
}
```

**Why committing here is actively wrong, not merely unnecessary.** `OnPartitionsRevoked`
commits are safe because the handoff hasn't happened yet — this instance is still the
system of record for those offsets at the moment it commits. `OnPartitionsLost` fires
*after* the handoff already happened without this instance's cooperation; a commit
attempted here is trying to write authoritative state for a partition this instance is
no longer authoritative over. The correct action is silence on the broker side and
cleanup on the local side.

---

## 3. What "Abandon" Means, Concretely

**Abandoning local state does not mean the in-flight `handleRecord` goroutines
processing a lost partition's records become unsafe — they remain safe by
construction**, because `handleRecord`'s dedup insert and business-logic write share
one transaction (`references/idempotent-consumer-standard.md` §3): whichever consumer
instance's transaction actually commits first for a given `(consumer_name, event_id)`
pair wins, and every other attempt at that same pair — whether from this instance
finishing a stale in-flight call or the new owner redelivering and reprocessing the
same record — becomes a no-op dedup skip. The correctness guarantee does not depend
on which instance happens to own the partition at commit time.

**What genuinely must be dropped is *bookkeeping* state scoped to the lost
partition(s)** — anything this consumer tracks in memory, per partition, that is not
already durable in Postgres:

- **Any locally-cached "next offset to commit" tracking** kept outside `kgo`'s own
  internal state, if this consumer's design ever adds one (e.g., a per-partition
  counter used to batch commits on an interval — `references/offset-commit-standard.md`
  §3's interval-based granularity option, if adopted). Carrying this forward into
  whatever partitions this instance keeps or is later reassigned risks committing an
  offset for a partition it doesn't currently own, or committing a stale offset if
  the same partition comes back to this instance in a future rebalance.
- **Per-partition backoff/rate-limiting counters**, if `withRetry` (`SKILL.md`'s
  "Retry with Backoff, then DLQ") is ever scoped per partition rather than per record —
  a partition's failure history is not this instance's concern once it no longer owns
  that partition.
- **Any partition-scoped in-memory cache** a future extension of this consumer might
  add (e.g., a small LRU keyed by partition for a hot lookup) — must be evicted for
  lost partitions specifically, not merely left to expire on its own TTL, since a stale
  entry silently answered against a partition this instance no longer authoritatively
  reads from is a correctness risk the TTL alone does not bound tightly enough.

**What must never be abandoned:** anything already durable — `processed_events` rows
and business-logic writes already committed to Postgres are permanent facts,
independent of which consumer instance produced them, and are not "local state" in
this sense at all. Abandonment applies exclusively to in-memory bookkeeping this
consumer process holds and nothing else; the durable side of the idempotent-consumer
standard is what makes it safe to be this aggressive about dropping the in-memory side
without a data-loss risk.

---

## 4. Rebalance Is Not an Error Path

A rebalance mid-batch — whether a graceful revocation (§1) or an ungraceful loss (§2)
— means some records get redelivered to the new owner. The idempotent-consumer dedup
(`references/idempotent-consumer-standard.md`) makes that redelivery a no-op, which is
exactly why idempotency is non-negotiable rather than nice-to-have: this standard is
what turns "a rebalance happened mid-batch" from an incident into routine, expected
operation.

Keep per-batch processing time (`references/offset-commit-standard.md` §3's `maxPoll`
tradeoff) well under the group's session/rebalance timeouts, or the broker evicts the
consumer for missing heartbeats during a long batch — turning what would have been an
`OnPartitionsRevoked` (graceful) into an `OnPartitionsLost` (ungraceful) on every such
occurrence, and thrashing the group as instances repeatedly fall out and rejoin.
