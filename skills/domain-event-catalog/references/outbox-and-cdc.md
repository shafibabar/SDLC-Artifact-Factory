# Outbox Pattern and Change Data Capture — Full Reference

Self-contained reference for the Transactional Outbox implementation, CDC/Debezium configuration,
at-least-once delivery guarantees, consumer idempotency, and Dead Letter Queue mechanics.
Read this when implementing the outbox table, the relay publisher, or setting up Debezium.

---

## Why the Outbox Pattern Exists

Publishing a Domain Event from the request path (writing to the Aggregate table AND posting to
Redpanda in the same handler) is a dual-write anti-pattern. Two failure windows exist:

1. **Handler crashes after DB commit, before broker publish** — the Aggregate's state changed,
   but no event was ever emitted. Downstream contexts are permanently out of sync.
2. **Broker publish succeeds, DB commit fails** — a phantom event was emitted for a state change
   that never happened. Consumers act on fabricated facts.

The Transactional Outbox eliminates both failure windows by making the event write part of the
same database transaction as the Aggregate write. The broker is never involved in the request
transaction. As Vernon describes in IDDD Ch. 8, the atomicity problem requires persisting the
event as part of the same local transaction as the Aggregate state change — a separate mechanism
then reliably forwards the persisted event to the messaging infrastructure.

---

## outbox_events Table — Full DDL

```sql
-- One outbox table per service (per Bounded Context).
-- All Aggregates in the service share this table.
CREATE TABLE outbox_events (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type   TEXT        NOT NULL,                        -- "DataAsset", "StorageSource", etc.
    aggregate_id     UUID        NOT NULL,                        -- Partition key for Redpanda
    event_type       TEXT        NOT NULL,                        -- "DataAssetClassified"
    event_version    TEXT        NOT NULL DEFAULT '1.0.0',        -- Schema version
    tenant_id        UUID        NOT NULL,                        -- Physical multi-tenancy
    correlation_id   UUID        NOT NULL,                        -- Propagated from Command
    causation_id     UUID        NOT NULL,                        -- ID that directly caused this event
    payload          JSONB       NOT NULL,                        -- Full serialised event (envelope + payload)
    published        BOOLEAN     NOT NULL DEFAULT false,
    published_at     TIMESTAMPTZ,                                 -- Set when relay marks as published
    retry_count      INT         NOT NULL DEFAULT 0,              -- Number of failed publish attempts
    last_error       TEXT,                                        -- Most recent relay error message
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Partial index: only unpublished rows — keeps the relay's query fast as published rows grow.
CREATE INDEX idx_outbox_unpublished
    ON outbox_events (aggregate_id, created_at)
    WHERE NOT published;

-- Index for tenant-scoped replay or audit queries.
CREATE INDEX idx_outbox_tenant
    ON outbox_events (tenant_id, created_at);
```

**Key column notes:**
- `aggregate_id` is used as the Redpanda **partition key**, guaranteeing per-Aggregate event order.
- `retry_count` is incremented by the relay on each failed publish attempt; use this to move
  persistently-failing events to the DLQ after a configurable threshold (e.g., `retry_count >= 5`).
- `last_error` stores the most recent error message from the relay to aid debugging without
  requiring log correlation.
- `published_at` is set atomically when the relay marks a row published, enabling audit queries
  on publication latency.
- `payload` stores the full serialised event JSON (envelope + payload) so the relay never needs
  to re-query the Aggregate table to reconstruct the event.

---

## Writing to the Outbox (Go — Application Service Layer)

The Application Service (thin orchestration layer, not the Aggregate itself) writes to the outbox
inside the same transaction that persists the Aggregate state:

```go
// internal/application/classify_data_asset.go
package application

import (
    "context"
    "encoding/json"
    "fmt"

    "github.com/google/uuid"
    "github.com/jackc/pgx/v5"

    "github.com/caizin/data-asset-management/internal/domain"
    "github.com/caizin/data-asset-management/internal/domain/events"
)

type ClassifyDataAssetHandler struct {
    repo domain.DataAssetRepository
    db   *pgx.Conn
}

func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAssetCommand) error {
    tx, err := h.db.BeginTx(ctx, pgx.TxOptions{})
    if err != nil {
        return fmt.Errorf("begin tx: %w", err)
    }
    defer tx.Rollback(ctx)

    // 1. Load and mutate the Aggregate.
    asset, err := h.repo.FindByIDTx(ctx, tx, cmd.DataAssetID, cmd.TenantID)
    if err != nil {
        return fmt.Errorf("load asset: %w", err)
    }
    evt, err := asset.Classify(cmd.SensitivityLevel, cmd.ClassifiedBy, cmd.CorrelationID)
    if err != nil {
        return err // invariant violation — no DB writes yet
    }

    // 2. Persist the updated Aggregate (optimistic concurrency via version field).
    if err := h.repo.SaveTx(ctx, tx, asset); err != nil {
        return fmt.Errorf("save asset: %w", err)
    }

    // 3. Write the event to the outbox — same transaction.
    payload, _ := json.Marshal(evt)
    _, err = tx.Exec(ctx, `
        INSERT INTO outbox_events
            (aggregate_type, aggregate_id, event_type, event_version,
             tenant_id, correlation_id, causation_id, payload)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    `,
        "DataAsset", asset.ID(), "DataAssetClassified", "1.0.0",
        cmd.TenantID, cmd.CorrelationID, cmd.CorrelationID, payload,
    )
    if err != nil {
        return fmt.Errorf("write outbox: %w", err)
    }

    // 4. Commit — either both the Aggregate update and the outbox write land, or neither does.
    return tx.Commit(ctx)
}
```

---

## Polling Relay (Go)

The polling relay runs as a separate goroutine (or a separate process). It queries unpublished
rows, publishes to Redpanda using `aggregate_id` as the partition key, then marks rows published.

```go
// internal/relay/outbox_relay.go
package relay

import (
    "context"
    "log/slog"
    "time"

    "github.com/jackc/pgx/v5/pgxpool"
    "github.com/twmb/franz-go/pkg/kgo"
)

type OutboxRelay struct {
    pool     *pgxpool.Pool
    kafka    *kgo.Client
    topic    string
    interval time.Duration
    maxRetry int
}

func (r *OutboxRelay) Run(ctx context.Context) {
    ticker := time.NewTicker(r.interval)
    defer ticker.Stop()
    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            r.publishBatch(ctx)
        }
    }
}

func (r *OutboxRelay) publishBatch(ctx context.Context) {
    rows, err := r.pool.Query(ctx, `
        SELECT id, aggregate_id, payload, retry_count
        FROM outbox_events
        WHERE NOT published
          AND retry_count < $1
        ORDER BY created_at
        LIMIT 100
        FOR UPDATE SKIP LOCKED
    `, r.maxRetry)
    if err != nil {
        slog.Error("outbox query failed", "err", err)
        return
    }
    defer rows.Close()

    for rows.Next() {
        var id, aggregateID [16]byte
        var payload []byte
        var retryCount int
        if err := rows.Scan(&id, &aggregateID, &payload, &retryCount); err != nil {
            continue
        }

        record := &kgo.Record{
            Topic: r.topic,
            Key:   aggregateID[:],  // partition key = aggregate_id → per-Aggregate order
            Value: payload,
        }
        if err := r.kafka.ProduceSync(ctx, record).FirstErr(); err != nil {
            slog.Error("publish failed", "event_id", id, "err", err)
            r.pool.Exec(ctx, `
                UPDATE outbox_events
                SET retry_count = retry_count + 1, last_error = $2
                WHERE id = $1
            `, id, err.Error())
            continue
        }

        r.pool.Exec(ctx, `
            UPDATE outbox_events
            SET published = true, published_at = now()
            WHERE id = $1
        `, id)
    }
}
```

**Relay rules:**
- `FOR UPDATE SKIP LOCKED` prevents two relay instances from processing the same row concurrently
  (safe for multi-instance deployments).
- `retry_count < maxRetry` filter: rows that have exceeded the retry threshold are not retried
  by the relay — they await a manual investigation or DLQ move.
- Partition key is `aggregate_id[:bytes]` — guarantees per-Aggregate event ordering in Redpanda.
  Cross-Aggregate ordering is never guaranteed and consumers must not depend on it.

---

## CDC with Debezium (Alternative to Polling)

When sub-second latency is required, use Debezium to capture WAL changes to `outbox_events`
and forward them to Redpanda. This eliminates polling latency without adding database load.

**Kafka Connect configuration (Debezium PostgreSQL connector):**

```json
{
  "name": "outbox-connector-classification-engine",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "plugin.name": "pgoutput",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "debezium",
    "database.password": "${secret:debezium-password}",
    "database.dbname": "classification_engine",
    "table.include.list": "public.outbox_events",
    "topic.prefix": "cdc",
    "transforms": "outbox",
    "transforms.outbox.type": "io.debezium.transforms.outbox.EventRouter",
    "transforms.outbox.table.field.event.id": "id",
    "transforms.outbox.table.field.event.key": "aggregate_id",
    "transforms.outbox.table.field.event.type": "event_type",
    "transforms.outbox.table.field.event.payload": "payload",
    "transforms.outbox.route.by.field": "aggregate_type",
    "transforms.outbox.route.topic.replacement": "events.${routedByValue}",
    "tombstones.on.delete": "false"
  }
}
```

**Prerequisites for CDC:**
1. PostgreSQL `wal_level = logical` (set in `postgresql.conf`)
2. Debezium replication user with `REPLICATION` and `LOGIN` privileges
3. `REPLICA IDENTITY FULL` on the `outbox_events` table (required for Debezium to capture full row data)

**Trade-offs:**

| Concern | Polling | CDC (Debezium) |
|---|---|---|
| Latency | 100ms–5s (configurable interval) | ~50ms (WAL-driven) |
| DB load | Periodic query on `outbox_events` | Minimal — reads WAL stream |
| Operational complexity | Low — a Go goroutine | Medium — Kafka Connect + Debezium |
| Failure mode | Relay down → events queue in outbox | Connector down → WAL lag grows |
| Recommended for | Most services | High-throughput or latency-sensitive |

---

## Consumer Idempotency Pattern

At-least-once delivery means consumers **will** receive the same event more than once (relay
retry, Redpanda redelivery on consumer restart). Every consumer must be idempotent.

Recommended: a `processed_events` table in the consumer's own database, checked and updated
inside the same transaction as the consumer's business logic.

```sql
-- In the consumer service's database (e.g., compliance_intelligence)
CREATE TABLE processed_events (
    event_id    UUID        PRIMARY KEY,  -- The eventId from the envelope
    event_type  TEXT        NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

```go
// Consumer handler — idempotent via processed_events deduplication
func (h *ClassificationHandler) Handle(ctx context.Context, evt events.DataAssetClassified) error {
    tx, err := h.db.BeginTx(ctx, pgx.TxOptions{})
    if err != nil {
        return err
    }
    defer tx.Rollback(ctx)

    // Check for duplicate — idempotency guard.
    var exists bool
    err = tx.QueryRow(ctx,
        `SELECT EXISTS(SELECT 1 FROM processed_events WHERE event_id = $1)`,
        evt.EventID,
    ).Scan(&exists)
    if err != nil {
        return err
    }
    if exists {
        return nil // Already processed — safe to ack without re-processing.
    }

    // Business logic: evaluate compliance gap.
    if err := h.evaluateGap(ctx, tx, evt); err != nil {
        return err
    }

    // Mark as processed — same transaction.
    _, err = tx.Exec(ctx,
        `INSERT INTO processed_events (event_id, event_type) VALUES ($1, $2)`,
        evt.EventID, evt.EventType,
    )
    if err != nil {
        return err
    }
    return tx.Commit(ctx)
}
```

---

## Dead Letter Queue (DLQ)

When a consumer cannot process an event after exhausting retries, the event moves to the DLQ.

**DLQ topic naming:** `{original-topic}.dlq`
- Source: `events.DataAsset` → DLQ: `events.DataAsset.dlq`

**DLQ rules:**
- Every consumer topic must have a corresponding DLQ topic, created at service deployment time.
- Every event in the DLQ must trigger an alert (Prometheus counter `dlq_events_total` by topic).
- Events in the DLQ must never be silently discarded — they represent processing failures requiring
  investigation.
- Reprocessing from the DLQ must be a safe, monitored, manually-triggered operation.

**Ordering caveat:** Parking an event in the DLQ allows later events for the same Aggregate to be
processed first. A consumer whose correctness depends on per-Aggregate ordering must either:
- Halt the affected partition until the poison event is resolved, or
- Be designed to reconcile out-of-order redelivery when the DLQ event is eventually replayed.

Record which approach each consumer takes in the Domain Event Catalog entry.

**Relay DLQ escalation:** Rows in `outbox_events` with `retry_count >= maxRetry` must be
monitored separately. A background job (or Grafana alert on `outbox_events WHERE retry_count >= 5`)
should page on-call when publication has failed repeatedly — these events may represent a broker
outage or a serialisation bug that requires a deployment fix, not just a retry.
