---
name: go-event-publisher
description: >
  Teaches how to implement reliable Domain Event publication via the Transactional
  Outbox — the outbox relay that polls committed outbox rows, publishes them to
  Redpanda with the standard envelope and trace context, marks them published, and
  retries with backoff. Covers ordering, at-least-once delivery, idempotent
  publication, graceful shutdown, and partition keying by tenant. Implements the
  data-architect's event-schema-design over the outbox from go-repository-pattern.
  Used by the backend-engineer during Implement.
version: 1.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, outbox, redpanda, kafka, event-publishing, at-least-once, relay]
---

# Go Event Publisher

## Purpose

A service must publish a Domain Event whenever it changes state — reliably, even across crashes. Publishing directly from a handler is unsafe: a crash between the DB commit and the broker publish loses the event. The **Transactional Outbox** solves this — the repository already wrote the event into the `outbox` table in the same transaction as the state change (see `go-repository-pattern`). This skill builds the **relay** that reliably drains the outbox to Redpanda.

This decouples *recording* an event (transactional, in the repo) from *publishing* it (this relay), giving at-least-once delivery without distributed transactions.

---

## The Relay Loop

The relay runs as a supervised component in the errgroup (see `go-service-skeleton`). It polls committed outbox rows, publishes them, and marks them published. Its lifetime is bound to the group context — on shutdown it stops cleanly mid-batch.

```go
// internal/infrastructure/messaging/outbox_relay.go
package messaging

type OutboxRelay struct {
    pool     *pgxpool.Pool
    producer *kgo.Client      // franz-go Redpanda/Kafka client
    batch    int
    interval time.Duration
    tracer   trace.Tracer
}

func (r *OutboxRelay) Run(ctx context.Context) error {
    ticker := time.NewTicker(r.interval)
    defer ticker.Stop()
    for {
        select {
        case <-ctx.Done():
            return nil // graceful stop: the in-flight batch already committed or rolled back
        case <-ticker.C:
            if err := r.drainOnce(ctx); err != nil {
                slog.ErrorContext(ctx, "outbox drain failed", "err", err) // log + retry next tick
            }
        }
    }
}
```

A failed drain is logged and retried on the next tick — transient broker outages do not lose events; they stay in the outbox until published.

---

## Draining a Batch

Rows are claimed with `FOR UPDATE SKIP LOCKED` so multiple relay replicas can run concurrently without publishing the same row twice. Ordering is preserved per aggregate by `occurred_at` within a batch — note that running **multiple** relay replicas trades strict cross-batch ordering for throughput (two replicas can publish adjacent batches for the same tenant concurrently). If strict per-tenant order matters more than relay throughput, run one replica; the design supports either.

```go
func (r *OutboxRelay) drainOnce(ctx context.Context) error {
    tx, err := r.pool.Begin(ctx)
    if err != nil {
        return fmt.Errorf("begin: %w", err)
    }
    defer tx.Rollback(ctx) //nolint:errcheck // no-op after commit

    rows, err := tx.Query(ctx, `
        SELECT id, aggregate_id, tenant_id, event_type, payload, occurred_at
          FROM outbox
         WHERE published_at IS NULL
         ORDER BY occurred_at
         LIMIT $1
         FOR UPDATE SKIP LOCKED`, r.batch)
    if err != nil {
        return fmt.Errorf("select outbox: %w", err)
    }

    var records []*kgo.Record
    var ids []uuid.UUID
    for rows.Next() {
        var m outboxRow
        if err := rows.Scan(&m.id, &m.aggregateID, &m.tenantID, &m.eventType, &m.payload, &m.occurredAt); err != nil {
            rows.Close()
            return fmt.Errorf("scan: %w", err)
        }
        records = append(records, r.toRecord(ctx, m))
        ids = append(ids, m.id)
    }
    rows.Close()
    if len(records) == 0 {
        return nil
    }

    // Publish synchronously; only mark published rows whose publish succeeded.
    if err := r.producer.ProduceSync(ctx, records...).FirstErr(); err != nil {
        return fmt.Errorf("produce: %w", err) // do NOT mark published; retry next tick
    }

    if _, err := tx.Exec(ctx,
        `UPDATE outbox SET published_at = now() WHERE id = ANY($1)`, ids); err != nil {
        return fmt.Errorf("mark published: %w", err)
    }
    return tx.Commit(ctx)
}
```

**Ordering of operations is the correctness crux:** publish *then* mark published. If the process crashes after publishing but before marking, the row is re-published next tick — at-least-once. Consumers are idempotent (see `go-event-consumer`), so a duplicate is harmless. The reverse order would risk *losing* an event, which is unacceptable.

---

## The Envelope and Partition Key

Each outbox row becomes a Redpanda record with the standard envelope (from `domain-event-catalog` / `event-schema-design`) and trace context propagated into headers so the consumer continues the same trace.

```go
func (r *OutboxRelay) toRecord(ctx context.Context, m outboxRow) *kgo.Record {
    env := Envelope{
        EventID:     m.id, // outbox row id — STABLE across re-publication, so consumer dedup recognises a replay
        EventType:   m.eventType,
        SchemaVersion: 1,
        OccurredAt:  m.occurredAt,
        AggregateID: m.aggregateID,
        TenantID:    m.tenantID,
        Payload:     m.payload, // already-marshalled JSON from the repo
    }
    value, err := json.Marshal(env)
    if err != nil {
        // Envelope fields are all marshal-safe types; reaching here is a bug, not an event.
        panic(fmt.Sprintf("marshal envelope for outbox row %s: %v", m.id, err))
    }

    rec := &kgo.Record{
        Topic: topicFor(m.eventType),
        Key:   m.tenantID[:], // partition by tenant — ordering per tenant, isolation, parallelism
        Value: value,
    }
    // Propagate W3C trace context into Kafka headers (see distributed-tracing-design)
    otel.GetTextMapPropagator().Inject(ctx, kafkaHeaderCarrier{rec})
    return rec
}
```

**Partition key = `tenant_id`.** This preserves per-tenant ordering, keeps a tenant's events together, and enables Competing Consumers to scale horizontally (see `data-pipeline-design`).

---

## Idempotent Publication

The `eventId` in the envelope is the consumer's dedup key, so it must be **stable across re-publication**: the relay uses the outbox row id as the envelope `eventId` (see `toRecord` above). A crash after publish but before mark re-publishes the row with the *same* `eventId`, the consumer's `processed_events` insert conflicts, and the duplicate is a no-op. Generating a fresh `uuid.New()` per publish attempt would defeat dedup entirely — every replay would look like a new event.

---

## Rules

- **Publish before mark.** Never mark published before a successful produce.
- **`SKIP LOCKED`** so replicas don't double-claim; safe horizontal scaling.
- **Partition by tenant.** Ordering + isolation + parallelism in one key choice.
- **Propagate trace context** into record headers — the trace must cross the broker.
- **Graceful stop** on `ctx.Done()`; never leave a transaction open across shutdown.
- **Outbox table is the contract** — the relay owns no business logic; it ships rows.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| At-least-once | Publish then mark; crash re-publishes | Mark-then-publish (can lose events) |
| Concurrent-safe drain | `FOR UPDATE SKIP LOCKED` | Replicas double-publishing rows |
| Tenant partitioning | Record key = tenant id | Random/no key; cross-tenant ordering loss |
| Trace continuity | Trace context injected into headers | Broken trace across the broker |
| Graceful shutdown | Stops on ctx cancel without open tx | Relay killed mid-tx; leaked locks |
| No business logic | Relay only ships outbox rows | Relay deciding what/whether to emit |
| Stable dedup identity | Envelope `eventId` = outbox row id | Fresh `uuid.New()` per publish attempt |

---

## Anti-Patterns

- **Publishing directly from the request handler** — the dual-write problem the Transactional Outbox exists to solve: a crash between DB commit and broker publish silently loses the Domain Event.
- **Mark-then-publish** — updating `published_at` before the produce succeeds converts a crash into a *lost* event. At-least-once requires publish-then-mark, always.
- **Fresh `eventId` per publish attempt** — makes every crash-replay look like a new event to consumers and defeats Idempotency downstream.
- **Random or absent partition key** — scatters one tenant's events across partitions, destroying per-tenant ordering and tenant isolation in one stroke.
- **Deleting outbox rows instead of marking them** — loses the audit trail and the ability to replay; sweep old *published* rows with a retention job instead.
- **Business decisions in the relay** — filtering, transforming, or suppressing events at publish time. The repository decided what happened; the relay only ships it.

---

## Output Format

Produces Go source plus integration tests (against Redpanda + PostgreSQL via testcontainers):

```
internal/infrastructure/messaging/outbox_relay.go
internal/infrastructure/messaging/envelope.go
internal/infrastructure/messaging/outbox_relay_test.go   (written first)
```
