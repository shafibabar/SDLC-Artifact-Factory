---
name: aggregate-design
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

### Business Logic Pattern
[Transaction Script / Active Record / Domain Model / Event-Sourced Domain Model] — [one-line justification naming the Decision Tree 1 branch taken]

### Invariants
1. [Rule that must always be true] — Q1: [yes/no] Q2: [yes/no] Q3: [yes/no]

### Rejected Candidate Invariants
- [Rule considered and correctly rejected] — [why it failed the True Invariant test]

### Entities
| Entity | Identity field | Mutable state | Why local, not its own Aggregate |
|---|---|---|---|

### Value Objects
| Value Object | Attributes | Equality rule | Domain Primitive? (self-validating) |
|---|---|---|---|

### Commands → Events
| Command | Guard / Invariant checked | Domain Event emitted | Published as-is / translated / internal-only |
|---|---|---|---|

### Cross-Aggregate Relationships
| Referenced Aggregate | Has-a? | Must-be-atomic-with? | Conclusion | Reference shape |
|---|---|---|---|---|

### Identity Generation Strategy
[Client-generated (default) / persistence-generated / NextIdentity()] — [reasoning if not the default]

### Concurrency Strategy
[Optimistic (default) / pessimistic / serializable] — [Decision Tree 4 branch taken; justifying condition if not optimistic]

### Event Sourcing Justification
[Which of Q1/Q2/Q3 passed, or "not applicable — current-state, no qualifying need"]

### Cross-Aggregate Coordination
[modeling smell (redraw boundary) / plain choreography / genuine Saga, with step classification if a Saga]

### Contention Estimate
[Low / Medium / High] — [reasoning: write frequency, population of writers, burstiness]

### Exceptions Taken
- [Rule broken] — [Exception 1 (true cross-object invariant) or Exception 2 (measured performance bottleneck)] — [documentation]

### Go Type Sketch
```go
type [AggregateName] struct { ... }
func (a *[AggregateName]) [CommandMethod](...) error { ... }
```

[Repeat "## Aggregate: [Name]" for each Aggregate in this Bounded Context]
