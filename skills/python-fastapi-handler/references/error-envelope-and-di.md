# Error Envelope, Exception Handlers, and Dependency Injection

Companion to `python-fastapi-handler`'s SKILL.md. Covers the single error-mapping points (`@app.exception_handler(...)`), the canonical error envelope, the domain-error-to-status table, and the `Depends()` wiring for authentication and the per-request unit of work. Targets FastAPI on Starlette, Pydantic v2, `asyncpg`. The error taxonomy itself (`DomainError` and its subclasses) is owned by `python-error-handling`; this file consumes it at the transport edge.

---

## The Canonical Error Envelope

Every error response — a Pydantic 422, a raised domain error, or an uncaught 500 — serialises to exactly one shape, so a client parses one body for every failure. It matches the Go sibling's `ErrorResponse` field-for-field, in snake_case.

```python
# app/api/errors.py  (envelope portion)
from pydantic import BaseModel


class FieldError(BaseModel):
    field: str          # dotted path, e.g. "justification" or "body.reviewed_by"
    message: str        # human-readable, safe to show


class ErrorEnvelope(BaseModel):
    code: str                       # machine-matchable, SCREAMING_SNAKE_CASE
    message: str                    # human-readable; opaque sentence for 5xx
    fields: list[FieldError] = []   # populated ONLY for structural (422) validation
    trace_id: str                   # correlates to the middleware span / structured log
```

- `code` is SCREAMING_SNAKE_CASE and stable — clients branch on it, never on the message string.
- `fields` is populated **only** for structural validation (the 422), and lists every failure at once.
- `trace_id` is read from the `contextvars.ContextVar` the middleware sets per request (`python-middleware`), never hardcoded and never read from a module global.

The opaque 5xx sentence is a single module constant, reused everywhere:

```python
OPAQUE_5XX_MESSAGE = "An unexpected error occurred. If it persists, contact support with the trace id."
```

---

## Domain-Error-Category → HTTP Status (canonical table)

Handlers `raise` typed exceptions and never touch a status code. The single `DomainError` handler maps category to status through this one table — the direct analog of Go's `writeDomainError` switch. Each exception type is a subclass of `DomainError` defined in `python-error-handling`.

| Exception type (subclass of `DomainError`) | HTTP status | `code` | Message specificity |
|---|---|---|---|
| `ValidationError` (domain-level, not Pydantic) | 400 Bad Request | `DOMAIN_VALIDATION_FAILED` | Specific — describes the client's request |
| `AuthenticationError` | 401 Unauthorized | `UNAUTHENTICATED` | Specific but generic ("missing or invalid credentials") |
| `PermissionDeniedError` | 403 Forbidden | `PERMISSION_DENIED` | Specific — names the action, never the resource internals |
| `NotFoundError` | 404 Not Found | `NOT_FOUND` | Specific — the resource kind |
| `ConflictError` | 409 Conflict | `CONFLICT` | Specific — the invariant violated |
| `PreconditionFailedError` | 412 Precondition Failed | `PRECONDITION_FAILED` | Specific — the failed precondition (e.g. stale `If-Match`) |
| `RateLimitedError` | 429 Too Many Requests | `RATE_LIMITED` | Specific — retry-after guidance |
| any uncaught `Exception` | 500 Internal Server Error | `INTERNAL` | **Always the opaque sentence** |

**The message-content rule is absolute:** 4xx messages may be specific because they describe the client's own request; 5xx messages are always `OPAQUE_5XX_MESSAGE`. Internals — SQL, tracebacks, `asyncpg` driver strings like `UniqueViolationError`, file paths — go to the structured log with the trace id, never the response body.

---

## The Single Exception-Handler Registration

Three handlers, registered once in `register_exception_handlers(app)`. Together they are the *only* places a status code is chosen — no handler body ever constructs one.

```python
# app/api/errors.py  (handlers portion)
import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.application.errors import (          # taxonomy owned by python-error-handling
    AuthenticationError,
    ConflictError,
    DomainError,
    NotFoundError,
    PermissionDeniedError,
    PreconditionFailedError,
    RateLimitedError,
    ValidationError as DomainValidationError,
)
from app.observability.context import current_trace_id   # reads the ContextVar

logger = logging.getLogger(__name__)

_STATUS_BY_TYPE: list[tuple[type[DomainError], int, str]] = [
    (DomainValidationError, 400, "DOMAIN_VALIDATION_FAILED"),
    (AuthenticationError, 401, "UNAUTHENTICATED"),
    (PermissionDeniedError, 403, "PERMISSION_DENIED"),
    (NotFoundError, 404, "NOT_FOUND"),
    (ConflictError, 409, "CONFLICT"),
    (PreconditionFailedError, 412, "PRECONDITION_FAILED"),
    (RateLimitedError, 429, "RATE_LIMITED"),
]


def register_exception_handlers(app: FastAPI) -> None:

    @app.exception_handler(DomainError)
    async def handle_domain_error(request: Request, exc: DomainError) -> JSONResponse:
        # ONE mapping point for every domain error — the writeDomainError analog.
        for exc_type, status, code in _STATUS_BY_TYPE:
            if isinstance(exc, exc_type):
                return JSONResponse(
                    status_code=status,
                    content=ErrorEnvelope(
                        code=code,
                        message=str(exc),          # safe: 4xx messages describe the request
                        trace_id=current_trace_id(),
                    ).model_dump(),
                )
        # A DomainError subclass with no mapping is a programming error -> opaque 500.
        logger.error("unmapped DomainError %s: %s", type(exc).__name__, exc,
                     extra={"trace_id": current_trace_id()})
        return _opaque_500()

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(request: Request, exc: RequestValidationError) -> JSONResponse:
        # Reshape FastAPI's DEFAULT 422 body into the ONE envelope, so the client
        # never sees two error shapes.
        fields = [
            FieldError(field=".".join(str(p) for p in e["loc"][1:]), message=e["msg"])
            for e in exc.errors()
        ]
        return JSONResponse(
            status_code=422,
            content=ErrorEnvelope(
                code="VALIDATION_FAILED",
                message="The request failed structural validation.",
                fields=fields,
                trace_id=current_trace_id(),
            ).model_dump(),
        )

    @app.exception_handler(Exception)
    async def handle_uncaught(request: Request, exc: Exception) -> JSONResponse:
        # Transport-edge analog of Go's panic/recover boundary: any uncaught error
        # becomes an OPAQUE 500. The internals go to the log, never the body.
        logger.exception("uncaught exception", extra={"trace_id": current_trace_id()})
        return _opaque_500()


def _opaque_500() -> JSONResponse:
    return JSONResponse(
        status_code=500,
        content=ErrorEnvelope(
            code="INTERNAL", message=OPAQUE_5XX_MESSAGE, trace_id=current_trace_id()
        ).model_dump(),
    )
```

Two honest FastAPI-specific notes:
- Registering a handler for the base `Exception` catches everything *except* what Starlette handles before it (e.g. a raw `HTTPException` you should not be raising anyway — handlers raise `DomainError`, not `HTTPException`).
- Ordering by `isinstance` down `_STATUS_BY_TYPE` means a subclass must appear before its parent in the list if it needs a different status; keep the list most-specific-first.

---

## Dependency Injection: `Depends()` for Auth and Unit of Work

`Depends()` is the analog of Go's constructor-injected ports. Providers are resolved once per request, typed, and explicit — never looked up ad hoc inside a handler body.

### Authentication provider — yields an authenticated `Subject`

```python
# app/api/dependencies.py
from dataclasses import dataclass
from uuid import UUID

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.application.errors import AuthenticationError
from app.security.jwt import decode_and_verify   # python-error-handling / security skill owns crypto

_bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class Subject:
    subject_id: UUID
    tenant_id: UUID
    scopes: frozenset[str]


async def require_subject(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> Subject:
    if creds is None:
        raise AuthenticationError("missing bearer credentials")   # -> 401 via the ONE handler
    claims = decode_and_verify(creds.credentials)                 # raises AuthenticationError on bad token
    return Subject(
        subject_id=UUID(claims["sub"]),
        tenant_id=UUID(claims["tenant_id"]),
        scopes=frozenset(claims.get("scopes", [])),
    )
```

This layer does **authentication** only — proving who the caller is. **Authorisation** (may this subject act on this specific aggregate) is a domain decision made in `python-service-layer`'s authorise-before-mutate step, not here. Raising `AuthenticationError`/`PermissionDeniedError` from a dependency is fine — it propagates to the single `DomainError` handler exactly like one raised in a handler body.

### Unit-of-work provider — the `async def ... yield` dependency

A yield-dependency is the analog of a `defer`-closed transaction: setup before `yield`, guaranteed teardown after, even on exception.

```python
# app/api/dependencies.py (continued)
from typing import AsyncIterator

from app.application.unit_of_work import UnitOfWork   # wraps repositories + the outbox


async def get_uow(request: Request) -> AsyncIterator[UnitOfWork]:
    pool = request.app.state.pool          # the per-tenant physically-isolated pool from lifespan
    async with pool.acquire() as conn:     # asyncpg connection from the pool
        async with conn.transaction():     # one DB transaction per request
            uow = UnitOfWork(conn)
            yield uow                       # handler runs here; on ANY exception the
            #                                 transaction rolls back and the connection
            #                                 returns to the pool — the defer-close analog.
```

Because `get_uow` opens the transaction and the outbox write happens inside it (`python-service-layer`'s Transactional Outbox), a raised `DomainError` rolls the whole request back atomically before the exception handler ever formats the envelope. The connection is always returned to the pool by the `async with` blocks — there is no leak path on the error branch.

### Why not construct the pool in the handler

A handler that calls `asyncpg.create_pool(...)` or `asyncpg.connect(...)` inline rebuilds infrastructure per request, bypasses the lifespan-managed pool, and makes the handler untestable in isolation. The pool is built once in `lifespan`; handlers receive a connection through `get_uow`. This is the exact discipline `go-chi-handler` states as "the router never constructs a pool" — enforced here through `Depends()` instead of a composition-root constructor call.
