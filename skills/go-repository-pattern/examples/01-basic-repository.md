# Example 1 — The basic repository: read, compare-and-swap save, outbox

Self-contained. The simplest complete repository that meets every standard in the skill. It covers one Aggregate (`DataAsset`) in one tenant-scoped table: a tenant-scoped read through `Reconstitute`, an optimistic-concurrency `Save`, Domain Events drained into the Transactional Outbox on the caller's transaction, and pgx errors translated at the boundary.

## Input

> Implement the `domain.DataAssetRepository` port for the `data_assets` table: `FindByID` and `Save`. Classification changes must publish `DataAssetClassified` reliably.

## Output — `internal/infrastructure/postgres/dataasset_repo.go`

```go
package postgres

import (
    "context"
    "encoding/json"
    "errors"
    "fmt"

    "github.com/google/uuid"
    "github.com/jackc/pgx/v5"
    "github.com/jackc/pgx/v5/pgconn"
    "github.com/jackc/pgx/v5/pgxpool"

    "example.com/dataestate/internal/domain"
)

// Querier is satisfied structurally by *pgxpool.Pool and pgx.Tx.
type Querier interface {
    Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
    Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
    QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

type DataAssetRepo struct{ q Querier }

func NewDataAssetRepo(pool *pgxpool.Pool) *DataAssetRepo { return &DataAssetRepo{q: pool} }

// WithTx rebinds this repository onto the caller's transaction. It opens,
// commits and rolls back nothing itself.
func (r *DataAssetRepo) WithTx(tx pgx.Tx) *DataAssetRepo { return &DataAssetRepo{q: tx} }

var _ domain.DataAssetRepository = (*DataAssetRepo)(nil)

func (r *DataAssetRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.DataAsset, error) {
    const q = `SELECT id, tenant_id, source_id, sensitivity_level, version
                 FROM data_assets
                WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL`
    var (
        assetID, ownerTenantID, sourceID uuid.UUID
        sensitivity                      string
        version                          int64
    )
    err := r.q.QueryRow(ctx, q, id, tenantID(ctx)).Scan(&assetID, &ownerTenantID, &sourceID, &sensitivity, &version)
    if err != nil {
        return nil, translatePgError(err, domain.ErrNotFound)
    }
    return domain.Reconstitute(assetID, ownerTenantID, sourceID, domain.SensitivityLevel(sensitivity), version), nil
}

// Save must run tx-bound (via WithTx): the UPDATE and the outbox INSERTs are
// only atomic on a shared pgx.Tx.
func (r *DataAssetRepo) Save(ctx context.Context, asset *domain.DataAsset) error {
    const q = `
        UPDATE data_assets
           SET sensitivity_level = @sensitivity, version = version + 1, updated_at = now()
         WHERE id = @id AND tenant_id = @tenant_id
           AND version = @expected_version` // compare-and-swap on the version this command read
    tag, err := r.q.Exec(ctx, q, pgx.StrictNamedArgs{
        "sensitivity":      string(asset.Sensitivity()),
        "id":               asset.ID(),
        "tenant_id":        asset.TenantID(),
        "expected_version": asset.Version(),
    })
    if err != nil {
        return translatePgError(fmt.Errorf("updating data asset %s: %w", asset.ID(), err), nil)
    }
    if tag.RowsAffected() == 0 {
        return fmt.Errorf("data asset %s: %w", asset.ID(), domain.ErrConcurrentModification)
    }
    return r.insertOutboxEvents(ctx, asset)
}

func (r *DataAssetRepo) insertOutboxEvents(ctx context.Context, asset *domain.DataAsset) error {
    for _, event := range asset.PullEvents() {
        payload, err := json.Marshal(event)
        if err != nil {
            return fmt.Errorf("marshalling %s: %w", event.EventType(), err)
        }
        if _, err := r.q.Exec(ctx, `
            INSERT INTO outbox (id, aggregate_id, tenant_id, event_type, payload, occurred_at)
            VALUES (@id, @aggregate_id, @tenant_id, @event_type, @payload, now())`,
            pgx.StrictNamedArgs{
                "id":           uuid.New(),
                "aggregate_id": asset.ID(),
                "tenant_id":    asset.TenantID(),
                "event_type":   event.EventType(),
                "payload":      payload,
            },
        ); err != nil {
            return translatePgError(fmt.Errorf("writing outbox %s: %w", event.EventType(), err), nil)
        }
    }
    return nil
}

// translatePgError maps pgx/pgconn errors onto domain errors; the full table
// lives in the skill's error-translation reference. No pgx type leaves this package.
func translatePgError(err error, notFound error) error {
    var pgErr *pgconn.PgError
    switch {
    case err == nil:
        return nil
    case errors.Is(err, pgx.ErrNoRows) && notFound != nil:
        return notFound
    case errors.Is(err, context.DeadlineExceeded):
        return domain.ErrTimeout
    case errors.Is(err, context.Canceled):
        return domain.ErrCanceled
    case errors.As(err, &pgErr) && pgErr.Code == "23505":
        // The reference maps the constraint name to a domain field name; the
        // raw constraint name is used here to keep the example short.
        return &domain.ErrDuplicate{Field: pgErr.ConstraintName}
    case errors.As(err, &pgErr) && pgErr.Code == "23503":
        return domain.ErrInvalidReference
    case errors.As(err, &pgErr) && pgErr.Code == "57014":
        return domain.ErrTimeout
    default:
        return fmt.Errorf("postgres: %w", err)
    }
}
```

The application layer opens the transaction and binds the repository to it:

```go
func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) (err error) {
    tx, err := h.pool.Begin(ctx)
    if err != nil {
        return fmt.Errorf("begin: %w", err)
    }
    defer func() {
        if err != nil {
            _ = tx.Rollback(ctx) // safe no-op after a successful Commit
        }
    }()

    assets := h.assets.WithTx(tx)
    asset, err := assets.FindByID(ctx, cmd.AssetID)
    if err != nil {
        return err
    }
    if err = asset.Classify(cmd.Level, cmd.ClassifiedBy); err != nil {
        return err // invariant violation, decided in the Aggregate
    }
    if err = assets.Save(ctx, asset); err != nil {
        return err
    }
    return tx.Commit(ctx)
}
```

## What the integration test must prove (go-integration-test owns the harness)

- Two concurrent `Save`s of the same version: exactly one succeeds, and the other returns `domain.ErrConcurrentModification`.
- A failing outbox `INSERT` rolls back the `UPDATE`: no state change without its event.
- `FindByID` with another tenant's asset ID returns `domain.ErrNotFound`, never the row.
