# The Port and the Set-Backed FakeRepository

This is the primary justification for the whole pattern (Percival & Gregory, *Architecture Patterns with Python* / "Cosmic Python", Ch. 2): the repository port exists **so that a fake can stand in for the database in tests**. Decoupling is a bonus; the fake is the payoff. This reference gives the full Protocol port, the set-backed `FakeRepository`, the `FakeUnitOfWork` that pairs with it, and a worked service-layer unit test that never opens a socket to Postgres.

---

## 1. The Port — a `typing.Protocol` in the domain layer

The port is **consumer-defined**: it is declared in the layer that *uses* it (domain / service), not in the infrastructure layer that implements it. This keeps the dependency arrow pointing inward — the `asyncpg` adapter depends on the domain, never the reverse.

```python
# domain/ports.py
from __future__ import annotations
from typing import Protocol
from uuid import UUID

from domain.data_asset import DataAsset


class DataAssetRepository(Protocol):
    """The persistence port for the DataAsset Aggregate.

    Declared here, in the domain layer, so the service layer depends on this
    abstraction and never on asyncpg. Both the real adapter and the fake
    satisfy it *structurally* — neither inherits from it.
    """

    async def get(self, asset_id: UUID) -> DataAsset | None: ...

    async def save(self, asset: DataAsset) -> None: ...

    async def list_by_source(self, source_id: UUID) -> list[DataAsset]: ...
```

### Protocol vs. `abc.ABC` — which to use

`typing.Protocol` is the default for a repository port. It gives **structural typing**: the `asyncpg` adapter satisfies the port merely by having methods of the right shape — it does not `import` or subclass `DataAssetRepository`. This is the closest Python gets to Go's implicit interface satisfaction and keeps the infrastructure layer free of any inward import back into the domain's abstractions.

Reserve `abc.ABC` for the narrow case where you want an explicit base class carrying **shared helper code** that every implementation inherits (e.g. a common `_row_to_domain` mapper). An `ABC` forces `class DataAssetRepo(DataAssetRepository):` — nominal, not structural — and raises `TypeError` at instantiation if an abstract method is unimplemented. For a plain port with no shared code, `Protocol` is the better fit.

**Honest divergence from Go:** neither form is checked at runtime the way Go checks interface satisfaction at compile time. A `Protocol` is only verified when `mypy`/`pyright` runs; an `ABC` catches only *missing* methods at instantiation, not wrong signatures. There is no runtime equivalent of Go's `var _ DataAssetRepository = (*DataAssetRepo)(nil)` compile-time assertion — the equivalent guarantee is a **mandatory `mypy` gate in CI** (`python-tooling`). Without that gate, a drifted fake or adapter ships silently.

---

## 2. The set-backed `FakeRepository`

The fake is a real, working, in-memory implementation of the exact same port — backed by a `set`. It is a handful of lines, and it is what makes the service and domain layers testable with no database at all.

```python
# tests/fakes.py
from uuid import UUID

from domain.data_asset import DataAsset


class FakeRepository:
    """In-memory DataAssetRepository, backed by a set. Satisfies the
    DataAssetRepository Protocol structurally — no inheritance."""

    def __init__(self, assets: list[DataAsset] | None = None) -> None:
        self._assets: set[DataAsset] = set(assets or [])

    async def get(self, asset_id: UUID) -> DataAsset | None:
        return next((a for a in self._assets if a.id == asset_id), None)

    async def save(self, asset: DataAsset) -> None:
        # Set semantics rely on DataAsset hashing/equality by identity (id),
        # so re-saving the same Aggregate id replaces the stored instance.
        self._assets.discard(asset)
        self._assets.add(asset)

    async def list_by_source(self, source_id: UUID) -> list[DataAsset]:
        return [a for a in self._assets if a.source_id == source_id]
```

For the `set` to behave correctly, the `DataAsset` entity must hash and compare **by identity** (its `id`), matching `python-domain-model`'s entity-equality rule:

```python
# domain/data_asset.py  (excerpt — full model in python-domain-model)
def __eq__(self, other: object) -> bool:
    return isinstance(other, DataAsset) and other.id == self.id

def __hash__(self) -> int:
    return hash(self.id)
```

### Why a fake, not a mock

The book's central testing argument: **fakes over mocks.** A mock would assert on *how* the service calls the repository (`repo.save.assert_called_once_with(...)`) — brittle, coupled to implementation, and it re-passes even when the persisted state is wrong. The fake lets the test assert on **state and outcome**: after the use case runs, was the right Aggregate actually stored, at the right version, carrying the right events? That is what a caller cares about, and it survives refactors of the service internals.

---

## 3. The `FakeUnitOfWork` — rollback by default

The service layer opens its transaction through a Unit of Work (`python-service-layer`), so tests need a fake UoW as well. Like the real one, it **defaults to rollback**: `commit()` must be called explicitly, and `__aexit__` rolls back otherwise. This makes "did we forget to commit?" a structurally-answered question even in tests.

```python
# tests/fakes.py  (continued)
class FakeUnitOfWork:
    def __init__(self, assets: list[DataAsset] | None = None) -> None:
        self.assets = FakeRepository(assets)
        self.committed = False

    async def __aenter__(self) -> "FakeUnitOfWork":
        return self

    async def __aexit__(self, *exc: object) -> None:
        # Default is rollback: only an explicit commit() flips `committed`.
        # A no-op rollback here mirrors the real UoW's rollback-on-exit.
        pass

    async def commit(self) -> None:
        self.committed = True

    def collect_new_events(self):
        for asset in self.assets._assets:
            while asset.events:
                yield asset.events.pop(0)
```

---

## 4. Worked service-layer unit test — no database

This is the whole point. A complete use case is driven through the service layer against the fakes; the assertions are on stored state and drained events. It runs in milliseconds, needs no `testcontainers`, no event loop bound to a socket, and no Postgres.

```python
# tests/application/test_register_data_asset.py
import pytest

from application.services import register_data_asset
from tests.fakes import FakeUnitOfWork

pytestmark = pytest.mark.asyncio


async def test_register_persists_asset_and_records_event() -> None:
    uow = FakeUnitOfWork()

    asset_id = await register_data_asset(
        uow,
        source_id=SOME_SOURCE_ID,
        sensitivity_level="confidential",
    )

    # Assert on OUTCOME (the id came back) and STATE (it was stored)...
    stored = await uow.assets.get(asset_id)
    assert stored is not None
    assert stored.sensitivity_level == "confidential"
    assert stored.version == 0

    # ...and that the use case committed and raised the creation event.
    assert uow.committed is True
    events = list(uow.collect_new_events())
    assert any(type(e).__name__ == "DataAssetRegistered" for e in events)


async def test_register_is_rolled_back_on_domain_error() -> None:
    uow = FakeUnitOfWork()

    with pytest.raises(InvalidSensitivityLevel):
        await register_data_asset(uow, source_id=SOME_SOURCE_ID,
                                  sensitivity_level="nonsense")

    assert uow.committed is False          # rollback-by-default proven
    assert list(await uow.assets.list_by_source(SOME_SOURCE_ID)) == []
```

Because both fakes satisfy the same Protocol the real adapter does, a green test here is meaningful: the service code under test is byte-for-byte the code that will run in production against `asyncpg` — only the injected adapter differs. The real adapter is then covered separately, and only once, by the integration suite in `references/asyncpg-adapter.md`.

---

## 5. The Test Pyramid this produces

- **Many fast unit tests** (this file): whole use cases through the service layer against fakes. Assert on state/outcome. No I/O.
- **A few per-Aggregate domain unit tests** (`python-domain-model`): invariants and state transitions, no repository at all.
- **A small integration suite** (`python-integration-test`): the real `asyncpg` adapter against a real PostgreSQL via `testcontainers-python` — real SQL, real CAS conflicts, real constraint violations.

The fake is what makes the wide base of that pyramid cheap. That is the abstraction earning its keep at the test seam — not decoupling for its own sake.
