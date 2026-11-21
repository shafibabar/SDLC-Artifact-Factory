# Projector Sketches in Go

**Moved here from `cqrs-pattern` (Wave 2, #1397; D047-10).** The Go sketches for the three projection mechanics (synchronous in the write transaction, event-driven from the broker, Change Data Capture from Debezium) and the two projector idempotency guards. The design-level comparison of the mechanics is in `read-model-design`. Kept as they were, with the original `DataAsset` example; reworked when `go-event-consumer` is rebuilt. This skill's own idempotency standard (`./idempotent-consumer-standard.md`) wins where they differ.

## 1. Mechanic sketches

### Sketch (within the Repository Save transaction)

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

### Sketch (Projector consuming from Redpanda)

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

### Sketch (Projector consuming Debezium CDC events)

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

## 2. Idempotency guards

### Dedup table: processed_event_ids Table

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

---

## 3. A Read Model projector (moved from `read-model-design`, #1398)

The full projector for one list view, moved with the rest of `read-model-design`'s Go (D047-10). It shows four things the design asks for: the event's Aggregate version copied into the row (for read-your-writes and the newer-than guard), a display value resolved at projection time and re-projected when its source changes, unknown event types skipped without error, and the consumer position written in the same transaction as the view. Note a gap the design names that this sketch does not cover: a replay from the start meets every historical event type, so a type that was replaced by a new one must keep its handler (or be read through an upcaster), never fall into `default` and be skipped. This skill's idempotency standard (`./idempotent-consumer-standard.md`) and offset-commit standard win where they differ.

```go
package projector

import (
    "context"
    "fmt"

    "github.com/google/uuid"
    "github.com/jackc/pgx/v5"
    "yourmodule/internal/domain"
    "yourmodule/internal/readmodel/store"
)

// DataAssetListProjector maintains the data_asset_list_view table.
// It is idempotent, never issues Commands, and handles all subscribed events.
type DataAssetListProjector struct {
    store             store.DataAssetListStore
    storageSourceRepo StorageSourceReader
    offsetStore       store.OffsetStore
}

func (p *DataAssetListProjector) Project(ctx context.Context, tx pgx.Tx, rec ConsumerRecord) error {
    var err error
    switch e := rec.Event.(type) {
    case domain.DataAssetRegistered:
        err = p.handleRegistered(ctx, tx, e)
    case domain.DataAssetClassified:
        err = p.handleClassified(ctx, tx, e)
    case domain.DataAssetArchived:
        err = p.handleArchived(ctx, tx, e)
    case domain.StorageSourceConfirmed:
        err = p.handleStorageSourceConfirmed(ctx, tx, e)
    default:
        // Tolerate unknown events — Tolerant Reader pattern.
        return p.offsetStore.CommitOffset(ctx, tx, rec.Topic, rec.Partition, rec.Offset)
    }
    if err != nil {
        return fmt.Errorf("projecting %T: %w", rec.Event, err)
    }
    // Commit the event offset in the SAME transaction as the Read Model write.
    return p.offsetStore.CommitOffset(ctx, tx, rec.Topic, rec.Partition, rec.Offset)
}

func (p *DataAssetListProjector) handleRegistered(ctx context.Context, tx pgx.Tx, e domain.DataAssetRegistered) error {
    source, err := p.storageSourceRepo.FindByID(ctx, e.TenantID, e.StorageSourceID)
    if err != nil {
        return fmt.Errorf("resolving storage source: %w", err)
    }
    return p.store.Upsert(ctx, tx, store.UpsertListItemParams{
        ID:                e.DataAssetID,
        TenantID:          e.TenantID,
        FilePath:          e.FilePath,
        FileType:          e.FileType,
        SensitivityLevel:  "Unclassified",
        StorageSourceID:   e.StorageSourceID,
        StorageSourceName: source.Name,
        StorageSourceType: source.SourceType,
        Version:           e.AggregateVersion,
        UpdatedAt:         e.OccurredAt,
    })
}

func (p *DataAssetListProjector) handleClassified(ctx context.Context, tx pgx.Tx, e domain.DataAssetClassified) error {
    return p.store.UpdateSensitivity(ctx, tx, store.UpdateSensitivityParams{
        DataAssetID: e.DataAssetID, TenantID: e.TenantID,
        SensitivityLevel: e.SensitivityLevel.String(), EntityCount: e.ExtractedEntityCount,
        LastClassifiedAt: e.OccurredAt, Version: e.AggregateVersion, UpdatedAt: e.OccurredAt,
    })
}

func (p *DataAssetListProjector) handleArchived(ctx context.Context, tx pgx.Tx, e domain.DataAssetArchived) error {
    return p.store.DeleteByID(ctx, tx, e.TenantID, e.DataAssetID)
}

// handleStorageSourceConfirmed re-projects all rows for the named source — the display name may have changed.
func (p *DataAssetListProjector) handleStorageSourceConfirmed(ctx context.Context, tx pgx.Tx, e domain.StorageSourceConfirmed) error {
    return p.store.UpdateStorageSourceInfo(ctx, tx, store.UpdateStorageSourceInfoParams{
        TenantID: e.TenantID, StorageSourceID: e.StorageSourceID,
        StorageSourceName: e.Name, StorageSourceType: e.SourceType,
    })
}
```

---


### Copying the Aggregate version into the row

```go
func (p *DataAssetListProjector) handleClassified(ctx context.Context, e domain.DataAssetClassified) error {
    return p.store.UpdateSensitivity(ctx, UpdateSensitivityParams{
        DataAssetID:      e.DataAssetID,
        TenantID:         e.TenantID,
        SensitivityLevel: e.SensitivityLevel.String(),
        LastClassifiedAt: e.OccurredAt,
        Version:          e.AggregateVersion, // copied from the event
        UpdatedAt:        e.OccurredAt,
    })
}
```

The upsert applies only a newer version, so a re-delivered old event cannot roll the row back:

```sql
INSERT INTO data_asset_list_view (id, tenant_id, file_path, version, updated_at)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (id, tenant_id)
DO UPDATE SET file_path = EXCLUDED.file_path, version = EXCLUDED.version, updated_at = EXCLUDED.updated_at
WHERE data_asset_list_view.version < EXCLUDED.version;
```
