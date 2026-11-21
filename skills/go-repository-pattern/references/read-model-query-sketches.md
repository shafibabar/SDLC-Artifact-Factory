# Read Model Query Sketches in Go

**Moved here from `read-model-design` (Wave 2, #1398; D047-10).** The Go and SQL for serving Read Models: table DDL for a list, a detail and a summary view, pgx row-scanning structs, the Read Model repository port, a filter struct, and the test-fixture pattern. Plus three small snippets that were embedded in the design references: the applied-version header for read-your-writes, the `asOf` field on a summary response, and scanning JSONB columns. The design (what a Read Model holds, which rung it sits on, its staleness and rebuild) stays in `read-model-design`. Kept as they were, with the original `DataAsset` example; reworked when `go-repository-pattern`'s harder cases next change. **This skill's own standards win where they differ:** in particular, the list query below assembles its `WHERE` clause with `fmt.Sprintf` (values still travel as `$N` parameters), which the Query-Construction Standard in `SKILL.md` forbids. Build the optional filters with `pgx.StrictNamedArgs` and fixed `(@x::type IS NULL OR column = @x)` predicates instead. Use keyset pagination (`./examples/02-tenant-list-keyset-pagination.md`), not `OFFSET`, on large tenant lists.

Projector code (the side that writes these tables) is in `go-event-consumer` (`references/projector-sketches.md` § 3).

## PostgreSQL Table DDL

### List View — data_asset_list_view

```sql
CREATE TABLE data_asset_list_view (
    id                  UUID        NOT NULL,
    tenant_id           UUID        NOT NULL,
    file_path           TEXT        NOT NULL,
    file_type           TEXT        NOT NULL,
    sensitivity_level   TEXT        NOT NULL DEFAULT 'Unclassified',
    storage_source_id   UUID        NOT NULL,
    storage_source_name TEXT        NOT NULL DEFAULT '',
    storage_source_type TEXT        NOT NULL DEFAULT '',
    entity_count        INTEGER     NOT NULL DEFAULT 0,
    last_classified_at  TIMESTAMPTZ,
    version             BIGINT      NOT NULL DEFAULT 0,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (id, tenant_id)
);

-- Primary filter: tenant + sensitivity
CREATE INDEX idx_data_asset_list_view_tenant_sensitivity ON data_asset_list_view (tenant_id, sensitivity_level);
-- Secondary filter: tenant + storage source
CREATE INDEX idx_data_asset_list_view_tenant_storage_source ON data_asset_list_view (tenant_id, storage_source_id);
```

### Detail View — data_asset_detail_view

```sql
CREATE TABLE data_asset_detail_view (
    id                  UUID        NOT NULL,
    tenant_id           UUID        NOT NULL,
    file_path           TEXT        NOT NULL,
    file_type           TEXT        NOT NULL,
    file_size_bytes     BIGINT      NOT NULL DEFAULT 0,
    sensitivity_level   TEXT        NOT NULL DEFAULT 'Unclassified',
    classified_by       TEXT        NOT NULL DEFAULT '',
    classified_at       TIMESTAMPTZ,
    storage_source_id   UUID        NOT NULL,
    storage_source_name TEXT        NOT NULL DEFAULT '',
    storage_source_type TEXT        NOT NULL DEFAULT '',
    extracted_entities  JSONB       NOT NULL DEFAULT '[]',
    compliance_flags    JSONB       NOT NULL DEFAULT '[]',
    version             BIGINT      NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (id, tenant_id)
);
```

### Aggregate View — compliance_dashboard_view

```sql
CREATE TABLE compliance_dashboard_view (
    tenant_id           UUID        NOT NULL PRIMARY KEY,
    total_assets        INTEGER     NOT NULL DEFAULT 0,
    classified_count    INTEGER     NOT NULL DEFAULT 0,
    unclassified_count  INTEGER     NOT NULL DEFAULT 0,
    by_sensitivity      JSONB       NOT NULL DEFAULT '{}', -- {"Restricted":12,"Confidential":34}
    gaps_by_framework   JSONB       NOT NULL DEFAULT '{}', -- {"SOC2":{"open":5,"resolved":2}}
    last_scan_at        TIMESTAMPTZ,
    as_of               TIMESTAMPTZ NOT NULL DEFAULT NOW(), -- freshness signal, always exposed in API
    version             BIGINT      NOT NULL DEFAULT 0
);
```

---

## Go Structs for pgx Row Scanning

Use `pgx.CollectRows` with `pgx.RowToStructByName` — struct fields are matched to column names
via the `db:` tag. Ensure column aliases in your SQL match the tag names exactly.

```go
package readmodel

import (
    "encoding/json"
    "time"

    "github.com/google/uuid"
)

// DataAssetListItem is the Read Model for the paginated asset list (GET /data-assets).
type DataAssetListItem struct {
    ID                uuid.UUID  `db:"id"`
    TenantID          uuid.UUID  `db:"tenant_id"`
    FilePath          string     `db:"file_path"`
    FileType          string     `db:"file_type"`
    SensitivityLevel  string     `db:"sensitivity_level"`
    StorageSourceID   uuid.UUID  `db:"storage_source_id"`
    StorageSourceName string     `db:"storage_source_name"`
    StorageSourceType string     `db:"storage_source_type"`
    EntityCount       int        `db:"entity_count"`
    LastClassifiedAt  *time.Time `db:"last_classified_at"`
    Version           int64      `db:"version"`
    UpdatedAt         time.Time  `db:"updated_at"`
}

// DataAssetView is the Read Model for the detail view (GET /data-assets/{id}).
type DataAssetView struct {
    ID                uuid.UUID       `db:"id"`
    TenantID          uuid.UUID       `db:"tenant_id"`
    FilePath          string          `db:"file_path"`
    FileType          string          `db:"file_type"`
    FileSizeBytes     int64           `db:"file_size_bytes"`
    SensitivityLevel  string          `db:"sensitivity_level"`
    ClassifiedBy      string          `db:"classified_by"`
    ClassifiedAt      *time.Time      `db:"classified_at"`
    StorageSourceID   uuid.UUID       `db:"storage_source_id"`
    StorageSourceName string          `db:"storage_source_name"`
    StorageSourceType string          `db:"storage_source_type"`
    ExtractedEntities json.RawMessage `db:"extracted_entities"`
    ComplianceFlags   json.RawMessage `db:"compliance_flags"`
    Version           int64           `db:"version"`
    CreatedAt         time.Time       `db:"created_at"`
    UpdatedAt         time.Time       `db:"updated_at"`
}

// ComplianceDashboard is the aggregate Read Model for the compliance dashboard.
type ComplianceDashboard struct {
    TenantID          uuid.UUID       `db:"tenant_id"`
    TotalAssets       int             `db:"total_assets"`
    ClassifiedCount   int             `db:"classified_count"`
    UnclassifiedCount int             `db:"unclassified_count"`
    BySensitivity     json.RawMessage `db:"by_sensitivity"`    // {"Restricted":12,...}
    GapsByFramework   json.RawMessage `db:"gaps_by_framework"` // {"SOC2":{"open":5,...}}
    LastScanAt        *time.Time      `db:"last_scan_at"`
    AsOf              time.Time       `db:"as_of"` // always exposed in API response
    Version           int64           `db:"version"`
}
```

---

## Repository Interface

The Read Model repository interface lives in the domain/ports layer (same package as the Write Model
ports). The implementation lives in `internal/infrastructure/postgres/readmodel/`.

```go
package ports

import (
    "context"

    "github.com/google/uuid"
    "yourmodule/internal/readmodel"
)

// DataAssetReadModelRepository defines the query contract for the DataAsset Read Models.
// This interface is owned by the domain layer; the postgres implementation is infrastructure.
type DataAssetReadModelRepository interface {
    // FindByID returns the detail view for one DataAsset. Returns ErrNotFound if absent.
    FindByID(ctx context.Context, tenantID, assetID uuid.UUID) (*readmodel.DataAssetView, error)

    // ListByTenant returns a paginated list of DataAssets for a tenant.
    // Use DataAssetListFilter to pass filter parameters safely (no SQL injection).
    ListByTenant(ctx context.Context, tenantID uuid.UUID, filter DataAssetListFilter) ([]readmodel.DataAssetListItem, int, error)
}

// ComplianceDashboardRepository defines the query contract for the compliance dashboard.
type ComplianceDashboardRepository interface {
    FindByTenant(ctx context.Context, tenantID uuid.UUID) (*readmodel.ComplianceDashboard, error)
}
```

---

## Filter Parameter Pattern — DataAssetListFilter

Never build SQL queries by string concatenation. All filter parameters must be passed as typed
struct fields and used as `$N` positional parameters in pgx queries. This prevents SQL injection
and makes query logic explicit.

```go
// DataAssetListFilter holds all parameters for a paginated DataAsset list query.
// All fields are optional — zero values mean "no filter applied".
type DataAssetListFilter struct {
    SensitivityLevel  string     // filter by sensitivity level; empty = all levels
    StorageSourceID   *uuid.UUID // filter by storage source; nil = all sources
    FileType          string     // filter by file type; empty = all types
    ClassifiedAfter   *time.Time // assets classified after this time; nil = no lower bound
    Limit             int        // page size; 0 defaults to 50; max 200
    Offset            int        // pagination offset
}

// defaultLimit is applied when the caller passes Limit = 0.
const defaultLimit = 50
const maxLimit = 200

func (f *DataAssetListFilter) resolvedLimit() int {
    if f.Limit <= 0 {
        return defaultLimit
    }
    if f.Limit > maxLimit {
        return maxLimit
    }
    return f.Limit
}
```

### Repository Implementation Using DataAssetListFilter

```go
func (r *pgDataAssetReadModelRepo) ListByTenant(
    ctx context.Context, tenantID uuid.UUID, filter ports.DataAssetListFilter,
) ([]readmodel.DataAssetListItem, int, error) {
    // Build WHERE clause from typed filter fields — never string-concat user input.
    // All values are $N positional params; pgx handles escaping.
    args := []any{tenantID} // $1 always tenant_id
    conditions := []string{"tenant_id = $1"}
    idx := 2
    appendCond := func(cond string, val any) {
        conditions = append(conditions, fmt.Sprintf(cond, idx)); args = append(args, val); idx++
    }
    if filter.SensitivityLevel != "" { appendCond("sensitivity_level = $%d", filter.SensitivityLevel) }
    if filter.StorageSourceID != nil { appendCond("storage_source_id = $%d", *filter.StorageSourceID) }
    if filter.FileType != ""         { appendCond("file_type = $%d", filter.FileType) }
    if filter.ClassifiedAfter != nil { appendCond("last_classified_at > $%d", *filter.ClassifiedAfter) }

    where := strings.Join(conditions, " AND ")
    limit := filter.resolvedLimit()
    query := fmt.Sprintf(`
        SELECT id, tenant_id, file_path, file_type, sensitivity_level,
               storage_source_id, storage_source_name, storage_source_type,
               entity_count, last_classified_at, version, updated_at
        FROM data_asset_list_view WHERE %s
        ORDER BY updated_at DESC LIMIT $%d OFFSET $%d`,
        where, idx, idx+1)
    args = append(args, limit, filter.Offset)

    rows, err := r.db.Query(ctx, query, args...)
    if err != nil { return nil, 0, fmt.Errorf("list data assets: %w", err) }
    items, err := pgx.CollectRows(rows, pgx.RowToStructByName[readmodel.DataAssetListItem])
    if err != nil { return nil, 0, fmt.Errorf("collect rows: %w", err) }

    // Count uses the same WHERE clause without LIMIT/OFFSET:
    var total int
    countQ := fmt.Sprintf(`SELECT COUNT(*) FROM data_asset_list_view WHERE %s`, where)
    if err := r.db.QueryRow(ctx, countQ, args[:idx-1]...).Scan(&total); err != nil {
        return nil, 0, fmt.Errorf("count data assets: %w", err)
    }
    return items, total, nil
}
```

---


## Test Fixture Pattern for Read Model Data

Read Model integration tests populate the Read Model table directly (bypassing the Projector) using
a fixture helper. This decouples repository query tests from projection logic.

```go
// DataAssetListFixture inserts a row directly into data_asset_list_view.
// Use the variadic overrides to customize fields per test case.
func DataAssetListFixture(t *testing.T, db *pgxpool.Pool, tenantID uuid.UUID, overrides ...func(*DataAssetListItem)) uuid.UUID {
    t.Helper()
    row := &DataAssetListItem{
        ID: uuid.New(), TenantID: tenantID,
        FilePath: "/test/fixture.pdf", FileType: "PDF",
        SensitivityLevel: "Unclassified",
        StorageSourceID: uuid.New(), StorageSourceName: "Test Drive",
        StorageSourceType: "GOOGLE_DRIVE", Version: 1, UpdatedAt: time.Now().UTC(),
    }
    for _, fn := range overrides { fn(row) }
    _, err := db.Exec(context.Background(), `
        INSERT INTO data_asset_list_view
            (id, tenant_id, file_path, file_type, sensitivity_level,
             storage_source_id, storage_source_name, storage_source_type,
             entity_count, last_classified_at, version, updated_at)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
        ON CONFLICT (id, tenant_id) DO UPDATE SET
            sensitivity_level = EXCLUDED.sensitivity_level,
            version = EXCLUDED.version, updated_at = EXCLUDED.updated_at`,
        row.ID, row.TenantID, row.FilePath, row.FileType,
        row.SensitivityLevel, row.StorageSourceID, row.StorageSourceName,
        row.StorageSourceType, row.EntityCount, row.LastClassifiedAt,
        row.Version, row.UpdatedAt)
    if err != nil { t.Fatalf("insert fixture: %v", err) }
    return row.ID
}

// Example: filter test using the fixture
func TestListByTenant_FiltersBySensitivity(t *testing.T) {
    db, tenantID := testDB(t), uuid.New()
    DataAssetListFixture(t, db, tenantID, func(r *DataAssetListItem) { r.SensitivityLevel = "Restricted" })
    DataAssetListFixture(t, db, tenantID) // Unclassified default

    items, total, err := postgres.NewDataAssetReadModelRepo(db).ListByTenant(
        context.Background(), tenantID, ports.DataAssetListFilter{SensitivityLevel: "Restricted"})
    if err != nil { t.Fatalf("ListByTenant: %v", err) }
    if total != 1 { t.Errorf("total = %d; want 1", total) }
    if len(items) != 1 || items[0].SensitivityLevel != "Restricted" {
        t.Errorf("unexpected items: %+v", items)
    }
}
```

Two separate test concerns:
- **Repository tests** use the fixture to seed rows and test query/filter logic only.
- **Projector tests** feed raw Domain Events and assert the correct Read Model rows appear,
  verifying the projection logic end-to-end without touching the repository interface.

---

## Snippets Moved From the Design References

### Read-your-writes: expose the applied version

The Command's response carries the new Aggregate version; the Read Model's GET exposes the version the view has applied, so the client (or BFF) can wait until `appliedVersion >= expectedVersion` or show the change as pending.

```go
// POST /data-assets/{id}/classify — handler response
type ClassifyResponse struct {
    DataAssetID      string `json:"dataAssetId"`
    SensitivityLevel string `json:"sensitivityLevel"`
    AppliedVersion   int64  `json:"appliedVersion"` // new Aggregate version after classify
}

// GET /data-assets/{id} — handler
func (h *Handler) GetDataAsset(w http.ResponseWriter, r *http.Request) {
    view, err := h.repo.FindByID(r.Context(), tenantID, assetID)
    // ...
    w.Header().Set("X-Applied-Version", strconv.FormatInt(view.Version, 10))
    json.NewEncoder(w).Encode(view)
}
```

### Summary views always expose `asOf`

```go
type ComplianceDashboardResponse struct {
    TotalAssets     int                   `json:"totalAssets"`
    ClassifiedCount int                   `json:"classifiedCount"`
    GapsByFramework map[string]GapSummary `json:"gapsByFramework"`
    AsOf            time.Time             `json:"asOf"` // always exposed; never omitted
    LastScanAt      *time.Time            `json:"lastScanAt,omitempty"`
}
```

### Scanning JSONB columns

```go
type DataAssetView struct {
    // ... other fields ...
    ExtractedEntities json.RawMessage `db:"extracted_entities"`
    ComplianceFlags   json.RawMessage `db:"compliance_flags"`
}

// Unmarshal when needed by the handler:
var flags []ComplianceFlag
if err := json.Unmarshal(view.ComplianceFlags, &flags); err != nil {
    return nil, fmt.Errorf("unmarshal compliance flags: %w", err)
}
```
