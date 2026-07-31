# The `DomainError` Hierarchy, Chaining, and `__cause__` Inspection

Reference for `python-error-handling`. The `SKILL.md` body states the rules; this file is the full hierarchy, the selection table, worked `raise ... from` chaining, and the rare `__cause__`-walking case.

All code targets Python 3.11+, FastAPI + `asyncpg`, the `DataAsset` bounded context, per-tenant physical isolation.

---

## 1. The base class

One project-root base per service. Everything the service raises on a business-rule or expected-failure path descends from it, so the single boundary handler can catch the whole family with `except DomainError`.

```python
# src/data_asset/domain/errors.py
from __future__ import annotations


class DomainError(Exception):
    """Base for every business-rule / expected failure this service raises.

    Never raised directly — always a concrete subclass, so the boundary
    handler can map each kind to a distinct HTTP status. Carries structured
    attributes on subclasses; the message string is for humans/logs only,
    never the machine-readable contract.
    """
```

`DomainError` subclasses `Exception`, **not** `BaseException` — `BaseException` also covers `KeyboardInterrupt` and `SystemExit`, which must never be caught by application code. `except DomainError` and even a catch-all `except Exception` both leave those two alone, which is correct.

---

## 2. The subclass roster and structured attributes

Each subclass carries the data a caller or the boundary handler needs as **attributes**, set in `__init__`, in addition to the human message. This is the Python equivalent of Go's typed errors: the caller reads `err.asset_id`, never re-parses the message string.

```python
# src/data_asset/domain/errors.py (continued)


class NotFoundError(DomainError):
    """A DataAsset the caller referenced does not exist in this tenant."""

    def __init__(self, asset_id: str, tenant_id: str) -> None:
        super().__init__(f"data asset {asset_id} not found")
        self.asset_id = asset_id
        self.tenant_id = tenant_id


class ValidationError(DomainError):
    """A domain invariant was violated by a well-formed request.

    Distinct from pydantic.ValidationError, which FastAPI raises for a
    malformed request body BEFORE the handler runs. This one is raised
    DEEP, inside the aggregate, when the shape was valid but the rule
    (e.g. 'a classified asset cannot be re-classified') was not.
    """

    def __init__(self, field: str, reason: str) -> None:
        super().__init__(f"invalid {field}: {reason}")
        self.field = field
        self.reason = reason


class ConflictError(DomainError):
    """The requested change conflicts with the asset's current state."""

    def __init__(self, asset_id: str, reason: str) -> None:
        super().__init__(f"conflict on data asset {asset_id}: {reason}")
        self.asset_id = asset_id
        self.reason = reason


class OptimisticConcurrencyError(ConflictError):
    """A CAS-on-version write lost the race — the row moved underneath us.

    Raised by the repository when `UPDATE ... WHERE version = $n` affects
    zero rows. A subclass of ConflictError so the boundary handler maps it
    to the same status without a separate branch, but its own type so the
    service layer can choose to retry the load-mutate-save cycle.
    """

    def __init__(self, asset_id: str, expected_version: int) -> None:
        super().__init__(asset_id, f"expected version {expected_version}, row changed")
        self.expected_version = expected_version
        self.retryable = True


class AuthorizationError(DomainError):
    """The authenticated Subject may not perform this action on this asset."""

    def __init__(self, subject_id: str, action: str, asset_id: str) -> None:
        # Deliberately vague message — see the never-leak rule; details go
        # to the log via attributes, not into a client-visible string.
        super().__init__("not authorized")
        self.subject_id = subject_id
        self.action = action
        self.asset_id = asset_id
```

### Selection table — pick the kind mechanically

| Raise this | When the failure is | Boundary maps it to |
|---|---|---|
| `NotFoundError` | A referenced aggregate does not exist in the tenant | 404 |
| `ValidationError` | A domain invariant is violated by an otherwise well-formed request | 422 |
| `ConflictError` | The change conflicts with current state (duplicate, illegal transition) | 409 |
| `OptimisticConcurrencyError` | A version-CAS write affected zero rows (lost race) | 409 |
| `AuthorizationError` | The Subject lacks permission for the action | 403 |
| `DomainError` (bare subclass) | A business failure none of the above name | 400 |
| Any non-`DomainError` (e.g. `asyncpg.PostgresError` that escaped) | An unexpected/infrastructure failure | 500, opaque |

The exact status mapping and envelope live in `boundary-mapping.md`; this table only fixes *which exception kind to raise* at the site of the failure.

---

## 3. Infrastructure translation — raise a domain error `from` the driver error

Driver exceptions (`asyncpg`, `aiokafka`) are infrastructure vocabulary. They must not travel above the repository/consumer. Translate at that boundary and preserve the original with `from`:

```python
# src/data_asset/adapters/errors.py
class RepositoryError(DomainError):
    """A persistence operation failed for an infrastructure reason.

    A translation target, not a business error — carries no domain
    attributes beyond the operation description. The boundary handler
    maps it (and anything else non-specific) toward a 500.
    """
```

```python
# src/data_asset/adapters/asyncpg_repository.py
import asyncpg

from data_asset.domain.errors import NotFoundError, OptimisticConcurrencyError
from data_asset.adapters.errors import RepositoryError


class AsyncpgDataAssetRepository:
    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool

    async def get(self, asset_id: str, tenant_id: str) -> "DataAsset":
        try:
            async with self._pool.acquire() as conn:
                row = await conn.fetchrow(
                    "SELECT id, tenant_id, status, version "
                    "FROM data_assets WHERE id = $1 AND tenant_id = $2",
                    asset_id,
                    tenant_id,
                )
        except asyncpg.PostgresError as exc:
            # Translate infra -> domain, preserving the driver error as __cause__.
            raise RepositoryError(f"loading data asset {asset_id}") from exc
        if row is None:
            raise NotFoundError(asset_id, tenant_id)
        return _hydrate(row)

    async def save(self, asset: "DataAsset", tenant_id: str) -> None:
        try:
            async with self._pool.acquire() as conn, conn.transaction():
                # CAS on version — the same discipline as go-repository-pattern.
                status = await conn.execute(
                    "UPDATE data_assets SET status = $1, version = version + 1 "
                    "WHERE id = $2 AND tenant_id = $3 AND version = $4",
                    asset.status,
                    asset.id,
                    tenant_id,
                    asset.version,
                )
                # asyncpg returns e.g. 'UPDATE 0' when no row matched.
                if status.endswith(" 0"):
                    raise OptimisticConcurrencyError(asset.id, asset.version)
                await conn.execute(
                    "INSERT INTO outbox (tenant_id, payload) VALUES ($1, $2)",
                    tenant_id,
                    asset.pending_event_json(),
                )
        except asyncpg.PostgresError as exc:
            raise RepositoryError(f"saving data asset {asset.id}") from exc
```

Note `OptimisticConcurrencyError` is raised **inside** the `try` but is a `DomainError`, not an `asyncpg` error, so it propagates untouched — only the `asyncpg.PostgresError` branch translates. Do **not** widen the `except` to `Exception`, which would wrongly re-wrap the domain error you just raised.

---

## 4. `raise ... from cause` — the `%w` analog, worked

`raise NewError(...) from cause` sets `NewError().__cause__ = cause` and prints a `"The above exception was the direct cause of the following exception"` chained traceback. It is the direct analog of Go's `fmt.Errorf("...: %w", err)`.

```python
>>> try:
...     try:
...         1 / 0
...     except ZeroDivisionError as exc:
...         raise ValidationError("ratio", "divisor was zero") from exc
... except ValidationError as e:
...     print(type(e).__name__, "->", type(e.__cause__).__name__)
...
ValidationError -> ZeroDivisionError
```

Three forms, three meanings:

| Form | `__cause__` | `__suppress_context__` | Use when |
|---|---|---|---|
| `raise New() from exc` | `exc` | `True` | Translating a caught exception — **the default when re-raising** |
| `raise New()` (inside `except`) | `None` (but `__context__ = exc`) | `False` | Rare; implicit chaining, weaker signal than `from` |
| `raise New() from None` | `None` | `True` | Deliberately hiding an irrelevant internal cause — needs a comment |

**Always prefer `from exc`** when translating a real failure. `raise New() from None` discards the chain and is an anti-pattern unless the cause is provably noise (documented in a comment). Bare `raise New()` inside an `except` block leaves the original on `__context__`, which still prints but reads as "during handling of X, Y occurred" — a weaker, easily-misread signal than the explicit `from`.

### Never flatten into a string

```python
# WRONG — severs the chain, loses the traceback, the Python twin of
# Go's errors.New(err.Error()).
raise RepositoryError(str(exc))

# WRONG — same defect, hidden inside an f-string.
raise RepositoryError(f"query failed: {exc}")

# RIGHT — the original travels as __cause__; the message adds context only.
raise RepositoryError("loading data asset") from exc
```

---

## 5. The rare `__cause__`-walking case

`isinstance()` matches the **class hierarchy**, never the `__cause__` chain. A `NotFoundError` wrapped inside a `RepositoryError` is **not** `isinstance(err, NotFoundError)` — this is the key divergence from Go's `errors.Is`/`errors.As`, which *do* walk the wrap chain. The standard avoids the situation by translating at each boundary so the top-most exception is already the kind callers branch on.

For the genuinely rare case where you must inspect a wrapped cause, walk `__cause__` explicitly:

```python
def find_in_chain(err: BaseException, kind: type[BaseException]) -> BaseException | None:
    """Walk __cause__ looking for an exception of `kind` — the manual
    equivalent of Go's errors.As over a %w chain. Python's isinstance()
    does NOT do this for you. Prefer boundary translation so you never
    need this; kept for diagnostics and tests only.
    """
    current: BaseException | None = err
    seen: set[int] = set()  # guard against a self-referential __cause__ cycle
    while current is not None and id(current) not in seen:
        if isinstance(current, kind):
            return current
        seen.add(id(current))
        current = current.__cause__
    return None
```

Using it — and why you should not need to in normal flow:

```python
try:
    await repo.get(asset_id, tenant_id)
except RepositoryError as err:
    # In well-structured code you branch on RepositoryError itself; you do
    # NOT reach past it for a NotFoundError, because get() raises
    # NotFoundError directly (not wrapped) for the not-found case. This
    # helper exists for the pathological "was a driver timeout ultimately
    # behind this?" diagnostic, not for control flow.
    original = find_in_chain(err, asyncpg.PostgresError)
```

---

## 6. Testing the hierarchy (per `python-unit-test`)

Assert the **kind and its attributes**, never the message string (which breaks on any rewording). `pytest.raises` captures the exception; `excinfo.value` is the instance.

```python
import pytest

from data_asset.domain.errors import NotFoundError, OptimisticConcurrencyError


async def test_get_missing_asset_raises_not_found(repo, tenant_id):
    with pytest.raises(NotFoundError) as excinfo:
        await repo.get("does-not-exist", tenant_id)
    # Assert the structured attribute, not str(excinfo.value).
    assert excinfo.value.asset_id == "does-not-exist"
    assert excinfo.value.tenant_id == tenant_id


async def test_save_stale_version_raises_concurrency(repo, tenant_id, stale_asset):
    with pytest.raises(OptimisticConcurrencyError) as excinfo:
        await repo.save(stale_asset, tenant_id)
    assert excinfo.value.retryable is True
    # A subclass check confirms the boundary handler's ConflictError branch
    # will also catch it — isinstance walks the CLASS hierarchy.
    from data_asset.domain.errors import ConflictError
    assert isinstance(excinfo.value, ConflictError)


def test_chain_preserved_on_translation():
    from data_asset.adapters.errors import RepositoryError
    cause = ValueError("boom")
    try:
        raise RepositoryError("saving") from cause
    except RepositoryError as err:
        assert err.__cause__ is cause  # the %w chain survived
```

A test that only asserts `pytest.raises(DomainError)` with no attribute or subtype check is the Python twin of Go's bare `if err == nil { t.Fatal() }` — it passes for the wrong exception too, and proves nothing about *which* failure occurred.
