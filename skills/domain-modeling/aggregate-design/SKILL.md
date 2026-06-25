---
name: aggregate-design
description: >
  Teaches how to design Aggregates in Domain-Driven Design — including the rules
  for setting Aggregate boundaries, the role of the Aggregate Root, invariant
  identification, the distinction between Entities and Value Objects inside an
  Aggregate, and how Aggregates translate to Go structs and repository interfaces.
  Correct Aggregate design is the primary determinant of whether the domain model
  can enforce its own rules without distributed coordination. Used by the
  domain-modeler agent after Event Storming and Bounded Context mapping.
version: 1.0.0
phase: design
owner: domain-modeler
tags: [design, ddd, aggregate, entity, value-object, invariants, go]
---

# Aggregate Design

## Purpose

An Aggregate is a cluster of Domain Objects (Entities and Value Objects) that is treated as a single unit for the purpose of data changes. The Aggregate Root is the entry point — it is the only object in the cluster that external code may hold a reference to, and it is responsible for enforcing all invariants that span the cluster.

Getting Aggregate boundaries right is one of the hardest and most consequential design decisions in DDD. Boundaries that are too wide cause contention and poor performance. Boundaries that are too narrow scatter invariants across multiple Aggregates, making them impossible to enforce without distributed coordination.

---

## The Rules of Aggregates

These rules are non-negotiable. Violations produce a domain model that cannot enforce its own rules:

### Rule 1: Enforce Invariants Within the Aggregate Boundary

An invariant is a rule that must always be true. **All invariants that span multiple Domain Objects must be enforced within a single Aggregate.** If an invariant requires checking state across two Aggregates, the boundary is wrong.

Example: "A DataAsset may only be marked Restricted if its storage source is confirmed active." Both `DataAsset` and `StorageSource` must be reachable within the same transaction for this check. This suggests either they belong to the same Aggregate, or the check can be relaxed to eventual consistency.

### Rule 2: Reference Other Aggregates by ID Only

An Aggregate never holds a direct object reference to another Aggregate. It holds only the other Aggregate's ID. This enforces loose coupling and prevents the boundary from being bypassed.

```go
// Correct: reference by ID
type DataAsset struct {
    id              DataAssetID
    storageSourceID StorageSourceID   // ID only — not *StorageSource
    ...
}

// Wrong: reference by object
type DataAsset struct {
    id            DataAssetID
    storageSource *StorageSource      // Direct reference — violates Aggregate boundary
    ...
}
```

### Rule 3: One Aggregate per Transaction

Each database transaction modifies at most one Aggregate. If a use case appears to require modifying two Aggregates atomically, either:
- Reconsider the Aggregate boundary (they may belong together)
- Accept eventual consistency (emit an event from the first Aggregate; the second updates asynchronously)
- Use the Saga pattern for the cross-Aggregate coordination

### Rule 4: The Root Controls All Modifications

External code never directly modifies an Entity or Value Object inside an Aggregate. All modifications go through the Aggregate Root, which enforces invariants before applying the change.

```go
// Correct: modification through root
asset.Classify(SensitivityLevel_Restricted, classifiedBy)

// Wrong: direct field modification
asset.sensitivityLevel = SensitivityLevel_Restricted   // bypasses invariant check
```

### Rule 5: Keep Aggregates Small

A common mistake is making Aggregates too large. An Aggregate should contain only the state it needs to enforce its own invariants. Additional state that doesn't participate in any invariant check doesn't belong inside the Aggregate.

---

## Entities vs Value Objects

Within an Aggregate, Domain Objects are either Entities or Value Objects:

| | Entity | Value Object |
|---|---|---|
| **Identity** | Has a unique identity (ID) that persists across changes | No identity — defined entirely by its attributes |
| **Mutability** | Mutable — state changes over its lifetime | Immutable — replacement, not mutation |
| **Equality** | Equal when IDs are equal, regardless of other attributes | Equal when all attributes are equal |
| **Examples** | `DataAsset`, `StorageSource`, `User` | `SensitivityLevel`, `FilePath`, `EmailAddress`, `DateRange` |
| **Go representation** | Struct with an ID field | Struct with no ID field; all fields unexported; equality by value |

**Prefer Value Objects.** A concept that can be modelled as a Value Object should be. Value Objects are immutable, have no identity management overhead, and are naturally thread-safe.

---

## Aggregate Root in Go

```go
// Aggregate Root
type DataAsset struct {
    id               DataAssetID
    storageSourceID  StorageSourceID
    filePath         FilePath          // Value Object
    fileType         FileType          // Value Object
    sensitivity      SensitivityLevel  // Value Object
    entities         []ExtractedEntity // Entity collection within the Aggregate
    version          int               // Optimistic concurrency
    domainEvents     []DomainEvent     // Uncommitted events — cleared after save
}

// All mutations go through methods on the root; invariants are enforced here
func (a *DataAsset) Classify(level SensitivityLevel, classifiedBy UserID) error {
    if a.filePath.IsEmpty() {
        return ErrDataAssetHasNoPath
    }
    a.sensitivity = level
    a.domainEvents = append(a.domainEvents, DataAssetClassified{
        DataAssetID:    a.id,
        SensitivityLevel: level,
        ClassifiedBy:   classifiedBy,
        OccurredAt:     time.Now().UTC(),
    })
    return nil
}

// Domain events are collected and published after the transaction commits
func (a *DataAsset) Events() []DomainEvent { return a.domainEvents }
func (a *DataAsset) ClearEvents()          { a.domainEvents = nil }
```

---

## Identifying Aggregate Boundaries

Use these heuristics from Event Storming output:

1. **Invariant clustering:** Group Domain Objects that participate in the same invariant. That group is a candidate Aggregate.
2. **Transaction boundary:** Which objects must be consistent at the end of a single user action (Command)? They belong in the same Aggregate.
3. **Event emission:** Which Domain Objects combine to produce a single Domain Event? They likely belong in the same Aggregate.
4. **Contention check:** How many concurrent users will modify this Aggregate simultaneously? High contention → split the Aggregate. Low contention → aggregating is safe.

---

## Aggregate Design Worksheet

For each Aggregate candidate from Event Storming:

```
Aggregate:     [Name]
Root Entity:   [Which Entity is the root]

Invariants:
  1. [Rule that must always be true about this Aggregate's state]
  2. [...]

Entities (within the Aggregate):
  - [Entity name] — [why it needs identity]

Value Objects (within the Aggregate):
  - [VO name] — [what it represents; its equality rule]

Commands Handled:
  - [Command name] → [Resulting Domain Event]

Events Emitted:
  - [Domain Event name]

Cross-Aggregate References (by ID only):
  - [Referenced Aggregate]: [Field name holding the ID]

Contention estimate: [Low / Medium / High — justification]
```

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Invariants documented | Every Aggregate has at least one named invariant | Aggregates with no invariants — they have no reason to exist as a unit |
| Cross-references by ID | Other Aggregates are referenced only by ID | Direct object references to other Aggregates |
| Single-transaction scope | Each Aggregate can be loaded and modified in one transaction | Aggregates that require joining with another Aggregate to enforce an invariant |
| Root controls mutations | All mutations go through public methods on the root | Direct field access bypassing the root |
| Domain events collected | Aggregates collect events internally; publish after commit | Events published inside the transaction (before commit) |
| Value Objects immutable | All Value Objects are immutable | Value Objects with setter methods or mutable fields |

---

## Output Format

```markdown
---
artifact: aggregate-design
product: [product name]
bounded-context: [context name]
version: 1.0.0
phase: design
created: [date]
owner: domain-modeler
---

# Aggregate Design: [Bounded Context Name]

## Aggregate: [Name]

### Root Entity
[Name and responsibility]

### Invariants
1. [Rule that must always be true]

### Entities
| Entity | Identity field | Mutable state |
|---|---|---|

### Value Objects
| Value Object | Attributes | Equality rule |
|---|---|---|

### Commands → Events
| Command | Guard / Invariant checked | Domain Event emitted |
|---|---|---|

### Cross-Aggregate References
| Referenced Aggregate | Field name | Purpose |
|---|---|---|

### Go Type Sketch
```go
type [AggregateName] struct { ... }
func (a *[AggregateName]) [CommandMethod](...) error { ... }
```

[Repeat for each Aggregate]
```
