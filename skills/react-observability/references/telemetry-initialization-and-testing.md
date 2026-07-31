# Telemetry Initialization, Session Correlation, and Testing — Full Reference

Self-contained reference for `react-observability`. Covers the full
initialization chain, the session ID module, and patterns for testing
telemetry code without live collectors.

---

## 1. Package Manifest

All packages in the `@opentelemetry` family must be on the same minor version
— mismatched versions cause context propagation to silently break (a span
started in one version's context is invisible to another's propagation API).
Pin the whole family together.

```json
{
  "dependencies": {
    "@sentry/react":                              "^8.0.0",
    "@opentelemetry/api":                         "^1.9.0",
    "@opentelemetry/core":                        "^1.26.0",
    "@opentelemetry/resources":                   "^1.26.0",
    "@opentelemetry/semantic-conventions":        "^1.27.0",
    "@opentelemetry/sdk-trace-web":               "^1.26.0",
    "@opentelemetry/sdk-trace-base":              "^1.26.0",
    "@opentelemetry/sdk-metrics":                 "^1.26.0",
    "@opentelemetry/instrumentation":             "^0.53.0",
    "@opentelemetry/instrumentation-fetch":       "^0.53.0",
    "@opentelemetry/instrumentation-document-load": "^0.42.0",
    "@opentelemetry/exporter-trace-otlp-http":   "^0.53.0",
    "@opentelemetry/exporter-metrics-otlp-http": "^0.53.0",
    "web-vitals":                                 "^4.2.4"
  },
  "devDependencies": {
    "@sentry/vite-plugin":                        "^2.22.0"
  }
}
```

**Version notes:**
- `@opentelemetry/instrumentation-*` packages track the `instrumentation`
  package, not the `sdk-*` packages, and use a different semver series
  (`0.x`) — pin the minor of `instrumentation` and all `instrumentation-*`
  packages together.
- `web-vitals` v4 reports CLS as a raw floating-point ratio (not multiplied
  by 1000 as some earlier betas did). Verify the unit assumption matches your
  histogram bucket boundaries when upgrading across major versions.
- `@sentry/vite-plugin` v2 supports GlitchTip's self-hosted Sentry API
  via the `url` configuration key. v1 does not have this key — do not use v1
  against a self-hosted instance.

---

## 2. Full Initialization Chain — `main.tsx`

```tsx
// src/main.tsx
import ReactDOM from "react-dom/client";
import { App } from "./App";
import { initErrorReporting } from "./telemetry/error-reporting";
import { initTracing }         from "./telemetry/otel";
import { reportWebVitals }     from "./telemetry/web-vitals";

// HMR guard — re-registration duplicates spans in development on hot reload.
// In production there is no HMR so this flag is set exactly once.
declare global { interface Window { __OTEL_INITIALIZED__?: boolean } }

if (!window.__OTEL_INITIALIZED__) {
  window.__OTEL_INITIALIZED__ = true;
  initErrorReporting();   // 1. Sentry first — captures errors thrown by OTel init
  initTracing();          // 2. OTel — FetchInstrumentation patches global fetch
}

// 3. React render — every fetch from here carries traceparent
const root = ReactDOM.createRoot(document.getElementById("root")!);
root.render(<App />);

// 4. Web Vitals — after render so LCP has a paint to observe
reportWebVitals();
```

**Why this exact order matters:**

| If you swap | The failure |
|---|---|
| OTel before Sentry | Errors thrown by `registerInstrumentations()` (e.g., bad DSN config) are lost — Sentry isn't up yet |
| Render before OTel | The first `<App />` mount may fire a `fetch` before `FetchInstrumentation` patches it — those requests have no `traceparent` and create orphaned server spans |
| Vitals before render | `onLCP` needs a paint event to fire — calling it before `render()` produces nothing |
| No HMR guard | Every file save in dev registers a new provider; spans duplicate per hot reload |

---

## 3. Session ID — `session.ts`

```ts
// src/telemetry/session.ts

const SESSION_KEY = "otel.session.id";

let _sessionId: string | undefined;

/**
 * Returns the stable session ID for this browser tab.
 * Generated once per tab, persisted across same-tab page refreshes,
 * cleared on tab close (sessionStorage semantics).
 */
export function getSessionId(): string {
  if (!_sessionId) {
    _sessionId =
      sessionStorage.getItem(SESSION_KEY) ?? crypto.randomUUID();
    sessionStorage.setItem(SESSION_KEY, _sessionId);
  }
  return _sessionId;
}

/**
 * Call after logout to prevent the next user's session from inheriting
 * the previous user's session ID on a shared device.
 */
export function clearSessionId(): void {
  _sessionId = undefined;
  sessionStorage.removeItem(SESSION_KEY);
}
```

**Design decisions:**

- `sessionStorage` (not `localStorage`): the ID is tab-scoped. Two tabs
  navigating the same app are separate sessions in telemetry — correct,
  because a crash in tab A is not caused by tab B's activity.
- Module-level `_sessionId` cache: avoids a `sessionStorage` read on every
  span — `getSessionId()` is called inside hot paths like `record(metric)`.
- `clearSessionId()` on logout: without this, the next login on the same
  device inherits the previous session's ID and correlates two different
  users' activities in the same session timeline — a privacy issue as well
  as a telemetry accuracy issue.

**Where to inject `session.id`:**

| Where | How | Why |
|---|---|---|
| OTel custom spans | `span.setAttributes({ "session.id": getSessionId() })` | Correlate spans to the Sentry event for the same session |
| Sentry error events | `scope.setExtra("session_id", getSessionId())` | Link a GlitchTip event to its full OTel trace |
| NOT on metric labels | Never | One Prometheus series per session = cardinality explosion |

---

## 4. Testing Patterns

### 4.1 Testing the Error Boundary

```tsx
// src/shared/ui/FeatureErrorBoundary.test.tsx
import { render, screen } from "@testing-library/react";
import { FeatureErrorBoundary } from "./FeatureErrorBoundary";
import * as errorReporting from "../../telemetry/error-reporting";

// Suppress React's own console.error output during intentional throws.
const consoleError = vi.spyOn(console, "error").mockImplementation(() => {});
afterAll(() => consoleError.mockRestore());

const Boom = () => { throw new Error("deliberate render error"); };

it("renders fallback when child throws", () => {
  vi.spyOn(errorReporting, "reportClientError").mockReturnValue(undefined);

  render(
    <FeatureErrorBoundary fallback={<div>Error occurred</div>}>
      <Boom />
    </FeatureErrorBoundary>,
  );

  expect(screen.getByText("Error occurred")).toBeInTheDocument();
});

it("calls reportClientError with kind=render and componentStack", () => {
  const spy = vi.spyOn(errorReporting, "reportClientError").mockReturnValue(undefined);

  render(
    <FeatureErrorBoundary>
      <Boom />
    </FeatureErrorBoundary>,
  );

  expect(spy).toHaveBeenCalledWith(
    expect.any(Error),
    expect.objectContaining({ kind: "render", componentStack: expect.any(String) }),
  );
});
```

### 4.2 Testing `scrubEvent`

```ts
// src/telemetry/error-reporting.test.ts
import { scrubEvent } from "./error-reporting";  // export it for testability
import type { Event } from "@sentry/react";

it("strips cookies, Authorization, query_string, and data", () => {
  const event: Event = {
    request: {
      cookies: "session=abc",
      headers: { Authorization: "Bearer token" },
      query_string: "token=secret",
      data: '{"password":"hunter2"}',
    },
  };

  const result = scrubEvent(event);

  expect(result).not.toBeNull();
  expect(result!.request?.cookies).toBeUndefined();
  expect(result!.request?.headers?.Authorization).toBeUndefined();
  expect(result!.request?.query_string).toBeUndefined();
  expect(result!.request?.data).toBeUndefined();
});

it("drops a TypeError with 'Failed to fetch' message", () => {
  const event: Event = { message: "TypeError: Failed to fetch" };
  const hint = { originalException: new TypeError("Failed to fetch") };
  expect(scrubEvent(event, hint)).toBeNull();
});

it("drops an AbortError", () => {
  const abort = new DOMException("Aborted", "AbortError");
  expect(scrubEvent({}, { originalException: abort })).toBeNull();
});
```

### 4.3 Testing OTel Spans — `InMemorySpanExporter`

`InMemorySpanExporter` from `@opentelemetry/sdk-trace-base` captures spans
in memory without a running collector. Use it to assert on span names,
attributes, and parent-child relationships:

```ts
// src/telemetry/otel.test.ts
import { InMemorySpanExporter, SimpleSpanProcessor } from "@opentelemetry/sdk-trace-base";
import { WebTracerProvider }  from "@opentelemetry/sdk-trace-web";
import { trace, context }     from "@opentelemetry/api";

let exporter: InMemorySpanExporter;
let provider: WebTracerProvider;

beforeEach(() => {
  exporter  = new InMemorySpanExporter();
  provider  = new WebTracerProvider({
    spanProcessors: [new SimpleSpanProcessor(exporter)],
  });
  provider.register();
});

afterEach(async () => {
  await provider.shutdown();
  exporter.reset();
});

it("records session.id on a custom span", async () => {
  vi.mock("./session", () => ({ getSessionId: () => "test-session-id" }));

  const tracer = trace.getTracer("test");
  const span = tracer.startSpan("my-flow");
  span.setAttributes({ "session.id": "test-session-id" });
  span.end();

  await provider.forceFlush();
  const spans = exporter.getFinishedSpans();

  expect(spans).toHaveLength(1);
  expect(spans[0].name).toBe("my-flow");
  expect(spans[0].attributes["session.id"]).toBe("test-session-id");
});
```

**Key points:**
- Use `SimpleSpanProcessor` in tests (not `BatchSpanProcessor`) — simple
  processes spans synchronously, so `getFinishedSpans()` returns results
  immediately without waiting for a batch flush.
- Call `provider.shutdown()` in `afterEach` to clear the global tracer
  registry between tests; without it, `trace.getTracer()` in later tests
  picks up the previous test's provider.
- `exporter.reset()` clears recorded spans without shutting down the
  provider — useful when you need one provider across multiple `it` blocks.

### 4.4 Testing Web Vitals

The `web-vitals` library requires a real browser paint to emit LCP/INP/CLS
measurements — `onLCP(record)` will never fire in jsdom. Do not attempt to
unit-test the vital measurement itself; instead:

1. Test that `reportWebVitals()` calls `onLCP`, `onINP`, and `onCLS` by
   mocking the `web-vitals` module.
2. Test that the `record(metric)` callback calls `vitalHistogram.record`
   with the correct attributes by injecting a mock histogram.
3. For end-to-end vital assertion, use a Playwright test with Chromium's
   `page.metrics()` or the `@playwright/test` built-in `webVitals` reporter.

```ts
// src/telemetry/web-vitals.test.ts
import { reportWebVitals } from "./web-vitals";
import * as webVitals from "web-vitals";

it("registers LCP, INP, and CLS callbacks", () => {
  const lcpSpy = vi.spyOn(webVitals, "onLCP").mockImplementation(() => {});
  const inpSpy = vi.spyOn(webVitals, "onINP").mockImplementation(() => {});
  const clsSpy = vi.spyOn(webVitals, "onCLS").mockImplementation(() => {});

  reportWebVitals();

  expect(lcpSpy).toHaveBeenCalledOnce();
  expect(inpSpy).toHaveBeenCalledOnce();
  expect(clsSpy).toHaveBeenCalledOnce();
});
```

### 4.5 Environment Gate Testing

```ts
// src/telemetry/error-reporting.test.ts
it("does not initialize Sentry when PROD is false and VITE_TELEMETRY_ENABLED is unset", () => {
  vi.stubEnv("PROD", false);
  vi.stubEnv("VITE_TELEMETRY_ENABLED", undefined);

  const initSpy = vi.spyOn(Sentry, "init").mockReturnValue(undefined);
  initErrorReporting();

  expect(initSpy).not.toHaveBeenCalled();
});
```

This is the single most important telemetry test in the suite: if the env
gate is absent or broken, every CI run reports real errors to GlitchTip,
attributes test failures to the product, and pollutes the error history
with noise that makes real production regressions harder to spot.

---

## 5. Consolidated Reviewer Checklist — Quality Criteria and Anti-Patterns

A single reviewer checklist covering all five standards in the SKILL.md body.
The Quality Criteria table states what passes and what fails per criterion; the
Anti-Patterns table pairs each common mistake with its correct replacement. Both
are cross-cutting — each references every standard, not only initialization and
testing — so they live together here rather than in any one per-standard file.

### Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Initialization order | Sentry → OTel → render → vitals; env-gated in non-prod | Any init after `React.render`; collectors hit in unit tests |
| Boundary is a class | `getDerivedStateFromError`/`componentDidCatch`, unaltered | "Hookified" into a nonexistent hook |
| Two-tier placement | One boundary per remote at shell; one per independently-failing organism inside each remote | One top-level boundary; a remote with no internal boundaries |
| Error reporting | GlitchTip via `@sentry/react`; `beforeSend` wired; payload contract met; sourcemaps uploaded in CI | No reporting; unscrubbed events; `email`/`username` sent; minified stacks in production |
| No competing tracers | Sentry's `browserTracingIntegration` disabled; OTel owns tracing | Two span trees for one request |
| Trace propagation | `traceparent` on API calls; backend extracts before `tracer.Start`; `trace_id` in Sentry tag | Severed trace at browser/server boundary |
| Per-remote scoped tracers | Remotes call `trace.getTracer(name, version)` from shared provider | Remote calls `provider.register()` — overwrites global, severs in-flight spans |
| Sampling configured | `TraceIdRatioBasedSampler` in production; always-sample in dev | 100% sampling in production; 0% in dev |
| Session correlation wired | `session.id` in span attributes and Sentry extra; `user.id`/`tenant_id` set post-auth | No cross-signal anchor; `session.id` on a metric label |
| Web Vitals captured | LCP/INP/CLS (not FID); OTel histograms; custom bucket boundaries; force-flushed on `hidden` | FID reported; default buckets; no flush — worst sessions missing |
| Shared observability stack | Frontend metrics in the backend's Prometheus/Grafana | Separate frontend-only RUM dashboard |
| Privacy-safe | No PII/secrets in any telemetry surface | Emails/tokens/file contents in spans, metrics, or error events |

### Anti-Patterns

| Anti-pattern | Instead |
|---|---|
| Telemetry initialized after `React.render` | Initialize Sentry then OTel then render then vitals — in that order, in `main.tsx` |
| Hookifying the error boundary | No `useErrorBoundary` exists; the class stays a class |
| One top-level boundary or a remote with none inside | Two tiers: shell wraps each remote; each remote wraps each independent organism |
| `browserTracingIntegration` alongside OTel Web | Disable it — two tracers, two `fetch` patches, two uncorrelated span trees |
| Remote calls `provider.register()` again | Call `trace.getTracer(name, version)` from the shared provider only |
| 100% sampling in production | `TraceIdRatioBasedSampler(0.1)` or similar; always-on in dev only |
| `session.id` as a metric attribute | High cardinality — millions of Prometheus series at real session volumes; use span attributes and Sentry extra |
| No sourcemaps in production | Upload via `@sentry/vite-plugin` in the prod build; minified stacks are useless |
| PII in error payload or span attributes | `user: { id, tenant_id }` only; `beforeSend` strips cookies, tokens, raw querystrings |
| Reporting FID or flushing on `unload` | FID is retired; `unload` drops the worst sessions — use INP and flush on `visibilitychange`→`hidden` |
| Observability active in unit tests | Gate all init on `import.meta.env.PROD` or an explicit opt-in env var |
| Separate frontend-only RUM tool | OTLP/HTTP to the same collector; one Grafana, one Prometheus |
