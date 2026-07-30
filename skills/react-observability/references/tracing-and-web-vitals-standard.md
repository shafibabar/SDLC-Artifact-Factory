# OpenTelemetry-for-Frontend and Core Web Vitals Standard — Full Standard

Self-contained reference for `react-observability`. Deepens the SKILL.md
body's tracing and Web Vitals rule statements into the exact
provider setup, trace-context propagation chain into the backend, and
metric export path into the shared Grafana stack.

---

## 1. OTel Web SDK Setup

```ts
// src/telemetry/otel.ts
import { WebTracerProvider } from "@opentelemetry/sdk-trace-web";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { BatchSpanProcessor } from "@opentelemetry/sdk-trace-base";
import { TraceIdRatioBasedSampler } from "@opentelemetry/core";
import { FetchInstrumentation } from "@opentelemetry/instrumentation-fetch";
import { DocumentLoadInstrumentation } from "@opentelemetry/instrumentation-document-load";
import { registerInstrumentations } from "@opentelemetry/instrumentation";
import { W3CTraceContextPropagator } from "@opentelemetry/core";
import { resourceFromAttributes } from "@opentelemetry/resources";
import { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION, ATTR_DEPLOYMENT_ENVIRONMENT_NAME } from "@opentelemetry/semantic-conventions";

export function initTracing(): void {
  if (!import.meta.env.PROD && !import.meta.env.VITE_TELEMETRY_ENABLED) return;

  const resource = resourceFromAttributes({
    [ATTR_SERVICE_NAME]: import.meta.env.VITE_SERVICE_NAME ?? "estate-ui-shell",
    [ATTR_SERVICE_VERSION]: __APP_VERSION__,
    [ATTR_DEPLOYMENT_ENVIRONMENT_NAME]: import.meta.env.MODE,
  });

  const sampler = import.meta.env.PROD
    ? new TraceIdRatioBasedSampler(Number(import.meta.env.VITE_TRACE_SAMPLE_RATE ?? "0.1"))
    : undefined; // AlwaysOnSampler by default in dev

  const provider = new WebTracerProvider({
    resource,
    sampler,
    spanProcessors: [
      new BatchSpanProcessor(
        new OTLPTraceExporter({ url: import.meta.env.VITE_OTLP_HTTP_ENDPOINT + "/v1/traces" }),
      ),
    ],
  });

  provider.register({ propagator: new W3CTraceContextPropagator() });

  registerInstrumentations({
    instrumentations: [
      new FetchInstrumentation({
        // API origin only — a traceparent propagated to a third-party host leaks an internal
        // trace id outside this system's trust boundary.
        propagateTraceHeaderCorsUrls: [/^https:\/\/api\.[a-z0-9-]+\.internal\//],
      }),
      new DocumentLoadInstrumentation(),  // page-load spans
    ],
  });
}
```

`FetchInstrumentation` monkey-patches the global `fetch`. Because
`react-api-client`'s `openapi-fetch` wrapper calls native `fetch`
underneath, `traceparent` injection happens automatically beneath it —
`react-api-client` needs no separate propagation code of its own; this
is what satisfies that skill's own "Trace propagated" quality-criterion
row.

**Resource attributes** — `service.name`, `service.version`, and
`deployment.environment` — appear on every span and metric exported from
this provider, enabling Grafana to filter by `service.name` and split
traffic between the shell and individual remotes. Use the semantic
convention attribute names from `@opentelemetry/semantic-conventions`
rather than ad-hoc string literals.

---

## 2. Trace-Context Propagation: Browser → `go-chi-handler`

The chain, exactly:

1. A user action triggers a fetch through `react-api-client`'s client.
2. `FetchInstrumentation`'s `W3CTraceContextPropagator` injects a
   `traceparent` header (and `tracestate`/`baggage`) into that request —
   the same W3C Trace Context format `opentelemetry-instrumentation`
   registers on the Go side via
   `propagation.NewCompositeTextMapPropagator(propagation.TraceContext{}, propagation.Baggage{})`.
   Both ends speak the identical propagator format by construction —
   there is no format translation step.
3. The request reaches `go-chi-handler`'s router, through `go-middleware`'s
   `Telemetry` middleware. For the browser's `traceparent` to become the
   **parent** of the server span — rather than the server minting an
   unrelated root span — that middleware must extract it from the
   incoming headers into the request context *before* starting the span:
   `ctx := otel.GetTextMapPropagator().Extract(r.Context(), propagation.HeaderCarrier(r.Header))`,
   then `ctx, span := m.tracer.Start(ctx, r.Method)` using the extracted
   `ctx`, not the raw `r.Context()`. This is the one call that joins the
   two sides into a single trace; omitting it produces two structurally
   valid but disconnected traces sharing no trace id.
4. `go-chi-handler`'s handler, and everything it calls (repository,
   outbox, broker) per `distributed-tracing-design`, nests underneath
   that server span, using the same trace id the browser minted.

**Resulting tree:** browser `DocumentLoad`/fetch span → (via `traceparent`)
→ `go-chi-handler`'s request span (named `METHOD /v1/route-pattern`, per
`go-middleware`'s Telemetry middleware) → repository/event spans. One
user-visible slow page load is traceable end to end from the click to
the exact backend span that was slow, in the same Tempo/Grafana
instance — the trace is never severed at the browser boundary.

---

## 3. Custom Spans Around UI Workflows

Wrap complex multi-step flows (the classification workflow, a
multi-step source-connect wizard, a heavy data transform) in custom
spans with attributes:

```ts
import { trace } from "@opentelemetry/api";
import { getSessionId } from "./session";

const tracer = trace.getTracer("estate-ui-shell", __APP_VERSION__);

const span = tracer.startSpan("classify-data-asset-flow");
span.setAttributes({
  "data_asset.id": id,
  "ui.step_count": steps.length,
  "session.id": getSessionId(),   // cross-signal anchor — same id in Sentry extra
});
try { await runFlow(); } finally { span.end(); }
```

Attributes carry quantitative detail (payload size, entity ids, step counts)
— never secrets or PII (`privacy-design`); ids and counts only, the same
low-cardinality discipline `opentelemetry-instrumentation` applies to metric
labels. `session.id` on a span attribute is acceptable (spans are indexed
individually, not aggregated) — it is the same id stored in Sentry's
`extra.session_id` so a Grafana trace query and a GlitchTip event can be
correlated to the same browser tab session.

---

## 4. Sampling — Cost Control in Production

Without sampling, every user interaction in every browser tab sends spans to
the collector. At thousands of concurrent sessions, this saturates the OTel
collector's ingest pipeline and drives up Tempo storage costs. Use
`TraceIdRatioBasedSampler` in production:

```ts
// Already wired in §1's provider setup above.
// The sample rate should be tuned to your traffic volume:
//   0.1  = 10% — suitable for high-traffic routes (dashboard page views)
//   1.0  = 100% — development only, and for synthetic smoke tests in staging
// Always-on sampling is safe in dev because local Tempo has no storage constraint.

// To guarantee critical paths are always sampled regardless of the ratio,
// set the "trace.samplerate" baggage attribute on the root span:
const span = tracer.startSpan("checkout-flow");
span.setAttributes({ "trace.force_sample": "true" });
// then configure a custom sampler that checks this attribute — or accept that
// the ratio covers important flows statistically at 10% and reserve force-sampling
// for explicit debugging sessions.
```

**Why `TraceIdRatioBasedSampler` rather than a head-based probability sampler
per span:** the ratio sampler decides at the root span using the trace id as
a uniform random number, so all spans sharing a trace id have the same
sampling decision. This preserves complete traces (every child span is either
all-in or all-out) rather than partial traces where a parent span exists but
its child spans were dropped.

---

## 5. Per-Remote Scoped Tracers — Microfrontend Pattern

In a Module Federation shell-and-remotes setup, **only the shell calls
`provider.register()`**. A remote that registers its own provider overwrites
the global, severing all spans already in flight from the shell or other remotes.

Remotes instead call `trace.getTracer(name, version)` to obtain a **scoped
tracer** from the already-registered global provider:

```ts
// Inside a Module Federation remote (e.g., data-governance-remote)
import { trace } from "@opentelemetry/api";

// The shell already called provider.register() at startup.
// This obtains a scoped tracer from the shared global provider.
// Spans emitted by this tracer carry scope.name = "data-governance-remote",
// which appears in Grafana as the instrumentation library name,
// letting you filter spans by remote without forking the provider.
const tracer = trace.getTracer("data-governance-remote", __APP_VERSION__);
```

**Scoped tracer vs. separate resource attribute:** a scoped tracer differentiates
spans by `scope.name` (the instrumentation library), not `service.name`. The
`service.name` on the resource is the shell's, shared by all remotes using the
same provider. If per-remote `service.name` attribution is a hard requirement
(e.g., you want separate Grafana panels per remote), each remote needs its own
`WebTracerProvider` — but this requires careful coordination: two providers
may export to the same collector endpoint, which is safe, but the OTel
`@opentelemetry/api` package must be the same singleton instance across all
remotes (ensured by Module Federation's `shared:` config in `webpack.config.js`
or `vite.config.ts` federation plugin).

```ts
// webpack.config.js — shell's Module Federation config
new ModuleFederationPlugin({
  shared: {
    "@opentelemetry/api": { singleton: true, requiredVersion: "^1.x" },
    "@sentry/react":       { singleton: true, requiredVersion: "^8.x" },
  },
});
```

Both `@opentelemetry/api` and `@sentry/react` must be singletons. A second
copy of `@opentelemetry/api` loaded by a remote produces a second context
object — `trace.getTracer()` calls inside that remote then operate on an
uninstrumented context, silently producing no spans.

---

Tasks over 50ms block the main thread and degrade INP. Observe them with
`PerformanceObserver` and report the worst offenders so they can be
hunted down (code-split, defer, or move to a worker):

```ts
new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    if (entry.duration > 50) {
      reportLongTask({ duration: entry.duration, name: entry.name, route: currentRoute() });
    }
  }
}).observe({ type: "longtask", buffered: true });
```

---

## 5. Core Web Vitals — Metrics and Thresholds

Use the `web-vitals` library — it implements the spec-accurate
measurement; do not hand-roll layout-shift or paint-timing math.

| Metric | Measures | Good |
|---|---|---|
| **LCP** (Largest Contentful Paint) | Loading — when the main content appeared | ≤ 2.5s |
| **INP** (Interaction to Next Paint) | Responsiveness — main-thread availability for interactions | ≤ 200ms |
| **CLS** (Cumulative Layout Shift) | Visual stability — unexpected movement | ≤ 0.1 |

**FID (First Input Delay) is retired** — Google replaced it with INP as
the official third Core Web Vital in March 2024 because FID only
measured the delay before an interaction started processing, not the
full time to the next paint; `onFID` is legacy and unused here.

```ts
// src/telemetry/web-vitals.ts
import { onLCP, onINP, onCLS, type Metric } from "web-vitals";
import { metrics } from "@opentelemetry/api";

const meter = metrics.getMeter("frontend-web-vitals", __APP_VERSION__);

const vitalHistogram = meter.createHistogram("web_vitals", {
  description: "Core Web Vitals per real session",
  // Explicit bucket boundaries tuned to each vital's Good/Needs-improvement/Poor thresholds.
  // Default OTel buckets (1, 5, 10, 25, ... ms) make percentile queries meaningless because
  // the vitals' threshold values (2500ms, 200ms, 0.1) do not land on bucket boundaries.
  // This is the same rule opentelemetry-instrumentation applies to backend latency histograms.
  advice: {
    explicitBucketBoundaries: [
      // LCP: 0, 1000, 2500 (Good), 4000 (Needs-improvement), 10000ms
      // INP: 0, 100, 200 (Good), 500 (Needs-improvement), 1000ms
      // CLS: 0, 0.05, 0.1 (Good), 0.25 (Needs-improvement), 1.0
      // Shared histogram across all three vitals — use the union of their meaningful thresholds.
      // Raw values: LCP and INP report milliseconds; CLS reports a unitless ratio × 1000 when
      // normalized by web-vitals v3+, or as a raw fraction in v4. Check the web-vitals
      // CHANGELOG before finalizing buckets if upgrading across a major version.
      0, 100, 200, 500, 1000, 2500, 4000, 10000,
    ],
  },
});

function record(metric: Metric) {
  vitalHistogram.record(metric.value, {
    "vital.name":   metric.name,    // LCP | INP | CLS — bounded set, safe as a label
    "vital.rating": metric.rating,  // good | needs-improvement | poor — bounded set
    route:   currentRoute(),        // route pattern, never the raw URL
    release: __APP_VERSION__,
    // Do NOT add session.id here — it is high-cardinality and creates one
    // Prometheus series per user session, saturating storage within days.
    // Session-level attribution uses span attributes (§3 above) and Sentry extra.
  });
}

export function reportWebVitals() {
  onLCP(record); onINP(record); onCLS(record);
}
```

LCP/INP/CLS often finalize as the page is closing. Force-flush the
meter's exporter on `visibilitychange` → `hidden` rather than waiting
for the periodic export interval:

```ts
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "hidden") meterProvider.forceFlush();
});
```

Skipping this means exactly the worst sessions — the ones that made a
user leave — are the ones missing from the data, the same failure mode
`opentelemetry-instrumentation`'s own shutdown-flush rule guards against
on the backend.

---

## 7. Export Path: Into the Shared Grafana Stack

Web Vitals are OpenTelemetry metrics, exported over the same OTLP
pipeline the backend already uses — not a bespoke RUM SaaS.

```ts
// src/telemetry/otel.ts — MeterProvider, alongside the TracerProvider in §1
import { MeterProvider, PeriodicExportingMetricReader } from "@opentelemetry/sdk-metrics";
import { OTLPMetricExporter } from "@opentelemetry/exporter-metrics-otlp-http";
import { metrics } from "@opentelemetry/api";

export let meterProvider: MeterProvider;

export function initMetrics(resource: Resource): void {
  meterProvider = new MeterProvider({
    resource,
    readers: [
      new PeriodicExportingMetricReader({
        // OTLP/HTTP — browsers cannot use gRPC (OTLP/gRPC is the backend's transport).
        exporter: new OTLPMetricExporter({
          url: import.meta.env.VITE_OTLP_HTTP_ENDPOINT + "/v1/metrics",
        }),
        exportIntervalMillis: 5_000,
      }),
    ],
  });

  metrics.setGlobalMeterProvider(meterProvider);
}
```

`VITE_OTLP_HTTP_ENDPOINT` points at the same OTel collector the backend
exports to. The collector exposes a Prometheus endpoint, Prometheus scrapes
both backend and frontend metrics, and Grafana reads one Prometheus instance
for both — exactly the pipeline `prometheus-metrics-design` documents for
backend RED/USE metrics. A dashboard reviewer filters by `service.name`
to see frontend vitals beside the backend service that served the same user
session.

Labels stay low-cardinality (`vital.name`, `vital.rating`, `route`,
`release`) — never a user id or session id as a metric attribute; that detail
belongs on a trace span or a Sentry/GlitchTip event, not a metric label.

---

## 8. Shutdown and HMR Safety

**Shutdown on page close:** the `visibilitychange` → `hidden` flush (§6 above)
handles Web Vitals. For the tracer provider, register a `pagehide` handler:

```ts
window.addEventListener("pagehide", () => {
  provider.shutdown();        // flushes BatchSpanProcessor queue
  meterProvider.shutdown();   // flushes PeriodicExportingMetricReader queue
}, { once: true });
```

`pagehide` fires before the page is unloaded and is more reliable than
`unload` (which `beforeunload` replaced) across bfcache-enabled browsers.

**HMR guard:** Vite's hot module replacement will re-execute `main.tsx` on
edits. Without a guard, `initTracing()` registers a new provider on top of
the previous one, producing duplicate spans on every saved file:

```ts
// main.tsx
if (!window.__OTEL_INITIALIZED__) {
  window.__OTEL_INITIALIZED__ = true;
  initErrorReporting();
  initTracing();
}
ReactDOM.createRoot(document.getElementById("root")!).render(<App />);
reportWebVitals();
```

The HMR guard is development-only overhead — in production there is no
hot-module replacement, so `__OTEL_INITIALIZED__` is never set twice. The
guard belongs in `main.tsx` rather than inside `initTracing()` so the
telemetry module itself remains pure and testable without global state.
