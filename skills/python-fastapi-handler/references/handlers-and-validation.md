# Worked FastAPI Handlers and Structural Validation

Companion to `python-fastapi-handler`'s SKILL.md. All code targets FastAPI (on Starlette), Pydantic v2, and `asyncpg`, served by `uvicorn`, for the DataAsset bounded context of this repo's data-estate product. Import lines are complete; nothing is elided into `...` except clearly marked bodies delegated to sibling skills.

---

## Route Registration: the `APIRouter`

Routes group by resource on an `APIRouter`, wired into the app in the `lifespan` composition root (`python-service-skeleton`). The router constructs nothing infrastructure-owned — the pool and repositories arrive via `Depends()`.

```python
# app/api/router.py
from fastapi import APIRouter

from app.api import data_assets, health

api_router = APIRouter(prefix="/v1")
api_router.include_router(data_assets.router)

# Health/readiness mount on a SEPARATE, unauthenticated router — never under /v1.
public_router = APIRouter()
public_router.include_router(health.router)
```

```python
# app/main.py (composition root — see python-service-skeleton for the full lifespan)
from contextlib import asynccontextmanager

import asyncpg
from fastapi import FastAPI

from app.api.errors import register_exception_handlers
from app.api.router import api_router, public_router
from app.settings import settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: open the per-tenant physically-isolated pool (one DB per tenant).
    app.state.pool = await asyncpg.create_pool(dsn=settings.database_dsn, min_size=2, max_size=10)
    yield
    # Shutdown: reverse order — drain the pool.
    await app.state.pool.close()


app = FastAPI(title="data-asset-service", lifespan=lifespan)
register_exception_handlers(app)   # the single error-mapping points — see error-envelope-and-di.md
app.include_router(api_router)
app.include_router(public_router)
```

Route paths mirror the approved OpenAPI contract exactly. Because FastAPI generates its schema *from* these routes (code-first-to-spec), CI runs a conformance check of the generated `app.openapi()` against the approved contract rather than treating the generated schema as the source of truth (`python-openapi-codegen`).

---

## Request and Response Models: structural validation as types

Pydantic models declare the wire shape. `extra="forbid"` is the analog of chi's `DisallowUnknownFields` — a typo'd or stale field is a 422, not a silent drop. `Field(...)` constraints, enum types, and constrained types express every structural rule, and FastAPI reports all violations at once.

```python
# app/api/data_assets.py  (models portion)
from __future__ import annotations

import enum
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class Classification(str, enum.Enum):
    PUBLIC = "public"
    INTERNAL = "internal"
    CONFIDENTIAL = "confidential"
    RESTRICTED = "restricted"


class ClassifyRequest(BaseModel):
    # extra="forbid" -> reject unknown fields (DisallowUnknownFields analog).
    model_config = ConfigDict(extra="forbid")

    classification: Classification                      # enum membership enforced by the type
    justification: str = Field(min_length=1, max_length=2_000)
    reviewed_by: UUID                                   # format-checked before the handler runs


class DataAssetResponse(BaseModel):
    id: UUID
    tenant_id: UUID
    path: str
    classification: Classification
    classified_at: datetime


class DataAssetPage(BaseModel):
    # A named top-level key, never a bare array — a later field (next cursor)
    # extends the response without breaking a client that reads `data_assets`.
    data_assets: list[DataAssetResponse]
    next_cursor: str | None = None
```

Pydantic v2 note: `model_config = ConfigDict(extra="forbid")` is the v2 spelling; the v1 `class Config: extra = "forbid"` inner-class form is deprecated. Constrained fields use `Field(...)` (`Field(gt=0)`, `Field(max_length=...)`); `conint`/`constr`/`EmailStr` remain available for reuse across models.

---

## The Canonical Mutation Handler: `classify_data_asset`

Decode is the framework's job; the visible body is call → return. The handler is `async def`, `await`s the application layer, touches no status code, and lets any raised `DomainError` propagate to the single exception handler.

```python
# app/api/data_assets.py  (routes portion)
from fastapi import APIRouter, Depends, Header, Path, Query, status

from app.api.dependencies import Subject, UnitOfWork, get_uow, require_subject
from app.application.commands import ClassifyDataAsset

router = APIRouter(tags=["data-assets"])


@router.post(
    "/data-assets/{asset_id}/classification",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def classify_data_asset(
    asset_id: UUID = Path(...),
    body: ClassifyRequest = ...,                       # framework validates BEFORE this body runs
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    subject: Subject = Depends(require_subject),        # authentication — see error-envelope-and-di.md
    uow: UnitOfWork = Depends(get_uow),                # per-request unit of work (yield dependency)
) -> None:
    # Forward the idempotency key UNEXAMINED; the dedupe store is the service's concern.
    command = ClassifyDataAsset(
        asset_id=asset_id,
        classification=body.classification,
        justification=body.justification,
        reviewed_by=body.reviewed_by,
        idempotency_key=idempotency_key,
    )
    # tenant_id / trace_id ride a contextvars.ContextVar set by middleware — NOT a module
    # global, which would leak across concurrently-scheduled coroutines (python-service-layer).
    await uow.classify.handle(command, subject=subject)
    # No return body: 204. A raised NotFoundError/ConflictError is mapped by the ONE
    # @app.exception_handler(DomainError) — never caught or status-coded here.
```

Because `body` is typed as `ClassifyRequest`, an unknown field, a bad enum value, a missing `justification`, or a non-UUID `reviewed_by` all short-circuit to a 422 with a per-field list *before* line one of the body — you never write that validation.

---

## The Canonical Query Handler: `list_data_assets`

Query params are declared with `Query(...)` constraints; `response_model` enforces the outgoing shape and drives the generated schema.

```python
@router.get("/data-assets", response_model=DataAssetPage)
async def list_data_assets(
    classification: Classification | None = Query(default=None),
    limit: int = Query(default=50, gt=0, le=200),       # range-checked at the boundary
    cursor: str | None = Query(default=None),
    subject: Subject = Depends(require_subject),
    uow: UnitOfWork = Depends(get_uow),
) -> DataAssetPage:
    page = await uow.assets.list(
        tenant_id=subject.tenant_id,                    # tenant scoping is authenticated, not client-supplied
        classification=classification,
        limit=limit,
        cursor=cursor,
    )
    return DataAssetPage(
        data_assets=[DataAssetResponse.model_validate(a) for a in page.items],
        next_cursor=page.next_cursor,
    )
```

Per-tenant **physical** isolation (one database per tenant) means `tenant_id` comes from the authenticated `Subject`, never a request field a client could forge to reach another tenant's pool.

---

## Structural vs. Domain Validation: the precise boundary

The rule is identical to `go-chi-handler`'s, only the mechanism differs (declared Pydantic types, not a hand-written `validate()`).

| Question the check answers | Answerable from the request bytes alone? | Layer | Mechanism |
|---|---|---|---|
| Is `classification` one of the four enum values? | Yes | Structural (422) | `Classification` enum type |
| Is `justification` present and ≤ 2000 chars? | Yes | Structural (422) | `Field(min_length=1, max_length=2_000)` |
| Is `reviewed_by` a well-formed UUID? | Yes | Structural (422) | `UUID` type hint |
| Is there an unknown/typo'd field? | Yes | Structural (422) | `ConfigDict(extra="forbid")` |
| Does this asset currently exist for this tenant? | No — needs the repository | Domain | `raise NotFoundError` in the service |
| Is this asset already classified `RESTRICTED` (no downgrade)? | No — needs the aggregate's state | Domain | Aggregate invariant, `raise ConflictError` |
| May this subject reclassify this asset? | No — needs permissions + resource | Domain | Authorise-before-mutate in the service |

**The bright line:** the instant a check needs the aggregate's current state, another aggregate, or the caller's permissions, it is domain validation and belongs to the Aggregate (`python-domain-model`) or the service (`python-service-layer`) — never a repository call inside a Pydantic `@field_validator`. A validator that opens an `asyncpg` connection has silently become domain logic in the transport layer, and now two places can disagree about the same rule.

A `@field_validator` is legitimate *only* for cross-field structural checks decidable from the request bytes — e.g. "if `classification == RESTRICTED` then `justification` must be ≥ 50 chars":

```python
from pydantic import field_validator, model_validator


class ClassifyRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    classification: Classification
    justification: str = Field(min_length=1, max_length=2_000)
    reviewed_by: UUID

    @model_validator(mode="after")
    def restricted_needs_detailed_justification(self) -> "ClassifyRequest":
        if self.classification is Classification.RESTRICTED and len(self.justification) < 50:
            raise ValueError("justification must be at least 50 characters for RESTRICTED")
        return self
```

A `ValueError` raised inside a validator is collected by Pydantic into the same 422 per-field list — it does not become a 500.

---

## Testing the Handler: `httpx.AsyncClient` round trips (written first)

The handler is a Humble Object — verified only via real request/response round trips against the ASGI app, one case per row of the validation and domain-error tables. Tests are written before the handler (TDD).

```python
# tests/api/test_classify_data_asset.py
import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.mark.asyncio
async def test_unknown_field_is_422_not_silently_dropped():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/v1/data-assets/3f2504e0-4f89-41d3-9a0c-0305e82c3301/classification",
            json={"classification": "internal", "justification": "ok",
                  "reviewed_by": "3f2504e0-4f89-41d3-9a0c-0305e82c3301",
                  "typo_field": "x"},                    # extra="forbid" -> 422
            headers={"Authorization": "Bearer <valid-test-jwt>"},
        )
    assert resp.status_code == 422
    assert resp.json()["code"] == "VALIDATION_FAILED"    # reshaped into the ONE envelope


@pytest.mark.asyncio
async def test_bad_enum_value_is_422():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post(
            "/v1/data-assets/3f2504e0-4f89-41d3-9a0c-0305e82c3301/classification",
            json={"classification": "top-secret", "justification": "ok",
                  "reviewed_by": "3f2504e0-4f89-41d3-9a0c-0305e82c3301"},
            headers={"Authorization": "Bearer <valid-test-jwt>"},
        )
    assert resp.status_code == 422
```

`ASGITransport(app=app)` drives the app in-process with no network socket and no running `uvicorn` — the async analog of Go's `httptest`. Mark async tests with `@pytest.mark.asyncio` (via `pytest-asyncio`), or run under `anyio`'s pytest plugin.

The domain-error round trips (404 on a missing asset, 409 on an illegal downgrade, 403 on an unauthorised subject) live in the same file, each asserting the status and the canonical envelope shape produced by the single exception handler — those handlers are in `error-envelope-and-di.md`.
