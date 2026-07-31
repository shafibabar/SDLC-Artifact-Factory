# CQRS Variants — Full Decision Reference

Self-contained reference for the three CQRS variants. Usable without the parent SKILL.md in context.

---

## Variant 1: Simple Read Model

### What It Is

Write and read share the same database. The read side is implemented as a dedicated query function or Query Handler that joins write tables through a typed Read Model struct — the Aggregate itself is never exposed to the query path. There is no event-driven projection pipeline, no Projector service, and no Read Model storage table separate from the Aggregate's own table.

This is still CQRS: the Command and Query responsibilities are in separate code paths with separate types. The separation is architectural and type-level, not storage-level.

### When to Use

- Write/read load is modest — both are served comfortably from one PostgreSQL instance
- Query shapes are close to the Aggregate's own shape (no heavy denormalization required)
- The Bounded Context does not yet emit Domain Events (or emits them only for external integration, not for projection)
- The team is small and delivery speed is the constraint — starting light is the right call
- Khononov's Business Logic Design Pattern for this subdomain is Active Record or the simpler end of Domain Model

### When Not to Use

- Read load is 10x or more of write load and requires independent scaling
- Multiple structurally different Read Models are needed from the same Aggregate data (dashboard, detail view, search index)
- Read queries require heavy joins across many tables that would impose latency on the write path or vice versa
- Event replay/rebuild of the read side is a stated requirement

### Infrastructure Requirements

- Single PostgreSQL instance (same as the write side)
- No broker subscription required
- No separate Read Model schema

### Consistency Guarantee

Immediate — the query reads directly from the same tables the write side updates. No propagation lag.

### Worked Example (DataAssetManagement BC)

The `list-data-assets` endpoint serves a simple list view. Until load warrants a separate Read Model table, the Query Handler executes:

```sql
SELECT
    da.id,
    da.tenant_id,
    da.name,
    da.sensitivity,
    da.storage_source_id,
    da.version,
    da.created_at
FROM data_assets da
WHERE da.tenant_id = $1
ORDER BY da.created_at DESC
LIMIT $2 OFFSET $3;
```

This is scanned into a `DataAssetListItem` Go struct — not the `DataAsset` Aggregate — and returned. The Aggregate's invariant-enforcement methods are not loaded.

---

## Variant 2: Full CQRS

### What It Is

Write and read use separate databases (or at minimum separate schemas with separate connection pools). Domain Events flow from the Write Model through the Transactional Outbox to a message broker (Redpanda), where Projectors subscribe, process events, and upsert into dedicated Read Model tables. Query Handlers read only from the Read Model tables.

This is the default for Core Bounded Contexts in this plugin.

### When to Use

- Read and write scaling requirements differ significantly
- Multiple consumers need the same domain data in structurally different shapes
- The Bounded Context already emits Domain Events for external integration — projecting them is low marginal cost
- Audit trail is required — the Domain Event stream from the write side is the record
- The domain model is complex enough that query complexity would pollute the Aggregate design if shared

### When Not to Use

- The subdomain is Generic or a simple Supporting subdomain (use Transaction Script or Active Record first)
- No Domain Events are yet defined for this Bounded Context — adding them solely to enable Full CQRS is a significant investment to evaluate consciously
- The team is very small and eventual consistency in Read Models is a user-experience risk not yet budgeted for

### Infrastructure Requirements

- Two separate PostgreSQL databases (or schemas): one for Aggregates + outbox, one for Read Models
- Redpanda topic per Bounded Context for Domain Event fan-out
- Transactional Outbox relay (polls `outbox_events WHERE published = false`, publishes to Redpanda, marks rows published)
- One Projector service (or in-process goroutines) per Bounded Context consuming its own topic

### Consistency Guarantee

Eventual — Read Models lag the Write Model by the round-trip time through the outbox relay and broker. In practice: milliseconds to low seconds under normal load. User-facing flows that depend on the Read Model reflecting a just-committed write should communicate a "processing" or "pending" state rather than assume the Read Model is already updated.

### Worked Example (DataAssetManagement BC)

After `ClassifyDataAsset` command commits:
1. `data_assets` row is updated (`sensitivity = 'RESTRICTED'`, `version` incremented)
2. `outbox_events` row is inserted (`event_type = 'DataAssetClassified'`, `payload = {...}`)
3. Outbox relay publishes the event to Redpanda topic `data-asset-management.events`
4. `DataAssetProjector` consumes the event and upserts `data_asset_detail` Read Model table
5. Query Handler for `GetDataAssetDetail` reads from `data_asset_detail`

---

## Variant 3: Event-Sourced CQRS

### What It Is

The Aggregate's authoritative state is its append-only stream of past internal events (not a mutable current-state row). Current state is always derived by replaying that stream through `Apply` methods. Projections are built from this same event stream. This is the Domain Model pattern with one additional layer: persistence strategy replaced by an Event Store.

### When to Use

Khononov's three-question justification test — all three must be evaluated and at least one must be true:

1. **Temporal reconstruction**: the business genuinely needs to reconstruct what the Aggregate's state was at an arbitrary past point in time — not "we log changes" but literally rehydrating `DataAsset` as it existed on 2025-01-15T14:30:00Z.
2. **Retroactive projections**: new Read Models or reports need to be built from data that already existed *before* the projection was designed (impossible with current-state persistence, since intermediate states are gone).
3. **Event stream as authoritative compliance record**: the event stream itself — not a bolted-on audit log — must be the authoritative record for audit/compliance purposes (e.g., SOC 2 evidence requires a tamper-evident, immutable history).

For this plugin's first product: `DataAsset`'s classification history (particularly `DataAssetClassified` events under SOC 2 requirements) is a candidate for criterion 3. Make the decision explicit in an ADR before adopting Event Sourcing for any Bounded Context.

### When Not to Use

- None of Khononov's three criteria apply — current-state persistence with a standard audit log suffices
- The team is adopting Event Sourcing because the subdomain is Core (and therefore "deserves the best") — this is the named anti-pattern; Core status alone does not justify the cost
- The Aggregate's event schema is expected to change frequently — event upcasting (a required discipline for event-sourced Aggregates) has non-trivial ongoing cost
- Snapshotting infrastructure is not yet in place and the event stream will grow unboundedly

### Infrastructure Requirements

- An Event Store (PostgreSQL table with append-only semantics and a `version` column, or a dedicated event store like EventStoreDB)
- Conditional-append operation: `INSERT INTO aggregate_events WHERE expected_version = $N` — the event-sourced equivalent of the CAS `UPDATE ... WHERE version = $N` optimistic-concurrency check
- Snapshotting cadence defined (e.g., every 100 events) and snapshot storage (same PostgreSQL, separate table)
- Upcasting registry for any stored event whose schema has changed since it was first persisted

### Consistency Guarantee

Eventual — same as Full CQRS. Projections are built from the event stream asynchronously.

---

## Khononov's Four Business Logic Design Patterns Mapped to CQRS

Khononov's *Learning DDD* names four patterns for implementing business logic in a subdomain, each mapped to a point on the complexity spectrum. CQRS variant selection should be made *after* determining which pattern applies.

| Pattern | Subdomain fit | Write side shape | CQRS variant that applies |
|---|---|---|---|
| **Transaction Script** | Generic, simplest Supporting | Procedural — no Aggregate, no domain object | No CQRS (simple CRUD); if a read-side view is needed, query the write table through a typed DTO |
| **Active Record** | Supporting with moderate logic | Object per row, CRUD-shaped behaviour | Simple Read Model at most — no projection pipeline warranted |
| **Domain Model** | Core, complex Supporting | Aggregate + Repository + Domain Events via Transactional Outbox | Full CQRS — event-driven projection into separate Read Model tables |
| **Event-Sourced Domain Model** | Core with temporal/audit/retroactive need | Aggregate state derived from event stream | Event-Sourced CQRS — projections built from the same event stream the Aggregate uses for state reconstruction |

**Decision rule:** choose the simplest pattern that honestly fits the subdomain's actual logic complexity and the query/write divergence. Applying Domain Model + Full CQRS to a Transaction Script subdomain is the named over-engineering failure mode Khononov calls "applying rich tactical patterns uniformly regardless of classification."

---

## Comparison Summary

| | Simple Read Model | Full CQRS | Event-Sourced CQRS |
|---|---|---|---|
| Storage separation | None | Write DB + Read DB | Event Store + Read DB |
| Broker required | No | Yes | Yes |
| Projector service | No | Yes | Yes |
| Consistency | Immediate | Eventual | Eventual |
| Rebuild Read Models | No | Yes | Yes |
| Temporal state reconstruction | No | No | Yes |
| Retroactive projections | No | No | Yes |
| Upcasting discipline required | No | No | Yes |
| Snapshotting required | No | No | Yes (for large streams) |
| Go pattern complexity | Low | Medium | High |
| Appropriate for Generic subdomain | Maybe (plain repo) | No | No |
| Appropriate for Core subdomain | Starting point only | Yes | Only with explicit criteria |
