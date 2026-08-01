---
name: cqrs-pattern
description: >
  Teaches the backend-engineer to select the appropriate CQRS variant for a
  service and implement the Write/Read model separation — covering the three
  CQRS variants (Simple Read Model, Full CQRS, Event-Sourced CQRS) with
  explicit selection criteria, the projection update mechanics (synchronous vs.
  event-driven vs. CDC-driven), consistency trade-offs, Go implementation
  patterns for command handlers and projectors, and the integration points with
  domain-event-catalog and read-model-design. Used during Implement when a
  service requires independent scaling of reads and writes or event sourcing.
version: 2.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: ["implement","cqrs","read-model","write-model","projections","event-sourcing","domain-modeling"]
produces: cqrs-design
domain: domain-modeling
status: stable
related: [domain-event-catalog, read-model-design, subdomain-distillation, aggregate-design, go-domain-model]
---

# CQRS Pattern

## What CQRS Is

Command Query Responsibility Segregation (CQRS, Greg Young) separates the **Write Model** (how state changes) from the **Read Model** (how state is queried). A Command mutates state and returns no data. A Query reads state and changes nothing.

This separation allows the write and read sides to be optimised independently, prevents query complexity from bleeding into the domain model, and enables multiple Read Models each optimised for a different query — without affecting Aggregate design.

**CQRS is independent of Event Sourcing.** The default in this plugin is current-state Aggregates (a standard PostgreSQL table) that emit Domain Events via the Transactional Outbox. Projectors consume those events to build Read Models. Event Sourcing (state derived from event stream replay) is a third, optional escalation — see `references/cqrs-variants.md`.

---

## Three CQRS Variants

Khononov identifies CQRS as a spectrum, not a binary choice. Select the variant per service based on the trade-off below.

| Variant | Description | Primary Selection Criterion |
|---|---|---|
| **Simple Read Model** | Same DB, separate query layer — a dedicated query function that joins write tables through a read-side type (never the Aggregate itself) | Default when write/read scaling is modest and query shapes have not diverged significantly |
| **Full CQRS** | Separate DBs, event-driven projection — Projectors subscribe to Domain Events and upsert into dedicated Read Model tables | Use when read/write scaling differs significantly, multiple consumers need the same data in different shapes, or the Bounded Context already emits Domain Events |
| **Event-Sourced CQRS** | Aggregate state derived from event stream replay; projections built from the same stream | Use when audit-trail reconstruction at an arbitrary past point in time is required, new Read Models must be built retroactively from existing history, or the event stream must be the authoritative compliance record |

> **Khononov's caution:** Simple Read Model is a legitimate starting point, not an anti-pattern. Escalate to Full CQRS when measured need arrives — not by default.

Full decision table (infrastructure requirements, consistency guarantees, when not to use, worked examples from this repo, and how Khononov's four Business Logic Design Patterns map to each variant) is in `references/cqrs-variants.md`.

---

## Key Trade-offs

| Axis | Simple Read Model | Full CQRS | Event-Sourced CQRS |
|---|---|---|---|
| Consistency | Immediate | Eventual | Eventual |
| Write throughput | Shared with reads | Independent | Independent |
| Infrastructure cost | Low | Medium (broker + projectors) | High (event store, snapshotting, upcasting) |
| Rebuild capability | No | Yes — replay events | Yes — replay event stream |
| Audit trail | Separate log needed | Domain Events are the record | Event stream is the authoritative record |

---

## Selection Inputs

Before selecting a variant, consult:
- **`domain-event-catalog`** — confirms which Domain Events this service emits. Full CQRS requires events; if they do not exist, adopting Full CQRS also means creating them.
- **`read-model-design`** — the Read Model shapes are the primary input to projector design. A Read Model that requires significant transformation at query time is shaped incorrectly; fix the projection, not the query handler.
- **`subdomain-distillation`** — for Generic or simple Supporting subdomains, evaluate Khononov's four Business Logic Design Patterns (Transaction Script, Active Record, Domain Model, Event-Sourced Domain Model) before defaulting to Full CQRS. See `references/cqrs-variants.md`.

---

## Write Side

```
HTTP Request
     ↓
API Handler — structural validation, maps DTO → Command struct
     ↓
Command Handler (application/commands/)
  — idempotency check
  — load Aggregate from Repository
  — call Aggregate method (invariant enforcement)
  — save Aggregate (state + outbox events in one transaction)
     ↓
Repository (infrastructure/postgres/)
  — BEGIN transaction
  — UPDATE aggregate table
  — INSERT into outbox_events
  — COMMIT
```

Command handlers return no domain data — only `error`, plus (at most) the new Aggregate ID and version for `201` responses. The application layer split is absolute:

```
application/
├── commands/    ← one handler per Command
└── queries/     ← one handler per Query
```

Go code for command handlers, idempotency enforcement, and the Repository interface pattern is in `references/go-implementation.md`.

---

## Read Side

```
Outbox Relay → Redpanda → Projector (infrastructure/projectors/)
                                ↓
                       Read Model Store (PostgreSQL — separate tables)
                                ↓
                       Query Handler (application/queries/)
                                ↓
                       API Handler → HTTP response DTO
```

Projector update mechanics — synchronous (same transaction as write), event-driven (subscribe to broker), and CDC-driven (Debezium reads WAL) — with idempotency requirements and Go implementation sketches are in `references/projection-patterns.md`.

---

## When to Apply CQRS

| Apply | Reason |
|---|---|
| Read and write loads are significantly different | Write: low volume, complex; Read: high volume, simple |
| Multiple Read Models needed from the same domain data | Dashboard view ≠ detail view ≠ search index |
| Bounded Context already emits Domain Events | Events already produced — projecting them is low marginal cost |
| Audit trail is required | Domain Events from the write side are the audit trail |
| Domain model is complex | CQRS keeps query complexity from polluting the Aggregate |

| Skip or simplify | Reason |
|---|---|
| Simple CRUD with no domain logic | Overhead exceeds the benefit |
| Read and write patterns are identical | No benefit from separate optimisation |
| Single consumer of the data | One Read Model = one query = Full CQRS is overkill |
| Generic or simple Supporting subdomain | Consider Transaction Script or Active Record first |

For this plugin's first product: Full CQRS applies to all core Bounded Contexts (Storage Integration, Classification, Compliance Intelligence, Graph). Simple support Bounded Contexts (user management, configuration) may use the Simple Read Model variant or a plain repository pattern.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Command returns no data | `error` + (optionally) new ID and version | Command returns updated Aggregate state or a query result |
| Query changes no state | Query handler calls no Aggregates; performs no writes | Query handler with a side effect |
| Separate packages | `application/commands/` and `application/queries/` are distinct | Mixed file with both commands and queries |
| Read Models from events | Read Models built by Projectors consuming Domain Events | Read Models built by querying Aggregate tables directly |
| Domain interface for repo | Repository interface in `domain/ports.go` | Repository interface in `infrastructure/` |
| Idempotency in command handler | All command handlers check idempotency before processing | Command handler with no idempotency check |
| Idempotency in projector | Projectors are idempotent — safe to process the same event twice | Projector with no dedup or version check |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Full CQRS everywhere** — for trivial CRUD contexts | Projectors, outbox rows, and eventual consistency are overhead where one model suffices | Apply "When to Apply CQRS" honestly; start with Simple Read Model |
| **Guards against Read Models** — command validates against a projection | Projection lags Write Model; guard races reality on stale data | Invariants enforced inside Aggregate against transactionally-loaded state |
| **Command handler with a query habit** — returning view data from the write path | Write path inherits read-side performance and shape concerns | Return only error / new ID and version |
| **Query with a side effect** — "just bump the view counter while reading" | Reads become non-repeatable and non-cacheable | Queries change nothing; if domain cares about views, that is a Command emitting a Domain Event |
| **Synchronous projection in the command transaction** — updating Read Model tables alongside the Aggregate write | Couples every view's schema and latency to the write path | Projectors consume events post-commit via Transactional Outbox and broker |
| **CQRS assumed to mean Event Sourcing** — dropping the state table because events exist | Event Sourcing's replay, snapshotting, and upcasting costs arrive uninvited | Current-state Aggregates by default; adopt Event-Sourced CQRS via an explicit ADR |
| **One handler class for everything** — `DataAssetService` with both commands and queries | Dependencies of both sides accumulate; separation exists only in method names | One handler per Command and per Query |

---

## Output Format

```markdown
## CQRS Design: [Service Name]

### Variant Selected
[Simple Read Model / Full CQRS / Event-Sourced CQRS] — [one-sentence rationale]

### Write Side
| Command | Handler | Aggregate method | Repository save | Event emitted |
|---|---|---|---|---|

### Read Side
| Read Model | Projector | Projection mechanic | Storage table | Query handler |
|---|---|---|---|---|

### Application Layer Structure
[Directory tree for application/commands/ and application/queries/]

### CQRS Applicability Decision
[Rationale for applying or not applying full CQRS to this service]
```
