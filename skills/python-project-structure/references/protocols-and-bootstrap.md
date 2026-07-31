# Protocol Ports, Edge Adapters, and the Bootstrap Composition Root

Self-contained reference for `SKILL.md`'s "typing.Protocol Ports" and "The Bootstrap Composition Root" sections. It shows a full port-in-domain / adapter-at-edge pair with no inheritance, the `bootstrap()` composition root wiring real adapters versus fakes, and a worked Dependency Inversion Principle walk-through over the DataAsset domain. This is the Python counterpart to `go-project-structure`'s `references/composition-and-generics.md`, adapted to Python's structural-typing and duck-typing model.

---

## The Port: a `typing.Protocol` in the Domain

A port is an abstraction **owned by the layer that consumes it**. It is declared in `domain/ports.py` (or `service_layer/unit_of_work.py` for the UoW), never beside its implementation. Python's tool is `typing.Protocol` — structural ("static duck") typing:

```python
# src/classification/domain/ports.py — defined by the CONSUMER
from __future__ import annotations
from typing import Protocol
from uuid import UUID

from classification.domain.dataasset import DataAsset


class DataAssetRepository(Protocol):
    """Persistence port for the DataAsset Aggregate. Implemented at the edge."""

    async def get(self, tenant_id: UUID, asset_id: UUID) -> DataAsset | None: ...

    async def add(self, tenant_id: UUID, asset: DataAsset) -> None: ...
```

`tenant_id: UUID` is the first argument of every method deliberately: this product's per-tenant **physical** isolation means every persistence call is tenant-scoped, and putting `tenant_id` in the port signature makes that structurally non-optional — an adapter cannot satisfy the port without accepting it.

---

## The Adapter: Implements the Port **Without Inheriting It**

The `asyncpg` adapter lives in `adapters/postgres.py`. It **does not** subclass `DataAssetRepository`. Structural typing means it satisfies the port simply by having methods of the right shape — the closest Python gets to Go's implicit interface satisfaction, and the reason the dependency arrow points inward (the adapter never imports the port at all):

```python
# src/classification/adapters/postgres.py — the IMPLEMENTATION
from uuid import UUID
import asyncpg

from classification.domain.dataasset import DataAsset
# NOTE: does NOT import domain.ports and does NOT subclass DataAssetRepository.


class AsyncpgRepo:
    """Concrete adapter. Satisfies DataAssetRepository structurally, not by inheritance."""

    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn

    async def get(self, tenant_id: UUID, asset_id: UUID) -> DataAsset | None:
        row = await self._conn.fetchrow(
            "SELECT id, sensitivity, version FROM data_assets "
            "WHERE tenant_id = $1 AND id = $2",
            tenant_id, asset_id,
        )
        return _to_aggregate(row) if row else None

    async def add(self, tenant_id: UUID, asset: DataAsset) -> None:
        await self._conn.execute(
            "INSERT INTO data_assets (tenant_id, id, sensitivity, version) "
            "VALUES ($1, $2, $3, $4)",
            tenant_id, asset.id, asset.sensitivity.value, asset.version,
        )
```

### Making the structural match a *checked* guarantee

Because a `Protocol` is verified **only when `mypy`/`pyright` runs**, add an explicit assertion so the type checker fails at the adapter if its shape drifts from the port — the Python analog of Go's `var _ domain.DataAssetRepository = (*AsyncpgRepo)(nil)` compile-time assertion:

```python
# at the bottom of adapters/postgres.py — checked by mypy/pyright, zero runtime cost
from classification.domain.ports import DataAssetRepository

def _assert_satisfies_port(repo: AsyncpgRepo) -> DataAssetRepository:
    return repo  # mypy error HERE if AsyncpgRepo stops matching the port
```

This one function is the whole reason the static type-check step is a **required CI gate**, not optional: without `mypy`/`pyright` in CI, a renamed or wrong-typed method on `AsyncpgRepo` is caught by nothing until it blows up at runtime when `bootstrap()` injects it. (This helper *does* import `domain.ports`, but it lives beside the adapter as a test-time assertion; if you prefer zero adapter→domain.ports imports even for the assertion, put the same function in the adapter's unit test module instead.)

`@runtime_checkable` on the Protocol would let `isinstance(repo, DataAssetRepository)` run at runtime, but it only checks method *names*, not signatures — it is a weak, partial check and no substitute for the static one. Prefer the `mypy`-checked assertion above.

### Why `Protocol` over `abc.ABC` for ports

| Concern | `typing.Protocol` (preferred) | `abc.ABC` |
|---|---|---|
| Coupling | Adapter needs **no** import of the port — arrow points inward | Adapter must `import` and subclass the ABC — arrow points outward |
| Satisfaction | Structural (duck typing), like a Go interface | Nominal (must inherit) |
| When to use | Every port in this plugin, by default | Only when you want a shared base **with helper code** |

Cosmic Python (Percival & Gregory) leans toward `Protocol`/duck-typed satisfaction over deep inheritance trees for exactly this reason — it keeps the domain from depending on its adapters.

---

## The Bootstrap Composition Root

`bootstrap.py` is the one module that constructs concrete adapters and injects them — the Python analog of Go's `cmd/server/main.go`. Crucially, it wires **real adapters for production and fakes for tests through the same entry point**, so the assembled object graph a unit test drives is built by identical code to the one production runs:

```python
# src/classification/bootstrap.py — the composition root
from __future__ import annotations

from classification.service_layer.unit_of_work import UnitOfWork
from classification.service_layer.messagebus import MessageBus, HANDLERS
from classification.adapters.uow import AsyncpgUnitOfWork
from classification.adapters.messaging import AiokafkaPublisher


def bootstrap(
    uow: UnitOfWork | None = None,
    publish=None,
) -> MessageBus:
    """Wire the object graph. Pass fakes in tests; defaults build real adapters."""
    if uow is None:                                  # None => production default
        uow = AsyncpgUnitOfWork()                    # real asyncpg-backed UoW
    if publish is None:
        publish = AiokafkaPublisher().publish        # real Redpanda publisher

    return MessageBus(uow=uow, handlers=HANDLERS, publish=publish)
```

Two disciplines make this a *composition root* and not just a factory:

1. **It only wires — it decides nothing about the domain.** Every branch is `if <dependency> is None` — i.e. "was a real or fake dependency supplied?" — never a branch on business state. The moment `bootstrap()` contains `if asset.sensitivity == "restricted"`, that decision is untestable without booting the whole app, and it belongs in the domain.
2. **Real vs. fake is the *only* thing it varies.** A test calls `bootstrap(uow=FakeUnitOfWork())` and gets the same message bus, same handlers, same wiring — only the edge swapped. This is the payoff the ports exist for (Cosmic Python's most-cited justification): database-free service/domain unit tests, with the real `asyncpg` adapter exercised only by a small `testcontainers` integration suite.

### Wiring `bootstrap()` into FastAPI

FastAPI's `lifespan` (see `python-service-skeleton`) calls `bootstrap()` **once** at startup and shares the result through `Depends()` — dependencies are constructed once, not per request, not looked up ad hoc inside a handler:

```python
# src/classification/entrypoints/fastapi_app.py (excerpt)
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends

from classification.bootstrap import bootstrap


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.bus = bootstrap()      # real adapters, once, at startup
    yield
    # reverse-order shutdown handled here / by the UoW's own close

app = FastAPI(lifespan=lifespan)


def get_bus(request) -> "MessageBus":
    return request.app.state.bus     # injected via Depends into each route
```

---

## The Dependency Inversion Principle, Worked

DIP: high-level policy must not depend on low-level detail; both depend on an abstraction. Trace it through the DataAsset reclassify use case:

1. **Policy** (`service_layer/commands.py`) depends on the **abstraction** `DataAssetRepository` (the Protocol), never on `AsyncpgRepo`:

   ```python
   async def reclassify_asset(cmd, uow: UnitOfWork) -> None:
       async with uow:                                  # UoW is a Protocol too
           asset = await uow.assets.get(cmd.tenant_id, cmd.asset_id)
           if asset is None:
               raise AssetNotFound(cmd.asset_id)        # domain exception, raised deep
           asset.reclassify(cmd.new_sensitivity)        # the invariant lives in the Aggregate
           await uow.commit()
   ```

   Nothing in this function names `asyncpg`, `aiokafka`, HTTP, or Postgres. It is pure use-case orchestration against abstractions.

2. **Detail** (`adapters/postgres.py`) depends inward on the same abstraction by *matching its shape* — the `AsyncpgRepo` above.

3. **The composition root** (`bootstrap.py`) is the one place the two meet — it injects the concrete `AsyncpgRepo` (via the `AsyncpgUnitOfWork`) into the policy. The dependency arrow at every other point in the codebase points inward, toward the domain; only `bootstrap.py` sits outside every ring as the plug that connects them, exactly as Go's `main.go` does.

The result: swapping `asyncpg` for a different driver, or the real UoW for a `FakeUnitOfWork`, is a change in `bootstrap.py` and the adapter module only — the domain and service layers never move. That is the Dependency Rule and DIP holding together, enforced at build time by the import-linter contracts in `references/layout-and-import-linter.md` and by the `mypy`/`pyright` gate on the `Protocol` shapes.
