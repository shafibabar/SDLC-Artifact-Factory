---
name: python-fastapi-handler
description: >
  Teaches the backend-engineer to write FastAPI route handlers — thin handlers
  with Pydantic request/response models doing structural validation at the
  framework layer (stronger than hand-written validate), decode→call-service→encode,
  and a single @app.exception_handler(DomainError) as the one error-mapping point.
  The Python analog of go-chi-handler.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, fastapi, pydantic, asyncpg, handler, dto, validation, error-mapping, async]
produces: python-http-handler
domain: backend
status: stable
related: [go-chi-handler, python-middleware, python-error-handling, python-openapi-codegen]
---

# Python FastAPI Handler

## Purpose

The FastAPI route handler is the transport edge — the async equivalent of `go-chi-handler`'s job: translate between HTTP and the application layer, and nothing else. It decodes the request, lets the framework validate its structure, calls the relevant command/query handler (`await`ed), and encodes the result — or maps the error through one central point. It contains no business logic and no persistence. Boring transport code is correct transport code.

This is Robert C. Martin's Humble Object pattern at the HTTP boundary, exactly as in the Go sibling: the handler is thin and is *not* unit-tested in isolation for business behaviour — it is verified via `httpx.AsyncClient` / Starlette `TestClient` request/response round trips. The business decisions it delegates to are unit-tested one layer in, in `python-service-layer`'s command/query handlers and `python-domain-model`'s Aggregates. This skill owns the `async def` handler body itself; the error taxonomy is `python-error-handling`'s and the middleware chain around the handler is `python-middleware`'s.

**Where Python is genuinely stronger than Go here:** FastAPI validates `path`/`query`/`body` against declared Pydantic models *before the handler body runs at all*, returning a structured 422 with per-field errors automatically. That is a strictly stronger position than chi's hand-written `validate()` method — you do not write the structural validator, you declare it as types. **Where Python is honestly weaker:** those type hints are runtime-erased for internal domain code; only the request/response boundary is validated by Pydantic. `mypy` (or `pyright`) as a CI-breaking gate is non-negotiable — without it a `python-*` service has a materially weaker static-safety story than the compiler-checked Go baseline. And FastAPI is **code-first-to-spec**: the OpenAPI schema is generated *from* your models, the reverse of Go's spec-first `oapi-codegen` — see `python-openapi-codegen` for the process consequence.

---

## Route Registration Conventions

Routes mirror the OpenAPI contract path-for-path — a route present in one but not the other is contract drift, not a style choice. FastAPI reverses the generation direction (the schema is derived from the routes), so the discipline becomes: author/approve the contract first, then treat FastAPI's generated schema as a conformance check against it (`python-openapi-codegen`). Resource paths are plural nouns (`/v1/data-assets`); HTTP methods map to intent (`GET` read, `POST` create, `PATCH` partial update, `DELETE` remove — `PUT` full-replace only where the contract models one); sub-actions are nested path segments (`/{asset_id}/classification`), never verbs.

Routes live on an `APIRouter` grouped by resource, wired into the app in the composition root (`python-service-skeleton`'s `lifespan`) — the router never constructs a pool or a repository; those arrive via `Depends()`. Health/readiness routes mount on a separate router with no auth dependency, never under the authenticated `/v1` group. Mutation routes read an optional `Idempotency-Key` header and forward it unexamined to the command — the dedupe store is `python-service-layer`'s concern.

Full worked router + routes: `references/handlers-and-validation.md`.

---

## Handler Shape: Decode → Call → Encode

Every handler is `async def` and follows the same three visible steps — decode is mostly the framework's job, not yours:

1. **Declare** the request as typed parameters — a Pydantic `BaseModel` for the body, `Path(...)`/`Query(...)` for path/query. FastAPI parses, size-limits, type-checks, and rejects unknown fields *before your body runs* (given `model_config = ConfigDict(extra="forbid")`). A malformed request never reaches line one of your handler.
2. **Call** the application layer with `await`, passing the tenant/trace context carried on `contextvars.ContextVar` (never a module global — that leaks state across concurrently-scheduled coroutines; see `python-service-layer`).
3. **Return** a Pydantic response model named on the route via `response_model=...`; FastAPI serialises it and enforces the response shape. A `201`/`204` uses `status_code=...` on the decorator.

The `classify_data_asset` mutation is the canonical worked example — declare `ClassifyRequest`, `await uow.classify.handle(...)`, return `204`. Any raised `DomainError` is mapped by the single exception handler, never caught inline. Full code: `references/handlers-and-validation.md`.

---

## Structural Validation at the Framework Boundary

Structural validation — types, formats, required fields, enum membership, ranges — is expressed as Pydantic model fields and `Field(...)` constraints, and runs before the handler body. You do not hand-roll a `validate()` method; you declare `extra="forbid"` (the analog of chi's `DisallowUnknownFields`), `Field(gt=0, max_length=...)`, `enum` types, and `EmailStr`/`constr`/`conint` where they fit. FastAPI returns all violations at once as a 422 with a per-field list.

The boundary rule is identical to Go's: the instant answering a question needs the aggregate's current state, another aggregate, or the caller's permissions, it is **domain** validation and belongs to the Aggregate (`python-domain-model`) — never a repository call inside a Pydantic `@field_validator` "just to check." A validator that opens a connection has quietly become domain logic in the wrong layer. Full boundary table and the 422-vs-domain-error contrast: `references/handlers-and-validation.md`.

---

## The Single Error-Mapping Point

Every domain error maps to HTTP status through exactly one `@app.exception_handler(DomainError)` — the direct analog of Go's `writeDomainError` switch. Handlers `raise` typed exceptions (`NotFoundError`, `ConflictError`, `PermissionDeniedError` — all subclasses of `DomainError` from `python-error-handling`) and never touch a status code. The registered handler inspects the exception type, maps it to the status, and writes the one canonical error envelope: `code` (SCREAMING_SNAKE_CASE), `message`, `fields` (structural only), `trace_id` (read from the `ContextVar`). FastAPI's own `RequestValidationError` (the 422) gets a second registered handler that reshapes FastAPI's default body into the *same* envelope, so a client parses one shape for every error.

The message-content rule is absolute and identical to the sibling: **4xx messages may be specific — they describe the client's own request — 5xx messages are always the same opaque sentence.** Internals (SQL, tracebacks, `asyncpg` driver strings) go to the structured log with the trace id, never the response body. A catch-all `Exception` handler converts any uncaught error to an opaque 500 — the transport-edge analog of Go's panic/recover boundary. Full envelope, status table, and both handler implementations: `references/error-envelope-and-di.md`.

---

## Dependency Injection for Auth and Unit of Work

Ports arrive through FastAPI's `Depends()` — the analog of Go's constructor-injected ports and composition root. A handler declares `subject: Subject = Depends(require_subject)` and `uow: UnitOfWork = Depends(get_uow)`; the provider functions extract-and-verify the JWT (yielding an authenticated `Subject`, or raising `PermissionDeniedError` mapped by the exception handler) and open/close a per-request unit of work via an `async def ... yield` dependency (the analog of a `defer`-closed transaction). Dependencies are typed, explicit, and resolved once per request — never looked up ad hoc inside the body. Auth is *authentication* only at this layer; *authorisation* (can this subject act on this aggregate) is a domain decision in `python-service-layer`. Full `Depends()` patterns, the yield-dependency UoW, and auth provider: `references/error-envelope-and-di.md`.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Thin handler | Declare/call/return only | Business logic, SQL, or event publish inline | Read the `async def` body; anything past the three steps is a defect |
| Route/contract parity | Every route matches an OpenAPI path+method | A route with no contract entry, or vice versa | Diff `APIRouter` routes against the approved `openapi.yaml` |
| Unknown fields rejected | `ConfigDict(extra="forbid")` on request models | Model silently drops stray/typo'd fields | Grep request models for `extra="forbid"` |
| Framework validates first | Body typed as a Pydantic model / `Path`/`Query` | Handler reads `Request` and parses JSON by hand | No `await request.json()` in a handler that has a typed model |
| Response shape enforced | `response_model=` on every route | Bare `dict`/`JSONResponse` returned untyped | Read the route decorators |
| Single error mapping | One `@app.exception_handler(DomainError)` + one for `RequestValidationError` | `HTTPException(status_code=...)` scattered per handler | `grep -rn "HTTPException\|status_code=4\|status_code=5"` — only in mapping points |
| One envelope | Every error is the one envelope shape (incl. reshaped 422) | FastAPI's default 422 body leaks through unreshaped | Induce a 422 in a test; assert the canonical keys |
| No leaked internals | 5xx `message` is always the opaque sentence | Traceback/`asyncpg` text in a body | Grep the exception handlers — no `str(exc)` reaching a 5xx body |
| `trace_id` populated | Present on every error, read from the `ContextVar` | Empty/hardcoded, or read from a module global | Test asserts non-empty `trace_id` on an induced error |
| Context via ContextVar | Tenant/trace read from `ContextVar` | Module-level global mutated per request | Grep for a module global holding tenant/trace |
| Async correctness | Handler `await`s the service; no blocking call on the loop | A sync DB driver / `requests` / blocking `time.sleep` in an `async def` | Read the body for un-`await`ed blocking I/O |
| DI, not ad hoc | Ports via `Depends()` | Pool/repo constructed inside the handler | No `asyncpg.connect`/pool construction in a handler body |
| mypy gate | `mypy`/`pyright` runs CI-breaking | Type errors merge silently | CI config fails the build on a type error |

---

## Anti-Patterns

- **Reading `await request.json()` by hand when a Pydantic model would do** — throws away framework validation, the 422, and the generated schema; declare the body as a model.
- **`extra="ignore"` (the Pydantic default) on request models** — silently drops typo'd/stale fields instead of rejecting them; the Python analog of forgetting `DisallowUnknownFields`. Set `extra="forbid"`.
- **`HTTPException(status_code=409)` scattered per handler** — the anti-pattern the single exception handler exists to prevent; `raise ConflictError(...)` and let the one handler map it.
- **A repository/connection call inside a `@field_validator`** — structural validation has become domain validation in the wrong layer; two places can now disagree about the same rule.
- **Blocking I/O in an `async def` handler** — a sync driver, `requests`, or `time.sleep` blocks the entire event loop (one thread under the GIL), stalling every concurrent request. Use `asyncpg`/`httpx.AsyncClient` and `await`.
- **Tenant/trace state in a module global** — leaks across concurrently-scheduled coroutines on the same loop, a correctness bug with no Go equivalent; use `contextvars.ContextVar`.
- **Echoing `str(exc)` in a 5xx body** — leaks schema and driver internals; log with the trace id, return the opaque envelope.
- **Letting FastAPI's default 422 body ship unreshaped** — the client now parses two error shapes; register a `RequestValidationError` handler that maps it into the one envelope.
- **Treating `mypy`/`pyright` as optional** — Pydantic only guards the boundary; internal domain hints are runtime-erased, so an ungated service silently ships weaker static safety than the Go baseline.

---

## Output Format

Produces Python source built exactly to the standards above — plus handler tests using `httpx.AsyncClient` against the ASGI app, written first, one case per row of the domain-error and validation mapping tables:

```
app/api/router.py                     (APIRouter wiring)
app/api/dependencies.py               (require_subject, get_uow — Depends providers)
app/api/errors.py                     (error envelope model + exception_handler registrations)
app/api/data_assets.py                (ClassifyRequest/Response models + async routes)
tests/api/test_classify_data_asset.py (httpx.AsyncClient round trips)
```

Full worked routes, Pydantic models, and validation boundary: `references/handlers-and-validation.md`. Full error envelope, status-code mapping table, exception-handler and `Depends()` implementations: `references/error-envelope-and-di.md`.
