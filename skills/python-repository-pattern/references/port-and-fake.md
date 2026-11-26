# The Port and the Set-Backed FakeRepository

This is the primary justification for the whole pattern (Percival & Gregory, *Architecture Patterns with Python* / "Cosmic Python", Ch. 2): the repository port exists **so that a fake can stand in for the database in tests**. Decoupling is a bonus; the fake is the payoff. This reference gives the full Protocol port, the set-backed `FakeRepository`, and a service-layer unit test that never opens a socket to Postgres. Paths follow `python-project-structure` (`classification` package).

---

## 1. The port — a `typing.Protocol` in the domain layer

The port is **consumer-defined**: it is declared in the layer that *uses* it (domain), not in the adapter that implements it. This keeps the dependency arrow pointing inward — the `asyncpg` adapter depends on the domain, never the reverse.

```python
# src/classification/domain/ports.py
from typing import Protocol
from uuid import UUID

from classification.domain.dataasset import DataAsset
from classification.domain.events import DomainEvent


class DataAssetRepository(Protocol):
    """The persistence port for the DataAsset Aggregate.

    Both the real adapter and the fake satisfy it *structurally* — neither
    inherits from it. The tenant is read from domain.context, not passed in.
    """

    saved_events: list[DomainEvent]   # events drained by save(), for after-commit dispatch

    async def get(self, asset_id: UUID) -> DataAsset | None: ...

    async def save(self, asset: DataAsset) -> None: ...

    async def list_by_source(self, source_id: UUID) -> list[DataAsset]: ...
```

### Protocol vs. `abc.ABC` — which to use

`typing.Protocol` is the default for a repository port. It gives **structural typing**: the `asyncpg` adapter satisfies the port merely by having members of the right shape — it does not subclass `DataAssetRepository`. This is the closest Python gets to Go's implicit interface satisfaction.

Reserve `abc.ABC` for the narrow case where you want an explicit base class carrying **shared helper code** that every implementation inherits (e.g. a common `_row_to_domain` mapper). An `ABC` forces `class DataAssetRepo(DataAssetRepository):` — nominal, not structural — and raises `TypeError` at instantiation if an abstract method is unimplemented. For a plain port with no shared code, `Protocol` is the better fit.

**Honest divergence from Go:** neither form is checked at runtime the way Go checks interface satisfaction at compile time. A `Protocol` is only verified when `mypy`/`pyright` runs, and only where a value is *used* as the port; an `ABC` catches only *missing* methods at instantiation, not wrong signatures. The equivalent guarantee is a **mandatory `mypy` gate in CI** (`python-tooling`). Without that gate, a drifted fake or adapter ships silently.

---

## 2. The set-backed `FakeRepository`

A real, working, in-memory implementation of the same port. It must behave like the database in the three ways a test could otherwise be fooled by: it hands out **copies** (so a mutation that is never saved is not visible), it checks the **version** on save, and it filters by **tenant**.

```python
# tests/fakes.py
from copy import deepcopy
from uuid import UUID

from classification.domain.context import tenant_id
from classification.domain.dataasset import DataAsset
from classification.domain.errors import ConflictError, OptimisticConcurrencyError
from classification.domain.events import DomainEvent


class FakeRepository:
    """In-memory DataAssetRepository, backed by a set. Satisfies the Protocol
    structurally. Set membership uses DataAsset's identity equality (its id)."""

    def __init__(self, assets: set[DataAsset] | None = None) -> None:
        self.assets: set[DataAsset] = assets if assets is not None else set()
        self.saved_events: list[DomainEvent] = []

    def _stored(self, asset_id: UUID) -> DataAsset | None:
        return next((a for a in self.assets if a.id == asset_id), None)

    async def get(self, asset_id: UUID) -> DataAsset | None:
        found = self._stored(asset_id)
        if found is None or found.tenant_id != tenant_id():
            return None
        return deepcopy(found)

    async def save(self, asset: DataAsset) -> None:
        if asset.tenant_id != tenant_id():
            raise RuntimeError("asset belongs to a different tenant than the context")
        if asset.version_number == asset.persisted_version:
            return                                          # nothing changed
        stored = self._stored(asset.id)
        if asset.persisted_version == 0:
            if stored is not None:
                raise ConflictError(asset.id, "already exists")
        elif stored is None or stored.version_number != asset.persisted_version:
            raise OptimisticConcurrencyError(asset.id, asset.persisted_version)
        self.saved_events.extend(asset.pull_events())
        asset.mark_persisted()
        self.assets.discard(asset)                           # replace by identity
        self.assets.add(deepcopy(asset))

    async def list_by_source(self, source_id: UUID) -> list[DataAsset]:
        return [deepcopy(a) for a in self.assets
                if a.source_id == source_id and a.tenant_id == tenant_id()]
```

The set works only because the `DataAsset` entity hashes and compares **by identity** (its `id`), `python-domain-model`'s entity-equality rule.

### Why a fake, not a mock

The book's central testing argument: **fakes over mocks.** A mock would assert on *how* the service calls the repository (`repo.save.assert_called_once_with(...)`) — brittle, coupled to implementation, and it passes even when the persisted state is wrong. The fake lets the test assert on **state and outcome**: after the use case runs, was the right Aggregate actually stored, at the right version, raising the right events? That is what a caller cares about, and it survives refactors of the service internals.

---

## 3. The Unit of Work fake

The service layer opens its transaction through a Unit of Work, so use-case tests need a fake of that too. `python-service-layer` owns `FakeUnitOfWork` (in the same `tests/fakes.py`): it wraps this `FakeRepository`, publishes its writes only on commit, and rolls back by default. Do not write a second one.

---

## 4. A service-layer unit test — no database

A complete use case (`register_data_asset(cmd, uow)`, `python-service-layer`) driven against the fakes; the assertions are on stored state and raised events. No `testcontainers`, no socket, no Postgres.

```python
# tests/unit/service_layer/test_register_data_asset.py
from uuid import uuid4

import pytest

from classification.domain.context import Subject, current_subject, current_tenant
from classification.domain.errors import AuthorizationError
from classification.service_layer.commands import RegisterDataAsset, register_data_asset
from tests.fakes import FakeUnitOfWork


def _sign_in(*perms: str) -> None:
    tenant = uuid4()
    current_tenant.set(tenant)
    current_subject.set(Subject(user_id=uuid4(), tenant_id=tenant, perms=frozenset(perms)))


@pytest.mark.asyncio
async def test_register_persists_asset_and_raises_event() -> None:
    _sign_in("data-assets:register")
    uow = FakeUnitOfWork()
    cmd = RegisterDataAsset(asset_id=uuid4(), source_id=uuid4(), idempotency_key="k-1")

    await register_data_asset(cmd, uow)

    stored = await uow.assets.get(cmd.asset_id)          # OUTCOME and STATE
    assert stored is not None
    assert stored.source_id == cmd.source_id
    assert stored.version_number == 1
    assert uow.committed is True
    assert [type(e).__name__ for e in uow.collect_new_events()] == ["DataAssetRegistered"]


@pytest.mark.asyncio
async def test_refused_register_stores_nothing() -> None:
    _sign_in()                                           # no permission
    uow = FakeUnitOfWork()
    cmd = RegisterDataAsset(asset_id=uuid4(), source_id=uuid4(), idempotency_key="k-2")

    with pytest.raises(AuthorizationError):
        await register_data_asset(cmd, uow)

    assert uow.committed is False                        # rollback by default
    assert await uow.assets.list_by_source(cmd.source_id) == []
```

A green test here is meaningful because the service code under test is the code that runs in production — only the injected adapter differs. The real adapter is covered separately by the integration suite.

---

## 5. The Test Pyramid this produces

- **Many fast unit tests**: whole use cases through the service layer against fakes. Assert on state/outcome. No I/O.
- **Per-Aggregate domain unit tests** (`python-domain-model`): invariants and state transitions, no repository at all.
- **A small integration suite** (`python-integration-test`): the real `asyncpg` adapter against a real PostgreSQL via `testcontainers-python` — real SQL, real CAS conflicts, real constraint violations.

The fake is what makes the wide base of that pyramid cheap. That is the abstraction earning its keep at the test seam.
