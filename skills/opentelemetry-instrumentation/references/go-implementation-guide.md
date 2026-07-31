# OpenTelemetry Instrumentation — Go Implementation Guide

This reference contains full Go code examples, detailed anti-patterns with consequences,
and the complete Collector deployment topology configuration. It is referenced by
`opentelemetry-instrumentation/SKILL.md` and is self-contained — usable without the
parent SKILL.md in context.

---

## Full Provider Initialisation

The tracer and meter providers are initialised once at the composition root and
return a shutdown function that flushes buffered telemetry on exit.

```go
// internal/infrastructure/telemetry/telemetry.go
package telemetry

import (
    "context"
    "errors"
    "fmt"

    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/propagation"
    "go.opentelemetry.io/otel/sdk/metric"
    "go.opentelemetry.io/otel/sdk/resource"
    "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

// Config holds the telemetry configuration injected from the environment.
// OTLPEndpoint is either "localhost:4317" (sidecar topology) or
// "$NODE_IP:4317" (DaemonSet topology) — set by the Helm chart / pod spec.
type Config struct {
    ServiceName  string
    Version      string
    Env          string
    OTLPEndpoint string  // host:port, no scheme
    SampleRatio  float64 // 0.0–1.0; 1.0 = always sample
}

func Init(ctx context.Context, cfg Config) (shutdown func(context.Context) error, err error) {
    res, err := resource.New(ctx,
        resource.WithAttributes(
            semconv.ServiceName(cfg.ServiceName),
            semconv.ServiceVersion(cfg.Version),
            semconv.DeploymentEnvironmentName(cfg.Env), // deployment.environment.name
        ),
    )
    if err != nil {
        return nil, fmt.Errorf("otel resource: %w", err)
    }

    // Traces → OTLP/gRPC to the Collector (sidecar or DaemonSet, per topology)
    texp, err := otlptracegrpc.New(ctx,
        otlptracegrpc.WithEndpoint(cfg.OTLPEndpoint),
        otlptracegrpc.WithInsecure(), // TLS terminated at the Collector, not the SDK hop
    )
    if err != nil {
        return nil, fmt.Errorf("otlp trace exporter: %w", err)
    }
    tp := trace.NewTracerProvider(
        trace.WithBatcher(texp),  // batch — do not block the request path
        trace.WithResource(res),
        trace.WithSampler(trace.ParentBased(trace.TraceIDRatioBased(cfg.SampleRatio))),
    )
    otel.SetTracerProvider(tp)

    // Metrics → OTLP/gRPC (the platform's Prometheus scrapes/receives from the Collector)
    mexp, err := otlpmetricgrpc.New(ctx,
        otlpmetricgrpc.WithEndpoint(cfg.OTLPEndpoint),
        otlpmetricgrpc.WithInsecure(),
    )
    if err != nil {
        return nil, fmt.Errorf("otlp metric exporter: %w", err)
    }
    mp := metric.NewMeterProvider(
        metric.WithReader(metric.NewPeriodicReader(mexp)),
        metric.WithResource(res),
    )
    otel.SetMeterProvider(mp)

    // W3C Trace Context + Baggage — cross-service and cross-broker propagation
    otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
        propagation.TraceContext{},
        propagation.Baggage{},
    ))

    return func(ctx context.Context) error {
        return errors.Join(tp.Shutdown(ctx), mp.Shutdown(ctx)) // flush both on exit
    }, nil
}
```

**Key decisions baked into this implementation:**
- `WithInsecure()` on both exporters — TLS is not needed for the localhost (sidecar) or
  node-local (DaemonSet) hop; the Collector handles TLS for the onward leg to the backend.
- `ParentBased(TraceIDRatioBased(ratio))` — traces are sampled consistently end-to-end;
  a downstream service inherits the sampling decision from its caller.
- Both providers flush on exit via `errors.Join` — if one fails, the other still runs.

---

## Metric Instrument Definitions

All instruments are created once at wiring time and reused across requests.
Creating instruments per request re-registers them on every call (SDK overhead + metrics drift).

```go
// internal/infrastructure/telemetry/metrics.go
package telemetry

import (
    "go.opentelemetry.io/otel/metric"
    semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

// ServiceMetrics holds all instruments for one service.
// Embed in the handler or pass through dependency injection.
type ServiceMetrics struct {
    // RED — every HTTP interface
    HTTPRequests metric.Int64Counter
    HTTPDuration metric.Float64Histogram
    HTTPInFlight metric.Int64UpDownCounter

    // RED — every event consumer
    EventsProcessed metric.Int64Counter
    EventDuration   metric.Float64Histogram
    EventErrors     metric.Int64Counter

    // USE — database pool
    DBPoolInUse    metric.Int64ObservableGauge
    DBPoolSatLevel metric.Int64ObservableGauge
    DBPoolErrors   metric.Int64Counter
}

func NewServiceMetrics(m metric.Meter) (*ServiceMetrics, error) {
    reqCount, err := m.Int64Counter("http.server.requests",
        metric.WithDescription("HTTP requests handled by route and status"))
    if err != nil {
        return nil, err
    }

    reqDur, err := m.Float64Histogram("http.server.duration",
        metric.WithUnit("s"),
        // Buckets bracket the SLO (e.g. 100ms SLO → fine-grained below 200ms)
        metric.WithExplicitBucketBoundaries(
            0.005, 0.01, 0.025, 0.05, 0.1, 0.2, 0.5, 1.0, 2.5, 5.0,
        ),
    )
    if err != nil {
        return nil, err
    }

    inFlight, err := m.Int64UpDownCounter("http.server.in_flight",
        metric.WithDescription("HTTP requests currently being processed"))
    if err != nil {
        return nil, err
    }

    eventsProcessed, err := m.Int64Counter("events.processed",
        metric.WithDescription("Domain events processed by consumer"))
    if err != nil {
        return nil, err
    }

    eventDur, err := m.Float64Histogram("events.processing.duration",
        metric.WithUnit("s"),
        metric.WithExplicitBucketBoundaries(
            0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0,
        ),
    )
    if err != nil {
        return nil, err
    }

    eventErrors, err := m.Int64Counter("events.processing.errors",
        metric.WithDescription("Event processing failures by event type"))
    if err != nil {
        return nil, err
    }

    dbErrors, err := m.Int64Counter("db.pool.errors",
        metric.WithDescription("Database pool errors (timeout, connect failure)"))
    if err != nil {
        return nil, err
    }

    // Observable gauges are registered with callbacks; the SDK calls them on each collect.
    var dbInUse, dbSat metric.Int64ObservableGauge
    dbInUse, err = m.Int64ObservableGauge("db.pool.in_use",
        metric.WithDescription("DB pool connections currently acquired"))
    if err != nil {
        return nil, err
    }
    dbSat, err = m.Int64ObservableGauge("db.pool.waiting",
        metric.WithDescription("Goroutines waiting for a DB pool connection (saturation)"))
    if err != nil {
        return nil, err
    }
    _ = dbInUse
    _ = dbSat

    return &ServiceMetrics{
        HTTPRequests: reqCount,
        HTTPDuration: reqDur,
        HTTPInFlight: inFlight,
        EventsProcessed: eventsProcessed,
        EventDuration:   eventDur,
        EventErrors:     eventErrors,
        DBPoolErrors:    dbErrors,
    }, nil
}
```

---

## RED Wiring in HTTP Middleware

```go
// internal/infrastructure/telemetry/middleware.go
package telemetry

import (
    "net/http"
    "time"

    "go.opentelemetry.io/otel/metric"
    semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

func HTTPMetricsMiddleware(m *ServiceMetrics) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()
            rw := &statusRecorder{ResponseWriter: w, status: 200}

            m.HTTPInFlight.Add(r.Context(), 1)
            defer m.HTTPInFlight.Add(r.Context(), -1)

            next.ServeHTTP(rw, r)

            // route is injected by chi's RouteContext — low-cardinality pattern, not raw path
            route := chi.RouteContext(r.Context()).RoutePattern()
            attrs := metric.WithAttributes(
                semconv.HTTPRoute(route),
                semconv.HTTPRequestMethodKey.String(r.Method),
                semconv.HTTPResponseStatusCode(rw.status),
            )
            m.HTTPRequests.Add(r.Context(), 1, attrs)
            m.HTTPDuration.Record(r.Context(), time.Since(start).Seconds(), attrs)
        })
    }
}

type statusRecorder struct {
    http.ResponseWriter
    status int
}

func (r *statusRecorder) WriteHeader(code int) {
    r.status = code
    r.ResponseWriter.WriteHeader(code)
}
```

---

## Collector Deployment Topology — Pod Spec Examples

### DaemonSet Topology (default for this repo)

The node IP is injected via the Downward API. The SDK connects to `$NODE_IP:4317`
without needing service discovery or TLS for the local hop.

```yaml
# Kubernetes pod spec (excerpt) — DaemonSet Collector topology
spec:
  containers:
  - name: my-service
    env:
    - name: NODE_IP
      valueFrom:
        fieldRef:
          fieldPath: status.hostIP
    - name: OTEL_EXPORTER_OTLP_ENDPOINT
      value: "http://$(NODE_IP):4317"
```

```go
// Go: read from environment (set by the Helm chart / pod spec above)
endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") // "http://10.0.0.5:4317"
// or, if building the endpoint manually:
endpoint := os.Getenv("NODE_IP") + ":4317"            // "10.0.0.5:4317"
```

### Sidecar Topology (use for exceptions)

The Collector runs as a native sidecar (Kubernetes 1.29+ `initContainers` with
`restartPolicy: Always`). The SDK always uses `localhost:4317`.

```yaml
# Kubernetes pod spec (excerpt) — Sidecar Collector topology, native sidecar (K8s ≥1.29)
spec:
  initContainers:
  - name: otel-collector
    image: otel/opentelemetry-collector-contrib:0.102.0
    restartPolicy: Always          # marks this as a native sidecar, not a run-once init
    args: ["--config=/etc/otel/config.yaml"]
    ports:
    - containerPort: 4317          # gRPC
    - containerPort: 4318          # HTTP
    volumeMounts:
    - name: otel-config
      mountPath: /etc/otel
  containers:
  - name: my-service
    env:
    - name: OTEL_EXPORTER_OTLP_ENDPOINT
      value: "http://localhost:4317"  # same pod network namespace
```

**Why `initContainers` with `restartPolicy: Always` rather than a `containers[]` entry:**
Kubernetes 1.29+ native sidecar guarantees the Collector starts before the app container
(preserving init ordering) and stays running throughout the pod lifecycle. A plain
`containers[]` entry starts in parallel with the app — the SDK may emit spans before the
Collector is ready, losing early startup telemetry.

---

## Anti-Patterns — Full Detail

### 1. Unbounded metric labels

**Pattern:** Using a UUID, raw request path, user ID, or free-text value as a metric attribute.

**Consequence:** Each unique label value creates a new time series. A service handling 1 million
unique users with `user_id` as a label creates 1 million active series. Prometheus's TSDB
memory consumption grows linearly with active series count; at scale this exhausts heap and
crashes the metrics backend — an observability-induced outage.

**Fix:** Use bounded categorical values (`tenant_tier: "enterprise" | "standard" | "free"`,
`http_route: "/v1/assets/{id}"` not `/v1/assets/abc-123`). High-cardinality detail goes on
trace spans; exemplars link a specific slow histogram bucket to a trace without labelling.

### 2. Instrument-type mismatch

**Pattern:** Using `Int64Counter` for "in-flight requests" (cannot go down) or
`Int64ObservableGauge` for "total events processed" (loses increments between scrapes).

**Consequence:** In-flight counter never decreases — the alert threshold is always exceeded
after the first request. Observable gauge for a cumulative total returns only the value at
scrape time, not the sum since last scrape — derivatives become negative or wildly incorrect.

**Fix:** Counter = cumulative, monotonically increasing. UpDownCounter = current value that
can increase or decrease. Gauge = observable snapshot (read at scrape time). Histogram =
distribution across a range. These are not stylistic choices — they are semantic contracts
between the SDK and the metrics backend.

### 3. Default histogram buckets on domain latency

**Pattern:** Not calling `WithExplicitBucketBoundaries` on a histogram.

**Consequence:** The OTel SDK default buckets (`[0, 5, 10, 25, 50, 75, 100, 250, 500, 750, 1000, 2500, 5000, 7500, 10000]` milliseconds) are designed for general use. A service with a 50ms SLO will have most observations fall into the first bucket — p50 = p95 = p99 = "≤5ms" (i.e. the first bucket boundary), which is not useful for SLO tracking.

**Fix:** Choose buckets that bracket the SLO. For a 100ms SLO: `[5, 10, 25, 50, 100, 200, 500, 1000]` milliseconds (or in seconds: `[0.005, 0.01, 0.025, 0.05, 0.1, 0.2, 0.5, 1.0]`).

### 4. Synchronous export on the request path

**Pattern:** Using `trace.NewSimpleSpanProcessor` instead of `trace.NewBatchSpanProcessor`,
or calling `tp.ForceFlush` inside a request handler.

**Consequence:** Every span export call blocks the request goroutine on a network round-trip
to the Collector. Under high load, Collector latency (typically 1–5ms) adds directly to
user-observed request latency.

**Fix:** Always use `trace.WithBatcher(exporter)` (which calls `NewBatchSpanProcessor`
internally). Never flush on the request path.

### 5. Creating instruments per request

**Pattern:**
```go
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    counter, _ := h.meter.Int64Counter("requests") // WRONG: called per request
    counter.Add(r.Context(), 1)
}
```

**Consequence:** The OTel SDK de-duplicates instrument registrations by name but still
incurs a map lookup and allocation on every call. At high RPS (>10k req/s) this creates
measurable GC pressure. More critically, if the registration logic is not idempotent (e.g.
different description on re-register), the SDK may return an error or log a warning per
request, flooding structured logs.

**Fix:** Create instruments once in a constructor or `sync.Once`. Store as struct fields.
Pass `*ServiceMetrics` via dependency injection.

### 6. Missing shutdown flush

**Pattern:** Not wiring the shutdown function returned by `Init` into the service's
lifecycle manager.

**Consequence:** When a pod receives SIGTERM (rolling update, scale-down, node eviction),
the last batch of spans and metrics — often the ones showing exactly why the pod stopped
being healthy — is dropped before export. Post-incident debugging loses the final seconds
of telemetry. This is the most-missed instrumentation bug in Go services.

**Fix:** Wire the shutdown function into `go-service-skeleton`'s cleanup chain:
```go
shutdown, err := telemetry.Init(ctx, cfg)
// ... register shutdown
defer func() {
    shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    if err := shutdown(shutdownCtx); err != nil {
        slog.Error("telemetry shutdown", "error", err)
    }
}()
```
