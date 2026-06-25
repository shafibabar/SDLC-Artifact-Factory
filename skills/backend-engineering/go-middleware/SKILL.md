---
name: go-middleware
description: >
  Teaches how to implement chi/net-http middleware — the cross-cutting request
  chain: request id/correlation, panic recovery (panic isolation), telemetry
  (trace span + RED metrics), structured logging with trace correlation, JWT
  authentication, security headers, and per-user rate limiting. Covers ordering,
  the context-value key pattern, and keeping each middleware single-purpose.
  Composes security-implementation and observability instrumentation. Used by the
  backend-engineer during Implement.
version: 1.0.0
phase: implement
owner: backend-engineer
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
RequestID → Recoverer → Telemetry → Logger → SecurityHeaders → Authenticate → RateLimit → handler
```

| Position | Why it sits here |
|---|---|
| `RequestID` first | Every later layer (logs, traces, panics) can reference the correlation id |
| `Recoverer` early | Must wrap everything inside it so any downstream panic is caught |
| `Telemetry` before `Logger` | The span exists before logging, so logs carry the trace id |
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

Starts the server span, records the three RED signals (Rate, Errors, Duration) per route, and makes the span available to everything downstream. Detailed instrument design is in `opentelemetry-instrumentation`; this is the wiring.

```go
func (m Middleware) Telemetry(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        route := chi.RouteContext(r.Context()).RoutePattern() // low-cardinality label
        ctx, span := m.tracer.Start(r.Context(), r.Method+" "+route)
        defer span.End()

        rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
        start := time.Now()
        next.ServeHTTP(rec, r.WithContext(ctx))

        attrs := metric.WithAttributes(
            attribute.String("http.route", route),
            attribute.String("http.method", r.Method),
            attribute.Int("http.status_code", rec.status),
        )
        m.reqCount.Add(ctx, 1, attrs)                                  // Rate (+ Errors via status)
        m.reqDuration.Record(ctx, time.Since(start).Seconds(), attrs)  // Duration (histogram)
        span.SetAttributes(attribute.Int("http.status_code", rec.status))
    })
}
```

**Use the chi route pattern (`/v1/data-assets/{id}/...`), not the raw path**, as the metric/span label — raw paths contain UUIDs and would explode metric cardinality.

---

## Authentication Middleware

Validates the JWT (RS256, JWKS) and puts the resolved `Subject` and `tenant_id` into context. The detailed token validation is in `security-implementation`; this places the result for downstream layers.

```go
func (m Middleware) Authenticate(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        sub, err := m.authn.SubjectFromRequest(r) // verifies signature, audience, issuer, expiry
        if err != nil {
            writeError(w, r, http.StatusUnauthorized, "AUTHENTICATION_REQUIRED", "authentication required")
            return
        }
        ctx := context.WithValue(r.Context(), ctxKeyToken, sub)
        ctx = context.WithValue(ctx, ctxKeyTenant, sub.TenantID)
        // bind identity to the log/span for the rest of the request
        slog.SetDefault(slog.Default()) // logger derives attrs from ctx; see structured-logging-design
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

Health/readiness routes are mounted **outside** the authenticated group so probes don't need tokens.

---

## Rate Limiting

Per-user token-bucket using `golang.org/x/time/rate` (detail in `security-implementation`). Applied after authentication so the limiter key is the user id.

```go
func (m Middleware) RateLimit(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        sub, _ := domain.SubjectFromContext(r.Context())
        if !m.limiter.Allow(sub.ID.String()) {
            w.Header().Set("Retry-After", "1")
            writeError(w, r, http.StatusTooManyRequests, "RATE_LIMIT_EXCEEDED", "too many requests")
            return
        }
        next.ServeHTTP(w, r)
    })
}
```

---

## Rules

- **One concern per middleware.** Don't merge auth + logging + metrics into one function.
- **Allocate per-request state minimally.** The `statusRecorder` is a small stack-friendly wrapper; avoid per-request maps/closures on the hot path (see `go-performance-optimization`).
- **Low-cardinality labels.** Route patterns, methods, status codes — never raw paths, ids, or user input.
- **Recover at the boundary only.** The chain has exactly one `Recoverer`; handlers do not recover.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Correct ordering | RequestID→Recoverer→Telemetry→Logger→…→Auth→RateLimit | Logger before telemetry; rate limit before auth |
| Panic isolation | One boundary recoverer; logs panic + trace id; 500 | Panics crashing the process |
| Context keys | Unexported key types | String keys / exported keys |
| Low cardinality | Route pattern as label | Raw path/UUID as a metric label |
| Single purpose | Each middleware does one thing | A "kitchen-sink" middleware |
| Probes unauthenticated | Health routes outside the auth group | Probes requiring a JWT |

---

## Output Format

Produces Go source plus middleware tests (`httptest`):

```
internal/handlers/http/middleware.go
internal/handlers/http/context.go
internal/handlers/http/middleware_test.go   (written first)
```
