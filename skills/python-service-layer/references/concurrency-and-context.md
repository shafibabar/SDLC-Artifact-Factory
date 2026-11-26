# Concurrency and Context — Worked Reference

Full worked code for parallel query fan-out with `asyncio.TaskGroup`, request-scoped
propagation with `contextvars.ContextVar`, and the idempotency helper — over the
FastAPI + `asyncpg` stack, the `classification` package. Real
library and API names only (`asyncio`, `contextvars`, `asyncpg`). The parent `SKILL.md`
gives the rules; this file is the exhaustive source.

---

## 1. Parallel query fan-out with `asyncio.TaskGroup`

A dashboard-style query gathers independent facts from several read-model views. Run
them concurrently so the slowest source bounds latency, not the sum. `asyncio.TaskGroup`
(Python 3.11+) is the direct analog of Go's `errgroup`:

- `tg.create_task(...)` schedules each child coroutine.
- The `async with` block's exit is the **join point** — it awaits every child.
- On the first child that raises, the group **cancels its sibling tasks** (each receives
  `asyncio.CancelledError`) rather than letting a failed or slow sibling run on
  unobserved.

```python
# src/classification/service_layer/queries.py
import asyncio
from dataclasses import dataclass
from typing import Any, Protocol
from uuid import UUID

from classification.domain.errors import ViewUnavailableError


class DashboardView(Protocol):
    async def count_assets(self, tenant_id: UUID) -> int: ...
    async def recent_scans(self, tenant_id: UUID, limit: int) -> list[Any]: ...
    async def open_findings(self, tenant_id: UUID) -> int: ...


@dataclass(frozen=True)
class Dashboard:
    asset_count: int
    recent_scans: list[Any]
    open_findings: int


async def load_dashboard(tenant_id: UUID, view: DashboardView) -> Dashboard:
    async with asyncio.TaskGroup() as tg:
        count_t    = tg.create_task(view.count_assets(tenant_id))
        scans_t    = tg.create_task(view.recent_scans(tenant_id, limit=10))
        findings_t = tg.create_task(view.open_findings(tenant_id))
    # Reached only when ALL three completed successfully.
    return Dashboard(
        asset_count=count_t.result(),
        recent_scans=scans_t.result(),
        open_findings=findings_t.result(),
    )
```

Each task writes only its own `Task` result object — the coroutine analog of ad hoc
confinement. No lock and no shared mutable target: the result of each source is reachable
by exactly one task by construction, so there is no race for a lock to prevent.

### Failure semantics — the fact that distinguishes `TaskGroup` from `gather`

When one child raises, `TaskGroup` cancels the still-running siblings and then, at the
`async with` exit, raises the failure(s) wrapped in a single **`ExceptionGroup`** (a
`BaseExceptionGroup` if a child raised a `BaseException` that is not an `Exception`;
`KeyboardInterrupt` and `SystemExit` are re-raised unwrapped, and a child's cancellation
is not collected).
This is why callers that must react to a specific failure use the Python 3.11
`except*` syntax to match a member type inside the group:

```python
# src/classification/service_layer/queries.py  (continued)
async def dashboard_or_unavailable(tenant_id: UUID, view: DashboardView) -> Dashboard:
    try:
        return await load_dashboard(tenant_id, view)
    except* TimeoutError as eg:
        # eg is an ExceptionGroup; eg.exceptions holds the matched members. The service
        # layer matches builtin or domain types; the adapter translates driver errors.
        raise ViewUnavailableError(tenant_id) from eg
```

Contrast with `asyncio.gather(*tasks)`: by default it does **not** cancel siblings when
one task fails — the other tasks keep running to completion (or you must pass
`return_exceptions=True` and inspect each result by hand). That is precisely the
unobserved-sibling hazard `TaskGroup` closes, and why `TaskGroup` is the standard here
and `gather` only the pre-3.11 fallback.

### CPU-bound honesty (do not port Go's worker pool naively)

`TaskGroup` fans out **I/O-bound** work cleanly — the coroutines are cheap and the GIL is
released during `await` on I/O. It does **not** give CPU parallelism: under the GIL, only
one thread runs Python bytecode at a time, so CPU-bound fan-out (entity extraction,
hashing, document parsing) inside a `TaskGroup` silently degrades to serial execution.
True CPU parallelism needs `concurrent.futures.ProcessPoolExecutor` (full OS processes,
pickling overhead), and heavy ML/OCR work should be escalated to a separately-scaled
worker service entirely (`python-async-concurrency`, `data-pipeline-implementation`) —
never run inline in a request-serving fan-out. This is a genuine Python-vs-Go divergence,
not a translation detail.

---

## 2. Request-scoped propagation with `contextvars.ContextVar`

Go's `context.Context` carries cancellation, deadline, tenant id, and trace span together
through every `ctx`-first signature. Python's `asyncio` cancellation carries only
cancellation and a deadline — **not** request values. `contextvars.ContextVar` is the
explicit, separate mechanism for tenant id, the authenticated `Subject`, and the trace
span across `await` boundaries.

The variables and `Subject` live in `domain/context.py` (full listing in
`python-domain-model`), because the service layer and the adapters both read them:

```python
# Illustration: the declarations
current_tenant: contextvars.ContextVar[UUID] = contextvars.ContextVar("current_tenant")
current_subject: contextvars.ContextVar[Subject] = contextvars.ContextVar("current_subject")
current_trace_id: contextvars.ContextVar[str] = contextvars.ContextVar("current_trace_id")
```

A `ContextVar` is `asyncio`-aware: each concurrently scheduled coroutine (and each
request handled on the shared single-threaded event loop) reads its own value. Setting it
for one request never leaks into another. Reading tenant/trace from an ordinary
module-level mutable global instead would leak state across concurrently scheduled
coroutines — a correctness bug with no Go equivalent, because Go passes the value
explicitly down the call stack.

### Setting it once at the edge (middleware)

```python
# src/classification/entrypoints/middleware.py  (registered via app.add_middleware)
from collections.abc import Awaitable, Callable
from uuid import uuid4

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from starlette.types import ASGIApp

from classification.domain.context import Subject, current_subject, current_tenant, current_trace_id

Authenticate = Callable[[Request], Awaitable[Subject]]   # verifies the JWT (python-middleware)


class ContextMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: ASGIApp, authenticate: Authenticate) -> None:
        super().__init__(app)
        self._authenticate = authenticate

    async def dispatch(self, request: Request,
                       call_next: Callable[[Request], Awaitable[Response]]) -> Response:
        subject = await self._authenticate(request)
        trace_id = request.headers.get("traceparent", uuid4().hex)
        # set() returns a Token; reset() restores the prior value on the way out.
        s_token = current_subject.set(subject)
        n_token = current_tenant.set(subject.tenant_id)   # from the token, never a header
        t_token = current_trace_id.set(trace_id)
        try:
            return await call_next(request)
        finally:
            current_subject.reset(s_token)
            current_tenant.reset(n_token)
            current_trace_id.reset(t_token)
```

An exception raised in `dispatch` (a failed `authenticate`) does not reach the app's
`DomainError` handler; return the 401 response here, or authenticate in a dependency.

The service layer then reads it with `current_subject.get()` — never receives it as a
parameter, never reads it from a global dict.

### Propagation into `TaskGroup` child tasks

When a coroutine schedules child tasks, each child runs in a **copy** of the current
context, so `ContextVar` values set before the fan-out are visible inside every child
automatically:

```python
# Illustration
async def load_tenant_dashboard(view):
    tenant = current_tenant.get()   # read once
    async with asyncio.TaskGroup() as tg:
        # Each child sees the same context variables
        # because asyncio copies the context at task creation.
        tg.create_task(view.count_assets(tenant))
        tg.create_task(view.open_findings(tenant))
```

`asyncio.to_thread` also copies the context. `loop.run_in_executor` does **not** —
capture it with `contextvars.copy_context()` and submit `ctx.run(fn, ...)`, or the thread
sees no tenant/trace value and `.get()` raises `LookupError`. A process pool cannot carry
the context at all; pass the values as arguments.

---

## 3. Idempotency helper (shared with the write transaction)

The idempotency check the command use case performs first is a narrow read against a
`command_log` table, scoped to the tenant, executed on the **same** `asyncpg` connection
the Unit of Work holds — so the check, the domain write, and the record insert all live
in one transaction. Positional `$1`/`$2` placeholders, matching `pgx`.

```python
# src/classification/adapters/command_log.py
from uuid import UUID

import asyncpg

from classification.domain.context import tenant_id
from classification.domain.errors import DuplicateCommandError


class PgCommandLog:
    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn   # the UoW's connection — NOT a new one

    async def already_processed(self, idempotency_key: str) -> bool:
        row = await self._conn.fetchrow(
            "SELECT 1 FROM command_log WHERE tenant_id = $1 AND idempotency_key = $2",
            tenant_id(), idempotency_key)
        return row is not None

    async def record(self, idempotency_key: str, asset_id: UUID) -> None:
        status = await self._conn.execute(
            "INSERT INTO command_log (tenant_id, idempotency_key, recorded_at) "
            "VALUES ($1, $2, now()) ON CONFLICT (tenant_id, idempotency_key) DO NOTHING",
            tenant_id(), idempotency_key)
        if status == "INSERT 0 0":
            # A concurrent delivery committed the key after our SELECT. Raising rolls
            # this whole unit back, so the Command takes effect once.
            raise DuplicateCommandError(asset_id, idempotency_key)
```

Because `record` runs on the UoW's connection inside its transaction, a rollback discards
the idempotency record along with the domain write. When two deliveries pass
`already_processed` together, the unique key is the real guarantee: the second `INSERT`
waits for the first transaction, inserts nothing, and `record` raises. (An update of the
same Aggregate can fail earlier on the version compare-and-swap; either way one delivery
wins.) The retried delivery then finds the key and returns.

### Schema

```sql
CREATE TABLE command_log (
    tenant_id       uuid NOT NULL,
    idempotency_key text NOT NULL,
    recorded_at     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, idempotency_key)
);
```

The key includes `tenant_id` so two tenants can use the same key under any isolation
model; a single-tenant product drops the column.
