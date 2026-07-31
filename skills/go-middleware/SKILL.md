---
name: go-middleware
description: >
  Teaches how to implement chi/net-http middleware — the cross-cutting
  request pipeline — to a checkable engineering standard: the exact ordering
  standard (Recoverer outermost, then RequestID, Telemetry, Logging,
  SecurityHeaders, CORS, Authenticate, RateLimit) with the reasoning for
  each position and the trade-off Recoverer's position entails; the
  panic-recovery standard (exact recover() placement, stack trace logged
  server-side only via debug.Stack(), never in the response, the opaque 500
  built from go-chi-handler's own ErrorResponse envelope); the statusRecorder
  ResponseWriter-wrapping standard for capturing status code and bytes
  written, and the two concrete bugs naive wrapping causes (WriteHeader never
  called, WriteHeader called twice); the token-bucket rate-limiting standard
  with exact 429/Retry-After response and idle-entry eviction; and the
  auth-middleware standard, including the private-context-key-type
  convention for the authenticated Subject (owned by domain, never a raw
  string key) and why RequestID must delegate to chi's own middleware rather
  than mint a bespoke key. Full Telemetry/CORS/Authenticate/RateLimit
  implementations are in references/middleware-stage-implementations.md; the
  Recoverer and statusRecorder standards are in
  references/recoverer-and-response-wrapping.md. Composes
  security-implementation and observability instrumentation into the chain
  wired by go-chi-handler. Used by the backend-engineer during Implement.
version: 3.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, middleware, chi, recover, response-writer, telemetry, jwt, rate-limit, context-key]
related: [go-error-handling, go-chi-handler, go-concurrency-patterns, go-domain-model, security-implementation, opentelemetry-instrumentation, structured-logging-design]
---

# Go Middleware

## Purpose

Middleware handles what every request needs but no handler should repeat: panic isolation, correlation, telemetry, logging, authentication, security headers, rate limiting. Each is a small single-purpose `func(http.Handler) http.Handler`. Composed in the right order, they form the request pipeline so handlers can stay thin and assume a well-formed, authenticated, observable request.

This is the **one place `recover()` is allowed in the HTTP chain** — `go-error-handling`'s panic/recover discipline names this middleware as the HTTP boundary explicitly; this skill owns the exact mechanics of that boundary. It composes the security controls from `security-implementation` and the instrumentation from `opentelemetry-instrumentation`/`structured-logging-design` into the chain `go-chi-handler` wires up.

---

## Middleware Ordering Standard

```
Recoverer → RequestID → Telemetry → Logging → SecurityHeaders → CORS → Authenticate → RateLimit → handler
```

| Position | Why it sits exactly here |
|---|---|
| `Recoverer` first, outermost | Must wrap **every** later middleware, not just the handler — a panic in `RequestID` or `CORS` is exactly as fatal to the process as one in the handler if nothing wraps it. The named cost: its own `r.Context()` never carries values set by anything inside it (see `references/recoverer-and-response-wrapping.md`). |
| `RequestID` second | Every later layer (logs, traces, the error envelope's `traceId`) can reference the correlation id from here on. Delegates to chi's own `middleware.RequestID` — see "Context Key Ownership" below. |
| `Telemetry` before `Logging` | The span exists before logging runs, so log lines carry the trace id; also wraps `w` in the `statusRecorder` that `Logging` reads. |
| `CORS` before `Authenticate` | A browser's preflight `OPTIONS` request carries no `Authorization` header/cookie by design — reaching an auth-gated stage first turns every cross-origin client's preflight into a confusing 401 instead of the real CORS decision. |
| `Authenticate` before `RateLimit` | The limiter key is the authenticated subject's id; identity must be resolved first, or the key falls back to IP and punishes everyone behind one NAT. |
| `RateLimit` last before the handler | Reject excess load after every cheap check, before any real work runs. |

---

## Context Key Ownership

Every context value crossing a package boundary is owned by exactly one package, which alone defines its private key type and exposes type-safe accessors — the pattern the `context` package's own documentation recommends, since an unexported key type can only be constructed by code inside its defining package: two packages independently choosing a string key like `"tenant"` can silently overwrite or misread each other's value; two independently-typed private keys cannot.

| Value | Owner | Setter | Getter |
|---|---|---|---|
| Request/trace id | chi's own `middleware` package | `middleware.RequestID` (this skill's `RequestID` delegates to it) | `middleware.GetReqID(ctx)` |
| Authenticated Subject (incl. `TenantID` field) | `domain` (`go-domain-model`) | `domain.ContextWithSubject(ctx, sub)` | `domain.SubjectFromContext(ctx)` |

`RequestID` delegates to chi's built-in middleware — not a bespoke key — specifically because `go-chi-handler`'s `writeError` already calls `middleware.GetReqID(ctx)` to populate `ErrorResponse.TraceID`; a locally-typed key here would leave every error response's `traceId` silently empty, a cross-skill inconsistency a review would only catch by tracing both files at once:

```go
func (m Middleware) RequestID(next http.Handler) http.Handler {
    return middleware.RequestID(next) // chi's key — go-chi-handler's writeError reads it
}
```

---

## Panic Recovery: the Recoverer Standard

The `Recoverer` catches a panic at the request boundary, logs it with `debug.Stack()` **to the log only**, sets `Connection: close` (a panic can leave `w`'s write state or the goroutine's own state undefined — never return that connection to the keep-alive pool), and returns the opaque 500 through `go-chi-handler`'s own `ErrorResponse` envelope — `code: "INTERNAL"`, `message: "an unexpected error occurred"`, never the panic value or a stack trace:

```go
defer func() {
    if rec := recover(); rec != nil {
        slog.ErrorContext(r.Context(), "panic recovered", "panic", rec, "stack", string(debug.Stack()))
        w.Header().Set("Connection", "close") // before writeError — header-ordering rule
        writeError(w, r, http.StatusInternalServerError, "INTERNAL", "an unexpected error occurred")
    }
}()
```

Exact placement, the outermost-position trade-off, and the full worked function: `references/recoverer-and-response-wrapping.md`. `panic` is reserved for genuinely unrecoverable states (`go-error-handling`'s panic/recover table); business errors are values, never panics.

---

## ResponseWriter-Wrapping Standard

`Telemetry` and `Logging` both need the response status and byte count. Wrap `http.ResponseWriter` **exactly once** — in `Telemetry`, the earlier of the two — with a `statusRecorder` that defaults its captured status to what `net/http` itself defaults to (`200`, the instant `Write` runs with no prior `WriteHeader`) and guards against a second `WriteHeader` call silently overwriting an already-sent status:

```go
func (r *statusRecorder) WriteHeader(status int) {
    if r.wroteHeader { return } // second call is a no-op — matches what the client actually got
    r.status, r.wroteHeader = status, true
    r.ResponseWriter.WriteHeader(status)
}
```

Full struct, the `Write`-defaults-to-200 bug, the double-`WriteHeader` bug, and why a *second* independent wrapper silently reads back zero values instead of the first wrapper's real bookkeeping: `references/recoverer-and-response-wrapping.md`.

---

## Telemetry, CORS, Authentication, Rate Limiting

`Telemetry` starts the span and records RED metrics using the chi **route pattern**, never the raw path, as the label (raw paths carry UUIDs and explode cardinality). `CORS` answers preflight `OPTIONS` before `Authenticate` ever runs; `AllowedOrigins` is never `"*"` with `AllowCredentials: true`. `Authenticate` resolves the bearer credential and stores the whole `domain.Subject` (carrying `TenantID` as a field — never a second, independently-set tenant key) via `domain.ContextWithSubject`; health/readiness routes are mounted on a separate, unauthenticated router entirely. `RateLimit` uses a per-subject token bucket (`golang.org/x/time/rate`, default 10 req/s sustained, burst 20) with a background sweep evicting subjects idle past 5 minutes — an unbounded limiter map is the same class of slow leak `go-concurrency-patterns` names for orphan goroutines, applied to a map — and computes the exact `Retry-After` from `rate.Reservation.Delay()`, cancelling the reservation on the rejected path so a denied request doesn't drain a token it never got to spend. Full implementations of all four: `references/middleware-stage-implementations.md`.

---

## Rules

- **Recoverer wraps everything, with no exceptions.** It is the first middleware registered — not "early."
- **One concern per middleware.** Don't merge auth + logging + metrics into one function.
- **Wrap `http.ResponseWriter` exactly once per request.** Every middleware after the wrapping one reuses it via a type assertion; never wrap a second time.
- **Low-cardinality labels.** Route patterns, methods, status codes — never raw paths, ids, or user input.
- **Context keys are owned by exactly one package, with type-safe accessors.** No raw string keys; no package reads another's private key type directly.
- **The rate limiter evicts idle entries.** An unbounded `map[string]*limiterEntry` is a memory leak, not a simplification.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Correct ordering | Recoverer→RequestID→Telemetry→Logging→…→CORS→Auth→RateLimit | Any middleware ahead of Recoverer; CORS or RateLimit after Auth | Read `router.go`'s `r.Use(...)` sequence top to bottom |
| Panic isolation, boundary discipline | Exactly one `recover()` in the whole HTTP chain, at `Recoverer` | A second `recover()` in a handler or another middleware | `grep -rn "recover()" internal/handlers/http` — one hit |
| Stack trace never in the response | `debug.Stack()` reaches `slog` only; response `message` is the literal opaque sentence | Panic value or stack text in the response body | `grep -n "rec\b" internal/handlers/http/middleware.go` — only inside the `slog` call |
| Post-panic connection closed | `Connection: close` set before `writeError` | Header set after, or omitted | Read statement order in `Recoverer` |
| `ResponseWriter` wrapped once | One `*statusRecorder`, reused via type assertion by `Logging` | A second independent wrapper constructed downstream | `grep -rn "statusRecorder{" internal/handlers/http` — one construction site |
| Default status matches `net/http`'s | `Write` calls `WriteHeader(200)` when unset | `status` field left at zero value for handlers that never call `WriteHeader` | Unit test: handler calls only `Write`; assert recorded `status == 200` |
| Context keys, no collisions | `middleware.GetReqID` / `domain.SubjectFromContext` only | A local `ctxKey` reused for the subject, or a string key | `grep -rn "context.WithValue" internal/handlers/http` — none outside `Authenticate`'s call into `domain.ContextWithSubject` |
| CORS before auth | Preflight `OPTIONS` resolved outside the auth group | Preflight hitting `Authenticate` and getting 401 | Integration test: unauthenticated `OPTIONS` returns 204 |
| Rate limiter bounded | Sweep goroutine evicts idle entries | Limiter map grows unbounded for the process lifetime | Read `newLimiterStore` for the `go s.sweep(...)` call |
| Exact `Retry-After` | Computed from `Reservation.Delay()`, reservation cancelled on reject | Hardcoded value, or token spent on a rejected request | Read `RateLimit`'s reject branch for `res.Cancel()` |
| Single purpose, low cardinality | Each middleware does one thing; route pattern as label | Kitchen-sink middleware; raw path/UUID as a metric label | Read each middleware function's body for its one job |

---

## Anti-Patterns

- **Any middleware ahead of `Recoverer`** — reopens the exact crash surface panic isolation exists to close, for whatever sits ahead of it.
- **A second `recover()` inside a handler or another middleware** — hides the panic from the boundary's logging, telemetry, and response mapping. One `Recoverer` per chain.
- **Stack trace, panic value, or driver text reaching the response body** — `go-chi-handler`'s 5xx message rule exists precisely to prevent this; the 500 message is always the same opaque sentence.
- **Panic response left keep-alive eligible** — omitting `Connection: close` lets the server return a possibly framing-corrupted connection to the pool.
- **A second, independent `ResponseWriter` wrapper** — silently reads back zero values instead of the first wrapper's real bookkeeping; wrap once, reuse via assertion.
- **A `statusRecorder` that doesn't default to 200 on first `Write`** — miscounts every handler that never calls `WriteHeader` explicitly.
- **String context keys** (`context.WithValue(ctx, "tenant", …)`) — collides silently across packages; every value here uses a private key type with type-safe accessors.
- **`RequestID` minting its own context key instead of delegating to chi's `middleware.RequestID`** — breaks `go-chi-handler`'s `writeError`, which reads `middleware.GetReqID` directly; every error response's `traceId` goes silently empty.
- **CORS mounted after auth, or rate limiting before authentication** — preflight fails with a confusing 401; an IP-keyed limiter punishes a shared NAT and leaves per-user abuse uncapped.
- **An unbounded rate-limiter map with no eviction sweep** — a slow memory leak, one entry per distinct subject ever seen, for the life of the process.

---

## Output Format

Go source built exactly to the standards above, plus middleware tests (`httptest`)
written first:

```
internal/handlers/http/middleware.go        (Recoverer, RequestID, Telemetry, Logging, SecurityHeaders, CORS, Authenticate, RateLimit)
internal/handlers/http/ratelimit.go         (limiterStore, sweep, reserve)
internal/handlers/http/middleware_test.go   (written first — one case per Quality Criteria row)
```

Middleware carries no domain logic and imports no repository — a middleware test never touches a database. `domain.ContextWithSubject`/`domain.SubjectFromContext` live in `go-domain-model`, not here; this skill only calls them. Full standards: `references/recoverer-and-response-wrapping.md`, `references/middleware-stage-implementations.md`.
