---
name: go-event-consumer
description: >
  Teaches how to implement an idempotent Redpanda consumer — the consume loop,
  the idempotent-consumer pattern (dedup on event id in the same transaction as
  the work), a bounded worker pool for parallel processing, manual offset commits
  after successful processing, retry with backoff, Dead Letter Queue routing,
  trace-context extraction, and graceful drain on shutdown. Implements a stage of
  the data-architect's data-pipeline-design. Used by the backend-engineer during
  Implement.
version: 1.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, consumer, redpanda, kafka, idempotent, worker-pool, dlq]
---

# Go Event Consumer

## Purpose

A consumer reacts to Domain Events from Redpanda — it is one stage in the choreographed pipeline (see `data-pipeline-design`). Because delivery is at-least-once, the consumer **must be idempotent**: processing the same event twice has the same effect as processing it once. It must also process in parallel for throughput, commit offsets only after success, route poison messages to a Dead Letter Queue (DLQ), and drain cleanly on shutdown.

This is where the blueprint's concurrency engineering meets the pipeline: bounded worker pools, deterministic goroutine lifetimes, and context-driven cancellation, all in service of correctness under redelivery.

---

## The Consume Loop

The consumer runs as a supervised component (errgroup, `go-service-skeleton`). It fetches batches and dispatches records to a bounded worker pool. Offsets are committed manually, only after a record is durably processed.

```go
// internal/handlers/events/consumer.go
package events

func (c *Consumer) Run(ctx context.Context) error {
    for {
        select {
        case <-ctx.Done():
            return c.drain(ctx) // stop fetching; finish in-flight; commit; close
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
        c.process(ctx, fetches)
    }
}
```

---

## Bounded Worker Pool (Fan-Out / Fan-In)

Records are processed concurrently, but with a hard ceiling on in-flight work so a burst cannot exhaust memory or overwhelm downstream stores. The pool uses `errgroup.SetLimit` — simple, bounded, leak-free.

```go
func (c *Consumer) process(ctx context.Context, fetches kgo.Fetches) {
    g, gctx := errgroup.WithContext(ctx)
    g.SetLimit(c.concurrency) // bounded fan-out: at most N records processed at once

    fetches.EachPartition(func(p kgo.FetchTopicPartition) {
        for _, rec := range p.Records {
            g.Go(func() error {
                c.handleRecord(gctx, rec) // never returns an error that cancels siblings; see below
                return nil
            })
        }
    })
    _ = g.Wait() // join: all records in the batch are handled before we commit offsets

    // Commit only after the whole batch is durably processed (or DLQ'd).
    if err := c.client.CommitUncommittedOffsets(ctx); err != nil {
        slog.ErrorContext(ctx, "offset commit failed", "err", err) // re-delivered next poll; idempotency covers it
    }
}
```

A per-record failure does **not** cancel the batch (we return `nil` from the goroutine) — it is handled by retry/DLQ inside `handleRecord`. We only let the group context cancel on shutdown.

---

## The Idempotent-Consumer Pattern

The dedup record and the work commit in **one transaction**. If the event was already processed, the insert conflicts and we skip. This is the same shape across every pipeline stage (see `data-pipeline-design`).

```go
func (c *Consumer) handleRecord(ctx context.Context, rec *kgo.Record) {
    ctx = otel.GetTextMapPropagator().Extract(ctx, kafkaHeaderCarrier{rec}) // continue the trace
    ctx, span := c.tracer.Start(ctx, "consume "+rec.Topic)
    defer span.End()

    env, err := decodeEnvelope(rec.Value)
    if err != nil {
        c.toDLQ(ctx, rec, fmt.Errorf("undecodable: %w", err)) // poison message: don't retry forever
        return
    }

    err = c.withRetry(ctx, func() error {
        tx, err := c.pool.Begin(ctx)
        if err != nil {
            return err
        }
        defer tx.Rollback(ctx) //nolint:errcheck

        // Dedup: insert (consumer, event_id); conflict ⇒ already processed ⇒ skip.
        ct, err := tx.Exec(ctx,
            `INSERT INTO processed_events (consumer_name, event_id) VALUES ($1,$2)
             ON CONFLICT DO NOTHING`, c.name, env.EventID)
        if err != nil {
            return err
        }
        if ct.RowsAffected() == 0 {
            return tx.Commit(ctx) // duplicate — nothing to do
        }

        // Do the work AND write any output event to the outbox — same tx.
        if err := c.work(ctx, tx, env); err != nil {
            return err
        }
        return tx.Commit(ctx)
    })
    if err != nil {
        c.toDLQ(ctx, rec, err) // retries exhausted
        span.RecordError(err)
    }
}
```

The dedup row and the work are atomic, so a crash mid-processing rolls back both — the event is re-delivered and re-processed cleanly.

---

## Retry with Backoff, then DLQ

Transient failures (a brief DB blip) are retried with exponential backoff + jitter. After a bounded number of attempts, the record goes to the Dead Letter Queue — it must never block the partition or be silently dropped (see `data-pipeline-design`).

```go
func (c *Consumer) withRetry(ctx context.Context, fn func() error) error {
    backoff := 100 * time.Millisecond
    for attempt := 1; ; attempt++ {
        err := fn()
        if err == nil || !isTransient(err) || attempt >= c.maxAttempts {
            return err
        }
        sleep := backoff + rand.N(backoff) // jitter (math/rand/v2: rand.N works on Duration directly)
        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-time.After(sleep):
        }
        backoff *= 2
    }
}
```

The DLQ record retains the original payload, the `tenant_id`, and the failure reason, on a `<stage>-dlq` topic. DLQ depth is an alerting metric.

---

## Graceful Drain

On shutdown, stop fetching, let in-flight records finish, commit final offsets, then close the client. No record is abandoned mid-flight; no offset is committed for unprocessed work.

```go
func (c *Consumer) drain(ctx context.Context) error {
    // The parent ctx is already cancelled at this point — use a fresh, bounded context for the final commit.
    dctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
    defer cancel()
    if err := c.client.CommitUncommittedOffsets(dctx); err != nil {
        slog.ErrorContext(dctx, "final offset commit failed", "err", err) // re-delivery on restart; idempotency covers it
    }
    c.client.Close()
    return nil
}
```

---

## Rebalance Handling

When the consumer group rebalances (a pod scales, deploys, or dies), partitions are revoked and reassigned. Two rules keep redelivery to a minimum and correctness absolute:

- **Commit before revocation.** Register an on-revoked callback so offsets for finished work are committed before the partition moves to another instance:

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

- **Rebalance is not an error path.** A rebalance mid-batch means some records get redelivered to the new owner — the idempotent-consumer dedup makes that a no-op, which is exactly why idempotency is non-negotiable rather than nice-to-have.

Keep per-batch processing time well under the group's session/rebalance timeouts, or the broker will evict the consumer and thrash the group.

---

## Rules

- **Idempotent always.** Dedup on `eventId` in the same tx as the work.
- **Commit offsets after success**, never before processing.
- **Bounded concurrency.** `errgroup.SetLimit` caps in-flight records; no unbounded `go`.
- **Per-record failure ≠ batch failure.** One bad record goes to DLQ; the batch proceeds.
- **DLQ, never drop.** Exhausted retries route to a monitored DLQ.
- **Continue the trace.** Extract trace context from headers.
- **Graceful drain** bounded by a deadline under the pod grace period.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Idempotency | Dedup + work in one tx | Work applied before/without dedup |
| Offset discipline | Commit after durable processing | Auto-commit / commit-before-process |
| Bounded fan-out | `SetLimit` caps concurrency | Unbounded goroutine spawn per record |
| Poison handling | Undecodable/exhausted → DLQ | Infinite retry on a poison message; or silent drop |
| Trace continuity | Trace extracted from headers | New disconnected trace per consume |
| Graceful drain | In-flight finished, offsets committed, deadline-bounded | Hard stop dropping in-flight work |

---

## Anti-Patterns

- **Auto-commit** — offsets committed on a timer regardless of whether processing succeeded. A crash between commit and completion silently loses events.
- **Dedup in memory** — a `map[uuid.UUID]bool` of seen events resets on restart and is invisible to other instances. Dedup must be durable and transactional with the work.
- **Dedup in a separate transaction** — marking the event processed, then doing the work (or vice versa) reintroduces the dual-write race the pattern exists to close.
- **Retrying poison messages forever** — an undecodable or permanently-failing record blocks its partition head. Bounded retries, then DLQ.
- **Failing the batch on one bad record** — returning the error into the errgroup cancels healthy siblings and turns one poison message into a stalled consumer.
- **Starting a new root span per record** — dropping the incoming trace context breaks the producer-to-consumer trace; extract from headers first.

---

## Output Format

Produces Go source plus integration tests (Redpanda + PostgreSQL via testcontainers):

```
internal/handlers/events/consumer.go
internal/handlers/events/dlq.go
internal/handlers/events/consumer_test.go   (written first; includes duplicate-delivery test)
```
