# Read Model Format Reference

This file is the authoritative template for the Read Model Design artifact — the design document produced
during the Design phase. It is self-contained: use it without the parent SKILL.md in context.

---

## Artifact Format — Design Document Fields

A Read Model design document is one Markdown artifact per Bounded Context. It carries frontmatter
identifying the bounded context and product, then a summary table followed by one section per Read Model.

### Required Frontmatter

```markdown
---
name: read-model-design
product: [product name from sdlc-config.json]
bounded-context: [bounded context name]
version: 1.0.0
phase: design
created: [ISO date]
owner: domain-modeler
---
```

### Summary Table

Every document opens with a summary table listing every Read Model in the bounded context:

```markdown
## Read Models Summary

| Read Model | Type | Storage table | API endpoint | Projector events |
|---|---|---|---|---|
| DataAssetListItem | List view | data_asset_list_view | GET /data-assets | DataAssetRegistered, DataAssetClassified, DataAssetArchived |
| DataAssetView | Detail view | data_asset_detail_view | GET /data-assets/{id} | DataAssetRegistered, DataAssetClassified, StorageSourceConfirmed |
| ComplianceDashboard | Aggregate view | compliance_dashboard_view | GET /compliance/dashboard | DataAssetClassified, ComplianceGapDetected, ComplianceGapResolved |
```

### Per-Read-Model Section

Each Read Model gets its own section with the following required fields:

```markdown
## Read Model: [Name]

**Type:** List view | Detail view | Aggregate view
**Storage:** PostgreSQL table `[table_name]` in the `[bounded_context]` database schema
**API endpoint:** `GET [path]`
**Staleness tolerance:** [1–5 s / minutes / zero — see SKILL.md staleness table]
**Source Aggregate:** [Aggregate name that owns the events this Read Model projects]
**Source events:** [comma-separated list of Domain Event names that update this Read Model]

### Fields

| Field | Type | Source | Denormalized from |
|---|---|---|---|
| id | uuid.UUID | DataAsset.ID | — |
| tenantID | uuid.UUID | DataAsset.TenantID | — |
| filePath | string | DataAsset.FilePath | — |
| fileType | string | DataAsset.FileType | — |
| sensitivityLevel | string | DataAssetClassified.SensitivityLevel | — |
| storageSourceName | string | StorageSourceConfirmed.Name | StorageSource.Name (denormalized) |
| lastClassifiedAt | *time.Time | DataAssetClassified.OccurredAt | — |
| entityCount | int | DataAssetClassified.ExtractedEntityCount | — |
| version | int64 | DataAsset.Version | Aggregate version counter |
| updatedAt | time.Time | event.OccurredAt | — |

### Update Trigger

| Event | Action |
|---|---|
| DataAssetRegistered | INSERT row with filePath, fileType; sensitivityLevel = "Unclassified" |
| DataAssetClassified | UPDATE sensitivityLevel, lastClassifiedAt, entityCount, version, updatedAt |
| DataAssetArchived | DELETE row |
| StorageSourceConfirmed | UPDATE storageSourceName WHERE storageSourceID matches |

### Rebuild Procedure

See `references/consistency-patterns.md` § "Rebuild With Shadow Table" for the full procedure.
Summary: project from position 0 into `data_asset_list_view_rebuild`, swap names in one transaction.
```

---

## Storage Options

Read Models are stored separately from Write Model (Aggregate) tables.

| Option | Best for | Notes |
|---|---|---|
| PostgreSQL (separate tables) | All Read Models — default | Same database schema as Write Model; simple ops; consistent backup; `pgx` scanning |
| PostgreSQL JSONB column | Variable-structure sub-fields (tags, metadata, compliance flags) | Use for columns whose schema may vary per-row; can query into JSON with `->` and `@>` |
| Redis (in-memory, TTL-keyed) | High-frequency, low-change dashboard summaries | With TTL; use only for reads that tolerate short staleness; not a replacement for a PostgreSQL Read Model |
| Elasticsearch | Full-text search Read Models | When the primary query mode is text search over large corpora, not key/filter lookups |

**Default for this plugin:** PostgreSQL tables in the same database as the Aggregate tables.

Table naming convention: `<snake_case_aggregate>_<view_type>_view`

Examples:
- `data_asset_list_view` — list view for DataAsset
- `data_asset_detail_view` — detail view for DataAsset
- `compliance_dashboard_view` — aggregate summary for the compliance domain

Each Read Model table lives in the same PostgreSQL schema as the Aggregate tables for that Bounded Context.
There is no shared "read" schema — each service owns its Read Model tables alongside its Aggregate tables.

---

## Worked Example — DataAssetView (Detail View)

This example shows a complete Read Model design for the `DataAssetView` — the detail Read Model used by
`GET /data-assets/{id}`. It is grounded in the DataAssetManagement Bounded Context.

### Document Section

```markdown
## Read Model: DataAssetView

**Type:** Detail view
**Storage:** PostgreSQL table `data_asset_detail_view` in the `data_asset_management` schema
**API endpoint:** `GET /data-assets/{id}`
**Staleness tolerance:** 1–5 seconds (user-facing interactive)
**Source Aggregate:** DataAsset
**Source events:** DataAssetRegistered, DataAssetClassified, StorageSourceConfirmed, ExtractedEntitiesUpdated, DataAssetArchived

### Fields

| Field | Type | Source | Denormalized from |
|---|---|---|---|
| id | uuid.UUID | DataAsset.ID | — |
| tenantID | uuid.UUID | DataAsset.TenantID | — |
| filePath | string | DataAssetRegistered.FilePath | — |
| fileType | string | DataAssetRegistered.FileType | — |
| fileSizeBytes | int64 | DataAssetRegistered.FileSizeBytes | — |
| sensitivityLevel | string | DataAssetClassified.SensitivityLevel | — |
| classifiedBy | string | DataAssetClassified.ClassifiedBy | — |
| classifiedAt | *time.Time | DataAssetClassified.OccurredAt | — |
| storageSourceID | uuid.UUID | DataAssetRegistered.StorageSourceID | — |
| storageSourceName | string | StorageSourceConfirmed.Name | StorageSource (denormalized) |
| storageSourceType | string | StorageSourceConfirmed.SourceType | StorageSource (denormalized) |
| extractedEntities | JSONB | ExtractedEntitiesUpdated.Entities | Array of {type, value, confidence} |
| complianceFlags | JSONB | DataAssetClassified.ComplianceFlags | Array of {framework, flagType, severity} |
| version | int64 | DataAsset.Version | Aggregate version counter |
| createdAt | time.Time | DataAssetRegistered.OccurredAt | — |
| updatedAt | time.Time | latest event OccurredAt | — |

### Update Trigger

| Event | Action |
|---|---|
| DataAssetRegistered | INSERT row with filePath, fileType, fileSizeBytes, storageSourceID; sensitivity = "Unclassified" |
| DataAssetClassified | UPDATE sensitivityLevel, classifiedBy, classifiedAt, complianceFlags, version, updatedAt |
| StorageSourceConfirmed | UPDATE storageSourceName, storageSourceType WHERE storageSourceID matches |
| ExtractedEntitiesUpdated | UPDATE extractedEntities JSONB column, version, updatedAt |
| DataAssetArchived | DELETE row (or mark archived if soft-delete is required for audit purposes) |

### Staleness Handling

After a classify Command completes, the Command handler returns the new Aggregate `version`.
The client polls `GET /data-assets/{id}` and inspects the `X-Applied-Version` response header
until `appliedVersion >= expectedVersion` — see `references/consistency-patterns.md` for the full pattern.
```

---

## Output Format Template (Copy-Paste Ready)

The following template is the complete artifact shell. Copy it when creating a new Read Model design artifact.

```markdown
---
name: read-model-design
product: [product name]
bounded-context: [context name]
version: 1.0.0
phase: design
created: [date]
owner: domain-modeler
---

# Read Model Design: [Bounded Context Name]

## Read Models Summary

| Read Model | Type | Storage table | API endpoint | Projector events |
|---|---|---|---|---|

---

## Read Model: [Name]

**Type:** [List view / Detail view / Aggregate view]
**Storage:** PostgreSQL table `[table_name]`
**API endpoint:** `GET [path]`
**Staleness tolerance:** [1–5 s / minutes / zero]
**Source Aggregate:** [Aggregate name]
**Source events:** [comma-separated Domain Event names]

### Fields

| Field | Type | Source | Denormalized from |
|---|---|---|---|

### Update Trigger

| Event | Action |
|---|---|

### Rebuild Procedure

[Reference to consistency-patterns.md shadow-table procedure, with table name filled in]

---

[Repeat for each Read Model]
```
