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
version: 1.0.0
phase: implement
owner: backend-engineer
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

Rows are claimed with `FOR UPDATE SKIP LOCKED` so multiple relay replicas can run concurrently without publishing the same row twice. Ordering is preserved per aggregate by `occurred_at`.

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
        EventID:     uuid.New(),
        EventType:   m.eventType,
        SchemaVersion: 1,
        OccurredAt:  m.occurredAt,
        AggregateID: m.aggregateID,
        TenantID:    m.tenantID,
        Payload:     m.payload, // already-marshalled JSON from the repo
    }
    value, _ := json.Marshal(env)

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

The `eventId` in the envelope is the consumer's dedup key. Because the relay may re-publish on crash, the same outbox row always produces a record carrying the same logical identity from the consumer's perspective (the consumer dedups on the envelope `eventId`, which is stable per outbox row when regenerated deterministically — or the outbox row id is carried as the dedup key). Either way, redelivery is safe.

> Implementation note: carry the **outbox row id** as the stable idempotency key in a header, so a re-published row is recognised as a duplicate even though the transport `eventId` may differ.

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

---

## Output Format

Produces Go source plus integration tests (against Redpanda + PostgreSQL via testcontainers):

```
internal/infrastructure/messaging/outbox_relay.go
internal/infrastructure/messaging/envelope.go
internal/infrastructure/messaging/outbox_relay_test.go   (written first)
```
