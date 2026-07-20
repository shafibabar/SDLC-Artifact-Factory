---
name: metrics-instrumentation-plan
description: >
  Teaches how to plan the connection between product and business metrics
  (activation, extraction throughput, classification accuracy, gap-closure rate)
  and their instrumentation source — distinct from `opentelemetry-instrumentation`'s
  system RED/USE metrics, these are PRODUCT metrics. Covers the metric definition
  table (name, formula, source, owner, target), event-to-metric traceability, and
  how metrics feed `dashboard-specification` and `reporting-spec` for consumption.
  Used by the data-engineer during Data.
version: 1.0.0
phase: data
owner: data-engineer
created: 2026-07-20
tags: [data, analytics, product-metrics, instrumentation, traceability, activation, throughput]
---

# Metrics Instrumentation Plan

## Purpose

A metric that exists as a concept in an OKR document (`okr-authoring`) or a stakeholder requirement (`analytics-requirements`) is not yet a metric a dashboard can show — someone has to define exactly which Domain Events or table rows produce it, where it's computed, and who's accountable when the number looks wrong. This skill is that connective plan: it takes named product and business metrics and specifies their instrumentation source, so `dashboard-specification` and `reporting-spec` have something concrete to consume.

This is explicitly about **product metrics** — activation, extraction throughput, classification accuracy, gap-closure rate — the things that tell you whether the product is working for customers. It is not about **system metrics** — request rate, error rate, latency, resource saturation — which is `opentelemetry-instrumentation`'s domain (RED/USE, owned by the backend-engineer). The two are easy to conflate because both eventually appear as a number on a dashboard; the test is *what question the number answers*. "Is the service healthy?" is a system metric. "Is the customer succeeding?" is a product metric.

---

## Product Metrics vs. System Metrics

| | System metrics (`opentelemetry-instrumentation`) | Product metrics (this skill) |
|---|---|---|
| Answers | Is the infrastructure healthy? | Is the product delivering value? |
| Examples | HTTP request rate, p99 latency, consumer lag, DB pool utilization | Trial-to-activation rate, extraction confidence trend, gap-closure rate |
| Instrument | OpenTelemetry counters/histograms/gauges, scraped by Prometheus | Domain Events and Read Model aggregations, stored in PostgreSQL |
| Owner | backend-engineer / platform-engineer | data-engineer |
| Consumed by | On-call engineers, SLO dashboards, alerting | Product stakeholders, compliance officers, Shafi |
| Cardinality discipline | Low-cardinality labels only (`opentelemetry-instrumentation`'s rule) | Can carry tenant/customer-level detail since it's stored relationally, not as high-cardinality metric labels |

A pipeline's consumer lag (system) tells an engineer the extraction stage is falling behind. Extraction confidence trend (product) tells a data-engineer whether the *quality* of what the stage produces is degrading. Both matter; they are different metrics with different owners, feeding different consumers.

---

## The Metric Definition Table

Every product metric gets one row, with all five fields filled before it's considered instrumented:

| Field | Meaning |
|---|---|
| **Name** | Canonical name, in Ubiquitous Language, used consistently everywhere the metric appears |
| **Formula** | The precise calculation — same precision discipline as `dashboard-specification`'s metric definitions |
| **Source table/event** | The Domain Event(s) or Read Model the metric is computed from |
| **Owner** | Who is accountable for correctness and for acting when the metric moves |
| **Target** | The value that represents success, tied to an OKR Key Result where one exists |

```
Name:     Extraction Confidence Trend
Formula:  7-day rolling average of extraction confidence score,
          across all EntityExtracted events, grouped by entity type
Source:   EntityExtracted event payload (confidence field), aggregated
          into extraction_confidence_daily (a materialized Read Model)
Owner:    data-engineer
Target:   ≥ 0.90 sustained (matches the data-quality-rules confidence
          threshold for general PII entity types)
```

---

## Core Product Metrics for the First Product

A starting set, each defined to the same precision as the worked example below:

| Metric | Formula | Source | Owner | Target |
|---|---|---|---|---|
| **Activation rate** | % of trial tenants that reach first compliance gap discovery within 30 minutes of connecting a source | `DataSourceConnected` → `ComplianceGapOpened` event pair, timestamp delta | data-engineer | 80% (ties to `okr-authoring`'s KR1.1) |
| **Extraction throughput** | Files processed per hour, by file type | `FileProcessed` event count, windowed | data-engineer | Sized to estate scan SLOs (`data-pipeline-design`) |
| **Classification accuracy proxy** | 1 − (steward-corrected classifications ÷ total steward reviews) | `DataAssetReclassified` events where the reviewer's decision *disagreed* with the automated provisional level, vs. total review events | data-engineer | ≥ 0.85 (below this, extraction model tuning is prioritized) |
| **Gap-closure rate** | % of `ComplianceGap` records moved from open to closed within the customer's target remediation window | `ComplianceGapOpened` → `ComplianceGapClosed` event pair, against a configured SLA | data-engineer | 90% within SLA |
| **Data quality pass rate** | % of pipeline stage outputs that pass their quality gate without quarantine (see `data-quality-rules`) | Quality gate outcomes per stage | data-engineer | ≥ 95% pass, by stage |

These are starting definitions — new metrics enter this plan only after passing `analytics-requirements`' decision-first elicitation and vanity-metric check; a metric that can't name the decision it informs does not belong in this table.

---

## Event-to-Metric Traceability

Every metric traces backward to the specific Domain Event(s) that roll up into it. This traceability is what makes a metric auditable — when a number looks wrong, the first question is "which events fed this," and the answer should be a direct lookup, not an investigation.

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

Maintain this as an explicit table, not tribal knowledge — it is what lets someone (including a future data-engineer) answer "what would change this number" without reading pipeline source code.

| Metric | Contributing Domain Events | Computed in |
|---|---|---|
| Activation rate | `DataSourceConnected`, `ComplianceGapOpened` | Daily batch job → `activation_funnel` Read Model |
| Extraction throughput | `FileProcessed` | Streaming aggregation → `extraction_throughput_hourly` |
| Classification accuracy proxy | `DataAssetClassified`, `DataAssetReclassified` | Daily batch job → `classification_accuracy_daily` |
| Gap-closure rate | `ComplianceGapOpened`, `ComplianceGapClosed` | Streaming aggregation → `gap_lifecycle`, daily rollup |
| Data quality pass rate | Quality gate outcome events (per `data-quality-rules`) | Streaming aggregation → `quality_gate_outcomes_daily` |

---

## Dashboard / Report Consumption

A metric defined here is inert until something consumes it. Every row in the metric definition table states where it surfaces:

| Metric | Surfaces in |
|---|---|
| Activation rate | Shafi's internal product-health dashboard (`dashboard-specification`) |
| Extraction throughput | Internal ops dashboard; referenced in `data-pipeline-implementation`'s backpressure tuning |
| Classification accuracy proxy | Internal data-quality dashboard; informs `data-quality-rules` threshold tuning |
| Gap-closure rate | Compliance officer's audit-prep dashboard; SOC 2 Evidence Report (`reporting-spec`) |
| Data quality pass rate | Internal data-quality dashboard |

This closes the loop: `analytics-requirements` established the decision, this skill defines exactly how the metric is computed and traced, and `dashboard-specification`/`reporting-spec` define how it's presented. A metric plan with no consuming dashboard or report is the same defect `analytics-requirements` calls out for an ownerless or undecided metric — instrumentation with nowhere to surface is wasted pipeline load.

---

## Worked Example — Extraction-Confidence-Trend, End to End

**1. Elicitation (`analytics-requirements`):** the data-engineer needs to know whether extraction quality is degrading before it silently overwhelms the steward review queue — the decision is "when do we intervene on the extraction model or tune thresholds."

**2. Metric definition (this skill):**

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

**3. Event-to-metric trace:**

```
EntityExtracted (Entity Extraction pipeline stage, data-pipeline-implementation)
  → extraction_confidence_daily (streaming aggregation, updated per event)
  → 7-day rolling window computed at read time by the dashboard query
```

**4. Instrumentation implementation:** the Entity Extraction stage worker (`data-pipeline-implementation`) already emits `EntityExtracted` with a `confidence` field per entity. No new pipeline stage is needed — the metric is a new aggregation over an event that already exists, which is the common case once the pipeline is instrumented for its own quality gates (`data-quality-rules`).

```sql
CREATE TABLE extraction_confidence_daily (
    tenant_id    UUID NOT NULL,
    day          DATE NOT NULL,
    entity_type  TEXT NOT NULL,
    file_type    TEXT NOT NULL,
    avg_confidence NUMERIC(4,3) NOT NULL,
    sample_count INT NOT NULL,
    PRIMARY KEY (tenant_id, day, entity_type, file_type)
);
```

**5. Consumption:** surfaces as the chart in the `data-storytelling` worked example presented to Shafi, and as a widget on the internal data-quality dashboard (`dashboard-specification`) that triggers the alert threshold above.

This is the full loop: a decision (elicited), a precise definition (this skill), a traceable event source (already emitted by the pipeline), and two consuming surfaces (a narrative brief and a standing dashboard) — nothing here required inventing new instrumentation, because the confidence score was already a first-class field on the event the pipeline stage was contractually required to emit.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Product vs. system distinction respected | Metric answers "is the product succeeding," not "is the infrastructure healthy" | System RED/USE metric mislabeled as a product metric, or vice versa |
| All five fields defined | Name, formula, source, owner, target present for every metric | Any field missing |
| Traced to Domain Events | Every metric names the specific event(s) that roll up into it | Metric with an unclear or undocumented source |
| Consuming surface named | Every metric states which dashboard or report it feeds | Instrumented metric with no consumer |
| Passed analytics-requirements gate | Metric traces to a decision or OKR Key Result | Metric added without decision justification |
| No duplicate instrumentation | Metric reuses existing pipeline-emitted events where possible | New pipeline stage built solely to emit a metric already derivable from existing events |
| Target tied to OKR where applicable | Metric target matches or explains its relationship to a Key Result | Target picked arbitrarily with no OKR link |

---

## Anti-Patterns

- **Conflating product and system metrics.** Putting consumer lag on the same dashboard, with the same framing, as gap-closure rate. They answer different questions for different audiences; mixing them dilutes both (see `opentelemetry-instrumentation`'s RED/USE for the system half).
- **The metric with no owner.** Defining a formula and a source but no accountable owner — the same failure `analytics-requirements` calls out, recurring here because instrumentation plans are often written after the elicitation step is treated as "done" and skipped on the follow-through.
- **Untraced metrics.** A dashboard number with no documented path back to the Domain Events that produce it. When the number looks wrong, "which events feed this" should be a lookup in this plan, not a codebase archaeology exercise.
- **Building a new pipeline stage just to emit a metric.** Adding pipeline complexity (a new consumer, a new topic) to compute something already derivable from an existing event's payload. Check the event-to-metric trace table for an existing source before proposing new instrumentation.
- **Orphaned instrumentation.** A metric fully defined and computed, with no `dashboard-specification` widget or `reporting-spec` section consuming it. If nothing surfaces the number, the pipeline load computing it is unjustified — the same discipline `analytics-requirements` applies to elicitation applies here to build-out.
- **Targets with no OKR link.** Picking a round number ("95%!") as a target with no connection to what the business actually needs, making it impossible to tell whether hitting the target matters.
- **High-cardinality product-metric labels reused as system-metric labels.** Product metrics can carry tenant-level detail because they live in PostgreSQL, not OTel metric series — but that detail must never leak into an OpenTelemetry metric attribute (`opentelemetry-instrumentation`'s cardinality rule still applies to the system-metrics half of the same service).

---

## Output Format

```markdown
---
name: metrics-instrumentation-plan
product: [product name]
version: 1.0.0
phase: data
created: [date]
owner: data-engineer
---

# Metrics Instrumentation Plan

## Metric Definitions
| Name | Formula | Source table/event | Owner | Target |
|---|---|---|---|---|

## Event-to-Metric Traceability
| Metric | Contributing Domain Events | Computed in |
|---|---|---|

## Consumption
| Metric | Surfaces in (dashboard / report) |
|---|---|

## OKR Alignment
| Metric | Related Key Result (okr-authoring) |
|---|---|
```
