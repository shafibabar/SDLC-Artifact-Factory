# Projection Mechanics

**Moved here from `cqrs-pattern` (Wave 2, #1397).** `cqrs-pattern` now decides only *whether* a context's Read Models are projected (a named trigger, D047-4); how a projection is kept up to date is this skill's. The three mechanics below are kept as they were and reworked when `read-model-design` is rebuilt (#1398). Code and DDL moved to `go-event-consumer`. Note: the old text's "this plugin's default is Full CQRS for Core contexts" no longer holds; projections need a named trigger.

A **Projector** consumes Domain Events and updates Read Model tables. Every Projector is idempotent: safe to process the same event twice.

---

## Projection Mechanic 1: Synchronous (Same Transaction as Write)

### What It Is

The Read Model table is updated inside the same database transaction that saves the Aggregate state and the outbox event row. If the transaction fails, neither the Aggregate state, the outbox row, nor the Read Model update is committed.

### Characteristics

- **Consistency**: Immediate — the Read Model is always current at the moment the write commits
- **Coupling**: Tight — every schema change to any Read Model requires touching the write transaction
- **Write throughput impact**: Every write pays the cost of every Read Model's update; complex or slow projections directly degrade write latency
- **Rebuild**: Cannot replay from events — the Read Model was never built from events, so replaying the event stream will not reconstruct it
- **Idempotency requirement**: Less critical (the write transaction is atomic), but still required if the write is retried after a partial failure

### When to Use

- The Simple Read Model variant, where write and read share one DB and there is no broker
- A single, lightweight summary counter or materialised view that adds negligible write latency
- **Do not use** in Full CQRS — this pattern reintroduces write-side coupling that Full CQRS exists to remove

The Go sketches are in `go-event-consumer` (projector sketches).

---

## Projection Mechanic 2: Event-Driven (Subscribe to Broker)

### What It Is

The Projector is a separate consumer that subscribes to a Redpanda topic (or consumer group). It processes Domain Events published by the Transactional Outbox relay and upserts Read Model tables. This is the standard mechanic for Full CQRS in this plugin.

### Characteristics

- **Consistency**: Eventual — Read Models lag the Write Model by the outbox relay + broker delivery round-trip (typically milliseconds to low seconds)
- **Coupling**: Decoupled — the Projector can be updated, redeployed, or replaced without touching the write path
- **Write throughput impact**: None — the write transaction ends when the outbox row is inserted; the projector runs asynchronously
- **Rebuild**: Yes — stop the projector, truncate the Read Model table, reset the consumer group offset to the earliest message, restart. The full event history in Redpanda replays and rebuilds the Read Model.
- **Idempotency requirement**: Critical — at-least-once delivery means the same event may arrive more than once (broker retry, consumer crash, rebalance). The projector must detect and skip duplicates.

### When to Use

- Any context `cqrs-pattern` has put on the projections rung
- Any Read Model that must be independently scalable, deployable, or rebuildable

The Go sketches are in `go-event-consumer` (projector sketches).

An upsert that applies an event only when its sequence is newer than the one stored keeps out-of-order and duplicate events from regressing the Read Model to an older state.

### Idempotency via processed_event_ids Table

For projectors where the upsert's own version-check is insufficient (e.g., delete events, or events with no natural sequence to compare), record each processed event ID in a deduplication table, in the same transaction as the Read Model write.

---

## Projection Mechanic 3: CDC-Driven (Change Data Capture via Debezium)

### What It Is

Debezium connects to the PostgreSQL Write DB's WAL (Write-Ahead Log) and captures every row-level change in the `data_assets` table (and optionally `outbox_events`). These change events are published to a Redpanda topic. The Projector subscribes to the Debezium topic instead of the application-level Domain Event topic.

### Characteristics

- **Consistency**: Eventual — slightly less lag than event-driven (no application-level outbox relay hop) but still asynchronous
- **Coupling to write schema**: Higher — the CDC event payload reflects the Aggregate table's column structure, not the Domain Event's business language. Schema migrations on the Aggregate table directly change the CDC event shape.
- **No application-level event publishing required**: The application does not need to publish Domain Events; Debezium observes the database directly. This is the primary advantage for legacy systems or contexts where event publishing is not yet in place.
- **Rebuild**: Yes — but requires Debezium to replay from a WAL snapshot; the WAL is not retained indefinitely. For long-term replay, use the event-driven mechanic (events stored in Redpanda with long retention) instead.
- **Idempotency requirement**: Same as event-driven — at-least-once delivery from Debezium; projector must be idempotent.

### When to Use

- The Write Model uses a legacy PostgreSQL schema where adding Transactional Outbox rows is impractical
- The team needs to project data from a table that does not emit application-level Domain Events
- Connecting an existing application's database changes to a new Read Model without modifying the application

### When Not to Use

- The Bounded Context already uses Transactional Outbox + Redpanda — the event-driven mechanic is simpler and more decoupled
- You need the payload to carry business-meaningful Domain Event fields (not raw column values)
- Long-term Read Model rebuild from an event stream is required — Debezium's WAL position may not be retained long enough

The Go sketches are in `go-event-consumer` (projector sketches).

---

## Idempotency: Why It Is Required and How to Implement It

Every Projector must be idempotent regardless of which projection mechanic is used, because all delivery guarantees in this plugin are at-least-once:

- The Transactional Outbox relay may retry a publish on a broker timeout — the consumer sees the event twice
- A Redpanda consumer group rebalance may replay events already processed before the crash
- A Projector restart for deployment may re-process messages from the last committed offset

**The two idempotency patterns and when to use each:**

| Pattern | When to use | Trade-off |
|---|---|---|
| **Event sequence check in upsert** (`ON CONFLICT DO UPDATE WHERE projector.event_sequence < EXCLUDED.event_sequence`) | When events carry a natural sequence number (version, timestamp, offset) and the Read Model row is keyed by the Aggregate ID | No extra table; works inline with the upsert; does not protect against non-upsert operations |
| **`processed_event_ids` dedup table** | When events are delete operations, when the Read Model cannot carry a comparable sequence, or when the projector spans multiple Read Model tables in one handler | Full protection for all event types; adds one table lookup + insert per event; must be within the same transaction as the Read Model write |

For most projectors, use the event sequence check as the primary guard and add the `processed_event_ids` table for any handler that performs delete operations or touches multiple tables.

The Read Model row carries the sequence of the last applied event (the Aggregate version or the broker offset), so a duplicate is a no-op.
