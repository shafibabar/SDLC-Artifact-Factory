---
name: go-domain-model
description: >
  Teaches how to implement a DDD Aggregate in idiomatic Go to a checkable
  engineering standard, not just a shape: the failing-constructor pattern
  (any constructor that can violate an invariant returns (*T, error), never
  a zero-value struct silently missing one), the precise pointer-vs-value
  receiver rule and how a type's method set determines interface
  satisfaction, Value Object immutability (unexported fields, no setters,
  equality by value, and the compile-time trap of a slice/map field making
  == uncompilable), the Domain Event struct-shape and past-tense-naming
  standard and exactly when an Aggregate method emits one, the
  invariant-violation error standard (one named error type per broken
  invariant, carrying the violating values, never a generic errors.New
  bucket), and what a domain-model unit test must specifically assert
  (invariant enforcement at every mutation path, immutability, event-
  emission completeness). The domain layer is pure: no framework, no I/O,
  fully unit-testable. Implements the domain-modeler's aggregate-design
  output and the data-architect's schemas in code. Full worked examples in
  references/value-objects-and-events.md and
  references/aggregate-invariant-enforcement.md. Used by the
  backend-engineer during Implement.
version: 3.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, ddd, aggregate, value-object, domain-event, invariants, receiver-type, escape-analysis]
related: [aggregate-design, go-error-handling, go-unit-test, go-project-structure, go-repository-pattern, event-schema-design, go-performance-optimization]
---

# Go Domain Model

## Purpose

The domain layer is where business rules live, expressed in the Ubiquitous Language, with zero knowledge of how data is stored or transported. An Aggregate enforces its invariants so an instance in memory is always valid — illegal states must be unrepresentable, not merely undocumented. This skill is the Go-implementation standard for `aggregate-design`'s DDD tactical patterns; it does not re-teach Aggregate boundary theory, sizing, or when Event Sourcing is justified — `aggregate-design` owns that reasoning. This skill owns only how the chosen boundary becomes correct, idiomatic Go.

---

## Aggregate Root: The Invariant-Enforcement Standard

**Every constructor that can fail returns `(*T, error)` — never a zero-value struct with a missing invariant silently left for a caller to notice later.** Fields are unexported; the only way to change state is a method that validates first, mutates second, and records a Domain Event third — in that order, atomically, within the same method call.

```go
// internal/domain/dataasset.go
package domain

type DataAsset struct {
    id, tenantID, sourceID uuid.UUID
    sensitivity  SensitivityLevel // Value Object; zero value = "unclassified"
    classifiedBy uuid.UUID
    classifiedAt time.Time
    version      int64  // optimistic concurrency (data-model-design)
    events       []DomainEvent
}

// NewDataAsset creates a NEW asset. Returns (*DataAsset, error) — construction
// itself is an invariant-checked operation, exactly like any mutating method.
func NewDataAsset(id, tenantID, sourceID uuid.UUID, now time.Time) (*DataAsset, error) {
    if id == uuid.Nil || tenantID == uuid.Nil {
        return nil, ErrMissingIdentity // no *DataAsset escapes half-built
    }
    a := &DataAsset{id: id, tenantID: tenantID, sourceID: sourceID, version: 1}
    a.recordEvent(DataAssetRegistered{AggregateID: id, TenantID: tenantID, OccurredAt: now})
    return a, nil
}

// Classify is the ONLY way to set sensitivity: validate, mutate, record — in order.
func (a *DataAsset) Classify(level SensitivityLevel, by uuid.UUID, now time.Time) error {
    if !level.IsValid() {
        return fmt.Errorf("classify data asset %s: %w", a.id, ErrInvalidSensitivity)
    }
    if a.sensitivity.IsHigherThan(level) { // True Invariant: no silent downgrade
        return &ErrSensitivityDowngrade{AssetID: a.id, From: a.sensitivity, To: level}
    }
    a.sensitivity, a.classifiedBy, a.classifiedAt = level, by, now
    a.recordEvent(DataAssetClassified{AggregateID: a.id, TenantID: a.tenantID,
        Sensitivity: level, ClassifiedBy: by, OccurredAt: now})
    return nil
}
```

Because validation runs *before* any field is written, a rejected `Classify` call leaves `a` byte-for-byte unchanged — there is no partial-mutation state to roll back. `Reconstitute` (rebuilding from storage) is a *separate* code path from `New…` — it does not re-validate and does not emit events, because the data was already valid when stored and it already exists. Full failing-constructor worked example (including the anti-pattern this replaces, and a table-driven test asserting the invariant), the precise Go method-set rule, and the one-type-per-invariant error standard below: `references/aggregate-invariant-enforcement.md`.

---

## Receiver-Type Standard: Pointer vs Value, and Method Sets

Go's rule is mechanical, not a style preference (Donovan & Kernighan, ch. 6.2): **a method declared with receiver `T` is in the method set of both `T` and `*T`; a method declared with receiver `*T` is in the method set of `*T` only.** This is why a bare `DataAsset` value — not `*DataAsset` — fails to satisfy any interface requiring a pointer-receiver method: the value's method set is missing every mutating method, and the compiler rejects the assignment outright, not at some later call site. Consequence: an Aggregate Root, whose methods mutate, is **always** `*T` — never mix receiver types across one type's method set (Harsanyi, ch. 6 on functions and methods); pick pointer-or-value once, per type, for every method. Value Objects have no mutating methods, so they take value receivers throughout, are passed by value, and are never referenced via a pointer in the domain — `*SensitivityLevel` invites nil checks and aliasing for a type whose entire point is cheap, safe copying. This receiver choice doubles as an escape-analysis decision, not just a mutability one: a small Value Object passed by value has no reason to escape to the heap, while an Aggregate Root's pointer necessarily does the moment it's returned from `New…` — verify actual allocation behaviour with `go-performance-optimization` rather than assuming, whenever a domain type sits on a hot path. Full method-set compile-error example and the sizing rule for when a *value* receiver would still be wrong for a large-but-immutable struct: `references/aggregate-invariant-enforcement.md`.

---

## Value Object Immutability Standard

Unexported fields, no setter methods, equality by value, never a pointer in the domain. **The trap:** a struct containing a slice or map field is not `==`-comparable — Go refuses to compile the comparison at all, not merely evaluate it wrong (Donovan & Kernighan, ch. 4 on slice/map reference semantics) — so a Value Object needing a collection field must either use a fixed-size array field or implement `Equals(other T) bool` explicitly, never `reflect.DeepEqual` on a hot path (`go-performance-optimization`). Full `SensitivityLevel` worked example and the slice-field `Equals` counter-example: `references/value-objects-and-events.md`.

---

## Domain Event Standard

A Domain Event is a plain, immutable value type: `AggregateID`, `TenantID`, business-specific fields, `OccurredAt time.Time` — named in the **past tense of the state change**, always aggregate-qualified (`DataAssetClassified`, never `Classified` or `ClassifyDataAsset`), one type per state transition, never reused across aggregates. It is recorded only inside the Aggregate method whose successful mutation it reports — atomically with that mutation, never on a failed validation path, never constructed by a service outside the Aggregate. Full worked `DataAssetClassified` example, the compile-time `var _ DomainEvent = ...{}` assertion convention, and the emission-completeness checklist: `references/value-objects-and-events.md`.

---

## Invariant-Violation Error Standard

`go-error-handling` owns the general sentinel-vs-typed taxonomy; this skill owns the domain-specific rule built on top of it: **a parameter-free invariant (existence, permission) is a package-level sentinel; any invariant whose violation carries diagnostic data gets its own named error type — never a single generic `errors.New` or a shared `InvariantViolationError{Rule string, Details map[string]any}` bucket that throws away Go's static field access for a stringly-typed lookup.**

```go
type ErrSensitivityDowngrade struct{ AssetID uuid.UUID; From, To SensitivityLevel }
func (e *ErrSensitivityDowngrade) Error() string {
    return fmt.Sprintf("data asset %s: cannot downgrade sensitivity %s → %s without explicit reclassification", e.AssetID, e.From, e.To)
}
```

A caller does `var dg *ErrSensitivityDowngrade; errors.As(err, &dg)` and gets `dg.From`/`dg.To` back typed — an HTTP 409 body or audit log can report the exact values without re-deriving state. `errors.New("cannot downgrade sensitivity")` cannot do this: the values are gone the instant the string is built. Full contrast and every invariant currently in the `DataAsset` roster classified sentinel-or-typed: `references/aggregate-invariant-enforcement.md`.

---

## Purity Rule

The domain package imports **only** stdlib, `github.com/google/uuid`, and `time`. No pgx, no chi, no OTel, no slog. A domain method never calls `time.Now()` or `uuid.New()` itself — both are **passed in** — so invariant tests are deterministic.

---

## Domain-Model Unit-Test Standard

`go-unit-test` owns the general table-driven/TDD standard; a domain-model test additionally must assert three things specific to this artifact type, for **every** exported mutating method:

1. **Invariant enforcement** — one table case per invariant that can be violated, asserting `errors.Is`/`errors.As` against the exact sentinel or typed error, not just "an error occurred."
2. **Immutability on the rejected path** — after a failing call, every field is asserted unchanged (byte-for-byte, or via a snapshot-and-compare) — this is what "validate before mutate" is *for*, and a test that skips it doesn't verify the ordering actually holds.
3. **Event-emission completeness** — a successful call recorded **exactly one** event of the expected type via `PullEvents()`; a rejected call recorded **zero**. Both directions, every method — a passing test that only checks the success path leaves the failure-path emission-completeness claim unverified.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Failing constructors typed | Every fallible `New…`/mutating method returns `(*T, error)` / `error` | A constructor returning a zero-value struct with no error path | Read every exported `New…` and mutating method's signature |
| Encapsulation | Aggregate fields unexported; mutation only via methods | Exported mutable fields | `grep -n "^\s*[A-Z]" internal/domain/*.go` field lists — no hits outside accessor return types |
| Validate-then-mutate order | Every mutating method's checks precede its first field write | A field written before its guarding check | Read method body top to bottom; first assignment must follow all `if`/`return` guards |
| Consistent receiver type | One type's methods are all pointer, or all value — never mixed | A type with both `func (a DataAsset)` and `func (a *DataAsset)` methods | `grep -n "func (a .*DataAsset)" internal/domain/*.go` — one receiver spelling only |
| Value Objects immutable | Value types, by-value, no setters, `==` or explicit `Equals` | Mutable VOs, pointer-to-VO, or a slice/map field with no `Equals` | Read VO type; if it has a slice/map field, an `Equals` method must exist beside it |
| Events recorded in-method | State-changing methods record their event before returning `nil` | Events constructed in a service/handler layer | Grep `recordEvent(` call sites — all inside `internal/domain` |
| One error type per invariant | Sentinel for parameter-free conditions; named typed error for anything with data | A generic `errors.New` invariant message, or a shared `Details map[string]any` bucket | Read `errors.go`; every data-carrying invariant has its own named type |
| Construct ≠ reconstitute | Separate `New…`/`Reconstitute`; only `New…` validates and emits | Loading from DB re-runs validation or re-fires creation events | Read `Reconstitute`'s body for the absence of both |
| Purity | Domain imports only stdlib + uuid + time; time/IDs injected | Framework import, or `time.Now()`/`uuid.New()` inside domain | `go list -deps ./internal/domain/...` |
| Unit test asserts all three axes | Every mutating method's table covers invariant-match, immutability-on-reject, event-count-both-ways | A test asserting only "err != nil" or only the success path's event | Read the test table's assertions against the three-item standard above, per method |

---

## Anti-Patterns

- **Anemic domain model** — exported fields/getters-setters with rules living in a service; invariants become unenforceable by any caller.
- **Zero-value construction on failure** — returning `&DataAsset{}, err` instead of `nil, err` leaves a caller one missed nil-check from operating on a half-built Aggregate.
- **Mixed receiver types on one Aggregate** — one method pointer, another value, "because that one doesn't mutate" — inconsistent method sets are a compile-time interface-satisfaction trap waiting for the next refactor.
- **A generic `InvariantViolationError{Rule, Details}` bucket** — reused across every invariant, it trades static field access for a map lookup a future caller has to reverse-engineer.
- **Events built outside the Aggregate, or on the failure path** — an event must correspond 1:1 to a committed mutation; constructing it before validation, or in a calling service, decouples the fact from the state change that supposedly caused it.
- **`time.Now()` / `uuid.New()` inside domain methods** — hidden nondeterminism makes invariant tests flaky.
- **Pointer-to-Value-Object** — invites nil checks and aliasing for a type whose whole point is cheap immutable copies.

---

## Output Format

Go source built exactly to the standards above, plus test-first unit tests (TDD) covering all three axes of the Domain-Model Unit-Test Standard for every mutating method:

```
internal/domain/dataasset.go        (Aggregate Root: New…, Reconstitute, mutating methods)
internal/domain/sensitivity.go      (Value Object: unexported field, IsValid, Equals if needed)
internal/domain/events.go           (Domain Events: past-tense structs + var _ DomainEvent assertions)
internal/domain/errors.go           (sentinels for parameter-free conditions; named types for data-carrying invariants)
internal/domain/dataasset_test.go   (table-driven: invariant match + immutability-on-reject + event count, per method)
```

Full worked examples: `references/aggregate-invariant-enforcement.md` (failing constructors, method sets, error typing) and `references/value-objects-and-events.md` (Value Objects, Domain Events, emission checklist).
