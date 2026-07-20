---
name: react-observability
description: >
  Teaches frontend observability and Real User Monitoring — capturing Core Web
  Vitals (LCP, INP, CLS) and Long Tasks via PerformanceObserver, OpenTelemetry Web
  tracing with W3C traceparent propagation into fetch (completing the browser→
  backend trace), custom spans around UI workflows, granular React error boundaries
  that degrade gracefully, and structured client log sinks that enrich errors with
  route/state/trace id before shipping. The §3 of the frontend blueprint — UX
  quality made measurable. Used by the frontend-engineer during Implement.
version: 1.1.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, observability, rum, web-vitals, opentelemetry, error-boundary]
---

# React Observability

## Purpose

You cannot improve a user experience you cannot see. Frontend observability makes the *real* experience — on real devices, real networks — measurable: how fast it loaded, how responsive it felt, whether it shifted under the user, and what happened when it broke. This skill instruments the browser so that UX quality is monitored, not assumed, and so a frontend error arrives with enough context to diagnose it.

It is the frontend counterpart to the backend's observability instrumentation, and it **completes the distributed trace** — a browser interaction's span links through to the backend server span via W3C context propagation.

---

## Core Web Vitals (RUM)

Capture the three Google Core Web Vitals from real users and report them to the aggregation gateway (the platform-engineer's collector). Use the `web-vitals` library — it implements the correct, spec-accurate measurement.

| Metric | Measures | Good |
|---|---|---|
| **LCP** (Largest Contentful Paint) | Loading — when the main content appeared | ≤ 2.5s |
| **INP** (Interaction to Next Paint) | Responsiveness — main-thread availability for interactions | ≤ 200ms |
| **CLS** (Cumulative Layout Shift) | Visual stability — unexpected movement | ≤ 0.1 |

```ts
// src/telemetry/web-vitals.ts
import { onLCP, onINP, onCLS, type Metric } from "web-vitals";

export function reportWebVitals(send: (m: Metric) => void) {
  onLCP(send); onINP(send); onCLS(send);   // reports each as it finalises, per real session
}
// send → batched POST to the RUM gateway, tagged with route, release, and connection type
```

Delivery matters as much as measurement: LCP/INP/CLS often finalise as the page is being closed, and a plain `fetch` at that moment is dropped. Flush the batch on `visibilitychange` → `hidden` using `navigator.sendBeacon` (or `fetch` with `keepalive: true`) — otherwise the worst sessions, the ones that made users leave, are exactly the ones missing from the data.

Report **per real session** (not lab averages), tagged with the route and the app release, so regressions are attributable to a deploy and a screen. These map directly to the optimisation work in `react-performance-optimization`.

---

## Long Task Monitoring

Tasks over 50ms block the main thread and degrade INP. Observe them with the `PerformanceObserver` API and report the worst offenders so they can be hunted down (code-split, defer, or move to a worker — e.g., the graph layout in `react-graph-visualization`).

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

## OpenTelemetry Web + Distributed Tracing

Use the OpenTelemetry Web SDK (`@opentelemetry/sdk-trace-web`) so browser activity produces spans, and — critically — **inject `traceparent` into outgoing fetch/XHR** so the trace continues into the backend. The backend's `distributed-tracing-design` already extracts it; this closes the loop into one end-to-end trace: **browser → API → pipeline**.

```ts
// src/telemetry/otel.ts
const provider = new WebTracerProvider({ resource: resourceFromEnv() });
provider.register({ propagator: new W3CTraceContextPropagator() });

registerInstrumentations({
  instrumentations: [
    new FetchInstrumentation({
      propagateTraceHeaderCorsUrls: [/\/api\//], // inject traceparent on API calls
    }),
    new DocumentLoadInstrumentation(),           // page-load spans
  ],
});
```

The API client's request middleware also injects `traceparent` (see `react-api-client`) — together, every API call carries trace context.

### Custom spans around UI workflows

Wrap complex multi-step flows (the classification workflow, a multi-step source-connect wizard, a heavy data transform) in custom spans with attributes, per the blueprint:

```ts
const span = tracer.startSpan("classify-data-asset-flow");
span.setAttributes({ "data_asset.id": id, "ui.step_count": steps.length });
try { await runFlow(); } finally { span.end(); }
```

Attributes carry quantitative detail (payload size, element/asset ids, step counts) — never secrets or PII (see `privacy-design`).

---

## Granular Error Boundaries

A React render error must degrade **one region**, not unmount the whole app. Place error boundaries at meaningful seams — per route, per dashboard widget, around the graph — so a crash falls back to a clean, recoverable UI.

```tsx
// Reused at route subtrees (errorElement) and around independent widgets.
class FeatureErrorBoundary extends React.Component<Props, State> {
  state = { error: null as Error | null };
  static getDerivedStateFromError(error: Error) { return { error }; }
  componentDidCatch(error: Error, info: React.ErrorInfo) {
    reportClientError(error, { kind: "render", componentStack: info.componentStack }); // ship with context
  }
  render() {
    return this.state.error
      ? <ErrorFallback onRetry={() => this.setState({ error: null })} />  // clean fallback + recover
      : this.props.children;
  }
}
```

Boundary placement (from `react-routing` / `react-dashboard-components`): one per route subtree, one per independent dashboard widget, one around the estate graph. The app shell never white-screens from a leaf component's crash.

---

## Structured Client Log Sinks

Capture what error boundaries can't — async errors and unhandled rejections — and enrich every client log with deterministic context before shipping to the logging endpoint.

```ts
// src/telemetry/error-sink.ts
window.addEventListener("error", (e) => reportClientError(e.error, { kind: "global" }));
window.addEventListener("unhandledrejection", (e) => reportClientError(e.reason, { kind: "promise" }));

function reportClientError(error: unknown, extra: Record<string, unknown>) {
  send("/telemetry/logs", {
    message: String((error as Error)?.message ?? error),
    stack: (error as Error)?.stack,           // source-mapped via the build's sourcemaps
    route: currentRoute(),                     // active route config
    release: __APP_VERSION__,
    userAgent: navigator.userAgent,
    traceId: activeTraceId(),                  // correlate to the backend trace
    // NO PII, NO tokens — enrich with context, never secrets (privacy-design)
  });
}
```

The `traceId` is the link that ties a client error to its full backend trace — a support ticket can be resolved from one id, browser to database. Logs ship as structured JSON to the same pipeline the backend uses (Fluent Bit → Elasticsearch — operated by the platform-engineer).

---

## Privacy in Telemetry

Frontend telemetry is a prime accidental-PII leak. The rules from `privacy-design` apply:
- **No PII** in spans, metrics, logs, or RUM tags — no emails, no file contents, no extracted entity values. Use ids and counts.
- **No tokens/secrets** ever (the JWT is never logged or put in a span).
- Honor user consent for any analytics; RUM performance metrics are operational, but treat anything user-identifying as governed data.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Web Vitals captured | LCP/INP/CLS reported per real session, tagged by route/release | No RUM; lab-only numbers |
| Long tasks observed | >50ms tasks reported with context | Main-thread blocking invisible |
| Trace propagation | `traceparent` injected into API calls; browser→backend trace joined | Trace severed at the browser |
| Custom spans | Complex flows wrapped with attributes | Opaque flows with no spans |
| Granular boundaries | Per-route/widget/graph boundaries with clean fallback | One top-level boundary (or none); white screens |
| Enriched log sinks | global error + rejection handlers; route/release/trace id attached | Errors lost; logs with no context |
| Privacy-safe | No PII/secrets in any telemetry | Emails/tokens/content in spans or logs |

---

## Anti-Patterns

- **Lab numbers as the truth** — a Lighthouse score on a developer laptop says little about a compliance officer on hotel Wi-Fi. RUM per real session is the measure; lab runs are for local iteration.
- **`unload`-time fetch for telemetry** — the final (often worst) vitals never arrive. Flush on `visibilitychange` with `sendBeacon`/`keepalive`.
- **One top-level error boundary** — turns a widget crash into a full-app white screen with a generic apology. Boundaries live at route/widget/graph seams.
- **Error boundary as the only net** — boundaries catch render errors only; async errors and unhandled rejections sail past. The global `error`/`unhandledrejection` sinks are mandatory.
- **Console.log as observability** — invisible in production, no structure, no correlation. Structured JSON to the log pipeline, with `traceId`.
- **Severed traces** — API calls without `traceparent` mean the frontend's spans and the backend's spans describe the same request as two unrelated stories.
- **PII in span attributes** — an email address or a document excerpt in a span attribute is a data leak into the telemetry store, which has weaker access controls than the product database. Ids and counts only.
- **Untagged metrics** — a vital without route and release cannot be attributed to a screen or a deploy; it is a number, not a signal.

---

## Output Format

Produces the telemetry layer and its tests:

```
src/telemetry/otel.ts            (Web SDK + W3C propagation + fetch instrumentation)
src/telemetry/web-vitals.ts       (Core Web Vitals + long tasks)
src/telemetry/error-sink.ts       (global error/rejection capture + enrichment)
src/shared/ui/FeatureErrorBoundary.tsx
src/telemetry/*.test.ts           (written first)
```
