# Fakes, Async, and Coverage — Worked Reference

The discipline layer: *when* to fake vs. mock (Khorikov's managed/unmanaged distinction and the
four pillars), the concrete `FakeRepository`/`FakeUnitOfWork` these skills use, `pytest-asyncio`
configuration for an all-async stack, the narrow `pytest-mock` use reserved for the unmanaged edge,
and coverage as a lagging signal. Self-contained; all code is `pytest` + `pytest-asyncio` for the
FastAPI + asyncpg + aiokafka stack.

---

## 1. The four pillars — the "why" behind every rule

Khorikov scores every unit test on four pillars, held as **multiplicative, not additive** — a zero
on any one zeroes the product:

1. **Protection against regressions** — does it catch a real bug?
2. **Resistance to refactoring** — does it stay green through a behaviour-preserving refactor, or
   throw false positives?
3. **Fast feedback** — milliseconds, in-memory, no I/O.
4. **Maintainability** — cheap to read and change.

The trap is over-optimizing one pillar at another's expense. Asserting a private call count
*looks* like more protection (pillar 1) but destroys resistance to refactoring (pillar 2): any
internal restructuring that preserves behaviour still reddens the test, training the team to
distrust red. A well-decoupled test stays green through any refactor that preserves behaviour and
fails only when observable behaviour changes.

---

## 2. Managed vs. unmanaged — what earns a mock at all

The single decision that determines how much a codebase mocks:

| Dependency kind | Definition | Verify by | Tool |
|---|---|---|---|
| **Managed** | Fully under your control, reachable **only** through your code (your Postgres, your outbox table) | Its **end state** | Set-backed **fake** (unit) or a `testcontainers-python` **integration test** (real) |
| **Unmanaged** | Side effect observable **outside** your app's control (an aiokafka publish, a third-party HTTP/SMTP call) | The **interaction** itself | A `pytest-mock` `mocker` patch verifying the call |

A repository is a **managed** dependency. Verifying it with a call-count mock (`assert
repo.save.called`) is Khorikov's classical-school violation — it couples the test to *how* the code
persists rather than *what* ends up persisted. Use a fake and assert on resulting state.

An aiokafka producer is an **unmanaged** dependency: the message crossing the broker boundary is
observable to other services, so the interaction *is* the behaviour. Here a `mocker` patch
asserting "published this event, to this topic, with this key" is correct and the only tool.

**Never assert on a stub.** A double that only supplies canned input (a stub) must never have its
calls verified. If you find yourself wanting to verify a stub's calls, it is functioning as a mock
and the test should say so — otherwise you have coupled to an implementation detail with zero
behavioural payoff.

---

## 3. FakeRepository — set-backed, drop-in

The Repository port (`python-repository-pattern`) is a `typing.Protocol`, so a fake is a three-line
drop-in backed by a `dict`/`set`. Because the port is an abstraction, the domain and service layers
get fast, database-free unit tests while the real `asyncpg` repository is exercised only by a few
integration tests. This test-seam leverage is the primary reason the port exists.

```python
# tests/fakes.py  (imported by tests/conftest.py, not by production code)
from src.domain.data_asset import DataAsset


class FakeRepository:
    """In-memory stand-in for the asyncpg repository. Managed dependency → fake, not mock."""

    def __init__(self, initial: list[DataAsset] | None = None) -> None:
        self._by_id: dict[str, DataAsset] = {a.id: a for a in (initial or [])}

    # --- async surface matching the real repository's Protocol ---
    async def get(self, asset_id: str) -> DataAsset | None:
        return self._by_id.get(asset_id)

    async def add(self, asset: DataAsset) -> None:
        self._by_id[asset.id] = asset

    # --- test-only conveniences (never on the production port) ---
    def seed(self, *assets: DataAsset) -> None:
        for a in assets:
            self._by_id[a.id] = a

    def get_sync(self, asset_id: str) -> DataAsset | None:
        return self._by_id.get(asset_id)
```

Assertions read the fake's **state** (`repo.get_sync(id).sensitivity`), never its call log.

---

## 4. FakeUnitOfWork — no-op commit, records outcome

The Unit of Work (`python-service-layer`) is an async context manager that defaults to rollback.
Its fake records whether `commit()` was called and exposes fake repositories inside it — so a
service test proves rollback-by-default through **observable state** (`uow.committed is False`),
not through a mock's interaction log.

```python
# tests/fakes.py
class FakeUnitOfWork:
    def __init__(self) -> None:
        self.assets = FakeRepository()
        self.committed = False
        self._entered = False

    async def __aenter__(self) -> "FakeUnitOfWork":
        self._entered = True
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        # rollback-by-default: on any exception, or no explicit commit, nothing "persists"
        if exc_type is not None:
            self.committed = False

    async def commit(self) -> None:
        self.committed = True

    async def aclose(self) -> None:
        self._entered = False
```

```python
# tests/conftest.py
import pytest
from tests.fakes import FakeUnitOfWork

@pytest.fixture
async def fake_uow():
    uow = FakeUnitOfWork()
    yield uow
    await uow.aclose()
```

---

## 5. pytest-asyncio configuration — load-bearing, not optional

The stack is `async def` end to end, so unit tests are coroutines. Configure `asyncio_mode = "auto"`
so `async def test_` functions and `async def … yield` fixtures run under an event loop with **no**
per-test `@pytest.mark.asyncio` decorator.

```toml
# pyproject.toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
addopts = "--strict-markers -ra"
markers = [
    "integration: real dependency via testcontainers (slow); excluded from the fast inner loop",
]
```

**The silent-pass hazard.** If `asyncio_mode` is unset and the `@pytest.mark.asyncio` decorator is
missing, pytest collects the `async def test_` function, calls it, gets a coroutine object back,
never awaits it, and reports the test **passed** — while zero assertions ran. This is the async
analog of an assertion-free test and has no Go equivalent (`testing.T` runs synchronously). Guard
it two ways: keep `asyncio_mode = "auto"` in config, and let one deliberately-failing async test in
CI prove the loop is actually driving coroutines.

Run the fast inner loop excluding integration tests:

```
pytest -m "not integration" --cov=src --cov-report=term-missing
```

---

## 6. pytest-mock — reserved for the unmanaged edge only

`pytest-mock` exposes patching as a `mocker` fixture with automatic per-test teardown (no nested
`with patch(...)` stacks). Use it **only** for the unmanaged edge — an aiokafka publish, a
third-party HTTP call — where the interaction is the observable behaviour.

```python
# tests/application/test_publish_reclassified.py
async def test_reclassify_publishes_domain_event(fake_uow, make_data_asset, mocker):
    # Arrange — patch the UNMANAGED edge (the broker), not the repository
    publish = mocker.patch("src.infrastructure.events.producer.publish", autospec=True)
    asset = make_data_asset()
    fake_uow.assets.seed(asset)
    # Act
    await reclassify_asset(ReclassifyAsset(asset_id=asset.id, sensitivity="restricted"), fake_uow)
    # Assert the INTERACTION — the message crossing the broker boundary IS the behaviour
    publish.assert_awaited_once()
    topic, event = publish.await_args.args
    assert topic == "data-asset.reclassified"
    assert event.asset_id == asset.id
```

Use `autospec=True` so the patch matches the real signature (a wrong-arity call fails loudly rather
than silently accepting anything). Note this is the *one* place an interaction assertion is
correct — the managed repository in the same test stays a fake, asserted by state.

---

## 7. Coverage — a signal, never a target

Wire `pytest-cov` for a **gap signal** only. Coverage reports that a line executed, not that a
meaningful assertion ran — an assertion-free test inflates it to 100% while catching nothing, and
it cannot measure resistance to refactoring or maintainability at all.

```
pytest --cov=src --cov-report=term-missing --cov-report=xml
```

Suggested per-layer expectation, applied as a *floor to investigate below*, never a bar to game:

| Layer | Expectation | Rationale |
|---|---|---|
| `src/domain` (quadrant 1) | High (~90%+) | Pure logic, few collaborators — the best unit-test ROI; genuinely coverable |
| `src/application` (service) | Moderate–high | Orchestration tested against fakes; some branches are integration-only |
| `src/infrastructure` (adapters) | Low at unit layer | Real-dependency code — covered by `testcontainers` integration tests, not unit |

The honest caveat (Khorikov): a coverage number can suggest under-tested code (a useful *negative*
signal) but can never certify a suite is good. Pair it with `python-mutation-test` for the
regression-protection axis it cannot measure — a survived mutant is a real gap a green coverage
report will happily hide.
