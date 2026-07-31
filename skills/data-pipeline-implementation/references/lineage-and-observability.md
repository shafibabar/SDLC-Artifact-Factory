# Lineage Emission and Pipeline Observability

Reference material for `data-pipeline-implementation`. Covers per-stage lineage-metadata emission (the implementation half of `data-lineage-design`'s capture points), OpenTelemetry instrumentation of pipeline metrics, and the DataOps data-observability pillars a stage worker must expose in production. Go code over this platform's Redpanda + PostgreSQL/pgx + OpenTelemetry/Prometheus/Tempo/Grafana stack. Grounded in `fundamentals-of-data-engineering` (the DataOps undercurrent, data observability, and the three metadata categories), OpenLineage's dataset/job/run model, and `data-lineage-design`.

---

## 1. Two Distinct Production Concerns

A stage worker owns two production responsibilities that are easy to conflate but are genuinely different:

| | Lineage emission | Data observability |
|---|---|---|
| Question it answers | *What produced what?* (provenance of one derived record) | *Is the pipeline healthy right now?* (freshness, volume, throughput, drift) |
| Granularity | Per record / per derivation edge | Aggregate, over a stream of records and time |
| Where it is written | `lineage_edges` rows, **in the state-change transaction** | OpenTelemetry metrics + traces, emitted as a side signal |
| Metadata category (`fundamentals-of-data-engineering`) | **Technical** metadata | **Operational** metadata |
| Distinct from | — | `data-quality-rules`' per-record gates (those are per-record *correctness*, not aggregate *health*) |

Both are the worker's job. Neither is a best-effort afterthought.

---

## 2. Lineage Emission Per Stage (Technical Metadata)

Every stage implements exactly the capture point `data-lineage-design` assigned it, writing to `lineage_edges` in the **same transaction** as its state change and outbox insert — never a separate, fire-and-forget call. The row schema follows the OpenLineage dataset/job/run model (`job_name`, `run_id`, input dataset + ref, output dataset + ref):

```go
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

Two properties make this correct:

- **Transactional with the work.** If the extraction commits, its lineage commits with it; if it rolls back, so does the lineage. There is never a derived record with no provenance, nor a provenance edge for work that did not happen. Emitting lineage async is precisely `data-lineage-design`'s "async collector" anti-pattern reintroduced one layer down.
- **Idempotent under redelivery.** `ON CONFLICT ... DO NOTHING` on the natural key means the same at-least-once redelivery that the rest of the stage tolerates does not double-insert edges. This mirrors the dedup discipline in `stage-workers-and-semantics.md` §3.

### Audit-by-reproduction

Because `lineage_edges` carries `job_name`, `run_id`, `input_ref`, and `output_ref`, a derived output can be *independently re-derived* from its recorded inputs and diffed against the live value (Kleppmann Ch. 12's correctness-via-reproducibility check). This is the same offset-reset replay mechanism from `stage-workers-and-semantics.md` §5, pointed at verification rather than backfill: re-run the stage against the recorded input and confirm it reproduces the recorded output.

---

## 3. Pipeline Metrics on OpenTelemetry (Operational Metadata)

The worker exposes operational metadata — how the pipeline actually behaved — as OpenTelemetry metrics scraped by Prometheus. The core instrument set per stage:

```go
type Metrics struct {
    processed    metric.Int64Counter       // records successfully processed
    failed       metric.Int64Counter       // records that errored (pre-DLQ)
    dlqRouted    metric.Int64Counter       // records parked in the DLQ
    duration     metric.Float64Histogram   // per-record processing latency (seconds)
    unitsPerFile metric.Int64Histogram      // volume signal: pages/sheets per document
    lagRecords   metric.Int64ObservableGauge // consumer lag = backlog depth (throttle signal)
}

func newMetrics(m metric.Meter) (*Metrics, error) {
    processed, _ := m.Int64Counter("pipeline.records.processed",
        metric.WithDescription("Records successfully processed by this stage"))
    failed, _ := m.Int64Counter("pipeline.records.failed")
    dlqRouted, _ := m.Int64Counter("pipeline.records.dlq_routed")
    duration, _ := m.Float64Histogram("pipeline.record.duration_seconds")
    unitsPerFile, _ := m.Int64Histogram("pipeline.document.units")
    // Consumer lag is observed from the kgo client each collection cycle.
    lag, _ := m.Int64ObservableGauge("pipeline.consumer.lag_records",
        metric.WithInt64Callback(func(_ context.Context, o metric.Int64Observer) error {
            o.Observe(currentLag(), metric.WithAttributes(attribute.String("stage", stageName)))
            return nil
        }))
    return &Metrics{processed, failed, dlqRouted, duration, unitsPerFile, lag}, nil
}
```

Every metric carries a `stage` attribute (and, where cardinality allows, a `tenant_id` bucket) so Grafana can break throughput and lag down per stage and spot a single tenant's scan saturating a stage. Traces (Tempo) are propagated from the Redpanda record headers into each `handleRecord` span (see `stage-workers-and-semantics.md` §3), so a single document's journey across `FileDiscovered → FileProcessed → EntityExtracted → …` is one distributed trace.

**Consumer lag is the load-bearing operational metric.** Per the backpressure model, the stage does not fake keeping up — lag *is* the visible queue depth. A steadily climbing `pipeline.consumer.lag_records` during a large initial scan is expected and self-draining; a lag that climbs and never falls in steady state is a real alert.

---

## 4. The Data-Observability Pillars for a Stage Worker

`fundamentals-of-data-engineering` frames production data health around observability pillars — continuously monitored, aggregate, distinct from per-record validation. For a pipeline stage worker the actionable subset:

| Pillar | Signal the worker exposes | Anomaly it catches |
|---|---|---|
| **Freshness** | Age of the oldest un-processed record in the backlog (`now() - oldest_unprocessed.occurred_at`) | The extraction backlog is stalling — files discovered hours ago still not processed |
| **Volume** | `pipeline.document.units` and files-processed-per-hour rate | A source connector silently broke — files-per-hour dropped to zero with no error; or a runaway scan spiking volume |
| **Schema (drift)** | Count of records hitting the `default:` (unsupported) branch of the file-type dispatch, tagged by the observed type | A new file format appearing in customer estates that no handler covers — surfaced as a rising metric, not a flood of DLQ records |
| **Distribution** | Extracted-entities-per-document distribution | Extraction quality regressed — documents that used to yield entities now yield none (a library upgrade broke a parser) |
| **Lineage** | `lineage_edges` write rate vs. processed rate | Provenance capture silently falling behind derivation (should be impossible given §2's transactionality — this pillar is the check that it stays impossible) |

These are **operational** signals about the *pipeline*, categorically different from `data-quality-rules`' per-record confidence gates, which judge *individual* extracted entities. A file that extracts cleanly but is one of a suspicious estate-wide drop in files-per-hour passes every per-record gate and still trips the volume pillar — which is exactly the kind of failure per-record validation cannot see.

### Freshness as a derived gauge

```go
// Emitted on each collection cycle: how stale is the backlog head?
freshness, _ := m.Float64ObservableGauge("pipeline.backlog.freshness_seconds",
    metric.WithInt64Callback(func(ctx context.Context, o metric.Float64Observer) error {
        var oldest time.Time
        // Oldest un-acknowledged record for this stage, from processed_events / lag offsets.
        err := pool.QueryRow(ctx, `
            SELECT COALESCE(MIN(occurred_at), now())
            FROM outbox_backlog_view WHERE stage = $1`, stageName).Scan(&oldest)
        if err != nil {
            return err
        }
        o.Observe(time.Since(oldest).Seconds(),
            metric.WithAttributes(attribute.String("stage", stageName)))
        return nil
    }))
```

---

## 5. The Three Metadata Categories, and Where Each Lives

`fundamentals-of-data-engineering` classifies metadata into three kinds; a stage worker emits two of them directly and must not conflate them:

| Category | What it captures | Where the worker puts it |
|---|---|---|
| **Technical** | Schemas, lineage, data types, partitioning — *how data is structured and where it flows* | `lineage_edges` (§2), written transactionally per derivation |
| **Operational** | Job run stats, durations, success/failure rates, records processed — *how the pipeline behaved* | OpenTelemetry metrics + traces (§3), scraped to Prometheus/Tempo |
| **Business** | Definitions, business rules, glossary terms, ownership — *what the data means* | **Not the worker's job** — lives in the canonical glossary and `data-classification`'s taxonomy; the worker only carries the `tenant_id`/`data_asset_id` keys that let a reader *join* to it |

The discipline: a stage worker owns technical and operational metadata emission and stays out of business metadata. It does not embed compliance-control names or glossary definitions in `lineage_edges` — it emits the keys (`output_ref`, `tenant_id`) that a governance query joins against the business-metadata stores. Mixing business meaning into the worker's technical/operational emission couples the pipeline to governance vocabulary that changes on a different cadence.

## 6. Observability Quality Checklist

| Check | Pass |
|---|---|
| Lineage transactional | `lineage_edges` written in the state-change tx, deduped on the natural key |
| Lineage never async | No fire-and-forget call to a separate lineage service |
| Trace continuity | Record-header context propagated so one document is one distributed trace across stages |
| Core metrics present | processed / failed / dlq_routed / duration / consumer lag, tagged by stage |
| Freshness exposed | Backlog-head age is a monitored gauge, not inferred from logs |
| Volume + schema-drift signals | Files-per-hour rate and unsupported-type counter both emitted |
| Operational vs. per-record separation | Pipeline-health signals kept distinct from `data-quality-rules`' per-record gates — they answer different questions |
