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
version: 1.2.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, observability, opentelemetry, otel, metrics, red, use, instrumentation, collector, daemonset, sidecar]
produces: go-otel-instrumentation
domain: observability
status: stable
---

# OpenTelemetry Instrumentation

## Purpose

Observability is a functional requirement, not an afterthought (the backend-engineer blueprint). Every service emits traces and metrics through OpenTelemetry — the vendor-neutral standard — so the platform's Prometheus, Tempo, and Grafana (operated by the platform-engineer) receive consistent, correlated signals from every service without bespoke wiring.

This skill covers in-code instrumentation (SDK init, instrument selection, RED/USE frameworks, cardinality discipline) and the OTel Collector deployment topology decision (where the Collector runs relative to the pod). Collector deployment, storage backends, dashboards, SLOs, and alerts are the platform-engineer's domain (`prometheus-metrics-design`, `slo-definition`, `alerting-rules-design`) — this skill produces the signals they consume.

---

## Provider Initialisation

Tracer and meter providers are initialised once in the composition root and return a shutdown function that flushes buffered telemetry on exit (wired into the service lifecycle — see `go-service-skeleton`).

```go
// internal/infrastructure/telemetry/telemetry.go — composition root only
func Init(ctx context.Context, cfg Config) (shutdown func(context.Context) error, err error) {
    res, _ := resource.New(ctx, resource.WithAttributes(
        semconv.ServiceName(cfg.ServiceName),
        semconv.ServiceVersion(cfg.Version),
        semconv.DeploymentEnvironmentName(cfg.Env),
    ))
    texp, _ := otlptracegrpc.New(ctx,
        otlptracegrpc.WithEndpoint(cfg.OTLPEndpoint), // localhost:4317 or $NODE_IP:4317
        otlptracegrpc.WithInsecure())
    tp := trace.NewTracerProvider(
        trace.WithBatcher(texp),  // batch — never block the request path
        trace.WithResource(res),
        trace.WithSampler(trace.ParentBased(trace.TraceIDRatioBased(cfg.SampleRatio))),
    )
    otel.SetTracerProvider(tp)
    mexp, _ := otlpmetricgrpc.New(ctx,
        otlpmetricgrpc.WithEndpoint(cfg.OTLPEndpoint),
        otlpmetricgrpc.WithInsecure())
    mp := metric.NewMeterProvider(metric.WithReader(metric.NewPeriodicReader(mexp)), metric.WithResource(res))
    otel.SetMeterProvider(mp)
    otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
        propagation.TraceContext{}, propagation.Baggage{}))
    return func(ctx context.Context) error { return errors.Join(tp.Shutdown(ctx), mp.Shutdown(ctx)) }, nil
}
```

`cfg.OTLPEndpoint` is injected by the pod spec — `localhost:4317` (sidecar topology) or `$NODE_IP:4317` (DaemonSet topology). See Collector Deployment Topology below. Full implementation with error handling and `Config` struct: `references/go-implementation-guide.md`.

---

## Collector Deployment Topology

The OTel Collector is a separate process that receives signals from the SDK and forwards them to the observability backends. The backend-engineer configures the SDK endpoint; the platform-engineer deploys the Collector. The backend-engineer must know which topology is active because it determines `OTLPEndpoint`.

### Sidecar Collector (one Collector per pod)

The Collector runs as a second container in the same pod, sharing the pod's network namespace.

- SDK exports to `localhost:4317` (gRPC) or `localhost:4318` (HTTP) — no TLS, no service discovery needed
- Kubernetes 1.29+ native sidecar: declare in `initContainers` with `restartPolicy: Always` — the Collector starts before the app container and stays running throughout the pod lifecycle (preferred over a plain `containers[]` entry, which starts in parallel and may miss early startup telemetry)
- Advantages: per-pod cardinality; independent pod lifecycle (a Collector crash does not affect other pods); per-service Collector configuration
- Use when: a specific service needs different sampling rates or different backend destinations; per-service Collector configuration is required

### DaemonSet Collector (one Collector per node)

A Kubernetes `DaemonSet` schedules one Collector pod per node. All pods on the node export to it.

- SDK exports to `$NODE_IP:4317` — the node IP is injected into the pod via the Downward API
- Pod spec: `env: [{name: NODE_IP, valueFrom: {fieldRef: {fieldPath: status.hostIP}}}]`
- Set `OTEL_EXPORTER_OTLP_ENDPOINT: "http://$(NODE_IP):4317"` in the container env
- Advantages: resource efficiency (N services share one Collector instead of N Collectors); simpler RBAC; uniform configuration
- Use when: all services share the same OTel configuration; resource efficiency is primary; per-service isolation is not needed

### Default for this repo

**DaemonSet Collector** — uniform OTel configuration and resource efficiency are the default constraints. Use Sidecar Collector only for services that require different sampling rates or backend routing.

Full pod spec YAML examples and Go endpoint wiring: `references/go-implementation-guide.md`.

---

## Metric Instruments — Choose Correctly

The instrument type encodes the semantics of the measurement. Choosing wrong makes a metric meaningless.

| Instrument | Represents | Examples |
|---|---|---|
| **Counter** | A cumulative value that only goes up | requests handled, events processed, errors |
| **UpDownCounter** | A value that goes up and down | in-flight requests, queue depth, open connections |
| **Gauge** (observable) | A current sampled value | consumer lag, pool utilisation, goroutine count |
| **Histogram** | A distribution, bucketed | request duration, payload size, batch size |

**Histograms require explicit bucket boundaries** chosen for the expected range. Example for a service with a 100ms SLO: `metric.WithExplicitBucketBoundaries(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5)`. Default buckets rarely fit a service's latency profile; bad buckets make percentile computations meaningless.

Full `ServiceMetrics` struct with RED and USE instrument definitions: `references/go-implementation-guide.md`.

---

## RED — Instrument Every Interface

For every request-handling interface (HTTP endpoint, event consumer), emit all three RED signals. (The HTTP RED wiring lives in the telemetry middleware — see `go-middleware`.)

| Signal | Instrument | Meaning |
|---|---|---|
| **Rate** | Counter | requests per second (derived from the counter) |
| **Errors** | Counter (or status attribute on Rate) | failed requests per second |
| **Duration** | Histogram | latency distribution (p50/p95/p99 derived downstream) |

Attributes on every RED metric: `http.route` (low-cardinality pattern, not raw path), `http.request.method`, `http.response.status_code`. Apply RED equally to the event consumer and to outbound calls to external systems.

Full HTTP middleware wiring with `statusRecorder`: `references/go-implementation-guide.md`.

---

## USE — Instrument Every Resource

For every constrained resource (DB pool, worker pool, consumer), emit all three USE signals so saturation is visible before it becomes an outage.

| Signal | Instrument | Example |
|---|---|---|
| **Utilization** | Observable Gauge | % of DB pool connections in use |
| **Saturation** | Observable Gauge / UpDownCounter | work queued and waiting; consumer lag |
| **Errors** | Counter | resource errors (pool timeouts, broker errors) |

Observable gauges sample the resource via a callback on each collection cycle — they do not block the request path. Consumer lag and worker-pool saturation are the early-warning signals for the data pipeline (see `data-pipeline-design`); they feed the platform-engineer's alerts.

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
| Collector topology | `localhost:4317` (sidecar) or `$NODE_IP:4317` via Downward API (DaemonSet) | Hardcoded non-local IP; no Downward API injection |
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
- **Default buckets on latency histograms** — a service with a 20ms p99 measured in second-scale buckets reports p99 ≈ the first bucket boundary, forever. Buckets bracket the SLO.
- **Synchronous export on the request path** — `NewSimpleSpanProcessor` or per-request flush turns Collector latency into user latency. Always use `WithBatcher`.
- **Creating instruments per request** — `meter.Int64Counter(...)` inside a handler re-registers on every call. Create instruments once at wiring time; store as struct fields.
- **Missing shutdown flush** — without calling the provider shutdown on exit, the final batch of spans — often the crash evidence — is dropped silently.
- **Per-tenant metric labels** — `tenant_id` as a label is unbounded growth by onboarding. Use tenant *tier*; per-tenant detail lives in traces and logs.

Full consequence analysis for each pattern: `references/go-implementation-guide.md`.

---

## Output Format

Produces Go source plus tests asserting instruments are registered:

```
internal/infrastructure/telemetry/telemetry.go    (providers, OTLP export, propagation)
internal/infrastructure/telemetry/metrics.go      (RED/USE instrument definitions)
internal/infrastructure/telemetry/metrics_test.go
```
