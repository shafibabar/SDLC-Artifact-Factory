---
name: read-model-design
description: "Teaches the domain-modeler and backend-engineer to design Read Models — the denormalized, query-optimized representations of Aggregate state produced by projections from Domain Events. Covers Read Model field selection (what to include from the Aggregate and related context), denormalization strategy (when and how to flatten nested structures), eventual consistency management (version fields, staleness tolerance, client-side handling), the Read Model artifact format, and naming conventions. Used during Design whenever a service exposes query endpoints that must return pre-computed, caller-optimized shapes."
version: 2.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: ["design","domain-modeling","cqrs","read-model","projections","denormalization","query-optimization"]
related: [cqrs-pattern, domain-event-catalog, aggregate-design, go-repository-pattern, data-model-design]
---

# Read Model Design

## What a Read Model Is

A Read Model is a denormalized, query-purpose-specific projection of write-side state. It is never built by querying Aggregate tables directly. It is built by projecting Domain Events into a structure optimized for the query it serves. This separation keeps the domain model free from query concerns and allows the read side to be optimized independently — denormalized, indexed differently, cached.

Khononov's framing: Read Models answer to query needs alone; Aggregate boundaries answer to transactional-consistency needs. The two decompositions do not need to match. A Read Model may freely combine fields sourced from several Aggregates' events; one Aggregate's events may feed multiple structurally unrelated Read Models.

---

## Read Model vs Write Model

| | Write Model (Aggregate) | Read Model (Projection) |
|---|---|---|
| **Purpose** | Enforce invariants; emit events | Serve queries; optimized for reading |
| **Normalization** | Normalized — one source of truth | Denormalized — shaped for the query |
| **Source of truth** | Yes — Aggregates own canonical state | No — rebuilt from events; replaceable |
| **Consistency** | Strongly consistent within transaction | Eventually consistent — updated async |
| **Structure** | DDD types (Entity, VO, Aggregate Root) | Simple structs; flat; JSON-serializable |
| **Mutability** | Updated by Commands through Aggregate Root | Updated by Projectors only |

---

## Field Selection Rules

Three rules govern which fields a Read Model carries:

1. **Include what the caller needs — no more.** Every field in the Read Model must be required by at least one caller. Fields added "in case they're useful later" widen every query's I/O and complicate future schema changes.

2. **Denormalize for the query — no JOINs at read time.** If the caller needs `storageSourceName`, embed it in the Read Model row instead of keeping only `storageSourceID`. Denormalization happens at projection time (when the Domain Event arrives), not at query time. The N+1 heuristic: if satisfying a query would require N+1 reads against the write model, the missing fields should be embedded in the Read Model.

3. **Carry `version` and `updatedAt` for cache busting.** Every Read Model row carries the last-applied Aggregate `version` (an integer propagated from the Aggregate's own optimistic-concurrency counter) and an `updatedAt` timestamp. These enable read-your-own-writes polling and client-side staleness detection.

See `references/denormalization-patterns.md` for embedding vs. referencing worked examples and the multi-Read-Model split heuristic.

---

## Staleness Tolerance Decision

| Consumer type | Tolerated lag | Mechanism |
|---|---|---|
| User-facing UI (interactive) | 1–5 seconds | Version-poll after a Command; stale-while-revalidate on repeat loads |
| Reporting / operational dashboards | Minutes | `AsOf` timestamp exposed in API response |
| Audit / compliance trail | Zero — no lag tolerated | Read directly from Write Model (Aggregate table); do not use a Read Model |

**Never use a Read Model for audit reads.** Projection lag and the possibility of a projector being down mean a Read Model cannot make guarantees an audit trail requires. Read directly from the Aggregate table in those cases only.

See `references/consistency-patterns.md` for version field propagation, read-your-own-writes implementation, and the rebuild procedure.

---

## Naming Conventions

- Read Model types: `<Aggregate>View` or `<Query>Result`
  - `DataAssetView` — full detail for one asset
  - `DataAssetListItem` — one row in a paginated list
  - `ComplianceDashboard` — aggregate-level summary view
- Storage tables: `<snake_case_aggregate>_<view_type>_view`
  - `data_asset_list_view`, `data_asset_detail_view`, `compliance_dashboard_view`
- Projector types: `<Aggregate><View>Projector`
  - `DataAssetListProjector`, `ComplianceDashboardProjector`

---

## One Read Model Per Query Shape

Each Read Model maps to exactly one API response shape. Do not overload a single Read Model to serve multiple callers with different field needs — each caller's distinct shape gets its own Read Model, built by its own Projector consuming the same Domain Events.

If the API response requires significant transformation of a Read Model at query time, the Read Model is wrongly shaped. Reshape the Read Model at projection time rather than adding a transformation layer.

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| Querying the Write Model for reads | Reintroduces CQRS coupling; query load shapes the domain schema | Build a Read Model projected from Domain Events |
| Command handler updates the Read Model | View cannot be rebuilt from events; handler bug corrupts both sides | Only Projectors write Read Models |
| One Read Model for all callers | Every consumer pays for every field; query-time transformation accumulates | One Read Model per query shape |
| Projector issuing Commands | Replays re-fire domain behavior; rebuilds must never change domain state | Reactions to events are Policies in the write side |
| Treating Read Model as source of truth | Projection lags and can be rebuilt; guards checked against it race reality | Invariants enforced inside the Aggregate only |
| Silent staleness | Users cannot tell "zero gaps" from "projector down six hours" | Every summary Read Model carries and exposes `AsOf` |
| Append-only projector for upsert semantics | Replay produces duplicates; idempotency broken by construction | Key the Read Model on Aggregate ID and upsert |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Event-sourced projectors | Every Read Model has a defined Projector with handled events | Read Model updated by Command handlers |
| Never queried from Aggregate tables | Built from events, not from Aggregate table joins | `SELECT * FROM aggregates JOIN ...` |
| Idempotent projectors | Replaying the same event twice produces the same state | Projectors that append rather than upsert |
| Replayable | Fully rebuildable from event stream from position 0 | Read Models that cannot be rebuilt |
| One shape per Read Model | Maps to one API response shape | Requires query-time transformation |
| Tenant scoping | Every row carries `tenant_id`; every query filters on it | Cross-tenant rows reachable through a query |
| Staleness declared | `version` and `updatedAt` on every row; `AsOf` on summary models | Rows with no freshness indicator |

---

## References

- `references/read-model-format.md` — complete Read Model artifact format (design document fields, worked `DataAssetView` example, storage options, Output Format template)
- `references/denormalization-patterns.md` — embedding vs. referencing patterns; N+1 flattening heuristic; multi-model split; list/detail/summary view Go struct examples; Aggregate boundary decoupling
- `references/consistency-patterns.md` — version field propagation from Aggregate to Read Model; read-your-own-writes polling; `AsOf` for dashboards; rebuild with shadow table; Projector position tracking; Kleppmann's eventual consistency anomalies
- `references/go-implementation.md` — pgx DDL for Read Model tables; Go repository interface; filter parameter pattern; Projector Go code; test fixture pattern
