---
name: data-pipeline-design
description: >
  Teaches how to design a data pipeline architecture — the staged flow that moves
  data from ingestion through processing to its destination stores. Covers pipeline
  stages, delivery semantics (at-least-once vs exactly-once), idempotency,
  backpressure, the Dead Letter Queue, the Transactional Outbox at stage boundaries,
  and how the pipeline preserves tenant isolation and feeds lineage. This is the
  architecture and contract of the pipeline — implementation is owned by the
  data-engineer. Produced by the data-architect during the Design phase.
version: 1.1.0
phase: design
owner: data-architect
created: 2026-06-25
tags: [design, data-architecture, pipeline, redpanda, dlq, idempotency, backpressure, outbox]
---

# Data Pipeline Design

## Purpose

A data pipeline moves data through a series of stages, transforming it at each step. For the first product, the pipeline is the core engine: it takes files discovered at customer storage and turns them into classified, graph-linked, compliance-evaluated knowledge — without raw content ever leaving customer infrastructure.

This skill designs the pipeline's *architecture*: its stages, the contracts between them, how it behaves under failure and load, and how it guarantees correctness. The data-engineer implements it; the backend-engineer builds the producers and consumers. This skill is the blueprint they build to.

---

## The Pipeline Stages

Each stage is an independent, separately deployable consumer. Stages communicate only through Redpanda topics — never direct calls. This is **Event Choreography**: each stage reacts to the event the previous stage emitted.

```
[Worker @ customer storage]
   │  emits FileDiscovered
   ▼
(Topic: file-discovered) ──► [File Processing] ──emits FileProcessed──► (Topic: file-processed)
                                                                              │
                                                                              ▼
                                          [Entity Extraction] ──emits EntityExtracted──► (Topic: entity-extracted)
                                                                              │
                                          ┌───────────────────────────────────┼───────────────────────────┐
                                          ▼                                   ▼                           ▼
                                  [Graph Update]                  [Classification]              [Compliance Rule Engine]
                                  updates Apache AGE              tags sensitivity              evaluates controls
                                          │                                   │                           │
                                          └──────────────► emits ───────────► (Topic: compliance-evaluated)
                                                                                                          │
                                                                                                          ▼
                                                                                          [Alert + Audit] ─► PostgreSQL audit log
```

**Why choreography, not orchestration:** stages are loosely coupled, independently scalable, and independently deployable. A slow extraction stage does not block file processing; it just builds backlog on its topic. No central coordinator becomes a bottleneck or single point of failure. (Where a multi-step process needs coordinated rollback, use a Saga — see the architecture `event-driven-patterns` skill.)

---

## Delivery Semantics

Distributed pipelines cannot get exactly-once delivery for free. The design choice:

| Semantic | Guarantee | Cost | Use |
|---|---|---|---|
| At-most-once | May lose messages | Cheapest | Never — data loss is unacceptable here |
| **At-least-once** | Never loses; may duplicate | Moderate | **Default** — combined with idempotent consumers |
| Exactly-once | No loss, no duplicates | Expensive (transactions across broker + store) | Only where duplication is genuinely unsafe and idempotency cannot be achieved |

**Default: at-least-once delivery + idempotent consumers.** This is the standard, frugal, robust combination. The broker guarantees no message is lost; each consumer guarantees that processing the same message twice has the same effect as processing it once.

---

## Idempotency at Every Stage

Because delivery is at-least-once, every stage must be idempotent. A stage that is not idempotent will corrupt data on the inevitable redelivery.

**Mechanism:** each consumer records the `eventId` values it has processed and skips duplicates.

```sql
CREATE TABLE processed_events (
    consumer_name  TEXT NOT NULL,
    event_id       UUID NOT NULL,
    processed_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (consumer_name, event_id)
);
```

```
on receive(event):
    begin transaction
        INSERT INTO processed_events (consumer_name, event_id) VALUES ($me, event.eventId)
            ON CONFLICT DO NOTHING       -- 0 rows → already processed → skip
        if inserted:
            do the work
            write any output (and its outbox row) in the SAME transaction
    commit
```

The dedup record and the work commit atomically. Either both happen or neither does — no partial processing on crash.

**`processed_events` is not append-forever.** Unpruned, it grows without bound and its primary-key index degrades every insert. Prune rows older than the maximum possible redelivery horizon — topic retention plus the longest tolerated consumer outage plus a margin. Prune *earlier* than that horizon and a late redelivery slips past the dedup check, reintroducing exactly the double-processing the table exists to prevent. The pruning window is therefore a designed number in the stage contract, not an ops afterthought.

---

## The Transactional Outbox at Stage Boundaries

A stage must not "do its work, then publish the next event" as two separate operations — a crash between them loses the event. Each stage writes its output event to an **outbox table in the same transaction** as its state change. A separate relay publishes outbox rows to the next topic.

```
[Entity Extraction transaction]
    INSERT extracted_entities (...)            -- state change
    INSERT outbox (event=EntityExtracted, ...) -- next event, same transaction
    COMMIT
                    │
        [Outbox relay] ──reads committed outbox rows──► publishes to (Topic: entity-extracted)
```

This guarantees the pipeline never loses an event between stages and never publishes an event for work that rolled back. (Pattern detail: architecture `event-driven-patterns`; the outbox table schema: domain-modeler `domain-event-catalog`.)

---

## Dead Letter Queue

A message that cannot be processed after a bounded number of retries is routed to a **Dead Letter Queue (DLQ)** — it must never block the pipeline or be silently dropped.

| Concern | Design |
|---|---|
| Retry policy | Retry with exponential backoff + jitter; cap attempts (e.g., 5) |
| What goes to DLQ | Messages that exhaust retries, or fail a poison-message check (malformed, un-decodable) |
| DLQ topic | One DLQ topic per stage: `<stage>-dlq`, carrying the original message + failure metadata |
| Tenant isolation | DLQ messages retain `tenant_id`; DLQ inspection is tenant-scoped |
| Disposition | Operator runbook: inspect, fix root cause, replay from DLQ or discard with audit record |

A DLQ with no monitoring is a silent failure. The DLQ depth is an alerting metric (see observability `alerting-rules-design`).

---

## Backpressure and Flow Control

When a downstream stage is slower than its upstream, the design must degrade gracefully, not collapse.

| Mechanism | Effect |
|---|---|
| Topic as buffer | Redpanda retains the backlog; a slow consumer builds lag without losing data or blocking the producer |
| Consumer lag metric | Lag per consumer group is monitored; sustained growth triggers scaling or alerting |
| Partitioning for parallelism | Topics partitioned by `tenant_id` (or asset id) so consumers scale horizontally via Competing Consumers |
| Bounded concurrency | Each consumer caps in-flight work to protect downstream stores from overload |
| Rate limiting at ingress | The worker tier throttles discovery so a huge estate cannot flood the pipeline faster than it drains |

**Partitioning rule:** the partition key is chosen for *ordering* first, parallelism second. All events for one Aggregate must land on one partition — key by `aggregateId` — or a consumer can apply `DataAssetClassified` before the `FileDiscovered` that created the asset. In the first product's physical multi-tenancy, topics are already tenant-scoped, so `aggregateId` keying gives per-Aggregate order *and* horizontal parallelism. In a shared-topic deployment, keying by `tenant_id` instead buys starvation isolation and per-tenant ordering — at the cost of capping each tenant's throughput at one partition. Name the trade-off you chose; do not inherit it by accident.

---

## Tenant Isolation in the Pipeline

- Every event envelope carries `tenant_id` end to end.
- Topics are partitioned by `tenant_id`; a consumer never processes two tenants' data in one unit of work that could leak across them.
- In physical multi-tenancy, each tenant's pipeline runs in its own deployment — the topics themselves are tenant-scoped. The `tenant_id` in the envelope remains the application-layer backstop.

---

## Pipeline Contract Specification

For each stage, the design documents a contract the implementer builds to:

| Field | Example |
|---|---|
| Stage name | Entity Extraction |
| Consumes (topic / event) | `file-processed` / `FileProcessed` |
| Emits (topic / event) | `entity-extracted` / `EntityExtracted` |
| Idempotency key | `eventId` of the consumed event |
| Delivery semantic | at-least-once |
| Retry / DLQ | 5 attempts, backoff+jitter → `entity-extraction-dlq` |
| State written | `extracted_entities` (metadata only — no raw PII) |
| Lineage emitted | source `data_asset_id` → produced entity ids (see data-lineage-design) |
| SLO | p95 processing latency < N s; max consumer lag < M |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Stages decoupled via topics | Stages communicate only through events | Stages calling each other synchronously |
| Idempotent consumers | Every stage dedups on event id | A stage that double-applies on redelivery |
| Transactional Outbox at boundaries | Output events written transactionally with state | Publish-after-commit two-step that can lose events |
| DLQ defined and monitored | Every stage has a DLQ + alert on depth | Failed messages dropped or blocking the stage |
| Backpressure handled | Lag monitored; partitioned for scale; bounded concurrency | Pipeline collapses or loses data under load |
| Tenant isolation end to end | `tenant_id` in every envelope; partitioned by tenant | Cross-tenant processing in one unit of work |
| Lineage emitted | Each stage records input→output provenance | Pipeline with no lineage trail |
| Dedup table lifecycle designed | `processed_events` pruned on a window ≥ the redelivery horizon | Unbounded growth, or pruning inside the redelivery window |

---

## Anti-Patterns

- **The dual write.** "Save the state, then publish the event" as two operations. A crash between them either loses the event (downstream never hears) or, in the publish-first ordering, announces work that rolled back. The Transactional Outbox exists precisely to make this impossible — there is no acceptable fast path around it.
- **"We'll deduplicate later."** Shipping a non-idempotent stage on the promise that duplicates are rare. At-least-once delivery makes redelivery a certainty, not an edge case; the first consumer-group rebalance under load corrupts data.
- **The orchestrator on the happy path.** A central coordinator invoking each stage in turn. It reintroduces the single point of failure and the deployment lockstep that choreography removed. Orchestration (a Saga) is reserved for flows needing coordinated compensation — not the default topology.
- **DLQ as landfill.** A Dead Letter Queue nobody monitors, with no runbook and no replay procedure. Dead-lettered messages are unprocessed customer data; a growing, un-alerted DLQ is silent data loss with extra steps.
- **Exactly-once everywhere.** Paying broker-transaction cost across every stage when idempotent consumers already make duplicates harmless. Exactly-once is a targeted tool for the rare non-idempotent-by-nature effect, not the pipeline default.
- **Raw content in the event.** Putting file contents or raw extracted PII values into pipeline events "so the next stage doesn't have to fetch". Payloads carry references and metadata — raw content in an immutable, replicated log is a privacy and retention liability (see `data-retention-policy`).
- **Retry without backoff or jitter.** Tight-loop retries that hammer a struggling downstream into full outage, and synchronized retries that arrive as a thundering herd. Every retry policy states its backoff curve, jitter, and attempt cap.

---

## Output Format

```markdown
---
name: data-pipeline-design
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: data-architect
---

# Data Pipeline Design

## Pipeline Topology
[Stage/topic flow diagram — choreography]

## Delivery Semantics
[Chosen semantic + idempotency approach]

## Stage Contracts
| Stage | Consumes | Emits | Idempotency key | Retry/DLQ | State written | SLO |
|---|---|---|---|---|---|---|

## Failure Handling
[Retry policy, DLQ topics, replay/runbook]

## Backpressure & Scaling
[Partitioning key, lag monitoring, concurrency bounds]
```
