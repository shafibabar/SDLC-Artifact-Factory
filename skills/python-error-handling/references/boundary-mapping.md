# The Single Transport-Edge Handler — Mapping, Envelope, and Logging

Reference for `python-error-handling`. The `SKILL.md` body states the "catch once at the edge", "never leak a traceback", and "log once" rules; this file is the full handler code, the exception-kind → HTTP-status table, the error-envelope shape, and the structured-logging discipline.

All code targets Python 3.11+, FastAPI (on Starlette), `asyncpg`, the `DataAsset` bounded context, per-tenant physical isolation.

---

## 1. Why exactly one handler

Domain and service code raises `DomainError` subclasses deep and catches nothing it cannot resolve. There is **one** place that catches the family and turns it into an HTTP response: a FastAPI exception handler registered on the app. This is the Python analog of Go's `writeDomainError` seam sitting behind the `Recoverer` middleware — the route handlers build **no** error responses themselves; they only raise (or let a raise propagate) and return success payloads.

Two handlers are registered, in this precedence:

1. `@app.exception_handler(DomainError)` — the whole business-error family, each kind mapped to a specific status.
2. `@app.exception_handler(Exception)` — the catch-all for anything unexpected (a bug, an untranslated infrastructure error), producing an opaque 500. This is the traceback firewall.

FastAPI dispatches to the **most specific** registered handler, so a `NotFoundError` hits handler (1), a `KeyError` bug hits handler (2).

---

## 2. The exception-kind → HTTP-status mapping

A single dict is the source of truth. `OptimisticConcurrencyError` is a subclass of `ConflictError`, so a plain `type(exc)` lookup would miss it — the resolver walks the MRO (method resolution order) so a subclass inherits its parent's status unless it declares its own.

```python
# src/app/exception_handlers.py
from http import HTTPStatus

from data_asset.domain.errors import (
    AuthorizationError,
    ConflictError,
    DomainError,
    NotFoundError,
    OptimisticConcurrencyError,
    ValidationError,
)

# Exception kind -> (HTTP status, stable machine-readable error code).
_STATUS_MAP: dict[type[DomainError], tuple[int, str]] = {
    NotFoundError: (HTTPStatus.NOT_FOUND, "not_found"),                       # 404
    ValidationError: (HTTPStatus.UNPROCESSABLE_ENTITY, "invalid"),           # 422
    ConflictError: (HTTPStatus.CONFLICT, "conflict"),                        # 409
    OptimisticConcurrencyError: (HTTPStatus.CONFLICT, "version_conflict"),   # 409
    AuthorizationError: (HTTPStatus.FORBIDDEN, "forbidden"),                 # 403
}
_DEFAULT = (HTTPStatus.BAD_REQUEST, "domain_error")                          # 400


def resolve_status(exc: DomainError) -> tuple[int, str]:
    """Walk the type's MRO so a DomainError subclass inherits the nearest
    registered status. OptimisticConcurrencyError, if it were removed from
    the map above, would still resolve to ConflictError's 409 this way.
    """
    for klass in type(exc).__mro__:
        if klass in _STATUS_MAP:
            return _STATUS_MAP[klass]
    return _DEFAULT
```

### The full table

| Exception kind | HTTP status | Envelope `code` |
|---|---|---|
| `NotFoundError` | 404 Not Found | `not_found` |
| `ValidationError` (domain) | 422 Unprocessable Entity | `invalid` |
| `ConflictError` | 409 Conflict | `conflict` |
| `OptimisticConcurrencyError` | 409 Conflict | `version_conflict` |
| `AuthorizationError` | 403 Forbidden | `forbidden` |
| any other `DomainError` | 400 Bad Request | `domain_error` |
| any non-`DomainError` (bug / untranslated infra) | 500 Internal Server Error | `internal` |

Note the domain `ValidationError` maps to **422**, the same status FastAPI itself returns for a Pydantic request-shape failure — deliberate, because both are "well-formed transport, unacceptable content"; the difference (shape vs. invariant) is an internal concern, not something the client needs a distinct status for.

---

## 3. The error envelope

Every error response — 4xx and 5xx alike — uses one shape, so clients parse errors uniformly. It carries a machine-readable `code`, a safe human `message`, and a `trace_id` that correlates the response with exactly one server log line.

```json
{
  "error": {
    "code": "not_found",
    "message": "data asset 7f3e-... not found",
    "trace_id": "b7ad1c9e2f5a4d18"
  }
}
```

The envelope **never** contains: a stack trace, `__cause__` details, SQL text, a connection string, a file path, an internal variable value, a secret, a token, or PII. For a `DomainError` the `message` is the exception's own (author-controlled, safe) message; for the 500 catch-all the `message` is a fixed constant, never `str(exc)`.

---

## 4. The `DomainError` handler

```python
# src/app/exception_handlers.py (continued)
import logging

from fastapi import Request
from fastapi.responses import JSONResponse

from app.context import trace_id_var  # a contextvars.ContextVar[str]

logger = logging.getLogger("data_asset")


def _envelope(code: str, message: str, trace_id: str) -> dict:
    return {"error": {"code": code, "message": message, "trace_id": trace_id}}


async def handle_domain_error(request: Request, exc: DomainError) -> JSONResponse:
    status, code = resolve_status(exc)
    trace_id = trace_id_var.get()
    # Log ONCE, here, with structured context pulled from the exception's
    # attributes and the request-scoped ContextVar. Never PII/secrets.
    logger.warning(
        "domain error",
        extra={
            "code": code,
            "status": status,
            "trace_id": trace_id,
            "tenant_id": getattr(exc, "tenant_id", None),
            "asset_id": getattr(exc, "asset_id", None),
            "path": request.url.path,
        },
    )
    return JSONResponse(
        status_code=status,
        content=_envelope(code, str(exc), trace_id),
    )
```

`logger.warning` (not `.exception`) is used for the `DomainError` family: these are *expected* failures with no traceback worth recording — the structured `extra` fields are the whole diagnostic. Reserve `logger.exception` (which attaches the traceback) for the catch-all below.

---

## 5. The catch-all handler — the traceback firewall

```python
# src/app/exception_handlers.py (continued)
async def handle_unexpected(request: Request, exc: Exception) -> JSONResponse:
    trace_id = trace_id_var.get()
    # The ONE place the full traceback is recorded — server-side only.
    # logger.exception attaches exc + its __cause__ chain to the log record.
    logger.exception(
        "unhandled exception",
        extra={"trace_id": trace_id, "path": request.url.path},
    )
    # Fixed message — NEVER str(exc), which could carry SQL, a path, or PII.
    return JSONResponse(
        status_code=500,
        content=_envelope("internal", "internal server error", trace_id),
    )


def register_exception_handlers(app) -> None:
    app.add_exception_handler(DomainError, handle_domain_error)
    app.add_exception_handler(Exception, handle_unexpected)
```

### `debug=False` in production is mandatory

Starlette's `ServerErrorMiddleware` will render a full HTML traceback page to the client when the app is constructed with `debug=True`. That is a development affordance and a data-leak in production. Construct the app with `debug=False` (the default) so the catch-all handler above owns every 500:

```python
app = FastAPI(debug=False)  # never True outside local dev
register_exception_handlers(app)
```

The traceback goes to the log (via `logger.exception`), never to the wire.

---

## 6. Log once — the `log-and-re-raise` anti-pattern

The Python form of "log-and-return duplication" is **log-and-re-raise**: catching at every layer, logging, and re-raising, so one failure produces N near-identical log lines.

```python
# WRONG — every layer logs the same failure.
class Service:
    async def classify(self, asset_id: str, tenant_id: str) -> None:
        try:
            asset = await self._repo.get(asset_id, tenant_id)
        except NotFoundError:
            logger.warning("asset not found in service")  # duplicate log #1
            raise
        ...

class Repository:
    async def get(self, asset_id, tenant_id):
        ...
        logger.warning("asset not found in repo")          # duplicate log #2
        raise NotFoundError(asset_id, tenant_id)
```

One request, two log lines for one fact — and the boundary handler will add a third. Correct: raise deep, log nowhere in between, and let the **single boundary handler** emit exactly one structured line:

```python
# RIGHT — deep code only raises; no logging on the way up.
class Repository:
    async def get(self, asset_id, tenant_id):
        row = await self._fetch(asset_id, tenant_id)
        if row is None:
            raise NotFoundError(asset_id, tenant_id)   # no log here
        return _hydrate(row)

class Service:
    async def classify(self, asset_id, tenant_id):
        asset = await self._repo.get(asset_id, tenant_id)  # no try/except
        asset.classify()
        await self._repo.save(asset, tenant_id)
        # If get() raised NotFoundError, it propagates untouched to the
        # boundary handler, which logs it once with full context.
```

### Context from a `ContextVar`, never PII

`tenant_id` and `trace_id` are request-scoped. Carry them in a `contextvars.ContextVar` (set by middleware at request entry), not a module global — a module global leaks across concurrently-scheduled coroutines on the same event loop, a correctness bug with no Go equivalent (Go's `context.Context` is passed explicitly). The handler reads `trace_id_var.get()`; it never logs the request body, a `Subject`'s email, an access token, a document's contents, or a database DSN.

| Log this | Never log this |
|---|---|
| `trace_id`, `tenant_id`, `asset_id`, error `code`, HTTP status, request path | Access tokens / API keys, passwords, connection strings (DSNs), request/response bodies, document contents, a Subject's email or name, any PII |

---

## 7. Testing the boundary (per `python-integration-test`)

Drive a real request through the ASGI app with `httpx.AsyncClient` and assert on the **status and envelope**, confirming no leakage:

```python
import httpx
import pytest
from httpx import ASGITransport


@pytest.mark.asyncio
async def test_missing_asset_returns_404_envelope(app):
    transport = ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://t") as client:
        resp = await client.get("/data-assets/does-not-exist")
    assert resp.status_code == 404
    body = resp.json()
    assert body["error"]["code"] == "not_found"
    assert "trace_id" in body["error"]


@pytest.mark.asyncio
async def test_unexpected_error_is_opaque_500(app, break_the_repo):
    # break_the_repo forces a bug (e.g. a KeyError) inside the handler path.
    transport = ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://t") as client:
        resp = await client.get("/data-assets/anything")
    assert resp.status_code == 500
    body = resp.json()
    assert body["error"] == {
        "code": "internal",
        "message": "internal server error",
        "trace_id": body["error"]["trace_id"],
    }
    # The firewall held: no traceback, no exception text on the wire.
    assert "Traceback" not in resp.text
    assert "KeyError" not in resp.text
```
