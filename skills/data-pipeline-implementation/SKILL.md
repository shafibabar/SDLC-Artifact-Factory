---
name: data-pipeline-implementation
description: >
  Implement a data pipeline in Go — stage-worker processes on Redpanda consumer
  groups, idempotent processing and checkpointing for exactly-once/at-least-once
  delivery semantics, dead-letter queues with retry/backoff for poison records,
  backpressure under a large-estate initial scan, reprocessing/replay by offset
  reset, and lineage-metadata emission per stage — over this platform's Redpanda +
  PostgreSQL (pgx) stack. Triggers on: building or reviewing an ingestion or
  transformation pipeline stage worker, offset/checkpoint/resume handling, DLQ
  routing after N retries, exponential backoff with jitter, poison-record
  detection, at-least-once vs effective exactly-once, idempotent upsert on a dedup
  key, backfill/replay, log compaction vs time-based retention, pipeline lag /
  freshness / throughput instrumentation. Used by the data-engineer during
  Implement for every pipeline (e.g. Google Drive/S3 ingestion into the DataAsset
  store, entity extraction, compliance evaluation).
version: 2.0.0
phase: implement
owner: data-engineer
created: 2026-07-20
tags: [implement, data-engineering, pipeline, idempotency, checkpointing, dead-letter-queue, exactly-once, lineage, go]
related: [data-pipeline-design, data-lineage-design, go-event-consumer, go-service-skeleton, opentelemetry-instrumentation, data-quality-rules]
---

# Data Pipeline Implementation

## Purpose

The data-architect designs the pipeline's topology, delivery semantics, and per-stage contracts (`data-pipeline-design`). This skill implements that blueprint: the worker processes that pull events off Redpanda topics, do the offline transformation work (file processing, entity extraction, compliance evaluation), and emit the next stage's events — built to the stage contracts already written, not redesigned here.

The question is not *what* the stages should be — that is `data-pipeline-design`. It is *how* to build a correct, resumable, backpressure-aware worker that honors the design's guarantees under real failure: crashes, redeploys, broker rebalances, poison records, and slow downstream stores.

---

## Boundary: Pipeline Stage Workers vs. Request-Path Consumers

The single most important distinction, because the code looks superficially the same.

| | Request-path consumer (`go-event-consumer`, backend-engineer) | Pipeline stage worker (this skill, data-engineer) |
|---|---|---|
| Triggered by | A user-facing Command completing | A prior stage's output event (`FileDiscovered` → `FileProcessed` → `EntityExtracted` → …) |
| Latency | Low — a user or adjacent service is waiting | Best-effort throughput — an estate backlog processed over minutes to hours |
| Work per record | Small, bounded state reaction | Heavy, long-running transformation (parsing, OCR, extraction, rule evaluation) |
| Owned by | backend-engineer | data-engineer |

**Shared, not reinvented:** the idempotent-consumer transaction shape, bounded worker pool, retry-then-DLQ mechanics, and graceful drain all come from `go-event-consumer` and apply identically. What differs is everything *inside* `handleRecord`: a stage worker may spend seconds to minutes per record, needs unit-level checkpointing for partial progress on large files, and must reason about backpressure across a whole estate scan.

A stage worker is a standalone deployable — its own container, its own scaling policy — never a goroutine inside a request-serving API process. This matches the choreography topology from `data-pipeline-design`: independently deployable, independently scalable stages. The composition root wires telemetry, the Redpanda client, and the pgx pool exactly as `go-service-skeleton` does.

---

## Delivery Semantics: At-Least-Once + Idempotent Consumer = Effective Exactly-Once

Redpanda gives at-least-once delivery: an offset is committed *after* a record is handled, so a crash between handling and commit redelivers. True broker-level exactly-once (transactional producer + read-committed) exists but carries real cost and operational burden that `fundamentals-of-data-engineering` warns against paying reflexively.

**The default and the rule:** take at-least-once delivery and make the *consumer* idempotent, so a redelivered record produces no duplicate effect. That combination is **effectively exactly-once** — the semantics the pipeline actually needs — without the broker-transaction machinery. Every stage's write is an idempotent upsert keyed on a natural/dedup key (the consumed event's id), inside the same transaction as the outbox write for the next stage.

Full mechanism — consumer-group offset management, the dedup-key upsert pattern, when broker exactly-once is genuinely warranted, and Go code: **`references/stage-workers-and-semantics.md`**. That reference also covers **reprocessing/replay** — resetting a consumer group's offset to the start of a topic to backfill derived state when a stage's logic changes or a stage is added late — and the **log-compaction vs. time-based-retention** topic-config decision that determines whether replay is even possible.

---

## Idempotency + Checkpointing: Two Different Guards

These are orthogonal and a stage that processes large files needs both:

- **Event-level idempotency** (`processed_events` dedup on `eventId`) guards against redoing an already-*completed* event. It only helps once the event's whole transaction has committed.
- **Unit-level checkpointing** guards against redoing already-*completed work within* an in-progress event. A stage parsing a 500-page PDF cannot restart from page 1 after every pod eviction; the checkpoint records the last completed unit (page, sheet, paragraph block) so a restart resumes from `LastUnitIndex + 1`.

The checkpoint is written in the **same transaction** as the unit's extracted output, so a crash mid-file leaves the checkpoint and the extracted-so-far entities consistent — never one ahead of the other. This is what keeps a large initial estate scan tractable under normal pod churn. Worked crash-and-resume walkthrough and Go code: **`references/stage-workers-and-semantics.md`**.

---

## DLQ and Retry for Poison Records

A poison record is one that will never succeed no matter how often it is retried (an undecodable envelope, an unsupported file type). Distinguish it from a *transient* failure (a momentary storage-fetch timeout) worth retrying:

- **Transient** → retry in place with **exponential backoff + jitter**, up to the stage contract's attempt cap.
- **Permanent (poison)** → route straight to the DLQ, no retry.
- **Attempt cap exhausted** → route to the DLQ after N retries.

The retry policy, attempt cap, and DLQ topic name are read from the stage's `data-pipeline-design` contract — not reinvented per worker. Tenant id and original payload travel with the DLQ record so DLQ tooling stays tenant-scoped. The offset is committed only once the record is durably in the DLQ; if the DLQ produce fails, do not commit — let redelivery retry the whole thing.

Poison detection, DLQ topic routing, backoff-with-jitter formula, partial-failure handling, and replay-from-DLQ — with Go code: **`references/error-handling-and-dlq.md`**.

---

## Backpressure

An initial large-estate scan can enqueue hundreds of thousands of `FileDiscovered` events at once. The stage must not race to drain them.

- **Bounded worker pool** sized to the stage's *actual* per-unit cost — extraction holds a decoded document in memory, so its concurrency is deliberately far lower than a lightweight consumer's (e.g. 4, not 64). Unbounded concurrency "for throughput" is the surest way to OOM-kill the pod under a large scan; bounded concurrency here is a correctness property, not a nicety.
- **Consumer lag is the throttle signal.** The stage does not fake keeping up — Redpanda retains the backlog and lag is the monitored queue depth.
- **Per-tenant fairness** follows from partitioning by `aggregateId`/tenant, so one tenant's huge scan cannot starve another's steady-state trickle.
- **Downstream store protection:** database writes are batched/rate-limited so a burst does not exhaust the pgx pool shared with the request API.

---

## Lineage and Observability Are Pipeline Responsibilities

Two production concerns the worker owns directly, not as afterthoughts:

- **Lineage emission per stage.** Every stage writes its assigned `data-lineage-design` capture point to `lineage_edges` in the **same transaction** as its state change and outbox insert — never a separate, best-effort side call. `ON CONFLICT DO NOTHING` on the natural key keeps capture idempotent under the same at-least-once redelivery everything else tolerates. Async/fire-and-forget lineage is `data-lineage-design`'s "async collector" anti-pattern reintroduced at the implementation layer.
- **Data observability of the worker itself** (`fundamentals-of-data-engineering`'s DataOps undercurrent): freshness of the extraction backlog, volume anomalies (files-per-hour), and source schema drift are continuously-monitored *operational* signals — distinct from the per-record quality gates owned by `data-quality-rules`, and distinct from lineage.

Lineage-edge emission, OpenTelemetry pipeline metrics (records processed/failed, consumer lag, throughput, backlog freshness), the observability pillars, and Go instrumentation: **`references/lineage-and-observability.md`**.

---

## The Python Exception

**Default is Go, per CLAUDE.md.** A stage is Go unless it genuinely depends on a library or model with no viable Go equivalent — most commonly OCR/ML extraction. This is a narrow, *named* exception, recorded in an ADR or the stage's contract, never a silent default or a familiarity choice. A justified Python stage still honors every correctness obligation here — event-id dedup, the same outbox/transactional discipline, lineage, DLQ — via `psycopg` against the same schema. Python changes the language, not the obligations, and remains a separately deployed, separately scaled service.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Boundary respected | Stage workers separate from request-path consumers | Heavy transformation inside an API process |
| Effective exactly-once | At-least-once + idempotent upsert keyed on the event id, in one tx | Broker-exactly-once bolted on, or no dedup guard |
| Event- *and* unit-level guards | Large files resume from last completed unit, checkpoint in the unit's tx | Full-file reprocessing on every restart |
| Poison vs transient distinguished | Permanent errors go straight to DLQ; transient retried with backoff+jitter | Everything retried, or everything DLQ'd |
| DLQ per contract | Retry/cap/topic match the stage contract | Ad hoc DLQ policy per worker |
| Backpressure-aware | Concurrency sized to per-unit cost; lag is the throttle | Unbounded concurrency that OOMs |
| Lineage transactional | `lineage_edges` written in the state-change tx, deduped on natural key | Async or out-of-transaction lineage |
| Replay considered | Topic retention (time-based vs compacted) chosen against reprocessing need | Retention left to default, replay impossible |
| Python exception justified | Non-Go stage names the specific library gap, recorded as a decision | Python chosen silently |

## Anti-Patterns

- **Pipeline work in the API process** — breaks independent scaling; a slow extraction burst degrades unrelated request latency.
- **Event-level idempotency without unit-level checkpointing** — a crash mid-file with no checkpoint restarts the whole file; does not scale to large documents.
- **Checkpoint written outside the unit's transaction** — a crash between the two leaves them disagreeing about progress.
- **Unbounded concurrency "for throughput"** — a stage that OOMs during a large scan is a backpressure failure, not bad luck.
- **DLQ policy invented per worker** — divergent retry curves make pipeline failure behavior unpredictable across stages.
- **Async or best-effort lineage** — `data-lineage-design`'s async-collector anti-pattern at the implementation layer.
- **Silent Python creep** — reaching for Python out of familiarity without a documented library gap.
- **Ignoring topic retention** — a stage silently log-compacted has no history left to replay when its logic later changes.

## Output Format

Go (or explicitly justified Python) source plus TDD-first integration tests (Redpanda + PostgreSQL via testcontainers), including a crash-mid-file resume test and a duplicate-delivery test. Full package layout and the stage-implementation artifact template: **`references/stage-workers-and-semantics.md`**.
