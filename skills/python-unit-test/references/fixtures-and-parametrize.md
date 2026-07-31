# Fixtures and Parametrize — Worked Reference

Full mechanics for the two idioms that replace Go's table-driven struct: `@pytest.fixture`
(dependency injection by name) and `@pytest.mark.parametrize` (the example table). Self-contained
worked DataAsset domain and service unit tests at the end. All code is `pytest` + `pytest-asyncio`
for the FastAPI + asyncpg + aiokafka stack; no code here touches a real database — that is the
whole point of the unit layer.

---

## 1. Fixture scopes

A fixture's `scope=` decides how often its setup runs. The lever turns an expensive resource from
per-test cost into per-run cost — but at the unit layer you almost always want `function` (the
default) so no state leaks between tests.

| Scope | Setup runs | Unit-layer use |
|---|---|---|
| `function` (default) | Once per test function | The default. Fresh fakes, factories, injected clock. |
| `class` | Once per test class | Rare at unit layer; a read-only value shared by grouped cases. |
| `module` | Once per test module | A precomputed read-only corpus; never mutable state. |
| `session` | Once per whole `pytest` run | Expensive real resources (async engine, testcontainer) — an **integration**-layer concern, not this skill's. |

Rule of thumb: if a fixture returns anything a test **mutates**, it must be `function`-scoped, or
one test's mutation bleeds into the next and `-p no:randomly` ordering hides the bug.

```python
import pytest

@pytest.fixture                      # function scope — a fresh set every test
def asset_repo() -> "FakeRepository":
    return FakeRepository()
```

---

## 2. `yield` teardown

A fixture that `yield`s runs everything before the `yield` as setup and everything after as
teardown. Teardown is guaranteed even when the test fails or raises — pytest unwinds the fixture
stack regardless. This is the composable replacement for xUnit `setUp`/`tearDown`.

```python
@pytest.fixture
def frozen_clock():
    clock = FrozenClock(at="2026-07-31T00:00:00Z")   # setup
    yield clock                                       # value injected into the test
    clock.reset()                                     # teardown — runs even if the test failed
```

For async resources the fixture is an async generator (`async def … yield`); `pytest-asyncio` in
`asyncio_mode = "auto"` awaits both halves without a decorator (see `fakes-async-coverage.md`).

```python
@pytest.fixture
async def fake_uow():
    uow = FakeUnitOfWork()
    yield uow
    await uow.aclose()                                # async teardown, still guaranteed
```

---

## 3. `conftest.py` layering — auto-discovery, never import

Fixtures placed in `conftest.py` are visible to every test file in that directory tree **with no
import**. Nested `conftest.py` files layer: a top-level `tests/conftest.py` holds project-wide
factories and fakes; a `tests/application/conftest.py` adds service-layer-only fixtures. A test
that cannot see a fixture is proof the fixture is in the wrong `conftest.py` — never fix it with an
import, move the fixture.

```
tests/
  conftest.py                 # make_data_asset factory, FakeRepository, frozen_clock
  domain/
    test_data_asset.py        # sees everything in tests/conftest.py
  application/
    conftest.py               # fake_uow (service-layer only)
    test_classify_asset.py    # sees both conftest.py layers
```

---

## 4. Factory fixtures — many configured instances

When a test needs *many* configured domain objects, a fixture returns a **factory** — an inner
function the test calls with parameters — instead of one fixed object. This keeps per-tenant /
per-sensitivity tests readable and stops every test re-specifying the whole object. It is the unit
analog of `test-fixture-design`'s builder pattern.

```python
# tests/conftest.py
from datetime import datetime, timezone
import pytest
from src.domain.data_asset import DataAsset, Sensitivity

@pytest.fixture
def make_data_asset():
    """Factory fixture: returns valid DataAsset instances with sensible defaults."""
    def _make(
        *,
        tenant: str = "acme",
        name: str = "customers.csv",
        sensitivity: Sensitivity = Sensitivity.INTERNAL,
        created: datetime | None = None,
    ) -> DataAsset:
        return DataAsset.create(
            tenant_id=tenant,
            name=name,
            sensitivity=sensitivity,
            now=created or datetime(2026, 7, 31, tzinfo=timezone.utc),   # injected clock, never wall-clock
        )
    return _make
```

A test then reads as one line per intent: `asset = make_data_asset(tenant="globex",
sensitivity=Sensitivity.RESTRICTED)`.

---

## 5. Parametrize — the example table as data

`@pytest.mark.parametrize(argnames, rows, ids=...)` expands one test function into N independent
cases. Each row is reported with its own id as its own pass/fail, so a failure names the exact
case — Specification by Example in code. **Always** give explicit `ids=`; without them a failure
reads `test_outranks[0-1-2]` and tells you nothing.

Two spellings of the same table:

```python
# Per-row id inline via pytest.param — preferred when rows are heterogeneous
import pytest
from src.domain.data_asset import Sensitivity

@pytest.mark.parametrize(
    ("higher", "lower", "expected"),
    [
        pytest.param(Sensitivity.RESTRICTED, Sensitivity.INTERNAL, True,  id="restricted-outranks-internal"),
        pytest.param(Sensitivity.INTERNAL,   Sensitivity.PUBLIC,   True,  id="internal-outranks-public"),
        pytest.param(Sensitivity.PUBLIC,     Sensitivity.PUBLIC,   False, id="equal-does-not-outrank"),
        pytest.param(Sensitivity.PUBLIC,     Sensitivity.RESTRICTED, False, id="public-never-outranks-restricted"),
    ],
)
def test_outranks(higher, lower, expected):
    # Act + Assert — one observable behaviour, driven by the row
    assert higher.outranks(lower) is expected
```

The case `public-never-outranks-restricted` is the important guard: it proves the ordering is a
strict total order and the lowest level never outranks the highest — the row a naive `>=`
implementation silently gets wrong. Adding a fifth sensitivity level is adding a `pytest.param`
row, never a new test function.

A fixture itself can be parametrized (`@pytest.fixture(params=[...])`) to run the whole dependent
suite across variants — e.g. every service test re-run under two tenant configurations:

```python
@pytest.fixture(params=["acme", "globex"], ids=["tenant-acme", "tenant-globex"])
def tenant_id(request):
    return request.param        # every test using `tenant_id` runs twice, once per tenant
```

---

## 6. Worked DataAsset **domain** unit test (no I/O)

The quadrant-1 case: high domain complexity, zero collaborators — the best return on unit-test
investment. Pure, in-memory, parametrized, asserting observable behaviour through the public
surface only.

```python
# tests/domain/test_data_asset.py
import pytest
from src.domain.data_asset import DataAsset, Sensitivity
from src.domain.errors import EmptyTenantError, IllegalDowngradeError


@pytest.mark.parametrize(
    ("tenant", "raises"),
    [
        pytest.param("acme", None,             id="valid-tenant-constructs"),
        pytest.param("",     EmptyTenantError, id="empty-tenant-rejected"),
        pytest.param("   ",  EmptyTenantError, id="whitespace-tenant-rejected"),
    ],
)
def test_create_validates_tenant(make_data_asset, tenant, raises):
    if raises is None:
        asset = make_data_asset(tenant=tenant)
        assert asset.tenant_id == tenant            # observable state, not a private field
    else:
        with pytest.raises(raises):
            make_data_asset(tenant=tenant)


def test_classify_raises_on_illegal_downgrade(make_data_asset):
    # Arrange — a restricted asset
    asset = make_data_asset(sensitivity=Sensitivity.RESTRICTED)
    # Act + Assert — downgrading violates the invariant; the Aggregate refuses
    with pytest.raises(IllegalDowngradeError):
        asset.classify(Sensitivity.PUBLIC)
    assert asset.sensitivity is Sensitivity.RESTRICTED   # state unchanged after the rejected call
```

Note `pytest.raises` as the idiom for asserting a raised domain exception — the AAA "assert" for
the error path. Assert on the exception *type* (a domain error class), never its message string;
message text is not a contract.

---

## 7. Worked DataAsset **service** unit test (against a fake)

The quadrant-3-adjacent case: a use-case function orchestrating the Aggregate through the Unit of
Work. Driven entirely through a `FakeUnitOfWork` (defined in `fakes-async-coverage.md`) so it
touches no database, and asserting on **resulting state**, not on how the code called its
collaborators.

```python
# tests/application/test_classify_asset.py
import pytest
from src.application.commands.classify_data_asset import classify_data_asset, ClassifyDataAsset
from src.domain.data_asset import Sensitivity
from src.domain.errors import NotFoundError


async def test_classify_persists_new_sensitivity(fake_uow, make_data_asset):
    # Arrange — seed the fake repo with an asset inside the fake UoW
    asset = make_data_asset(sensitivity=Sensitivity.INTERNAL)
    fake_uow.assets.seed(asset)
    cmd = ClassifyDataAsset(asset_id=asset.id, sensitivity=Sensitivity.RESTRICTED,
                            idempotency_key="k-1")
    # Act — one use case
    await classify_data_asset(cmd, fake_uow)
    # Assert — observable end state, and that the UoW committed
    assert fake_uow.assets.get_sync(asset.id).sensitivity is Sensitivity.RESTRICTED
    assert fake_uow.committed is True


async def test_classify_unknown_asset_raises_and_does_not_commit(fake_uow):
    cmd = ClassifyDataAsset(asset_id="missing", sensitivity=Sensitivity.RESTRICTED,
                            idempotency_key="k-2")
    with pytest.raises(NotFoundError):
        await classify_data_asset(cmd, fake_uow)
    assert fake_uow.committed is False        # rollback-by-default proven through state
```

`fake_uow.committed` is an **observable outcome of the fake**, not an interaction assertion on a
mock — the fake records whether `commit()` ran and the test reads that state. This is the
fakes-over-mocks discipline in practice: no `assert repo.save.called`, no call-count check.

---

## 8. Running a single case

Parametrized cases are addressable by id for a fast focused loop:

```
pytest tests/domain/test_data_asset.py -k "empty-tenant-rejected"
pytest "tests/domain/test_data_asset.py::test_outranks[public-never-outranks-restricted]"
```

Both run exactly one row — the Python analog of Go's `go test -run
TestOutranks/public-never-outranks-restricted`.
