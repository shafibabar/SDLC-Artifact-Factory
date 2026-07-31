# Middleware Stage Implementations

Full worked implementations for `Telemetry`, `CORS`, `Authenticate`, and `RateLimit` —
the chain stages that are mostly wiring detail once their placement rule is
understood. Placement and the reasoning behind it live in `SKILL.md`'s "Middleware
Ordering Standard"; the `Recoverer` and `statusRecorder` standards live in the sibling
`references/recoverer-and-response-wrapping.md`; this file is the remaining stages'
code. Self-contained — read it without assuming `SKILL.md`'s body is also loaded.

---

## Telemetry Middleware (span + RED metrics)

Starts the server span, records the three RED signals (Rate, Errors, Duration) per
route, and wraps `w` in the `statusRecorder` (`references/recoverer-and-response-wrapping.md`)
that `Logging` reads from further in. Detailed instrument design is in
`opentelemetry-instrumentation`; this is the wiring:

```go
func (m Middleware) Telemetry(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // chi resolves the route inside next.ServeHTTP — RoutePattern() is empty before it.
        ctx, span := m.tracer.Start(r.Context(), r.Method)
        defer span.End()

        rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
        start := time.Now()
        next.ServeHTTP(rec, r.WithContext(ctx)) // rec flows to Logging unchanged — wrap once

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

**Use the chi route pattern (`/v1/data-assets/{id}/...`), not the raw path**, as the
metric/span label — raw paths contain UUIDs and would explode metric cardinality.

---

## CORS Middleware

Resolves cross-origin requests for the React frontend (tech-stack default) — and
short-circuits the browser's preflight `OPTIONS` request — before `Authenticate` ever
runs:

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

A preflight `OPTIONS` request carries no `Authorization` header or cookie by design —
the browser sends it *before* deciding whether to attach credentials to the real
request. `cors.Handler` answers the preflight itself (204, no further chain), which is
exactly why it must sit outside `Authenticate`: if it sat inside, every cross-origin
browser client would fail preflight with a confusing 401 instead of getting the actual
CORS decision. `AllowedOrigins` is never `"*"` when `AllowCredentials` is `true` — the
CORS spec forbids the combination and browsers reject it outright.

---

## Authentication Middleware

Validates the bearer credential (RS256 JWT + JWKS, or an opaque session token —
`security-implementation` owns the verification mechanics) and stores the resolved
`domain.Subject` — which already carries `TenantID` as a field — under `domain`'s own
private context key via `domain.ContextWithSubject`, never a second, independently-set
tenant key:

```go
func (m Middleware) Authenticate(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        sub, err := m.authn.SubjectFromRequest(r) // verifies signature, audience, issuer, expiry
        if err != nil {
            writeError(w, r, http.StatusUnauthorized, "AUTHENTICATION_REQUIRED", "authentication required")
            return
        }
        // domain.ContextWithSubject is the ONLY way to set this key — its type is
        // private to the domain package (SKILL.md's "Context Key Ownership").
        next.ServeHTTP(w, r.WithContext(domain.ContextWithSubject(r.Context(), sub)))
    })
}
```

Storing one `domain.Subject` value (not a `Subject` key plus a separate `TenantID`
key set from the same struct) removes an entire class of drift bug: two
independently-set context values can be updated inconsistently by a future edit that
touches one and forgets the other; one value with `TenantID` as a field cannot.

Health/readiness routes are mounted **outside** the authenticated group entirely (a
separate router — `health-check-design`), never nested under a group that passes
through `Authenticate`, so probes don't need tokens.

---

## Rate Limiting

Per-subject token bucket via `golang.org/x/time/rate`, mounted after `Authenticate` so
the limiter key is the authenticated subject's id, not a shared/spoofable IP:

```go
type limiterStore struct {
    mu       sync.Mutex
    limiters map[string]*limiterEntry
    rate     rate.Limit // sustained rate — see defaults below
    burst    int        // short-spike allowance
}

type limiterEntry struct {
    limiter  *rate.Limiter
    lastSeen time.Time
}

func newLimiterStore(r rate.Limit, burst int) *limiterStore {
    s := &limiterStore{limiters: make(map[string]*limiterEntry), rate: r, burst: burst}
    go s.sweep(5 * time.Minute) // eviction goroutine, owned for the process lifetime
    return s
}

// sweep evicts entries idle past the interval — without it, this map grows one entry
// per distinct subject ever seen, for the life of the process (Edwards, Let's Go
// Further; the same "orphan" hazard go-concurrency-patterns names for goroutines,
// here applied to a map).
func (s *limiterStore) sweep(interval time.Duration) {
    t := time.NewTicker(interval)
    defer t.Stop()
    for range t.C {
        s.mu.Lock()
        for key, e := range s.limiters {
            if time.Since(e.lastSeen) > interval {
                delete(s.limiters, key)
            }
        }
        s.mu.Unlock()
    }
}

func (s *limiterStore) reserve(key string) *rate.Reservation {
    s.mu.Lock()
    defer s.mu.Unlock()
    e, ok := s.limiters[key]
    if !ok {
        e = &limiterEntry{limiter: rate.NewLimiter(s.rate, s.burst)}
        s.limiters[key] = e
    }
    e.lastSeen = time.Now()
    return e.limiter.Reserve()
}
```

**Default parameters**: `rate.Limit(10)` (10 requests/second sustained) with `burst:
20` — the sustained rate bounds steady-state load per subject; the burst headroom
absorbs a legitimate short spike (a page load firing several requests at once)
without rejecting it. Tune per route class in `sdlc-config.json`, never hand-picked
per handler.

```go
func (m Middleware) RateLimit(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        sub, err := domain.SubjectFromContext(r.Context())
        if err != nil {
            // Invariant violation, not a client error: RateLimit is mounted inside
            // Authenticate, so a Subject must already be in context. A missing one
            // means the chain was misassembled — a bug, caught by Recoverer.
            panic(fmt.Errorf("RateLimit: %w", err))
        }
        res := m.limiters.reserve(sub.ID.String())
        if delay := res.Delay(); delay > 0 {
            res.Cancel() // give the token back — this request is rejected, don't spend it
            w.Header().Set("Retry-After", strconv.Itoa(int(delay.Round(time.Second).Seconds())+1))
            writeError(w, r, http.StatusTooManyRequests, "RATE_LIMIT_EXCEEDED", "too many requests")
            return
        }
        next.ServeHTTP(w, r)
    })
}
```

`res.Delay()` computes the exact wait until the next token is available — `Retry-After`
is a real, computed number of seconds, not a hardcoded guess. `res.Cancel()` on the
rejected path returns the reservation's token to the bucket; omitting it silently
drains capacity from a request that was never actually allowed to proceed, tightening
the effective rate below the configured one for every subsequent caller sharing that
key.
