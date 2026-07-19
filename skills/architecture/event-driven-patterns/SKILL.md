---
name: event-driven-patterns
description: >
  Reference skill for the core event-driven architecture patterns used in this
  plugin — covering Event Choreography vs Orchestration, the Saga pattern for
  distributed transactions, Idempotent Consumers, Event Replay, the Competing
  Consumers pattern for parallel processing, and Change Data Capture. Provides
  the pattern knowledge that the enterprise-architect, backend-engineer, and
  platform-engineer apply when designing and implementing event-driven services.
version: 1.1.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, event-driven, saga, choreography, orchestration, idempotency, cdc]
---

# Event-Driven Patterns

## Purpose

This skill is a reference for the event-driven architecture patterns that appear throughout the plugin's artifact set. It provides the "how" behind patterns that are mandated in the methodology and tech stack — giving the enterprise-architect and backend-engineer the knowledge to apply each pattern correctly and avoid its failure modes.

---

## 1. Event Choreography vs Orchestration

The fundamental choice in multi-service event flows:

### Choreography

Each service reacts to events from other services. There is no central coordinator — each service knows what to do when it receives an event.

```
Storage Integration                 Classification Service
emits: StorageSourceConnected  ────▶  reacts: trigger initial scan
emits: FileCrawled             ────▶  reacts: classify file
                                      emits: DataAssetClassified
                                                    │
                                                    ▼
                                      Graph Service
                                      reacts: update knowledge graph
```

**Advantages:** Loose coupling; each service is independently deployable; no single point of failure.

**Disadvantages:** Hard to trace the overall flow; difficult to debug when something fails midway; can lead to circular event chains if not carefully designed.

**Use when:** The flow is simple (2-3 services); the services are clearly owned by independent teams; the events are the natural public API between contexts.

### Orchestration

A central orchestrator service coordinates the flow by issuing Commands to each participant and waiting for their results.

```
Scan Orchestrator
  1. Command → Storage Integration: "crawl this source"
  2. Receives: CrawlCompleted event
  3. Command → Classification Service: "classify these files"
  4. Receives: ClassificationCompleted event
  5. Command → Graph Service: "update graph"
  6. Receives: GraphUpdated event
  7. Emits: EstateScanCompleted
```

**Advantages:** The flow is visible and traceable in one place; easier to debug; clear recovery path when a step fails.

**Disadvantages:** The orchestrator is a coupling point; it must know about all participants; a bug in the orchestrator affects the entire flow.

**Use when:** The flow is complex (4+ services); the business logic of "what happens next" is genuinely cross-cutting; strong observability of the flow is required.

**Default for this plugin:** Choreography for standard Domain Event flows; Orchestration (Saga) for multi-step distributed business processes.

---

## 2. Saga Pattern (Distributed Transactions)

A Saga is a sequence of local transactions. Each step emits an event (or message) that triggers the next step. If a step fails, compensating transactions undo the preceding steps.

### Choreography-based Saga

```
Step 1: ConnectStorageSource    → emits StorageSourceConnected
Step 2: CreateConsumerGroup     → emits ConsumerGroupCreated (or Failed → compensate Step 1)
Step 3: TriggerInitialScan      → emits InitialScanStarted (or Failed → compensate Steps 1-2)
```

Each service knows its compensating action. `StorageSourceConnected` → if Step 2 fails → emit `DisconnectStorageSource` command.

### Orchestration-based Saga

```
Saga Orchestrator tracks state:
  STARTED
    → send ConnectStorageSource command
  STORAGE_CONNECTED
    → send CreateConsumerGroup command
  CONSUMER_GROUP_CREATED
    → send TriggerInitialScan command
  SCAN_TRIGGERED → COMPLETED
  
  On any failure:
  STORAGE_CONNECTED + CreateConsumerGroup failed
    → send DisconnectStorageSource (compensate)
  → FAILED
```

The Saga Orchestrator persists its state — it must survive restarts and continue from where it left off. The state transition is persisted **before** the next Command is dispatched; a crash between dispatch and persistence is resolved by the participants' idempotency (the re-dispatched Command is deduplicated).

### Compensation Rules

Compensation is where Sagas actually fail in production. These rules are non-negotiable:

1. **Compensate in reverse order.** Compensating transactions run in the reverse order of the completed steps. Step 3 fails → compensate Step 2, then Step 1. Forward steps may have built on earlier state; unwinding out of order compensates state a later compensation still depends on.
2. **Compensations must not fail permanently.** A compensating transaction is retried until it succeeds or is escalated to manual intervention (DLQ + alert). There is no "compensation of a compensation" — design each compensating action to be idempotent and always eventually applicable.
3. **Classify every step: compensatable, pivot, or retryable.** A *compensatable* step can be undone. The *pivot* is the point of no return — once it commits, the Saga can only move forward. *Retryable* steps after the pivot must always eventually succeed. Order steps so all compensatable steps precede the pivot; a Saga with two pivots is two Sagas.
4. **Compensation is semantic, not rollback.** `DisconnectStorageSource` does not make `StorageSourceConnected` un-happen — the event history keeps both facts. Consumers of the intermediate events must tolerate seeing work that was later compensated (e.g. a scan started, then cancelled).
5. **Compensation data is captured on the way forward.** Each step records in the Saga `payload` whatever its compensation will need (created IDs, prior values). A compensation that must query current state to know what to undo will race concurrent changes.

**Saga state table (PostgreSQL):**
```sql
CREATE TABLE saga_instances (
    id              UUID PRIMARY KEY,
    saga_type       TEXT NOT NULL,
    current_state   TEXT NOT NULL,
    payload         JSONB NOT NULL,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    failed_at       TIMESTAMPTZ,
    failure_reason  TEXT
);
```

---

## 3. Idempotent Consumers

Redpanda (Kafka) provides at-least-once delivery. A consumer may receive the same event more than once (after a restart, network failure, or rebalance). Consumers must be idempotent — processing the same event twice must produce the same result as processing it once.

### Implementation Pattern

```go
type IdempotencyStore interface {
    HasProcessed(ctx context.Context, eventID uuid.UUID) (bool, error)
    MarkProcessed(ctx context.Context, eventID uuid.UUID) error
}

func (h *DataAssetClassifiedHandler) Handle(ctx context.Context, event domain.DataAssetClassified) error {
    // Idempotency check
    processed, err := h.idempotency.HasProcessed(ctx, event.EventID)
    if err != nil {
        return fmt.Errorf("checking idempotency: %w", err)
    }
    if processed {
        return nil // already handled — safe to skip
    }

    // Process event
    if err := h.readModelStore.UpdateSensitivity(ctx, event.DataAssetID, event.SensitivityLevel); err != nil {
        return err
    }

    // Mark processed (in the same transaction as the state update)
    return h.idempotency.MarkProcessed(ctx, event.EventID)
}
```

The idempotency check and the state update must be in the same transaction. If they are not, a crash between the state update and the idempotency mark will cause the event to be processed again on restart.

---

## 4. Event Replay

The ability to replay events from the beginning of the event stream is critical for:
- Rebuilding a corrupted Read Model
- Adding a new Read Model without re-scanning all data
- Debugging — reproducing a historical state
- Onboarding a new consumer service that needs to process historical events

**Replay requirements:**
1. Redpanda topic retention must be set long enough for replay (minimum 7 days; compliance use cases may require indefinitely)
2. All consumers must be idempotent (replay will re-deliver already-processed events)
3. Consumer groups can be reset to the beginning of a topic (`--reset-offsets --to-earliest`)
4. Read Models must support full rebuild (drop and rebuild, not incremental patch)

**Replay as a maintenance operation:**
```bash
# Reset consumer group offset to beginning of topic
rpk group seek [consumer-group] --topic [topic-name] --to-earliest

# Restart the consumer service — it will process all events from the beginning
```

---

## 5. Competing Consumers (Parallel Processing)

When processing volume exceeds single-consumer throughput, multiple consumer instances read from the same consumer group. Redpanda assigns partitions to each consumer instance — each partition is processed by exactly one consumer at a time.

```
Topic: classification.file-crawled (8 partitions)
Consumer Group: classification-service
  Instance 1: partitions 0, 1
  Instance 2: partitions 2, 3
  Instance 3: partitions 4, 5
  Instance 4: partitions 6, 7
```

**Partition key design:** The partition key determines which partition an event lands on. Events with the same partition key always go to the same partition, which means they are always processed by the same consumer instance in order.

For the first product, partition by `tenant_id` — all events for a given tenant go to the same partition, preserving per-tenant ordering while allowing concurrent processing across tenants.

---

## 6. Change Data Capture (CDC)

CDC captures database row changes as events, without modifying application code. Debezium (or PostgreSQL logical replication) streams `INSERT`, `UPDATE`, and `DELETE` operations as events to Redpanda.

**When to use:**
- Integrating with a legacy service that cannot be modified to use the Transactional Outbox
- Building a real-time analytics pipeline from an existing database
- Migrating from a monolith to microservices by capturing existing database changes as events

**When NOT to use:**
- As a substitute for the Transactional Outbox in new services — the Transactional Outbox is simpler to operate
- When event schemas need to be domain-meaningful — CDC events reflect table row structure, not domain concepts

**CDC in this plugin's first product:** CDC is used for the graph update pipeline — changes to entity extraction results in the Classification service are captured and streamed to the Graph service via CDC, avoiding a direct service call.

---

## Pattern Selection Guide

| Need | Pattern |
|---|---|
| Simple multi-service flow (≤3 services) | Choreography |
| Complex multi-step flow with compensations | Saga (orchestration-based) |
| High-throughput event processing | Competing Consumers with partition-by-tenant |
| Rebuild a Read Model | Event Replay |
| Guarantee at-most-once business effect | Idempotent Consumer |
| Integrate with legacy system without code change | CDC (Debezium) |
| New service needs historical events | Event Replay to new consumer group |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Choreography vs orchestration declared | Each multi-service flow names its coordination style | Flows with no documented coordination pattern |
| Saga compensation defined | Every Saga step has a documented compensating action | Sagas with no rollback strategy |
| Idempotency everywhere | All event consumers implement the idempotency pattern | Consumers that process events without idempotency checks |
| Partition key documented | Every topic defines its partition key and the ordering guarantee it provides | Topics with default (round-robin) partitioning applied to ordered-processing use cases |
| Topic retention set | Retention period defined for every topic, justified by replay and compliance needs | Topics with no retention policy |
| CDC justified | CDC usage is explicitly justified against the Transactional Outbox | CDC used in new services where the Transactional Outbox is simpler |
| Saga step classification | Every Saga step is classified compensatable, pivot, or retryable, with one pivot per Saga | Steps of unknown class, or compensatable steps after the pivot |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Choreography sprawl** — a 6-service business process coordinated purely by event reactions | Nobody can answer "where is this scan right now?"; failure recovery requires reading six services' logs | Flows beyond ~3 services, or any flow with compensations, get an orchestration-based Saga |
| **Orchestrator doing the work** — the Saga Orchestrator calling databases and applying business rules itself | The orchestrator becomes a god service; participants' invariants are bypassed | The orchestrator only sends Commands, tracks state, and triggers compensations; all domain work stays in participants |
| **Circular event chains** — context A reacts to B's events with events B reacts to | Infinite loops or oscillating state, often triggered only under production timing | Draw the full event flow graph during design; any cycle must be broken with a terminating condition or merged into one Saga |
| **Distributed transaction nostalgia** — trying to make a Saga atomic (locks held across steps, two-phase commit) | Reintroduces the coupling and availability collapse Sagas exist to avoid | Accept intermediate states as visible facts; design compensations and consumer tolerance instead |
| **Compensation as afterthought** — Saga designed happy-path-first, compensations "to be added later" | The first mid-Saga failure strands real tenant state with no recovery path | Compensating actions, step classification, and pivot placement are part of the initial Saga design |
| **Read-check idempotency across transactions** — `HasProcessed` and the state write in separate transactions | A crash between them re-processes the event; the guarantee silently degrades to at-least-twice | Idempotency mark and state change commit atomically; unique-constraint violation treated as "already processed" |
| **Partitioning by random key for ordered flows** — round-robin partitioning where order matters | Events for one tenant interleave across consumers; per-tenant ordering is destroyed | Partition key = `tenant_id` (or Aggregate ID where finer ordering is needed); document the guarantee per topic |
| **Replay without rebuild discipline** — replaying a topic into a live, incrementally-patched Read Model | Replayed events mix with live ones; the view ends in a state neither history produced | Replay into a shadow table, then swap; consumers must be idempotent and replay-aware |

---

## Output Format

This skill produces design notes incorporated into the Integration Design and Container Diagram artifacts:

```markdown
## Event-Driven Pattern Decisions: [Service/Flow Name]

| Flow | Coordination style | Rationale |
|---|---|---|

## Saga Definitions
| Saga | Steps | Compensation actions | State persistence |
|---|---|---|---|

## Topic Design
| Topic | Partition key | Retention | Consumer groups | DLQ |
|---|---|---|---|---|

## Idempotency Implementation
[Per-consumer: idempotency store location, transaction scope]
```
