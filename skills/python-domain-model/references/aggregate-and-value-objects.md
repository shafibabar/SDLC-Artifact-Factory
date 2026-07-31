# Aggregate and Value Objects — Worked Examples

Full worked material referenced from `SKILL.md`'s "Aggregate Root: The Invariant-Enforcement Standard" and "Entity vs Value Object" sections. Self-contained — reads without the parent body already in context. All code targets Python 3.11+, the FastAPI + `asyncpg` stack, and the `DataAsset` domain with per-tenant physical isolation.

---

## The Fallible-Constructor Pattern, and the Anti-Pattern It Replaces

Python has no `(*T, error)` return pair the way Go's `go-domain-model` uses. The idiom is a **classmethod factory** that raises a `DomainError` subclass on a violated invariant, so a caller can never obtain a half-built Aggregate.

**Wrong** — a plain `__init__` that always succeeds, pushing invariant checking onto every caller:

```python
# ANTI-PATTERN: no validation, invariant checking left to whoever remembers.
class DataAsset:
    def __init__(self, id, tenant_id, source_id):
        self.id = id                 # public + unvalidated
        self.tenant_id = tenant_id
        self.source_id = source_id
        self.sensitivity = None
```

Nothing stops `DataAsset(None, None, None)` from constructing. The identity-less asset is now live in memory, indistinguishable from a valid one until something downstream happens to check `id is not None` — if anything ever does. Worse, every attribute is public and mutable, so even a validated instance can be corrupted by `asset.sensitivity = whatever` from any caller.

**Right** — a private `__init__` plus a validating `register` factory; state is private by convention:

```python
# app/domain/data_asset.py
from datetime import datetime
from uuid import UUID

from app.domain.sensitivity import SensitivityLevel
from app.domain.events import DomainEvent, DataAssetRegistered, DataAssetClassified
from app.domain.errors import MissingIdentityError, SensitivityDowngradeError


class DataAsset:
    """Aggregate Root. State is private by convention (leading underscore);
    the only supported way to change it is through a method on this class."""

    def __init__(self, id: UUID, tenant_id: UUID, source_id: UUID, version_number: int):
        # Not called directly by application code — go through register()/reconstitute().
        self._id = id
        self._tenant_id = tenant_id
        self._source_id = source_id
        self._sensitivity = SensitivityLevel.UNCLASSIFIED
        self._version_number = version_number
        self._events: list[DomainEvent] = []

    @classmethod
    def register(cls, id: UUID, tenant_id: UUID, source_id: UUID, now: datetime) -> "DataAsset":
        """Create a NEW asset. Validates the identity invariant, then records the
        creation event. Raises rather than returning a half-built instance."""
        if id is None or tenant_id is None:
            raise MissingIdentityError(id=id, tenant_id=tenant_id)
        asset = cls(id, tenant_id, source_id, version_number=1)
        asset._record(DataAssetRegistered(aggregate_id=id, tenant_id=tenant_id, occurred_at=now))
        return asset

    @classmethod
    def reconstitute(cls, *, id: UUID, tenant_id: UUID, source_id: UUID,
                     sensitivity: SensitivityLevel, version_number: int) -> "DataAsset":
        """Rebuild an EXISTING asset from a stored row. Does NOT re-validate and does
        NOT record events — the data was valid when written, and it already exists.
        Called only by python-repository-pattern's row-to-Aggregate mapping."""
        asset = cls(id, tenant_id, source_id, version_number=version_number)
        asset._sensitivity = sensitivity
        return asset

    # --- read-only accessors (no setters) ---
    @property
    def id(self) -> UUID:
        return self._id

    @property
    def sensitivity(self) -> SensitivityLevel:
        return self._sensitivity

    @property
    def version_number(self) -> int:
        return self._version_number

    # --- the only mutation entry point for sensitivity ---
    def classify(self, level: SensitivityLevel, by: UUID, now: datetime) -> None:
        if self._sensitivity.is_higher_than(level):   # True Invariant: no silent downgrade
            raise SensitivityDowngradeError(asset_id=self._id, from_=self._sensitivity, to=level)
        self._sensitivity = level
        self._version_number += 1
        self._record(DataAssetClassified(
            aggregate_id=self._id, tenant_id=self._tenant_id,
            sensitivity=level, classified_by=by, occurred_at=now))

    # --- event plumbing ---
    def _record(self, event: DomainEvent) -> None:
        self._events.append(event)

    def pull_events(self) -> list[DomainEvent]:
        """Drain recorded events. The service layer calls this after commit and hands
        them to the outbox (python-repository-pattern) / message bus (python-service-layer)."""
        drained, self._events = self._events, []
        return drained
```

The caller cannot obtain a `DataAsset` with a missing identity — `register` raises before `cls(...)` runs. `reconstitute` is a deliberately separate path: it takes the already-persisted `version_number` (rather than resetting it to 1) and records no `DataAssetRegistered`, because re-firing a creation event on every load would tell every downstream consumer the asset was created once per read.

Note the two factories divide the responsibility exactly as Go's `New…`/`Reconstitute` split does — but Python enforces none of it at compile time, which is why the "private by convention" and testing disciplines in `invariants-and-events.md` carry the load Go's compiler carries for free.

---

## Value Objects: `enum.Enum` and Frozen Dataclass

A Value Object has no identity, is compared by value, and is immutable. Python gives two genuinely-enforced shapes for it: an `enum.Enum` for a closed set, and `@dataclass(frozen=True)` for a small record. Both are the *one* place Python's immutability is real rather than conventional — attribute assignment raises at runtime.

### A closed set — `enum.Enum`

```python
# app/domain/sensitivity.py
from enum import Enum


class SensitivityLevel(Enum):
    UNCLASSIFIED = 0
    PUBLIC = 1
    INTERNAL = 2
    CONFIDENTIAL = 3
    RESTRICTED = 4

    def is_valid_classification(self) -> bool:
        # UNCLASSIFIED is the zero value / ordering floor, not a valid *assigned* class.
        return self is not SensitivityLevel.UNCLASSIFIED

    def is_higher_than(self, other: "SensitivityLevel") -> bool:
        return self.value > other.value
```

Enum members are singletons: `SensitivityLevel.PUBLIC is SensitivityLevel.PUBLIC`, equality and hashing come for free, and the member set is closed — a caller cannot invent `SensitivityLevel("bogus")` without an error. This is the cheapest, safest Value Object shape and the one to prefer whenever the data is a closed set of named values. The ordering rank lives in the member `value`, so `is_higher_than` needs no separate lookup table.

### A small record — frozen dataclass, validated in `__post_init__`

When the Value Object holds several fields rather than a single closed choice, use a frozen dataclass. Because `frozen=True` blocks normal attribute assignment, invariant validation and any normalization in `__post_init__` must go through `object.__setattr__`:

```python
# app/domain/retention.py
from dataclasses import dataclass


@dataclass(frozen=True)
class RetentionPolicy:
    """Value Object: how long a DataAsset's contents may be retained, and whether
    a legal hold overrides deletion. Immutable and compared by value."""
    days: int
    legal_hold: bool

    def __post_init__(self) -> None:
        if self.days < 0:
            raise ValueError(f"retention days must be non-negative, got {self.days}")
        # Normalization example: a legal hold forces retention to 'indefinite' (0 == no expiry).
        # Direct assignment would raise FrozenInstanceError — object.__setattr__ is the escape.
        if self.legal_hold and self.days != 0:
            object.__setattr__(self, "days", 0)


# rp1 = RetentionPolicy(days=30, legal_hold=False)
# rp1.days = 60                      # raises dataclasses.FrozenInstanceError
# rp1 == RetentionPolicy(30, False)  # True — value equality, generated by the decorator
# {rp1: "ok"}                        # works — frozen dataclass is hashable
```

`frozen=True` generates value-based `__eq__` and `__hash__`, so two `RetentionPolicy` instances with the same fields are equal and interchangeable as dict keys. The frozen guarantee is genuine: unlike an Aggregate's `_underscore` fields, `object.__setattr__` is the *only* way past it, and it never appears in application code — only inside the VO's own `__post_init__`.

### The collection-field trap: use a tuple, not a list

A frozen dataclass with a **list** or **set** field is not hashable and its "immutability" is a lie — the outer object is frozen but the inner list is still mutable and aliases whatever the caller passed in:

```python
# WRONG: field is a mutable list — not hashable, and aliases the caller's list.
@dataclass(frozen=True)
class AllowedFormats:
    formats: list[str]         # hash(AllowedFormats(["pdf"])) raises TypeError: unhashable

# RIGHT: a tuple is immutable and hashable; normalize in __post_init__.
@dataclass(frozen=True)
class AllowedFormats:
    formats: tuple[str, ...]

    def __post_init__(self) -> None:
        # Accept any iterable, store a sorted tuple — no aliasing, deterministic equality.
        object.__setattr__(self, "formats", tuple(sorted(self.formats)))
```

The tuple choice is the Python analog of `go-domain-model`'s "prefer a comparable representation over a slice field" rule: a `tuple` gives value equality and hashability for free, where a `list`/`set` field forces the object to be unhashable and leaves an aliasing hole. Convert at the boundary (`tuple(sorted(...))`), never store the caller's mutable collection directly.

---

## Entity vs Value Object Equality, Side by Side

The distinction is entirely about equality, and Python expresses each half differently.

```python
# ENTITY — equal by identity. Two DataAssets are the same asset iff their ids match,
# even if every other field differs (one may be a stale in-memory copy of the other).
class DataAsset:
    def __eq__(self, other: object) -> bool:
        return isinstance(other, DataAsset) and self._id == other._id

    def __hash__(self) -> int:
        return hash(self._id)   # identity-based, stable across mutation of other fields


# VALUE OBJECT — equal by value. Two RetentionPolicies are equal iff ALL fields match;
# there is no identity. @dataclass(frozen=True) generates exactly this __eq__/__hash__.
@dataclass(frozen=True)
class RetentionPolicy:
    days: int
    legal_hold: bool
```

Two consequences worth stating explicitly, because getting them backwards is a defect:

- An **entity** must *not* use value equality. If `DataAsset.__eq__` compared every field, then mutating `sensitivity` would change whether two references to *the same asset* are "equal" — nonsense for something with a stable identity. Identity equality means a loaded-then-mutated asset still equals its pre-mutation self.
- A **Value Object** must *not* use identity equality. Two separately-constructed `RetentionPolicy(30, False)` values are genuinely interchangeable; comparing them by `id()` would call two equal policies unequal. `frozen=True` gives the correct value semantics automatically — never hand-roll it.

---

## `pytest` Table Proving the Invariant Is Actually Enforced

Per `SKILL.md`'s Domain-Model Unit-Test Standard, this parametrized test asserts all three axes — invariant raise, immutability-on-reject, event-count-both-ways — for `classify`:

```python
# tests/domain/test_data_asset.py
from datetime import datetime, timezone
from uuid import uuid4

import pytest

from app.domain.data_asset import DataAsset
from app.domain.sensitivity import SensitivityLevel
from app.domain.events import DataAssetClassified
from app.domain.errors import SensitivityDowngradeError

FIXED_NOW = datetime(2026, 7, 31, tzinfo=timezone.utc)


def _registered_asset(start: SensitivityLevel) -> DataAsset:
    asset = DataAsset.register(uuid4(), uuid4(), uuid4(), FIXED_NOW)
    asset._sensitivity = start   # test-only direct set; production code never touches _fields
    asset.pull_events()          # drain the registration event before the assertion
    return asset


@pytest.mark.parametrize(
    "start, target, expect_downgrade",
    [
        (SensitivityLevel.UNCLASSIFIED, SensitivityLevel.PUBLIC, False),  # success
        (SensitivityLevel.PUBLIC, SensitivityLevel.INTERNAL, False),      # success (upgrade)
        (SensitivityLevel.RESTRICTED, SensitivityLevel.PUBLIC, True),     # invariant violation
        (SensitivityLevel.CONFIDENTIAL, SensitivityLevel.INTERNAL, True), # invariant violation
    ],
)
def test_classify(start, target, expect_downgrade):
    asset = _registered_asset(start)

    if expect_downgrade:
        with pytest.raises(SensitivityDowngradeError) as exc:
            asset.classify(target, uuid4(), FIXED_NOW)
        # (1) exact typed error carrying the violating values
        assert exc.value.from_ == start and exc.value.to == target
        # (2) immutability on the rejected path — nothing mutated before the raise
        assert asset.sensitivity == start
        assert asset.version_number == 1
        # (3) event-recording completeness — a rejected call records ZERO events
        assert asset.pull_events() == []
    else:
        asset.classify(target, uuid4(), FIXED_NOW)
        assert asset.sensitivity == target
        assert asset.version_number == 2          # bumped exactly once
        events = asset.pull_events()
        # (3) exactly one event, of the expected type
        assert len(events) == 1
        assert isinstance(events[0], DataAssetClassified)
        assert events[0].sensitivity == target
```

The rejected-call branch checks three things, not one: the exact typed error (with its carried `from_`/`to`), that `sensitivity` and `version_number` are unchanged, and that `pull_events()` drains zero events. A test that only asserted `pytest.raises(SensitivityDowngradeError)` would pass even if `classify` mutated state or bumped the version before raising — it is the immutability and event-count assertions that actually prove "validate before mutate" holds.
</content>
