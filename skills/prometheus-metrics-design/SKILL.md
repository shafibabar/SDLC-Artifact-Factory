---
name: prometheus-metrics-design
description: >
  Teaches how to design and operate the Prometheus metrics backend — naming
  conventions (base units, unit suffixes, _total), per-metric label allowlists
  and cardinality budgets, the tenant_id policy under physical multi-tenancy,
  histogram bucket design per latency class, recording rules and their
  level:metric:operation naming, the per-tenant scrape and federation topology,
  and the PromQL patterns that answer the standard operational questions. The
  stack half of the metrics pipeline — services emit the signals, this skill
  stores and shapes them. Used by the platform-engineer during Deploy.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, observability, prometheus, metrics, promql, cardinality, recording-rules, federation]
---

# Prometheus Metrics Design

## Purpose

Prometheus is the platform's metrics backend — open-source, pull-based, and self-hosted (frugal: no metrics SaaS). Services emit RED and USE metrics through the OpenTelemetry Go SDK over OTLP (`opentelemetry-instrumentation` — the in-code half; this skill does not re-teach it); the OpenTelemetry Collector exposes them on a Prometheus endpoint, and Prometheus scrapes, stores, and evaluates them. Grafana reads Prometheus for dashboards; Alertmanager evaluates its alerts (`alerting-rules-design`); Service Level Objectives are computed from its series (`slo-definition`).

A metrics backend lives or dies on discipline: consistent names make queries reusable across services, bounded labels keep the series count survivable, and correct histogram buckets make percentiles meaningful. This skill encodes those standards.

---

## Metric Taxonomy — What Prometheus Receives

The taxonomy is set upstream and is not renegotiated here:

| Class | Framework | Emitted by | Examples |
|---|---|---|---|
| Interface metrics | **RED** (Rate/Errors/Duration) | every endpoint and event consumer | `http_server_requests_total`, `http_server_duration_seconds` |
| Resource metrics | **USE** (Utilization/Saturation/Errors) | every pool, queue, consumer | `db_pool_in_use`, `pipeline_consumer_lag` |
| Platform metrics | infrastructure exporters | kube-state-metrics, node-exporter, Linkerd | pod restarts, CPU/memory, mesh success rate |

OTLP names are translated on the way in: dots become underscores, the unit becomes a suffix, cumulative counters gain `_total`. OTel's `http.server.duration` (unit `s`) is queried in Prometheus as `http_server_duration_seconds`. Design queries, recording rules, and dashboards against the translated names.

Health probes are not metrics — liveness and readiness belong to `health-check-design`; Prometheus measures behaviour, Kubernetes probes gate traffic.

---

## Naming Conventions

| Rule | Right | Wrong |
|---|---|---|
| `snake_case`, prefixed by subsystem | `pipeline_documents_processed_total` | `DocumentsProcessed` |
| Base units only (seconds, bytes, ratios 0–1) | `http_server_duration_seconds` | `_millis`, `_kb`, percentages |
| Unit as suffix | `payload_size_bytes` | `bytes_payload` |
| Counters end `_total` | `classification_errors_total` | `classification_error_count` |
| Gauges are bare nouns | `pipeline_consumer_lag` | `pipeline_consumer_lag_total` |
| Ratios end `_ratio`, scaled 0–1 | `db_pool_utilization_ratio` | `db_pool_utilization_percent` |
| No rate baked into the name | `requests_total` + `rate()` at query time | `requests_per_second` |

The name states *what is measured*; PromQL states *how it is read*. A counter plus `rate()` can answer per-second, per-minute, and per-day questions — a pre-rated metric can answer only one.

---

## Label and Cardinality Budget

Every label value mints a new time series. Cardinality is a budget, spent deliberately:

- **Per-metric label allowlist.** Each metric declares its permitted labels and their bounded value sets; anything not on the allowlist is dropped at the Collector. New labels are a reviewed change, not a code-side convenience.
- **Series budget:** a service should hold under ~5,000 active series; a single metric under ~1,000. Check with `count({__name__=~"pipeline_.*"})` and the `prometheus_tsdb_head_series` gauge after every deploy.
- **Never as labels:** UUIDs, raw URL paths, user ids, emails, file names, free text. That detail belongs on trace spans (`distributed-tracing-design`), reached from metrics via exemplars.

**The `tenant_id` policy under physical multi-tenancy:** each tenant runs an isolated deployment with its own Prometheus, so tenant identity is a property of the *installation*, not of any metric. It is stamped once as an `external_label` on the tenant's Prometheus (below) — never emitted as a metric label by services. This keeps per-service cardinality flat no matter how many tenants onboard, and matches the `opentelemetry-instrumentation` rule that forbids per-tenant labels in code.

Example allowlist for the classification pipeline:

| Metric | Allowed labels |
|---|---|
| `http_server_requests_total` | `service`, `http_route`, `http_request_method`, `http_response_status_code` |
| `http_server_duration_seconds` | `service`, `http_route`, `http_request_method` |
| `pipeline_documents_processed_total` | `service`, `source_type` (gdrive/s3), `document_type` (pdf/docx/xlsx), `outcome` (ok/error/dlq) |
| `pipeline_consumer_lag` | `service`, `topic` |
| `pipeline_dlq_depth` | `service`, `topic` |

Worst case is bounded arithmetic: `pipeline_documents_processed_total` = 3 services × 2 sources × 3 types × 3 outcomes = 54 series. That is a budget holding.

---

## Histogram Bucket Design

`histogram_quantile` interpolates within buckets — percentiles are only as precise as the boundaries. Buckets are chosen per latency class, and **one boundary always sits exactly on the SLO threshold** so the latency Service Level Indicator (SLI) (`slo-definition`) is an exact bucket ratio, not an interpolation:

| Latency class | Example | Explicit buckets (seconds) |
|---|---|---|
| Fast sync read (SLO p95 < 0.3s) | `GET /v1/data-assets/{id}` | 0.005, 0.01, 0.025, 0.05, 0.1, **0.3**, 0.5, 1, 2.5 |
| Sync command (SLO p99 < 0.8s) | `ClassifyDataAsset` via `PATCH …/classification` | 0.01, 0.05, 0.1, 0.25, 0.5, **0.8**, 1, 2.5, 5 |
| Async unit of work (seconds) | entity-extractor per-document extraction | 0.1, 0.5, 1, 2.5, 5, 10, **30**, 60, 120 |
| Pipeline end-to-end (minutes) | discovery → classified freshness | 30, 60, 120, 300, **600**, 1200, 1800, 3600 |

Bucket boundaries are set in code (`opentelemetry-instrumentation` sets them per instrument); this table is the platform standard those instruments implement. Ten to twelve buckets is the ceiling — every bucket is a full extra series per label combination.

---

## Recording Rules

Recording rules pre-compute the expensive, frequently-asked queries so dashboards, SLO calculations, and federation read cheap flat series. Naming follows the Prometheus convention `level:metric:operations` — aggregation level, metric name, operations applied:

```yaml
# rules/service-red.yaml
groups:
  - name: service-red
    interval: 30s
    rules:
      - record: service:http_requests:rate5m
        expr: sum by (service) (rate(http_server_requests_total[5m]))
      - record: service:http_request_errors:ratio_rate5m
        expr: |
          sum by (service) (rate(http_server_requests_total{http_response_status_code=~"5.."}[5m]))
          /
          sum by (service) (rate(http_server_requests_total[5m]))
      - record: service:http_request_duration_seconds:p99_5m
        expr: |
          histogram_quantile(0.99,
            sum by (service, le) (rate(http_server_duration_seconds_bucket[5m])))
      - record: service:pipeline_consumer_lag:max
        expr: max by (service, topic) (pipeline_consumer_lag)
```

Write a recording rule when a query is (a) on a dashboard refreshed continuously, (b) an SLI feeding SLO burn-rate alerts, or (c) federated upward. Do not record one-off exploration queries — every rule is evaluated forever.

---

## Scrape and Federation Topology for Per-Tenant Deployments

Physical multi-tenancy means one observability spine per tenant, with a thin aggregate layer for the operator:

```
tenant namespace: estate-scanner ─┐
                  entity-extractor ├─ OTLP → otel-collector ──(scrape)── tenant Prometheus
                  compliance-engine ┘                                        │ /federate
                                                                            ▼
                            central Prometheus  ←── only service:* recorded series
                                    │
                                Grafana (one instance, tenant variable via external label)
```

- **Tenant Prometheus** scrapes only its own namespace, holds full-resolution series, evaluates recording and alerting rules locally, and stamps every series with its identity via `external_labels`.
- **Central Prometheus** federates *only* the `service:*` recorded aggregates — never raw series. Full-resolution data stays in the tenant; the operator view stays small and cheap.
- Scrapes traverse Linkerd, so metrics are encrypted in transit by mesh mTLS with no extra configuration.

```yaml
# tenant prometheus.yml (deployed by the tenant Helm Chart)
global:
  scrape_interval: 30s
  external_labels:
    tenant: acme-corp          # tenant identity lives here — never in service code
    environment: production
scrape_configs:
  - job_name: otel-collector   # services export OTLP; the collector exposes /metrics
    static_configs:
      - targets: ["otel-collector:8889"]

# central prometheus.yml — aggregate view only
scrape_configs:
  - job_name: federate-tenants
    honor_labels: true         # keep the tenant external label from the source
    metrics_path: /federate
    params:
      match[]: ['{__name__=~"service:.*"}']
    kubernetes_sd_configs:
      - role: service
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_label_app]
        regex: prometheus-tenant
        action: keep
```

---

## PromQL Patterns for the Standard Questions

| Question | Pattern |
|---|---|
| Error rate of compliance-engine? | `service:http_request_errors:ratio_rate5m{service="compliance-engine"}` |
| p99 latency of the ClassifyDataAsset route? | `histogram_quantile(0.99, sum by (le) (rate(http_server_duration_seconds_bucket{service="compliance-engine", http_route="/v1/data-assets/{id}/classification"}[5m])))` |
| Is the pipeline keeping up? | `max by (topic) (pipeline_consumer_lag{service="entity-extractor"})` trending via `deriv(...[15m])` |
| Is the Dead Letter Queue (DLQ) filling? | `sum by (service, topic) (pipeline_dlq_depth) > 0` |
| DB pool saturation? | `db_pool_in_use / db_pool_max` approaching 1 |
| Throughput by document type? | `sum by (document_type) (rate(pipeline_documents_processed_total{outcome="ok"}[5m]))` |

Rules of reading: `rate()` before `sum()` (counters reset on restart; summing raw counters across restarts lies); `histogram_quantile` over `sum by (le, …)` of bucket rates; latency always as percentiles, never averages — the same standard `go-load-test` gates on.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Naming | Base units, unit suffix, `_total` on counters | Mixed units; rates baked into names |
| Label allowlist | Every metric has a documented bounded label set | Ad-hoc labels added in code without review |
| Cardinality budget | Series counted per service and held under budget | Unbounded labels; series growth unmonitored |
| Tenant isolation | `tenant` as external label only; per-tenant Prometheus | `tenant_id` as a metric label anywhere |
| Buckets | Explicit per latency class; boundary on SLO threshold | Default buckets; SLO between boundaries |
| Recording rules | `level:metric:operations` naming; SLIs and dashboards pre-computed | Dashboards running raw heavy queries; ad-hoc rule names |
| Federation | Central scrapes `service:*` aggregates only | Raw series federated; duplicated full-resolution storage |
| Frugality | Self-hosted Prometheus/Grafana per stack | Metrics SaaS; oversized retention nobody queries |

---

## Anti-Patterns

- **`tenant_id` as a metric label** — under physical multi-tenancy this is doubly wrong: it grows series linearly with onboarding *and* it is redundant, because the tenant's own Prometheus already knows who it is. External label, always.
- **Federating raw series** — pulling every `http_*` series into the central Prometheus recreates every tenant's storage bill in one place and melts the aggregate instance. Federate recorded aggregates only.
- **Averaging latency** — `rate(sum)/rate(count)` hides the tail that users actually feel and that the SLO is written against. Percentiles from buckets, always.
- **`sum` before `rate`** — summing raw counters across pods, then rating, corrupts the result on every pod restart. Rate first, then aggregate.
- **Default buckets on an SLO metric** — if no boundary sits at 0.3s, the "requests under 300ms" SLI is an interpolated guess. Buckets bracket the SLO.
- **Recording rule sprawl** — recording every query ever written makes rule evaluation itself the heaviest tenant workload. Record what dashboards, SLOs, and federation read repeatedly.
- **Scraping services directly while also exporting OTLP** — two paths for the same metrics produce double-counted series that disagree. One path: SDK → OTLP → Collector → scrape.

---

## Output Format

Produces the metrics design document plus deployable configuration:

```markdown
---
name: prometheus-metrics-design-<product>
product: <product-name>
version: 1.0.0
phase: deploy
created: <date>
owner: platform-engineer
---

# Prometheus Metrics Design — <Product>

## Scrape Topology
[Per-tenant Prometheus, collector endpoint, central federation diagram]

## Metric Inventory and Label Allowlist
| Metric | Type | Unit | Allowed labels | Worst-case series |

## Histogram Bucket Classes
| Latency class | SLO threshold | Buckets |

## Recording Rules
| Rule name (level:metric:operations) | Expression | Consumed by |

## Cardinality Budget
[Per-service series budget, current usage, review trigger]

## Configuration Files
- prometheus/tenant/prometheus.yml
- prometheus/central/prometheus.yml
- prometheus/rules/*.yaml
```
