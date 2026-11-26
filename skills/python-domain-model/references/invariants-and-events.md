# Invariants, Domain Events, and the Encapsulation Discipline — Worked Examples

Full worked material referenced from `SKILL.md`'s "Invariant-Guarding Methods and Domain Errors", "The Honest Encapsulation Gap vs Go", and "Domain-Model Unit-Test Standard" sections. Self-contained — reads without the parent body already in context. Targets Python 3.11+, FastAPI + `asyncpg`, the `DataAsset` domain.

---

## The `DomainError` Hierarchy — One Typed Error Per Data-Carrying Invariant

`python-error-handling` owns the general exception hierarchy and the single FastAPI boundary handler; this file owns the domain-specific rule built on top of it: **a parameter-free invariant (existence, permission) can be a bare `DomainError` subclass with no attributes; any invariant whose violation carries diagnostic data gets its own subclass carrying those values as typed attributes — never a bare `raise Exception("...")` and never a single stringly-typed bucket.**

**Wrong** — every invariant funneled through a generic exception or a string-keyed bucket:

```python
# ANTI-PATTERN A: stringly-typed, no structured data recoverable by a catcher.
if self._sensitivity.is_higher_than(level):
    raise Exception("cannot downgrade sensitivity")

# ANTI-PATTERN B: a generic bucket "solves" the missing-data problem by trading
# typed attribute access for a dict whose keys a caller has to know and guess the types of.
class InvariantViolationError(Exception):
    def __init__(self, rule: str, details: dict):
        self.rule, self.details = rule, details

if self._sensitivity.is_higher_than(level):
    raise InvariantViolationError("no-downgrade", {"from": self._sensitivity, "to": level})
# caller: err.details["from"]  — no autocomplete, no type check, breaks silently on a key rename
```

**Right** — a named subclass per invariant carrying its own violating values as real attributes:

```python
# src/classification/domain/errors.py
from __future__ import annotations

from typing import TYPE_CHECKING
from uuid import UUID

if TYPE_CHECKING:  # type hints only; sensitivity.py imports this module at runtime
    from classification.domain.sensitivity import SensitivityLevel


class DomainError(Exception):
    """Base of the domain exception family. python-error-handling maps this whole
    family to HTTP status once, via a single FastAPI @app.exception_handler(DomainError)."""


# --- the shared taxonomy (python-error-handling names it and maps it) -------------

class NotFoundError(DomainError):
    def __init__(self, asset_id: UUID, tenant_id: UUID):
        super().__init__(f"data asset {asset_id} not found")
        self.asset_id, self.tenant_id = asset_id, tenant_id


class ValidationError(DomainError):
    def __init__(self, field: str, reason: str):
        super().__init__(f"invalid {field}: {reason}")
        self.field, self.reason = field, reason


class ConflictError(DomainError):
    def __init__(self, asset_id: UUID, reason: str):
        super().__init__(f"conflict on data asset {asset_id}: {reason}")
        self.asset_id, self.reason = asset_id, reason


class OptimisticConcurrencyError(ConflictError):
    def __init__(self, asset_id: UUID, expected_version: int):
        super().__init__(asset_id, f"expected version {expected_version}, row changed")
        self.expected_version = expected_version
        self.retryable = True


class AuthorizationError(DomainError):
    def __init__(self, subject_id: UUID, action: str, asset_id: UUID | None = None):
        super().__init__("not authorized")
        self.subject_id, self.action, self.asset_id = subject_id, action, asset_id


class ViewUnavailableError(DomainError):
    def __init__(self, tenant_id: UUID):
        super().__init__("read model unavailable")
        self.tenant_id = tenant_id


# --- DataAsset's own failures -----------------------------------------------------

class MissingIdentityError(ValidationError):
    def __init__(self, id: UUID | None, tenant_id: UUID | None, source_id: UUID | None):
        super().__init__("identity", "id, tenant_id and source_id are required")
        self.id, self.tenant_id, self.source_id = id, tenant_id, source_id


class InvalidSensitivityError(ValidationError):
    def __init__(self, raw_value: str):
        super().__init__("sensitivity", f"{raw_value!r} is not an assignable level")
        self.raw_value = raw_value


class SensitivityDowngradeError(ConflictError):
    """Data-carrying: from_/to are needed by the caller (409 body, audit log)."""
    def __init__(self, asset_id: UUID, from_: SensitivityLevel, to: SensitivityLevel):
        super().__init__(asset_id, f"cannot downgrade sensitivity {from_.name} -> {to.name}")
        self.from_, self.to = from_, to


class DuplicateCommandError(ConflictError):
    """A concurrent delivery of the same Command recorded its key first."""
    def __init__(self, asset_id: UUID, idempotency_key: str):
        super().__init__(asset_id, "command already processed")
        self.idempotency_key = idempotency_key
```

The request context lives in the domain package too, because both the service layer and the
adapters read it and neither may import the other:

```python
# src/classification/domain/context.py
import contextvars
from dataclasses import dataclass
from uuid import UUID

from classification.domain.errors import AuthorizationError


@dataclass(frozen=True)
class Subject:
    user_id: UUID
    tenant_id: UUID
    perms: frozenset[str]

    def require(self, perm: str, asset_id: UUID | None = None) -> None:
        if perm not in self.perms:
            raise AuthorizationError(self.user_id, perm, asset_id)


# The ContextVar OBJECT is a module global; its VALUE is per execution context.
current_tenant: contextvars.ContextVar[UUID] = contextvars.ContextVar("current_tenant")
current_subject: contextvars.ContextVar[Subject] = contextvars.ContextVar("current_subject")
current_trace_id: contextvars.ContextVar[str] = contextvars.ContextVar("current_trace_id")


def tenant_id() -> UUID:
    try:
        return current_tenant.get()
    except LookupError:
        # A missing tenant must never silently become a cross-tenant query.
        raise RuntimeError("tenant id missing from context") from None
```

A caller catches the specific type and reads its attributes back, typed — no dict, no guessing:

```python
try:
    asset.classify(level, by=actor_id, now=now)
except SensitivityDowngradeError as err:
    audit.log("sensitivity-downgrade-blocked", asset=err.asset_id, from_=err.from_, to=err.to)
    raise            # re-raise; the FastAPI boundary handler turns it into a 409
```

`raise Exception("cannot downgrade")` cannot do this — the `from_`/`to` values are gone the instant the f-string is built.

### The `raise ... from cause` Chaining Rule

When a domain error is triggered by catching a lower-level one, chain it explicitly with `from` — Python's native analog of Go's `%w` wrapping. This sets `__cause__`, preserving the original traceback for logs without leaking it to the client:

```python
try:
    level = SensitivityLevel[raw_value.upper()]
except KeyError as cause:
    raise InvalidSensitivityError(raw_value) from cause   # __cause__ = the KeyError
```

Never omit `from cause` when translating inside an `except` block: Python then sets only `__context__` ("during handling of the above exception, another exception occurred"), leaves `__cause__` as `None`, and the traceback reads like a second bug rather than a translation. And never chain in the *other* direction (catching a `DomainError` to re-raise a generic one) — the domain error is already the most specific, most useful type at that point.

### Classifying the `DataAsset` Error Roster

| Invariant | Carries data? | Standard |
|---|---|---|
| Missing identity (`id`/`tenant_id`/`source_id` is `None`) | Which one was missing | `MissingIdentityError` (a `ValidationError`) |
| Unknown or unassignable sensitivity | The rejected value | `InvalidSensitivityError(raw_value)` (a `ValidationError`) |
| Silent downgrade attempted | Yes — `from_`/`to` needed by caller (audit, 409) | `SensitivityDowngradeError(asset_id, from_, to)` (a `ConflictError`) |
| Actor lacks the permission (checked in the service layer, not the Aggregate) | The subject and the action | `AuthorizationError(subject_id, action, asset_id)` |

The dividing line is mechanical: **if a caller could plausibly want to read a specific value out of the failure, it is a typed subclass with that value as an attribute — never a bare `Exception`, never a shared string-keyed bucket.**

---

## Domain Events as Frozen Dataclasses

A Domain Event is a plain, immutable value type recorded on the Aggregate — a frozen dataclass, so it is immutable and value-comparable exactly like a Value Object. Its shape is fixed: `aggregate_id` (which instance), a `tenant_id` scoping field (in a multi-tenant product), business-specific fields, and `occurred_at: datetime` (always passed in, never `datetime.now()` inside the event). The serialization contract for Redpanda wire transport is owned by `event-schema-design`; the domain defines only this in-memory shape.

```python
# src/classification/domain/events.py
from dataclasses import dataclass
from datetime import datetime
from uuid import UUID

from classification.domain.sensitivity import SensitivityLevel


@dataclass(frozen=True)
class DomainEvent:
    """Marker base. Subclasses are frozen dataclasses named in the PAST TENSE."""
    aggregate_id: UUID
    tenant_id: UUID
    occurred_at: datetime


@dataclass(frozen=True)
class DataAssetRegistered(DomainEvent):
    source_id: UUID


@dataclass(frozen=True)
class DataAssetClassified(DomainEvent):
    sensitivity: SensitivityLevel
    classified_by: UUID
```

`frozen=True` means a recorded event cannot be mutated after the fact, and two events with identical fields compare equal — useful in tests asserting exactly which event was recorded.

### Past-Tense Naming Standard

| Rule | Good | Bad | Why |
|---|---|---|---|
| Past tense of the state change | `DataAssetClassified` | `ClassifyDataAsset` | The event reports a fact that already happened; the imperative form is the *Command* that caused it — a different concept, named in the application layer (`python-service-layer`) |
| Aggregate-qualified | `DataAssetClassified`, `DataAssetRegistered` | `Classified`, `Registered` | An unqualified past participle collides the moment a second Aggregate in the same Bounded Context has an analogous transition (`SourceRegistered` vs `DataAssetRegistered`) |
| One type per transition | Distinct `DataAssetClassified` / `DataAssetRegistered` / `DataAssetReclassified` | A single generic `DataAssetChanged(field, old, new)` | A generic event forces every consumer to branch on `field` and guess `old`/`new` types; a specific event gives consumers typed attributes, the same way a specific error type does |

### Event-Recording Completeness Checklist

Run this against **every** mutating method on the Aggregate, not just the ones that "obviously" need an event:

1. Does a successful call record exactly one event? (Not zero — a silent mutation is invisible to the outbox and every downstream consumer. Not two — a double-record duplicates the fact.)
2. Is the event recorded **after** every validation check has passed and **within** the same method that performed the mutation — never constructed by a calling service, never deferred to a later "event builder"?
3. Does a rejected call record **zero** events? (A validation failure that still appends an event reports a fact that never became true.)
4. Are the event's fields derived from the method's actual parameters / resulting state, not recomputed independently in a way that could disagree with what was just written?

A domain-model unit test verifies points 1 and 3 directly via `pull_events()` counts on both the success and failure branches of every parametrized case — this checklist is the design-time version of the same two checks.

---

## The Encapsulation Discipline — What Compensates for Python's Weak Privacy

`SKILL.md` states the gap: Go enforces private fields at compile time; Python's `_single_underscore` is unenforced convention and `__double_underscore` is trivially-bypassed name-mangling. This section shows the bypass concretely and lists the discipline that carries the load Go's compiler carries for free.

### How `__double_underscore` Mangling Is Bypassed

Name-mangling rewrites `self.__version` inside class `DataAsset` to the attribute `_DataAsset__version`. It is *not* access control — it only prepends the class name to avoid subclass collisions. A determined caller reaches straight through it:

```python
class DataAsset:
    def __init__(self):
        self.__version = 1          # stored under the mangled name

asset = DataAsset()
# asset.__version                   # AttributeError — but NOT because it's protected
asset._DataAsset__version = 999     # WORKS — the invariant is corrupted from outside
print(asset._DataAsset__version)    # 999
```

The `_DataAsset__version` spelling is public, documented Python behavior — nothing at runtime or compile time prevents the assignment. This is the honest gap: a Go `version int64` unexported field simply cannot be written from another package, full stop; the Python equivalent is always reachable. **Because of this, `python-domain-model` uses plain `_single_underscore` (not `__double`), since mangling buys no real protection and only obscures the field** — the protection has to come from discipline, not the underscore count.

### The Discipline That Actually Enforces the Boundary

Since the language will not stop external mutation, four practices do the enforcing Go's compiler would:

1. **Private-by-convention naming, consistently applied** — all Aggregate state is `_underscore`, mutation is only ever through methods, and reviewers treat any `asset._field = ...` outside the domain package (or outside a test's explicit setup) as a defect. Convention is only load-bearing if it is actually reviewed.
2. **Frozen dataclasses for every Value Object** — this is the *one* genuinely-enforced immutability in the model; `@dataclass(frozen=True)` raises `FrozenInstanceError` at runtime, so Value Objects get real protection even though entities cannot.
3. **A mandatory `mypy` / `pyright` gate in CI** — type hints are runtime-erased; without a required static-type step, a wrong-shaped object flowing into a domain method is caught by nothing. `python-error-handling` and the tooling skill make this gate non-negotiable, precisely because it is the closest Python gets to the Go compiler's always-on checking.
4. **`import-linter` contracts** — Python has no `internal/` compiler privacy, so the inward-only dependency rule is enforced as a CI fitness function instead. A `layers` contract only governs imports between the project's own packages; keeping `asyncpg`/`fastapi` out of the domain package also needs a `forbidden` contract with external packages included:

```ini
# .importlinter  (add include_external_packages to the existing [importlinter] section)
[importlinter]
root_package = classification
include_external_packages = True

[importlinter:contract:domain-is-pure]
name = domain imports no framework or driver
type = forbidden
source_modules =
    classification.domain
forbidden_modules =
    aiokafka
    asyncpg
    fastapi
    pydantic
    sqlalchemy
    starlette
```

The honest summary for any artifact: **Python's domain model achieves the same *design* as Go's, but its invariant protection is a review-and-CI discipline, not a compiler guarantee — the frozen dataclass is the only part the runtime enforces on its own.** Say that plainly; do not imply parity.
