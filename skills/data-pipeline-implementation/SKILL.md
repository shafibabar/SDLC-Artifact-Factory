---
name: data-pipeline-implementation
description: >
  Teaches how to implement the data-architect's `data-pipeline-design` blueprint —
  the offline/async pipeline stage workers (file processing, entity extraction,
  compliance rule engine) as distinct from the backend-engineer's request-path
  producers and consumers. Covers idempotent stage processing keyed by Domain Event
  id, checkpoint/resume on restart, backpressure handling, DLQ wiring, and lineage
  emission per `data-lineage-design`'s capture points, with a Go worker skeleton
  (Python permitted only as a justified exception for genuine ML/extraction
  library needs). Used by the data-engineer during Data.
version: 1.0.0
phase: data
owner: data-engineer
created: 2026-07-20
tags: [data, pipeline, worker, redpanda, idempotency, checkpoint, backpressure, dlq, lineage, go]
---

# Data Pipeline Implementation

## Purpose

The data-architect designs the pipeline's topology, delivery semantics, and per-stage contracts (`data-pipeline-design`). This skill implements that blueprint: the actual worker processes that pull events off Redpanda topics, do the offline transformation work (file processing, entity extraction, compliance evaluation), and emit the next stage's events — built to the stage contracts the data-architect wrote, not redesigned from scratch here.

This is not domain expertise about *what* the pipeline stages should be — that question is answered by `data-pipeline-design`. This skill is about *how* to build a correct, resumable, backpressure-aware worker that honors that design's guarantees under real failure conditions: crashes, redeploys, broker rebalances, and slow downstream stores.

---

## Boundary: Pipeline Stage Workers vs. Request-Path Consumers

This is the most important distinction in this skill, and it must be explicit because the code patterns look superficially similar.

| | Request-path consumer (`go-event-consumer`, backend-engineer) | Pipeline stage worker (this skill, data-engineer) |
|---|---|---|
| Triggered by | A user-facing Command completing (e.g., `ClassifyDataAsset` succeeding triggers a notification consumer) | A prior pipeline stage's output event (`FileDiscovered` → `FileProcessed` → `EntityExtracted` → …) |
| Latency expectation | Low — the user or an adjacent service is often waiting on the effect | Best-effort throughput — the pipeline processes an estate's backlog over minutes to hours, not milliseconds |
| Work performed | Small, bounded application-layer reactions (send a notification, update a projection) | Heavy, potentially long-running transformation (file parsing, OCR, entity extraction, rule evaluation) |
| Owned by | backend-engineer | data-engineer |
| Shares | The idempotent-consumer pattern, the consume loop shape, the DLQ mechanics — all from `go-event-consumer`, reused here, not reinvented | — |

**What's shared, and what isn't:** the idempotent-consumer pattern, bounded worker pool, retry-then-DLQ mechanics, and graceful drain from `go-event-consumer` apply identically here — this skill does not redefine them, it reuses them for a different workload shape. What differs is everything about *what happens inside* `handleRecord`: a request-path consumer does a small, fast state update; a pipeline stage worker may spend seconds to minutes doing CPU- or I/O-heavy transformation, needs checkpointing for partial progress on large files, and must reason about backpressure across an entire estate scan rather than a single request.

---

## Stage Worker Structure

A stage worker is a standalone deployable process (its own container, its own scaling policy) — never a goroutine embedded inside a request-serving API process. This matches the choreography topology from `data-pipeline-design`: independently deployable, independently scalable stages.

```
cmd/
  entity-extraction-worker/
    main.go                    # composition root: config, telemetry, consumer, graceful shutdown
internal/
  pipeline/
    entityextraction/
      worker.go                 # consume loop + handleRecord (built on go-event-consumer's pattern)
      extract.go                 # the actual extraction logic (file-type dispatch)
      checkpoint.go               # per-file progress tracking for resumability
      lineage.go                  # lineage_edges emission for this stage
```

The composition root (`main.go`) wires telemetry (`opentelemetry-instrumentation`), the Redpanda client, and the PostgreSQL pool exactly as a backend-engineer service would (`go-service-skeleton`) — the wiring pattern is shared infrastructure, not pipeline-specific.

---

## Idempotent Stage Processing Keyed by Domain Event ID

Every stage reuses the exact idempotent-consumer transaction shape from `go-event-consumer` and `data-pipeline-design`: dedup on the consumed event's `eventId`, do the work, write the outbox row for the next stage's event, commit — all in one transaction.

```go
// internal/pipeline/entityextraction/worker.go
func (w *Worker) handleRecord(ctx context.Context, rec *kgo.Record) {
    ctx = otel.GetTextMapPropagator().Extract(ctx, kafkaHeaderCarrier{rec})
    ctx, span := w.tracer.Start(ctx, "entity-extraction.process")
    defer span.End()

    env, err := decodeEnvelope(rec.Value) // FileProcessed event
    if err != nil {
        w.toDLQ(ctx, rec, fmt.Errorf("undecodable: %w", err))
        return
    }

    err = w.withRetry(ctx, func() error {
        tx, err := w.pool.Begin(ctx)
        if err != nil {
            return err
        }
        defer tx.Rollback(ctx) //nolint:errcheck

        ct, err := tx.Exec(ctx,
            `INSERT INTO processed_events (consumer_name, event_id) VALUES ($1,$2)
             ON CONFLICT DO NOTHING`, w.stageName, env.EventID)
        if err != nil {
            return err
        }
        if ct.RowsAffected() == 0 {
            return tx.Commit(ctx) // already processed — redelivery, no-op
        }

        result, err := w.extractEntities(ctx, tx, env) // the stage's actual work
        if err != nil {
            return fmt.Errorf("extraction: %w", err)
        }

        if err := w.emitLineage(ctx, tx, env, result); err != nil { // same tx — see below
            return fmt.Errorf("lineage: %w", err)
        }

        for _, entity := range result.Entities {
            payload, _ := json.Marshal(entityExtractedPayload(entity))
            if _, err := tx.Exec(ctx, `
                INSERT INTO outbox (id, aggregate_id, tenant_id, event_type, payload, occurred_at)
                VALUES ($1,$2,$3,'EntityExtracted',$4, now())`,
                uuid.New(), env.AggregateID, env.TenantID, payload); err != nil {
                return fmt.Errorf("outbox: %w", err)
            }
        }
        return tx.Commit(ctx)
    })
    if err != nil {
        w.toDLQ(ctx, rec, err)
        span.RecordError(err)
    }
}
```

This is deliberately the same shape as `go-event-consumer`'s `handleRecord` — the pattern is not stage-specific. What's new below is what a *long-running, resumable* stage needs on top of it.

---

## Checkpoint / Resume on Restart

A request-path consumer's unit of work completes in milliseconds — a crash mid-processing simply redelivers the whole event, cheaply. A pipeline stage processing a 500-page scanned PDF cannot afford to restart from page 1 after every pod restart; large-file processing needs its own checkpoint, independent of the outer event-level idempotency.

```go
// internal/pipeline/entityextraction/checkpoint.go
//
// A checkpoint records how far into a single file's extraction we got,
// so a restart resumes from the last completed unit (e.g., page or sheet)
// rather than reprocessing the whole file. This is orthogonal to the
// processed_events dedup: that guards against redoing an already-*completed*
// event; the checkpoint guards against redoing already-*completed work
// within* an in-progress event.

type Checkpoint struct {
    RunID          uuid.UUID
    DataAssetID    uuid.UUID
    LastUnitIndex  int       // e.g., last fully-processed page/sheet index
    UpdatedAt      time.Time
}

func (w *Worker) checkpointedExtract(ctx context.Context, tx pgx.Tx, run ExtractionRun) (Result, error) {
    cp, err := loadCheckpoint(ctx, tx, run.ID)
    if err != nil && !errors.Is(err, pgx.ErrNoRows) {
        return Result{}, err
    }
    startUnit := 0
    if cp != nil {
        startUnit = cp.LastUnitIndex + 1 // resume after the last completed unit
    }

    var entities []Entity
    for i, unit := range run.Units[startUnit:] {
        found, err := extractUnit(ctx, unit) // page, sheet, or paragraph
        if err != nil {
            return Result{}, fmt.Errorf("unit %d: %w", startUnit+i, err)
        }
        entities = append(entities, found...)

        if err := saveCheckpoint(ctx, tx, run.ID, startUnit+i); err != nil {
            return Result{}, fmt.Errorf("checkpoint: %w", err)
        }
    }
    return Result{Entities: entities}, nil
}
```

The checkpoint is written in the **same transaction** as the unit's extracted output — so a crash mid-file leaves the checkpoint and the extracted-so-far entities consistent with each other, never one ahead of the other. On restart, the worker resumes from `LastUnitIndex + 1` instead of reprocessing the whole file — this is what keeps a large-estate initial scan tractable under normal pod churn (deploys, autoscaling, spot eviction).

---

## Backpressure Handling

Pipeline stages face a backpressure shape `go-event-consumer`'s request-path guidance doesn't fully cover: an initial large-estate scan can enqueue hundreds of thousands of `FileDiscovered` events at once, all landing on the extraction stage's input topic simultaneously.

| Mechanism | Applied here |
|---|---|
| Bounded worker pool | Same `errgroup.SetLimit` as `go-event-consumer`, sized to the stage's actual resource cost (extraction is CPU/memory-heavy per file — set the limit much lower than a lightweight request consumer would) |
| Consumer lag as the throttle signal | The stage does not try to "keep up" artificially; Redpanda retains the backlog, and consumer lag is the visible, monitored queue depth (`data-pipeline-design`) |
| Per-tenant fairness | Because topics are partitioned by `aggregateId`/tenant (`data-pipeline-design`'s partitioning rule), one tenant's huge initial scan cannot starve another tenant's steady-state trickle of updates, as long as partition count and consumer group size give every tenant partition a fair shot at a worker |
| Downstream store protection | The stage's own database writes are batched/rate-limited so a burst of extraction results doesn't overwhelm PostgreSQL connection pool capacity shared with the request-serving API |

```go
// Concurrency is sized to the stage's actual cost, not maxed out —
// extraction is memory-heavy (holds a decoded document in memory per
// in-flight unit), so this is deliberately much lower than a typical
// lightweight consumer's concurrency.
w.pool.SetLimit(cfg.ExtractionConcurrency) // e.g., 4, not 64
```

A stage worker that races to drain its topic as fast as possible, ignoring the cost per unit of work, is the surest way to OOM-kill the pod under a large initial scan — bounded concurrency here is a correctness property, not just a nicety.

---

## DLQ Wiring Per the Blueprint's Contract

The stage's DLQ wiring implements exactly the contract `data-pipeline-design` specified for it — retry policy, attempt cap, and DLQ topic name are read from that stage's contract table, not reinvented per worker.

```go
func (w *Worker) toDLQ(ctx context.Context, rec *kgo.Record, cause error) {
    dlqRec := &kgo.Record{
        Topic: w.stageName + "-dlq", // per data-pipeline-design's naming convention
        Value: rec.Value,
        Headers: append(rec.Headers,
            kgo.RecordHeader{Key: "dlq-reason", Value: []byte(cause.Error())},
            kgo.RecordHeader{Key: "dlq-stage", Value: []byte(w.stageName)},
        ),
    }
    if err := w.dlqProducer.ProduceSync(ctx, dlqRec).FirstErr(); err != nil {
        slog.ErrorContext(ctx, "failed to route to DLQ — record will be redelivered", "err", err)
        return // do not commit the offset; let redelivery retry the whole thing
    }
    // Only safe to consider this record "handled" once it's durably in the DLQ.
}
```

Tenant ID and the original payload travel with the DLQ record, per `data-pipeline-design`'s tenant-isolation-in-DLQ requirement — DLQ inspection tooling remains tenant-scoped even for failed records.

---

## Lineage Emission Per Stage

Every stage implements the specific capture point `data-lineage-design` assigned to it, writing to `lineage_edges` in the **same transaction** as the stage's state change and outbox insert — never as a separate, best-effort side call.

```go
// internal/pipeline/entityextraction/lineage.go
func (w *Worker) emitLineage(ctx context.Context, tx pgx.Tx, env Envelope, result Result) error {
    for _, entity := range result.Entities {
        _, err := tx.Exec(ctx, `
            INSERT INTO lineage_edges
                (id, tenant_id, job_name, run_id, input_dataset, input_ref,
                 output_dataset, output_ref, occurred_at)
            VALUES ($1,$2,'entity-extraction',$3,'data_assets',$4,
                    'extracted_entities',$5, now())
            ON CONFLICT ON CONSTRAINT lineage_edge_natural_key DO NOTHING`,
            uuid.New(), env.TenantID, env.RunID, env.AggregateID, entity.ID)
        if err != nil {
            return fmt.Errorf("lineage edge for entity %s: %w", entity.ID, err)
        }
    }
    return nil
}
```

The `ON CONFLICT ... DO NOTHING` on the natural key is what makes lineage capture idempotent under the same at-least-once redelivery that every other part of the stage must tolerate (`data-lineage-design`'s idempotent-capture requirement).

---

## The Python Exception

**Default is Go, per CLAUDE.md's tech stack.** A pipeline stage worker is written in Go unless a specific stage genuinely depends on a library or model ecosystem that has no viable Go equivalent — most commonly OCR/ML-based extraction (e.g., a document-layout or OCR model only available via a mature Python library). This is a deliberate, narrow, and named exception — never a silent default or a convenience choice ("the data-engineer just prefers Python").

When a stage justifies the exception:

- The exception is recorded explicitly (an ADR, or a note in the stage's contract in `data-pipeline-design`) — stating which library/model requires it and confirming no Go equivalent was viable.
- The stage still honors every contract in this skill: idempotent processing keyed by event id, the same outbox/transactional-boundary discipline (via a Go-compatible client library or a thin transactional wrapper), lineage emission, and DLQ wiring. Python changes the language, not the correctness obligations.
- The stage remains a separately deployed, separately scaled service — it does not become a shared dependency that pulls Python tooling into the rest of the Go codebase.

```python
# internal/pipeline/ocr-fallback-worker/worker.py
# Exception justified: uses <ocr-library>, no equivalent Go binding exists.
# Still honors: idempotent dedup on event_id (same processed_events table,
# same ON CONFLICT DO NOTHING pattern), transactional outbox write,
# lineage emission, DLQ routing — via psycopg + the same PostgreSQL schema.
```

If a future stage's "we need Python" claim turns out to be avoidable (a Go library matures, or the need was really just familiarity), that is exactly the kind of budget/frugality tradeoff CLAUDE.md requires flagging rather than accepting quietly.

---

## Worked Example — Entity-Extractor Stage Worker for PDF/DOCX/XLSX

The Entity Extraction stage (`data-pipeline-design`'s topology) consumes `FileProcessed` and emits `EntityExtracted`. Its worker dispatches by file type, each with a different unit-of-work granularity for checkpointing:

```go
// internal/pipeline/entityextraction/extract.go
func (w *Worker) extractEntities(ctx context.Context, tx pgx.Tx, env Envelope) (Result, error) {
    fileType := env.Payload.FileType // "pdf" | "docx" | "xlsx"

    run := ExtractionRun{ID: env.RunID, DataAssetID: env.AggregateID}
    switch fileType {
    case "pdf":
        run.Units = pdfPages(env.Payload.StorageRef)       // checkpoint granularity: page
    case "docx":
        run.Units = docxParagraphs(env.Payload.StorageRef) // checkpoint granularity: paragraph block
    case "xlsx":
        run.Units = xlsxSheets(env.Payload.StorageRef)     // checkpoint granularity: sheet
    default:
        return Result{}, fmt.Errorf("%w: unsupported file type %q", ErrPermanent, fileType)
    }

    return w.checkpointedExtract(ctx, tx, run)
}
```

`ErrPermanent` is checked by `withRetry` to distinguish "will never succeed, don't retry, go straight to DLQ" (an unsupported file type) from a transient failure worth retrying (a momentary storage-fetch timeout) — the same transient-vs-permanent distinction `go-event-consumer` already establishes, reused here.

A 40-page scanned PDF crashes mid-extraction at page 23 (pod eviction during a rolling deploy). On restart:
1. The stage's outer consumer redelivers the `FileProcessed` event (at-least-once).
2. `processed_events` dedup check: this event was **not yet fully committed** (the transaction that would have marked it done never committed), so it is *not* skipped — correctly, since no `EntityExtracted` event was ever emitted.
3. `checkpointedExtract` loads the checkpoint, finds `LastUnitIndex = 22`, and resumes from page 23 — not page 1.
4. Extraction completes; lineage edges for all 40 pages' entities are written; the `EntityExtracted` outbox row is written; the outer transaction commits.

No duplicate work beyond the one in-flight page at crash time, no lost progress, and no `EntityExtracted` event emitted until the whole file is genuinely done.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Boundary respected | Stage workers are separate deployables from request-path consumers; no pipeline transformation embedded in an API service | Heavy extraction work running inside the request-serving process |
| Idempotent at the event level | Dedup on `eventId` in the same transaction as the work and outbox write | Work applied without the dedup guard, or dedup in a separate transaction |
| Checkpointed at the unit level | Large files resume from the last completed unit, written in the same tx as the unit's output | Full-file reprocessing from scratch on every restart |
| Backpressure-aware | Concurrency sized to actual per-unit cost; lag is the accepted throttle signal | Unbounded or over-provisioned concurrency that OOMs under a large scan |
| DLQ per contract | Retry/attempt-cap/topic-name match the stage's `data-pipeline-design` contract exactly | Ad hoc DLQ policy invented per worker |
| Lineage transactional | `lineage_edges` written in the same tx as the state change, deduplicated on the natural key | Lineage emitted async or outside the transaction |
| Python exception justified | Any non-Go stage names the specific library/model need and is recorded as a deliberate exception | Python chosen silently, or without checking a Go alternative first |

---

## Anti-Patterns

- **Pipeline work in the API process.** Running entity extraction as a goroutine inside the request-serving service "to keep it simple." This breaks independent scaling and deployment — a slow extraction burst degrades API latency for unrelated requests.
- **Event-level idempotency without unit-level checkpointing.** Relying only on `processed_events` dedup for a stage that processes large files. The dedup guard only helps once the whole event's transaction commits — a crash mid-file with no checkpoint means starting the entire file over, which does not scale to large documents or large estates.
- **Checkpoint written outside the unit's transaction.** Saving checkpoint progress in a separate commit from the extracted output it describes — a crash between the two leaves them disagreeing about how far processing actually got.
- **Unbounded concurrency "for throughput."** Maxing out worker pool concurrency without accounting for per-unit memory/CPU cost. A stage that OOMs during a large initial estate scan is a backpressure design failure, not bad luck.
- **DLQ policy invented per worker.** Each stage worker choosing its own retry count and backoff curve instead of reading them from the stage contract `data-pipeline-design` specified. Divergent policies make the pipeline's failure behavior unpredictable across stages.
- **Async or best-effort lineage.** Emitting lineage via a fire-and-forget call to a separate service instead of the same transaction as the state change — this is exactly `data-lineage-design`'s "async collector" anti-pattern, reintroduced at the implementation layer.
- **Silent Python creep.** Reaching for Python because it's familiar or "faster to prototype," without a genuine, documented library/model gap in Go. Every non-Go stage is a deliberately recorded exception, not a default.

---

## Output Format

Produces Go (or explicitly justified Python) source plus integration tests (Redpanda + PostgreSQL via testcontainers):

```
cmd/entity-extraction-worker/main.go
internal/pipeline/entityextraction/worker.go        (consume loop + handleRecord)
internal/pipeline/entityextraction/extract.go        (file-type dispatch)
internal/pipeline/entityextraction/checkpoint.go      (unit-level resumability)
internal/pipeline/entityextraction/lineage.go          (lineage_edges emission)
internal/pipeline/entityextraction/worker_test.go       (written first; includes
                                                            crash-mid-file resume test
                                                            and duplicate-delivery test)
```

```markdown
---
name: data-pipeline-implementation
product: [product name]
stage: [stage name]
version: 1.0.0
phase: data
created: [date]
owner: data-engineer
implements: [data-pipeline-design stage contract reference]
---

# Pipeline Stage Implementation — [Stage Name]

## Worker Structure
[Package layout]

## Idempotency Key
[Event id dedup mechanism]

## Checkpoint Strategy
[Unit granularity, resume behavior]

## Backpressure Configuration
[Concurrency limit, rationale]

## DLQ Configuration
[Matches data-pipeline-design contract: retries, backoff, topic]

## Lineage Capture Points
[What input/output pairs this stage records]

## Language Exception (if applicable)
[Library/model justifying non-Go, ADR reference]
```
