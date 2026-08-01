---
name: go-event-publisher
description: >
  Teaches how to implement reliable Domain Event publication via the
  Transactional Outbox to a checkable engineering standard, not just a relay
  loop shape: the exact outbox table schema and the exact SQL that inserts an
  outbox row in the same transaction as the aggregate's state change (owned in
  full by go-repository-pattern; this skill is the relay that drains it), the
  poller-based relay/drain loop with FOR UPDATE SKIP LOCKED, why this produces
  at-least-once (never exactly-once) delivery and why that is the correct
  tradeoff given idempotent consumers, the memory-bounded batching standard
  (preallocated slices sized to the query's own LIMIT, never unbounded
  append-growth) and its batch-size/batch-timeout latency tradeoff, the
  backpressure standard for a slow or unavailable broker (the outbox absorbs
  it by construction — no queue to overflow, no caller ever blocks on a
  publish), and the deterministic idempotency-key construction rule a
  consumer's dedup depends on (the outbox row's own id, stable across
  re-publication, never a fresh UUID per attempt). Full outbox schema, atomic
  insert SQL, and relay loop in
  references/transactional-outbox-standard.md; full batching, backpressure,
  and idempotency-key depth in
  references/batching-backpressure-and-idempotency.md. Used by the
  backend-engineer during Implement.
version: 2.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, outbox, redpanda, kafka, event-publishing, at-least-once, relay, backpressure, idempotency, batching]
produces: go-outbox-relay
domain: backend
status: stable
related: [go-repository-pattern, go-event-consumer, go-concurrency-patterns, go-error-handling, go-service-skeleton, go-performance-optimization, go-migration, event-schema-design, data-pipeline-design, distributed-tracing-design, go-integration-test, multi-tenancy-design]
---

# Go Event Publisher

## Purpose

A service must publish a Domain Event whenever it changes state — reliably, even across crashes. Publishing directly from a request handler is unsafe: a crash between the DB commit and the broker publish silently loses the event (the dual-write problem). The **Transactional Outbox** closes this gap by splitting the work in two: `go-repository-pattern`'s `Save` writes the event into an `outbox` table in the *same transaction* as the aggregate's state change, so recording an event is exactly as atomic as the write that caused it; this skill builds the **relay** — a separate, independently-failing process that reliably drains that table to Redpanda. Full schema and atomic-insert SQL: `references/transactional-outbox-standard.md`.

Decoupling *recording* (transactional, free) from *publishing* (network I/O, can fail, can be slow) is what makes at-least-once delivery achievable without a distributed transaction spanning the database and the broker.

---

## The Relay Loop and Draining a Batch

The relay runs as a supervised component in the composition root's `errgroup` (`go-service-skeleton`): it starts when the group starts and stops the instant `ctx.Done()` fires, never leaving a transaction open across shutdown — `go-concurrency-patterns`' general goroutine-lifecycle rule, applied to the one goroutine this skill owns. `Run` ticks on a fixed `interval`; each tick calls `drainOnce`, which opens one `pgx.Tx`, claims up to `batch` unpublished rows with `SELECT ... FOR UPDATE SKIP LOCKED` (so concurrent relay *replicas* never double-claim a row), publishes them, marks them published, and commits. A failed drain logs and returns `nil` from `Run` — never fatal, since a transient broker outage must not crash the process; the unpublished rows simply wait for the next tick (the mechanism behind the backpressure standard below). Full `Run`/`drainOnce` listing: `references/transactional-outbox-standard.md`.

**`records` and `ids` are preallocated to `r.batch`** (`make([]*kgo.Record, 0, r.batch)`), not grown by bare `append` — the query's own `LIMIT $1` already bounds `rows.Next()` to at most `r.batch` iterations, so the capacity is known before the loop starts (`go-performance-optimization`'s Preallocate Slices and Maps rule). This is the memory-bounded batching fix this skill is built around; the full tradeoff standard it generalizes is in `references/batching-backpressure-and-idempotency.md`.

**Publish, then mark — never the reverse.** `drainOnce` calls `ProduceSync` *before* the `UPDATE outbox SET published_at = now()`. If the process crashes after `ProduceSync` succeeds but before `Commit`, the transaction rolls back, `published_at` stays `NULL`, and the row is re-claimed and re-published next tick: at-least-once, by construction. Marking first and publishing second would risk the opposite failure — a row marked published that the broker never actually received — which is unacceptable. Full at-least-once reasoning and why exactly-once is not attempted: `references/transactional-outbox-standard.md`.

---

## Backpressure: Why a Slow or Down Broker Cannot Overflow Anything

A slow or unavailable broker is ordinary operation, not an incident, for this design: a `ProduceSync` error just means `drainOnce` returns early with nothing marked published, and the rows it read stay exactly where they were — durable rows in a Postgres table, not messages in a fixed-capacity in-memory queue. Nothing upstream of the outbox ever talks to the broker directly (the aggregate save already committed and returned before the relay's next tick runs), so there is no buffer to overflow and no caller blocked on a publish. The outbox *is* the backpressure mechanism: unpublished rows accumulate as backlog until the broker recovers, drained at whatever rate it can sustain. Full standard, including the one caller-visible growth this shifts responsibility to (outbox table size under sustained outage) and how to observe it: `references/batching-backpressure-and-idempotency.md`.

---

## The Envelope, Partition Key, and Idempotency Key

Each outbox row becomes one Redpanda record with the standard envelope (`event-schema-design`) and W3C trace context propagated into headers so the consumer continues the same trace (`distributed-tracing-design`).

```go
func (r *OutboxRelay) toRecord(ctx context.Context, m outboxRow) *kgo.Record {
    env := Envelope{
        EventID:       m.id, // idempotency key — see the standard below
        EventType:     m.eventType,
        SchemaVersion: 1,
        OccurredAt:    m.occurredAt,
        AggregateID:   m.aggregateID,
        TenantID:      m.tenantID,
        Payload:       m.payload, // already-marshalled JSON from the repo
    }
    value, err := json.Marshal(env)
    if err != nil {
        panic(fmt.Sprintf("marshal envelope for outbox row %s: %v", m.id, err)) // marshal-safe fields; reaching here is a bug
    }
    rec := &kgo.Record{Topic: topicFor(m.eventType), Key: m.tenantID[:], Value: value}
    otel.GetTextMapPropagator().Inject(ctx, kafkaHeaderCarrier{rec})
    return rec
}
```

**Idempotency-key construction rule: the envelope's `EventID` is always the outbox row's own primary-key `id` — never a freshly generated `uuid.New()` at publish time.** This is what makes a crash-replay safe: the same row re-published after a rollback carries the *same* `EventID`, so the consumer's `processed_events` dedup insert (`go-event-consumer`) conflicts and the duplicate is a no-op. A fresh id per attempt would make every replay look like a new event and defeat Idempotency entirely. **Partition key = `tenant_id`** — preserves per-tenant ordering and gives Competing Consumers a natural parallelism boundary (`data-pipeline-design`). Full construction rule and the two things that must never be used as the key instead: `references/batching-backpressure-and-idempotency.md`.

---

## Rules

- **Publish before mark.** Never set `published_at` before `ProduceSync` succeeds.
- **`SKIP LOCKED`** so replicas never double-claim a row; safe horizontal scaling.
- **Preallocate the batch buffers.** `make([]T, 0, r.batch)`, never a bare `var` grown by `append` alone.
- **`EventID` = outbox row id, always.** The one fact the entire idempotency chain depends on.
- **Partition by `tenant_id`.** Ordering, isolation, and parallelism from one key choice.
- **Propagate trace context** into record headers — the trace must survive the broker hop.
- **Graceful stop on `ctx.Done()`.** No transaction ever left open across shutdown.
- **The relay ships rows; it never decides what to ship.** Filtering/suppressing events here is a defect — the repository already decided what happened.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Outbox insert is atomic with the aggregate write | Outbox `INSERT` and aggregate `UPDATE` share one `pgx.Tx` (`go-repository-pattern`'s `Save`) | A publish-adjacent `INSERT INTO outbox` outside that transaction | Read `Save`; confirm the outbox insert uses the same `Querier` as the state-changing statement |
| At-least-once, never mark-then-publish | `drainOnce` calls `ProduceSync` before `UPDATE ... SET published_at` | `published_at` set, or set inside the same statement as the produce call, before `ProduceSync` returns success | Read `drainOnce` top to bottom; the `UPDATE` must textually follow a checked `ProduceSync` error return |
| Concurrent-safe drain | `SELECT ... FOR UPDATE SKIP LOCKED` in the claim query | Plain `SELECT` with no locking clause | Read the claim query for `FOR UPDATE SKIP LOCKED` |
| Memory-bounded batching | `records`/`ids` preallocated `make(..., 0, r.batch)` | Bare `var records []*kgo.Record` grown by `append` alone, or `r.batch` unbounded | `grep -n "make(\[\]" internal/infrastructure/messaging/outbox_relay.go` shows the capacity argument |
| Backpressure requires no new code path | A failed `ProduceSync` returns an error from `drainOnce` and nothing else | A retry loop, buffer, or circuit breaker bolted onto the relay to "handle" broker slowness | Read `drainOnce`'s produce-error branch — it must be a single `return fmt.Errorf(...)`, nothing more |
| Stable idempotency key | Envelope `EventID` = outbox row `id`, read from the same row it's attached to | `uuid.New()` (or any other fresh id) called inside `toRecord` | `grep -n "uuid.New()" internal/infrastructure/messaging/outbox_relay.go` — no hits |
| Tenant partitioning | Record `Key` = `tenant_id` | Random, absent, or event-id partition key | Read `toRecord`'s `kgo.Record{Key: ...}` field |
| Trace continuity | `otel.GetTextMapPropagator().Inject` called on every record | No header injection, or injection skipped on any path | Read `toRecord` for the `Inject` call on every return |
| Graceful shutdown | `Run` returns `nil` on `ctx.Done()` with no transaction left open | A path where `ctx.Done()` fires mid-`drainOnce` with the `tx` neither committed nor rolled back | Read `Run`'s `select` — `ctx.Done()` only fires between ticks, never inside `drainOnce`, and `drainOnce`'s `defer tx.Rollback` covers every return |
| No business logic in the relay | `drainOnce`/`toRecord` only read, serialize, and publish rows | Any conditional that decides *whether* a row gets published based on its content | Read the full file for an `if` branch that skips a row without an error |
| One goroutine, one owner | `Run` is the only goroutine this package starts; no bare `go func()` inside `drainOnce` or `toRecord` | A per-record or per-batch goroutine spawned to "parallelize" publishing | `grep -n "go func" internal/infrastructure/messaging/*.go` — no hits |

---

## Anti-Patterns

- **Publishing directly from the request handler** — the dual-write problem the Transactional Outbox exists to solve: a crash between DB commit and broker publish silently loses the Domain Event.
- **Mark-then-publish** — updating `published_at` before `ProduceSync` succeeds converts a crash into a *lost* event, not a harmless duplicate.
- **A fresh `uuid.New()` per publish attempt** — makes every crash-replay look like a new event to consumers and defeats Idempotency downstream (`go-event-consumer`).
- **Random or absent partition key** — scatters one tenant's events across partitions, destroying per-tenant ordering and isolation in one stroke.
- **Deleting outbox rows instead of marking them published** — loses the audit trail and replay capability; sweep old *published* rows with a retention job instead.
- **Bolting retry/circuit-breaker logic onto the relay to "handle" broker slowness** — the outbox already is the backpressure mechanism; added machinery here duplicates what the next tick already does for free.
- **Bare `var records []*kgo.Record` grown by `append`** — reintroduces the unbounded growth-and-copy the batching standard exists to prevent, even though the query already bounds the loop.
- **Business decisions in the relay** — filtering, transforming, or suppressing events at publish time. The repository decided what happened; the relay only ships it.

---

## Output Format

Go source built exactly to the standards above, plus integration tests run against real PostgreSQL and Redpanda via Testcontainers (`go-integration-test` owns the harness mechanics):

```
internal/infrastructure/messaging/outbox_relay.go        (OutboxRelay, Run, drainOnce, toRecord)
internal/infrastructure/messaging/envelope.go             (Envelope struct — event-schema-design's shape)
internal/infrastructure/messaging/outbox_relay_test.go    (written first — TDD)
```

Full standards: `references/transactional-outbox-standard.md` (outbox schema, atomic insert SQL, relay/poller loop, at-least-once reasoning) and `references/batching-backpressure-and-idempotency.md` (batch-size/timeout tradeoff, backpressure depth, idempotency-key construction rule).
