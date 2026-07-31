# Go Implementation Patterns for CQRS

Self-contained reference for Go code patterns in a Full CQRS service. Usable without the parent SKILL.md in context.

All patterns target this plugin's default stack: Go, `net/http` + `chi`, PostgreSQL + `pgx/v5`, Redpanda (Kafka-compatible). Patterns are grounded in Evans' four-layer architecture (UI/Application/Domain/Infrastructure) with the Domain layer isolated from all I/O.

---

## Package Layout for a CQRS Service

```
internal/
├── domain/
│   ├── data_asset.go         ← Aggregate root, value objects, domain errors
│   ├── ports.go              ← Repository interface + Command/Event types
│   └── events.go             ← Domain Event structs (immutable, value types)
├── application/
│   ├── commands/
│   │   ├── classify_data_asset.go    ← ClassifyDataAssetHandler
│   │   ├── register_data_asset.go    ← RegisterDataAssetHandler
│   │   └── idempotency.go            ← CommandLog interface + pgx implementation
│   └── queries/
│       ├── get_data_asset_detail.go  ← GetDataAssetDetailHandler
│       └── list_data_assets.go       ← ListDataAssetsHandler
├── infrastructure/
│   ├── postgres/
│   │   ├── data_asset_repo.go        ← DataAssetRepository implementation
│   │   └── outbox.go                 ← Outbox insert helper
│   ├── projectors/
│   │   └── data_asset_projector.go   ← DataAssetProjector (event-driven)
│   └── readstore/
│       └── data_asset_read_store.go  ← Read Model queries via pgx
└── api/
    └── handlers/
        ├── data_asset_write.go       ← POST/PUT handlers → Command
        └── data_asset_read.go        ← GET handlers → Query Handler
```

**Rules enforced by this layout:**
- `domain/` imports only stdlib, `uuid`, and `time`. No framework, no I/O (Evans' Domain-layer isolation).
- `application/commands/` never imports `application/queries/` and vice versa.
- `application/` depends on `domain/` interfaces, never on `infrastructure/` concrete types.
- `infrastructure/` depends on `domain/` interfaces only (Dependency Inversion).

---

## Command Handler Pattern

Command handlers live in `application/commands/`. One file per Command.

```go
// application/commands/classify_data_asset.go

package commands

import (
    "context"
    "fmt"

    "github.com/org/service/internal/domain"
)

// ClassifyDataAsset is the Command struct — a plain value, no methods.
type ClassifyDataAsset struct {
    IdempotencyKey  string
    DataAssetID     domain.DataAssetID
    TenantID        domain.TenantID
    Sensitivity     domain.SensitivityLevel
    ClassifiedBy    string
    OccurredAt      time.Time
}

// ClassifyDataAssetHandler coordinates the classify use case.
// It depends only on domain interfaces — never on concrete infrastructure types.
type ClassifyDataAssetHandler struct {
    repo       domain.DataAssetRepository
    commandLog CommandLog
}

func NewClassifyDataAssetHandler(
    repo domain.DataAssetRepository,
    commandLog CommandLog,
) *ClassifyDataAssetHandler {
    return &ClassifyDataAssetHandler{repo: repo, commandLog: commandLog}
}

// Handle executes the classify use case.
// Returns (newVersion int64, error) — version enables read-your-own-writes polling.
func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) (int64, error) {
    // 1. Idempotency check — reject duplicate commands before any domain work.
    if err := h.commandLog.CheckAndRecord(ctx, cmd.IdempotencyKey); err != nil {
        return 0, fmt.Errorf("idempotency: %w", err)
    }

    // 2. Load Aggregate from Repository.
    asset, err := h.repo.FindByID(ctx, cmd.DataAssetID, cmd.TenantID)
    if err != nil {
        return 0, fmt.Errorf("loading data asset %s: %w", cmd.DataAssetID, err)
    }

    // 3. Domain operation — Aggregate enforces invariants, collects events.
    if err := asset.Classify(domain.ClassifyCommand{
        Sensitivity:  cmd.Sensitivity,
        ClassifiedBy: cmd.ClassifiedBy,
        OccurredAt:   cmd.OccurredAt,
    }); err != nil {
        return 0, err // domain.ErrInvariantViolation wraps business rule errors
    }

    // 4. Save — Aggregate state + outbox events in one transaction.
    if err := h.repo.Save(ctx, asset); err != nil {
        return 0, fmt.Errorf("saving data asset: %w", err)
    }

    return asset.Version(), nil
}
```

### CommandLog Interface (Idempotency)

```go
// domain/ports.go

// CommandLog records processed command idempotency keys.
// The implementation uses a PostgreSQL table:
//   CREATE TABLE command_log (
//       idempotency_key TEXT PRIMARY KEY,
//       recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
//   );
type CommandLog interface {
    // CheckAndRecord inserts the key if absent, returning nil on success.
    // Returns ErrAlreadyProcessed if the key is already present.
    CheckAndRecord(ctx context.Context, key string) error
}
```

---

## Repository Interface (Domain Layer)

```go
// domain/ports.go

// DataAssetRepository is the port. The interface lives in the domain layer.
// The PostgreSQL implementation lives in infrastructure/postgres/.
type DataAssetRepository interface {
    FindByID(ctx context.Context, id DataAssetID, tenantID TenantID) (*DataAsset, error)
    Save(ctx context.Context, asset *DataAsset) error
}
```

### Repository Implementation (Infrastructure Layer)

```go
// infrastructure/postgres/data_asset_repo.go

package postgres

type DataAssetRepository struct {
    db *pgxpool.Pool
}

func (r *DataAssetRepository) Save(ctx context.Context, asset *domain.DataAsset) error {
    tx, err := r.db.Begin(ctx)
    if err != nil {
        return err
    }
    defer tx.Rollback(ctx)

    // Optimistic concurrency: CAS on version (Vernon's default).
    // "0 rows affected" means a concurrent writer already incremented version.
    tag, err := tx.Exec(ctx, `
        UPDATE data_assets
        SET sensitivity = $1, classified_at = $2, version = $3
        WHERE id = $4 AND tenant_id = $5 AND version = $6`,
        asset.Sensitivity(), asset.ClassifiedAt(),
        asset.Version(),          // new version (incremented by Aggregate)
        asset.ID(), asset.TenantID(),
        asset.Version()-1,        // expected version (old)
    )
    if err != nil {
        return fmt.Errorf("updating data asset: %w", err)
    }
    if tag.RowsAffected() == 0 {
        return domain.ErrConcurrentModification
    }

    // Insert Domain Events into outbox (same transaction — Transactional Outbox pattern).
    for _, evt := range asset.Events() {
        payload, err := json.Marshal(evt)
        if err != nil {
            return err
        }
        _, err = tx.Exec(ctx, `
            INSERT INTO outbox_events (id, aggregate_id, event_type, payload, created_at)
            VALUES ($1, $2, $3, $4, $5)`,
            uuid.New(), asset.ID(), evt.EventType(), payload, time.Now(),
        )
        if err != nil {
            return fmt.Errorf("inserting outbox event: %w", err)
        }
    }

    return tx.Commit(ctx)
}
```

---

## Projector Pattern (Event-Driven)

```go
// infrastructure/projectors/data_asset_projector.go

package projectors

// DataAssetProjector maintains the data_asset_detail Read Model
// by consuming DataAsset Domain Events from Redpanda.
type DataAssetProjector struct {
    db *pgxpool.Pool
}

// HandleDataAssetClassified updates the detail Read Model when an asset is classified.
// Idempotency: the ON CONFLICT ... WHERE event_sequence < EXCLUDED.event_sequence
// clause ensures that replaying an already-applied event is a safe no-op.
func (p *DataAssetProjector) HandleDataAssetClassified(
    ctx context.Context,
    evt events.DataAssetClassified,
) error {
    _, err := p.db.Exec(ctx, `
        INSERT INTO data_asset_detail (
            id, tenant_id, name, sensitivity,
            storage_source_id, storage_source_name,
            classified_at, event_sequence
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (id) DO UPDATE
            SET sensitivity         = EXCLUDED.sensitivity,
                classified_at       = EXCLUDED.classified_at,
                event_sequence      = EXCLUDED.event_sequence
            WHERE data_asset_detail.event_sequence < EXCLUDED.event_sequence`,
        evt.DataAssetID, evt.TenantID, evt.Name,
        evt.Sensitivity, evt.StorageSourceID, evt.StorageSourceName,
        evt.OccurredAt, evt.EventSequence,
    )
    if err != nil {
        return fmt.Errorf("upserting data_asset_detail: %w", err)
    }
    return nil
}
```

### Read Model Schema

```sql
CREATE TABLE data_asset_detail (
    id                  UUID        PRIMARY KEY,
    tenant_id           UUID        NOT NULL,
    name                TEXT        NOT NULL,
    sensitivity         TEXT        NOT NULL,
    storage_source_id   UUID,
    storage_source_name TEXT,                   -- denormalised from StorageSource events
    classified_at       TIMESTAMPTZ,
    event_sequence      BIGINT      NOT NULL DEFAULT 0
);

CREATE INDEX data_asset_detail_tenant ON data_asset_detail (tenant_id);
```

---

## Read Query Handler Pattern

```go
// application/queries/get_data_asset_detail.go

package queries

// GetDataAssetDetail is the Query — a plain value, no side effects.
type GetDataAssetDetail struct {
    DataAssetID domain.DataAssetID
    TenantID    domain.TenantID
}

// DataAssetDetail is the Read Model — shaped entirely by what the client needs,
// not by the Aggregate's own fields. (Khononov: Read Model is decoupled from
// Aggregate boundaries by design.)
type DataAssetDetail struct {
    ID                 domain.DataAssetID
    TenantID           domain.TenantID
    Name               string
    Sensitivity        domain.SensitivityLevel
    StorageSourceID    uuid.UUID
    StorageSourceName  string
    ClassifiedAt       *time.Time
}

// DataAssetReadStore is the port for the Read Model store.
type DataAssetReadStore interface {
    FindDetail(ctx context.Context, id domain.DataAssetID, tenantID domain.TenantID) (*DataAssetDetail, error)
    ListForTenant(ctx context.Context, tenantID domain.TenantID, limit, offset int) ([]*DataAssetDetail, error)
}

// GetDataAssetDetailHandler executes the read-side query.
// It never calls the Repository, never loads an Aggregate.
type GetDataAssetDetailHandler struct {
    store DataAssetReadStore
}

func (h *GetDataAssetDetailHandler) Handle(
    ctx context.Context,
    query GetDataAssetDetail,
) (*DataAssetDetail, error) {
    detail, err := h.store.FindDetail(ctx, query.DataAssetID, query.TenantID)
    if err != nil {
        return nil, err
    }
    return detail, nil
}
```

### Read Store Implementation

```go
// infrastructure/readstore/data_asset_read_store.go

func (s *DataAssetReadStore) FindDetail(
    ctx context.Context,
    id domain.DataAssetID,
    tenantID domain.TenantID,
) (*queries.DataAssetDetail, error) {
    row := s.db.QueryRow(ctx, `
        SELECT id, tenant_id, name, sensitivity,
               storage_source_id, storage_source_name, classified_at
        FROM data_asset_detail
        WHERE id = $1 AND tenant_id = $2`,
        id, tenantID,
    )

    var d queries.DataAssetDetail
    if err := row.Scan(
        &d.ID, &d.TenantID, &d.Name, &d.Sensitivity,
        &d.StorageSourceID, &d.StorageSourceName, &d.ClassifiedAt,
    ); err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            return nil, domain.ErrNotFound
        }
        return nil, fmt.Errorf("scanning data_asset_detail: %w", err)
    }
    return &d, nil
}
```

---

## Wiring It Together (Dependency Injection at Startup)

```go
// main.go or cmd/server/main.go

func main() {
    db := mustConnectDB()

    // Infrastructure
    assetRepo     := postgres.NewDataAssetRepository(db)
    commandLog    := postgres.NewCommandLog(db)
    readStore     := readstore.NewDataAssetReadStore(db)

    // Application — Commands
    classifyHandler := commands.NewClassifyDataAssetHandler(assetRepo, commandLog)

    // Application — Queries
    detailHandler := queries.NewGetDataAssetDetailHandler(readStore)

    // HTTP Router
    r := chi.NewRouter()
    r.Put("/data-assets/{id}/classify",
        api.HandleClassifyDataAsset(classifyHandler))
    r.Get("/data-assets/{id}",
        api.HandleGetDataAssetDetail(detailHandler))

    // Projector (runs as a separate goroutine or process)
    projector := projectors.NewDataAssetProjector(db)
    go projector.Start(ctx, redpandaClient)

    http.ListenAndServe(":8080", r)
}
```

**Dependency direction:** `api` → `application` → `domain` ← `infrastructure`. The domain layer never imports any of the other three. Infrastructure only imports the domain's interfaces.
