# Error Handling, Retry/Backoff, and the Dead-Letter Queue

Reference material for `data-pipeline-implementation`. Covers poison-record detection, transient-vs-permanent classification, exponential backoff with jitter, DLQ topic routing after N retries, partial-failure handling, and replay from the DLQ, with Go code over this platform's Redpanda + PostgreSQL/pgx stack. Grounded in `fundamentals-of-data-engineering`'s DataOps undercurrent (plan-for-failure, graceful degradation).

---

## 1. The Failure Taxonomy

Every failure inside `handleRecord` is exactly one of three kinds, and the correct action differs for each:

| Kind | Example | Action |
|---|---|---|
| **Transient** | Storage fetch timeout, broker rebalance, pgx pool exhausted, a `503` from a downstream store | Retry in place with backoff+jitter, up to the attempt cap |
| **Permanent (poison)** | Undecodable envelope, unsupported file type, a payload that fails schema validation, a NULL where a NOT NULL is required | Route straight to the DLQ — retrying will never help |
| **Attempt cap exhausted** | A "transient" error that has now failed N times | Route to the DLQ; treat as poison for now, replay later once the root cause is fixed |

Conflating these is the most common failure-handling defect. Retrying a poison record N times wastes N×backoff of wall-clock and log noise before it lands in the DLQ anyway; DLQ-ing a transient error on the first blip loses work that a single retry would have recovered.

### Sentinel-error classification in Go

```go
var (
    // ErrPermanent marks a poison record: never retry, go straight to DLQ.
    ErrPermanent = errors.New("permanent error")
    // ErrTransient is the default assumption for un-annotated errors: retry.
    ErrTransient = errors.New("transient error")
)

// Wrap at the point the nature is known:
//   return fmt.Errorf("%w: unsupported file type %q", ErrPermanent, ft)
//   return fmt.Errorf("%w: storage fetch: %v", ErrTransient, err)

func isPermanent(err error) bool { return errors.Is(err, ErrPermanent) }
```

Un-annotated errors default to *transient* (retry) — it is safer to retry a truly-permanent error a few times (it still lands in the DLQ after the cap) than to silently DLQ a recoverable one on the first attempt.

---

## 2. Retry with Exponential Backoff and Jitter

Retries are in-process, bounded by the stage contract's attempt cap. The delay grows exponentially so a struggling downstream store is not hammered, and **jitter** is added so many workers that failed at the same instant (e.g. a shared store restart) do not retry in a synchronized thundering herd.

```go
type RetryPolicy struct {
    MaxAttempts int           // from the stage's data-pipeline-design contract
    BaseDelay   time.Duration // e.g. 200ms
    MaxDelay    time.Duration // e.g. 30s — cap the exponential growth
}

func (w *Worker) withRetry(ctx context.Context, fn func() error) error {
    var err error
    for attempt := 1; attempt <= w.retry.MaxAttempts; attempt++ {
        if err = fn(); err == nil {
            return nil
        }
        if isPermanent(err) {
            return err // do not waste further attempts — straight to DLQ caller-side
        }
        if attempt == w.retry.MaxAttempts {
            break // cap exhausted; caller routes to DLQ
        }
        select {
        case <-time.After(backoffWithJitter(attempt, w.retry)):
        case <-ctx.Done():
            return ctx.Err()
        }
    }
    return fmt.Errorf("exhausted %d attempts: %w", w.retry.MaxAttempts, err)
}

// Full jitter: delay is uniformly random in [0, min(MaxDelay, Base*2^(attempt-1))].
// Full jitter (rather than "exponential + small random") maximally decorrelates
// retries across workers, which is what actually protects a recovering store.
func backoffWithJitter(attempt int, p RetryPolicy) time.Duration {
    exp := float64(p.BaseDelay) * math.Pow(2, float64(attempt-1))
    capped := math.Min(exp, float64(p.MaxDelay))
    return time.Duration(rand.Int63n(int64(capped) + 1))
}
```

Backoff runs *inside* one `handleRecord` invocation — the offset is not committed and the record is not redelivered by the broker during in-process retries. Only after the attempt cap is exhausted does the record move to the DLQ.

---

## 3. DLQ Topic Routing

The DLQ is a dedicated Redpanda topic per stage, named by the stage contract's convention (`<stage>-dlq`). Routing a record there is itself a durable produce — and the source offset must **not** be committed until that produce has succeeded, or a failure to DLQ would silently drop the record.

```go
func (w *Worker) toDLQ(ctx context.Context, rec *kgo.Record, cause error) error {
    dlqRec := &kgo.Record{
        Topic: w.stageName + "-dlq", // per data-pipeline-design's naming convention
        Key:   rec.Key,               // preserve partition key for tenant-scoped inspection
        Value: rec.Value,             // original payload travels intact
        Headers: append(rec.Headers,
            kgo.RecordHeader{Key: "dlq-reason",      Value: []byte(cause.Error())},
            kgo.RecordHeader{Key: "dlq-stage",       Value: []byte(w.stageName)},
            kgo.RecordHeader{Key: "dlq-failed-at",   Value: []byte(time.Now().UTC().Format(time.RFC3339))},
            kgo.RecordHeader{Key: "dlq-attempts",    Value: []byte(strconv.Itoa(w.retry.MaxAttempts))},
        ),
    }
    if err := w.dlqProducer.ProduceSync(ctx, dlqRec).FirstErr(); err != nil {
        // Do NOT commit the source offset — let redelivery retry the whole thing.
        slog.ErrorContext(ctx, "failed to route to DLQ; record will be redelivered", "err", err)
        return err
    }
    w.metrics.dlqRouted.Add(ctx, 1, metric.WithAttributes(attribute.String("stage", w.stageName)))
    return nil // safe to commit the source offset now — record is durably parked
}
```

### Tenant isolation in the DLQ

Tenant id (in the record key and/or an envelope field) and the original payload travel with every DLQ record. `data-pipeline-design`'s tenant-isolation requirement extends to failed records: DLQ inspection and replay tooling stays tenant-scoped, so an operator inspecting one tenant's failures never sees another tenant's document content. Preserving `rec.Key` keeps DLQ records partitioned the same way, so per-tenant DLQ consumption is straightforward.

---

## 4. Partial-Failure Handling

A record may partially succeed — e.g. 38 of 40 pages extract cleanly and 2 pages are corrupt. Options, in order of preference:

1. **Checkpoint the good units, fail the record as transient/permanent for the bad ones.** Because the checkpoint (see `stage-workers-and-semantics.md` §4) commits per completed unit, the 38 good pages are durably recorded; on retry only pages 39–40 are reattempted. If those pages are permanently corrupt, the record eventually DLQs — but with 38 pages of lineage/entities already committed.
2. **Emit a partial-success signal** where the domain allows it (e.g. `EntityExtracted` with a `partial: true` flag and the failed unit indices), so downstream compliance evaluation can proceed on what was extracted while the failed units are triaged from the DLQ.
3. **Never** silently swallow the failed units and emit a clean success event — that hides a data-completeness defect (`fundamentals-of-data-engineering`'s completeness dimension) from every downstream stage.

Which of 1/2 applies is a stage-contract decision, not a per-worker improvisation.

---

## 5. Replay from the DLQ

A DLQ is a parking lot, not a graveyard. Once the root cause of a batch of failures is fixed (a bug patched, a new file-type handler added, a downstream store scaled up), the parked records are replayed:

```
                 ┌─────────────┐   retry cap exhausted / poison   ┌───────────────┐
  file-processed │ stage worker│ ───────────────────────────────▶ │ <stage>-dlq   │
       topic ───▶│ (idempotent)│                                   │ (parked recs) │
                 └─────────────┘                                   └───────┬───────┘
                        ▲                                                  │ fix deployed
                        │            replay tool re-produces to            │
                        └──────────  the stage's INPUT topic ◀─────────────┘
```

The replay tool consumes `<stage>-dlq`, optionally filters by `dlq-reason` or `tenant_id`, and re-produces each record to the stage's **input** topic — so it flows through the *same* idempotent worker, not a special code path. Idempotency (see `stage-workers-and-semantics.md` §3) is what makes replay safe: any record that had in fact partially succeeded before failing converges to the same state rather than double-writing.

```bash
# Replay only the records that failed on an unsupported-file-type bug now fixed,
# for a single tenant, back onto the live input topic.
dlq-replay --dlq entity-extraction-dlq \
           --filter 'dlq-reason~="unsupported file type"' \
           --tenant "$TENANT_ID" \
           --to file-processed
```

Guardrails for replay:

- **Fix first, replay second.** Replaying before the root cause is fixed just re-parks the records after another N wasted retries.
- **Scope by reason and tenant.** A blanket replay of a mixed DLQ re-runs records whose failures are unrelated and still unfixed.
- **Rely on idempotency, not on "these definitely never succeeded."** Some DLQ records failed *after* partial success; only the dedup-key upsert makes re-running them safe.

---

## 6. DLQ / Retry Quality Checklist

| Check | Pass |
|---|---|
| Poison vs transient distinguished | `ErrPermanent`-wrapped errors skip retry; others retry to the cap |
| Backoff has jitter | Full-jitter delay, capped at `MaxDelay` — no synchronized retry herds |
| Policy from the contract | `MaxAttempts`, base/max delay, and DLQ topic name read from `data-pipeline-design`, not hard-coded per worker |
| Offset commit ordering | Source offset committed only after the record is durably in the DLQ |
| Tenant isolation preserved | Tenant id + original payload + partition key carried on the DLQ record |
| Partial failure explicit | Good units checkpointed; failed units DLQ'd or flagged — never silently dropped |
| Replay path exists | DLQ records can be re-produced to the input topic and flow through the same idempotent worker |
