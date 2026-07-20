---
name: opentelemetry-instrumentation
description: >
  Teaches how to instrument a Go service with OpenTelemetry — initialising the
  tracer and meter providers, OTLP export, resource attributes, context
  propagation, and designing metrics with the RED (Rate/Errors/Duration) and USE
  (Utilization/Saturation/Errors) frameworks using the correct instruments
  (counters, gauges, histograms with explicit buckets). This is the in-code
  instrumentation half of the observability domain. Used by the backend-engineer
  during Implement. Exports are operated by the platform-engineer.
version: 1.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, observability, opentelemetry, otel, metrics, red, use, instrumentation]
---

# OpenTelemetry Instrumentation

## Purpose

Observability is a functional requirement, not an afterthought (the backend-engineer blueprint). Every service emits traces and metrics through OpenTelemetry — the vendor-neutral standard — so the platform's Prometheus, Tempo, and Grafana (operated by the platform-engineer) receive consistent, correlated signals from every service without bespoke wiring.

This skill covers the in-code instrumentation: initialising the SDK, choosing the right metric instruments, and applying the RED and USE frameworks. The collector, storage, dashboards, SLOs, and alerts are the platform-engineer's domain (`prometheus-metrics-design`, `slo-definition`, `alerting-rules-design`) — this skill produces the signals they consume.

---

## Provider Initialisation

The tracer and meter providers are set up once in the composition root and return a shutdown function that flushes buffered telemetry on exit (wired into the lifecycle — see `go-service-skeleton`).

```go
// internal/infrastructure/telemetry/telemetry.go
package telemetry

func Init(ctx context.Context, cfg Config) (shutdown func(context.Context) error, err error) {
    res, err := resource.New(ctx,
        resource.WithAttributes(
            semconv.ServiceName(cfg.ServiceName),
            semconv.ServiceVersion(cfg.Version),
            semconv.DeploymentEnvironmentName(cfg.Env), // deployment.environment.name in current semconv
        ),
    )
    if err != nil {
        return nil, fmt.Errorf("otel resource: %w", err)
    }

    // Traces → OTLP/gRPC to the collector (operated by platform-engineer)
    texp, err := otlptracegrpc.New(ctx, otlptracegrpc.WithEndpoint(cfg.OTLPEndpoint))
    if err != nil {
        return nil, fmt.Errorf("otlp trace exporter: %w", err)
    }
    tp := trace.NewTracerProvider(
        trace.WithBatcher(texp),                       // batch — don't block the request path
        trace.WithResource(res),
        trace.WithSampler(trace.ParentBased(trace.TraceIDRatioBased(cfg.SampleRatio))),
    )
    otel.SetTracerProvider(tp)

    // Metrics → OTLP (the platform scrapes/receives into Prometheus)
    mexp, err := otlpmetricgrpc.New(ctx, otlpmetricgrpc.WithEndpoint(cfg.OTLPEndpoint))
    if err != nil {
        return nil, fmt.Errorf("otlp metric exporter: %w", err)
    }
    mp := metric.NewMeterProvider(metric.WithReader(metric.NewPeriodicReader(mexp)), metric.WithResource(res))
    otel.SetMeterProvider(mp)

    // W3C Trace Context + Baggage propagation (cross-service + cross-broker)
    otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
        propagation.TraceContext{}, propagation.Baggage{}))

    return func(ctx context.Context) error {
        return errors.Join(tp.Shutdown(ctx), mp.Shutdown(ctx)) // flush both on exit
    }, nil
}
```

**Resource attributes** (`service.name`, `service.version`, `deployment.environment`) tag every signal so they are filterable in Grafana. **Batching** keeps export off the request hot path. **ParentBased sampling** ensures a trace is sampled consistently end-to-end.

---

## Metric Instruments — Choose Correctly

The instrument type encodes the semantics of the measurement. Choosing wrong makes a metric meaningless.

| Instrument | Represents | Examples |
|---|---|---|
| **Counter** | A cumulative value that only goes up | requests handled, events processed, errors |
| **UpDownCounter** | A value that goes up and down | in-flight requests, queue depth, open connections |
| **Gauge** (observable) | A current sampled value | consumer lag, pool utilisation, goroutine count |
| **Histogram** | A distribution, bucketed | request duration, payload size, batch size |

```go
type Metrics struct {
    ReqCount    metric.Int64Counter
    ReqDuration metric.Float64Histogram
    InFlight    metric.Int64UpDownCounter
}

func NewMetrics(m metric.Meter) (*Metrics, error) {
    reqCount, err := m.Int64Counter("http.server.requests",
        metric.WithDescription("HTTP requests handled"))
    if err != nil { return nil, err }

    reqDur, err := m.Float64Histogram("http.server.duration",
        metric.WithUnit("s"),
        metric.WithExplicitBucketBoundaries(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5))
    if err != nil { return nil, err }

    inFlight, err := m.Int64UpDownCounter("http.server.in_flight")
    if err != nil { return nil, err }

    return &Metrics{ReqCount: reqCount, ReqDuration: reqDur, InFlight: inFlight}, nil
}
```

**Histograms need explicit bucket boundaries** chosen for the expected range — default buckets rarely fit your latency profile, and bad buckets make percentiles useless.

---

## RED — Instrument Every Interface

For every request-handling interface (HTTP endpoint, event consumer), emit the three RED signals. (The HTTP RED wiring lives in the telemetry middleware — see `go-middleware`.)

| Signal | Instrument | Meaning |
|---|---|---|
| **Rate** | Counter | requests per second (derived from the counter) |
| **Errors** | Counter (or status attribute on Rate) | failed requests per second |
| **Duration** | Histogram | latency distribution (p50/p95/p99 derived downstream) |

```go
attrs := metric.WithAttributes(
    semconv.HTTPRoute(route),                        // low cardinality: route pattern, not raw path
    semconv.HTTPRequestMethodKey.String(r.Method),
    semconv.HTTPResponseStatusCode(status),          // Errors derived from status class
)
m.ReqCount.Add(ctx, 1, attrs)
m.ReqDuration.Record(ctx, elapsed.Seconds(), attrs)
```

Apply RED equally to the **event consumer** (rate of events processed, processing errors, processing duration) and to **outbound calls** to external systems.

---

## USE — Instrument Every Resource

For every constrained resource (DB pool, worker pool, consumer), emit the three USE signals so saturation is visible before it becomes an outage.

| Signal | Instrument | Example |
|---|---|---|
| **Utilization** | Gauge | % of DB pool connections in use |
| **Saturation** | Gauge / UpDownCounter | work queued and waiting; consumer lag |
| **Errors** | Counter | resource errors (pool timeouts, broker errors) |

```go
// Observable gauges sample the resource on each collection cycle.
_, err := m.Int64ObservableGauge("db.pool.in_use",
    metric.WithInt64Callback(func(_ context.Context, o metric.Int64Observer) error {
        s := pool.Stat()
        o.Observe(int64(s.AcquiredConns()))
        return nil
    }))
```

Consumer lag and worker-pool saturation are the early-warning signals for the data pipeline (see `data-pipeline-design`); they feed the platform-engineer's alerts.

---

## Cardinality Discipline

Every metric attribute multiplies the time series. **Labels must be low-cardinality.**

- Use route patterns (`/v1/data-assets/{id}`), method, status class, tenant *tier* — bounded sets.
- **Never** use as labels: raw paths, UUIDs, user ids, emails, free text, unbounded values.
- High-cardinality detail belongs on **trace spans** (see `distributed-tracing-design`), not metrics.

A single unbounded label (e.g., `asset_id`) can create millions of series and take down the metrics backend. This is the most common, most damaging instrumentation mistake.

**Exemplars bridge the two worlds.** The SDK can attach the current trace id to histogram samples recorded inside a sampled span (exemplar support in the OTel Go SDK, surfaced in Prometheus/Grafana as dots on the latency heatmap). The p99 spike on `http.server.duration` then links directly to an example trace of a slow `ClassifyDataAsset` request — aggregate metrics answer *whether*, the linked trace answers *why* — without ever putting a high-cardinality label on the metric.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Provider lifecycle | Init in composition root; shutdown flushes on exit | No flush; telemetry lost on shutdown |
| Correct instruments | Counter/gauge/histogram match semantics | Gauge used for cumulative; counter for current value |
| Explicit buckets | Histograms have range-appropriate buckets | Default buckets on latency histograms |
| RED on interfaces | Every endpoint/consumer emits rate/errors/duration | Endpoints with no metrics |
| USE on resources | Pools/queues emit utilisation/saturation/errors | Saturation invisible until outage |
| Low cardinality | Bounded labels only | UUID/user/path labels exploding series |
| Propagation | W3C TraceContext + Baggage set | Broken context across services/broker |

---

## Anti-Patterns

- **Unbounded metric labels** — a UUID, raw path, or email as an attribute mints a series per value. The metrics backend dies before the service does. High-cardinality detail goes on spans; exemplars provide the link.
- **Instrument-type mismatch** — a Gauge for "events processed" loses increments between scrapes; a Counter for "in-flight requests" can never go down. The semantics of the measurement pick the instrument.
- **Default buckets on latency histograms** — a service with a 20ms p99 measured in buckets built for seconds reports p99 ≈ the first bucket boundary, forever. Buckets bracket the SLO.
- **Synchronous export on the request path** — a simple span processor or per-request flush turns collector latency into user latency. Batch, always.
- **Creating instruments per request** — `meter.Int64Counter(...)` inside a handler re-registers on every call. Instruments are created once, at wiring time, and reused.
- **Skipping the shutdown flush** — without calling the provider shutdown on exit, the last batch of spans — often the ones showing why the pod died — is dropped.
- **Per-tenant metric labels** — `tenant_id` as a label is unbounded growth by onboarding. Use tenant *tier* if segmentation is needed; per-tenant detail lives in traces and logs.

---

## Output Format

Produces Go source plus tests asserting instruments are registered:

```
internal/infrastructure/telemetry/telemetry.go    (providers, OTLP export, propagation)
internal/infrastructure/telemetry/metrics.go      (RED/USE instrument definitions)
internal/infrastructure/telemetry/metrics_test.go
```
