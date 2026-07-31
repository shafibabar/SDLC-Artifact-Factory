# Cardinality Budget, Histograms, Recording Rules, RED/USE Catalogues, and Federation

Reference for `prometheus-metrics-design`. Comprehensive, self-contained. Covers the cardinality
budget with worked good/bad label examples, per-service label allowlists and the worst-case
series arithmetic, histogram bucket design keyed to SLO thresholds, recording rules,
the RED and USE instrumentation catalogues for this repo's services, the per-tenant scrape and
central federation topology, and the PromQL patterns for the standard operational questions.

Repo services referenced throughout: **estate-scanner** (discovers assets in Google Drive / S3),
**entity-extractor** (extracts entities from PDF/DOCX/XLSX), **compliance-engine** (classifies and
scores assets against policy). Stack: Go + chi + pgx + PostgreSQL + Redpanda; per-tenant physical
isolation; OpenTelemetry → Collector → Prometheus → Grafana; Alertmanager; Linkerd mTLS.

---

## 1. The Cardinality Budget — Worked Examples

Every distinct combination of label values is a separate time series that Prometheus stores,
indexes, and evaluates rules over. Series count is the dominant cost driver of a Prometheus
instance, so labels are spent from a fixed budget, not added for convenience.

### Good vs bad labels

| Label | Verdict | Why |
|---|---|---|
| `outcome` (`ok`/`error`/`dlq`) | **good** | 3 bounded values, known at design time |
| `document_type` (`pdf`/`docx`/`xlsx`) | **good** | closed set fixed by the product |
| `http_response_status_code` | **good** | bounded (a few dozen codes; usually reduced to a class) |
| `http_route` (templated: `/v1/data-assets/{id}`) | **good** | one series per *route template*, not per URL |
| `user_id` / `tenant_id` | **bad** | unbounded — grows with every user/tenant onboarded |
| `document_id` / `request_id` (UUID) | **bad** | effectively infinite — one new series per document |
| `file_name` / raw URL path `/v1/data-assets/9f3c.../classification` | **bad** | unbounded free text; one series per file/URL |
| `error_message` | **bad** | free text; put it on a trace span or log, never a label |

The rule: a label is admissible only if you can **write down its complete value set in advance**
and that set is small (single or low double digits). Anything you cannot enumerate is
high-cardinality detail that belongs on a **trace span** (`distributed-tracing-design`), reached
from a metric via an **exemplar**, not on the metric itself.

### Per-metric label allowlist (classification pipeline)

Each metric declares its permitted labels; the Collector drops anything not on the list, so a
stray label added in code cannot silently explode the series count.

| Metric | Type | Allowed labels |
|---|---|---|
| `http_server_requests_total` | counter | `service`, `http_route`, `http_request_method`, `http_response_status_code` |
| `http_server_duration_seconds` | histogram | `service`, `http_route`, `http_request_method` |
| `pipeline_documents_processed_total` | counter | `service`, `source_type` (gdrive/s3), `document_type` (pdf/docx/xlsx), `outcome` (ok/error/dlq) |
| `pipeline_consumer_lag` | gauge | `service`, `topic` |
| `pipeline_dlq_depth` | gauge | `service`, `topic` |
| `db_pool_in_use` | gauge | `service` |
| `db_pool_max` | gauge | `service` |

### Worst-case series arithmetic

Worst case is bounded multiplication of the label cardinalities. For
`pipeline_documents_processed_total`:

```
services (3) × source_type (2) × document_type (3) × outcome (3)
= 3 × 2 × 3 × 3
= 54 active series
```

Fifty-four series is a budget that holds comfortably. Do the same multiplication for every metric
before shipping it; a service should stay under ~5,000 active series and a single metric under
~1,000. Verify after each deploy:

```promql
count({__name__=~"pipeline_.*"})     # series in the pipeline_ subsystem
prometheus_tsdb_head_series          # total live series in this Prometheus
```

### The tenant_id policy under physical multi-tenancy

Each tenant runs an isolated deployment with its own Prometheus. Tenant identity is therefore a
property of the **installation**, not of any metric. It is stamped **once** as an `external_label`
on the tenant's Prometheus (Section 5) and is **never** emitted as a metric label by service code.
This keeps every service's series count flat no matter how many tenants onboard — adding the
1,000th tenant adds a whole new Prometheus, not a 1,000× multiplier on every existing series.
Emitting `tenant_id` as a metric label is doubly wrong: it grows series linearly with onboarding
*and* it is redundant, because the tenant's own Prometheus already knows who it is.

---

## 2. Histogram Bucket Design

`histogram_quantile` linearly interpolates *within* the bucket a percentile falls into, so a
percentile is only as precise as the boundaries around it. Two design rules:

1. **A boundary sits exactly on the SLO threshold.** Then the latency SLI (`slo-definition`) is a
   direct bucket ratio — `requests ≤ threshold / all requests` — not an interpolation, and the SLO
   burn-rate alert (`alerting-rules-design`) reads a precise number.
2. **Split by success/failure before computing the percentile.** A failed request often returns
   very fast and, mixed in, drags the p99 down to a falsely comforting value (SRE, Four Golden
   Signals: distinguish successful-request latency from failed-request latency). Filter the bucket
   sum by `http_response_status_code` (e.g. exclude `5..`) before `histogram_quantile`.

### Bucket classes (boundaries in seconds; the SLO threshold is bold)

| Latency class | Example | Explicit buckets (seconds) |
|---|---|---|
| Fast sync read (SLO p95 < 0.3s) | `GET /v1/data-assets/{id}` | 0.005, 0.01, 0.025, 0.05, 0.1, **0.3**, 0.5, 1, 2.5 |
| Sync command (SLO p99 < 0.8s) | `ClassifyDataAsset` via `PATCH …/classification` | 0.01, 0.05, 0.1, 0.25, 0.5, **0.8**, 1, 2.5, 5 |
| Async unit of work (seconds) | entity-extractor per-document extraction | 0.1, 0.5, 1, 2.5, 5, 10, **30**, 60, 120 |
| Pipeline end-to-end (minutes) | discovery → classified freshness | 30, 60, 120, 300, **600**, 1200, 1800, 3600 |

Ten to twelve buckets is the ceiling — every bucket is a full extra series per label combination,
so a 12-bucket histogram with the 3 allowed labels on `http_server_duration_seconds` already costs
`12 × (route × method)` series. Bucket boundaries are set in code via an OpenTelemetry SDK
explicit-bucket View per instrument; this table is the platform standard those Views implement.

---

## 3. Recording Rules

A recording rule pre-computes an expensive or frequently-read query into a cheap flat series, so
dashboards, SLO calculations, and federation read pre-aggregated data. Names follow the Prometheus
`level:metric:operations` convention — aggregation level, metric name, operations applied.

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

      # success-only p99 — failed requests excluded so a fast 5xx cannot flatter the tail
      - record: service:http_request_duration_seconds:p99_5m
        expr: |
          histogram_quantile(0.99,
            sum by (service, le) (
              rate(http_server_duration_seconds_bucket{http_response_status_code!~"5.."}[5m])))

      - record: service:pipeline_consumer_lag:max
        expr: max by (service, topic) (pipeline_consumer_lag)

      - record: service:db_pool_utilization:ratio
        expr: db_pool_in_use / db_pool_max
```

Write a recording rule only when the query is (a) on a continuously-refreshed dashboard, (b) an SLI
feeding SLO burn-rate alerts, or (c) federated upward. Do not record one-off exploration queries —
every rule is evaluated on every interval, forever, so recording-rule sprawl becomes the heaviest
workload on the instance.

---

## 4. RED and USE Instrumentation Catalogues

### RED — every request-serving interface

| Service | Interface | Rate | Errors | Duration |
|---|---|---|---|---|
| compliance-engine | HTTP API (chi) | `http_server_requests_total` | `..._total{status=~"5.."}` | `http_server_duration_seconds` |
| estate-scanner | discovery job runs | `scan_runs_total` | `scan_runs_total{outcome="error"}` | `scan_run_duration_seconds` |
| entity-extractor | Redpanda consumer | `pipeline_documents_processed_total` | `..._total{outcome=~"error|dlq"}` | `extraction_duration_seconds` |

### USE — every finite resource

| Service | Resource | Utilization | Saturation | Errors |
|---|---|---|---|---|
| all | pgx pool | `db_pool_in_use / db_pool_max` | in-use approaching max; wait count | `db_pool_acquire_errors_total` |
| entity-extractor | consumer group | throughput | `pipeline_consumer_lag` (trend via `deriv`) | `pipeline_dlq_depth` |
| all | worker pool | active/total workers | queue depth trending up | task rejection counter |

**Saturation as a trend, not a snapshot.** The fourth Golden Signal is best expressed as time to
exhaustion, not a static percentage. Project it with `deriv()` over the recent window rather than
only alerting on a fixed threshold — e.g. consumer lag growing steadily is a leading indicator even
while still below any absolute limit:

```promql
# lag is growing and is already non-trivial → will breach soon
deriv(service:pipeline_consumer_lag:max[15m]) > 0 and service:pipeline_consumer_lag:max > 1000

# DB pool saturation trending toward the ceiling
service:db_pool_utilization:ratio > 0.8 and deriv(service:db_pool_utilization:ratio[15m]) > 0
```

This turns the `db_pool_in_use / db_pool_max` query from a dashboard-only view into a ticket-tier
saturation alert (`alerting-rules-design`), giving the Four Golden Signals their fourth pillar for
every resource, not just the pipeline.

---

## 5. Scrape and Federation Topology

Physical multi-tenancy means one observability spine per tenant plus a thin aggregate for the
operator:

```
tenant namespace: estate-scanner ─┐
                  entity-extractor ├─ OTLP → otel-collector ──(scrape)── tenant Prometheus
                  compliance-engine ┘                                        │ /federate
                                                                            ▼
                            central Prometheus  ←── only service:* recorded series
                                    │
                                Grafana (one instance, tenant variable via external label)
```

- **Tenant Prometheus** scrapes only its own namespace, holds full-resolution series, evaluates
  recording and alerting rules locally, and stamps every series with its identity via
  `external_labels`.
- **Central Prometheus** federates *only* the `service:*` recorded aggregates — never raw series.
  Full-resolution data stays in the tenant; the operator view stays small and cheap.
- Scrapes traverse Linkerd, so metrics are mTLS-encrypted in transit with no extra configuration.

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

## 6. PromQL Patterns for the Standard Questions

| Question | Pattern |
|---|---|
| Error rate of compliance-engine? | `service:http_request_errors:ratio_rate5m{service="compliance-engine"}` |
| p99 latency of the ClassifyDataAsset route (success only)? | `histogram_quantile(0.99, sum by (le) (rate(http_server_duration_seconds_bucket{service="compliance-engine", http_route="/v1/data-assets/{id}/classification", http_response_status_code!~"5.."}[5m])))` |
| Is the pipeline keeping up? | `max by (topic) (pipeline_consumer_lag{service="entity-extractor"})`, trend via `deriv(...[15m])` |
| Is the Dead Letter Queue filling? | `sum by (service, topic) (pipeline_dlq_depth) > 0` |
| DB pool saturation? | `db_pool_in_use / db_pool_max` approaching 1 |
| Throughput by document type? | `sum by (document_type) (rate(pipeline_documents_processed_total{outcome="ok"}[5m]))` |

Rules of reading: `rate()` **before** `sum()` (counters reset on restart; summing raw counters
across restarts lies); `histogram_quantile` over `sum by (le, …)` of bucket rates; latency always
as percentiles, never averages — the same standard `go-load-test` gates on.
