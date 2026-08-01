---
name: metrics-instrumentation-plan
description: >
  Teaches how to plan the connection between product, business, and delivery metrics
  and their instrumentation source. Product metrics (activation, extraction throughput,
  classification accuracy, gap-closure rate) — the "is the customer succeeding?" layer;
  distinct from `opentelemetry-instrumentation`'s system RED/USE metrics. Delivery
  metrics (DORA four: Deployment Frequency, Lead Time for Changes, MTTR, Change Failure
  Rate) — the "is the team delivering effectively?" layer, sourced from CI/CD pipeline
  events (GitHub Actions API, Alertmanager, cd-pipeline commit log), not application
  telemetry. Covers the metric definition table (name, formula, source, owner, target),
  event-to-metric traceability, and how metrics feed `dashboard-specification` and
  `reporting-spec`. Used by the data-engineer and platform-engineer during Data and
  Deploy phases.
version: 2.0.0
phase: data
owner: data-engineer
created: 2026-07-20
tags: [data, analytics, product-metrics, delivery-metrics, dora, instrumentation, traceability, activation, throughput, deploy]
produces: metrics-instrumentation-plan
domain: data
status: stable
---

# Metrics Instrumentation Plan

## Purpose

A metric that exists as a concept in an OKR document (`okr-authoring`) or a stakeholder requirement (`analytics-requirements`) is not yet a metric a dashboard can show — someone has to define exactly which Domain Events, CI/CD API calls, or table rows produce it, where it's computed, and who's accountable when the number looks wrong. This skill is that connective plan.

Three distinct categories of metric exist for any service. Conflating them causes instrumentation owned by the wrong team, stored in the wrong system, and consumed by the wrong audience.

---

## Three Metric Categories

| | System metrics | Product metrics (this skill) | Delivery metrics (this skill) |
|---|---|---|---|
| **Answers** | Is the infrastructure healthy? | Is the product delivering value? | Is the team delivering effectively? |
| **Examples** | HTTP rate, p99 latency, consumer lag | Trial-to-activation rate, gap-closure rate | Deployment Frequency, Lead Time, MTTR, Change Failure Rate |
| **Instrument** | OTel counters/histograms, Prometheus | Domain Events + Read Model aggregations in PostgreSQL | GitHub Actions API, Alertmanager, cd-pipeline commit log |
| **Owner** | backend-engineer / platform-engineer | data-engineer | platform-engineer |
| **Consumed by** | On-call, SLO dashboards, alerting | Product stakeholders, compliance officers, Shafi | Engineering leads, delivery retrospectives |
| **Source** | Application telemetry at runtime | Domain Events emitted by application | CI/CD pipeline events — not the application itself |
| **Skill** | `opentelemetry-instrumentation` | This skill | This skill |

**Key distinctions:**
- System → "Is the service healthy?" → instrumented in the application via OTel
- Product → "Is the customer succeeding?" → instrumented from Domain Events
- Delivery → "Is the team delivering effectively?" → instrumented from the CI/CD pipeline, never from the application

---

## The Metric Definition Table

Every metric gets one row, with all five fields filled before it's considered instrumented:

| Field | Meaning |
|---|---|
| **Name** | Canonical name, in Ubiquitous Language, used consistently everywhere the metric appears |
| **Formula** | The precise calculation — same precision discipline as `dashboard-specification`'s metric definitions |
| **Source** | The Domain Event(s), CI/CD API, or system the metric is computed from |
| **Owner** | Who is accountable for correctness and for acting when the metric moves |
| **Target** | The value that represents success, tied to an OKR Key Result or Accelerate cluster benchmark |

---

## Core Product Metrics

| Metric | Formula | Source | Owner | Target |
|---|---|---|---|---|
| **Activation rate** | % of trial tenants reaching first compliance gap within 30 min of connecting a source | `DataSourceConnected` → `ComplianceGapOpened` pair, timestamp delta | data-engineer | 80% (KR1.1) |
| **Extraction throughput** | Files processed per hour, by file type | `FileProcessed` event count, windowed | data-engineer | Sized to estate scan SLOs |
| **Classification accuracy proxy** | 1 − (steward-corrected ÷ total steward reviews) | `DataAssetReclassified` (disagreement) vs. total review events | data-engineer | ≥ 0.85 |
| **Gap-closure rate** | % of `ComplianceGap` records closed within remediation window | `ComplianceGapOpened` → `ComplianceGapClosed` pair, against configured SLA | data-engineer | 90% within SLA |
| **Data quality pass rate** | % of pipeline outputs passing quality gate without quarantine | Quality gate outcome events per `data-quality-rules` | data-engineer | ≥ 95% per stage |

New metrics enter this plan only after passing `analytics-requirements`' vanity-metric check — a metric that can't name the decision it informs does not belong here. Full event-to-metric traceability, SQL Read Model schemas, and worked end-to-end example: `references/product-metrics-catalogue.md`.

---

## Delivery Metrics — DORA Four

Delivery metrics are process metrics sourced from CI/CD pipeline events, not from the application. They require instrumentation from GitHub Actions, Alertmanager, and the cd-pipeline GitOps environment repository. The platform-engineer owns them — not the data-engineer or backend-engineer. Full per-metric instrumentation specs, storage architecture, collection scripts, and Grafana integration: `references/delivery-metrics-dora.md`.

| Metric | Formula | Source | Owner | Target (Accelerate High cluster) |
|---|---|---|---|---|
| **Deployment Frequency** | Count of successful main-branch deployments per week, per service | GitHub Actions `workflow_run` events: `conclusion=success`, `branch=main` | platform-engineer | Multiple per week (on demand) |
| **Lead Time for Changes** | `deploy_complete_timestamp` − `first_commit_in_PR_authored_date` | GitHub commit API (PR merge commit → earliest parent authored_date); cd-pipeline promotion PR merge timestamp | platform-engineer | < 1 hour |
| **MTTR** | `alert_resolved_timestamp` − `alert_fired_timestamp`, histogram | Alertmanager alert lifecycle; stored as `alertmanager_alert_duration_seconds` histogram | platform-engineer | P50 < 1 hour, P95 < 4 hours |
| **Change Failure Rate** | Count of `[ROLLBACK]`-tagged promotion commits ÷ count of all promotion commits in window | cd-pipeline environment repo commit log | platform-engineer | < 15% |

**Critical distinction:** DORA metrics are not instrumented in the application. A service does not emit an OTel counter for its own Deployment Frequency — the CI/CD pipeline emits it. Sourcing delivery metrics from application telemetry creates incorrect attribution and misses events that fail before the app starts.

---

## Event-to-Metric Traceability

Every metric traces backward to its specific source. When a number looks wrong, the path back to the source is a lookup in this table, not a codebase archaeology exercise. Maintain as an explicit table, not tribal knowledge.

| Metric | Source events / API | Computed in |
|---|---|---|
| Activation rate | `DataSourceConnected`, `ComplianceGapOpened` | Daily batch job → `activation_funnel` Read Model |
| Extraction throughput | `FileProcessed` | Streaming → `extraction_throughput_hourly` |
| Classification accuracy proxy | `DataAssetClassified`, `DataAssetReclassified` | Daily batch → `classification_accuracy_daily` |
| Gap-closure rate | `ComplianceGapOpened`, `ComplianceGapClosed` | Streaming → `gap_lifecycle`, daily rollup |
| Data quality pass rate | Quality gate outcome events | Streaming → `quality_gate_outcomes_daily` |
| Deployment Frequency | GitHub Actions `workflow_run` API (`conclusion=success`, `branch=main`) | Prometheus Pushgateway counter: `sdlc_deployment_frequency_total{service, env}` |
| Lead Time for Changes | GitHub commit API (authored_date) + cd-pipeline promotion PR merge timestamp | Computed at collection time → `delivery_metrics_daily` |
| MTTR | Alertmanager `/api/v2/alerts` lifecycle (firing → resolved) | `alertmanager_alert_duration_seconds` histogram, Prometheus |
| Change Failure Rate | cd-pipeline env repo commit log (commits tagged `[ROLLBACK]`) | Computed daily → `delivery_metrics_daily` |

---

## Dashboard / Report Consumption

Every metric in the definition table states where it surfaces. Instrumented metrics with no consuming surface are wasted pipeline load — the same discipline `analytics-requirements` applies to elicitation applies here.

| Metric | Surfaces in |
|---|---|
| Activation rate | Internal product-health dashboard (`dashboard-specification`) |
| Extraction throughput | Internal ops dashboard; `data-pipeline-implementation` backpressure tuning |
| Classification accuracy proxy | Internal data-quality dashboard; informs `data-quality-rules` threshold tuning |
| Gap-closure rate | Compliance officer's audit-prep dashboard; SOC 2 Evidence Report (`reporting-spec`) |
| Data quality pass rate | Internal data-quality dashboard |
| Deployment Frequency | Delivery performance dashboard (Grafana); DORA quarterly retrospective |
| Lead Time for Changes | Delivery performance dashboard; DORA quarterly retrospective |
| MTTR | SRE alerting dashboard; DORA quarterly retrospective |
| Change Failure Rate | Delivery performance dashboard; DORA quarterly retrospective |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Category distinction respected | Metric correctly classified as product, system, or delivery | System RED/USE labeled as product; delivery metric sourced from app telemetry |
| All five fields defined | Name, formula, source, owner, target present | Any field missing |
| Traced to source | Every metric names its specific source events, API, or commit log | Unclear or undocumented source |
| Consuming surface named | Every metric states which dashboard or report it feeds | Instrumented metric with no consumer |
| Passed analytics-requirements gate | Metric traces to a decision or OKR Key Result | Metric added without decision justification |
| DORA metrics sourced from CI/CD | Delivery metrics come from GitHub Actions API, Alertmanager, cd-pipeline | Delivery metric sourced from application-emitted OTel |
| Target tied to OKR or cluster | Product target matches a Key Result; delivery target matches Accelerate High cluster | Target picked arbitrarily with no link |
| No duplicate instrumentation | Metric reuses existing pipeline-emitted events where possible | New pipeline stage built solely to emit a derivable metric |

---

## Anti-Patterns

- **Conflating product and system metrics.** Consumer lag (system) and gap-closure rate (product) answer different questions for different audiences — mixing them on the same dashboard dilutes both.
- **Instrumenting DORA metrics from application telemetry.** Deployment Frequency is a CI/CD event, not an OTel counter from the running service. Sourcing from the app misses failed deploys and creates circular attribution.
- **The metric with no owner.** Defining formula and source but no accountable owner — the same failure `analytics-requirements` calls out, recurring at the instrumentation follow-through step.
- **Untraced metrics.** A dashboard number with no documented path back to its source events or API. The source should be a lookup in this plan, not an investigation.
- **Building new pipeline stages for derivable metrics.** Check the event-to-metric trace for an existing source before proposing new instrumentation.
- **Orphaned instrumentation.** A fully defined metric with no `dashboard-specification` widget or `reporting-spec` section consuming it.
- **High-cardinality product-metric labels in OTel.** Product metrics can carry tenant-level detail in PostgreSQL — that detail must never leak into OTel metric attributes.
- **Gaming DORA metrics.** Force-deploying more often without improving test automation increases Change Failure Rate — the four metrics are correlated, not independent levers (Accelerate, Ch. 2).

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
| Name | Formula | Source | Owner | Target |
|---|---|---|---|---|

## Event-to-Metric Traceability
| Metric | Source events / API | Computed in |
|---|---|---|

## Consumption
| Metric | Surfaces in (dashboard / report) |
|---|---|

## OKR Alignment
| Metric | Related Key Result (okr-authoring) |
|---|---|
```
