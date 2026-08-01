# Error-Boundary Placement and Frontend Error-Reporting Standard — Full Standard

Self-contained reference for `react-observability`. Deepens the SKILL.md
body's two rule statements — boundary placement and error reporting —
into the exact granularity, code, and payload contract a reviewer checks.

---

## 1. Boundary Placement Is Two Tiers, Not One

A crash's blast radius is bounded by where the nearest boundary sits.
This layout has **two tiers**, each owned by a different layer, and both
apply — they are additive, not alternatives:

| Tier | Owner | Placement | Blast radius if no boundary here |
|---|---|---|---|
| **1 — Per-remote** | Shell (`microfrontend-architecture`) | One boundary around **each remote's** mount point — where the shell renders `React.lazy(() => import("remoteApp/App"))` (the same mount point `react-routing`'s Standard 1 names as the remote's `/*` wildcard) | One remote's render crash unmounts the entire shell — every other loaded remote and the persistent nav disappear with it |
| **2 — Per-organism** | The remote itself | One boundary around each independently-failing organism inside the remote — a modal, a dashboard widget, the estate graph (`react-component-design`'s Minimum Bar) | A crash in one widget takes down the whole remote's screen, even though the rest of that remote's UI never touched the failing code path |

**The rule this replaces: never one single top-level boundary for the
whole app.** A lone `<App>`-wrapping boundary collapses both tiers into
one — a bug in one dashboard widget white-screens the entire product,
shell chrome included, for a fault that touched one fragment. The shell
mounts a `FeatureErrorBoundary` per remote; each remote mounts its own
per independently-failing organism. Neither tier substitutes for the
other — a remote with no internal boundaries still takes down its own
whole screen for one widget's bug, even though the shell and sibling
remotes survive.

**The litmus test at both tiers is the same:** if this subtree's code
throws during render, what is the smallest region of the screen that
should show a fallback while everything outside it keeps working? That
region gets its own boundary.

---

## 2. The Class-Based Error Boundary — Preserved Verbatim

React has never shipped a `useErrorBoundary` hook. `getDerivedStateFromError`
and `componentDidCatch` are lifecycle methods with no Hook translation —
this is a permanent, accepted exception to "hooks replaced classes," not
a temporary gap awaiting a future hook (Banks & Porcello, *Learning
React*, 2nd ed.). Every other component in this domain's 13 skills is a
function component; this one class is correct specifically **because**
no hook equivalent exists, and it must not be "modernized" into one that
doesn't. The mechanism is unchanged from this skill's prior revision —
reproduced here verbatim, not rewritten:

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

One `FeatureErrorBoundary` component serves both tiers — the shell
instantiates it around each remote's lazy import; a remote instantiates
it around each of its own independently-failing organisms. Only the
call site changes; the class does not. `reportClientError` — called from
`componentDidCatch` above — is defined in §3: it is a thin wrapper over
the error-reporting SDK, not part of the boundary's own logic, so the
boundary stays exactly as written above regardless of which reporting
backend §3 wires it to.

---

## 3. Frontend Error-Reporting Standard

### Tool choice: GlitchTip, via the `@sentry/react` SDK

Per CLAUDE.md § Budget and Frugality (open-source over paid tooling),
point the official, MIT-licensed `@sentry/react` client SDK at a
**self-hosted GlitchTip** instance rather than Sentry SaaS. GlitchTip
implements Sentry's ingestion API, so the well-tested official SDK —
automatic `window.onerror`/`unhandledrejection` capture, breadcrumbs,
`beforeSend` scrubbing, release tagging — works unmodified against it.
This mirrors the platform's existing self-hosted-over-SaaS pattern
(Prometheus/Grafana over a metrics SaaS, per `prometheus-metrics-design`)
applied to error reporting.

```ts
// src/telemetry/error-reporting.ts
import * as Sentry from "@sentry/react";
import { getSessionId } from "./session";

export function initErrorReporting(): void {
  // Only initialize in production — unit tests must never hit a collector.
  if (!import.meta.env.PROD && !import.meta.env.VITE_TELEMETRY_ENABLED) return;

  Sentry.init({
    dsn: import.meta.env.VITE_GLITCHTIP_DSN,   // self-hosted GlitchTip project DSN
    environment: import.meta.env.MODE,           // "production" | "staging"
    release: __APP_VERSION__,                    // injected by @sentry/vite-plugin at build time
    integrations: [],                            // no browserTracingIntegration — OTel Web owns tracing
    beforeSend: scrubEvent,                      // enforces the payload contract on every event
  });
}

export function reportClientError(
  error: unknown,
  extra: { kind: "render" | "global" | "promise"; componentStack?: string },
) {
  Sentry.captureException(error, (scope) => {
    scope.setTag("kind", extra.kind);
    if (extra.componentStack) scope.setContext("react", { componentStack: extra.componentStack });
    scope.setTag("route", currentRoute());
    scope.setTag("trace_id", activeTraceId()); // correlates to the OTel trace — see tracing-and-web-vitals-standard.md §2
    scope.setExtra("session_id", getSessionId()); // cross-signal glue — correlates to OTel span session.id
    return scope;
  });
}
```

**No `browserTracingIntegration`.** OTel Web already owns tracing
(`references/tracing-and-web-vitals-standard.md`) and completes the
browser→backend trace via `traceparent`. Running Sentry's own
performance/tracing integration alongside it would double-instrument
`fetch`, mint a second, uncorrelated span tree, and duplicate overhead —
the "two competing tracers" anti-pattern (SKILL.md). GlitchTip/`@sentry/react`
here does exactly one job: error and breadcrumb capture. The link
between an error event and its full backend trace is the `trace_id` tag
set explicitly above, not a second tracer.

`window.addEventListener("error", …)`/`"unhandledrejection"` handlers
are unnecessary alongside this SDK — `Sentry.init` installs its own
`GlobalHandlers` integration that captures both automatically and routes
them through the same `beforeSend` scrubbing. A hand-rolled listener
duplicating that capture is redundant, not additive.

**`session_id` in `extra`** is not a `tags` field — it is high-cardinality
(unique per page load) so it cannot index in GlitchTip's tag index, but
it is stored in `extra` and searchable in the event detail view, which is
sufficient to pivot from a Sentry event to the OTel trace for that session.

### The exact payload contract

| Field | Source | Rule |
|---|---|---|
| `message` / `stack` | The caught `Error` | Source-mapped via uploaded sourcemaps — see §4 |
| `react.componentStack` | `componentDidCatch`'s `info.componentStack` | Render-path errors only; absent for global/promise errors |
| `tags.kind` | `"render"` \| `"global"` \| `"promise"` | Distinguishes boundary catches from `window` listener catches |
| `tags.route` | Active route config | Never the raw URL — path pattern only, mirroring `opentelemetry-instrumentation`'s low-cardinality label rule |
| `tags.trace_id` | The active OTel trace id | The single field a support ticket needs to pull the full backend trace |
| `extra.session_id` | `getSessionId()` from `session.ts` | Cross-signal glue to OTel spans for this page visit; high-cardinality, stored in `extra` not `tags` |
| `user` | `{ id, tenant_id }` only, via `Sentry.setUser` | **Never** `email`/`username` — id and tenant id are enough to reproduce a session; matches `privacy-design`'s data-minimisation principle |
| `release` | `__APP_VERSION__` injected by `@sentry/vite-plugin` | Attributes a regression to a specific deploy |

### `beforeSend` scrubbing is the enforcement point

```ts
function scrubEvent(event: Sentry.Event): Sentry.Event | null {
  delete event.request?.cookies;
  delete event.request?.headers?.Authorization;
  // Never let a raw querystring (may carry a token) or request body through.
  if (event.request) { delete event.request.query_string; delete event.request.data; }
  return event;
}
```

**No PII, no secrets, ever** — no email addresses, no file contents, no
extracted entity values, no tokens — matching `go-error-handling`'s
identical rule on the backend side ("No PII or secrets in error text")
and `privacy-design`'s minimisation principle. `beforeSend` is the one
place this is enforced for every event, the same "one mapping point"
discipline `go-chi-handler` applies to status-code mapping — scrubbing
scattered across call sites is exactly as unreliable as status logic
scattered across handlers.

---

## 4. Sourcemap Upload — CI Pipeline Step

Without sourcemaps uploaded to GlitchTip, every stack trace in production
shows minified line numbers (`bundle.min.js:1:42930`) — useless for
debugging. Upload sourcemaps as part of the production build via
`@sentry/vite-plugin`:

```ts
// vite.config.ts
import { sentryVitePlugin } from "@sentry/vite-plugin";

export default defineConfig({
  build: { sourcemap: true },  // generate sourcemaps
  plugins: [
    // ...other plugins
    sentryVitePlugin({
      org: "self-hosted",                             // GlitchTip org slug
      project: "estate-ui",                          // GlitchTip project slug
      url: process.env.VITE_GLITCHTIP_URL,           // self-hosted GlitchTip base URL
      authToken: process.env.SENTRY_AUTH_TOKEN,      // from CI secrets — never in code
      release: { name: process.env.APP_VERSION },    // matches __APP_VERSION__ in the bundle
      sourcemaps: {
        assets: "./dist/**",
        deleteAfterUpload: true,  // don't ship sourcemaps to the CDN — they expose source
      },
    }),
  ],
});
```

`deleteAfterUpload: true` is load-bearing: sourcemaps uploaded to GlitchTip
must not also be served from the CDN. They contain your full original source
code and, if publicly accessible, expose the application logic to any
external party who fetches `bundle.min.js.map`.

The plugin runs only when `SENTRY_AUTH_TOKEN` is set — it silently skips
in local dev and in PRs that don't have the secret, so no special branch
condition is needed.

---

## 5. Network Error Filtering

Not every error caught by `Sentry.init`'s `GlobalHandlers` deserves a
GlitchTip event. Transient network noise, browser extensions, and
user-initiated cancellations generate high-volume noise with no actionable
signal. Drop them in `beforeSend` rather than paying storage and alert
fatigue costs for events you cannot act on:

```ts
function scrubEvent(event: Sentry.Event, hint?: Sentry.EventHint): Sentry.Event | null {
  const err = hint?.originalException;

  // Drop transient network errors — these are connection issues, not code bugs.
  if (err instanceof TypeError && /network|fetch|failed to fetch/i.test(String(err.message))) {
    return null;  // returning null drops the event entirely
  }

  // Drop AbortError — the user (or the api client's own timeout) cancelled the request.
  if (err instanceof DOMException && err.name === "AbortError") return null;

  // Drop browser-extension errors — they originate in code we don't own.
  const stack = typeof err === "object" && err !== null && "stack" in err ? String((err as Error).stack) : "";
  if (/chrome-extension:|moz-extension:|safari-extension:/.test(stack)) return null;

  // Strip credentials and request body from surviving events.
  delete event.request?.cookies;
  delete event.request?.headers?.Authorization;
  if (event.request) { delete event.request.query_string; delete event.request.data; }

  return event;
}
```

**The principle:** `beforeSend` is the single enforcement point for both
scrubbing (what fields survive) and filtering (which events survive). This
is the same "one mapping point" discipline `go-chi-handler` applies to
status-code mapping — scrubbing or filtering scattered across multiple call
sites is exactly as unreliable as status logic scattered across handlers.

---

## 6. Verification

- Render a component that throws inside each boundary tier (a remote's
  root, and a nested organism) in a test; assert the fallback renders
  and everything outside the boundary is unaffected.
- Assert `reportClientError` is called with `kind`, `componentStack`
  (render errors only), `route`, `trace_id`, and `session_id` populated —
  a test double for `Sentry.captureException` is sufficient; no live
  GlitchTip call in unit tests.
- Assert `scrubEvent` strips `cookies`, `Authorization`, `query_string`,
  and `data` from a synthetic event with all four present.
- Assert `scrubEvent` returns `null` for a synthetic `TypeError` with
  "Failed to fetch" as its message, and for an `AbortError`, and for an
  error whose stack includes `chrome-extension:`.
