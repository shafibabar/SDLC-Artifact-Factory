# DQ Metrics and Scorecard — computing, trending, and alerting on data quality

Reference for `data-quality-rules`. Covers how to compute a data-quality score per dimension and overall, how to trend it over a rolling window, the scorecard artifact shape, and how alerting fires when a dimension drops below threshold. Grounded in DAMA-DMBOK's Data Quality Management operating cycle and this repo's stack (PostgreSQL + `metrics-instrumentation-plan` + OpenTelemetry). Self-contained.

## Why a scorecard, not just gate outcomes

A pipeline gate answers a point-in-time question: is *this* record trustworthy right now. That is necessary but not sufficient. DAMA-DMBOK's Data Quality KA describes an ongoing cycle: profile data to discover unknown issues, define rules, **measure continuously**, run root-cause analysis on recurring failures, and track a **longitudinal scorecard**. Without the scorecard, a rule can silently degrade for months — `data-quality-rules`' own motivating example (falling OCR confidence on scanned PDFs as a customer's estate ages) is exactly a *trend* that per-record gates never surface but a trended accuracy score catches immediately.

The scorecard is a **recurring** artifact (produced on a schedule over a rolling window), distinct from `data-storytelling`'s one-off narrative and from the point-in-time pass/quarantine/reject counts a gate emits.

---

## Per-dimension score

For each of the six DAMA dimensions, the score is the pass rate over the evaluation window:

```
dimension_score(d, window) = records_passing_all_rules_for(d, window)
                             / records_evaluated_for(d, window)
```

A record is "evaluated for d" if at least one rule of dimension d applied to it. Not every record is evaluated for every dimension (a `data_asset` has no `EMAIL`-format validity rule; an `extracted_entity` has no timeliness rule) — divide only by the records the dimension actually gated, or the score is diluted by irrelevant rows.

```sql
-- Accuracy score over a rolling 24h window, from the gate-outcome ledger
SELECT
  count(*) FILTER (WHERE outcome = 'pass')::numeric
    / NULLIF(count(*), 0) AS accuracy_score
FROM dq_gate_outcomes
WHERE dimension = 'accuracy'
  AND evaluated_at >= now() - interval '24 hours';
```

The gate-outcome ledger is the raw material for every score:

```sql
CREATE TABLE dq_gate_outcomes (
  id           BIGSERIAL PRIMARY KEY,
  tenant_id    UUID NOT NULL,
  stage        TEXT NOT NULL,          -- pipeline stage the gate sat at
  dimension    TEXT NOT NULL,          -- completeness|accuracy|consistency|timeliness|validity|uniqueness
  rule_id      TEXT NOT NULL,          -- which specific rule
  entity_type  TEXT,                   -- nullable; set for entity-level rules
  outcome      TEXT NOT NULL,          -- pass|quarantine|auto_correct|reject
  evaluated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ON dq_gate_outcomes (dimension, evaluated_at);
CREATE INDEX ON dq_gate_outcomes (rule_id, evaluated_at);
```

Note the four outcome values are the four remediation paths from `remediation-and-go.md`. For scoring, `pass` and `auto_correct` both count as "the record ended up acceptable" (auto-correct fixed it losslessly); `quarantine` and `reject` count as failures of that dimension. This is a deliberate choice: a losslessly auto-corrected record is a quality *success* of the pipeline, not a failure — but track the auto-correct rate separately, because a rising auto-correct rate is itself a signal that upstream data is degrading.

---

## Overall score — weighted roll-up

The overall DQ score is a **weighted** average of the six dimension scores. Weights reflect compliance risk, not equal thirds or equal sixths — in this product accuracy and consistency carry more weight than timeliness, because a wrong or internally-contradictory classification is a wrong finding, while a slightly stale one is merely late.

```
overall_score = Σ (weight(d) × dimension_score(d))   over the six dimensions,
                with  Σ weight(d) = 1.0
```

Default weights (stored as configuration, tunable):

| Dimension | Default weight | Why |
|---|---|---|
| Accuracy | 0.25 | A wrong classification is a wrong compliance finding |
| Consistency | 0.20 | An internally contradictory level is indefensible in an audit |
| Completeness | 0.20 | A finding built on missing fields is not traceable |
| Validity | 0.15 | Malformed data is usually caught early and cheaply |
| Uniqueness | 0.10 | Duplicates inflate counts but rarely change a verdict |
| Timeliness | 0.10 | A late-but-correct classification is recoverable |

```sql
CREATE TABLE dq_dimension_weights (
  dimension TEXT PRIMARY KEY,
  weight    NUMERIC(3,2) NOT NULL CHECK (weight >= 0 AND weight <= 1)
);
-- A CHECK/trigger enforcing SUM(weight)=1.0 across the table keeps the roll-up honest.
```

A weighted roll-up is honest only if the weights sum to 1.0 — enforce it, or the "overall score" is uninterpretable.

---

## The scorecard artifact

The scorecard is a small, recurring table snapshotted per window and retained for trending:

```sql
CREATE TABLE dq_scorecard_snapshots (
  id             BIGSERIAL PRIMARY KEY,
  tenant_id      UUID NOT NULL,
  window_start   TIMESTAMPTZ NOT NULL,
  window_end     TIMESTAMPTZ NOT NULL,
  dimension      TEXT NOT NULL,      -- one row per dimension + an 'overall' row
  score          NUMERIC(5,4) NOT NULL,
  records_evaluated BIGINT NOT NULL,
  alert_threshold   NUMERIC(5,4) NOT NULL,
  breached          BOOLEAN NOT NULL,
  snapshotted_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Rendered for a human reviewer (Shafi, PM — no IDE), one window looks like:

| Dimension | Weight | Window (24h) | Score | Alert threshold | Status |
|---|---|---|---|---|---|
| Completeness | 0.20 | 07-30 → 07-31 | 0.998 | 0.99 | OK |
| Accuracy | 0.25 | 07-30 → 07-31 | 0.912 | 0.90 | OK |
| Consistency | 0.20 | 07-30 → 07-31 | 0.994 | 0.98 | OK |
| Timeliness | 0.10 | 07-30 → 07-31 | 0.870 | 0.85 | OK |
| Validity | 0.15 | 07-30 → 07-31 | 0.999 | 0.99 | OK |
| Uniqueness | 0.10 | 07-30 → 07-31 | 0.997 | 0.99 | OK |
| **Overall** | 1.00 | 07-30 → 07-31 | **0.958** | 0.93 | OK |

---

## Trending

A single snapshot cannot tell decline from noise. Trend each dimension across a sequence of windows and detect a **sustained downward slope**, not just a single dip:

```sql
-- Accuracy over the last 14 daily windows, for a sparkline / slope check
SELECT window_start::date, score
FROM dq_scorecard_snapshots
WHERE dimension = 'accuracy'
  AND window_start >= now() - interval '14 days'
ORDER BY window_start;
```

A dimension that is above threshold every day but has fallen 0.94 → 0.93 → 0.92 → 0.91 across four windows is degrading and should raise a **trend warning** before it breaches — this is the early-warning the scorecard exists to provide. A simple, frugal rule: warn if the linear slope over the trailing N windows is negative AND the projected value crosses the threshold within M windows. No ML required.

---

## Root-cause slice

When a dimension breaches, DAMA's cycle calls for **root-cause analysis** — do not just re-run the gate. The gate-outcome ledger is already sliced by `rule_id`, `stage`, and `entity_type`, so the failing dimension can be decomposed:

```sql
-- Which rule and which entity type is dragging accuracy down?
SELECT rule_id, entity_type,
       count(*) FILTER (WHERE outcome IN ('quarantine','reject')) AS failures,
       count(*) AS total,
       round(count(*) FILTER (WHERE outcome IN ('quarantine','reject'))::numeric
             / count(*), 3) AS failure_rate
FROM dq_gate_outcomes
WHERE dimension = 'accuracy'
  AND evaluated_at >= now() - interval '24 hours'
GROUP BY rule_id, entity_type
ORDER BY failure_rate DESC;
```

If the failure concentrates on `entity_type='SSN'` in `stage='ocr_extraction'`, the root cause is OCR quality on scanned documents — a model/tuning problem, not a threshold problem. If it is spread evenly, the threshold itself may be miscalibrated. Root-cause is a slice, not a guess.

---

## Alerting and wiring to instrumentation

Every score and every gate outcome rolls up into a named metric in `metrics-instrumentation-plan`. The scorecard adds two alert conditions distinct from the gate's own:

| Signal | Metric | Alert condition |
|---|---|---|
| Per-dimension score | `dq_dimension_score{dimension=...}` (gauge) | score < alert_threshold(dimension) |
| Overall score | `dq_overall_score` (gauge) | overall < overall_threshold |
| Auto-correct rate | `dq_auto_correct_rate{rule_id=...}` | sustained rise (upstream degradation signal) |
| Quarantine queue age | `dq_quarantine_age_seconds` (histogram) | oldest item older than SLA — alert on **age**, not volume |
| DLQ depth | `dlq_depth` (gauge, from `data-pipeline-design`) | any sustained growth — alert on **volume** |

The age-vs-volume distinction is load-bearing and is the mirror of the DLQ-vs-quarantine split: a growing DLQ is a defect (alert on volume); a growing quarantine backlog is a steward-capacity problem (alert on age). Emitting these as OpenTelemetry gauges/histograms lets Grafana render the scorecard and Prometheus fire the alerts, per this repo's observability stack — no new tooling, satisfying the frugality constraint.

## Summary

Per-dimension score = pass rate over the window; overall = weighted roll-up with weights summing to 1.0 and reflecting compliance risk; scorecard = recurring snapshot retained for trending; trend detection warns before a breach; root-cause slices the outcome ledger by rule/stage/entity-type; alerting distinguishes age (quarantine) from volume (DLQ). This is the measurement half of DAMA's continuous Data Quality cycle — the rules live in `dq-dimensions-catalogue.md`, the correction step in `remediation-and-go.md`.
