---
name: prometheus-metrics-design
description: >
  Design and operate the self-hosted Prometheus metrics backend for the
  data-estate platform. Covers choosing a Prometheus metric type (counter,
  gauge, histogram, summary), RED vs USE instrumentation selection, metric
  naming with base units and _total/_ratio suffixes, per-metric label
  allowlists and the cardinality budget, why unbounded label values
  (user-id, request-id, raw URL path, file name) are forbidden, the tenant_id
  external-label policy under physical multi-tenancy, histogram bucket design
  with a boundary on the SLO threshold, when to write a recording rule, and
  the per-tenant scrape plus central federation topology. Consumed by
  platform-engineer during Deploy; feeds slo-definition and
  alerting-rules-design.
version: 2.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, observability, prometheus, metrics, red-method, use-method, cardinality, histogram, recording-rules, federation]
produces: prometheus-metrics-design
domain: observability
status: stable
related: [slo-definition, alerting-rules-design, opentelemetry-instrumentation, distributed-tracing-design, health-check-design]
---

# Prometheus Metrics Design

## Purpose

Prometheus is the platform's metrics backend — open-source, pull-based, self-hosted (frugal: no metrics SaaS). Services emit signals through the OpenTelemetry Go SDK over OTLP (`opentelemetry-instrumentation` owns the in-code half); the OpenTelemetry Collector exposes them on a Prometheus endpoint, and Prometheus scrapes, stores, and evaluates them. Grafana reads Prometheus for dashboards; Alertmanager evaluates its alerts (`alerting-rules-design`); Service Level Objectives are computed from its series (`slo-definition`).

A metrics backend lives or dies on discipline: consistent names make queries reusable, bounded labels keep the series count survivable, and correct histogram buckets make percentiles meaningful. This skill encodes those standards. Prometheus's own designers built it as the open-source successor to Google's Borgmon, so the SRE monitoring philosophy — symptom-based signals, the Four Golden Signals — transplants directly onto this stack.

---

## Choosing a Metric Type

Prometheus has four instrument types. Pick by the question the series must answer:

| Type | Use when | Example |
|---|---|---|
| **Counter** | A monotonically increasing total; read a rate at query time | `http_server_requests_total`, `classification_errors_total` |
| **Gauge** | A value that goes up and down; a current level | `pipeline_consumer_lag`, `db_pool_in_use` |
| **Histogram** | A distribution you will read percentiles from | `http_server_duration_seconds` |
| **Summary** | Client-side quantiles that cannot be aggregated across instances — avoid on this platform | (do not use — a summary's p99 cannot be re-aggregated across pods) |

Rules of thumb: **counter + `rate()` beats a pre-rated gauge** (a counter answers per-second, per-minute, and per-day; a `requests_per_second` gauge answers only one), and **histogram beats summary** because histogram buckets re-aggregate across pods and a summary's precomputed quantiles do not. Full per-type depth, OpenTelemetry Go SDK code, and OTLP→Prometheus name translation: `references/metric-types-and-naming.md`.

---

## RED vs USE Selection

Two complementary instrumentation frameworks, aligned with the SRE Four Golden Signals (latency, traffic, errors, saturation):

- **RED — Rate, Errors, Duration** — for every request-serving *interface*: HTTP endpoints, gRPC methods, event consumers. Answers "how is the work going?" (traffic + errors + latency).
- **USE — Utilization, Saturation, Errors** — for every finite *resource*: connection pools, worker pools, queues, consumer groups. Answers "is a resource running out?" (saturation).

Instrument every interface with RED and every constrained resource with USE; the two do not overlap. Health probes are not metrics — liveness/readiness belong to `health-check-design`. Full instrumentation catalogues for this repo's services (estate-scanner, entity-extractor, compliance-engine) are in `references/cardinality-and-histograms.md`.

---

## Naming Conventions (in brief)

- `snake_case`, prefixed by subsystem: `pipeline_documents_processed_total`.
- Base units only — seconds, bytes, ratios in 0–1. Never `_millis`, `_kb`, or percentages.
- Unit as a suffix: `payload_size_bytes`, not `bytes_payload`.
- Counters end `_total`; ratios end `_ratio` (scaled 0–1); gauges are bare nouns.
- No rate baked into the name — `requests_total` read with `rate()`, never `requests_per_second`.

The name states *what* is measured; PromQL states *how* it is read. The full naming rule set, the unit-suffix catalogue, and the OTLP dotted-name translation table are in `references/metric-types-and-naming.md`.

---

## The Cardinality Budget

Every distinct label value mints a new time series. Cardinality is a budget spent deliberately — the single most important discipline in this skill:

- **Bound every label's value set.** Each metric declares a per-metric label allowlist of permitted labels and their *bounded* value sets; anything not on the allowlist is dropped at the Collector. Adding a label is a reviewed change, not a code-side convenience.
- **Never put unbounded values in labels.** UUIDs, raw URL paths, user ids, emails, file names, request ids, free text — these grow the series count without limit. That high-cardinality detail belongs on trace spans (`distributed-tracing-design`), reached from a metric via exemplars.
- **Series budget:** hold a service under ~5,000 active series and a single metric under ~1,000; check `count({__name__=~"pipeline_.*"})` and `prometheus_tsdb_head_series` after every deploy.

**The `tenant_id` policy under physical multi-tenancy:** each tenant runs an isolated deployment with its own Prometheus, so tenant identity is a property of the *installation*, not of any metric. It is stamped once as an `external_label` on the tenant's Prometheus — never emitted as a metric label by services. This keeps per-service cardinality flat no matter how many tenants onboard. Worked good/bad label examples, per-service allowlists, and the worst-case series arithmetic are in `references/cardinality-and-histograms.md`.

---

## Histograms for Latency

`histogram_quantile` interpolates *within* a bucket — a percentile is only as precise as the boundaries. Two principles:

1. **One boundary always sits exactly on the SLO threshold**, so the latency Service Level Indicator (`slo-definition`) is an exact bucket ratio, not an interpolation. If the SLO is p95 under the threshold, that threshold must be an explicit boundary.
2. **Split latency by success vs failure before computing percentiles.** A failed request can return very fast and drag the p99 down to a falsely comforting number (SRE, Four Golden Signals). Filter by `http_response_status_code` in the recording rule.

Ten to twelve buckets is the ceiling — each bucket is a full extra series per label combination. Per-latency-class bucket tables and the recording rules that read them are in `references/cardinality-and-histograms.md`.

---

## Recording Rules and Federation

Write a **recording rule** — pre-computing an expensive query into a cheap flat series — only when the query is (a) on a continuously-refreshed dashboard, (b) an SLI feeding SLO burn-rate alerts, or (c) federated upward. Do not record one-off exploration queries; every rule is evaluated forever. Names follow `level:metric:operations` (e.g. `service:http_requests:rate5m`).

**Federation topology** under physical multi-tenancy: one observability spine per tenant, plus a thin aggregate for the operator. Each **tenant Prometheus** scrapes only its own namespace, holds full-resolution series, evaluates rules locally, and stamps its identity via `external_labels`. The **central Prometheus** federates *only* the `service:*` recorded aggregates — never raw series — so full-resolution data stays in the tenant and the operator view stays small. Scrapes traverse Linkerd, so metrics are mTLS-encrypted in transit with no extra config. Full recording-rule YAML, the tenant and central `prometheus.yml`, and the PromQL pattern catalogue for the standard operational questions are in `references/cardinality-and-histograms.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Type choice | Counter+`rate()`; histogram for latency | Summary for aggregatable quantiles; pre-rated gauge |
| Naming | Base units, unit suffix, `_total` on counters | Mixed units; rates baked into names |
| Label allowlist | Every metric has a documented, bounded label set | Ad-hoc labels added in code without review |
| Cardinality | Series counted per service, held under budget | Unbounded labels; series growth unmonitored |
| Tenant isolation | `tenant` as external label only | `tenant_id` as a metric label anywhere |
| Buckets | Explicit per class; boundary on SLO threshold; success/failure split | Default buckets; SLO between boundaries; latency averaged across outcomes |
| Recording rules | `level:metric:operations`; only dashboards/SLIs/federation | Ad-hoc names; recording every query written |
| Federation | Central scrapes `service:*` aggregates only | Raw series federated; duplicated storage |

---

## Anti-Patterns

- **`tenant_id` as a metric label** — grows series linearly with onboarding *and* is redundant (the tenant's own Prometheus already knows who it is). External label, always.
- **Federating raw series** — recreates every tenant's storage bill in one central instance. Federate recorded aggregates only.
- **Averaging latency** — `rate(sum)/rate(count)` hides the tail the SLO is written against. Percentiles from buckets, always.
- **`sum` before `rate`** — summing raw counters across pods then rating corrupts the result on every pod restart. Rate first, then aggregate.
- **Default buckets on an SLO metric** — if no boundary sits at the threshold, the SLI is an interpolated guess.
- **Summary for anything aggregated** — a summary's quantiles cannot be re-aggregated across pods; use a histogram.
- **Two paths for the same metric** — scraping a service directly *and* exporting OTLP double-counts. One path: SDK → OTLP → Collector → scrape.

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

## Scrape Topology            [per-tenant Prometheus, collector endpoint, central federation]
## Metric Inventory           | Metric | Type | Unit | Allowed labels | Worst-case series |
## Histogram Bucket Classes    | Latency class | SLO threshold | Buckets |
## Recording Rules            | Rule name (level:metric:operations) | Expression | Consumed by |
## Cardinality Budget         [per-service budget, current usage, review trigger]
## Configuration Files        prometheus/tenant/prometheus.yml, prometheus/central/prometheus.yml, prometheus/rules/*.yaml
```
