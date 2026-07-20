---
name: go-domain-model
description: >
  Teaches how to implement a DDD Aggregate in idiomatic Go — the Aggregate Root
  with private fields and invariant-enforcing methods, Value Objects as immutable
  value types, domain event recording, factory/reconstitution functions, and the
  value-vs-pointer decision driven by escape analysis. The domain layer is pure:
  no framework, no I/O, fully unit-testable. Implements the domain-modeler's and
  data-architect's model in code. Used by the backend-engineer during Implement.
version: 1.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, ddd, aggregate, value-object, domain-event, invariants, escape-analysis]
---

# Go Domain Model

## Purpose

The domain layer is where the business rules live, expressed in the Ubiquitous Language, with zero knowledge of how data is stored or transported. An Aggregate enforces its invariants so that an instance in memory is always valid — it is impossible to construct or mutate it into an illegal state. This is the heart of DDD made concrete in Go.

This skill turns the domain-modeler's Aggregates, Value Objects, and Domain Events, and the data-architect's schemas, into Go types. It writes no SQL and no HTTP — those are other layers.

---

## Aggregate Root

The Aggregate Root has **unexported fields** so no outside code can bypass its invariants. State changes go through methods that validate first, mutate second, and record a Domain Event.

```go
// internal/domain/dataasset.go
package domain

type DataAsset struct {
    id          uuid.UUID
    tenantID    uuid.UUID
    sourceID    uuid.UUID
    sensitivity SensitivityLevel   // Value Object; zero value = "unclassified"
    classifiedBy uuid.UUID
    classifiedAt time.Time
    version     int64              // optimistic concurrency (matches data-model-design)

    events []DomainEvent           // uncommitted events; drained on save
}

// Classify enforces the invariant and records the event. It is the ONLY way to set sensitivity.
func (a *DataAsset) Classify(level SensitivityLevel, by uuid.UUID, now time.Time) error {
    if !level.IsValid() {
        return fmt.Errorf("classify data asset %s: %w", a.id, ErrInvalidSensitivity)
    }
    // Invariant: de-escalation must be explicit/audited — block silent downgrade here.
    if a.sensitivity.IsHigherThan(level) {
        return fmt.Errorf("classify data asset %s: %w", a.id, ErrCannotDowngradeSilently)
    }
    a.sensitivity = level
    a.classifiedBy = by
    a.classifiedAt = now
    a.recordEvent(DataAssetClassified{
        AggregateID: a.id, TenantID: a.tenantID,
        Sensitivity: level, ClassifiedBy: by, OccurredAt: now,
    })
    return nil
}

func (a *DataAsset) recordEvent(e DomainEvent) { a.events = append(a.events, e) }

// PullEvents returns and clears uncommitted events — the repository drains these into the outbox.
func (a *DataAsset) PullEvents() []DomainEvent {
    e := a.events
    a.events = nil
    return e
}

// Accessors expose state read-only.
func (a *DataAsset) ID() uuid.UUID            { return a.id }
func (a *DataAsset) TenantID() uuid.UUID      { return a.tenantID }
func (a *DataAsset) Sensitivity() SensitivityLevel { return a.sensitivity }
func (a *DataAsset) Version() int64           { return a.version }
```

---

## Construction vs Reconstitution

Two distinct entry points, never conflated:

```go
// NewDataAsset — creates a NEW asset (a real domain event: it came into existence).
func NewDataAsset(id, tenantID, sourceID uuid.UUID, now time.Time) (*DataAsset, error) {
    if id == uuid.Nil || tenantID == uuid.Nil {
        return nil, ErrMissingIdentity
    }
    a := &DataAsset{id: id, tenantID: tenantID, sourceID: sourceID, version: 1}
    a.recordEvent(DataAssetRegistered{AggregateID: id, TenantID: tenantID, OccurredAt: now})
    return a, nil
}

// Reconstitute — rebuilds an EXISTING asset from storage. No events; it already exists.
// Called only by the repository (see go-repository-pattern).
func Reconstitute(id, tenantID, sourceID uuid.UUID, level SensitivityLevel, version int64) *DataAsset {
    return &DataAsset{id: id, tenantID: tenantID, sourceID: sourceID, sensitivity: level, version: version}
}
```

Reconstitution does not emit events and does not re-validate (the data was valid when stored) — conflating it with creation would double-fire events on every load.

---

## Value Objects

Value Objects are immutable, compared by value, and have no identity. Implement them as small value types (often a defined string/int) with behaviour attached.

```go
// internal/domain/sensitivity.go
package domain

type SensitivityLevel string

const (
    SensitivityUnclassified SensitivityLevel = ""
    SensitivityPublic       SensitivityLevel = "Public"
    SensitivityInternal     SensitivityLevel = "Internal"
    SensitivityConfidential SensitivityLevel = "Confidential"
    SensitivityRestricted   SensitivityLevel = "Restricted"
)

func (s SensitivityLevel) IsValid() bool {
    switch s {
    case SensitivityPublic, SensitivityInternal, SensitivityConfidential, SensitivityRestricted:
        return true
    }
    return false
}

func (s SensitivityLevel) rank() int {
    return map[SensitivityLevel]int{
        SensitivityUnclassified: 0, SensitivityPublic: 1, SensitivityInternal: 2,
        SensitivityConfidential: 3, SensitivityRestricted: 4,
    }[s]
}

func (s SensitivityLevel) IsHigherThan(other SensitivityLevel) bool { return s.rank() > other.rank() }
```

A Value Object is never a pointer in the domain — passing it by value is cheap, prevents aliasing bugs, and keeps it immutable.

---

## Value vs Pointer (Escape Analysis Awareness)

The blueprint's mechanical-sympathy rule applies in the domain:

| Use a value (`T`) | Use a pointer (`*T`) |
|---|---|
| Value Objects (small, immutable) | Aggregate Roots (identity + mutable state + event buffer) |
| Small structs that don't need mutation | Anything whose methods mutate the receiver |
| Map keys / set membership | Large structs where copying is measurably costly |

Aggregate Roots are passed by pointer because their methods mutate (record events, change state) and identity matters. Value Objects are passed by value because copying is cheap and immutability is the point. Avoid pointer-to-Value-Object — it invites nil and aliasing for no benefit. (Verify allocation behaviour with `go-performance-optimization` when a domain type is on a hot path.)

---

## Domain Events as Types

Domain Events are plain immutable value types implementing a tiny interface. The serialization contract is owned by `event-schema-design`; the domain only defines the in-memory shape.

```go
// internal/domain/events.go
package domain

type DomainEvent interface{ EventType() string }

type DataAssetClassified struct {
    AggregateID  uuid.UUID
    TenantID     uuid.UUID
    Sensitivity  SensitivityLevel
    ClassifiedBy uuid.UUID
    OccurredAt   time.Time
}

func (DataAssetClassified) EventType() string { return "DataAssetClassified" }
```

---

## Purity Rule

The domain package imports **only** stdlib, `github.com/google/uuid`, and `time`. No pgx, no chi, no OTel, no slog. If a domain method needs the current time, it is **passed in** (`now time.Time`) — the domain does not call `time.Now()` itself, so tests are deterministic. The same applies to ID generation where determinism matters.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Encapsulation | Aggregate fields unexported; mutation only via methods | Exported mutable fields bypassing invariants |
| Invariants enforced | Illegal states are unrepresentable / rejected at the method | Validation done in handlers, not the Aggregate |
| Events recorded in domain | State-changing methods record Domain Events | Events constructed in the service/handler layer |
| Construct ≠ reconstitute | Separate `New…` and `Reconstitute`; only `New…` emits events | Loading from DB re-fires creation events |
| Value Objects immutable | Value types, by-value, behaviour attached | Mutable VOs or pointer-to-VO |
| Purity | Domain imports only stdlib + uuid + time; time injected | Domain importing frameworks or calling `time.Now()` |

---

## Anti-Patterns

- **Anemic domain model** — an Aggregate that is a bag of exported fields with getters/setters, while the "rules" live in a service. The invariants become unenforceable; any caller can construct an illegal state.
- **Aggregate as ORM struct** — `db:` / `json:` tags on domain types couple the model to storage and transport. Mapping lives in the repository and handler layers.
- **Events built outside the Aggregate** — a service constructing `DataAssetClassified` itself can drift from the state change that supposedly caused it. The method that mutates records the event, atomically with the mutation.
- **Re-validating (or re-emitting events) on reconstitution** — loading an asset must never fire `DataAssetRegistered` again or reject data that was valid under the rules in force when it was stored.
- **`time.Now()` / `uuid.New()` inside domain methods** — hidden nondeterminism makes invariant tests flaky and time-dependent rules untestable. Inject `now` (and IDs where identity matters).
- **Pointer-to-Value-Object** — `*SensitivityLevel` invites nil checks and aliasing for a type whose whole point is cheap immutable copies.

---

## Output Format

Produces Go source plus its test-first unit tests (TDD):

```
internal/domain/dataasset.go        (Aggregate Root)
internal/domain/sensitivity.go      (Value Object)
internal/domain/events.go           (Domain Events)
internal/domain/errors.go           (sentinel errors)
internal/domain/dataasset_test.go   (table-driven invariant tests — written first)
```
