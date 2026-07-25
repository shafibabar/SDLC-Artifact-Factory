---
name: go-middleware
description: >
  Teaches how to implement chi/net-http middleware — the cross-cutting request
  chain: request id/correlation, panic recovery (panic isolation, including
  closing the connection after a panic), telemetry (trace span + RED metrics),
  structured logging with trace correlation, CORS for cross-origin browser
  clients, JWT authentication, security headers, and per-user rate limiting.
  Covers ordering, the context-value key pattern, and keeping each middleware
  single-purpose. Composes security-implementation and observability
  instrumentation. Full Telemetry/Authenticate/RateLimit implementations are in
  references/middleware-stage-implementations.md. Used by the backend-engineer
  during Implement.
version: 2.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, middleware, chi, recover, telemetry, jwt, rate-limit]
---

# Go Middleware

## Purpose

Middleware handles what every request needs but no handler should repeat: correlation, panic recovery, telemetry, logging, authentication, security headers, rate limiting. Each is a small single-purpose `func(http.Handler) http.Handler`. Composed in the right order, they form the request pipeline so that handlers can stay thin and assume a well-formed, authenticated, observable request.

This composes the security controls from `security-implementation` and the instrumentation from `opentelemetry-instrumentation` / `structured-logging-design` into the chain wired by `go-chi-handler`.

---

## Ordering Matters

Middleware runs outside-in on the way in, inside-out on the way out. The order is deliberate:

```
RequestID → Recoverer → Telemetry → Logger → SecurityHeaders → CORS → Authenticate → RateLimit → handler
```

| Position | Why it sits here |
|---|---|
| `RequestID` first | Every later layer (logs, traces, panics) can reference the correlation id |
| `Recoverer` early | Must wrap everything inside it so any downstream panic is caught |
| `Telemetry` before `Logger` | The span exists before logging, so logs carry the trace id |
| `CORS` before `Authenticate` | A browser's preflight `OPTIONS` request carries no `Authorization` header/cookie by design — if it reaches an auth-gated stage first, every cross-origin browser client fails with a confusing 401-on-preflight instead of the real, debuggable cross-origin failure |
| `Authenticate` before `RateLimit` | Rate limit is per-user, so identity must be resolved first |
| `RateLimit` last before handler | Reject excess load after cheap checks, before doing real work |

---

## The Context Key Pattern

Values shared from middleware to handlers (subject, tenant, request id) go in the request context under **unexported key types** — so no other package can collide or read them by guessing a string.

```go
// internal/handlers/http/context.go
package http

type ctxKey int

const (
    ctxKeyRequestID ctxKey = iota
    ctxKeyToken
    ctxKeyTenant
)
```

---

## Panic Recovery (Panic Isolation)

The blueprint's rule: a panic in one request must never crash the process. The recoverer catches it at the request boundary, logs it with the trace id and stack, and returns an opaque 500.

```go
func (m Middleware) Recoverer(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        defer func() {
            if rec := recover(); rec != nil {
                slog.ErrorContext(r.Context(), "panic recovered",
                    "panic", rec, "stack", string(debug.Stack()))
                span := trace.SpanFromContext(r.Context())
                span.RecordError(fmt.Errorf("panic: %v", rec))
                span.SetStatus(codes.Error, "panic")
                // A panic can leave the handler goroutine's state — and any partial
                // write to w — undefined. Force the server to close this connection
                // rather than return it to the keep-alive pool for reuse; must be
                // set before the response is written (Edwards, Let's Go Further).
                w.Header().Set("Connection", "close")
                writeError(w, r, http.StatusInternalServerError, "INTERNAL", "an unexpected error occurred")
            }
        }()
        next.ServeHTTP(w, r)
    })
}
```

`panic` is reserved for genuinely unrecoverable states; `recover` lives only at boundaries like this one and the top of each spawned goroutine (see `go-concurrency-patterns`). Business errors are values, never panics (see `go-error-handling`).

---

## Telemetry Middleware (span + RED metrics)

Starts the server span, records the three RED signals (Rate, Errors, Duration) per route, and makes the span available to everything downstream. **Use the chi route pattern (`/v1/data-assets/{id}/...`), not the raw path**, as the metric/span label — raw paths contain UUIDs and would explode metric cardinality. Full implementation: `references/middleware-stage-implementations.md`.

---

## CORS Middleware

Resolves cross-origin requests for the React frontend (tech-stack default) — and short-circuits the browser's preflight `OPTIONS` request — before any auth-gated stage. Allowed origins/methods/headers are environment-dependent: the local dev-server origin in dev, the deployed frontend's real origin(s) in prod.

```go
func (m Middleware) CORS(next http.Handler) http.Handler {
    return cors.Handler(cors.Options{
        AllowedOrigins:   m.cfg.AllowedOrigins,   // dev: http://localhost:5173 (Vite); prod: https://app.example.com
        AllowedMethods:   []string{http.MethodGet, http.MethodPost, http.MethodPatch, http.MethodDelete, http.MethodOptions},
        AllowedHeaders:   []string{"Authorization", "Content-Type", "Idempotency-Key"},
        ExposedHeaders:   []string{"Retry-After"},
        AllowCredentials: true,           // requires an explicit origin list — never "*" with credentials
        MaxAge:           300,            // seconds a browser may cache the preflight result
    })(next)
}
```

A preflight `OPTIONS` request carries no `Authorization` header or cookie by design — the browser sends it *before* deciding whether to attach credentials to the real request. `cors.Handler` answers the preflight itself (204, no further chain) so it must sit outside (before) `Authenticate`; if it sat inside, every cross-origin browser client would fail preflight with a confusing 401 instead of getting the actual CORS decision. `AllowedOrigins` is never `"*"` when `AllowCredentials` is `true` — the CORS spec forbids the combination and browsers reject it.

---

## Authentication Middleware

Validates the JWT (RS256, JWKS) and puts the resolved `Subject` and `tenant_id` into context. The detailed token validation is in `security-implementation`; this places the result for downstream layers. Health/readiness routes are mounted **outside** the authenticated group so probes don't need tokens. Full implementation: `references/middleware-stage-implementations.md`.

---

## Rate Limiting

Per-user token-bucket using `golang.org/x/time/rate` (detail in `security-implementation`). Applied after authentication so the limiter key is the user id. Full implementation: `references/middleware-stage-implementations.md`.

---

## Rules

- **One concern per middleware.** Don't merge auth + logging + metrics into one function.
- **Allocate per-request state minimally.** The `statusRecorder` is a small stack-friendly wrapper; avoid per-request maps/closures on the hot path (see `go-performance-optimization`).
- **Low-cardinality labels.** Route patterns, methods, status codes — never raw paths, ids, or user input.
- **Recover at the boundary only.** The chain has exactly one `Recoverer`; handlers do not recover.
- **Close the connection after a panic.** `Recoverer` sets `Connection: close` before writing the 500 — a post-panic connection must not return to the keep-alive pool in a potentially inconsistent state.
- **CORS resolves before authentication.** Preflight `OPTIONS` requests carry no credentials by design; `CORS` sits outside (before) `Authenticate` so preflight gets the real cross-origin decision, not a 401.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Correct ordering | RequestID→Recoverer→Telemetry→Logger→…→CORS→Auth→RateLimit | Logger before telemetry; CORS or rate limit after auth |
| Panic isolation | One boundary recoverer; logs panic + trace id; 500 | Panics crashing the process |
| Post-panic connection closed | `Connection: close` set before the 500 is written | Panic response left keep-alive eligible |
| CORS before auth | Preflight `OPTIONS` resolved outside the auth group | Preflight requests hitting `Authenticate` and getting 401 |
| Context keys | Unexported key types | String keys / exported keys |
| Low cardinality | Route pattern as label | Raw path/UUID as a metric label |
| Single purpose | Each middleware does one thing | A "kitchen-sink" middleware |
| Probes unauthenticated | Health routes outside the auth group | Probes requiring a JWT |

---

## Anti-Patterns

- **Kitchen-sink middleware** — one function doing auth, logging, and metrics. Impossible to test, reorder, or reuse; each concern gets its own `func(http.Handler) http.Handler`.
- **String context keys** — `context.WithValue(ctx, "tenant", …)` collides silently across packages and lets any import read or overwrite the value. Unexported key types only.
- **Reading `RoutePattern()` before `next.ServeHTTP`** — chi resolves the route inside the handler chain; the pattern is empty until routing completes. Capture it after, or every metric lands on an empty route.
- **Raw URL path as a span name or metric label** — `/v1/data-assets/6f9a…/classification` mints a new series per UUID. Cardinality explosions take down the metrics backend, not the service.
- **Rate limiting before authentication** — the limiter key falls back to IP, punishing everyone behind one NAT and leaving per-user abuse uncapped.
- **A second `recover` inside handlers** — hides bugs from the boundary recoverer and its panic telemetry. One recoverer per chain.
- **Mutating global state per request** (e.g., `slog.SetDefault` in a middleware) — process-wide side effects from request scope race by definition.
- **Panic response left keep-alive eligible** — omitting `Connection: close` before the opaque 500 lets the server return a connection that may be mid-write or framing-corrupted to the pool, where the *next* request on it can read a corrupted response.
- **CORS mounted after auth** — preflight `OPTIONS` requests fail with 401 instead of the real cross-origin failure they're meant to catch.

---

## Output Format

Produces Go source plus middleware tests (`httptest`):

```
internal/handlers/http/middleware.go
internal/handlers/http/context.go
internal/handlers/http/middleware_test.go   (written first)
```

Full Telemetry/Authenticate/RateLimit implementations: `references/middleware-stage-implementations.md`.
