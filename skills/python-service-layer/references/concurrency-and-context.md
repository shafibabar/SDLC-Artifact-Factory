# Concurrency and Context — Worked Reference

Full worked code for parallel query fan-out with `asyncio.TaskGroup`, request-scoped
propagation with `contextvars.ContextVar`, and the idempotency helper — over the
FastAPI + `asyncpg` stack, `DataAsset` domain, per-tenant physical isolation. Real
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
# src/application/queries/dashboard.py
import asyncio
from dataclasses import dataclass


@dataclass(frozen=True)
class Dashboard:
    asset_count: int
    recent_scans: list
    open_findings: int


async def load_dashboard(tenant_id: str, view: "DashboardView") -> Dashboard:
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
`async with` exit, raises the failure(s) wrapped in a single **`ExceptionGroup`** (or
`BaseExceptionGroup` when a `BaseException` such as a bare cancellation is involved).
This is why callers that must react to a specific failure use the Python 3.11
`except*` syntax to match a member type inside the group:

```python
try:
    dash = await load_dashboard(tenant_id, view)
except* asyncpg.PostgresError as eg:
    # eg is an ExceptionGroup; eg.exceptions holds the matched members.
    raise ViewUnavailable(tenant_id) from eg
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

```python
# src/application/context.py
import contextvars
from dataclasses import dataclass


@dataclass(frozen=True)
class Subject:
    tenant_id: str
    perms: frozenset[str]

    def require(self, perm: str) -> None:
        if perm not in self.perms:
            raise Forbidden(perm)


# Declared once, at module scope. The ContextVar OBJECT is a module global;
# its VALUE is per-execution-context, never shared across coroutines.
current_subject: contextvars.ContextVar[Subject] = contextvars.ContextVar("subject")
current_trace_id: contextvars.ContextVar[str] = contextvars.ContextVar("trace_id")
```

A `ContextVar` is `asyncio`-aware: each concurrently scheduled coroutine (and each
request handled on the shared single-threaded event loop) reads its own value. Setting it
for one request never leaks into another. Reading tenant/trace from an ordinary
module-level mutable global instead would leak state across concurrently scheduled
coroutines — a correctness bug with no Go equivalent, because Go passes the value
explicitly down the call stack.

### Setting it once at the edge (middleware)

```python
# src/interface/middleware.py  (registered via app.add_middleware)
from starlette.middleware.base import BaseHTTPMiddleware
from src.application.context import current_subject, current_trace_id


class ContextMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        subject = await authenticate(request)   # decode JWT -> Subject
        trace_id = request.headers.get("traceparent", new_trace_id())
        # set() returns a Token; reset() restores the prior value on the way out.
        s_token = current_subject.set(subject)
        t_token = current_trace_id.set(trace_id)
        try:
            return await call_next(request)
        finally:
            current_subject.reset(s_token)
            current_trace_id.reset(t_token)
```

The service layer then reads it with `current_subject.get()` — never receives it as a
parameter, never reads it from a global dict.

### Propagation into `TaskGroup` child tasks

When a coroutine schedules child tasks, each child runs in a **copy** of the current
context, so `ContextVar` values set before the fan-out are visible inside every child
automatically:

```python
async def load_tenant_dashboard(view) -> Dashboard:
    tenant_id = current_subject.get().tenant_id   # read once
    async with asyncio.TaskGroup() as tg:
        # Each child sees the same current_subject / current_trace_id
        # because asyncio copies the context at task creation.
        tg.create_task(view.count_assets(tenant_id))
        tg.create_task(view.open_findings(tenant_id))
    ...
```

If you spin up work with the lower-level `loop.run_in_executor` or a thread, the context
does **not** copy automatically — capture it explicitly with `contextvars.copy_context()`
and run the callable inside it (`ctx.run(fn, ...)`), or the child sees no tenant/trace
value and `current_subject.get()` raises `LookupError`.

---

## 3. Idempotency helper (shared with the write transaction)

The idempotency check the command use case performs first is a narrow read against a
`command_log` table, scoped to the tenant, executed on the **same** `asyncpg` connection
the Unit of Work holds — so the check, the domain write, and the record insert all live
in one transaction. Positional `$1`/`$2` placeholders, matching `pgx`.

```python
# src/infrastructure/repositories.py
class PgCommandLog:
    def __init__(self, conn: "asyncpg.Connection") -> None:
        self._conn = conn   # the UoW's connection — NOT a new one

    async def already_processed(self, idempotency_key: str) -> bool:
        row = await self._conn.fetchrow(
            "SELECT 1 FROM command_log WHERE idempotency_key = $1", idempotency_key
        )
        return row is not None

    async def record(self, idempotency_key: str) -> None:
        # ON CONFLICT DO NOTHING makes a concurrent double-delivery safe even
        # if two workers pass the SELECT check at the same instant.
        await self._conn.execute(
            "INSERT INTO command_log (idempotency_key, recorded_at) "
            "VALUES ($1, now()) ON CONFLICT (idempotency_key) DO NOTHING",
            idempotency_key,
        )
```

Because `record` runs on the UoW's connection inside its transaction, a rollback
(exception, or no `commit()`) discards the idempotency record along with the domain
write — the ledger and the write are atomic, never split. The `ON CONFLICT DO NOTHING`
guard closes the narrow race where two concurrent deliveries both pass `already_processed`
before either commits: the second `INSERT` no-ops, and the unique constraint on
`idempotency_key` is the real guarantee, not the earlier `SELECT`.

### Schema

```sql
CREATE TABLE command_log (
    idempotency_key text PRIMARY KEY,
    recorded_at     timestamptz NOT NULL DEFAULT now()
);
```

For per-tenant physical isolation, this table lives in each tenant's own database/schema
alongside the Aggregate tables — the connection the UoW acquired is already the tenant's,
so no `tenant_id` column is needed here (it is implied by which physical database the
connection points at).
