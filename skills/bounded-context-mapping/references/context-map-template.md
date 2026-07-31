# Context Map Template
## Diagram Conventions, Notation, and Worked Multi-BC Example

Self-contained reference for the `bounded-context-mapping` skill. Use this when drawing or
reviewing a Context Map for any product.

---

## What the Context Map Shows

A Context Map is a system-level diagram showing:
1. Every Bounded Context as a named box
2. Every integration relationship between contexts as a directed arrow
3. The named relationship pattern for each arrow
4. The upstream/downstream direction for each connection

The Context Map is the primary input to two downstream decisions:
- **Service decomposition** — each BC box is a candidate deployable service
- **Integration design** — each arrow becomes an implementation decision (which pattern, which
  transport, which schema)

The Context Map is not a deployment diagram and not a sequence diagram. It shows the *structure*
of the model and the obligations between models, not message flows or call sequences.

---

## Diagram Conventions

### Box notation
Each Bounded Context is a labelled rectangle:

```
┌─────────────────────────────────┐
│  DataAsset Management           │
│  (Core)                         │
│  owns: DataAsset, StorageSource  │
│         ExtractionJob            │
└─────────────────────────────────┘
```

Include:
- Context name (Ubiquitous Language noun phrase)
- Strategic classification in parentheses: (Core), (Supporting), or (Generic)
- A brief list of owned Aggregates

### Arrow notation
Arrows point **downstream** — in the direction of dependency.

```
Upstream ──[pattern label]──▶ Downstream
```

The upstream context is the **producer** or **authority**; the downstream context is the
**consumer** or **dependent**. The downstream depends on the upstream, not the other way around.

In a Customer/Supplier relationship:
- The **Supplier** is upstream
- The **Customer** is downstream
- The Customer drives the Supplier's interface (via Consumer-Driven Contracts)

### Pattern labels
Label each arrow with the pattern name, abbreviated:

| Pattern | Abbreviation |
|---|---|
| Anti-Corruption Layer | ACL |
| Open Host Service | OHS |
| Published Language | PL |
| Customer/Supplier | C/S |
| Conformist | CONF |
| Shared Kernel | SK |
| Partnership | PART |
| Separate Ways | SW |
| Big Ball of Mud | BBOM |

When OHS and PL are both in play (common for event-driven internal integrations), label the
arrow `OHS/PL`.

### ACL placement
When a downstream context uses an ACL, the ACL itself is a component inside the downstream
context — it is not a separate box on the Context Map. Annotate the downstream box:

```
┌──────────────────────────────────────────┐
│  Compliance Intelligence  (Core)          │
│  [ACL: Google Drive Adapter]              │  ← indicates ACL exists here for external system
│  owns: ComplianceGap, AuditRecord         │
└──────────────────────────────────────────┘
```

The ACL is implementation detail — it belongs in the service-decomposition reference, not in
the Context Map diagram itself.

---

## Worked Example: Data Estate Mapping & Compliance Intelligence Platform

This Context Map covers four Bounded Contexts identified for the first product engagement.

### Full Context Map Diagram

```
                         [External Systems]
    ┌─────────────┐    ┌────────────────┐    ┌──────────────────┐
    │ Google Drive │    │    AWS S3      │    │  Office 365 /    │
    │  API         │    │    API         │    │  SharePoint API  │
    └──────┬───────┘    └───────┬────────┘    └────────┬─────────┘
           │ ACL                │ ACL                  │ ACL
           ▼                    ▼                      ▼
    ┌────────────────────────────────────────────────────────────┐
    │  DataAsset Management                      (Core)          │
    │                                                            │
    │  Owned Aggregates: DataAsset, StorageSource, ExtractionJob │
    │  [ACL: GDrive Adapter, S3 Adapter, O365 Adapter]          │
    └────────┬─────────────────────┬──────────────────┬──────────┘
             │ OHS/PL              │ OHS/PL           │ OHS/PL
             │ (events)            │ (events)         │ (events)
             ▼                     ▼                   ▼
    ┌──────────────────┐   ┌───────────────────┐  ┌───────────────────┐
    │  Compliance      │   │  Graph Context    │  │  Reporting        │
    │  Intelligence    │   │  (Supporting)     │  │  (Supporting)     │
    │  (Core)          │   │                   │  │                   │
    │                  │   │  Aggregates:      │  │  Aggregates:      │
    │  Aggregates:     │   │  EntityRelation   │  │  ReportDefinition │
    │  ComplianceGap   │◀──│  ship,            │  │                   │
    │  AuditRecord     │C/S│  KnowledgeGraph   │  │  [Read Models     │
    │  ClassificationR │   │                   │  │   from DataAsset  │
    │  ule             │   └───────────────────┘  │   Management and  │
    └──────────────────┘                          │   Compliance      │
                                                  │   Intelligence]   │
                                                  └───────────────────┘

Legend:
  ──▶       Downstream dependency (arrow points to consumer / downstream)
  ACL       Anti-Corruption Layer protects downstream from upstream model
  OHS/PL    Open Host Service + Published Language (event topics, schema registry)
  C/S       Customer/Supplier with Consumer-Driven Contracts
```

### Relationship Detail Table

| Upstream Context | Downstream Context | Pattern | Implementation note |
|---|---|---|---|
| Google Drive API | DataAsset Management | ACL | `internal/infrastructure/gdrive/` translates `File` → `StorageSourceItem` Value Object; domain never sees Drive types |
| AWS S3 API | DataAsset Management | ACL | `internal/infrastructure/s3/` translates `Object` → `StorageSourceItem` |
| Office 365 API | DataAsset Management | ACL | `internal/infrastructure/o365/` translates `DriveItem` → `StorageSourceItem` |
| DataAsset Management | Compliance Intelligence | OHS/PL | Emits `DataAssetRegistered`, `DataAssetClassified`, `DataAssetArchived` on Redpanda topics; schemas in schema registry |
| DataAsset Management | Graph Context | OHS/PL | Emits `DataAssetClassified`; Graph builds knowledge graph from classification events |
| DataAsset Management | Reporting | OHS/PL | Emits all events; Reporting projects Read Models for dashboards |
| Graph Context | Compliance Intelligence | C/S | Graph is Supplier — Compliance Intelligence is Customer; CDC test enforces the `EntityRelationshipCreated` event schema |

---

## Pattern-by-Pattern Notation Guide

### Anti-Corruption Layer (ACL)

```
[External / Legacy Context] ──ACL──▶ [Internal Context]
                                      [ACL lives here, inside the downstream]
```

The ACL is the downstream context's own protective translation layer. It translates the
upstream's model into the downstream's Ubiquitous Language. The upstream never knows an ACL
exists. In Go:

```go
// internal/infrastructure/gdrive/adapter.go
// The ACL: translates Google Drive API types into domain Value Objects.
// Nothing outside this package ever imports a Google Drive type.

package gdrive

import (
    "google.golang.org/api/drive/v3"
    "github.com/org/product/internal/domain/dataasset"
)

// ToStorageSourceItem converts a Drive File into a domain Value Object.
// This is the ACL translation boundary.
func ToStorageSourceItem(f *drive.File) dataasset.StorageSourceItem {
    return dataasset.StorageSourceItem{
        ExternalID:   f.Id,
        Name:         f.Name,
        MimeType:     f.MimeType,
        SizeBytes:    f.Size,
        LastModified: parseRFC3339(f.ModifiedTime),
    }
}
```

### Open Host Service + Published Language (OHS/PL)

The upstream context publishes events on a well-defined Redpanda topic using a schema registered
in the schema registry. Any downstream context can consume without negotiating privately:

```
[Upstream Context] ──OHS/PL──▶ [schema registry] ──▶ [Any downstream]
                    (topic: dataasset.classified.v1)
```

The OHS is the upstream's commitment to maintain the schema. The PL is the schema itself —
every consumer validates against it. Breaking schema changes require a new topic version
(`dataasset.classified.v2`), with the v1 topic maintained until all consumers migrate.

### Customer/Supplier (C/S)

```
[Supplier context] ──C/S──▶ [Customer context]
                    CDC test enforces contract
```

The Customer drives the Supplier's interface. The Customer writes the contract test; the
Supplier's CI pipeline runs it. If the Supplier breaks the contract, its CI fails. See
`context-map-patterns` and `go-contract-test` for implementation details.

---

## How the Context Map Feeds Downstream Skills

The completed Context Map is the primary input to:

- **`context-map-patterns`** — the detailed implementation guide for each named relationship
  pattern; read it after the Context Map is agreed to implement each arrow.
- **`references/service-decomposition.md`** — translates BC boxes into deployable services;
  read it after the Context Map to produce the service inventory.
- **`aggregate-design`** — each BC box identifies which Aggregates belong inside; read it to
  design the Aggregates that the BC definition artifact named.
- **`go-contract-test`** — each C/S arrow becomes a Consumer-Driven Contract test; read it to
  implement the contract between Customer and Supplier.

The Context Map is a living artifact. Update it whenever a new BC is discovered, a BC boundary
is moved, or a relationship pattern changes. A stale Context Map is worse than no Context Map
— teams will build on the wrong mental model.
