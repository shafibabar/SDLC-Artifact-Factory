---
name: read-model-design
description: >
  Teaches how to design Read Models in a CQRS architecture — covering the
  distinction between the Write Model (Aggregates) and Read Models (query-optimised
  projections), how to build Read Models from Domain Events, denormalisation
  strategies, Go struct design for Read Models, and how Read Models connect to
  API response contracts and frontend data requirements. Used by the domain-modeler
  agent after the domain-event-catalog is complete.
version: 1.0.0
phase: design
owner: domain-modeler
tags: [design, ddd, cqrs, read-model, projections, query-side, go]
---

# Read Model Design

## Purpose

In CQRS (Command Query Responsibility Segregation), the write side and the read side are separated. The write side is the domain model — Aggregates that enforce invariants and emit Domain Events. The read side is a set of Read Models — query-optimised projections of the domain state, built from Domain Events.

A Read Model is never built by querying the Aggregate table directly. It is built by projecting Domain Events into a structure optimised for the query it serves. This separation:
- Keeps the domain model free from query concerns
- Allows the read side to be optimised independently (denormalised, indexed differently, cached)
- Enables multiple Read Models to serve the same domain data in different shapes for different consumers

---

## Read Model vs Write Model

| | Write Model (Aggregate) | Read Model (Projection) |
|---|---|---|
| **Purpose** | Enforce invariants; emit events | Serve queries; optimised for reading |
| **Normalisation** | Normalised — one source of truth | Denormalised — shaped for the query |
| **Source of truth** | Yes — Aggregates own the canonical state | No — rebuilt from events; can be rebuilt if corrupted |
| **Consistency** | Strongly consistent within the transaction | Eventually consistent — updated asynchronously |
| **Structure** | DDD types (Entity, VO, Aggregate Root) | Simple structs; flat; JSON-serialisable |
| **Mutability** | Updated by Commands through the Aggregate Root | Updated by event projectors; never directly by Command handlers |

---

## Read Model Categories

### 1. List Views

Paginated, filterable lists. Optimised for search and browse. Heavily denormalised — include display fields from multiple source entities.

```go
type DataAssetListItem struct {
    ID               uuid.UUID        `json:"id"`
    FilePath         string           `json:"filePath"`
    FileType         string           `json:"fileType"`
    SensitivityLevel string           `json:"sensitivityLevel"`
    StorageSourceName string          `json:"storageSourceName"`
    LastClassifiedAt time.Time        `json:"lastClassifiedAt"`
    EntityCount      int              `json:"entityCount"`
}
```

### 2. Detail Views

Full detail for a single resource. May include nested objects. Optimised for a single-resource GET request.

```go
type DataAssetDetail struct {
    ID               uuid.UUID         `json:"id"`
    FilePath         string            `json:"filePath"`
    FileType         string            `json:"fileType"`
    SensitivityLevel string            `json:"sensitivityLevel"`
    StorageSource    StorageSourceRef  `json:"storageSource"`
    ExtractedEntities []EntityRef      `json:"extractedEntities"`
    ComplianceFlags  []ComplianceFlag  `json:"complianceFlags"`
    ScanHistory      []ScanRecord      `json:"scanHistory"`
    CreatedAt        time.Time         `json:"createdAt"`
    ClassifiedAt     *time.Time        `json:"classifiedAt,omitempty"`
}
```

### 3. Aggregate Views (Dashboard / Summary)

Pre-computed aggregates. Totals, counts, breakdowns by category. Optimised for dashboard rendering — one query, complete data.

```go
type ComplianceDashboard struct {
    TenantID         uuid.UUID                    `json:"tenantId"`
    TotalAssets      int                          `json:"totalAssets"`
    ClassifiedCount  int                          `json:"classifiedCount"`
    UnclassifiedCount int                         `json:"unclassifiedCount"`
    BySensitivity    map[string]int               `json:"bySensitivity"`
    GapsByFramework  map[string]ComplianceGapSummary `json:"gapsByFramework"`
    LastScanAt       *time.Time                   `json:"lastScanAt,omitempty"`
    AsOf             time.Time                    `json:"asOf"`
}
```

---

## Building Read Models from Events (Projectors)

A Projector is a function that consumes Domain Events and updates a Read Model. Each Read Model has one or more Projectors.

```go
// Projector for DataAssetListItem — updates the list view when assets change
type DataAssetListProjector struct {
    store ReadModelStore
}

func (p *DataAssetListProjector) Project(ctx context.Context, event domain.DomainEvent) error {
    switch e := event.(type) {
    case domain.DataAssetRegistered:
        return p.store.UpsertListItem(ctx, DataAssetListItem{
            ID:       e.DataAssetID,
            FilePath: e.FilePath,
            FileType: e.FileType,
        })
    case domain.DataAssetClassified:
        return p.store.UpdateSensitivity(ctx, e.DataAssetID, e.SensitivityLevel, e.OccurredAt)
    case domain.DataAssetArchived:
        return p.store.RemoveListItem(ctx, e.DataAssetID)
    }
    return nil
}
```

**Projector rules:**
- Projectors are idempotent — replaying the same event twice must produce the same Read Model state
- Projectors never issue Commands — they only read events and write Read Models
- Projectors must handle all events they care about; unrecognised events are silently ignored (not errors)
- Projectors must be replayable from event position 0 — the Read Model can always be rebuilt from the event stream

---

## Read Model Storage

Read Models are stored separately from the Write Model (Aggregate tables). Storage options:

| Option | Best for | Notes |
|---|---|---|
| PostgreSQL (separate tables) | All Read Models — default | Same database as Write Model; simple ops; consistent backup |
| PostgreSQL JSONB | Variable-structure Read Models | Flexible schema; can query into JSON |
| Redis / in-memory cache | High-frequency, low-change dashboard summaries | With TTL; use only for reads that tolerate short staleness |
| Elasticsearch | Full-text search Read Models | When search is the primary query mode |

**Default for this plugin:** PostgreSQL tables in the same database as the Aggregate tables, with a `_view` suffix convention: `data_asset_list_view`, `compliance_dashboard_view`.

---

## Read Model / API Contract Connection

Each Read Model should correspond to at most one API response shape. The Read Model struct is directly serialisable to the API response — no transformation layer between the Read Model and the JSON response.

This is intentional: if the API response requires significant transformation of the Read Model, the Read Model is wrongly shaped. Reshape the Read Model (at projection time, not query time) instead of adding a transformation layer.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Never queried from Aggregate tables | Read Models are built from events, not from Aggregate table joins | Read Model built with `SELECT * FROM aggregates JOIN ...` |
| Event-sourced projectors | Every Read Model has a defined Projector with handled events | Read Models updated by Command handlers directly |
| Idempotent projectors | Replaying the same event twice produces the same Read Model state | Projectors that append rather than upsert |
| Replayable | Read Model can be fully rebuilt from the event stream from position 0 | Read Models that cannot be rebuilt (missing projector coverage) |
| One shape per Read Model | Each Read Model maps to one API response shape | Read Models that require query-time transformation |
| Storage named | Read Model storage table is named and defined | Undocumented Read Model storage |

---

## Output Format

```markdown
---
artifact: read-model-design
product: [product name]
bounded-context: [context name]
version: 1.0.0
phase: design
created: [date]
owner: domain-modeler
---

# Read Model Design: [Bounded Context Name]

## Read Models Summary

| Read Model | Type | Storage | API Endpoint | Projector Events |
|---|---|---|---|---|

---

## Read Model: [Name]

**Type:** [List view / Detail view / Aggregate view]
**Storage:** [Table name and database]
**API endpoint:** `GET [path]`

**Go struct:**
```go
type [ReadModelName] struct { ... }
```

**Projector:**
| Domain Event | Action on Read Model |
|---|---|

**Rebuild procedure:**
[How to rebuild this Read Model from the event stream if it becomes corrupted or needs migration]

[Repeat for each Read Model]
```
