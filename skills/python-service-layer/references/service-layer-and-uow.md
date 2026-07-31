# Service Layer and Unit of Work — Worked Reference

Full worked code for the Python service layer over the FastAPI + `asyncpg` stack, the
`DataAsset` domain, per-tenant physical isolation. Every snippet is pattern-accurate
Python — real library and API names only (`asyncpg`, `typing.Protocol`,
`contextlib`, Pydantic). Adapt names to your Bounded Context; do not copy verbatim
without wiring the imports.

The parent `SKILL.md` gives the decision-shaping rules. This file is the exhaustive
source: the Unit of Work Protocol, its concrete `asyncpg` implementation, the
`FakeUnitOfWork` twin, a full command use-case function, and the command-vs-event
dispatch rule.

---

## 1. The Unit of Work port (`typing.Protocol`)

The port lives in the application layer and is a **structural** type — the concrete
`asyncpg` UoW below never imports or subclasses it; it merely matches the shape. This is
the closest Python gets to Go's implicit interface satisfaction. `mypy`/`pyright` is the
only thing that checks the match — it is a required CI gate, because nothing at runtime
rejects a wrong-shaped object.

```python
# src/application/ports.py
from __future__ import annotations
from typing import Protocol, runtime_checkable


class AssetRepository(Protocol):
    async def get(self, asset_id: str) -> "DataAsset | None": ...
    async def add(self, asset: "DataAsset") -> None: ...


class CommandLog(Protocol):
    async def already_processed(self, idempotency_key: str) -> bool: ...
    async def record(self, idempotency_key: str) -> None: ...


@runtime_checkable
class AbstractUnitOfWork(Protocol):
    assets: AssetRepository
    commands: CommandLog

    async def __aenter__(self) -> "AbstractUnitOfWork": ...
    async def __aexit__(self, exc_type, exc, tb) -> None: ...
    async def commit(self) -> None: ...
    async def rollback(self) -> None: ...
```

Note `__aexit__`'s signature: it receives the exception triple, which is how the context
manager knows whether the block exited cleanly or via an exception. The contract below
is the load-bearing rule: **it must roll back unless `commit()` was explicitly called.**

---

## 2. The concrete `asyncpg` Unit of Work

`__aenter__` acquires a pooled connection and opens its transaction; `__aexit__` commits
only when the caller flagged commit, otherwise rolls back. Crucially, an exception
propagating out of the `async with` block arrives at `__aexit__` with a non-`None`
`exc_type`, and the default path — no commit flag set — rolls back. There is no way to
leave a half-written transaction open.

```python
# src/infrastructure/uow.py
import asyncpg
from src.infrastructure.repositories import PgAssetRepository, PgCommandLog


class AsyncpgUnitOfWork:
    """Owns exactly one asyncpg transaction. Rollback is the default."""

    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool
        self._committed = False

    async def __aenter__(self) -> "AsyncpgUnitOfWork":
        self._conn = await self._pool.acquire()
        self._tx = self._conn.transaction()
        await self._tx.start()
        # Repositories share THIS connection — never open their own transaction.
        self.assets = PgAssetRepository(self._conn)
        self.commands = PgCommandLog(self._conn)
        self._committed = False
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        try:
            if exc_type is None and self._committed:
                await self._tx.commit()
            else:
                await self._tx.rollback()   # DEFAULT: any exception, or no commit()
        finally:
            await self._pool.release(self._conn)

    async def commit(self) -> None:
        # Marks intent; the actual COMMIT happens in __aexit__ so a later
        # exception in the same block still rolls the whole unit back.
        self._committed = True

    async def rollback(self) -> None:
        self._committed = False
```

A subtle but deliberate choice: `commit()` sets a flag rather than issuing the SQL
`COMMIT` immediately. That keeps the whole `async with` block atomic — if code after
`await uow.commit()` (but still inside the block) raises, `__aexit__` sees the exception
and rolls back despite the flag. Ending the block cleanly is what actually commits.

---

## 3. The `FakeUnitOfWork` twin

The single biggest day-to-day payoff of the port. Backed by `set`-based fake
repositories, no-op commit, no database. The service layer's unit tests run entirely
against it — fast, hermetic, no `testcontainers`. Prefer this fake over a `unittest.mock`
mock: assert on resulting state (`uow.committed`, what is in the fake repo), not on how
the code called its collaborators.

```python
# tests/fakes.py
class FakeAssetRepository:
    def __init__(self, assets=()):
        self._assets = {a.id: a for a in assets}

    async def get(self, asset_id):
        return self._assets.get(asset_id)

    async def add(self, asset):
        self._assets[asset.id] = asset


class FakeCommandLog:
    def __init__(self):
        self._seen: set[str] = set()

    async def already_processed(self, idempotency_key):
        return idempotency_key in self._seen

    async def record(self, idempotency_key):
        self._seen.add(idempotency_key)


class FakeUnitOfWork:
    def __init__(self, assets=()):
        self.assets = FakeAssetRepository(assets)
        self.commands = FakeCommandLog()
        self.committed = False
        self.rolled_back = False

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        if not self.committed:
            self.rolled_back = True

    async def commit(self):
        self.committed = True

    async def rollback(self):
        self.rolled_back = True
```

A TDD test drives the whole use case through it:

```python
import pytest

@pytest.mark.asyncio
async def test_classify_commits_once_and_is_idempotent():
    asset = DataAsset(id="a1", tenant_id="t1", sensitivity="internal")
    uow = FakeUnitOfWork(assets=[asset])
    cmd = ClassifyDataAsset(asset_id="a1", sensitivity="restricted",
                            idempotency_key="k-1")

    with subject_scope(Subject(tenant_id="t1", perms={"data-assets:classify"})):
        await classify_data_asset(cmd, uow)
        assert uow.committed is True
        assert (await uow.assets.get("a1")).sensitivity == "restricted"

        # Second identical delivery is a no-op replay — the key is already recorded.
        uow2 = FakeUnitOfWork(assets=[asset])
        uow2.commands._seen.add("k-1")
        await classify_data_asset(cmd, uow2)
        # committed stays False on the replay branch — nothing to write.
```

---

## 4. The full command use-case function

Fixed step order: **idempotency check → load → authorise → domain call → commit.** The
processed-key `record` shares the UoW's one transaction with the domain write, so a crash
between them is impossible by construction — the Python twin of `go-service-layer`'s
`command_log` first-statement rule.

```python
# src/application/commands/classify_data_asset.py
from dataclasses import dataclass
from src.application.ports import AbstractUnitOfWork
from src.application.context import current_subject
from src.domain.errors import NotFoundError


@dataclass(frozen=True)
class ClassifyDataAsset:
    asset_id: str
    sensitivity: str
    idempotency_key: str


async def classify_data_asset(cmd: ClassifyDataAsset,
                              uow: AbstractUnitOfWork) -> None:
    async with uow:
        if await uow.commands.already_processed(cmd.idempotency_key):
            return                                     # duplicate delivery — replay
        asset = await uow.assets.get(cmd.asset_id)     # load, tenant-scoped repo
        if asset is None:
            raise NotFoundError(cmd.asset_id)
        subject = current_subject.get()                # ContextVar, not a global
        subject.require("data-assets:classify")        # authorise BEFORE mutate
        asset.classify(cmd.sensitivity)                # domain call — invariant here
        await uow.assets.add(asset)
        await uow.commands.record(cmd.idempotency_key) # same transaction as the write
        await uow.commit()                             # explicit; absence == rollback
```

The function returns the use case's own result DTO (here `None`), never an
`asyncpg.Record`, never a Pydantic request model, never an HTTP object. It changes
exactly **one** Aggregate per transaction. A use case that appears to need two Aggregates
changed atomically is a design signal — reconsider the boundary, or emit a Domain Event
and let a second use case react (eventual consistency), never a transaction spanning two.

---

## 5. Command vs. Event dispatch

Percival & Gregory draw a sharp line, and it matters for how the service layer routes
work:

| | Command | Event |
|---|---|---|
| Intent | Imperative — "do this" | Statement of fact — "this happened" |
| Handlers | Exactly **one** | **Zero or more** |
| Failure | May fail loudly; the caller wants the outcome | Each handler fails independently without breaking the caller |
| Example | `ClassifyDataAsset` | `DataAssetClassified` |

A command use-case function is called directly (one handler). Domain **Events** are a
different mechanism: the Aggregate appends them to a `self.events` list during the domain
call; after `await uow.commit()` succeeds, the service layer drains them to an in-process
message bus that routes each to its handler(s):

```python
# after a successful commit, drain and dispatch
async def classify_and_publish(cmd, uow, bus):
    await classify_data_asset(cmd, uow)      # commits inside
    for event in uow.assets.collect_new_events():
        await bus.handle(event)              # each handler failing is independent
```

Keep the handler map explicit and readable, not magical:

```python
EVENT_HANDLERS = {
    "DataAssetClassified": [write_to_outbox, reindex_search_projection],
}
```

**Boundary note (do not conflate two layers):** this in-process message bus is Cosmic
Python's *intra-process* events — one Python process. It is **not** the cross-service
broker. Cross-context delivery goes through the Transactional Outbox written inside this
same UoW transaction (`python-repository-pattern`) and relayed to Redpanda by a separate
publisher (`python-event-publisher`). An in-process event handler may *write* an outbox
row; a broker later delivers it cross-service. Blurring the in-process bus and the
Redpanda broker erases a real architectural boundary.

---

## 6. Why the service function stays framework-free

The same `classify_data_asset` above is driven identically from three call sites — this
is the whole point of the layer, and the test at §3 is literally the third one:

```python
# FastAPI route (python-fastapi-handler owns this edge)
@app.post("/data-assets/{asset_id}/classification", status_code=204)
async def http_classify(asset_id: str, body: ClassifyBody,
                        uow: AbstractUnitOfWork = Depends(get_uow)):
    cmd = ClassifyDataAsset(asset_id, body.sensitivity, body.idempotency_key)
    await classify_data_asset(cmd, uow)   # no logic here — parse, call, 204

# CLI
async def cli_classify(args):
    cmd = ClassifyDataAsset(args.asset_id, args.sensitivity, uuid4().hex)
    await classify_data_asset(cmd, AsyncpgUnitOfWork(pool))
```

No HTTP types, no Pydantic request model, and no `asyncpg` object leak into the use-case
function. That is what makes it uniformly testable and reusable.
