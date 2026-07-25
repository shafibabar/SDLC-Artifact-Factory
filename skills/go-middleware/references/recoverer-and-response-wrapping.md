# Recoverer and ResponseWriter Wrapping

Full standard referenced from `SKILL.md`'s "Panic Recovery" and "ResponseWriter
Wrapping Standard" sections: the exact `recover()` placement, why `Recoverer` sits
outermost despite a real trade-off that position entails, the canonical
`statusRecorder` wrapper, the two concrete bugs a naive version of it produces, and
the exact 500 response shape. Self-contained — read it without assuming `SKILL.md`'s
body is also loaded.

---

## Why Recoverer Is Outermost, and What That Costs

`go-error-handling`'s panic/recover discipline states that `recover` lives only at
runtime boundaries — "The HTTP `Recoverer` middleware (one per chain — see
`go-middleware`)" — and that a panic must degrade one request, never crash the
process. That guarantee is only unconditional if `Recoverer` wraps **every**
subsequent middleware, not just the handler: a panic inside `RequestID`, `Telemetry`,
`Logging`, `CORS`, `Authenticate`, or `RateLimit` is exactly as fatal to the process as
one inside the handler if nothing wraps it. `Recoverer` is therefore the first
middleware registered, full stop — not "early," first.

This has one deliberate, named cost. Each middleware's `next.ServeHTTP(w,
r.WithContext(ctx))` call constructs a *new* `*http.Request` for the inner call only —
it does not mutate the caller's own `r`. `Recoverer`'s deferred closure was bound to
its own `r` parameter at the moment `Recoverer.ServeHTTP` was invoked — before
`RequestID` (or anything else) has run — and that binding never changes, no matter how
deep in the chain the panic actually occurs. **`Recoverer`'s own `r.Context()` never
carries a request id, trace id, or subject set by any middleware inside it.** This is
not a bug to fix by moving `Recoverer` inward; it is the fixed price of unconditional
coverage, and it is why `go-chi-handler`'s `ErrorResponse.TraceID` field is
`json:"traceId,omitempty"` — optional by design, because a panic recovered before
`RequestID` has run legitimately has none to report.

---

## The Recoverer: Exact `recover()` Placement

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
                // write to w — undefined. Force this connection closed rather than
                // returned to the keep-alive pool, where the next request on it
                // could read a framing-corrupted response (Edwards, Let's Go
                // Further). Must be set before writeError's WriteHeader call.
                w.Header().Set("Connection", "close")
                writeError(w, r, http.StatusInternalServerError, "INTERNAL",
                    "an unexpected error occurred")
            }
        }()
        next.ServeHTTP(w, r)
    })
}
```

Four rules this code encodes exactly, each a defect if violated:

1. **`defer` is the first statement in the returned `http.HandlerFunc`**, registered
   before `next.ServeHTTP` runs — a `defer` placed after would never execute on a
   panic, since the panic unwinds past it before it's ever registered.
2. **`recover()` is called only inside that one deferred func.** A second `recover()`
   anywhere else in the chain (a handler, another middleware) intercepts the panic
   before it reaches this boundary, hiding it from this logging/telemetry/response
   path entirely — see `go-error-handling`'s "recover only at boundaries" rule.
3. **The stack trace goes to `slog` via `debug.Stack()`, never into the response.**
   `writeError`'s `message` argument is the literal string `"an unexpected error
   occurred"` — not `rec`, not `err.Error()`, not anything derived from the panic
   value. This is `go-chi-handler`'s own 5xx message-content rule ("5xx messages are
   always the same opaque sentence") applied at its one source: a stack trace, SQL
   fragment, or driver string reaching a client is exactly the leak that rule exists
   to prevent.
4. **`Connection: close` is set before `writeError` runs**, because `writeError`
   internally calls `w.Header().Set(...)` then `w.WriteHeader(...)` — and per
   `go-chi-handler`'s header-ordering rule, any header set after `WriteHeader` is
   silently discarded. Setting it after `writeError` returns would be a no-op with no
   error, no warning — just a keep-alive connection returned to the pool anyway.

---

## The 500 Response Is go-chi-handler's `ErrorResponse` — Not a Second Shape

`writeError(w, r, http.StatusInternalServerError, "INTERNAL", "an unexpected error
occurred")` calls the identical function `go-chi-handler`'s handlers call for every
other error — same envelope, same `code`, same category:

```json
{
  "error": {
    "code": "INTERNAL",
    "message": "an unexpected error occurred",
    "traceId": "4b8f1e2a-9c3d-4a11-8e77-2f6a1d0c9b44"
  }
}
```

This is exactly `go-chi-handler`'s domain-error-category table's "Unmapped /
unexpected error → 500 → `INTERNAL`" row — a recovered panic is, from the client's
side, indistinguishable from any other unmapped 500, and the envelope must not
distinguish them either. `traceId` is populated when `Recoverer` has one (i.e., when
the panic occurred after `RequestID` ran) and empty otherwise, per the trade-off
above — never a second, bespoke "panic error" shape.

---

## The `statusRecorder`: ResponseWriter-Wrapping Standard

`Telemetry` needs the response status for its RED metrics; `Logging` needs status and
bytes written for its access-log line. Both read the **same** wrapper — wrapped
exactly once, by whichever middleware sits first among the two (`Telemetry`, since it
is positioned ahead of `Logging` in the ordering standard):

```go
type statusRecorder struct {
    http.ResponseWriter
    status      int
    bytes       int
    wroteHeader bool
}

func (r *statusRecorder) WriteHeader(status int) {
    if r.wroteHeader {
        return // guard — see "Bug 2" below
    }
    r.status = status
    r.wroteHeader = true
    r.ResponseWriter.WriteHeader(status)
}

func (r *statusRecorder) Write(b []byte) (int, error) {
    if !r.wroteHeader {
        r.WriteHeader(http.StatusOK) // see "Bug 1" below
    }
    n, err := r.ResponseWriter.Write(b)
    r.bytes += n
    return n, err
}
```

### Bug 1: never calling `WriteHeader` at all

A handler that never calls `w.WriteHeader` explicitly and just calls `w.Write(body)`
is completely normal Go — `net/http`'s real `ResponseWriter` defaults to `200` the
instant `Write` runs without a prior `WriteHeader`. A naive wrapper that only
overrides `WriteHeader` and initializes `status` to the zero value (`0`) will log
`status=0` for every such handler — every `writeJSON` success path, in fact, since
`go-chi-handler`'s own `writeJSON` **does** call `WriteHeader` explicitly, but any
`http.Handler` that doesn't is silently miscounted. The fix above is `Write`
delegating to `WriteHeader(http.StatusOK)` when `wroteHeader` is still false, so the
recorder's default matches `net/http`'s own default exactly, for the same reason.

### Bug 2: `WriteHeader` called more than once

If `WriteHeader` is called a second time — a genuine handler bug, or `writeError`
called after a partial success write — a naive wrapper re-assigns `status` to the
*second* value and calls the embedded `ResponseWriter.WriteHeader` a second time. The
real `net/http` response already committed the first status to the wire; the second
call cannot change what the client receives, but it does log
`http: superfluous response.WriteHeader call` **and**, without the `wroteHeader`
guard, silently overwrites the recorded `status` with a value that was never actually
sent — an access-log line and a real response that disagree about what status the
client got. The `wroteHeader` guard makes the second call a no-op on both fronts:
first call wins, exactly matching what the client actually receives on the wire.

### Wrap exactly once

`Telemetry` constructs the `*statusRecorder` and passes it to `next.ServeHTTP` as `w`;
`Logging`, mounted directly inside it, receives that same pointer as its own `w`
parameter and reads it back with a type assertion (`rec, ok :=
w.(*statusRecorder)`) rather than constructing a second wrapper. A second, independent
`statusRecorder` wrapping the first would only ever see whatever the *first* wrapper's
`Write`/`WriteHeader` methods do to satisfy `http.ResponseWriter` — its own `status`
and `bytes` fields would silently read back the zero values the outer handler never
touched directly, since the actual write lands on the inner wrapper, not on the outer
one's own bookkeeping.
