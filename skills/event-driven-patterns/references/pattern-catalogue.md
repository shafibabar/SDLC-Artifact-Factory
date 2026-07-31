# Event-Driven Pattern Catalogue

Full reference for each event-driven integration pattern used in this platform. Each entry gives a **formal definition**, **when to use / when NOT to use**, the **failure mode** it defends against, the **consistency guarantee** it provides, and how it **manifests on the Redpanda + Go stack**. Grounded in Kleppmann (*Designing Data-Intensive Applications* — log-based message brokers, stream processing, effectively-once semantics), Newman (*Building Microservices* — choreography vs. orchestration, smart endpoints/dumb pipes), and Ford et al. (*Software Architecture: The Hard Parts* — dynamic coupling, the Saga taxonomy).

Worked domain throughout: the Data Estate Mapping & Compliance Intelligence platform — three Bounded Contexts (DataAsset Management, Compliance, Reporting), Go + chi + pgx services, per-tenant physical isolation, Redpanda topics, OpenTelemetry/Prometheus/Tempo/Grafana observability.

---

## The three axes of dynamic coupling (Ford)

Before selecting a pattern, classify the flow on **three orthogonal axes** — Ford et al. separate what a single "sync vs. async" or "choreography vs. orchestration" toggle conflates:

1. **Communication** — synchronous vs. asynchronous. Does the caller block for a reply?
2. **Consistency** — atomic vs. eventual. Must all effects commit together, or may they converge over time?
3. **Coordination** — orchestrated vs. choreographed. Is there a central conductor, or do services react autonomously?

These three binary axes produce **eight Saga archetypes**, each named memorably in *The Hard Parts*:

| Archetype | Communication | Consistency | Coordination | Verdict |
|---|---|---|---|---|
| **Epic Saga** | sync | atomic | orchestrated | Distributed monolith — high coupling, simple to reason about |
| **Phone Tag Saga** | sync | atomic | choreographed | Brittle — every service must know the next; avoid |
| **Fairy Tale Saga** | sync | eventual | orchestrated | Moderate coupling, tolerable |
| **Time Travel Saga** | sync | eventual | choreographed | Workable but hard to trace |
| **Fantasy Fiction Saga** | async | atomic | orchestrated | Atomicity over async is awkward |
| **Horror Story** | async | atomic | choreographed | **Worst combination** — no coordinator AND assumed atomicity; the book says avoid |
| **Parallel Saga** | async | eventual | orchestrated | **Recommended default** for complex multi-step processes |
| **Anthology Saga** | async | eventual | choreographed | Most scalable/decoupled — for genuinely independent reactions |

**Artifact language rule:** the whimsical names are memory aids, not PM-reviewable vocabulary. In artifacts, classify a flow by its three dimensions (e.g., "async, eventual, orchestrated") and add the archetype name only as a parenthetical `(Parallel Saga)`. This platform's default complex-flow shape is the **Parallel Saga**; the default two-context reaction is close to an **Anthology Saga**.

---

## 1. Event Choreography

**Definition.** Each service reacts to events emitted by others. No central coordinator exists; every service encodes "what I do when I see event X."

```
Storage Integration                 Classification Service
emits StorageSourceConnected  ────▶  reacts: trigger initial scan
emits FileCrawled             ────▶  reacts: classify file
                                     emits DataAssetClassified
                                                   │
                                                   ▼
                                     Graph Service — reacts: update knowledge graph
```

**When to use.** Simple flows (2–3 services); steps are natural independent reactions; participants owned by independent teams; no compensation is needed. Corresponds to the **Anthology Saga** (async, eventual, choreographed).

**When NOT to use.** Flows of 4+ services; any flow needing a queryable "where is this now?" view; any flow with compensating transactions (those need a coordinator).

**Failure mode it defends against.** Central-coordinator coupling and single-point-of-failure. Each service stays independently deployable.

**Failure mode it introduces.** *Choreography sprawl* — a 6-service process nobody can trace; and *circular event chains* — context A reacts to B's events with events B reacts to, producing infinite loops. Draw the full event-flow graph during Design; any cycle must be broken with a terminating condition or merged into one Saga.

**Consistency guarantee.** Eventual only. Intermediate states are visible facts.

**Redpanda manifestation.** Each context publishes to its own topic (`storage.source-connected`, `classification.data-asset-classified`); consumers subscribe via distinct consumer groups. No topic contains routing logic — **smart endpoints, dumb pipes** (Newman): all business logic lives in producer/consumer handlers, never in the broker.

---

## 2. Orchestration (Saga coordinator)

**Definition.** A central orchestrator issues Commands to participants, receives their result events, and holds the flow's state.

```
Scan Orchestrator
  1. Command → Storage Integration: "crawl source"      2. ← CrawlCompleted
  3. Command → Classification: "classify files"          4. ← ClassificationCompleted
  5. Command → Graph: "update graph"                     6. ← GraphUpdated
  7. emits EstateScanCompleted
```

**When to use.** Complex flows (4+ steps); a central, queryable view of progress is required; the flow has compensations. Corresponds to the **Parallel Saga** (async, eventual, orchestrated) — the recommended default for complex processes.

**When NOT to use.** Simple two-context reactions where an orchestrator adds a coupling point for no benefit.

**Failure mode it defends against.** Untraceable choreography; unclear recovery. One place answers "where is this scan, and what failed?"

**Failure mode it introduces.** The orchestrator becomes a coupling point and — if misused — a *god service* doing the work itself. Rule: the orchestrator only sends Commands, tracks state, and triggers compensations; all domain work stays in participants.

**Consistency guarantee.** Eventual, with a coordinated recovery path. Not atomic — see "no 2PC" below.

**Redpanda manifestation.** The orchestrator consumes result topics and produces Command topics; its state lives in a `saga_instances` table (see `saga-patterns.md`). It persists each state transition **before** dispatching the next Command; a crash between dispatch and persistence is resolved by participant idempotency.

---

## 3. Saga

Covered fully in `saga-patterns.md`. In brief: a sequence of local transactions, each emitting an event that triggers the next; on failure, compensating transactions undo completed steps in reverse order. It is this platform's answer to the fact that **two-phase commit does not scale to microservices** (Kleppmann Ch. 9: 2PC is a blocking protocol — a coordinator crash after "yes" votes strands participants holding locks). A Saga trades atomicity for eventual consistency plus explicit compensation.

**Consistency guarantee.** Eventual. Intermediate states are visible; compensation is *semantic*, not rollback — `DisconnectStorageSource` does not un-happen `StorageSourceConnected`, it emits a new corrective fact.

---

## 4. Idempotent Consumer

**Definition.** Processing the same event twice produces the same result as processing it once.

**When to use.** **Always.** Redpanda (like Kafka) provides *at-least-once* delivery; a consumer may see the same event again after a restart, rebalance, or network failure. Every consumer in this platform is idempotent.

**When NOT to use.** Never skip it. The only variation is the dedup mechanism (see below).

**Failure mode it defends against.** Duplicate side effects — a compliance alert sent twice, a DataAsset counted twice, a Read Model double-incremented.

**Consistency guarantee.** **Effectively-once processing** (Kleppmann Ch. 11) — the honest, achievable alternative to literal "exactly-once." At-least-once delivery + a deduplicating consumer = the *observable business effect* of processing once. The dedup mark and the state write **must commit in the same local transaction**; if they are separate, a crash between them degrades the guarantee to at-least-twice.

**End-to-end argument (Kleppmann).** Deduplication is only real at the ultimate side-effect boundary. Thread one idempotency key (`eventId`) from the true origin (e.g., `FileDiscovered`) through every hop to the final effect (e.g., a compliance alert actually sent). Per-hop dedup that happens to compose is not a guarantee unless the same key travels end-to-end.

**Redpanda manifestation.** A `processed_message_ids` table (see `go-implementation.md`) records handled event IDs; a unique-constraint violation is treated as "already processed."

---

## 5. Competing Consumers

**Definition.** Multiple instances of one consumer group read from the same topic; Redpanda assigns each partition to exactly one instance at a time.

```
Topic classification.file-crawled (8 partitions)   Group classification-service
  Instance 1: partitions 0,1   Instance 2: 2,3   Instance 3: 4,5   Instance 4: 6,7
```

**When to use.** Processing volume exceeds a single consumer's throughput and horizontal scale-out is needed.

**When NOT to use.** Low-volume flows where one consumer suffices — extra instances just sit idle (a topic has a fixed partition count; instances beyond the partition count get nothing).

**Failure mode it defends against.** Single-consumer throughput ceiling.

**Consistency guarantee.** Per-partition ordering only. Events with the same partition key always land on the same partition and are processed in order by one instance.

**Partition-key design (Kleppmann Ch. 6 — hash partitioning, hot keys).** Partition by `tenant_id`: all of a tenant's events keep per-tenant order while different tenants process concurrently. Two caveats: (1) a single very large tenant can become a **hot key** exceeding one partition's throughput — the ceiling is `1 partition per tenant`; if hit, split by a finer key (Aggregate ID) or salt the hot tenant. (2) Per-tenant ordering does **not** give causal ordering across Aggregates — two causally-related events on different Aggregates may sit on different partitions and be observed out of order. Name that constraint explicitly if a flow depends on it; otherwise the `causationId` field is tracing-only.

**Redpanda manifestation.** Set the partition count higher than the current instance count (Kleppmann's rebalancing guidance: fixed partition count assigned across consumers, not chosen for today's fleet size) so scale-out doesn't require repartitioning.

---

## 6. Transactional Outbox

**Definition.** A service writes its state change and an "event to publish" row into an `outbox` table in **one local transaction**; a separate publisher process reads the outbox and relays rows to Redpanda, marking them sent.

**When to use.** The default for **every new service** that must emit an event atomically with its own database write. It is the local-atomicity answer that replaces cross-service 2PC.

**When NOT to use.** For a legacy service whose code you cannot modify to write the outbox row — use CDC instead.

**Failure mode it defends against.** The dual-write problem: writing to the DB and publishing to Redpanda as two separate operations means a crash between them either loses the event or emits an event for a rolled-back write. The Outbox makes the state change and the event's *durability* atomic.

**Consistency guarantee.** Atomic locally (one transaction, one node); at-least-once from the outbox to Redpanda (the publisher may re-send a row it already sent but hadn't marked — consumers' idempotency absorbs this).

**Redpanda manifestation.** See `go-implementation.md` for the `outbox` DDL and publisher loop.

---

## 7. Change Data Capture (CDC)

**Definition.** Database row changes (`INSERT`/`UPDATE`/`DELETE`) are captured from the write-ahead log and streamed as events — no application code change. Implemented with Debezium or PostgreSQL logical replication.

**When to use.** Integrating with a **legacy** service that cannot adopt the Transactional Outbox; building a pipeline from an existing database; migrating a monolith by capturing its table changes.

**When NOT to use.** As a substitute for the Outbox in new services — the Outbox is simpler to operate and emits **domain-meaningful** events. CDC events reflect *table row structure*, not domain concepts; a `UPDATE data_assets SET ...` row is not a `DataAssetClassified` Domain Event.

**Failure mode it defends against.** The need to modify unmodifiable code to emit events.

**Consistency guarantee.** Eventual; ordering per source table (via the WAL log sequence).

**Redpanda manifestation.** In this platform, CDC is reserved for the case where entity-extraction results in a legacy Classification component must reach the Graph service without a direct call. New services use the Outbox.

---

## 8. Dead Letter Queue (DLQ)

**Definition.** After a message fails processing N times, it is routed to a separate "dead letter" topic instead of being retried forever or dropped.

**When to use.** Every consumer. A malformed or unprocessable **poison message** must not block its partition indefinitely — because one partition is processed in order by one consumer, a stuck message halts every message behind it for that tenant.

**When NOT to use.** Never skip it. Pair it with a retry policy (below) and a Grafana alert on DLQ depth.

**Failure mode it defends against.** Partition head-of-line blocking; silent message loss.

**Consistency guarantee.** None added — it is a poison-message escape valve. DLQ contents require a human or a repair job.

**Redpanda manifestation.** A `<topic>.dlq` topic; the consumer publishes the failed message (with failure metadata) there after N attempts and commits its offset so the partition advances. See `go-implementation.md`.

---

## 9. Retry with Backoff

**Definition.** A failed processing attempt is retried after a growing delay (exponential) with random **jitter** to avoid a thundering herd of synchronized retries.

**When to use.** For **transient** failures — a downstream 5xx, a network blip, a momentary DB contention — that are worth re-attempting.

**When NOT to use.** For **permanent** failures (a schema-invalid message, a business-rule rejection). Retrying those wastes cycles; route them straight to the DLQ. Distinguish transient from permanent by the error type before deciding to retry.

**Failure mode it defends against.** Transient downstream unavailability turning into lost work; and retry storms (jitter defends against synchronized retries).

**Consistency guarantee.** None added; it composes with idempotency (a retry may re-run a partially-succeeded handler — idempotency makes that safe).

**Redpanda manifestation.** In-process retry with exponential backoff + jitter, then DLQ on exhaustion. See `go-implementation.md`.

---

## Event replay

**Definition.** Re-reading a topic from the earliest offset to rebuild a consumer's state.

**When to use.** Rebuild a corrupted Read Model; add a new Read Model without re-scanning source data; onboard a new consumer that needs history; debug by reproducing a historical state.

**Requirements.** (1) Topic retention long enough (min 7 days; compliance cases may require indefinite). (2) All consumers idempotent — replay re-delivers processed events. (3) Read Models must support full rebuild. **Replay into a shadow table, then swap** — never replay into a live, incrementally-patched Read Model, or replayed and live events mix into a state neither history produced.

```bash
rpk group seek classification-service --topic classification.file-crawled --to-earliest
# restart the consumer; it processes from the beginning
```

---

## Selection cross-check

| Situation | Pattern(s) | Rejected alternative & why |
|---|---|---|
| 2-context reaction, no rollback | Choreography (Anthology Saga) | Orchestration — adds a needless coupling point |
| 4-step ingestion with compensation | Orchestration-based Saga (Parallel Saga) | Choreography — untraceable, no central recovery |
| New service emitting an event with its write | Transactional Outbox | CDC — table-shaped events, harder to operate |
| Legacy component, no code access | CDC | Outbox — requires code change that isn't possible |
| Transient downstream error | Retry + backoff, then DLQ | Infinite retry — blocks the partition |
| Duplicate delivery after rebalance | Idempotent Consumer | "Exactly-once" delivery — not achievable end-to-end |
