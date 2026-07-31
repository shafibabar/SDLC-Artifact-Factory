---
name: react-observability
description: >
  Teaches frontend observability as five standards for a React microfrontend
  stack: (0) initialization order — Sentry before OTel before React.render
  before web-vitals, so no error or span is lost at startup; (1) error-boundary
  placement — class-based FeatureErrorBoundary at two tiers, one per remote
  at shell level and one per independently-failing organism inside each remote;
  (2) frontend error reporting — GlitchTip via @sentry/react with an exact
  beforeSend payload contract, CI sourcemap upload for symbolicated stacks,
  and network-error filtering; (3) OpenTelemetry Web tracing — W3C traceparent
  propagation completing the browser-to-backend trace into go-middleware's
  server span, per-remote scoped tracers via trace.getTracer() (not duplicate
  provider registrations), trace sampling, custom spans, and Long Task
  monitoring; (4) Core Web Vitals — LCP/INP/CLS as OTel histograms with
  explicit bucket boundaries, force-flushed on visibilitychange into the same
  Grafana stack the backend already uses, never a separate RUM tool; plus
  session correlation (session.id anchoring spans, vitals, and error events),
  privacy rules across all telemetry surfaces, and testing the telemetry layer
  with InMemorySpanExporter without live collectors. Used by the frontend-
  engineer during Implement.
version: 3.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, observability, rum, web-vitals, opentelemetry, error-boundary, error-reporting, microfrontend, session-correlation, tracing]
related: [microfrontend-architecture, react-component-design, react-api-client, react-performance-optimization, go-chi-handler, go-middleware, opentelemetry-instrumentation, distributed-tracing-design, privacy-design, prometheus-metrics-design, slo-definition]
---

# React Observability

## Purpose

You cannot improve a user experience you cannot see. This skill maps the
browser to the SRE Four Golden Signals: Core Web Vitals cover **latency**
(LCP/INP) and **saturation** (Long Tasks blocking the main thread);
GlitchTip events cover **errors**; OTel spans cover **traffic** at the
interaction level. Five standards govern the implementation, in the order
they apply during development. Full code for every standard:
`references/error-boundary-and-reporting-standard.md`,
`references/tracing-and-web-vitals-standard.md`,
`references/telemetry-initialization-and-testing.md`.

---

## Standard 0 — Initialization Order

Telemetry must initialize before React renders. An error thrown during the
first render is lost if Sentry is not yet initialized; a `fetch` fired before
OTel instruments the global produces an untraced span. The required sequence
in `main.tsx`:

| Step | Call | Why it must be here |
|---|---|---|
| 1 | `initErrorReporting()` | Sentry captures errors thrown by the OTel init below |
| 2 | `initTracing()` | `FetchInstrumentation` patches global `fetch` before any component fires one |
| 3 | `ReactDOM.createRoot(...).render(<App />)` | Every fetch from here carries `traceparent` |
| 4 | `reportWebVitals()` | Must run after render — LCP needs a paint to observe |

Gate all four calls on `import.meta.env.PROD` (or an explicit `VITE_TELEMETRY_ENABLED`
env var) so unit tests never hit a collector. Full initialization code, the HMR
guard (never re-register providers on hot-module replacement), and package
versions: `references/telemetry-initialization-and-testing.md` §§1–2.

---

## Standard 1 — Error-Boundary Placement: Two Tiers

`getDerivedStateFromError`/`componentDidCatch` have no Hook translation —
React has never shipped a `useErrorBoundary` hook, and this is a permanent
exception to "hooks replaced classes," not a gap awaiting one (Banks &
Porcello). The boundary is a class component; it stays one.

| Tier | Owner | Placement |
|---|---|---|
| 1 — Per-remote | Shell (`microfrontend-architecture`) | One boundary around each remote's mount point — one crash falls back to that slot while shell chrome and every other remote keep working |
| 2 — Per-organism | The remote | One boundary around each independently-failing organism — a modal, a widget, the estate graph (`react-component-design`'s Minimum Bar) |

**Never one top-level boundary for the whole app** — it collapses both tiers,
turning a single widget's bug into a full white screen. Full placement rationale
and exact boundary class: `references/error-boundary-and-reporting-standard.md`
§§1–2.

---

## Standard 2 — Frontend Error Reporting

**Tool: GlitchTip** (self-hosted, Sentry-ingestion-API-compatible) via the
official `@sentry/react` SDK — open-source client against an open-source
self-hosted backend, per the frugality constraint. Disable
`browserTracingIntegration` — OTel Web (Standard 3) already owns tracing;
running both double-instruments `fetch` and mints a second, uncorrelated span
tree.

**Exact payload, enforced in `beforeSend`:** message/stack (source-mapped),
`react.componentStack` from `componentDidCatch`, `tags.kind`/`route`/`trace_id`,
`extra.session_id` (cross-signal glue — see Standard 5), and
`user: { id, tenant_id }` only — **never** `email`/`username`, matching
`privacy-design`'s minimisation principle.

**Sourcemaps:** upload to GlitchTip as part of the production build pipeline
(`@sentry/vite-plugin` or `sentry-cli upload-sourcemaps`) so stack traces are
symbolicated — a minified `bundle.min.js:1:42930` is useless in production.
Full SDK setup, `beforeSend` scrubbing, network-error filtering (which errors to
drop silently), and the CI sourcemap step:
`references/error-boundary-and-reporting-standard.md` §§3–5.

---

## Standard 3 — OpenTelemetry Web: Completing the Trace

`@opentelemetry/sdk-trace-web`'s `FetchInstrumentation` injects a W3C
`traceparent` header into outbound API calls — the same propagator format
`opentelemetry-instrumentation` registers on the Go side. For that header to
become the **parent** of the server span `go-middleware`'s `Telemetry`
middleware starts, the incoming context must be extracted from the header before
`tracer.Start` runs — the one call joining browser and backend into a single
trace. `react-api-client`'s `openapi-fetch` wrapper calls native `fetch`
underneath, so `traceparent` injection happens automatically with no separate
propagation code in that skill.

**Sampling:** apply `TraceIdRatioBasedSampler` (e.g., `0.1` in production) to
avoid saturating the collector at high session volume; always-on in development.

**Per-remote scoped tracers (microfrontend pattern):** the shell registers the
global `WebTracerProvider` once. Each remote calls
`trace.getTracer(remoteName, remoteVersion)` to obtain a scoped tracer from
the shared provider — scoped tracers differentiate spans by instrumentation
library name without forking the provider. Remotes **must not** call
`provider.register()` again; that overwrites the global and severs all spans
currently in flight. Module Federation's `shared:` config ensures a single OTel
package instance is shared across all remotes.

Full provider setup (with resource attributes), the exact extraction call,
custom span patterns, Long Task monitoring, sampling config, and the MFE
singleton: `references/tracing-and-web-vitals-standard.md` §§1–5.

---

## Standard 4 — Core Web Vitals Into the Shared Grafana Stack

Use the `web-vitals` library — spec-accurate measurement, never hand-rolled.
**FID is retired**: INP replaced it as the third official Core Web Vital in
March 2024.

| Metric | Measures | Good |
|---|---|---|
| **LCP** | Loading — when main content appeared | ≤ 2.5s |
| **INP** | Responsiveness — main-thread availability for interactions | ≤ 200ms |
| **CLS** | Visual stability — unexpected layout shift | ≤ 0.1 |

Report each as an OTel histogram (`vital.name`, `vital.rating`, `route`,
`release` — bounded, low-cardinality; never `session.id` — see Standard 5).
Set explicit histogram bucket boundaries tuned to each vital's Good/
Needs-improvement/Poor thresholds — default OTel buckets make percentile
queries meaningless (same rule `opentelemetry-instrumentation` applies on the
backend). Force-flush the meter exporter on `visibilitychange` → `hidden` —
LCP/INP/CLS often finalize as the page closes, and the worst sessions are
exactly the ones missing without this flush. Full metric code, export pipeline,
and bucket boundaries: `references/tracing-and-web-vitals-standard.md` §§6–8.

The `OTLP_HTTP_ENDPOINT` points at the same collector the backend uses —
one Prometheus, one Grafana, filterable by `service.name`. LCP/INP/CLS p75
thresholds per route can become latency SLIs in `slo-definition`, so backend
and frontend reliability are tracked in a single error-budget model.

---

## Standard 5 — Session Correlation

A telemetry event is actionable only when it correlates to the failing session.
Three anchors tie spans, vitals, and error events together:

| Anchor | Where set | Surfaces |
|---|---|---|
| `trace_id` | Active OTel trace (Standard 3) | Sentry `tags.trace_id` — pulls the full backend trace from one Sentry event |
| `session.id` | `crypto.randomUUID()` in `session.ts`, persisted to `sessionStorage` | OTel span attributes; Sentry `extra.session_id` — **never** a metric attribute (cardinality) |
| `user: { id, tenant_id }` | `Sentry.setUser(...)` after auth completes | Sentry user context only — ids, never PII |

`session.id` on metric labels would create one Prometheus series per user
session — a cardinality explosion that saturates Prometheus storage within days
on any real traffic volume. Keep it on span attributes (indexed, not aggregated)
and Sentry context (same). Full `session.ts` implementation and injection points:
`references/telemetry-initialization-and-testing.md` §3.

---

## Testing the Telemetry Layer

Telemetry code is production code — test it first.

- **Error boundary:** render a throwing component; assert fallback renders and
  `reportClientError` is called with the right `kind`/`componentStack`/`trace_id`.
- **`scrubEvent`:** pass a synthetic Sentry event with `cookies`, `Authorization`,
  `query_string`, `data` populated; assert all four are absent from the return.
- **OTel spans:** inject `@opentelemetry/sdk-trace-base`'s `InMemorySpanExporter`
  as the exporter in test setup; run the code under test; assert on recorded
  spans without touching a collector.
- **Web Vitals:** `web-vitals` measurements are not unit-testable (they need a
  real browser paint); verify the reporting pipeline in a Playwright test or
  leave the histogram record call shallow and assert on span attributes instead.

Full mock setup, provider test harness, and assertion patterns:
`references/telemetry-initialization-and-testing.md` §4.

---

## Privacy in Telemetry

`privacy-design`'s minimisation principle and `go-error-handling`'s "no PII
in error text" rule apply uniformly across every standard: no PII in spans,
metrics, error events, or tags — ids and counts only, never emails, file
contents, or extracted entity values; no tokens or secrets ever; honor user
consent for analytics even though RUM performance data is operational.

---

## Quality Criteria

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

---

## Anti-Patterns

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

---

## Output Format

```
src/telemetry/session.ts                (session.id generation + sessionStorage persistence)
src/telemetry/error-reporting.ts        (Sentry/GlitchTip init, beforeSend scrubbing, reportClientError, env gate)
src/telemetry/otel.ts                   (WebTracerProvider + MeterProvider, resource attrs, W3C propagation, sampling, fetch/document-load instrumentation)
src/telemetry/web-vitals.ts             (LCP/INP/CLS OTel histograms, bucket boundaries, force-flush on visibilitychange)
src/shared/ui/FeatureErrorBoundary.tsx  (class component — shell mounts per remote, remotes mount per organism)
src/telemetry/*.test.ts                 (written first — boundary throws, scrubEvent, InMemorySpanExporter span assertions)
vite.config.ts                          (@sentry/vite-plugin sourcemap upload on prod build)
```
