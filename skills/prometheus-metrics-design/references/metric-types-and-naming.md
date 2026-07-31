# Metric Types, OpenTelemetry Go SDK Instrumentation, and Naming

Reference for `prometheus-metrics-design`. Comprehensive, self-contained. Covers the four
Prometheus metric types in depth, the OpenTelemetry Go SDK code that produces each, the full
naming and unit-suffix rules, and the OTLP dotted-name → Prometheus name translation.

On this platform services do **not** expose `/metrics` directly. They instrument with the
OpenTelemetry Go SDK, export over OTLP to the OpenTelemetry Collector, and the Collector's
`prometheusexporter` exposes the translated series for Prometheus to scrape. Every name and
type below is therefore an OTel instrument on one side and a Prometheus series on the other —
both are shown.

---

## 1. The Four Prometheus Metric Types

### Counter — a monotonically increasing total

A counter only ever goes up (or resets to zero on process restart). You never read a counter's
raw value; you read a **rate** of it at query time. Restarts are handled automatically by
`rate()`/`increase()`, which detect the reset and do not count the drop as negative traffic.

Use for: requests served, errors, documents processed, bytes ingested, DLQ messages produced.

OpenTelemetry Go SDK (`Int64Counter`), producing the Prometheus series
`pipeline_documents_processed_total`:

```go
meter := otel.Meter("entity-extractor")
docsProcessed, _ := meter.Int64Counter(
    "pipeline.documents.processed",              // OTel dotted name
    metric.WithDescription("documents processed by the extraction pipeline"),
    metric.WithUnit("1"),                         // dimensionless count
)
// on each processed document:
docsProcessed.Add(ctx, 1, metric.WithAttributes(
    attribute.String("source_type", "gdrive"),    // bounded: gdrive|s3
    attribute.String("document_type", "pdf"),      // bounded: pdf|docx|xlsx
    attribute.String("outcome", "ok"),             // bounded: ok|error|dlq
))
```

The Collector appends `_total` on export, so this is queried in Prometheus as
`pipeline_documents_processed_total`. Read it as `rate(pipeline_documents_processed_total[5m])`.

### Gauge — a value that rises and falls

A gauge is a point-in-time level: it can go up or down, and its raw value is meaningful. Read it
directly (or with `max`/`min`/`avg`/`deriv` for trend), never with `rate()`.

Use for: consumer lag, queue depth, in-use connections, in-flight requests, current pool size.

OpenTelemetry Go SDK observable gauge (`Int64ObservableGauge`), producing `pipeline_consumer_lag`:

```go
_, _ = meter.Int64ObservableGauge(
    "pipeline.consumer.lag",
    metric.WithDescription("Redpanda consumer group lag in messages"),
    metric.WithUnit("1"),
    metric.WithInt64Callback(func(ctx context.Context, o metric.Int64Observer) error {
        for _, topic := range topics {
            o.Observe(lagFor(topic), metric.WithAttributes(
                attribute.String("topic", topic),   // bounded: fixed topic set
            ))
        }
        return nil
    }),
)
```

A gauge never takes a `_total` suffix — `pipeline_consumer_lag`, not `pipeline_consumer_lag_total`.

### Histogram — a distribution read as percentiles

A histogram counts observations into cumulative buckets, so you can compute any percentile at
query time with `histogram_quantile`. This is the **only** correct type for latency, because its
buckets **re-aggregate across pods**: summing `_bucket` series by `le` then applying
`histogram_quantile` gives a correct fleet-wide p99. A histogram exports three series families —
`_bucket{le="..."}`, `_sum`, and `_count`.

OpenTelemetry Go SDK (`Float64Histogram`), producing `http_server_duration_seconds`:

```go
dur, _ := meter.Float64Histogram(
    "http.server.duration",
    metric.WithDescription("HTTP server request duration"),
    metric.WithUnit("s"),                          // seconds — base unit
)
start := time.Now()
// ... serve request ...
dur.Record(ctx, time.Since(start).Seconds(), metric.WithAttributes(
    attribute.String("http_route", route),
    attribute.String("http_request_method", r.Method),
))
```

Explicit bucket boundaries are set per instrument via a SDK View (see
`cardinality-and-histograms.md` for the per-latency-class boundary tables).

### Summary — client-side quantiles, avoided here

A summary computes quantiles inside the client process and exports them as pre-baked
`quantile="0.99"` series. Its fatal flaw: **quantiles cannot be aggregated**. The p99 of pod A
and the p99 of pod B do not combine into a fleet p99 — there is no mathematically valid way to
merge them. On a horizontally-scaled platform every latency signal spans many pods, so summaries
are prohibited. Always use a histogram, which re-aggregates correctly. (Summaries are also not a
first-class OTel instrument.)

| Type | Aggregates across pods? | Read with | Suffix |
|---|---|---|---|
| Counter | yes | `rate()` / `increase()` | `_total` |
| Gauge | yes (via `sum`/`max`/`avg`) | direct value / `deriv()` | none |
| Histogram | **yes** | `histogram_quantile` over `_bucket` | `_bucket`/`_sum`/`_count` |
| Summary | **no** | direct `quantile` series | `quantile` label |

---

## 2. Naming Conventions (full)

| Rule | Right | Wrong |
|---|---|---|
| `snake_case`, subsystem prefix | `pipeline_documents_processed_total` | `DocumentsProcessed` |
| Base units only (seconds, bytes, ratio 0–1) | `http_server_duration_seconds` | `_millis`, `_kb`, percent |
| Unit as trailing suffix | `payload_size_bytes` | `bytes_payload` |
| Counters end `_total` | `classification_errors_total` | `classification_error_count` |
| Gauges are bare nouns | `pipeline_consumer_lag` | `pipeline_consumer_lag_total` |
| Ratios end `_ratio`, scaled 0–1 | `db_pool_utilization_ratio` | `db_pool_utilization_percent` |
| No rate baked into the name | `requests_total` + `rate()` | `requests_per_second` |

The name states *what* is measured; PromQL states *how* it is read. A counter plus `rate()`
answers per-second, per-minute, and per-day questions from one series; a pre-rated metric answers
only one and cannot be re-windowed.

### Unit suffix catalogue

| Quantity | Base unit | Suffix | Never |
|---|---|---|---|
| Duration / latency | seconds | `_seconds` | `_ms`, `_millis`, `_micros` |
| Size / payload | bytes | `_bytes` | `_kb`, `_mb`, `_kib` |
| Ratio / fraction | 0–1 | `_ratio` | `_percent`, `_pct` |
| Temperature-free count | dimensionless | `_total` (counter) or bare (gauge) | `_count` on a counter |
| Timestamp | Unix seconds | `_timestamp_seconds` | formatted strings |

Prometheus convention is base units so a query never has to know the scale: `_seconds` and
`_bytes` throughout, never a mix of `_ms` here and `_seconds` there that makes dashboards lie.

---

## 3. OTLP → Prometheus Name Translation

The Collector's Prometheus exporter rewrites OTel names on the way out. Design every query,
recording rule, and dashboard against the **translated** Prometheus name, not the OTel dotted one:

| Transformation | OTel instrument | Prometheus series |
|---|---|---|
| Dots become underscores | `http.server.duration` | `http_server_duration` |
| Unit appended as suffix | unit `s` on `http.server.duration` | `http_server_duration_seconds` |
| Cumulative counters gain `_total` | `pipeline.documents.processed` (counter) | `pipeline_documents_processed_total` |
| Histogram fans into three families | `http.server.duration` (histogram) | `_bucket{le}`, `_sum`, `_count` |
| Attributes become labels | `attribute.String("http_route", ...)` | label `http_route="..."` |

Worked example: the OTel instrument `http.server.duration` with unit `s` and attributes
`http_route`, `http_request_method` is queried in Prometheus as
`http_server_duration_seconds_bucket{http_route="...", http_request_method="..."}`. A common
mistake is writing a recording rule against `http.server.duration` (the OTel name) — that series
does not exist in Prometheus and the rule silently produces nothing.

---

## 4. Selecting a Type — Decision Checklist

1. Is it a total that only grows (requests, errors, bytes)? → **Counter** (`_total`), read with `rate()`.
2. Is it a current level that rises and falls (lag, depth, in-use)? → **Gauge** (bare noun).
3. Will you read percentiles or a distribution from it (latency, payload size distribution)? → **Histogram**.
4. Tempted by a summary for a quantile? → Use a **histogram** instead; summaries do not aggregate across pods.
5. Tempted to bake a rate into a gauge (`_per_second`)? → Use a **counter** and rate at query time.
