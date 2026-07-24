---
name: aggregate-design
description: >
  Teaches how to design Aggregates in Domain-Driven Design — grounded in
  Eric Evans' foundational tactical patterns, Vaughn Vernon's four
  prescriptive Effective Aggregate Design rules, and Vlad Khononov's
  modern Business Logic Design Pattern catalog and event-sourcing
  guidance. Covers: the prior gate of whether an Aggregate is even the
  right pattern (Transaction Script / Active Record / Domain Model /
  Event-Sourced Domain Model), Aggregate boundary rules and their
  explicit, documented exceptions, Entity/Value Object/Factory/
  Specification/Repository patterns, sizing under contention, identity
  generation and concurrency strategy, cross-Aggregate coordination via
  Domain Events and Sagas, and event-sourced Aggregate design. Includes
  scripts/scaffold-aggregate-design.sh and
  scripts/validate-aggregate-design.sh. Split across seven references/
  files with explicit branching decision trees, not flat prose. Used by
  the domain-modeler agent after Event Storming and Bounded Context
  mapping.
version: 2.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: [design, ddd, aggregate, entity, value-object, invariants, event-sourcing, go]
related: [skill-authoring-standards, subdomain-distillation, bounded-context-mapping, cqrs-pattern, domain-event-catalog, go-domain-model, go-repository-pattern, access-control-model]
---

# Aggregate Design

## Purpose

An Aggregate is a cluster of Domain Objects (Entities and Value Objects) treated as a single unit for data changes. It exists to solve one specific problem: how does a business rule spanning several objects stay true after every transaction, without distributed locking? The answer — per Eric Evans, the pattern's originator — is to draw a boundary around exactly the objects that participate in the rule, appoint one of them the Aggregate Root, and forbid any single transaction from touching more than one such cluster at a time. Every rule below exists to serve that one purpose; none of them is a goal in itself.

Getting Aggregate boundaries right is one of the hardest and most consequential decisions in DDD. Too wide causes contention and poor performance. Too narrow scatters invariants across multiple Aggregates, making them impossible to enforce without distributed coordination. Vaughn Vernon, whose four rules this skill is built around, is explicit that oversized Aggregates — not undersized ones — are the single most common mistake he has seen across DDD engagements, and that the mistake is *seductive*: it comes from a well-intentioned but wrong belief that clustering more together is "safer."

---

## Before You Reach for an Aggregate at All

Not every use case needs the Domain Model pattern. Per Vlad Khononov, a subdomain's classification (`subdomain-distillation`'s Core/Supporting/Generic) is a *necessary* gate but not a *sufficient* one — even a Core-classified Bounded Context routinely contains individual use cases too simple to warrant full Aggregate machinery. Four Business Logic Design Patterns exist, escalating in cost and rigor: **Transaction Script** (a single procedure, no object model, no enforced invariant), **Active Record** (an object per row, CRUD-shaped, no cross-object invariant), **Domain Model** (the full Aggregate/Entity/Value-Object pattern this skill teaches), and **Event-Sourced Domain Model** (Domain Model plus deriving state from an event stream instead of a current-state row). Pick per Aggregate or per use case, not once for a whole Bounded Context. Full decision tree, fit criteria, and worked Go-adjacent guidance: `references/decision-trees-and-worksheets.md`.

The rest of this skill assumes that gate has already pointed to Domain Model (or its event-sourced escalation).

---

## The Rules of Aggregates

These rules are the working default, not universal laws with no exceptions — Vernon himself states this directly, and this skill follows his framing rather than a harder-than-the-source absolutism. A documented, deliberate exception is legitimate; an undocumented one is not. See `references/invariants-and-consistency-boundaries.md`'s "When It's OK to Break These Rules" section before treating any exception as settled.

### Rule 1: Enforce True Invariants Within the Consistency Boundary

A **True Invariant** is a rule that must hold at every instant, has no acceptable after-the-fact compensating fix, and isn't already enforced by an external system. Only a rule that clears all three bars earns a place inside a single Aggregate's transaction. The hard part is not applying this rule — it's telling a True Invariant apart from a business rule that merely *looks* urgent but can tolerate a moment of staleness. Full three-question test, a worked true-invariant example, and — critically — a worked *counter*-example most teams get wrong: `references/invariants-and-consistency-boundaries.md`.

### Rule 2: Design Small Aggregates

Every Aggregate pays a cost proportional to its size, argued from three genuinely separate angles: performance (loading the whole object graph every time), scalability (contention is measured per instance — a big Aggregate concentrates write traffic), and collaboration (legitimate, unrelated user actions collide artificially when they shouldn't need to). Full sizing methodology, the coupling/cohesion trade-off framing, and contention analysis: `references/sizing-contention-and-concurrency.md`.

### Rule 3: Reference Other Aggregates by Identity Only

Store another Aggregate's ID, never a live object reference — and this extends one level deeper than the root's own fields: a Value Object nested inside the Aggregate that embeds a reference to another Aggregate's Entity is the same violation wearing different syntax. The diagnostic that catches most boundary mistakes: separate "does the Ubiquitous Language say this object *has* these others" from "must this object be *atomically consistent* with those others" — a domain expert saying "has" is not evidence the two need to be in the same transaction. Full diagnostic and Go patterns: `references/entities-value-objects-and-domain-primitives.md`.

```go
// Correct: reference by ID
type DataAsset struct {
    id              DataAssetID
    storageSourceID StorageSourceID   // ID only — not *StorageSource
}

// Wrong: reference by object
type DataAsset struct {
    id            DataAssetID
    storageSource *StorageSource      // Direct reference — violates the boundary
}
```

### Rule 4: Use Eventual Consistency Outside the Boundary

A single use case should, ideally, modify exactly one Aggregate instance inside its own transaction. Anything else that logically needs to change as a consequence is updated via eventual consistency — a Domain Event, published reliably, consumed idempotently — never folded into the same atomic unit of work. This is the direct payoff of Rules 1–3, not a compromise: everything correctly pushed outside the boundary is exactly the set of things that never belonged inside it. Full coordination mechanics, Saga pattern, choreography-vs-orchestration trade-offs: `references/cross-aggregate-coordination-and-sagas.md`.

---

## Entities vs Value Objects

The identity-vs-attribute-equality distinction is a **per-Bounded-Context modeling decision**, not an intrinsic property of a concept — the same real-world thing (a `User`) can be an Entity in one context and a Value Object snapshot in another.

| | Entity | Value Object |
|---|---|---|
| **Identity** | Has a unique identity (ID) that persists across changes | No identity — defined entirely by its attributes |
| **Mutability** | Mutable — state changes over its lifetime | Immutable — replacement, not mutation |
| **Equality** | Equal when IDs are equal, regardless of other attributes | Equal when all attributes are equal |
| **Identity scope** | Global (findable from anywhere) if it's an Aggregate Root; local (found only by traversing the root) if it's a child Entity inside one | N/A — no identity to scope |
| **Go representation** | Struct with an ID field | Struct with no ID field; all fields unexported; equality by value |

**Prefer Value Objects.** Every Entity carries ongoing identity-management cost (equality by ID, concurrent-modification handling, lifecycle tracking) a Value Object never incurs — this is the reason for the preference, not just the rule. Full identity/equality reasoning, the Domain Primitive tie-in (the same self-validating-construction discipline `access-control-model` already applies to ABAC attributes, applied here to Aggregate-internal types), Factory and Specification patterns, and Closure of Operations: `references/entities-value-objects-and-domain-primitives.md`.

---

## Identifying Aggregate Boundaries

From Event Storming output:

1. **Invariant clustering:** Group Domain Objects that participate in the same True Invariant. That group is a candidate Aggregate.
2. **Transaction boundary:** Which objects must be consistent at the end of a single Command? They belong together.
3. **Event emission:** Which Domain Objects combine to produce a single Domain Event? They likely belong together.
4. **Contention check:** How many concurrent users will modify this Aggregate simultaneously? High → split. Low → aggregating is safe.
5. **Has-a vs. must-be-atomic-with:** For every candidate relationship, answer both questions separately and in writing. A "has-a: yes, must-be-atomic-with: no" mismatch is the single most common signal of an oversized candidate.

Full worksheet, worked walkthroughs (including a full "one big Aggregate, then correctly split it" narrative), and the complete decision trees: `references/decision-trees-and-worksheets.md` and `references/worked-examples.md`.

---

## Identity Generation and Concurrency Strategy

Prefer **client-generated identity** (a UUID assigned at construction) over persistence-generated (database-surrogate) identity — a fully valid instance, ID included, should exist before the first database write, so a creation-time Domain Event can correctly carry the new Aggregate's ID and a unit test needs zero database dependency. Default to **optimistic concurrency** (a version-field compare-and-swap); pessimistic locking is a narrow, justified exception, never a default reached for out of unfamiliarity with retry handling. Full guidance, Go patterns, and the event-sourced equivalent (conditional append instead of compare-and-swap): `references/go-implementation-patterns.md`.

---

## Scripts

Per `skill-authoring-standards`, this skill owns two deterministic scripts — neither decides whether a design is *correct*, only whether the design document is structurally complete.

| Script | Does | Run when |
|---|---|---|
| `scripts/scaffold-aggregate-design.sh <product> <bounded-context>` | Copies `assets/aggregate-design-template.md`, fills in product/context metadata, writes a new design doc under `artifacts/[product]/design/[bounded-context]/` | Starting Aggregate design for a Bounded Context |
| `scripts/validate-aggregate-design.sh <path>` | Checks required frontmatter, that at least one Aggregate has a named Root Entity and at least one Invariant, that Entities/Value Objects tables have data, and that Cross-Aggregate References are by ID | Before treating the design as ready for the Component Diagram gate |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Business Logic Pattern chosen deliberately | Every Aggregate/use case states which of the four patterns it uses and why | Domain Model applied by default with no consideration of Transaction Script/Active Record |
| True Invariant, not just a rule | Every named invariant passes the three-question test | A "rule" that's really a business process tolerating staleness, forced into the boundary |
| Small Aggregates | Sized to the invariant, not to "everything that seems related" | God Aggregate absorbing unrelated state |
| Cross-references by ID | Other Aggregates — and nested Value Objects referencing them — are by ID only | Direct object references, at the root or nested one level deeper |
| Single-transaction scope | Each Aggregate loads and modifies in one transaction | Requires joining another Aggregate to enforce an invariant |
| Root controls mutations | All mutations go through root methods enforcing invariants | Direct field access bypassing the root |
| Identity generation stated | Client-generated (default) or persistence-generated, with reasoning | Left as an accidental implementation detail |
| Concurrency strategy stated | Optimistic (default) or pessimistic, with the narrow justifying condition named | Assumed rather than chosen |
| Domain events collected, not published early | Collected internally; published after commit via the outbox | Published inside the transaction, before commit |
| Value Objects immutable | All Value Objects are immutable | Value Objects with setters or mutable fields |
| Event Sourcing justified, not defaulted | Adopted only against Khononov's three-question test (temporal query / retroactive projection / audit-as-record) | Adopted because the subdomain is Core Domain, with no specific justifying need |
| Exceptions documented | Any rule-break is deliberate, documented, and matches a named exception criterion | Undocumented exception, or one reached for out of convenience |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Anemic Aggregate** — exported fields or getter/setter pairs, invariants enforced in an application service | Invariant enforcement scatters across every caller; nothing guarantees it runs | All mutation goes through root methods that enforce invariants before applying change |
| **God Aggregate** — one Aggregate absorbs every related concept "to be safe" | Every write serialises on one instance; the mistake is seductive precisely because it *feels* safer, not because anyone intends harm | Keep only invariant-participating state; split the rest into separate Aggregates linked by ID — see the full worked SaaSOvation-style narrative in `references/worked-examples.md` |
| **Repository per Entity** — a repository for each Entity inside the Aggregate | Callers load and mutate internals without the root, bypassing invariants — repositories query by identity, and only roots have queryable identity | One repository per Aggregate, keyed by the root's ID |
| **Cross-Aggregate transaction** — one transaction saves two Aggregates | Couples their locks and availability; violates Rule 4 | Emit a Domain Event from the first; update the second eventually, or coordinate with a Saga |
| **Leaking internal collections** — a getter returns the root's internal slice | A reference is a capability; handing one out bypasses the root exactly as a direct field write would | Return copies or read-only views; expose behaviour, not structure |
| **The has-a trap** — the domain language says one object "has" another, so the modeler clusters them into one Aggregate | Conceptual ownership is a much weaker, more common relationship than transactional-consistency need; conflating them is Vernon's named root cause of oversized Aggregates | Ask both questions separately, in writing, every time |
| **Premature Event Sourcing** — adopting event-sourced persistence because a subdomain is Core Domain and "deserves the best patterns" | Pays real, ongoing costs (upcasting discipline, snapshotting infrastructure, replay-based testing) with no corresponding benefit if none of the three justifying needs actually apply | Require an explicit answer to the temporal-query / retroactive-projection / audit-as-record test before adopting; default to current-state persistence otherwise |
| **Publishing Domain Events before commit** | Consumers act on state that may roll back | Collect events on the root; publish via the Transactional Outbox after commit |
| **Conflating internal and integration events** — publishing every internal event-sourcing state transition as an external contract | Couples other Bounded Contexts to this Aggregate's storage implementation detail | Maintain a deliberate translation step; publish only the coarser, business-meaningful event externally |

Full anti-pattern depth, including why each mistake is seductive rather than merely wrong: `references/invariants-and-consistency-boundaries.md`, `references/sizing-contention-and-concurrency.md`, and `references/worked-examples.md`.

---

## Output Format

Fill-in-and-go: `assets/aggregate-design-template.md` (or generate it directly via `scripts/scaffold-aggregate-design.sh`). Mechanical completeness check: `scripts/validate-aggregate-design.sh`.

---

## References — Which File Do You Need?

| If you're asking... | Go to |
|---|---|
| "Is this actually a True Invariant, or a rule that can tolerate staleness?" / "When is it OK to break these rules?" | `references/invariants-and-consistency-boundaries.md` |
| "How big is too big?" / "Optimistic or pessimistic concurrency?" / "What does write skew have to do with this?" | `references/sizing-contention-and-concurrency.md` |
| "How do two Aggregates coordinate?" / "Saga, choreography, or orchestration?" | `references/cross-aggregate-coordination-and-sagas.md` |
| "Entity or Value Object?" / "Do I need a Factory?" / "What's a Specification?" / "How does this relate to Domain Primitives?" | `references/entities-value-objects-and-domain-primitives.md` |
| "What does the Go code actually look like?" / "Client- or persistence-generated ID?" / "How do I implement an event-sourced Aggregate?" | `references/go-implementation-patterns.md` |
| "Show me a complete, worked Aggregate design, start to finish." | `references/worked-examples.md` |
| "Walk me through the decision, step by step." / "Give me the fill-in worksheet." | `references/decision-trees-and-worksheets.md` |
