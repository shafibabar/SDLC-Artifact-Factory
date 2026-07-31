# Product Metrics Catalogue — First Product

Self-contained reference. No parent SKILL.md needed. Covers the full event-to-metric traceability, Read Model schemas, and a worked instrumentation example for the data estate compliance product.

---

## Full Metric Definition Table

All five fields are required for every metric before it enters the instrumentation plan. See the parent SKILL.md for the field definitions.

| Metric | Formula | Source table/event | Owner | Target |
|---|---|---|---|---|
| **Activation rate** | % of trial tenants that reach first compliance gap discovery within 30 minutes of connecting a source | `DataSourceConnected` → `ComplianceGapOpened` event pair, timestamp delta | data-engineer | 80% (ties to `okr-authoring`'s KR1.1) |
| **Extraction throughput** | Files processed per hour, by file type | `FileProcessed` event count, windowed by hour | data-engineer | Sized to estate scan SLOs per `data-pipeline-design` |
| **Classification accuracy proxy** | 1 − (steward-corrected classifications ÷ total steward reviews) | `DataAssetReclassified` events where the reviewer's decision *disagreed* with the automated provisional level, vs. total `DataAssetClassified` and review events | data-engineer | ≥ 0.85 (below this, extraction model tuning is prioritized) |
| **Gap-closure rate** | % of `ComplianceGap` records moved from open to closed within the customer's target remediation window | `ComplianceGapOpened` → `ComplianceGapClosed` event pair, against a configured SLA per tenant | data-engineer | 90% within SLA |
| **Data quality pass rate** | % of pipeline stage outputs that pass their quality gate without quarantine | Quality gate outcome events per stage (see `data-quality-rules`) | data-engineer | ≥ 95% pass, by stage |
| **Extraction confidence trend** | 7-day rolling average of `EntityExtracted.confidence`, grouped by entity type and file type | `EntityExtracted` event payload (`entity_type`, `file_type`, `confidence`), aggregated into `extraction_confidence_daily` | data-engineer | ≥ 0.90 sustained for PII entity types; alert if 7-day average drops below 0.85 for two consecutive days |

These are starting definitions. New metrics enter only after passing `analytics-requirements`' decision-first elicitation and vanity-metric check — a metric that can't name the decision it informs does not belong here.

---

## Event-to-Metric Traceability

Every metric traces backward to the specific Domain Events that roll up into it. This is what makes a metric auditable — when a number looks wrong, the first question is "which events fed this," and the answer is a direct lookup here.

```
Metric: Gap-Closure Rate
  ← rolls up from:
      ComplianceGapOpened   (Compliance bounded context, domain-event-catalog)
      ComplianceGapClosed   (Compliance bounded context, domain-event-catalog)
  ← computed by:
      Compliance Rule Engine pipeline stage writes gap_lifecycle rows on
      both events (data-pipeline-implementation); a daily aggregation job
      computes the closure-rate Read Model from gap_lifecycle
  ← consumed by:
      dashboard-specification's "Gap Closure Trend" widget
      reporting-spec's SOC 2 Evidence Report, Section 4 (Compliance Gap History)
```

| Metric | Contributing Domain Events | Computed in |
|---|---|---|
| Activation rate | `DataSourceConnected`, `ComplianceGapOpened` | Daily batch job → `activation_funnel` Read Model |
| Extraction throughput | `FileProcessed` | Streaming aggregation → `extraction_throughput_hourly` |
| Classification accuracy proxy | `DataAssetClassified`, `DataAssetReclassified` | Daily batch job → `classification_accuracy_daily` |
| Gap-closure rate | `ComplianceGapOpened`, `ComplianceGapClosed` | Streaming aggregation → `gap_lifecycle`, daily rollup |
| Data quality pass rate | Quality gate outcome events (per `data-quality-rules`) | Streaming aggregation → `quality_gate_outcomes_daily` |
| Extraction confidence trend | `EntityExtracted` (confidence field) | Streaming aggregation → `extraction_confidence_daily` |

---

## Read Model Schemas

### activation_funnel

```sql
CREATE TABLE activation_funnel (
    tenant_id           UUID NOT NULL,
    day                 DATE NOT NULL,
    trial_tenants       INT NOT NULL,        -- tenants that connected a source
    activated_tenants   INT NOT NULL,        -- tenants that opened first gap ≤ 30 min
    activation_rate     NUMERIC(5,4) NOT NULL,
    PRIMARY KEY (tenant_id, day)
);
```

### extraction_throughput_hourly

```sql
CREATE TABLE extraction_throughput_hourly (
    tenant_id   UUID NOT NULL,
    hour        TIMESTAMPTZ NOT NULL,
    file_type   TEXT NOT NULL,
    files_count INT NOT NULL,
    PRIMARY KEY (tenant_id, hour, file_type)
);
```

### classification_accuracy_daily

```sql
CREATE TABLE classification_accuracy_daily (
    tenant_id           UUID NOT NULL,
    day                 DATE NOT NULL,
    total_reviews       INT NOT NULL,
    disagreements       INT NOT NULL,        -- steward overrode the automated level
    accuracy_proxy      NUMERIC(5,4) NOT NULL, -- 1 − (disagreements / total_reviews)
    PRIMARY KEY (tenant_id, day)
);
```

### gap_lifecycle

```sql
CREATE TABLE gap_lifecycle (
    gap_id          UUID NOT NULL,
    tenant_id       UUID NOT NULL,
    opened_at       TIMESTAMPTZ NOT NULL,
    closed_at       TIMESTAMPTZ,            -- NULL until closed
    sla_deadline    TIMESTAMPTZ NOT NULL,   -- configured per tenant
    within_sla      BOOLEAN,               -- set when closed_at is recorded
    PRIMARY KEY (gap_id)
);
```

### quality_gate_outcomes_daily

```sql
CREATE TABLE quality_gate_outcomes_daily (
    tenant_id       UUID NOT NULL,
    day             DATE NOT NULL,
    stage           TEXT NOT NULL,
    total_outputs   INT NOT NULL,
    passed          INT NOT NULL,
    quarantined     INT NOT NULL,
    pass_rate       NUMERIC(5,4) NOT NULL,
    PRIMARY KEY (tenant_id, day, stage)
);
```

### extraction_confidence_daily

```sql
CREATE TABLE extraction_confidence_daily (
    tenant_id       UUID NOT NULL,
    day             DATE NOT NULL,
    entity_type     TEXT NOT NULL,
    file_type       TEXT NOT NULL,
    avg_confidence  NUMERIC(4,3) NOT NULL,
    sample_count    INT NOT NULL,
    PRIMARY KEY (tenant_id, day, entity_type, file_type)
);
```

---

## Worked Example — Extraction Confidence Trend, End to End

This example traces a single metric from the elicitation decision through to the standing dashboard — illustrating how nothing here required inventing new pipeline instrumentation.

### 1. Elicitation (`analytics-requirements`)

The data-engineer needs to know whether extraction quality is degrading before it silently overwhelms the steward review queue. The decision: "When do we intervene on the extraction model or tune thresholds?"

This passes the vanity-metric check: the metric names a specific decision, with a specific threshold that triggers it.

### 2. Metric Definition

```
Name:     Extraction Confidence Trend
Formula:  7-day rolling average of confidence score from EntityExtracted
          events, grouped by entity_type and file_type
Source:   EntityExtracted event payload (entity_type, file_type,
          confidence), aggregated into extraction_confidence_daily
Owner:    data-engineer
Target:   ≥ 0.90 sustained for PII entity types (data-quality-rules'
          threshold); alert if the 7-day average drops below 0.85
          for two consecutive days
```

### 3. Event-to-Metric Trace

```
EntityExtracted (Entity Extraction pipeline stage, data-pipeline-implementation)
  → extraction_confidence_daily (streaming aggregation, updated per event batch)
  → 7-day rolling window computed at read time by the dashboard query
```

### 4. Instrumentation Implementation

The Entity Extraction stage worker (`data-pipeline-implementation`) already emits `EntityExtracted` with a `confidence` field per entity. No new pipeline stage is needed — the metric is a new aggregation over an event that already exists. This is the common case once the pipeline is instrumented for its quality gates (`data-quality-rules`).

The streaming aggregation job updates `extraction_confidence_daily` using a tumbling daily window:

```sql
-- Run daily at 00:05 UTC — aggregates the previous day's EntityExtracted events
INSERT INTO extraction_confidence_daily (
    tenant_id, day, entity_type, file_type, avg_confidence, sample_count
)
SELECT
    tenant_id,
    DATE(extracted_at) AS day,
    entity_type,
    file_type,
    AVG(confidence)::NUMERIC(4,3) AS avg_confidence,
    COUNT(*) AS sample_count
FROM entity_extracted_staging   -- written by the pipeline stage consumer
WHERE extracted_at >= CURRENT_DATE - INTERVAL '1 day'
  AND extracted_at < CURRENT_DATE
GROUP BY tenant_id, DATE(extracted_at), entity_type, file_type
ON CONFLICT (tenant_id, day, entity_type, file_type) DO UPDATE
    SET avg_confidence = EXCLUDED.avg_confidence,
        sample_count   = EXCLUDED.sample_count;
```

### 5. 7-Day Rolling Window Query (dashboard)

```sql
SELECT
    day,
    entity_type,
    AVG(avg_confidence) OVER (
        PARTITION BY tenant_id, entity_type, file_type
        ORDER BY day
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_7d_avg
FROM extraction_confidence_daily
WHERE tenant_id = $1
  AND day >= CURRENT_DATE - INTERVAL '90 days'
ORDER BY day, entity_type;
```

### 6. Alert Rule

```yaml
# dashboard-specification alert definition
- name: ExtractionConfidenceDegrading
  condition: rolling_7d_avg < 0.85 for 2 consecutive days
  severity: warning
  notify: data-engineer
  message: "PII extraction confidence below 0.85 — review extraction model thresholds"
```

### 7. Consumption

Surfaces as:
- A chart widget on the internal data-quality dashboard (`dashboard-specification`) — the 7-day rolling average per entity type, with threshold lines at 0.90 and 0.85.
- Referenced in the `data-storytelling` narrative brief presented to Shafi as a leading quality indicator.

### Why No New Instrumentation Was Needed

The `confidence` score was a first-class field on `EntityExtracted` because `data-quality-rules` required the pipeline stage to emit it for its own quality gate. The metric is a new *aggregation* over an event that already existed — not a new event, not a new topic, not a new consumer. This is the correct pattern: check the event-to-metric trace for an existing source before proposing new pipeline stages.

---

## Dashboard / Report Surface Map

| Metric | Surfaces in |
|---|---|
| Activation rate | Shafi's internal product-health dashboard (`dashboard-specification`) |
| Extraction throughput | Internal ops dashboard; referenced in `data-pipeline-implementation`'s backpressure tuning |
| Classification accuracy proxy | Internal data-quality dashboard; informs `data-quality-rules` threshold tuning |
| Gap-closure rate | Compliance officer's audit-prep dashboard; SOC 2 Evidence Report (`reporting-spec`) |
| Data quality pass rate | Internal data-quality dashboard |
| Extraction confidence trend | Internal data-quality dashboard (alert on 2-day degradation); `data-storytelling` brief |

Every metric has at least one named consuming surface. A metric fully defined and computed but with no `dashboard-specification` widget or `reporting-spec` section consuming it is orphaned instrumentation — the same discipline `analytics-requirements` applies to elicitation applies here.
