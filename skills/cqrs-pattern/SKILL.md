---
name: cqrs-pattern
description: >
  Teaches how to apply Command Query Responsibility Segregation (CQRS) within
  a service — covering the write model (Commands → Aggregates → Domain Events),
  the read model (Domain Events → Projectors → Read Models), the application
  layer separation, Go implementation patterns for command handlers and query
  handlers, and when CQRS is appropriate vs when it adds unnecessary complexity.
  Companion to the domain-event-catalog and read-model-design skills. Used by
  the enterprise-architect and backend-engineer agents.
version: 1.1.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, cqrs, write-model, read-model, event-sourcing, go]
---

# CQRS Pattern

## Purpose

Command Query Responsibility Segregation (CQRS, Greg Young) separates the write model (how state is changed) from the read model (how state is queried). In a CQRS system, a Command mutates state and returns no data; a Query reads state and changes nothing.

This separation:
- Allows the write and read sides to be optimised independently
- Prevents query complexity from bleeding into the domain model
- Enables multiple Read Models (each optimised for its query) without affecting the Aggregate design
- Is the natural complement to Domain Events: events flow from the write side to the read side

---

## CQRS is Not Event Sourcing

CQRS and Event Sourcing are often discussed together but are independent patterns:

| Pattern | What it is | Required by the other? |
|---|---|---|
| **CQRS** | Separate write and read models | No — CQRS can be used without event sourcing |
| **Event Sourcing** | The Aggregate's state is derived entirely from its event history; no state table | No — event sourcing can exist without CQRS, but they are highly complementary |

**This plugin uses CQRS by default.** Event Sourcing is an option for specific Bounded Contexts where full event history replay is required (e.g., audit trail reconstruction), but it is not the default — it adds significant complexity.

The default approach: Aggregates store state in a standard PostgreSQL table, emit Domain Events via the Transactional Outbox, and Projectors build Read Models from those events.

---

## The Write Side

### Flow

```
HTTP Request
     ↓
API Handler (handlers/)
  - Structural validation
  - Map request DTO → Command struct
     ↓
Command Handler (application/commands/)
  - Check idempotency
  - Load Aggregate from Repository
  - Call Aggregate method (business rule enforcement)
  - Save Aggregate to Repository (includes writing to outbox_events)
  - Return result
     ↓
Repository (infrastructure/postgres/)
  - BEGIN transaction
  - UPDATE aggregate table
  - INSERT into outbox_events
  - COMMIT
```

### Command Handler Pattern (Go)

```go
type ClassifyDataAssetHandler struct {
    repo       domain.DataAssetRepository
    commandLog CommandLog
}

func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd domain.ClassifyDataAsset) error {
    // Idempotency check
    if err := h.commandLog.CheckAndRecord(ctx, cmd.IdempotencyKey); err != nil {
        return err // already processed
    }

    // Load aggregate
    asset, err := h.repo.FindByID(ctx, cmd.DataAssetID)
    if err != nil {
        return fmt.Errorf("loading data asset: %w", err)
    }

    // Domain operation (enforces invariants, collects events)
    if err := asset.Classify(cmd); err != nil {
        return err // domain error — business rule violated
    }

    // Save (aggregate state + outbox events in one transaction)
    return h.repo.Save(ctx, asset)
}
```

### Repository Interface (domain/)

```go
type DataAssetRepository interface {
    FindByID(ctx context.Context, id DataAssetID) (*DataAsset, error)
    Save(ctx context.Context, asset *DataAsset) error
}
```

The Repository interface is defined in the domain layer. The PostgreSQL implementation is in the infrastructure layer. The Command Handler depends only on the interface — not the implementation (Dependency Inversion).

---

## The Read Side

### Flow

```
Outbox Relay
  - Reads from outbox_events (WHERE published = false)
  - Publishes to Redpanda
     ↓
Projector (infrastructure/projectors/)
  - Consumes from Redpanda consumer group
  - Calls ReadModelStore.Upsert/Update/Delete based on event type
     ↓
Read Model Store (PostgreSQL — separate tables from aggregate tables)
     ↓
Query Handler (application/queries/)
  - Queries Read Model Store
  - Returns Read Model struct
     ↓
API Handler (handlers/)
  - Maps Read Model struct → HTTP response DTO
```

### Query Handler Pattern (Go)

```go
type GetDataAssetDetailHandler struct {
    store DataAssetReadStore
}

func (h *GetDataAssetDetailHandler) Handle(ctx context.Context, query GetDataAssetDetail) (*DataAssetDetail, error) {
    detail, err := h.store.FindDetail(ctx, query.DataAssetID, query.TenantID)
    if err != nil {
        return nil, err
    }
    return detail, nil
}
```

Query handlers are intentionally simple. The complexity lives in the Projector (which builds the Read Model) and in the Read Model store's index design. The query handler just retrieves the pre-built result.

---

## When to Apply CQRS

CQRS adds complexity. Apply it where the benefits are worth the cost:

| Apply CQRS | Reason |
|---|---|
| Read and write loads are significantly different | Write: low volume, complex; Read: high volume, simple |
| Multiple Read Models needed from the same domain data | Dashboard view ≠ detail view ≠ search index |
| Bounded Context emits Domain Events to other contexts | Events are already being produced — projecting them into Read Models is low marginal cost |
| Audit trail is required | The event stream from the write side is the audit trail |
| The domain model is complex | CQRS keeps query complexity from polluting the domain model |

| Skip CQRS | Reason |
|---|---|
| Simple CRUD with no domain logic | The overhead exceeds the benefit |
| Read and write patterns are identical | No benefit from separate optimisation |
| Single consumer of the data | One Read Model = one query = CQRS is overkill |
| Team is small and delivery speed is the constraint | Simpler architecture may be the right trade-off |

For this plugin's first product, CQRS applies to all core Bounded Contexts (Storage Integration, Classification, Compliance Intelligence, Graph). Simple support Bounded Contexts (user management, configuration) may use a simpler repository pattern without full CQRS.

---

## Application Layer Separation

The Application layer has two clearly separated sections:

```
application/
├── commands/
│   ├── classify_data_asset.go      ← ClassifyDataAssetHandler
│   ├── connect_storage_source.go   ← ConnectStorageSourceHandler
│   └── trigger_estate_scan.go      ← TriggerEstateScanHandler
└── queries/
    ├── get_data_asset_detail.go    ← GetDataAssetDetailHandler
    ├── list_data_assets.go         ← ListDataAssetsHandler
    └── get_compliance_dashboard.go ← GetComplianceDashboardHandler
```

No file crosses the boundary. A command handler never queries a Read Model store. A query handler never calls an Aggregate.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Command returns no data | Command handlers return no domain data — an `error`, plus at most the new Aggregate ID and version (for `201` responses and read-your-own-writes) | Command handler returns the updated Aggregate state or a query result |
| Query changes no state | Query handlers call no Aggregates; perform no writes | Query handler with a side effect |
| Separate packages | `application/commands/` and `application/queries/` are distinct packages | Mixed file with both commands and queries |
| Read Models from events | Read Models built by Projectors consuming Domain Events | Read Models built by querying Aggregate tables directly |
| Domain interface for repo | Repository interface in `domain/ports.go` | Repository interface in `infrastructure/` |
| Idempotency in command handler | All command handlers check idempotency before processing | Command handlers with no idempotency check |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **CQRS everywhere** — full write/read separation for trivial CRUD contexts | Projectors, outbox rows, and eventual consistency are pure overhead where one model would do | Apply the "When to Apply CQRS" table honestly; support contexts may use a plain repository |
| **Guards checked against Read Models** — a command handler validating against a projection | The projection lags the Write Model; the guard races reality and passes on stale data | Invariants are enforced inside the Aggregate against transactionally-loaded state |
| **Command handler with a query habit** — returning view data from the write path | The write path inherits read-side performance and shape concerns; the separation dissolves | Return only the error / new ID and version; the client queries a Read Model |
| **Query with a side effect** — "just bump the view counter while reading" | Reads become non-repeatable and non-cacheable; load tests mutate production state | Queries change nothing; if the domain cares about views, that is a Command emitting a Domain Event |
| **Synchronous projection in the command transaction** — updating Read Model tables alongside the Aggregate write | Couples every view's schema and latency to the write path; rebuild-from-events is no longer true | Projectors consume events after commit via the Transactional Outbox and broker |
| **CQRS assumed to mean Event Sourcing** — dropping the state table because events exist | Event Sourcing's replay, snapshotting, and versioning costs arrive uninvited | Keep state-stored Aggregates by default; adopt Event Sourcing per Bounded Context via an ADR |
| **One handler class for everything** — `DataAssetService` exposing both commands and queries | Dependencies of both sides accumulate in one type; the separation exists only in method names | One handler per Command and per Query, in `application/commands/` and `application/queries/` |

---

## Output Format

This skill produces design notes that are incorporated into the Component Diagram and the service design artifact:

```markdown
## CQRS Design: [Service Name]

### Write Side
| Command | Handler | Aggregate method | Repository save | Event emitted |
|---|---|---|---|---|

### Read Side
| Read Model | Projector | Source events | Storage table | Query handler |
|---|---|---|---|---|

### Application Layer Structure
[Directory tree for application/commands/ and application/queries/]

### CQRS Applicability Decision
[Rationale for applying or not applying full CQRS to this service]
```
