# Service Layer and Unit of Work — Worked Reference

Full worked code for the Python service layer over the FastAPI + `asyncpg` stack, the
`DataAsset` domain in the `classification` package (`python-project-structure`'s layout).
The example product is multi-tenant; the isolation model is the tenancy design's choice. Every snippet is pattern-accurate
Python — real library and API names only (`asyncpg`, `typing.Protocol`,
Pydantic). Adapt names to your Bounded Context; do not copy verbatim
without wiring the imports.

The parent `SKILL.md` gives the decision-shaping rules. This file is the exhaustive
source: the Unit of Work Protocol, its concrete `asyncpg` implementation, the
`FakeUnitOfWork` twin, a full command use-case function, and the command-vs-event
dispatch rule.

---

## 1. The Unit of Work port (`typing.Protocol`)

The port lives in the service layer and is a **structural** type — the concrete `asyncpg`
UoW below never subclasses it; it merely matches the shape. This is the closest Python
gets to Go's implicit interface satisfaction. `mypy`/`pyright` is the only thing that
checks the match — it is a required CI gate, because nothing at runtime rejects a
wrong-shaped object. The repository port is `domain/ports.py`'s `DataAssetRepository`
(`python-repository-pattern`).

```python
# src/classification/service_layer/unit_of_work.py
from collections.abc import Iterable
from types import TracebackType
from typing import Protocol
from uuid import UUID

from classification.domain.events import DomainEvent
from classification.domain.ports import DataAssetRepository


class CommandLog(Protocol):
    async def already_processed(self, idempotency_key: str) -> bool: ...
    async def record(self, idempotency_key: str, asset_id: UUID) -> None: ...


class UnitOfWork(Protocol):
    # Read-only members, so a concrete or fake class with a narrower attribute type
    # still satisfies the port under mypy.
    @property
    def assets(self) -> DataAssetRepository: ...
    @property
    def commands(self) -> CommandLog: ...

    async def __aenter__(self) -> "UnitOfWork": ...
    async def __aexit__(self, exc_type: type[BaseException] | None,
                        exc: BaseException | None, tb: TracebackType | None) -> None: ...
    async def commit(self) -> None: ...
    async def rollback(self) -> None: ...
    def collect_new_events(self) -> Iterable[DomainEvent]: ...
```

`__aexit__` receives the exception triple, which is how the context manager knows whether
the block exited cleanly. The load-bearing rule: **it must roll back unless `commit()` was
explicitly called.**

---

## 2. The concrete `asyncpg` Unit of Work

`__aenter__` acquires a pooled connection and opens its transaction; `__aexit__` commits
only when the caller flagged commit and no exception is propagating, otherwise rolls back.
The connection is released on every path.

```python
# src/classification/adapters/uow.py
from collections.abc import Iterable
from types import TracebackType

import asyncpg

from classification.adapters.command_log import PgCommandLog
from classification.adapters.errors import RepositoryError
from classification.adapters.postgres import DataAssetRepo
from classification.domain.events import DomainEvent


class AsyncpgUnitOfWork:
    """Owns exactly one asyncpg transaction. Rollback is the default.
    Construct one per use-case call: it is not safe to share between coroutines."""

    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool
        self._commit_requested = False
        self._events: list[DomainEvent] = []

    async def __aenter__(self) -> "AsyncpgUnitOfWork":
        self._commit_requested = False
        self._events = []
        self._conn = await self._pool.acquire()
        try:
            self._tx = self._conn.transaction()
            await self._tx.start()
        except BaseException:
            await self._pool.release(self._conn)
            raise
        # Repositories share THIS connection — never open their own transaction.
        self.assets = DataAssetRepo(self._conn)
        self.commands = PgCommandLog(self._conn)
        return self

    async def __aexit__(self, exc_type: type[BaseException] | None,
                        exc: BaseException | None, tb: TracebackType | None) -> None:
        try:
            if exc_type is None and self._commit_requested:
                try:
                    await self._tx.commit()
                except asyncpg.PostgresError as cause:
                    raise RepositoryError("commit failed") from cause
                self._events = list(self.assets.saved_events)
            else:
                await self._tx.rollback()   # DEFAULT: any exception, or no commit()
        finally:
            await self._pool.release(self._conn)

    async def commit(self) -> None:
        # Marks intent; the actual COMMIT happens in __aexit__ so a later
        # exception in the same block still rolls the whole unit back.
        self._commit_requested = True

    async def rollback(self) -> None:
        self._commit_requested = False

    def collect_new_events(self) -> Iterable[DomainEvent]:
        """Events of the last COMMITTED block; empty after a rollback."""
        drained, self._events = self._events, []
        return drained
```

`commit()` sets a flag rather than issuing `COMMIT` immediately. That keeps the whole
`async with` block atomic — if code after `await uow.commit()` (still inside the block)
raises, `__aexit__` sees the exception and rolls back despite the flag. Leaving the block
cleanly is what commits, so a commit-time failure surfaces at the end of the block.

---

## 3. The `FakeUnitOfWork` twin

The biggest day-to-day payoff of the port. It sits in `tests/fakes.py` beside the
`FakeRepository` (`python-repository-pattern`). Writes are staged on a copy and published
only by a committed, clean exit, so a use case that forgets `commit()` leaves no trace —
a state assertion therefore proves the commit. Prefer this fake over a `unittest.mock`
mock: assert on resulting state, not on how the code called its collaborators.

```python
# tests/fakes.py  (continued; FakeRepository and deepcopy are already defined above)
from collections.abc import Iterable
from types import TracebackType

from classification.domain.errors import DuplicateCommandError


class FakeCommandLog:
    def __init__(self, seen: set[str] | None = None) -> None:
        self.seen: set[str] = seen if seen is not None else set()

    async def already_processed(self, idempotency_key: str) -> bool:
        return idempotency_key in self.seen

    async def record(self, idempotency_key: str, asset_id: UUID) -> None:
        if idempotency_key in self.seen:
            raise DuplicateCommandError(asset_id, idempotency_key)
        self.seen.add(idempotency_key)


class FakeUnitOfWork:
    def __init__(self, assets: Iterable[DataAsset] = ()) -> None:
        stored: set[DataAsset] = set()
        for asset in assets:                      # seeded assets count as already persisted
            copy = deepcopy(asset)
            copy.pull_events()
            copy.mark_persisted()
            stored.add(copy)
        self.assets = FakeRepository(stored)
        self.commands = FakeCommandLog()
        self.committed = False
        self.rolled_back = False
        self._events: list[DomainEvent] = []

    async def __aenter__(self) -> "FakeUnitOfWork":
        self.committed = self.rolled_back = False
        self._events = []
        self._snapshot = (set(self.assets.assets), set(self.commands.seen))
        self.assets.saved_events = []
        return self

    async def __aexit__(self, exc_type: type[BaseException] | None,
                        exc: BaseException | None, tb: TracebackType | None) -> None:
        if exc_type is None and self.committed:
            self._events = list(self.assets.saved_events)
            return
        self.assets.assets, self.commands.seen = self._snapshot   # discard staged writes
        self.committed = False
        self.rolled_back = True

    async def commit(self) -> None:
        self.committed = True

    async def rollback(self) -> None:
        self.committed = False

    def collect_new_events(self) -> Iterable[DomainEvent]:
        drained, self._events = self._events, []
        return drained
```

A test drives the whole use case through it:

```python
# tests/unit/service_layer/test_commands.py
from uuid import uuid4
from datetime import datetime, timezone

import pytest

from classification.domain.context import Subject, current_subject, current_tenant
from classification.domain.dataasset import DataAsset
from classification.domain.sensitivity import SensitivityLevel
from classification.service_layer.commands import ClassifyDataAsset, classify_data_asset
from tests.fakes import FakeUnitOfWork


@pytest.mark.asyncio
async def test_classify_commits_once_and_is_idempotent() -> None:
    tenant = uuid4()
    current_tenant.set(tenant)
    current_subject.set(Subject(uuid4(), tenant, frozenset({"data-assets:classify"})))
    asset = DataAsset.register(uuid4(), tenant, uuid4(), datetime.now(timezone.utc))
    uow = FakeUnitOfWork(assets=[asset])
    cmd = ClassifyDataAsset(asset.id, "restricted", idempotency_key="k-1")

    await classify_data_asset(cmd, uow)

    assert uow.committed is True
    stored = await uow.assets.get(asset.id)
    assert stored is not None
    assert stored.sensitivity is SensitivityLevel.RESTRICTED
    assert stored.version_number == 2

    # Second identical delivery is a no-op replay — the key is already recorded.
    await classify_data_asset(cmd, uow)
    assert uow.committed is False                      # nothing to write
    replayed = await uow.assets.get(asset.id)
    assert replayed is not None and replayed.version_number == 2
```

---

## 4. The full command use-case functions

Fixed step order: **idempotency check → load → authorise → domain call → commit** (a
creating use case has nothing to load). The processed-key `record` shares the UoW's one
transaction with the domain write, so a crash cannot split them. Time is injected: the
domain never reads the clock, and a test can pass a fixed one.

```python
# src/classification/service_layer/commands.py
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import UUID

from classification.domain.context import current_subject, tenant_id
from classification.domain.dataasset import DataAsset
from classification.domain.errors import NotFoundError
from classification.domain.sensitivity import SensitivityLevel
from classification.service_layer.unit_of_work import UnitOfWork

Clock = Callable[[], datetime]


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


@dataclass(frozen=True)
class RegisterDataAsset:
    asset_id: UUID
    source_id: UUID
    idempotency_key: str


@dataclass(frozen=True)
class ClassifyDataAsset:
    asset_id: UUID
    sensitivity: str
    idempotency_key: str


async def register_data_asset(cmd: RegisterDataAsset, uow: UnitOfWork,
                              clock: Clock = _utc_now) -> None:
    async with uow:
        if await uow.commands.already_processed(cmd.idempotency_key):
            return
        current_subject.get().require("data-assets:register")
        asset = DataAsset.register(cmd.asset_id, tenant_id(), cmd.source_id, clock())
        await uow.assets.save(asset)
        await uow.commands.record(cmd.idempotency_key, asset.id)
        await uow.commit()


async def classify_data_asset(cmd: ClassifyDataAsset, uow: UnitOfWork,
                              clock: Clock = _utc_now) -> None:
    async with uow:
        if await uow.commands.already_processed(cmd.idempotency_key):
            return                                     # duplicate delivery — replay
        asset = await uow.assets.get(cmd.asset_id)     # load, tenant-scoped repo
        if asset is None:
            raise NotFoundError(cmd.asset_id, tenant_id())
        subject = current_subject.get()                # ContextVar, not a parameter
        subject.require("data-assets:classify", asset.id)  # authorise BEFORE mutate
        level = SensitivityLevel.parse(cmd.sensitivity)
        asset.classify(level, by=subject.user_id, now=clock())   # invariant here
        await uow.assets.save(asset)
        await uow.commands.record(cmd.idempotency_key, asset.id)  # same transaction
        await uow.commit()                             # explicit; absence == rollback
```

A command function returns `None` or the use case's own result DTO, never an
`asyncpg.Record`, a Pydantic request model or an HTTP object. It changes exactly **one**
Aggregate per transaction. A use case that appears to need two Aggregates changed
atomically is a design signal — reconsider the boundary, or emit a Domain Event and let a
second use case react (eventual consistency), never a transaction spanning two.

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
different mechanism: the Aggregate records them during the domain call; the repository's
`save` drains them into the outbox in the same transaction and remembers them; after the
commit the caller takes them from the Unit of Work and gives them to an in-process
message bus that routes each to its handler(s):

```python
# Illustration: after a successful commit, drain and dispatch
async def classify_and_dispatch(cmd, uow, bus):
    await classify_data_asset(cmd, uow)      # commits on leaving its block
    for event in uow.collect_new_events():   # empty if nothing was committed
        await bus.handle(event)              # each handler failing is independent
```

Keep the handler map explicit and readable, not magical:

```python
# Illustration
EVENT_HANDLERS = {
    DataAssetClassified: [refresh_dashboard_cache],
}
```

**Boundary note (do not conflate two layers):** this in-process message bus is Cosmic
Python's *intra-process* events — one Python process, and a crash after commit loses the
dispatch. Use it only for work that may be lost. Cross-context delivery goes through the
Transactional Outbox rows that `save` already wrote inside this UoW transaction
(`python-repository-pattern`), relayed to Redpanda by a separate publisher
(`python-event-publisher`). A handler on this bus never writes the outbox: that would be
a second write after the commit, the dual-write problem again.

---

## 6. Why the service function stays framework-free

The same `classify_data_asset` above is driven identically from three call sites — this
is the whole point of the layer, and the test at §3 is literally the third one:

```python
# Illustration: three call sites
# FastAPI route (python-fastapi-handler owns this edge)
@app.post("/data-assets/{asset_id}/classification", status_code=204)
async def http_classify(asset_id: UUID, body: ClassifyBody,
                        uow: UnitOfWork = Depends(get_uow)):
    cmd = ClassifyDataAsset(asset_id, body.sensitivity, body.idempotency_key)
    await classify_data_asset(cmd, uow)   # no logic here — parse, call, 204

# CLI (sets current_tenant and current_subject itself; there is no middleware)
async def cli_classify(args, pool):
    cmd = ClassifyDataAsset(UUID(args.asset_id), args.sensitivity, args.idempotency_key)
    await classify_data_asset(cmd, AsyncpgUnitOfWork(pool))

# Unit test: the same function against FakeUnitOfWork (§3)
```

No HTTP types, no Pydantic request model, and no `asyncpg` object leak into the use-case
function. That is what makes it uniformly testable and reusable.
