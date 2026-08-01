---
name: go-event-consumer
description: >
  Teaches how to implement a Redpanda/Kafka consumer to a checkable engineering
  standard, not just a consume-loop shape: the idempotent-consumer standard
  (the exact processed_events dedup table schema, the exact
  INSERT ... ON CONFLICT DO NOTHING check placed before any business-logic
  write and inside the same transaction as that write — full standard in
  references/idempotent-consumer-standard.md), the Dead Letter Queue standard
  (the exact x-retry-count header convention, the <topic>.dlq naming
  convention, the original envelope forwarded byte-for-byte unchanged with
  failure metadata carried only in headers — full standard in
  references/dead-letter-queue-standard.md), the consumer-group offset-commit
  standard (manual commit after successful processing, never auto-commit, and
  the per-record/per-batch/per-interval commit-batching tradeoff — full
  standard in references/offset-commit-standard.md), a bounded worker pool for
  parallel processing, retry with backoff, trace-context extraction, rebalance
  handling including exactly what per-partition state must be abandoned, never
  committed, on OnPartitionsLost (full client configuration in
  references/rebalance-handling.md), a two-signal liveness heartbeat
  distinguishing a wedged consume goroutine from healthy idle (full worked
  example in references/liveness-heartbeat.md), and graceful drain on
  shutdown. Implements a stage of the data-architect's data-pipeline-design.
  The idempotency-key contract this consumer's dedup depends on is owned by
  go-event-publisher's EventID construction rule, cross-referenced here, not
  restated. Used by the backend-engineer during Implement.
version: 3.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, consumer, redpanda, kafka, idempotent, worker-pool, dlq, offset-commit, rebalance, heartbeat]
produces: go-event-consumer
domain: backend
status: stable
related: [go-event-publisher, go-concurrency-patterns, go-error-handling, go-service-skeleton, go-integration-test, go-performance-optimization, data-pipeline-design, distributed-tracing-design, multi-tenancy-design, event-schema-design]
---

# Go Event Consumer

## Purpose

A consumer reacts to Domain Events from Redpanda — one stage in the choreographed pipeline (`data-pipeline-design`). Because delivery is at-least-once, the consumer **must be idempotent**: processing the same event twice has the same effect as processing it once. It must also process in parallel for throughput, commit offsets only after success, route poison messages to a Dead Letter Queue, survive rebalances without losing correctness, and drain cleanly on shutdown — bounded worker pools, deterministic goroutine lifetimes, and context-driven cancellation, all in service of correctness under redelivery.

---

## The Consume Loop and Bounded Worker Pool

The consumer runs as a supervised component (`errgroup`, `go-service-skeleton`). It fetches batches and dispatches records to a worker pool bounded by `errgroup.SetLimit` — a hard ceiling on in-flight work so a burst cannot exhaust memory. A per-record failure never cancels the batch (the goroutine always returns `nil`; retry/DLQ handle it internally) — only `ctx.Done()` cancels the group. `process` joins the whole batch with `g.Wait()` and commits **only after** every record is durably processed or DLQ'd:

```go
g.SetLimit(c.concurrency)                 // bounded fan-out
fetches.EachPartition(func(p kgo.FetchTopicPartition) {
    for _, rec := range p.Records {
        g.Go(func() error { c.handleRecord(gctx, rec); return nil })
    }
})
_ = g.Wait()                              // every record durably processed or DLQ'd first
c.client.CommitUncommittedOffsets(ctx)    // then, and only then, commit
```

`kgo.DisableAutoCommit()` is set at client construction — offsets are **never** committed on a timer. Full `process` listing, why autocommit is a lost-message risk, and the per-record/per-batch/per-interval batching tradeoff: `references/offset-commit-standard.md`.

---

## The Idempotent-Consumer Pattern

The dedup record and the work commit in **one transaction** — insert into `processed_events (consumer_name, event_id)` first; if it conflicts, the event was already handled, commit empty and return; otherwise run the business logic and commit together.

```go
ct, err := tx.Exec(ctx, `INSERT INTO processed_events (consumer_name, event_id)
    VALUES ($1,$2) ON CONFLICT DO NOTHING`, c.name, env.EventID)
if err != nil { return err }
if ct.RowsAffected() == 0 { return tx.Commit(ctx) } // duplicate — nothing to do
// business logic runs here, same tx
```

`event_id` is the envelope's `EventID` — always `go-event-publisher`'s outbox row id, never re-derived here (that contract is owned in full by that skill, not restated). `consumer_name` scopes the dedup ledger per pipeline stage, so one stage's replay never collides with another's. Full schema, retention rule, and why the insert must precede business logic in the same tx: `references/idempotent-consumer-standard.md`.

---

## Retry with Backoff, then DLQ

Transient failures retry with exponential backoff + jitter; exhausted or undecodable records route to `<topic>.dlq`, envelope bytes forwarded **unchanged**, with an `x-retry-count` header and failure metadata carried only in headers.

```go
for attempt := 1; ; attempt++ {
    if err := fn(); err == nil || !isTransient(err) || attempt >= c.maxAttempts {
        return err
    }
    select {
    case <-ctx.Done():
        return ctx.Err()
    case <-time.After(backoff + rand.N(backoff)): // fresh Timer per iteration is safe under the pinned golang:1.23-bookworm image
    }
    backoff *= 2
}
```

`attempt` at exhaustion is what `toDLQ` records as `x-retry-count` (§3 of the DLQ standard). Full DLQ standard — exact topic naming, exact header set, why the envelope is never re-marshalled: `references/dead-letter-queue-standard.md`.

---

## Liveness Heartbeat

Consumer lag and DLQ depth both catch a *slow or failing* consumer — neither catches a goroutine that is alive, scheduled, and stuck inside `handleRecord` on a call with no timeout: zero throughput and flat lag look identical to "no work available." Cox-Buday's **Heartbeat Pattern** closes this, but an independently-ticking pulse alone only proves the *process* hasn't hung — not that `Run`'s own goroutine is unstuck. This consumer keeps two `sync/atomic` signals: `lastTickerPulse` (an independent ticker; proves the scheduler is alive) and `lastLoopPulse` (updated once per fully-completed `Run` iteration; proves this specific goroutine made progress — silence here means it's wedged). Full worked example and the reasoning for both signals: `references/liveness-heartbeat.md`.

---

## Rebalance Handling and Graceful Drain

`OnPartitionsRevoked` (graceful handoff) commits finished work before releasing a partition; `OnPartitionsLost` (this instance was already evicted) must **never** commit — it no longer owns the partition — and instead abandons local per-partition bookkeeping only (durable Postgres state is never at risk; see `references/idempotent-consumer-standard.md`). Full client configuration and exactly what "abandon" covers: `references/rebalance-handling.md`.

On shutdown, stop fetching, let in-flight records finish, commit final offsets on a **fresh** bounded context (the parent is already cancelled — reusing it would make the final commit fail immediately), then close:

```go
dctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
defer cancel()
c.client.CommitUncommittedOffsets(dctx) // errors here just mean re-delivery on restart; dedup covers it
c.client.Close()
```

---

## Rules

- **Idempotent always.** Dedup on `(consumer_name, event_id)` in the same tx as the work.
- **Manual commit only**, after `g.Wait()` proves the batch durably processed or DLQ'd.
- **Bounded concurrency.** `errgroup.SetLimit` caps in-flight records; no unbounded `go`.
- **Per-record failure ≠ batch failure.** One bad record goes to DLQ; the batch proceeds.
- **DLQ, never drop.** `<topic>.dlq`, envelope unchanged, `x-retry-count` set once per push.
- **`OnPartitionsLost` never commits.** Only `OnPartitionsRevoked` may.
- **Continue the trace.** Extract trace context from headers; preserve it into DLQ pushes.
- **Graceful drain**, bounded by a deadline under the pod grace period.
- **Two heartbeat signals, not one.** An independent ticker proves the scheduler is alive; an in-loop pulse proves this goroutine specifically isn't wedged.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Idempotency | Dedup + business logic share one `pgx.Tx`, dedup runs first | Work applied before/without dedup, or dedup in a separate tx | Read `handleRecord` for one `tx.Begin`...`tx.Commit` spanning both |
| Dedup key scope | `(consumer_name, event_id)` composite key | `event_id` alone | Read `processed_events`' `PRIMARY KEY` clause |
| Offset discipline | `DisableAutoCommit()` set; commit only after `g.Wait()` | Autocommit enabled, or commit before/inside the worker loop | `grep -n "DisableAutoCommit\|CommitUncommittedOffsets" internal/handlers/events/*.go` |
| Bounded fan-out | `g.SetLimit(c.concurrency)` present | Unbounded goroutine spawn per record | `grep -n "SetLimit" internal/handlers/events/consumer.go` |
| Poison handling | Undecodable/exhausted → DLQ, envelope unchanged | Infinite retry, silent drop, or DLQ value re-marshalled | Read `toDLQ` — `Value: rec.Value`, not a re-encoded struct |
| DLQ topic naming | `<topic>.dlq` | Any other naming, or one shared DLQ topic | `grep -n "dlqTopic" internal/handlers/events/dlq.go` |
| Rebalance safety | `OnPartitionsLost` never calls a commit function | Any commit call inside the lost-partition callback | Read `onPartitionsLost` for the absence of `Commit` |
| Trace continuity | Extracted on consume; re-injected unchanged on DLQ push | New disconnected trace, or headers dropped on DLQ | Read `handleRecord`'s `Extract` and `toDLQ`'s header `append` |
| Graceful drain | In-flight finished, commit on a fresh bounded context | Hard stop, or drain reuses the already-cancelled parent ctx | Read `drain` for `context.WithTimeout(context.Background(), ...)` |
| Heartbeat completeness | Both `lastTickerPulse` and `lastLoopPulse` checked | Only an independent ticker pulse, no in-loop coupling | `grep -n "lastLoopPulse\|lastTickerPulse" internal/handlers/events/consumer.go` |

---

## Anti-Patterns

- **Auto-commit** — offsets advanced on a timer regardless of processing outcome; a crash between the tick and completion silently loses events.
- **Dedup in memory or in a separate transaction** — resets on restart, invisible to other instances, or reintroduces the dual-write race the pattern exists to close.
- **Retrying poison messages forever, or failing the whole batch on one bad record** — the first blocks the partition head; the second cancels healthy siblings over one failure.
- **A shared DLQ topic across source topics, or a DLQ value that isn't the original bytes unchanged** — the first makes DLQ depth ambiguous; the second discards the one thing an undecodable record can still preserve.
- **Committing inside `OnPartitionsLost`** — this instance no longer owns the partition; a commit here races or is rejected.
- **A heartbeat pulse from an independent ticker alone** — proves the process is scheduled, not that this consume goroutine specifically isn't wedged inside `handleRecord`.

---

## Output Format

Go source built exactly to the standards above, plus integration tests against real Redpanda and PostgreSQL via Testcontainers (`go-integration-test` owns the harness):

```
internal/handlers/events/consumer.go         (Consumer, Run, process, handleRecord, drain, onPartitionsLost)
internal/handlers/events/dlq.go              (toDLQ, dlqTopic)
internal/handlers/events/consumer_test.go    (written first — TDD; includes a duplicate-delivery test)
```

Full standards: `references/idempotent-consumer-standard.md`, `references/dead-letter-queue-standard.md`, `references/offset-commit-standard.md`, `references/rebalance-handling.md`, `references/liveness-heartbeat.md`.
