# Projection Patterns — Full Reference

Self-contained reference for the three projection update mechanics available in Full CQRS. Usable without the parent SKILL.md in context.

A **Projector** is a component that consumes Domain Events and upserts Read Model tables. It is the bridge between the Write Model and the Read Model in Full CQRS. Every Projector must be idempotent — safe to process the same event twice without corrupting the Read Model.

---

## Projection Mechanic 1: Synchronous (Same Transaction as Write)

### What It Is

The Read Model table is updated inside the same database transaction that saves the Aggregate state and the outbox event row. If the transaction fails, neither the Aggregate state, the outbox row, nor the Read Model update is committed.

### Characteristics

- **Consistency**: Immediate — the Read Model is always current at the moment the write commits
- **Coupling**: Tight — every schema change to any Read Model requires touching the write transaction
- **Write throughput impact**: Every write pays the cost of every Read Model's update; complex or slow projections directly degrade write latency
- **Rebuild**: Cannot replay from events — the Read Model was never built from events, so replaying the event stream will not reconstruct it
- **Idempotency requirement**: Less critical (the write transaction is atomic), but still required if the write is retried after a partial failure

### When to Use

- The Simple Read Model variant, where write and read share one DB and there is no broker
- A single, lightweight summary counter or materialised view that adds negligible write latency
- **Do not use** in Full CQRS — this pattern reintroduces write-side coupling that Full CQRS exists to remove

### Go Sketch (within the Repository Save transaction)

```go
func (r *DataAssetRepo) Save(ctx context.Context, tx pgx.Tx, asset *domain.DataAsset) error {
    // 1. Update aggregate state
    _, err := tx.Exec(ctx,
        `UPDATE data_assets SET sensitivity=$1, version=$2 WHERE id=$3 AND version=$4`,
        asset.Sensitivity(), asset.Version(), asset.ID(), asset.Version()-1)
    if err != nil {
        return fmt.Errorf("updating aggregate: %w", err)
    }
    // 2. Insert outbox events
    for _, evt := range asset.Events() {
        if err := r.insertOutboxEvent(ctx, tx, evt); err != nil {
            return err
        }
    }
    // 3. Synchronous projection (only for simple, non-Full-CQRS scenarios)
    _, err = tx.Exec(ctx,
        `INSERT INTO data_asset_summary (id, sensitivity)
         VALUES ($1, $2)
         ON CONFLICT (id) DO UPDATE SET sensitivity = EXCLUDED.sensitivity`,
        asset.ID(), asset.Sensitivity())
    return err
}
```

---

## Projection Mechanic 2: Event-Driven (Subscribe to Broker)

### What It Is

The Projector is a separate consumer that subscribes to a Redpanda topic (or consumer group). It processes Domain Events published by the Transactional Outbox relay and upserts Read Model tables. This is the standard mechanic for Full CQRS in this plugin.

### Characteristics

- **Consistency**: Eventual — Read Models lag the Write Model by the outbox relay + broker delivery round-trip (typically milliseconds to low seconds)
- **Coupling**: Decoupled — the Projector can be updated, redeployed, or replaced without touching the write path
- **Write throughput impact**: None — the write transaction ends when the outbox row is inserted; the projector runs asynchronously
- **Rebuild**: Yes — stop the projector, truncate the Read Model table, reset the consumer group offset to the earliest message, restart. The full event history in Redpanda replays and rebuilds the Read Model.
- **Idempotency requirement**: Critical — at-least-once delivery means the same event may arrive more than once (broker retry, consumer crash, rebalance). The projector must detect and skip duplicates.

### When to Use

- Full CQRS in all Core Bounded Contexts
- Any Read Model that must be independently scalable, deployable, or rebuildable

### Go Sketch (Projector consuming from Redpanda)

```go
// DataAssetProjector subscribes to data-asset-management.events
// and maintains the data_asset_detail Read Model table.
type DataAssetProjector struct {
    store *pgxpool.Pool
}

func (p *DataAssetProjector) Handle(ctx context.Context, msg *kgo.Record) error {
    var evt events.DataAssetClassified
    if err := json.Unmarshal(msg.Value, &evt); err != nil {
        return fmt.Errorf("unmarshal event: %w", err)
    }

    return p.handleDataAssetClassified(ctx, evt)
}

func (p *DataAssetProjector) handleDataAssetClassified(ctx context.Context, evt events.DataAssetClassified) error {
    _, err := p.store.Exec(ctx, `
        INSERT INTO data_asset_detail (
            id, tenant_id, name, sensitivity,
            storage_source_id, classified_at, event_sequence
        ) VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT (id) DO UPDATE
            SET sensitivity    = EXCLUDED.sensitivity,
                classified_at  = EXCLUDED.classified_at,
                event_sequence = EXCLUDED.event_sequence
            WHERE data_asset_detail.event_sequence < EXCLUDED.event_sequence`,
        evt.DataAssetID, evt.TenantID, evt.Name,
        evt.Sensitivity, evt.StorageSourceID, evt.OccurredAt,
        evt.EventSequence,
    )
    return err
}
```

The `WHERE data_asset_detail.event_sequence < EXCLUDED.event_sequence` clause on the upsert ensures out-of-order delivery and duplicate events do not regress the Read Model to an older state.

### Idempotency via processed_event_ids Table

For projectors where the upsert's own version-check is insufficient (e.g., delete events, or events with no natural sequence to compare), use a separate deduplication table:

```sql
CREATE TABLE processed_event_ids (
    event_id    UUID        NOT NULL,
    projector   TEXT        NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (event_id, projector)
);
```

```go
func (p *DataAssetProjector) isAlreadyProcessed(ctx context.Context, tx pgx.Tx, eventID uuid.UUID) (bool, error) {
    var exists bool
    err := tx.QueryRow(ctx,
        `SELECT EXISTS(
            SELECT 1 FROM processed_event_ids
            WHERE event_id = $1 AND projector = 'DataAssetProjector'
        )`, eventID).Scan(&exists)
    return exists, err
}

func (p *DataAssetProjector) markProcessed(ctx context.Context, tx pgx.Tx, eventID uuid.UUID) error {
    _, err := tx.Exec(ctx,
        `INSERT INTO processed_event_ids (event_id, projector)
         VALUES ($1, 'DataAssetProjector')
         ON CONFLICT DO NOTHING`,
        eventID)
    return err
}
```

Both `isAlreadyProcessed` and the Read Model upsert run inside a single transaction. If the process crashes after the upsert but before committing, the event is reprocessed on restart — the `processed_event_ids` insert and the upsert both succeed again (ON CONFLICT DO NOTHING / ON CONFLICT DO UPDATE WHERE ... is idempotent).

---

## Projection Mechanic 3: CDC-Driven (Change Data Capture via Debezium)

### What It Is

Debezium connects to the PostgreSQL Write DB's WAL (Write-Ahead Log) and captures every row-level change in the `data_assets` table (and optionally `outbox_events`). These change events are published to a Redpanda topic. The Projector subscribes to the Debezium topic instead of the application-level Domain Event topic.

### Characteristics

- **Consistency**: Eventual — slightly less lag than event-driven (no application-level outbox relay hop) but still asynchronous
- **Coupling to write schema**: Higher — the CDC event payload reflects the Aggregate table's column structure, not the Domain Event's business language. Schema migrations on the Aggregate table directly change the CDC event shape.
- **No application-level event publishing required**: The application does not need to publish Domain Events; Debezium observes the database directly. This is the primary advantage for legacy systems or contexts where event publishing is not yet in place.
- **Rebuild**: Yes — but requires Debezium to replay from a WAL snapshot; the WAL is not retained indefinitely. For long-term replay, use the event-driven mechanic (events stored in Redpanda with long retention) instead.
- **Idempotency requirement**: Same as event-driven — at-least-once delivery from Debezium; projector must be idempotent.

### When to Use

- The Write Model uses a legacy PostgreSQL schema where adding Transactional Outbox rows is impractical
- The team needs to project data from a table that does not emit application-level Domain Events
- Connecting an existing application's database changes to a new Read Model without modifying the application

### When Not to Use

- The Bounded Context already uses Transactional Outbox + Redpanda — the event-driven mechanic is simpler and more decoupled
- You need the payload to carry business-meaningful Domain Event fields (not raw column values)
- Long-term Read Model rebuild from an event stream is required — Debezium's WAL position may not be retained long enough

### Go Sketch (Projector consuming Debezium CDC events)

```go
// DebeziumEnvelope is the standard Debezium Kafka Connect change event shape.
type DebeziumEnvelope struct {
    Before *DataAssetRow `json:"before"`
    After  *DataAssetRow `json:"after"`
    Op     string        `json:"op"` // "c" create, "u" update, "d" delete, "r" read (snapshot)
}

type DataAssetRow struct {
    ID          string `json:"id"`
    TenantID    string `json:"tenant_id"`
    Name        string `json:"name"`
    Sensitivity string `json:"sensitivity"`
    Version     int64  `json:"version"`
}

func (p *DataAssetCDCProjector) Handle(ctx context.Context, msg *kgo.Record) error {
    var env DebeziumEnvelope
    if err := json.Unmarshal(msg.Value, &env); err != nil {
        return err
    }

    switch env.Op {
    case "c", "u", "r":
        return p.upsert(ctx, env.After)
    case "d":
        return p.delete(ctx, env.Before.ID)
    }
    return nil
}
```

---

## Idempotency: Why It Is Required and How to Implement It

Every Projector must be idempotent regardless of which projection mechanic is used, because all delivery guarantees in this plugin are at-least-once:

- The Transactional Outbox relay may retry a publish on a broker timeout — the consumer sees the event twice
- A Redpanda consumer group rebalance may replay events already processed before the crash
- A Projector restart for deployment may re-process messages from the last committed offset

**The two idempotency patterns and when to use each:**

| Pattern | When to use | Trade-off |
|---|---|---|
| **Event sequence check in upsert** (`ON CONFLICT DO UPDATE WHERE projector.event_sequence < EXCLUDED.event_sequence`) | When events carry a natural sequence number (version, timestamp, offset) and the Read Model row is keyed by the Aggregate ID | No extra table; works inline with the upsert; does not protect against non-upsert operations |
| **`processed_event_ids` dedup table** | When events are delete operations, when the Read Model cannot carry a comparable sequence, or when the projector spans multiple Read Model tables in one handler | Full protection for all event types; adds one table lookup + insert per event; must be within the same transaction as the Read Model write |

For most Core Bounded Context projectors in this plugin, use the event sequence check as the primary guard and add the `processed_event_ids` table for any handler that performs delete operations or touches multiple tables.

**Schema for sequence-carrying events:**

```sql
-- Read Model table carrying the sequence of the last applied event
CREATE TABLE data_asset_detail (
    id               UUID         PRIMARY KEY,
    tenant_id        UUID         NOT NULL,
    name             TEXT         NOT NULL,
    sensitivity      TEXT         NOT NULL,
    storage_source_name TEXT,
    classified_at    TIMESTAMPTZ,
    event_sequence   BIGINT       NOT NULL DEFAULT 0  -- Redpanda offset or domain event version
);
```

The `event_sequence` column receives the Redpanda message offset (or domain event version number). The upsert's `WHERE` clause rejects any event whose sequence is not greater than the stored sequence, making duplicate delivery a no-op.
