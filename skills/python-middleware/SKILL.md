---
name: python-middleware
description: >
  Teaches the backend-engineer to build the Starlette/FastAPI middleware
  chain — a named, ordered, single-purpose-per-stage chain
  (RequestID → Recoverer → Telemetry → Logger → SecurityHeaders →
  Authenticate → RateLimit), registered via app.add_middleware in fixed
  order, with CORSMiddleware built into Starlette. Covers the
  add_middleware LIFO gotcha (last-added is outermost, so the chain is
  registered in reverse); why RequestID sits outside Recoverer here even
  though Go puts Recoverer outermost (Starlette's own ServerErrorMiddleware
  is the ultimate process-safety net, so the custom Recoverer only owns the
  structured opaque-500 envelope and can carry a request id); request-scoped
  state via contextvars.ContextVar instead of Go's typed private context key,
  and the weak-encapsulation honesty that entails; panic recovery via
  exception-catching middleware with the traceback logged server-side only;
  response status read straight off the returned Response (no ResponseWriter
  wrapping); and per-subject token-bucket rate limiting with its
  multiple-uvicorn-worker caveat. Full stage implementations are in
  references/middleware-chain.md; authenticate/rate-limit/CORS are in
  references/auth-ratelimit-cors.md. The Python analog of go-middleware,
  composing security-implementation and observability instrumentation into
  the chain wired by python-fastapi-handler. Used by backend-engineer during
  Implement.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, middleware, fastapi, starlette, asgi, contextvars, jwt, rate-limit, cors]
produces: python-http-middleware
domain: backend
status: stable
related: [go-middleware, python-fastapi-handler, python-service-skeleton]
---

# Python Middleware

## Purpose

Middleware handles what every request needs but no handler should repeat: correlation, panic isolation, telemetry, logging, security headers, authentication, rate limiting. Under ASGI (Starlette, and FastAPI built on it), each concern is one small single-purpose middleware, composed in a fixed order into the request pipeline so handlers stay thin and assume a well-formed, authenticated, observable request.

This is the Python analog of `go-middleware`. It composes the security controls from `security-implementation` and the instrumentation from `structured-logging-design`/observability into the chain `python-fastapi-handler` wires up. Where Python diverges honestly from Go — registration order, encapsulation, the panic boundary — the divergence is called out below, never papered over.

---

## Middleware Ordering Standard

Outermost (runs first on the way in, last on the way out) to innermost:

```
RequestID → Recoverer → Telemetry → Logger → SecurityHeaders → Authenticate → RateLimit → handler
```

| Position | Why it sits exactly here |
|---|---|
| `RequestID` outermost | Every later layer (logs, spans, the Recoverer's own 500 envelope) can reference the correlation id from here on. Unlike Go — where `Recoverer` must be outermost because nothing else catches a panic and its context therefore has *no* request id — here `RequestID` can sit outside `Recoverer`, so even a recovered panic carries a correlation id. See "Recoverer vs ServerErrorMiddleware" below. |
| `Recoverer` second | Converts any uncaught exception raised further in into the opaque structured 500. It does not need absolute-outermost position (Starlette's `ServerErrorMiddleware` is the real crash floor). |
| `Telemetry` before `Logger` | The span exists before logging runs, so log lines carry the trace id. |
| `SecurityHeaders` | Sets response headers on the way out; cheap, no dependency on identity. |
| `Authenticate` before `RateLimit` | The limiter key is the authenticated subject id; identity must resolve first, or the key falls back to client IP and punishes everyone behind one NAT. |
| `RateLimit` last before the handler | Reject excess load after every cheap check, before any real work runs. |

`CORSMiddleware` (built into Starlette) is registered too — see "CORS Is Built In".

---

## The `add_middleware` LIFO Gotcha

`app.add_middleware(cls)` **prepends** — the *last* middleware you add becomes the *outermost*. Starlette builds the stack as `[ServerErrorMiddleware] + user_middleware + [ExceptionMiddleware]` and wraps it in reverse. So to get the order above, register the chain **bottom-up (reverse)**: add `RateLimit` first, `RequestID` last. Reading the `add_middleware` calls top to bottom shows the chain *inside-out*. This is the single most common Starlette middleware bug — see the full registration block in `references/middleware-chain.md`.

One concern per middleware. Never merge auth + logging + metrics into one class.

---

## Recoverer vs Starlette's `ServerErrorMiddleware`

Go's `Recoverer` must be first because a panic anywhere unwrapped crashes the process. Python is different, and honestly so: Starlette *always* wraps the entire app in `ServerErrorMiddleware` as the true outermost layer — any uncaught exception already becomes a 500 and the server never dies. So the custom `Recoverer` here owns a narrower job: emitting the *structured* opaque-500 envelope (`code: "INTERNAL"`, the same shape `python-fastapi-handler` returns for every other error) with the traceback logged **server-side only, never in the response body**. Because that job doesn't require absolute-outermost position, `RequestID` can sit outside it — eliminating the Go trade-off where the Recoverer's own context had no request id.

Honest caveat: Starlette's registered exception handlers (`@app.exception_handler`) only wrap the **router**, not the user middleware stack — an exception raised *inside* another middleware bypasses them. That is exactly why a dedicated `Recoverer` middleware exists rather than relying on exception handlers alone. Full code: `references/middleware-chain.md`.

---

## Request-Scoped State: `contextvars.ContextVar`

Python has no `context.Context` threaded through every call and no unexported key type. Request-scoped values (the request id, the authenticated `Subject` carrying `tenant_id`) are carried across `await` boundaries by `contextvars.ContextVar`, owned by one module (`python-service-skeleton`'s domain/context module) that exposes typed `set_*`/`get_*` accessors and — critically — **`ContextVar.set` returns a `Token` that must be reset** in a `finally`, or the value leaks to the next coroutine scheduled on that task.

Honest divergence — weak encapsulation: Go's private context-key type *cannot* be constructed outside its package; the compiler enforces ownership. Python's convention (a module-level `_subject: ContextVar` behind accessors) is discipline only — nothing stops another module importing `_subject` and mutating it. State the accessor as the sole supported path; you cannot make it the sole *possible* path.

---

## Response Status: No Wrapper Needed

Go wraps `http.ResponseWriter` in a `statusRecorder` to capture the status code (and dodge two default-200 / double-`WriteHeader` bugs). Python needs none of that: `response = await call_next(request)` returns a `Response` whose `response.status_code` is a plain attribute — read it directly. Only the response **byte count** needs the streaming-body iterator wrapped, a far smaller concern; see `references/middleware-chain.md`.

Like Go, the resolved route template is only available *after* the request routes: read `request.scope["route"].path` (the low-cardinality template `/v1/data-assets/{id}`, never `request.url.path` with its embedded UUIDs) **after** `call_next` returns.

---

## CORS Is Built In

Starlette ships `CORSMiddleware` — no third-party plugin, unlike chi's hand-rolled CORS or Node's `@fastify/cors`. It answers the browser's preflight `OPTIONS` (which carries no `Authorization` by design) itself, so it must sit outside `Authenticate` or every cross-origin preflight fails with a confusing 401. `allow_origins` is never `["*"]` together with `allow_credentials=True` — the CORS spec forbids the pair and browsers reject it. Config: `references/auth-ratelimit-cors.md`.

---

## Rules

- **Register the chain in reverse.** `add_middleware` is LIFO — last added is outermost. Add `RateLimit` first, `RequestID` last.
- **One concern per middleware.** No kitchen-sink middleware.
- **The `Recoverer`'s traceback goes to the log only.** The response body is always the same opaque sentence — never the exception message or traceback.
- **Every `ContextVar.set` is paired with a `Token` reset in `finally`.** An un-reset token leaks request-scoped state across coroutines.
- **Read the route template, not the raw path, for labels.** `request.scope["route"].path` after `call_next` — never `request.url.path`.
- **The rate limiter is keyed by the authenticated subject, and evicts idle entries.** An unbounded bucket map is a memory leak.
- **`CORSMiddleware` sits outside `Authenticate`, and never pairs `allow_origins=["*"]` with `allow_credentials=True`.**

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Correct effective order | Chain resolves RequestID→…→RateLimit outermost-to-innermost | Reading `add_middleware` calls top-to-bottom as if that were the order | Trace the reversed registration; last-added is outermost |
| Registered in reverse | `RateLimit` added first, `RequestID` last | Added in reading order (RequestID first) — inverts the whole chain | Read the `add_middleware` sequence |
| Panic isolation | Exactly one exception-catching `Recoverer`; traceback to logger only | Traceback or exception text in the response body | `grep` the Recoverer — response `detail`/message is the literal opaque sentence |
| Request id survives a panic | Recovered 500 still carries a request id | Recoverer outside RequestID, so id is empty | `RequestID` is the last `add_middleware` call |
| ContextVar token reset | Every `set` has a `finally: reset(token)` | `set` with no reset | `grep` for `.set(` and confirm a matching `.reset(` |
| Status without wrapping | `response.status_code` read directly | A hand-rolled ASGI status-capturing wrapper | Read the Logger/Telemetry middleware |
| Low-cardinality label | `request.scope["route"].path` after `call_next` | `request.url.path` (raw, UUID-bearing) | `grep` for `url.path` — none as a metric/span label |
| CORS before auth | Preflight `OPTIONS` resolved outside auth | Preflight reaching `Authenticate` → 401 | `CORSMiddleware` added after `AuthenticateMiddleware` |
| Rate limiter bounded & keyed | Per-subject bucket, idle eviction | Unbounded map or IP-keyed | Read the limiter store for eviction + subject key |

---

## Anti-Patterns

- **Registering middleware in reading order** — inverts the entire chain because `add_middleware` is LIFO; the "outermost" middleware ends up innermost.
- **A traceback, exception message, or SQL fragment in the 500 response body** — `python-fastapi-handler`'s 5xx opaque-message rule exists precisely to prevent this leak.
- **Relying on `@app.exception_handler` to catch middleware panics** — those handlers wrap only the router, not the middleware stack; the `Recoverer` middleware is what catches them.
- **A module-level global instead of a `ContextVar` for tenant/trace state** — leaks state across coroutines concurrently scheduled on one event loop, a correctness bug with no Go equivalent.
- **A `ContextVar.set` with no `Token` reset** — the value survives into the next request handled by that task.
- **`request.url.path` as a metric or span label** — embeds UUIDs, explodes cardinality; use the route template.
- **`allow_origins=["*"]` with `allow_credentials=True`** — the CORS spec forbids it and browsers reject it outright.
- **An unbounded per-subject rate-limiter map with no eviction** — a slow memory leak, one entry per distinct subject ever seen.

---

## Output Format

Python source built exactly to the standards above, with middleware tests (Starlette's `TestClient`, or `httpx.AsyncClient` + `ASGITransport`) written first:

```
app/middleware/chain.py          (RequestID, Recoverer, Telemetry, Logger, SecurityHeaders)
app/middleware/auth.py           (Authenticate)
app/middleware/ratelimit.py      (RateLimit + token-bucket store)
app/middleware/register.py       (add_middleware sequence — registered in reverse)
tests/middleware/test_chain.py   (written first — one case per Quality Criteria row)
```

Middleware carries no domain logic and imports no repository — a middleware test never touches a database. The `Subject` `ContextVar` and its accessors live in `python-service-skeleton`, not here; this skill only calls them. Full standards: `references/middleware-chain.md`, `references/auth-ratelimit-cors.md`.
