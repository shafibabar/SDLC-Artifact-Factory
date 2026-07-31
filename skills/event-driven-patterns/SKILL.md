---
name: event-driven-patterns
description: >
  Teaches the enterprise-architect and backend-engineer to select and apply
  event-driven integration patterns — Event Choreography vs. Orchestration, the
  Saga pattern for distributed transactions, Idempotent Consumers, Competing
  Consumers, the Transactional Outbox, Change Data Capture, Dead Letter Queues,
  and Retry/Backoff — covering the explicit selection criterion for each, the
  consistency guarantees each provides, the failure modes each defends against,
  and the Go + Redpanda implementation in this platform. Used during Design when
  defining how Bounded Contexts communicate asynchronously.
version: 2.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, event-driven, choreography, orchestration, saga, idempotency, transactional-outbox, cdc, dead-letter-queue]
related: [integration-design, data-pipeline-design, event-schema-design, cqrs-pattern, container-diagram, context-map-patterns]
---

# Event-Driven Patterns

## Purpose

Reference for the event-driven architecture patterns mandated by this plugin's methodology and Redpanda tech stack. It gives the enterprise-architect and backend-engineer the criteria to **select** the right pattern for a given asynchronous integration between Bounded Contexts, the **consistency guarantee** each provides, and the **failure mode** each defends against — so a flow is designed with the correct coordination style and correct delivery guarantees, not defaulted into one.

This skill is knowledge, not reasoning: it holds the selection tables and criteria. Applying them to a specific flow (which pattern this scan needs, which steps compensate) is the enterprise-architect's and backend-engineer's job.

---

## The Primary Choice: Choreography vs. Orchestration

Every multi-service flow is first classified on its **coordination style**. This is the organizing decision; every other pattern below is layered on top of it.

| | Choreography | Orchestration |
|---|---|---|
| **Who decides "what's next"** | Each service reacts to events autonomously; no central coordinator | A central orchestrator issues Commands and tracks progress |
| **Coupling** | Lowest — events are the public API between contexts | Orchestrator couples to every participant |
| **Central view of progress** | None — "where is this scan?" requires reading N services' logs | One place holds the flow state, queryable |
| **Failure recovery** | Distributed across participants | Clear, centralized recovery path |
| **Select when** | Flow is simple (**2–3 services**); steps are natural independent reactions; no compensation needed | Flow is complex (**4+ services**); needs a queryable central view; has compensating transactions |

**Selection criteria, in order of weight:** (1) **number of steps** — 2–3 favors choreography, 4+ favors orchestration; (2) **need for a central view of progress** — any "where is this business process right now?" requirement forces orchestration; (3) **coupling tolerance** — if the participants are owned by independent teams and must stay decoupled, prefer choreography and accept the tracing cost.

**Default for this plugin:** Choreography for standard Domain Event flows between two contexts; **Orchestration (a persisted Saga coordinator)** for any multi-step distributed business process with compensations.

`references/pattern-catalogue.md` classifies each flow further on all three of Ford's *dynamic-coupling* axes — communication (sync/async), **consistency (atomic/eventual)**, and coordination (choreographed/orchestrated) — and names the eight Saga archetypes those axes produce, so consistency is chosen as its own decision, not conflated with coordination.

---

## The Pattern Menu

Each pattern below has a one-line definition and its **primary selection criterion**. Full definitions, failure modes, consistency guarantees, and Redpanda manifestations are in `references/pattern-catalogue.md`; the Saga in depth is in `references/saga-patterns.md`; Go code is in `references/go-implementation.md`.

| Pattern | One line | Select when (primary criterion) |
|---|---|---|
| **Event Choreography** | Services react to each other's events with no coordinator | Simple flow (≤3 services), steps are independent reactions |
| **Orchestration (Saga coordinator)** | A persisted state machine issues Commands and tracks progress | Complex flow (4+ steps) needing a central, queryable view |
| **Saga** | A sequence of local transactions with compensating transactions on failure | A business process spans **multiple services/Aggregates** and cannot be one ACID transaction |
| **Idempotent Consumer** | Processing the same event twice yields the same result as once | **Always** — Redpanda delivery is at-least-once; every consumer needs it |
| **Competing Consumers** | Multiple instances of one consumer group split a topic's partitions | Processing volume exceeds a single consumer's throughput |
| **Transactional Outbox** | State change and its event are written in **one** local transaction; a publisher relays the outbox row | A new service must emit an event atomically with its own DB write |
| **Change Data Capture (CDC)** | DB row changes are streamed as events without app code changes | A **legacy** service can't adopt the Outbox, or you must capture existing table changes |
| **Dead Letter Queue (DLQ)** | Poison messages are routed to a side topic after N failed retries | A malformed/unprocessable event must not block its partition forever |
| **Retry with Backoff** | Failed processing is retried on a growing, jittered delay | A **transient** failure (network, downstream 5xx) is worth re-attempting before DLQ |

**Two patterns that are easy to confuse — pick deliberately:**
- **Transactional Outbox vs. CDC** — both get a DB change onto a topic. The **Outbox is the default for new services** (simpler to operate, emits domain-meaningful events). CDC is for **legacy** systems you cannot modify, and its events reflect *table row structure*, not domain concepts. Using CDC where the Outbox would do is an anti-pattern.
- **Retry/Backoff vs. DLQ** — Retry is for **transient** failures worth re-attempting; the DLQ is the terminus for **permanent** failures (poison messages) after retries are exhausted, so one bad message never blocks a partition. They compose: retry N times, then DLQ.

---

## Eventual Consistency: When It's Acceptable

Every asynchronous pattern above trades synchronous atomicity for **eventual consistency** — Kleppmann's precise, weak guarantee: *if writes stop, replicas eventually converge, with no promise about ordering or timing.* The design must state, for each flow, whether that is acceptable.

**Eventual consistency is acceptable when** the intermediate state is a tolerable, visible fact — a DataAsset is "classified" a few seconds after it is "ingested"; a compliance dashboard lags the write side by seconds. Consumers must tolerate seeing work that is in-flight or was later compensated.

**A synchronous call is required instead when** the caller cannot proceed without the result *and* the result must be current — e.g., an authorization check ("may this tenant access this source?") gating a request, or a uniqueness constraint that must hold *now* (a **linearizability** need, not merely eventual). These are the deliberate exceptions; everything else defaults to async events.

**Causal ordering.** The event envelope's `causationId`/`correlationId` fields carry *happens-before* metadata (Kleppmann's causal consistency — cheaper than linearizability). Partitioning by `tenant_id` preserves per-tenant order **within a partition** only; two causally-related events on *different* Aggregates can still be observed out of order across partitions. If a flow genuinely needs causal ordering across Aggregates, that is a design constraint to name explicitly — see `references/pattern-catalogue.md`.

**No distributed transactions.** This platform never uses two-phase commit (2PC) across services — it is a blocking protocol that collapses availability (Kleppmann Ch. 9). Atomicity is achieved *locally* (Transactional Outbox: one transaction, one node) and cross-service effects propagate as an idempotently-retriable event stream. A Saga's compensations replace the cross-service rollback 2PC would have given.

---

## Pattern Selection Guide

| Need | Pattern |
|---|---|
| Simple multi-service flow (≤3 services) | Choreography |
| Complex multi-step flow with compensations | Orchestration-based Saga (persisted coordinator) |
| High-throughput event processing | Competing Consumers, partitioned by `tenant_id` |
| Emit an event atomically with a DB write (new service) | Transactional Outbox |
| Capture changes from a legacy DB you can't modify | CDC (Debezium / logical replication) |
| Guarantee a business effect fires effectively-once | Idempotent Consumer (dedup table) |
| Survive transient downstream failures | Retry with exponential backoff + jitter |
| Stop a poison message blocking a partition | DLQ after N retries |
| Rebuild a Read Model from history | Event replay into a shadow table, then swap |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Coordination style declared | Each multi-service flow names choreography or orchestration | Flow with no documented coordination pattern |
| Consistency named separately | Each flow states atomic vs. eventual as its own decision | Consistency conflated with, or inferred from, coordination |
| Saga compensation defined | Every Saga step has a documented compensating action and a class (compensatable/pivot/retryable) | Saga with no rollback strategy, or steps of unknown class |
| Idempotency everywhere | Every consumer dedups redelivered events atomically with its state write | Consumer that processes events with no idempotency check |
| Partition key documented | Every topic names its partition key and the ordering guarantee it gives | Round-robin partitioning applied to an ordered-processing use case |
| Outbox vs. CDC justified | CDC usage justified against the Outbox; Outbox is the new-service default | CDC used in a new service where the Outbox is simpler |
| DLQ + retry policy set | Every consumer defines retry count, backoff, and DLQ routing | Poison messages that can block a partition indefinitely |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Choreography sprawl** — a 6-service process coordinated purely by event reactions | Nobody can answer "where is this scan now?"; recovery means reading six services' logs | Flows beyond ~3 services, or any with compensations, get an orchestration-based Saga |
| **Orchestrator doing the work** — the coordinator calls DBs and applies business rules | It becomes a god service; participants' invariants are bypassed | The orchestrator only sends Commands, tracks state, triggers compensations |
| **Horror Story Saga** — async communication + attempted *atomic* consistency + choreographed | No coordinator *and* an assumed all-or-nothing across async calls: the worst combination (Ford) | Either accept eventual consistency explicitly, or move to an orchestrated Parallel Saga |
| **Distributed-transaction nostalgia** — trying to make a Saga atomic via 2PC/locks | Reintroduces the coupling and availability collapse Sagas exist to avoid | Accept intermediate states as visible facts; design compensations and consumer tolerance |
| **Compensation as afterthought** — happy-path Saga, "compensations added later" | The first mid-Saga failure strands real tenant state with no recovery path | Compensations, step classes, and pivot placement are part of the initial design |
| **Read-check idempotency across transactions** — `HasProcessed` and the state write in separate transactions | A crash between them re-processes the event; the guarantee degrades to at-least-twice | Dedup mark and state change commit atomically; unique-constraint violation = "already processed" |
| **CDC where the Outbox would do** — CDC bolted onto a new service | Events reflect table rows, not domain concepts; two mechanisms to operate | Use the Transactional Outbox for new services; reserve CDC for legacy integration |
| **No DLQ / infinite retry** — a poison message retried forever | It blocks its partition; per-tenant processing stalls | Retry transient failures with backoff, then route to a DLQ after N attempts |
| **Partitioning by random key for ordered flows** — round-robin where order matters | Events for one tenant interleave across consumers; per-tenant ordering is destroyed | Partition key = `tenant_id` (or Aggregate ID for finer ordering); document the guarantee |

---

## References

- **`references/pattern-catalogue.md`** — every pattern in full: formal definition, when to use / when NOT to use, the failure mode addressed, the consistency guarantee, and the Redpanda + Go manifestation. Grounded in Kleppmann (log-based brokers, effectively-once) and Newman/Ford (choreography vs. orchestration, the eight Saga archetypes, smart endpoints/dumb pipes).
- **`references/saga-patterns.md`** — the Saga in depth: choreographed vs. orchestrated, compensating transactions, the **pivot transaction** concept, step classification, failure and recovery, and a worked DataAsset ingestion → classification → compliance-check → indexing Saga with a compensation for each step. Includes Ford's guidance on Saga state ownership.
- **`references/go-implementation.md`** — Go sketches on Redpanda: the Transactional Outbox table DDL + publisher, the idempotent consumer with a `processed_message_ids` dedup table, DLQ routing after N retries, exponential backoff with jitter, and the exactly-once vs. at-least-once trade-off on Redpanda.

---

## Output Format

This skill produces design notes incorporated into the Integration Design and Container Diagram artifacts:

```markdown
## Event-Driven Pattern Decisions: [Service/Flow Name]

| Flow | Coordination | Consistency (atomic/eventual) | Rationale |
|---|---|---|---|

## Saga Definitions
| Saga | Steps (class: comp/pivot/retry) | Compensation actions | State persistence |
|---|---|---|---|

## Topic Design
| Topic | Partition key | Retention | Consumer groups | DLQ topic |
|---|---|---|---|---|

## Idempotency & Delivery
[Per-consumer: dedup store, transaction scope, retry/backoff policy, DLQ threshold]
```
