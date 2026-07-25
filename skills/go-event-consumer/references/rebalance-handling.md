# Rebalance Handling — Full Client Configuration

Full worked material referenced from `SKILL.md`'s "Rebalance Handling" section.

---

## Committing Before Revocation

When the consumer group rebalances (a pod scales, deploys, or dies), partitions are revoked and reassigned. Register an on-revoked callback so offsets for finished work are committed before a partition moves to another instance, and pair it with cooperative sticky balancing (incremental rebalance — untouched partitions keep flowing) and `BlockRebalanceOnPoll` (no rebalance while a polled batch is still mid-processing):

```go
kgo.NewClient(
    kgo.ConsumerGroup(c.group),
    kgo.Balancers(kgo.CooperativeStickyBalancer()), // incremental rebalance — untouched partitions keep flowing
    kgo.OnPartitionsRevoked(func(ctx context.Context, cl *kgo.Client, _ map[string][]int32) {
        if err := cl.CommitUncommittedOffsets(ctx); err != nil {
            slog.ErrorContext(ctx, "commit on revoke failed", "err", err)
        }
    }),
    kgo.BlockRebalanceOnPoll(), // no rebalance while a polled batch is still being processed
)
```

## Rebalance Is Not an Error Path

A rebalance mid-batch means some records get redelivered to the new owner — the idempotent-consumer dedup (`SKILL.md`'s "The Idempotent-Consumer Pattern") makes that a no-op, which is exactly why idempotency is non-negotiable rather than nice-to-have.

Keep per-batch processing time well under the group's session/rebalance timeouts, or the broker will evict the consumer and thrash the group.
