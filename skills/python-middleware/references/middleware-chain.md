# Middleware Chain: Stage Implementations and Registration

Full worked implementations for the correlation/observability/safety half of the
chain — `RequestID`, `Recoverer`, `Telemetry`, `Logger`, `SecurityHeaders` — plus the
one thing that must be exactly right for the whole chain to work: the **reverse
registration order**. Authenticate, RateLimit, and CORS live in the sibling
`references/auth-ratelimit-cors.md`. Self-contained — read it without assuming
`SKILL.md`'s body is also loaded.

All examples target FastAPI on Starlette, Python 3.11+, `uvicorn` as the ASGI server.
Two middleware styles appear: subclassing `BaseHTTPMiddleware` (ergonomic, `dispatch`
receives `request` and a `call_next`) and the pure-ASGI class form (lighter, no extra
task per request). Use `BaseHTTPMiddleware` for the request/response stages here; drop
to pure-ASGI only where its overhead is measured to matter.

---

## The Context Module (owned by `python-service-skeleton`, used here)

The request id and the authenticated `Subject` are carried across `await` boundaries
by `contextvars.ContextVar`, not passed as arguments. This module owns them; every
middleware calls its accessors and never touches the raw `ContextVar`:

```python
# app/context.py  (lives in python-service-skeleton; shown here for reference)
from contextvars import ContextVar, Token
from dataclasses import dataclass
from uuid import UUID

_request_id: ContextVar[str] = ContextVar("request_id", default="")


@dataclass(frozen=True, slots=True)
class Subject:
    id: UUID
    tenant_id: UUID          # carried as a field — never a second, independent ContextVar
    scopes: frozenset[str]


_subject: ContextVar[Subject | None] = ContextVar("subject", default=None)


def set_request_id(value: str) -> Token:
    return _request_id.set(value)          # caller MUST reset the returned Token


def get_request_id() -> str:
    return _request_id.get()


def set_subject(value: Subject) -> Token:
    return _subject.set(value)


def get_subject() -> Subject | None:
    return _subject.get()


def reset(var: ContextVar, token: Token) -> None:
    var.reset(token)
```

**Weak-encapsulation honesty:** the leading underscore on `_subject` is convention, not
enforcement. Unlike Go's unexported context-key type — which the compiler makes
impossible to construct outside its package — any Python module can `from app.context
import _subject` and mutate it. The accessors are the *supported* path, not the only
*possible* one. Code review, not the language, enforces this.

---

## RequestID (outermost)

Reads an inbound `X-Request-ID` if a trusted proxy set one, else mints a UUID, binds it
to the `ContextVar`, echoes it on the response, and — non-negotiably — resets the token
in `finally` so the id never leaks into the next request handled by this task:

```python
# app/middleware/chain.py
import uuid
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.context import set_request_id, get_request_id, reset, _request_id


class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        rid = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        token = set_request_id(rid)
        try:
            response = await call_next(request)
        finally:
            reset(_request_id, token)      # pair every .set() with a reset
        response.headers["X-Request-ID"] = rid
        return response
```

Without the `reset`, `contextvars` in an `asyncio` app silently carries the last
request's id into whatever coroutine the event loop schedules next on the same task — a
correctness bug with no synchronous-framework or Go equivalent.

---

## Recoverer (second)

Catches any exception raised further in, logs it **with the traceback to the log
stream only**, and returns the identical opaque-500 envelope `python-fastapi-handler`
returns for every other unmapped error. The exception value and traceback never reach
the response body:

```python
import logging
from starlette.responses import JSONResponse

logger = logging.getLogger("app.request")


class RecovererMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        try:
            return await call_next(request)
        except Exception:                       # noqa: BLE001 — this is the boundary
            # exc_info=True sends the full traceback to the log handler, never the client.
            logger.exception("unhandled exception", extra={"request_id": get_request_id()})
            return JSONResponse(
                status_code=500,
                content={
                    "error": {
                        "code": "INTERNAL",
                        "message": "an unexpected error occurred",
                        "traceId": get_request_id(),   # populated because RequestID ran outside us
                    }
                },
            )
```

**Why this middleware exists at all, given Starlette already catches everything:**
Starlette wraps the whole app in `ServerErrorMiddleware` (the true outermost layer) and
in `ExceptionMiddleware` (innermost, around the router). `ExceptionMiddleware` is what
dispatches your registered `@app.exception_handler` handlers — but it wraps **only the
router**, so an exception raised inside another *middleware* bypasses every registered
handler and falls straight through to `ServerErrorMiddleware`, which returns a bare,
unstructured 500. The custom `RecovererMiddleware` is what guarantees a *structured*
envelope for panics anywhere in the chain, not just in endpoints. It sits *inside*
`RequestID` on purpose, so its `traceId` is always populated — the exact Go trade-off
(Go's outermost Recoverer has no request id in its own context) does not exist here.

The opaque message is the literal string `"an unexpected error occurred"`. Never
`str(exc)`, never a traceback, never a driver/SQL fragment — the same leak
`python-fastapi-handler`'s 5xx-message rule exists to prevent, closed at its source.

---

## Telemetry (before Logger)

Starts the server span and records the three RED signals (Rate, Errors, Duration) per
route using the **route template** as the label — resolved only *after* `call_next`,
exactly like chi's `RoutePattern()` being empty until `next.ServeHTTP`. Detailed
instrument design lives in the observability skill; this is the wiring:

```python
import time
from opentelemetry import trace, metrics

tracer = trace.get_tracer("app.http")
meter = metrics.get_meter("app.http")
_req_count = meter.create_counter("http.server.requests")
_req_duration = meter.create_histogram("http.server.duration", unit="s")


class TelemetryMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        start = time.perf_counter()
        with tracer.start_as_current_span(request.method) as span:
            response = await call_next(request)

            route = request.scope.get("route")
            # request.scope["route"].path is the low-cardinality template
            # "/v1/data-assets/{id}" — never request.url.path, which carries the UUID.
            template = route.path if route is not None else "unmatched"
            span.update_name(f"{request.method} {template}")

            attrs = {
                "http.request.method": request.method,
                "http.route": template,
                "http.response.status_code": response.status_code,
            }
            _req_count.add(1, attrs)
            _req_duration.record(time.perf_counter() - start, attrs)
            span.set_attribute("http.response.status_code", response.status_code)
        return response
```

`response.status_code` is a plain attribute of the returned `Response` — no
`statusRecorder`/`ResponseWriter` wrapper is needed to capture it, unlike Go. The two
bugs Go's wrapper guards against (status defaulting to 0 instead of 200; a second
`WriteHeader` silently overwriting the recorded status) simply cannot occur, because
the status is materialized on the `Response` object, not inferred from write calls.

---

## Logger (after Telemetry)

Emits one structured access-log line per request — method, route template, status,
duration, request id, tenant — reading the same `response.status_code` Telemetry read.
No wrapper; the byte count, if wanted, is the one field that *does* need the streaming
body iterator wrapped (shown minimal here):

```python
class LoggerMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        start = time.perf_counter()
        response = await call_next(request)
        route = request.scope.get("route")
        subject = get_subject()
        logger.info(
            "request completed",
            extra={
                "method": request.method,
                "route": route.path if route is not None else "unmatched",
                "status": response.status_code,
                "duration_ms": round((time.perf_counter() - start) * 1000, 2),
                "request_id": get_request_id(),
                "tenant_id": str(subject.tenant_id) if subject else None,
            },
        )
        return response
```

Structured fields go through `extra=`; the message string stays constant so log
aggregation groups on it. Use `structlog` with `structlog.contextvars.bind_contextvars`
if the product's logging config prefers it — the field set is identical.

---

## SecurityHeaders (before Authenticate)

Sets the standard hardening headers on every response, on the way out. Cheap, no
identity dependency, so it sits ahead of `Authenticate`:

```python
class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'"
        response.headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains"
        return response
```

`security-implementation` owns the rationale for each header value; this middleware is
the wiring that applies them uniformly. HSTS `max-age=63072000` is two years, the
value that qualifies a domain for browser preload lists.

---

## Registration — In Reverse (the whole point)

`app.add_middleware(cls)` **prepends** to the user-middleware list, and Starlette wraps
the assembled stack in reverse — so the **last** `add_middleware` call is the
**outermost** middleware at runtime. To get the standard order
`RequestID → Recoverer → Telemetry → Logger → SecurityHeaders → Authenticate → RateLimit`,
register it **bottom-up**:

```python
# app/middleware/register.py
from starlette.middleware.cors import CORSMiddleware
from app.middleware.chain import (
    RequestIDMiddleware, RecovererMiddleware, TelemetryMiddleware,
    LoggerMiddleware, SecurityHeadersMiddleware,
)
from app.middleware.auth import AuthenticateMiddleware
from app.middleware.ratelimit import RateLimitMiddleware


def register_middleware(app, settings) -> None:
    # Added FIRST -> innermost. Read this block bottom-to-top to see request order.
    app.add_middleware(RateLimitMiddleware, rate=10.0, burst=20)
    app.add_middleware(AuthenticateMiddleware)
    app.add_middleware(
        CORSMiddleware,                       # sits OUTSIDE Authenticate — preflight rule
        allow_origins=settings.allowed_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "Idempotency-Key"],
    )
    app.add_middleware(SecurityHeadersMiddleware)
    app.add_middleware(LoggerMiddleware)
    app.add_middleware(TelemetryMiddleware)
    app.add_middleware(RecovererMiddleware)
    app.add_middleware(RequestIDMiddleware)   # Added LAST -> outermost
```

The comment `Read this block bottom-to-top to see request order` is not decoration — it
is the mental model that keeps the chain correct. Registering these in reading order
(RequestID first) would put `RequestID` innermost and `RateLimit` outermost, inverting
the entire pipeline: requests would be rate-limited before being authenticated, and the
correlation id would be bound after every other stage had already run without it.
