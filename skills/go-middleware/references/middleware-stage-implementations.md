# Middleware Stage Implementations

Full worked implementations for the three chain stages that are mostly wiring detail once their placement rule is understood: `Telemetry`, `Authenticate`, and `RateLimit`. Placement in the chain and the reasoning behind it live in `SKILL.md`'s Ordering Matters table — this file is the code.

---

## Telemetry Middleware (span + RED metrics)

Starts the server span, records the three RED signals (Rate, Errors, Duration) per route, and makes the span available to everything downstream. Detailed instrument design is in `opentelemetry-instrumentation`; this is the wiring.

```go
func (m Middleware) Telemetry(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // chi resolves the route inside next.ServeHTTP — RoutePattern() is empty before it.
        // Start the span with a provisional name; finalise name + attrs after routing.
        ctx, span := m.tracer.Start(r.Context(), r.Method)
        defer span.End()

        rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
        start := time.Now()
        next.ServeHTTP(rec, r.WithContext(ctx))

        route := chi.RouteContext(r.Context()).RoutePattern() // now populated; low-cardinality label
        span.SetName(r.Method + " " + route)

        attrs := metric.WithAttributes(
            semconv.HTTPRoute(route),                       // semconv constants, not hand-typed keys
            semconv.HTTPRequestMethodKey.String(r.Method),
            semconv.HTTPResponseStatusCode(rec.status),
        )
        m.reqCount.Add(ctx, 1, attrs)                                  // Rate (+ Errors via status)
        m.reqDuration.Record(ctx, time.Since(start).Seconds(), attrs)  // Duration (histogram)
        span.SetAttributes(semconv.HTTPResponseStatusCode(rec.status))
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
        // Identity travels in ctx; the ctx-aware slog.Handler adds subject/tenant to every
        // downstream log line automatically — see structured-logging-design.
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
        sub, _ := domain.SubjectFromContext(r.Context()) // always present: RateLimit is mounted inside Authenticate
        if !m.limiter.Allow(sub.ID.String()) {
            w.Header().Set("Retry-After", "1")
            writeError(w, r, http.StatusTooManyRequests, "RATE_LIMIT_EXCEEDED", "too many requests")
            return
        }
        next.ServeHTTP(w, r)
    })
}
```
