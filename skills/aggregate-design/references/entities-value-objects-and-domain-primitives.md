# Entities, Value Objects, and Domain Primitives

Self-contained — loadable without reading `SKILL.md` first.

**STATUS: STUB — full content to be written in sub-issue #181 (d6).** This file's job: the full Entity/Value Object/Factory/Specification depth, grounded in `research/domain-driven-design/domain-driven-design-evans.md`, and the tie-in to `research/security/secure-by-design.md`'s Domain Primitive pattern already implemented in `access-control-model`.

## Identity vs. Attribute Equality, Per Bounded Context
[Stub: Evans' behavioral test — is continuity of identity meaningful to the application, or are two identical-attribute instances interchangeable? The same real-world thing can be an Entity in one context and a Value Object in another (a `User` in Identity & Access vs. a `User` snapshot embedded in an audit record).]

## Why Value Objects Are Preferred: the Cost Asymmetry
[Stub: identity-management overhead (equality by ID, concurrent-modification handling, lifecycle tracking) an Entity always pays and a Value Object never does.]

## Immutability Enables Sharing
[Stub: because a Value Object never changes after construction, multiple Aggregates or threads can safely hold copies without any risk of one holder's mutation corrupting another's view.]

## Local vs. Global Identity: the Test for What Belongs Inside
[Stub: Evans' distinction — Aggregate Roots need global identifiers findable from anywhere; child Entities inside an Aggregate need only local identity, found by traversing the root. The actual test for "does this collaborator need its own Entity identity, or can it be demoted to a Value Object or a locally-scoped child Entity."]

## Value Objects Are Domain Primitives Too
[Stub: the direct tie to access-control-model's already-established Domain Primitive pattern (self-validating construction, the Go zero-value trap, the discarded-constructor-error failure mode) — the SAME discipline applied to Aggregate-internal Value Objects like SensitivityLevel, FilePath, DateRange, not a separate concept requiring separate teaching.]

## Rule 3 One Level Deeper: Value Objects Referencing Other Aggregates
[Stub: a Value Object embedding a live reference to another Aggregate's Entity is the same boundary violation as the root doing it directly — extend the reference-by-ID rule explicitly to nested Value Objects.]

## The Factory Pattern: When a Constructor Isn't Enough
[Stub: Evans' decision test — construction needs a Factory (even if implemented as a plain Go constructor function) when it enforces invariants spanning multiple objects created together, chooses among concrete implementations, or needs a materially different path for reconstitution vs. genuine creation. Tie to go-domain-model's existing NewDataAsset/Reconstitute split as an already-correct, uncredited factory-method pair.]

## The Specification Pattern: Naming a Recurring Business Rule
[Stub: an explicit, named, testable predicate object for a rule that recurs across a query filter, a validation check, and a UI-facing eligibility check — extracted once, reused everywhere, instead of drifting out of sync across three separate implementations. This repo's clearest genuinely-new-content gap per the Evans research.]

## Closure of Operations
[Stub: a Value Object operation that returns the same type (e.g. DateRange.Overlap(other) (DateRange, bool)) is easier to compose and test than one that degrades to primitive types.]
