---
name: data-pipeline-design
description: >
  Design a data pipeline topology in the Design phase — the batch vs streaming vs
  micro-batch decision (driven by business-decision latency, volume, and source
  generation semantics), ELT vs ETL vs streaming-transform, stage decomposition,
  fault-tolerance as a design property (checkpoint boundaries, replayability,
  idempotent stages, exactly-once cost), backfill/reprocessing, and orchestration
  (choreography vs a coordinating Saga, the DAG model, SLA/freshness targets,
  pipeline observability). The design-phase counterpart to data-pipeline-implementation.
  Used when a new data flow between systems is defined — ingestion, CDC, event
  stream processing, or scheduled batch. Produced by the data-architect.
version: 2.0.0
phase: design
owner: data-architect
created: 2026-06-25
tags: [design, data-architecture, pipeline, batch, streaming, fault-tolerance, elt, orchestration]
produces: data-pipeline-design
domain: data
status: stable
related: [data-pipeline-implementation, event-driven-patterns, data-lineage-design, metrics-instrumentation-plan, data-retention-policy, alerting-rules-design, domain-event-catalog]
---

# Data Pipeline Design

## Purpose

A data pipeline moves data through staged transformations from a source system to its
destination stores. This skill designs the pipeline's **topology and its design-level
guarantees**: the processing mode, where transformation happens, how stages are decomposed, how
the pipeline behaves under failure, and how it is coordinated and observed. `data-pipeline-implementation`
builds to this design; the backend-engineer builds the producers and consumers. For the first
product the pipeline is the core engine — files discovered at customer storage become classified,
graph-linked, compliance-evaluated knowledge without raw content leaving customer infrastructure.
Design it as a topology decision, not an inherited default.

---

## Frame the flow on the lifecycle first

Before choosing anything, name which lifecycle stage the flow touches — **generation, storage,
ingestion, transformation, serving** (Reis & Housley) — and, critically, treat **generation as a
design input**: what does the source system guarantee about change notification, ordering, and
rate? Google Drive / S3 are third-party stores this product cannot influence; there is no native
CDC feed, ordering across a bulk scan is not guaranteed, and rate is bursty. Those constraints
bound what `FileDiscovered` can promise and are the reason the bulk scan and the steady-state
change flow are two load regimes, not one. Full lifecycle framing: `references/topology-decision.md`.

---

## Decision 1 — Batch vs Streaming vs Micro-Batch

"Just make it streaming" is a trade-off to justify, not a default. True sub-second streaming
carries real cost (stateful processing, exactly-once machinery, operational burden). The
governing question is **what latency does the business decision this data supports actually
require** — map that latency to a mode:

| Decision-latency budget | Mode | Why |
|---|---|---|
| Hours or more | Scheduled batch | Cheapest; run on a trigger |
| Seconds to a few minutes | **Micro-batch (default bias)** | Most of the "real-time" benefit at a fraction of the cost |
| Sub-second, per-event action | True streaming | Only when a single late event changes an immediate action |

For a compliance product, no reviewer acts on one file's classification within a second of it
landing — micro-batch is the default. Reserve true streaming for the narrow case where sub-second
latency is a genuine requirement (e.g. blocking an external share the instant a Special Category
is detected). Full criteria table, latency bands, and worked examples (bulk scan, steady-state,
the streaming counter-example): `references/topology-decision.md`.

---

## Decision 2 — ELT vs ETL vs Streaming-Transform

A second, orthogonal choice: **where** transformation happens relative to storage.

- **ETL** — transform then load; discards raw. **ELT** — load raw, transform in place (re-derivable).
- **Streaming-transform** — transform in-flight at each stage, then land derived. **This product's
  choice**, made deliberately: privacy/residency forbids a raw-content landing zone, and per-stage
  scaling avoids an orchestrator bottleneck.

Record it as a decision with the alternative named and rejected — never inherit it by accident.
Name the cost honestly: streaming-transform has no ELT-style "re-run the transform against the
retained raw load," so logic changes reprocess from the event log instead. Full tradeoff and the
parsed-content-artifact lever: `references/topology-decision.md`.

---

## Stage decomposition

Decompose the flow into stages of **one concern each**, communicating only through Redpanda topics
— never direct calls. This is **Event Choreography**: each stage reacts to the event the previous
stage emitted.

```
[Worker @ customer storage] ──FileDiscovered──► (file-discovered)
     ──► [File Processing] ──FileProcessed──► (file-processed)
          ──► [Entity Extraction] ──EntityExtracted──► (entity-extracted)
               ├─► [Graph Update]     (Apache AGE)
               ├─► [Classification]   (sensitivity)
               └─► [Compliance Rule Engine] ──ComplianceEvaluated──► [Alert + Audit] ─► audit log
```

A stage that silently mixes ingestion and transformation concerns is a smell. One concern per stage
keeps each independently deployable and scalable, and the fault-tolerance design below tractable.

---

## Fault-tolerance as a design property

Fault tolerance is decided here, not left to implementation. Four design rules — full mechanism
designs (delivery-semantics table, dedup/outbox contracts, DLQ design, exactly-once cost, replay
and backfill, per-topic retention) live in `references/fault-tolerance-design.md`:

1. **Delivery semantic: at-least-once + idempotent consumers by default.** The broker loses nothing;
   idempotency makes the inevitable redelivery harmless — without paying exactly-once cost.
2. **Checkpoint boundaries at the state-commit.** Each stage commits derived state and records the
   consumed offset/event-id in the *same* transaction; never advance the offset before the work and
   its outbox row commit. That atomic unit is the checkpoint.
3. **Every mutating stage is idempotent** — by upsert-on-stable-key or dedup-on-`eventId`. Decide the
   mechanism per stage at design time; redelivery is a certainty under at-least-once, not an edge case.
4. **Replayability is designed in.** The topic is a replayable history: a consumer group can reset
   its offset to reprocess when a stage's logic changes or a stage is added late — no new code path,
   because stages are already idempotent and checkpointed. This forces a per-topic retention choice
   (time-based vs. log compaction); a silently compacted topic has no history to replay against.

Reserve **exactly-once** for externally-visible, non-idempotent effects (a notification, a paid API
call) via an idempotency key on that one call — not broker transactions across every stage.

---

## Orchestration

Coordinate stages by **choreography** (each reacts to events) by default — loosely coupled,
independently scalable, no central bottleneck or single point of failure. Reserve **orchestration
(a Saga)** for flows needing coordinated compensation (step 3 fails → roll back steps 1–2 in order);
do not put an orchestrator on the happy path "for visibility." Scheduled/batch flows are the
exception where a **DAG** orchestrator fits — model nodes, dependencies, triggers, and per-node
retry. Every flow states its **SLA/freshness targets** (they drive alerting) and its **observability
signals** — freshness, volume, distribution, schema, lineage — with thresholds, handing the metric
definitions to `metrics-instrumentation-plan` and alert rules to `alerting-rules-design`. Full DAG
model, backpressure/partitioning, SLA table, and the five observability pillars:
`references/orchestration-and-observability.md`.

---

## Tenant isolation in the pipeline

Every event envelope carries `tenant_id` end to end; topics are partitioned so a consumer never
processes two tenants' data in one unit of work that could leak across them. In physical
multi-tenancy each tenant's pipeline runs in its own deployment — topics are tenant-scoped; the
`tenant_id` in the envelope remains the application-layer backstop.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Processing mode justified | Latency budget named; mode chosen against it | Streaming by reflex, no latency requirement stated |
| Transform placement recorded | ELT/ETL/streaming-transform chosen, alternative rejected | Topology inherited, choice implicit |
| Stages single-concern & decoupled | One concern per stage, topics only | A stage mixing ingestion + transformation, or synchronous calls |
| Delivery + idempotency designed | at-least-once + per-stage idempotency mechanism named | Non-idempotent stage on at-least-once delivery |
| Checkpoint at state-commit | Offset + work + outbox commit atomically | Offset advanced before work commits |
| Replay/retention decided | Per-topic retention chosen against backfill need | Topic silently compacted, no replay history |
| Orchestration chosen deliberately | Choreography default; Saga only for compensation | Orchestrator on the happy path |
| SLA + observability designed | Freshness/lag SLOs + 5 observability signals with thresholds | No freshness contract; drift undetectable |
| Tenant isolation end to end | `tenant_id` in every envelope; partitioned by tenant | Cross-tenant processing in one unit of work |

---

## Anti-Patterns

- **Streaming by reflex.** Choosing sub-second streaming with no business-decision latency
  requirement — paying stateful-processing and exactly-once cost for a minutes-budget workload.
- **The implicit topology.** Never recording *why* streaming-transform was chosen over ELT, so the
  choice cannot be revisited when residency or reprocessing needs change.
- **The orchestrator on the happy path.** A central coordinator invoking each stage in turn —
  reintroducing the single point of failure and deployment lockstep choreography removes.
- **"We'll deduplicate later."** Shipping a non-idempotent stage betting duplicates are rare;
  at-least-once makes redelivery a certainty, and the first rebalance under load corrupts data.
- **Silent log compaction.** Leaving a topic compacted with no deliberate retention decision, then
  discovering at backfill time there is no history to replay against.
- **Exactly-once everywhere.** Paying broker-transaction cost across every stage when idempotent
  consumers already make duplicates harmless — it is a targeted tool, not the default.
- **The unobserved pipeline.** No freshness/volume/schema signals, so a stalled stage or a source
  outage shows up as a silently stale compliance number, not an alert.

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

## Topology Decision
[Lifecycle stages touched; processing mode (batch/micro-batch/streaming) + latency budget;
 transform placement (ELT/ETL/streaming-transform) + rejected alternative; data-flow pattern]

## Pipeline Topology
[Stage/topic choreography diagram — one concern per stage]

## Stage Contracts
| Stage | Consumes | Emits | Idempotency key | Delivery | Retry/DLQ | State | Partition key | SLO |
|---|---|---|---|---|---|---|---|---|

## Fault Handling
[Checkpoint boundaries; per-stage idempotency mechanism; exactly-once cases; DLQ;
 replay/backfill approach; per-topic retention (time-based vs compacted)]

## Orchestration & Observability
[Choreography vs Saga; any batch DAG + triggers; SLA/freshness targets;
 observability signals (freshness/volume/distribution/schema/lineage) + thresholds]
```
