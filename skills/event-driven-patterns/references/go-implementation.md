# Event-Driven Patterns — Go Implementation on Redpanda

Implementation sketches for the event-driven patterns on this platform's stack: **Go + chi + pgx + Redpanda**, per-tenant physical PostgreSQL isolation, OpenTelemetry/Prometheus/Tempo/Grafana. These are reference skeletons, not drop-in production code — they show the mechanism each pattern requires. Grounded in Kleppmann's treatment of log-based message brokers and effectively-once processing.

Redpanda is Kafka-API-compatible; the sketches use the `franz-go` client style (`github.com/twmb/franz-go/pkg/kgo`) but the mechanisms translate to any Kafka client.

---

## Delivery semantics on Redpanda: at-least-once vs. exactly-once

Redpanda offers three producer/consumer guarantees; the platform's default is **at-least-once + idempotent consumers = effectively-once** (Kleppmann Ch. 11).

| Guarantee | How | Cost | Use in this platform |
|---|---|---|---|
| **At-most-once** | Commit offset *before* processing | Message loss on crash | Never — we don't drop DataAssets |
| **At-least-once** | Commit offset *after* processing; process may re-run | Duplicate delivery | **Default** — paired with idempotent consumers |
| **Exactly-once (EOS)** | Kafka transactions (`transactional.id`), atomic consume-process-produce **within one Redpanda cluster** | Higher latency, coordinator overhead, only within one cluster | Reserved for a stream-processing stage whose input and output are both Redpanda topics in the same cluster |

Kleppmann's honest assessment: literal exactly-once across independent systems (Redpanda → PostgreSQL → an external API) is **not achievable** — a database write and a Kafka offset commit cannot be one atomic transaction. What *is* achievable is effectively-once: at-least-once delivery + a deduplicating consumer whose observable effect equals processing-once. Redpanda EOS only closes the loop when both ends are Redpanda topics; the moment a side effect leaves the cluster (a Postgres write, an alert), fall back to idempotency.

**Rule:** default to at-least-once + the idempotent consumer below. Reach for Redpanda EOS only for a topic-to-topic transform, and even then keep consumers idempotent.

---

## Idempotent consumer with a `processed_message_ids` dedup table

The dedup mechanism: a table of already-handled event IDs, written **in the same transaction** as the business state change. A repeat delivery hits the unique constraint and is treated as "already processed."

```sql
-- Per-tenant PostgreSQL, one row per handled event
CREATE TABLE processed_message_ids (
    event_id     UUID        PRIMARY KEY,      -- from the event envelope
    consumer     TEXT        NOT NULL,         -- which consumer group handled it
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Periodic prune: DELETE WHERE processed_at < now() - interval '30 days';
-- (retention must exceed the topic's replay window so replayed events still dedup)
```

```go
// Handle deduplicates via processed_message_ids, atomically with the state write.
func (h *DataAssetClassifiedHandler) Handle(ctx context.Context, e domain.DataAssetClassified) error {
    return pgx.BeginTxFunc(ctx, h.pool, pgx.TxOptions{}, func(tx pgx.Tx) error {
        // 1. Claim the event. Unique-constraint violation => already processed.
        _, err := tx.Exec(ctx,
            `INSERT INTO processed_message_ids (event_id, consumer) VALUES ($1, $2)`,
            e.EventID, "reporting-read-model")
        if err != nil {
            var pgErr *pgconn.PgError
            if errors.As(err, &pgErr) && pgErr.Code == "23505" { // unique_violation
                return nil // already handled — safe to skip, commit empty tx
            }
            return fmt.Errorf("claiming event %s: %w", e.EventID, err)
        }

        // 2. Business state change — SAME transaction as the dedup mark.
        _, err = tx.Exec(ctx,
            `UPDATE read_model_assets SET sensitivity = $2 WHERE id = $1`,
            e.DataAssetID, e.SensitivityLevel)
        return err
    })
    // 3. Only after commit does the caller commit the Redpanda offset.
}
```

**Why one transaction.** If the dedup mark and the state write were separate transactions, a crash between them would re-process the event on restart (mark missing) or drop it (mark present, state not written). Committing them together makes the guarantee hold. The **offset is committed only after the transaction commits** — that is what makes it at-least-once, not at-most-once.

**End-to-end argument.** `event_id` here is the *envelope* ID for this hop. For a side effect that must never double-fire across the whole pipeline (a compliance alert), thread the *origin* idempotency key (e.g., the `FileDiscovered` event's ID) all the way through, so the final alert-sending step dedups on the true origin, not just its immediate upstream.

---

## Transactional Outbox: DDL + publisher

Atomically write state change and event within one local transaction; a separate publisher relays the outbox to Redpanda.

```sql
CREATE TABLE outbox (
    id            BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    aggregate_id  UUID        NOT NULL,
    topic         TEXT        NOT NULL,        -- e.g. 'dataasset.classified'
    partition_key TEXT        NOT NULL,        -- tenant_id, for per-tenant ordering
    payload       JSONB       NOT NULL,        -- the serialized event envelope
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_at  TIMESTAMPTZ                  -- NULL until relayed
);
CREATE INDEX outbox_unpublished ON outbox (id) WHERE published_at IS NULL;
```

```go
// In the command handler: state change + outbox insert in ONE transaction.
func (s *ClassificationService) Classify(ctx context.Context, cmd ClassifyCommand) error {
    return pgx.BeginTxFunc(ctx, s.pool, pgx.TxOptions{}, func(tx pgx.Tx) error {
        if _, err := tx.Exec(ctx,
            `UPDATE data_assets SET sensitivity = $2, status = 'CLASSIFIED' WHERE id = $1`,
            cmd.AssetID, cmd.Sensitivity); err != nil {
            return err
        }
        evt := domain.NewDataAssetClassified(cmd.TenantID, cmd.AssetID, cmd.Sensitivity)
        _, err := tx.Exec(ctx,
            `INSERT INTO outbox (aggregate_id, topic, partition_key, payload)
             VALUES ($1, 'dataasset.classified', $2, $3)`,
            cmd.AssetID, cmd.TenantID.String(), evt.JSON())
        return err // both commit together, or neither does
    })
}
```

```go
// Publisher loop: relay unpublished rows to Redpanda, then mark sent. At-least-once.
func (p *OutboxPublisher) run(ctx context.Context) {
    for {
        rows, _ := p.pool.Query(ctx,
            `SELECT id, topic, partition_key, payload FROM outbox
             WHERE published_at IS NULL ORDER BY id LIMIT 100`)
        for rows.Next() {
            var id int64; var topic, key string; var payload []byte
            rows.Scan(&id, &topic, &key, &payload)
            rec := &kgo.Record{Topic: topic, Key: []byte(key), Value: payload}
            if err := p.client.ProduceSync(ctx, rec).FirstErr(); err != nil {
                break // retry whole batch next tick; row stays unpublished
            }
            p.pool.Exec(ctx, `UPDATE outbox SET published_at = now() WHERE id = $1`, id)
        }
        select {
        case <-ctx.Done(): return
        case <-time.After(500 * time.Millisecond):
        }
    }
}
```

A publisher that produced a row but crashed before the `UPDATE` will re-produce it next tick — duplicate delivery that the idempotent consumer absorbs. `partition_key = tenant_id` preserves per-tenant ordering on the topic.

---

## Retry with exponential backoff + jitter, then DLQ

Distinguish **transient** (retry) from **permanent** (straight to DLQ) failures, then cap retries and route poison messages to a `<topic>.dlq` so a partition never blocks.

```go
const maxRetries = 5

func (c *Consumer) process(ctx context.Context, rec *kgo.Record) {
    var lastErr error
    for attempt := 0; attempt <= maxRetries; attempt++ {
        err := c.handler.Handle(ctx, rec)
        if err == nil {
            return // success — caller commits the offset
        }
        lastErr = err
        if isPermanent(err) { // schema-invalid, business-rule rejection
            break // do not retry; go straight to DLQ
        }
        // transient: exponential backoff with full jitter (AWS-style)
        backoff := time.Duration(1<<attempt) * 100 * time.Millisecond // 100ms,200,400,800,1600
        jittered := time.Duration(rand.Int63n(int64(backoff)))        // full jitter
        c.metrics.RetryCount.Inc()
        select {
        case <-ctx.Done():
            return
        case <-time.After(jittered):
        }
    }
    // retries exhausted OR permanent failure -> DLQ, then advance the partition
    c.toDLQ(ctx, rec, lastErr)
}

func (c *Consumer) toDLQ(ctx context.Context, rec *kgo.Record, cause error) {
    dead := &kgo.Record{
        Topic: rec.Topic + ".dlq",
        Key:   rec.Key,
        Value: rec.Value,
        Headers: []kgo.RecordHeader{
            {Key: "x-error", Value: []byte(cause.Error())},
            {Key: "x-original-topic", Value: []byte(rec.Topic)},
            {Key: "x-failed-at", Value: []byte(time.Now().UTC().Format(time.RFC3339))},
        },
    }
    c.client.ProduceSync(ctx, dead).FirstErr()
    c.metrics.DLQDepth.Inc() // Grafana alerts when DLQ depth > 0
}
```

**Why full jitter.** Fixed exponential backoff synchronizes retries into a thundering herd; full jitter (`rand(0, backoff)`) spreads them so a recovering downstream isn't re-flooded. **Why the DLQ commits the offset.** Because one partition is processed in order by one consumer, leaving a poison message un-committed blocks every tenant event behind it; DLQ-and-advance is what keeps the partition flowing.

---

## Observability hooks

Every consumer emits, via OpenTelemetry → Prometheus/Tempo/Grafana:

- `consumer_lag` per partition (Redpanda group lag) — the primary "are we keeping up?" signal.
- `retry_count`, `dlq_depth` — a Grafana alert fires the moment `dlq_depth > 0`.
- A Tempo span per event, carrying the envelope's `correlationId`/`causationId` so a Saga can be traced end-to-end across services — the causal metadata that makes a multi-hop flow reconstructable.
- `saga_duration` and `saga_failed_total{saga_type}` from the orchestrator, so stuck or failing Sagas surface on the compliance-ingestion dashboard.
