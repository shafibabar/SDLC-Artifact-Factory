---
name: python-service-layer
description: >
  Teaches the backend-engineer to build a Python service layer — one function
  per use case (load → authorise → domain-call → commit), the Unit of Work as
  an async context manager owning the atomic transaction (defaults to rollback)
  with a FakeUnitOfWork twin, asyncio.TaskGroup for parallel query fan-out
  (cancels siblings on failure, like errgroup), and contextvars for
  tenant/trace propagation. The Python analog of go-service-layer.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, fastapi, asyncpg, application-layer, service-layer, unit-of-work, idempotency, taskgroup, contextvars, async]
produces: python-cqrs-handlers
domain: backend
status: stable
related: [go-service-layer, python-repository-pattern, python-domain-model, python-error-handling]
---

# Python Service Layer (Application Layer)

## Purpose

The application layer expresses use cases as functions between the FastAPI transport
edge (`python-fastapi-handler`) and the domain model (`python-domain-model`). A
service-layer function orchestrates: load the Aggregate, authorise the caller, call a
domain method, commit. It holds **no business rules itself** — those live in the
Aggregate. This is the Python analog of `go-service-layer`; Percival & Gregory's Cosmic
Python pairs the Service Layer with a Unit of Work so the same use-case flow drives
identically from an HTTP handler, a CLI, and a test — none of the logic lives in the
handler.

Two Python realities differ honestly from Go and shape everything below:

- **The Unit of Work replaces `go-service-layer`'s handler-owned `pgx.Tx`.** In Go the
  handler holds `pool` and opens the `tx`; in Python the atomic boundary is a named,
  first-class object — an async context manager — a genuine structural difference.
- **`contextvars` is not free.** Go's `context.Context` carries tenant id and trace span
  implicitly through every `ctx`-first signature; Python's `asyncio` cancellation carries
  only cancellation and a deadline — **not** request values. Tenant/trace propagation
  across `await` needs `contextvars` explicitly, or it silently leaks — a correctness bug
  with no Go equivalent.

---

## Use-Case Function Standard

One function per use case, taking a command DTO (a Pydantic model or frozen dataclass)
and the Unit of Work, returning the use case's own result DTO — never an ORM object,
never an `asyncpg.Record`, never an HTTP type. Fixed step order, identical in spirit to
`go-service-layer`'s five-step discipline:

**idempotency check → load → authorise → domain call → commit.**

```python
async def classify_data_asset(cmd: ClassifyDataAsset, uow: AbstractUnitOfWork) -> None:
    async with uow:
        if await uow.commands.already_processed(cmd.idempotency_key):
            return                                    # duplicate delivery — replay
        asset = await uow.assets.get(cmd.asset_id)    # load (tenant-scoped repo)
        if asset is None:
            raise NotFoundError(cmd.asset_id)
        subject = current_subject.get()               # from a ContextVar, not a global
        subject.require("data-assets:classify")       # authorise BEFORE mutate
        asset.classify(cmd.sensitivity)               # domain call — invariant lives here
        await uow.assets.add(asset)
        await uow.commands.record(cmd.idempotency_key)
        await uow.commit()                            # explicit; absence == rollback
```

The idempotency `record` insert shares the UoW's single transaction with the domain
write — same guarantee as `go-service-layer`'s `command_log` rule and
`python-repository-pattern`'s outbox-in-one-transaction rule: a crash between the ledger
write and the domain write is impossible by construction. A use-case function changes
**exactly one Aggregate per transaction**; a case that appears to need two atomically is
a signal to reconsider the boundary or emit a Domain Event, never a transaction spanning
two.

Full worked command function, the UoW definition, the `FakeUnitOfWork` twin, and the
command-vs-event dispatch rule: `references/service-layer-and-uow.md`.

---

## Query Standard

Queries never load Aggregates and never open a Unit of Work. A read has no invariant to
enforce, so it goes straight to a narrow read-model port scoped to the tenant and
permission — the CQRS Read Model, a denormalised projection read with one `SELECT`:

```python
async def list_data_assets(q: ListDataAssets, view: DataAssetView) -> Page[DataAssetDTO]:
    subject = current_subject.get()
    subject.require("data-assets:read")
    return await view.list(subject.tenant_id, q.sensitivity, q.page)
```

Bypassing the domain layer for reads is deliberate — a read has no invariant to enforce.

---

## Unit of Work: Async Context Manager, Rollback by Default

The Unit of Work owns one atomic transaction and exposes the repositories inside it. It
is an `async with` context manager whose `__aexit__` **rolls back unless the caller
explicitly `await uow.commit()`ed** — so "did we forget to commit?" and "did an
exception leave a half-written transaction?" become structurally-answered questions, not
review-time worries. `__aenter__` acquires an `asyncpg` connection and opens its
transaction; `__aexit__` commits only if `commit()` was called, else rolls back.

Because the port is an abstraction, its biggest day-to-day payoff is a test fake: a
`FakeUnitOfWork` backed by `set`-based fake repositories, no-op commit, lets the whole
service layer get fast, database-free unit tests, while the real `asyncpg` UoW is
exercised only by a few `testcontainers` integration tests. Prefer this fake over a
mock: assert on resulting state, not on how the code called its collaborators. Full
`AbstractUnitOfWork` Protocol, the concrete `asyncpg` UoW, and the `FakeUnitOfWork`:
`references/service-layer-and-uow.md`.

The port is a `typing.Protocol` (structural typing — the `asyncpg` implementation never
subclasses it), the closest Python gets to Go's implicit interface satisfaction. Honest
caveat: a `Protocol` is only checked if `mypy`/`pyright` runs — nothing at runtime
rejects a wrong-shaped object, unlike Go's compile error, so the type-check step is a
required CI gate.

---

## Parallel Query Fan-Out with asyncio.TaskGroup

When a query gathers independent data from several sources, fan out so the slowest
source bounds latency, not the sum. Use **`asyncio.TaskGroup`** (Python 3.11+): the
direct analog of Go's `errgroup` — when one child task fails, the group **cancels its
sibling tasks** and surfaces the failure rather than letting a failed sibling run on
unobserved. Each task writes only its own local — the coroutine analog of ad hoc
confinement; no lock is needed because the state is reachable by exactly one task.

```python
async with asyncio.TaskGroup() as tg:
    assets = tg.create_task(view.count_assets(tenant_id))
    scans  = tg.create_task(view.recent_scans(tenant_id))
# both awaited at the `async with` exit — the join point
return Dashboard(assets.result(), scans.result())
```

`asyncio.gather` is the pre-3.11 fallback but does **not** cancel siblings on first
failure by default — prefer `TaskGroup`. Full fan-out, the failure/cancel semantics,
`contextvars` propagation into tasks, and the idempotency helper:
`references/concurrency-and-context.md`.

---

## Tenant and Trace Propagation with contextvars

Tenant id, the authenticated `Subject`, and the trace span are carried in
`contextvars.ContextVar`s — set once by middleware at the request edge, read by the
service layer via `.get()`. A `ContextVar` is `asyncio`-aware: each concurrently
scheduled coroutine sees its own value, so tenant state cannot leak between requests
sharing the event loop. **Never** read tenant/trace from a module-level global — that
leaks state across concurrent coroutines, the bug with no Go equivalent. Definitions,
middleware set-up, and propagation into `TaskGroup` tasks: `references/concurrency-and-context.md`.

---

## Rules

- **No business logic in use-case functions.** Decisions live in the Aggregate; the
  service layer orchestrates.
- **The Unit of Work owns the transaction, never the repository.** The atomic boundary is
  the `async with uow:` block; a repository method never opens its own transaction.
- **Rollback is the default.** The happy path ends in an explicit `await uow.commit()`; its
  absence, or any exception, rolls back.
- **Authorise before mutate.** The permission check precedes the domain call, always.
- **Idempotent commands, same transaction** — the processed-key record shares the domain
  write's UoW. **Read tenant/trace from a `ContextVar`, never a module global**; no HTTP
  types, no Pydantic request models, and no `asyncpg.Record` cross this layer.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Thin functions, one use case each | Orchestration only; command DTO in, result DTO out | Business logic in the function, or an Aggregate/`Record` returned | Read the body against the fixed step order |
| UoW owns the transaction | `commit`/rollback only via the UoW context manager; repos never open a transaction | A repository calling `conn.transaction()` itself | `grep -rn "conn.transaction()" src/infrastructure` — only inside the UoW |
| Rollback by default | Happy path ends in `await uow.commit()`; `__aexit__` rolls back otherwise | A UoW that commits in `__aexit__` unconditionally | Read `__aexit__`; read the end of every use-case function |
| Idempotency same-transaction | Processed-key record shares the UoW with the domain write | Record and domain write in separate transactions | Read the function for one `async with uow:` spanning both |
| Write/read separation | Commands mutate Aggregates; queries hit read-model views | A query loading an Aggregate or opening a UoW | Grep query functions for `uow` / `.get(` — none |
| Fan-out cancels siblings, tenant via ContextVar | `asyncio.TaskGroup` with one local per task; `current_subject.get()` | `gather` with no cancel-on-failure, or tenant from a module-level global | Read each `create_task` write target; `grep -rn "^tenant" src` — none |

---

## Anti-Patterns

- **The "service" that is really the domain** — invariant checks written in the function;
  the Aggregate can no longer guarantee them.
- **A repository opening its own transaction**, or an idempotency record in a separate
  transaction from the domain write — both reopen the dual-write race the UoW closes.
- **A UoW that commits by default** — an exception mid-use-case then persists a
  half-written change; rollback must be the default and commit explicit.
- **Authorise-after-mutate** — a forbidden caller's in-memory mutation already happened.
- **Queries through the write model** — loading Aggregates to answer a list screen.
- **`asyncio.gather` where cancel-on-failure matters** — a failed sibling's peers run on
  unobserved; `TaskGroup` cancels them. Or **tenant/trace in a module-level global**,
  which leaks across concurrent coroutines — the bug Go's `context.Context` cannot have.

---

## Output Format

Python source built to the standards above, tests written first (TDD): use-case
functions get fast unit tests against the `FakeUnitOfWork`; the real `asyncpg` UoW gets
`testcontainers` integration tests against real PostgreSQL — a fake cannot verify a
transaction boundary that is itself under test.

```
src/application/commands/classify_data_asset.py
tests/application/commands/test_classify_data_asset.py   (unit — FakeUnitOfWork)
src/infrastructure/uow.py
tests/infrastructure/test_uow.py                          (integration — real asyncpg)
```
