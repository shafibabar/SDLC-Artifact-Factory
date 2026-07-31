---
name: python-domain-model
description: >
  Teaches the backend-engineer to build a Python domain model — the Aggregate
  root as sole mutation entry point owning its invariant and version_number,
  entities (identity equality) vs value objects (@dataclass(frozen=True), value
  equality), invariant-guarding methods, and the honest encapsulation gap
  (Python _underscore/__mangled fall short of Go compiler-private fields). The
  Python analog of go-domain-model.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, ddd, aggregate, value-object, domain-event, invariants, dataclass, encapsulation]
related: [go-domain-model, python-repository-pattern, python-service-layer]
---

# Python Domain Model

## Purpose

The domain layer is where business rules live, expressed in the Ubiquitous Language, with zero knowledge of how data is stored or transported. An Aggregate enforces its invariants so an instance in memory is always valid — illegal states must be unrepresentable, not merely undocumented. This skill is the Python-implementation standard for `aggregate-design`'s DDD tactical patterns on the FastAPI + `asyncpg` stack; it does not re-teach Aggregate boundary theory, sizing, or when Event Sourcing is justified — `aggregate-design` owns that reasoning. It is the Python analog of `go-domain-model`; where Python differs *honestly* from Go — chiefly weak encapsulation — this skill says so rather than implying parity.

---

## Aggregate Root: The Invariant-Enforcement Standard

**A fallible constructor validates before it builds — raise a `DomainError` subclass so no half-built Aggregate escapes.** Python has no `(*T, error)` return pair; the idiom is a classmethod factory (`DataAsset.register(...)`) that raises on a violated invariant instead of returning a broken instance. State is private *by convention* (`_leading_underscore`), and the only way to change it is a method that validates first, mutates second, and records a Domain Event third — in that order, within one method call.

```python
# app/domain/data_asset.py
class DataAsset:
    def __init__(self, id: UUID, tenant_id: UUID, source_id: UUID, version_number: int):
        self._id = id
        self._tenant_id = tenant_id
        self._source_id = source_id
        self._sensitivity = SensitivityLevel.UNCLASSIFIED  # a Value Object
        self._version_number = version_number              # optimistic concurrency
        self._events: list[DomainEvent] = []

    @classmethod
    def register(cls, id: UUID, tenant_id: UUID, source_id: UUID, now: datetime) -> "DataAsset":
        if id is None or tenant_id is None:
            raise MissingIdentityError(id=id, tenant_id=tenant_id)  # nothing half-built escapes
        asset = cls(id, tenant_id, source_id, version_number=1)
        asset._record(DataAssetRegistered(aggregate_id=id, tenant_id=tenant_id, occurred_at=now))
        return asset

    def classify(self, level: "SensitivityLevel", by: UUID, now: datetime) -> None:
        if self._sensitivity.is_higher_than(level):     # True Invariant: no silent downgrade
            raise SensitivityDowngradeError(asset_id=self._id, from_=self._sensitivity, to=level)
        self._sensitivity = level
        self._version_number += 1
        self._record(DataAssetClassified(aggregate_id=self._id, tenant_id=self._tenant_id,
                                         sensitivity=level, classified_by=by, occurred_at=now))
```

Because validation runs *before* any field is written, a rejected `classify` call leaves `self` unchanged — there is no partial-mutation state to roll back. `reconstitute` (rebuilding from a stored row) is a *separate* classmethod from `register` — it does not re-validate and does not record events, because the data was already valid when stored and it already exists. The `version_number` is the CAS token `python-repository-pattern` reads on save; bumping it inside every mutating method is what lets two concurrent transactions collide instead of silently interleaving. Full worked Aggregate (including `reconstitute`, the anti-pattern this replaces, and a `pytest` table proving the invariant): `references/aggregate-and-value-objects.md`.

---

## Entity vs Value Object

The distinction is about equality, and it is enforced differently in Python than in Go.

- **Entity** — has identity; two entities are equal iff their identity fields match, regardless of any other attribute. The Aggregate root is an entity. Implement `__eq__`/`__hash__` on the identity only (or leave the default identity-by-`id()` and never compare entities by value). An entity is a mutable ordinary class.
- **Value Object** — has no identity; equality is by *value*, and it is immutable. Implement it as `@dataclass(frozen=True)` — this gives value equality and a `__hash__` for free, and turns any attribute assignment into a `FrozenInstanceError` at runtime. This is the one place Python's immutability is genuinely enforced (unlike entity privacy — see the caveat below). Prefer an `enum.Enum` for a closed set of values (`SensitivityLevel`), a frozen dataclass for a small record of fields.

A frozen dataclass validates its own invariant in `__post_init__`; because normal assignment is blocked, any normalization there must go through `object.__setattr__`. Worked Value Objects, the `__post_init__` validation pattern, and identity-vs-value equality side by side: `references/aggregate-and-value-objects.md`.

---

## Invariant-Guarding Methods and Domain Errors

Every mutating method guards its invariant first and raises on violation. Errors are a `DomainError` hierarchy carrying the violating values as typed attributes — never a bare `raise Exception("...")` or a single stringly-typed bucket. `python-error-handling` owns the general hierarchy and the single FastAPI `@app.exception_handler(DomainError)` that maps the family to HTTP status at the transport edge; this skill owns the rule that the *domain* raises deep and never builds an HTTP response itself.

```python
class DomainError(Exception): ...

class SensitivityDowngradeError(DomainError):
    def __init__(self, asset_id: UUID, from_: "SensitivityLevel", to: "SensitivityLevel"):
        self.asset_id, self.from_, self.to = asset_id, from_, to
        super().__init__(f"data asset {asset_id}: cannot downgrade sensitivity {from_} -> {to}")
```

A caller catches `SensitivityDowngradeError` and reads `err.from_`/`err.to` as typed attributes for a 409 body or audit log — a `raise Exception("cannot downgrade")` throws that data away the instant the string is built. Full contrast, the `raise ... from cause` chaining rule, and every `DataAsset` invariant classified: `references/invariants-and-events.md`.

---

## The Honest Encapsulation Gap vs Go

**State this plainly in every artifact — do not imply parity with `go-domain-model`.** Go enforces private fields at compile time: an unexported field is unreachable from another package, so an Aggregate's invariant genuinely *cannot* be bypassed by external mutation. Python offers only:

- `_single_underscore` — pure convention, entirely unenforced; any caller can read or write `asset._sensitivity` directly.
- `__double_underscore` — name-mangling, weakly enforced and trivially bypassed (the attribute is still reachable under its mangled name).

So a determined or careless caller can always reach around a Python Aggregate's methods and corrupt its invariant — nothing at compile time stops them. The compensating discipline (private-by-convention naming, a mandatory `mypy`/`pyright` gate, `import-linter` layering, and code review as the real enforcement seam) is covered in `references/invariants-and-events.md`, including exactly how `__double_underscore` mangling is bypassed and why frozen dataclasses are the *only* genuinely-enforced immutability in the model.

---

## Purity Rule

The domain package imports **only** the stdlib (`uuid`, `datetime`, `dataclasses`, `enum`) and nothing else — no `asyncpg`, no `fastapi`, no `pydantic`, no OTel. A domain method never calls `datetime.now(...)` or `uuid.uuid4()` itself — both are **passed in** — so invariant tests are deterministic. (Pydantic models belong at the FastAPI boundary, not in the domain — keeping the domain plain-object keeps it framework-free and fast to unit-test.)

---

## Domain-Model Unit-Test Standard

`python-unit-test` owns the general `pytest`/`@pytest.mark.parametrize`/TDD standard; a domain-model test additionally must assert three things for **every** mutating method:

1. **Invariant enforcement** — one parametrized case per invariant, asserting `pytest.raises(SpecificError)` against the *exact* `DomainError` subclass, not a bare `Exception`.
2. **Immutability on the rejected path** — after a raising call, every field is asserted unchanged — this is what "validate before mutate" is *for*, and a test skipping it doesn't verify the ordering holds.
3. **Event-recording completeness** — a successful call recorded **exactly one** event of the expected type via `pull_events()`; a rejected call recorded **zero**. Both directions, every method.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Fallible constructor raises | Every invariant-checked factory raises a `DomainError` subclass before building | A factory returning a half-built instance with no raise path | Read every `@classmethod` factory and mutating method |
| Encapsulation by convention | Aggregate state is `_underscore`; mutation only via methods; caveat stated | Public mutable attributes, or implied parity with Go's enforced privacy | `grep -n "self\.[a-z]" domain/*.py` — leading-underscore state only |
| Validate-then-mutate order | Every mutating method's guards precede its first field write | A field written before its guarding check | Read method body top to bottom |
| Value Objects immutable | `@dataclass(frozen=True)` or `Enum`; value equality; validated in `__post_init__` | A mutable class used as a Value Object, or `frozen=True` omitted | Read the VO decorator; `frozen=True` present |
| Entity vs VO equality correct | Entities equal by identity; VOs equal by value | An entity with value equality, or a VO compared by identity | Read `__eq__`/decorator on each domain type |
| Errors carry typed data | Named `DomainError` subclass per data-carrying invariant | A bare `raise Exception("...")` or a shared string-keyed bucket | Read the error module |
| Events recorded in-method | State-changing methods record their event before returning | Events built in a service/handler layer | Grep `_record(` call sites — all inside `domain/` |
| Construct != reconstitute | Separate `register`/`reconstitute`; only `register` validates and records | Loading from DB re-runs validation or re-fires creation events | Read `reconstitute`'s body |
| Purity | Domain imports only stdlib; time/IDs injected | Framework import, or `datetime.now()`/`uuid.uuid4()` inside domain | `grep -rn "import" domain/` |
| Test asserts all three axes | Every method's table covers invariant-raise, immutability-on-reject, event-count-both-ways | A test asserting only `pytest.raises` or only the success path | Read the test against the three-item standard |

---

## Anti-Patterns

- **Anemic domain model** — public attributes with rules living in a service; invariants become unenforceable by any caller.
- **Implying Go-parity on encapsulation** — presenting `_underscore`/`__mangled` as if they enforced privacy; they do not, and an artifact that pretends otherwise is a defect (say the gap plainly).
- **A mutable class used as a Value Object** — omitting `frozen=True` throws away the one genuinely-enforced immutability Python offers here.
- **A bare `raise Exception("...")` for an invariant** — trades typed, catchable, data-carrying failures for a string a caller has to parse.
- **Events built outside the Aggregate, or on the failure path** — an event must correspond 1:1 to a committed mutation.
- **`datetime.now()` / `uuid.uuid4()` inside domain methods** — hidden nondeterminism makes invariant tests flaky.
- **Pydantic `BaseModel` as the Aggregate** — drags framework/validation concerns into the domain and couples it to the transport layer; keep the domain plain-object.

---

## Output Format

Plain-object Python built exactly to the standards above, plus test-first `pytest` tests (TDD) covering all three axes for every mutating method:

```
app/domain/data_asset.py     (Aggregate Root: register, reconstitute, mutating methods, _record/pull_events)
app/domain/sensitivity.py    (Value Object: Enum or frozen dataclass, is_valid/is_higher_than)
app/domain/events.py         (Domain Events: past-tense frozen dataclasses)
app/domain/errors.py         (DomainError hierarchy; typed subclass per data-carrying invariant)
tests/domain/test_data_asset.py (parametrized: invariant-raise + immutability-on-reject + event count, per method)
```

Full worked examples: `references/aggregate-and-value-objects.md` (Aggregate, Value Objects, identity-vs-value equality) and `references/invariants-and-events.md` (invariant enforcement, domain events, the encapsulation-discipline conventions Python needs to compensate for weak privacy).
</content>
