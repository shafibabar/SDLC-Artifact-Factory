# Stage Workers, Delivery Semantics, and Replay

Reference material for `data-pipeline-implementation`. Covers the consumer-group stage-worker structure on Redpanda, offset and checkpoint management, at-least-once vs. exactly-once and the idempotent-write pattern, reprocessing/replay by offset reset, and the log-compaction-vs-time-based-retention topic decision. Grounded in `fundamentals-of-data-engineering` (Reis & Housley) and the `designing-data-intensive-applications` Part III cross-check (Kleppmann), over this platform's Redpanda + PostgreSQL/pgx stack.

---

## 1. Package Layout

A stage worker is one standalone deployable per stage:

```
cmd/
  entity-extraction-worker/
    main.go                 # composition root: config, telemetry, Redpanda client, pgx pool, graceful drain
internal/
  pipeline/
    entityextraction/
      worker.go             # consume loop + handleRecord (built on go-event-consumer's pattern)
      extract.go            # file-type dispatch, unit granularity
      checkpoint.go         # unit-level resumability
      lineage.go            # lineage_edges emission
      worker_test.go        # written FIRST (TDD): duplicate-delivery + crash-mid-file resume tests
```

`main.go` wires the same shared infrastructure a `go-service-skeleton` service does (OpenTelemetry, the `kgo` client, the pgx pool) — the wiring is not pipeline-specific. What is pipeline-specific is everything inside `handleRecord`.

---

## 2. Delivery Semantics: The Three Options

| Guarantee | Mechanism | Cost | Use when |
|---|---|---|---|
| At-most-once | Commit offset *before* handling | Cheap; loses records on crash | Never for this pipeline — a lost file is a compliance gap |
| At-least-once | Commit offset *after* handling | Cheap; redelivers on crash | **Default.** Combine with an idempotent consumer |
| Exactly-once (broker) | Transactional producer + read-committed consumer, offset commit inside the producer transaction | Real throughput cost, added operational burden, cross-topic coordination | Only when a side effect is genuinely non-idempotent and cannot be made so |

`fundamentals-of-data-engineering` is explicit that reflexive "just make it exactly-once" is a common over-engineering trap: the machinery (stateful transactional producers, coordinator overhead) rarely earns its cost. The pipeline's correct posture:

> Take **at-least-once** delivery from Redpanda and make the **consumer idempotent**. A redelivered record then produces no duplicate effect — which is **effectively exactly-once**, the property the business actually needs, without broker transactions.

Redpanda is Kafka-protocol compatible; with the `franz-go` (`kgo`) client, at-least-once is simply "handle the record, then commit its offset." Auto-commit is disabled so the offset is never committed ahead of the work.

---

## 3. The Idempotent-Write Pattern (Dedup-Key Upsert)

Idempotency is achieved by an **upsert keyed on a natural dedup key** — the consumed event's `eventId` — inside the *same* transaction as the outbox write for the next stage. There are two equivalent shapes; use whichever fits the stage's write:

**Shape A — explicit dedup table** (when the stage's own write is not itself keyed by the event):

```go
func (w *Worker) handleRecord(ctx context.Context, rec *kgo.Record) {
    ctx = otel.GetTextMapPropagator().Extract(ctx, kafkaHeaderCarrier{rec})
    ctx, span := w.tracer.Start(ctx, "entity-extraction.process")
    defer span.End()

    env, err := decodeEnvelope(rec.Value) // FileProcessed event
    if err != nil {
        w.toDLQ(ctx, rec, fmt.Errorf("%w: undecodable: %v", ErrPermanent, err))
        return
    }

    err = w.withRetry(ctx, func() error {
        tx, err := w.pool.Begin(ctx)
        if err != nil {
            return err
        }
        defer tx.Rollback(ctx) //nolint:errcheck

        // Dedup guard: insert the event id; a redelivery hits ON CONFLICT.
        ct, err := tx.Exec(ctx,
            `INSERT INTO processed_events (consumer_name, event_id)
             VALUES ($1,$2) ON CONFLICT DO NOTHING`, w.stageName, env.EventID)
        if err != nil {
            return err
        }
        if ct.RowsAffected() == 0 {
            return tx.Commit(ctx) // already processed — redelivery, no-op
        }

        result, err := w.extractEntities(ctx, tx, env)
        if err != nil {
            return fmt.Errorf("extraction: %w", err)
        }
        if err := w.emitLineage(ctx, tx, env, result); err != nil {
            return fmt.Errorf("lineage: %w", err)
        }
        for _, e := range result.Entities {
            payload, _ := json.Marshal(entityExtractedPayload(e))
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
    // Offset committed by the consume loop only after handleRecord returns cleanly.
}
```

**Shape B — natural-key upsert** (when the derived row *is* keyed by a stable natural key, e.g. one classification row per `(tenant_id, data_asset_id)`):

```sql
INSERT INTO data_asset_classification (tenant_id, data_asset_id, effective_level, computed_from_event, updated_at)
VALUES ($1, $2, $3, $4, now())
ON CONFLICT (tenant_id, data_asset_id)
DO UPDATE SET effective_level     = EXCLUDED.effective_level,
              computed_from_event = EXCLUDED.computed_from_event,
              updated_at          = now()
WHERE data_asset_classification.computed_from_event <> EXCLUDED.computed_from_event;
```

Here the dedup key is the row's natural key and the `WHERE` on `computed_from_event` makes a redelivery of the *same* event a genuine no-op while still allowing a *newer* event to advance the row. Both shapes give the same guarantee: **applying the same event twice leaves the store in the state it would have after applying it once.**

Choosing the key: prefer the event id for append-style work (each event produces new rows); prefer the entity's natural key for state-convergence work (each event overwrites a current-state row). Never use an auto-generated surrogate id or `now()` as part of a dedup key — a redelivery would produce a new key and defeat the guard.

---

## 4. Checkpoint / Resume Within One Event

Event-level dedup only helps once an event's whole transaction commits. A stage processing a large file needs a second, orthogonal guard so a crash mid-file resumes rather than restarts:

```go
type Checkpoint struct {
    RunID         uuid.UUID
    DataAssetID   uuid.UUID
    LastUnitIndex int       // last fully-processed page / sheet / paragraph block
    UpdatedAt     time.Time
}

func (w *Worker) checkpointedExtract(ctx context.Context, tx pgx.Tx, run ExtractionRun) (Result, error) {
    cp, err := loadCheckpoint(ctx, tx, run.ID)
    if err != nil && !errors.Is(err, pgx.ErrNoRows) {
        return Result{}, err
    }
    start := 0
    if cp != nil {
        start = cp.LastUnitIndex + 1 // resume after the last completed unit
    }
    var entities []Entity
    for i, unit := range run.Units[start:] {
        found, err := extractUnit(ctx, unit)
        if err != nil {
            return Result{}, fmt.Errorf("unit %d: %w", start+i, err)
        }
        entities = append(entities, found...)
        if err := saveCheckpoint(ctx, tx, run.ID, start+i); err != nil { // SAME tx as the unit's output
            return Result{}, fmt.Errorf("checkpoint: %w", err)
        }
    }
    return Result{Entities: entities}, nil
}
```

The checkpoint row is written in the *same transaction* as the unit's extracted output, so the two never disagree about progress.

### Worked crash-and-resume walkthrough

A 40-page scanned PDF is evicted mid-extraction at page 23 (rolling deploy). On restart:

1. The consumer redelivers `FileProcessed` (at-least-once) — its transaction never committed, so `processed_events` does **not** skip it. Correct: no `EntityExtracted` was ever emitted.
2. `checkpointedExtract` loads the checkpoint, finds `LastUnitIndex = 22`, resumes from page 23.
3. Extraction finishes; lineage edges for all 40 pages, the `EntityExtracted` outbox row, and the final `processed_events`/checkpoint state all commit in one transaction.

No duplicate work beyond the single in-flight page at crash time, no lost progress, and no downstream event emitted until the file is genuinely done.

---

## 5. Reprocessing / Replay (Backfill)

Crash-and-resume handles one in-flight run. It does **not** handle: *a stage's logic changed, or a new stage was added after go-live, and history must catch up.* Kleppmann's Ch. 11 gives the mechanism — a log is replayable history, and a consumer group can be bootstrapped from the beginning of a topic by resetting its offset:

> To backfill or reprocess, **reset the stage's consumer-group offset to the earliest offset** and let the *existing* idempotent, checkpointed worker consume the whole topic from the start. No new code path is needed — idempotency makes the re-run safe against records already processed once.

```bash
# Reset entity-extraction stage to replay its entire input topic from the beginning.
# Safe precisely because handleRecord is idempotent (dedup-key upsert) — records
# already processed converge to the same state; only genuinely new derivation happens.
rpk group seek entity-extraction --to start --topics file-processed
```

Two disciplines make this safe and affordable:

- **Idempotency is the precondition.** Without the Section 3 guard, a replay double-writes. With it, replay is a no-op for already-current rows and a real update only where the new logic changes the derived value.
- **A dedicated replay consumer group** (a temporary second group) can rebuild a *new* derived store — e.g. bootstrapping the Apache AGE graph after adding a graph-update stage — without disturbing the live group's committed offset.

---

## 6. Topic Retention: Time-Based vs. Log Compaction

Replay is only possible if the history still exists. This is a per-topic decision the stage's `data-pipeline-design` contract must state, not leave to a broker default:

| Policy | Keeps | Choose when | Redpanda config |
|---|---|---|---|
| **Time-based retention** | Every record within a time window (e.g. 30 days, or effectively infinite for a compliance audit trail) | Downstream may need to **replay full history** — a new stage, a corrected extraction rule, an audit re-derivation | `retention.ms` (and/or `retention.bytes`) |
| **Log compaction** | Only the **latest record per key** | Downstream needs only current state per key, not history — e.g. a "latest classification per asset" state topic | `cleanup.policy=compact` |

```bash
# History-bearing input topic (must support future reprocessing): time-based, long window.
rpk topic alter-config file-processed  --set cleanup.policy=delete  --set retention.ms=-1

# Current-state topic (only latest per asset matters): compacted.
rpk topic alter-config asset-classification-state --set cleanup.policy=compact
```

The trap the SKILL.md Anti-Patterns names: a stage silently log-compacted has **no history left to replay** the day its logic changes. If in doubt for an input topic that feeds derived state, prefer time-based retention — history you kept can always be compacted later; history you discarded cannot be recovered.

---

## 7. Stage-Implementation Artifact Template

```markdown
---
name: pipeline-stage-implementation
product: [product name]
stage: [stage name]
version: 1.0.0
phase: implement
created: [date]
owner: data-engineer
implements: [data-pipeline-design stage contract reference]
---

# Pipeline Stage Implementation — [Stage Name]

## Worker Structure
[Package layout]

## Delivery Semantics
[At-least-once + idempotent consumer; dedup key chosen; broker exactly-once only if justified]

## Idempotency Key
[Event id, or natural key + WHERE guard]

## Checkpoint Strategy
[Unit granularity, resume behavior]

## Backpressure Configuration
[Concurrency limit and rationale]

## DLQ Configuration
[Matches data-pipeline-design contract: retries, backoff, topic]

## Topic Retention
[Time-based vs. compacted, chosen against whether this stage may need historical replay]

## Lineage Capture Points
[Input/output pairs this stage records]

## Language Exception (if applicable)
[Library/model justifying non-Go, ADR reference]
```
