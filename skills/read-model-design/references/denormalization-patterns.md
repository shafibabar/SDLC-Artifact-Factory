# Denormalization Patterns for Read Models

Self-contained reference for denormalization decisions in Read Model design. Usable without
the parent SKILL.md in context.

Grounded in: Khononov (Learning DDD — Read Models answer to query needs, not Aggregate structure),
Evans (Domain-Driven Design — Aggregates enforce invariants; Read Models serve queries separately),
and practical Go/pgx conventions.

---

## Core Principle: Aggregate Boundary vs. Read Model Shape

An Aggregate boundary is drawn around a transactional-consistency requirement. A Read Model boundary
is drawn around a query requirement. These are different forces and different decompositions — they
do not need to align.

Practical consequences:
- A `DataAssetListItem` may embed `storageSourceName` (from the `StorageSource` Aggregate in another
  bounded context) even though `DataAsset` only holds a `storageSourceID` reference in its write model.
- A `ComplianceDashboard` Read Model may aggregate counts from `DataAssetClassified` events across
  the entire tenant — crossing the boundary of any individual `DataAsset` Aggregate instance.
- A single Domain Event (`DataAssetClassified`) may feed three structurally unrelated Read Models
  (`DataAssetListItem`, `DataAssetView`, `ComplianceDashboard`) without any structural coupling
  between those Read Models.

Never ask "which Aggregate does this Read Model belong to?" Ask instead: "which query does this
Read Model serve, and what fields does that query's caller actually need?"

---

## Embedding vs. Referencing

### Rule: Embed when the caller needs the display value, not the ID

| Scenario | Write model has | Caller needs | Decision |
|---|---|---|---|
| List shows storage source name | `storageSourceID uuid.UUID` | "Google Drive" | Embed `storageSourceName string` |
| Detail shows owner info | `ownerUserID uuid.UUID` | Owner email + display name | Embed `ownerEmail`, `ownerDisplayName` |
| List shows sensitivity | `sensitivityLevel SensitivityLevel` (VO) | "Restricted" string | Embed as `string` — no VO in Read Model |
| Report aggregates by framework | `complianceFlags []ComplianceFlag` | Count per framework | Embed `gapsByFramework map[string]int` |

### Rule: Never embed a sub-document when a reference ID is all the caller needs

If the caller navigates to a detail page using an ID, the list Read Model should carry only the ID.
Do not pre-embed the entire related entity in the list view when the caller only needs a navigation link.

Example:
```
// WRONG: entire StorageSource detail embedded in list item
type DataAssetListItem struct {
    ID            uuid.UUID
    StorageSource StorageSourceDetail  // 12 fields the list page never shows
}

// CORRECT: embed only the display fields the list page renders
type DataAssetListItem struct {
    ID                uuid.UUID
    StorageSourceID   uuid.UUID  // for navigation link
    StorageSourceName string     // for display
    StorageSourceType string     // for display icon
}
```

---

## The N+1 Flattening Heuristic

**If satisfying a query would require N+1 reads against the write model, the missing fields must be
embedded in the Read Model.**

Example: A list page shows 20 `DataAsset` rows. Each row shows `storageSourceName`. If the Read Model
holds only `storageSourceID`, the API must issue one `SELECT` per row to resolve the name — 20 extra
queries for a 20-row page. The projector must embed `storageSourceName` at event time:

```go
// In the DataAssetListProjector, when handling DataAssetRegistered:
func (p *DataAssetListProjector) handleRegistered(ctx context.Context, e domain.DataAssetRegistered) error {
    // Resolve storageSourceName at projection time, not at query time
    source, err := p.storageSourceReader.FindByID(ctx, e.TenantID, e.StorageSourceID)
    if err != nil {
        return fmt.Errorf("resolving storage source for projection: %w", err)
    }
    return p.store.UpsertListItem(ctx, DataAssetListItem{
        ID:                e.DataAssetID,
        TenantID:          e.TenantID,
        FilePath:          e.FilePath,
        FileType:          e.FileType,
        StorageSourceID:   e.StorageSourceID,
        StorageSourceName: source.Name,
        StorageSourceType: source.SourceType,
        Version:           e.AggregateVersion,
        UpdatedAt:         e.OccurredAt,
    })
}
```

Corollary: when a related Aggregate's display data changes (e.g., StorageSource is renamed), the
Projector must handle that event and re-project the Read Model rows that embedded the old value.
This is the cost of denormalization — accept it rather than introduce query-time JOINs.

---

## Variable-Structure Fields — JSONB

Use a PostgreSQL JSONB column when:
- The field is an array of items with a known schema but variable length (extracted entities, compliance flags)
- The field is a key-value map with variable keys per row (metadata, tags per classification framework)
- Querying inside the field is required (e.g., `complianceFlags @> '[{"framework":"SOC2"}]'`)

Use a separate Read Model (or a separate table) when:
- A query needs to filter/sort by an attribute inside the variable-structure field
- The JSONB document grows without bound (unbounded arrays — a hotspot risk on a single row)
- Different callers need different subsets of the same embedded data with meaningful frequency

Example JSONB usage:
```sql
-- In data_asset_detail_view:
extracted_entities  JSONB    NOT NULL DEFAULT '[]',  -- [{type: "EMAIL", value: "...", confidence: 0.97}]
compliance_flags    JSONB    NOT NULL DEFAULT '[]',  -- [{framework: "SOC2", flagType: "PII_EXPOSURE", severity: "HIGH"}]
```

Example JSONB Go scanning:
```go
type DataAssetView struct {
    // ... other fields ...
    ExtractedEntities  json.RawMessage `db:"extracted_entities"`
    ComplianceFlags    json.RawMessage `db:"compliance_flags"`
}

// Unmarshal when needed by the handler:
var flags []ComplianceFlag
if err := json.Unmarshal(view.ComplianceFlags, &flags); err != nil {
    return nil, fmt.Errorf("unmarshal compliance flags: %w", err)
}
```

---

## Read Model Categories — Go Structs

### List View

Paginated, filterable. Optimized for search and browse. Heavily denormalized — includes display fields
from multiple Aggregates' events.

```go
// DataAssetListItem — one row in GET /data-assets (paginated list)
type DataAssetListItem struct {
    ID                uuid.UUID  `db:"id"`
    TenantID          uuid.UUID  `db:"tenant_id"`
    FilePath          string     `db:"file_path"`
    FileType          string     `db:"file_type"`
    SensitivityLevel  string     `db:"sensitivity_level"`
    StorageSourceName string     `db:"storage_source_name"`
    StorageSourceType string     `db:"storage_source_type"`
    EntityCount       int        `db:"entity_count"`
    LastClassifiedAt  *time.Time `db:"last_classified_at"`
    Version           int64      `db:"version"`
    UpdatedAt         time.Time  `db:"updated_at"`
}
```

### Detail View

Full detail for a single resource. May include JSONB sub-documents. Optimized for a single-resource
GET request. One Projector upserts this row in full.

```go
// DataAssetView — GET /data-assets/{id}
type DataAssetView struct {
    ID                 uuid.UUID       `db:"id"`
    TenantID           uuid.UUID       `db:"tenant_id"`
    FilePath           string          `db:"file_path"`
    FileType           string          `db:"file_type"`
    FileSizeBytes      int64           `db:"file_size_bytes"`
    SensitivityLevel   string          `db:"sensitivity_level"`
    ClassifiedBy       string          `db:"classified_by"`
    ClassifiedAt       *time.Time      `db:"classified_at"`
    StorageSourceID    uuid.UUID       `db:"storage_source_id"`
    StorageSourceName  string          `db:"storage_source_name"`
    StorageSourceType  string          `db:"storage_source_type"`
    ExtractedEntities  json.RawMessage `db:"extracted_entities"`
    ComplianceFlags    json.RawMessage `db:"compliance_flags"`
    Version            int64           `db:"version"`
    CreatedAt          time.Time       `db:"created_at"`
    UpdatedAt          time.Time       `db:"updated_at"`
}
```

### Aggregate View (Dashboard / Summary)

Pre-computed aggregates. Totals, counts, breakdowns by category. Optimized for dashboard rendering —
one query returns all data the dashboard needs. Always includes `AsOf` to communicate freshness.

```go
// ComplianceDashboard — GET /compliance/dashboard
type ComplianceDashboard struct {
    TenantID          uuid.UUID              `db:"tenant_id"`
    TotalAssets       int                    `db:"total_assets"`
    ClassifiedCount   int                    `db:"classified_count"`
    UnclassifiedCount int                    `db:"unclassified_count"`
    BySensitivity     json.RawMessage        `db:"by_sensitivity"`      // {"Restricted":12,"Confidential":34}
    GapsByFramework   json.RawMessage        `db:"gaps_by_framework"`   // {"SOC2":{"open":5,"resolved":2}}
    LastScanAt        *time.Time             `db:"last_scan_at"`
    AsOf              time.Time              `db:"as_of"`               // when this projection was last updated
    Version           int64                  `db:"version"`
}
```

---

## When to Split Into Multiple Read Models

Split a single Read Model into two or more when:

| Trigger | Explanation |
|---|---|
| Different staleness tolerances | A summary needs immediate freshness; a report tolerates minutes — one Read Model cannot serve both without overloading the projector |
| Different consumer types | Mobile client needs 6 fields; admin panel needs 40 fields — the wide model wastes I/O for the mobile caller |
| Unbounded JSONB growth | A JSONB array that grows without bound on a single row becomes a hotspot; split into a child Read Model table with one row per item |
| Diverging update cadence | List rows are updated on every event; a dashboard is rebuilt at a coarser cadence — separate Projectors with separate update strategies |

Do not split prematurely. The cost of maintaining two Projectors and two tables is real. Split only
when one of the above triggers actually applies.

---

## DataAsset Denormalization Example — Full Story

The DataAssetManagement Bounded Context demonstrates all three patterns:

**StorageSource name embedded in list and detail views:**
- The `StorageSource` Aggregate lives in a separate Storage Connectors context.
- `DataAsset` holds only `storageSourceID` in the write model (reference by ID, per Vernon's Rule 3).
- The list view must show the storage source name for each asset.
- The DataAssetListProjector resolves `storageSourceName` at projection time and embeds it.
- When the Storage Connectors context publishes `StorageSourceRenamed`, the DataAssetListProjector
  handles it and re-projects all affected rows (a targeted UPDATE on `storage_source_name WHERE storage_source_id = $1`).

**Extracted entities as JSONB:**
- The number and content of extracted entities varies per asset.
- The detail view embeds `extracted_entities` as JSONB (full list, with type/value/confidence).
- The list view embeds only `entity_count` (an integer count) — what the list page renders.
- These are two separate fields in two separate Read Models, both populated from the same
  `ExtractedEntitiesUpdated` domain event, but shaped for their respective callers.

**Compliance dashboard as a separate Aggregate view:**
- The dashboard shows total assets, classified/unclassified counts, and breakdowns by sensitivity and framework.
- This data spans all `DataAsset` instances in a tenant — no single Aggregate owns it.
- A `ComplianceDashboardProjector` consumes `DataAssetClassified`, `ComplianceGapDetected`, and
  `ComplianceGapResolved` and maintains a single row per tenant in `compliance_dashboard_view`.
- The row carries `as_of` set to the timestamp of the most recently processed event.
