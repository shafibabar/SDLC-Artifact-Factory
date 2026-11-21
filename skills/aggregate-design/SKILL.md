---
name: aggregate-design
description: >
  Design the Aggregates of a Bounded Context, or a lean product's single
  domain model: decide whether a use case needs a Domain Model at all or
  only a Transaction Script or Active Record, whether a business rule is a
  true invariant (the three-question test), where the consistency boundary
  goes, one Aggregate or two (has-a versus must-be-atomic), Entity or Value
  Object, reference by ID, identity and concurrency strategy, write skew,
  and whether event sourcing is justified. Use when drawing, sizing,
  splitting or reviewing an Aggregate, when an Aggregate is too large or
  contended, when one use case changes several Aggregates, when deciding
  whether a cross-Aggregate process is a Saga, or when someone proposes
  event sourcing or a Domain Model because a subdomain is Core. Writing the
  Aggregate in code is go-domain-model; persistence is go-repository-pattern.
  Used by domain-modeler.
version: 3.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: [design, domain-modeling, ddd, aggregate, invariants, entity, value-object, event-sourcing, concurrency, consistency-boundary]
produces: [aggregate-design, domain-model]
domain: domain-modeling
status: stable
related: [subdomain-distillation, bounded-context-mapping, ubiquitous-language, event-storming-facilitation, domain-event-catalog, command-catalog, read-model-design, cqrs-pattern, event-driven-patterns, go-domain-model, go-repository-pattern, access-control-model]
sources:
  - research/domain-driven-design/domain-driven-design-evans.md
  - research/domain-driven-design/implementing-ddd-vernon.md
  - research/domain-driven-design/learning-ddd-khononov.md
  - research/security/secure-by-design.md
  - research/software-architecture/designing-data-intensive-applications-kleppmann-part2-consistency-consensus.md
  - research/software-architecture/microservices-patterns-richardson.md
---

# Aggregate Design

## Purpose

An Aggregate answers one question (Evans): how does a business rule that spans several objects stay true after every transaction, without locking across the system? Draw a boundary around exactly the objects the rule involves, make one of them the root, and let one transaction change one such cluster. Everything below serves that purpose. Getting the boundary wrong costs in both directions: too wide and writers contend; too narrow and a rule can't be enforced. Vernon finds the wide mistake far more common, and seductive, because clustering *feels* safer.

## 1. First: Does This Use Case Need an Aggregate?

Khononov names four business-logic patterns, rising in cost: **Transaction Script** (one procedure, no object model), **Active Record** (one object per row, simple single-record behaviour), **Domain Model** (Aggregates with invariants enforced by the root) and **Event-Sourced Domain Model** (a Domain Model whose state is replayed from its events). Choose **per use case or per Aggregate**, never once for a context: a Core context routinely holds use cases too simple for a Domain Model.

The deciding question is not the subdomain type but: **is there a rule across more than one record that must hold at every instant?** If not, it's a Transaction Script or an Active Record. A single-record rule ("a plot has one tenant") is a constraint on that record, not a reason for an Aggregate. Use `subdomain-distillation`'s Modelling column as a cross-check. Decision path and fit criteria: `./references/business-logic-patterns.md`.

## 2. Is It a True Invariant?

Vernon's three questions, answered **in writing against one sentence stating the rule**:

1. **Real harm:** would a momentary violation cause real business harm if left uncorrected?
2. **Fixable later:** can a reasonable compensating action (a reconciliation, a human fix, a refund) correct it with no lasting harm?
3. **Enforced elsewhere:** does something else already enforce it?

Only **yes / no / no** puts the rule inside a consistency boundary. Anything else is handled outside: a Domain Event and an idempotent reaction, a query, a Read Model, or the system that already enforces it. Derived values (counts, totals, balances kept in lockstep) are the commonest false invariant. Record rejected candidates with their answers. The boundary must coincide with one transaction: "check the other Aggregate first, then write mine" does not enforce a rule spanning two (write skew). Worked pairs, the transaction link and Assertions: `./references/invariants-and-boundaries.md`.

## 3. Drawing the Boundary

- **Has-a is not must-be-atomic.** For every candidate relationship, answer both separately: does the language say one *has* the other, and is there a True Invariant needing them changed together? "Has-a yes, atomic no" is Vernon's root cause of oversized Aggregates: keep them separate.
- **Rule 1: true invariants inside the boundary.** **Rule 2: small Aggregates**, checked from three separate angles (performance, scalability, collaboration). **Rule 3: other Aggregates by ID only**, including inside nested Value Objects. **Rule 4: eventual consistency outside the boundary**: one use case changes one Aggregate instance in its transaction.
- **Prefer Value Objects.** An Entity pays for identity, equality, concurrency and lifecycle; a Value Object pays for none. Entity or Value Object is decided per context (does continuity of identity matter *here*?). Make Value Objects self-validating Domain Primitives (*Secure by Design*). A child Entity has local identity and no Repository; anything looked up from outside on its own is its own Aggregate.
- **The rules are defaults, not laws** (Vernon). Two documented exceptions only: a genuine cross-object invariant such as a debit and its credit (accept a wider Aggregate), and a *measured* read bottleneck (a read-only copy, never authoritative).

Building blocks (Factories, Specifications, closure of operations): `./references/building-blocks.md`. Sizing and the two exceptions: `./references/invariants-and-boundaries.md` § 3–4.

## 4. Identity and Concurrency, Stated per Aggregate

- **Identity:** client-generated by default, so a valid instance and its creation event exist before storage. A business identifier (a case number) is reserved through the Repository. Storage-generated identity needs a written reason.
- **Concurrency:** optimistic by default (a version check, a bounded retry, then the conflict is shown). Pessimistic only for a named condition (a hot instance, a costly retry, a sequential batch job). A version check on one row cannot catch a rule spanning two Aggregates' rows (Kleppmann's write skew): redraw the boundary, use a database constraint or serialisable isolation scoped to that rule, or accept eventual consistency. Routine conflicts mean the boundary is wrong, not the retry budget.

Decision tree, write-skew timeline, unbounded collections: `./references/sizing-and-concurrency.md`.

## 5. Coordination Between Aggregates

A consequence in another Aggregate travels as a Domain Event, recorded in the same transaction and published after commit (`event-driven-patterns`), consumed idempotently. The user sees a pending state meanwhile. A Saga is only for a named multi-step process where a later step can fail after earlier ones committed. A rule with zero tolerance for an in-between state is never a Saga: redraw the boundary. Each Saga step is a one-Aggregate transaction, and each compensation is a real Command on the root. Decision tree and step rules: `./references/coordination-and-sagas.md`.

## 6. Event Sourcing: Justified, Never Defaulted

Adopt it for an Aggregate only when at least one need applies to *that Aggregate* (Khononov): **temporal query** (its state as of a past moment), **retroactive projection** (new Read Models from history already lived), or **audit-as-record** (the stream itself must be the authoritative record). "The subdomain is Core" is not a need, and neither is "we need an audit trail": events in an audit store usually meet that. When adopted, name the costs (upcasting kept forever, snapshots, event-sequence tests), and publish coarser translated events, not the internal stream. Detail: `./references/business-logic-patterns.md`.

## Producing the Design

Standard and enterprise: one `design/<context>/aggregates.md` per Bounded Context (`./templates/aggregates.md`). Lean: one `design/domain-model.md` for every context, also covering Domain Events, Commands and Read Models (`./templates/domain-model.md`). No code (D047-10).

1. **Read** the context's language (`design/<context>/ubiquitous-language.md`), the Software Design Event Storming output where it exists (Aggregate candidates, Commands, events, hotspots), the subdomain classification and the context map. At lean, read the Big Picture and context map.
2. **For each use case,** write the candidate rules as single sentences and run § 2's test. Decide the pattern (§ 1): a Transaction Script or Active Record becomes a `## Use case:` block, a Domain Model a `## Aggregate:` block.
3. **For each Aggregate,** draw the boundary (§ 3): has-a vs must-be-atomic for each relationship; members as Entities or Value Objects; Commands with their guard and guarantee and the event they record. Then identity, concurrency and contention (§ 4), coordination (§ 5) and event sourcing (§ 6). Plan → validate → execute: a boundary that moves after `domain-event-catalog` or code exists is costly, so check the boundaries against the checklist before writing the catalogues.
4. **Agent-run:** mark a verdict that rests on an assumption about business tolerance (is a minute of staleness acceptable?) as *assumed*, with an open question for the product owner.
5. **Validate, then loop.** Run `./scripts/validate-aggregate-design.sh <file>`. Fix every FAIL and run it again until it exits clean, then go through `./resources/aggregate-checklist.md` for what the script can't judge.
6. **Present** each Aggregate with its invariants, the rules rejected and why, any exception or event sourcing with its justification, and, for every request you declined, its reason in full (§ Gotchas).

Examples: `./examples/01-lean-allotment-waiting-list.md` (no Aggregate needed), `./examples/02-standard-hotel-bookings.md` (the has-a trap and a rule spanning Bookings), `./examples/03-enterprise-marketplace-ledger.md` (a balanced entry, write skew, a Saga and justified event sourcing).

## Gotchas

Each trap comes with the reason to give in full.

- **"The Room has its Bookings, so one Aggregate keeps them consistent."** *Reason:* conceptual ownership is not a transactional need; Vernon names this has-a trap as the root cause of oversized Aggregates, which contend per instance and load unbounded collections. *Instead:* answer has-a and must-be-atomic separately for each relationship; keep them separate unless a True Invariant needs both in one transaction.
- **"It's Core, so model it as a full Domain Model" (or "so event-source it").** *Reason:* Khononov chooses the pattern per use case from its rules, not its subdomain; a Domain Model needs a rule across records that must hold at every instant, and event sourcing needs temporal query, retroactive projection or audit-as-record for *this* Aggregate. Both carry real ongoing cost. *Instead:* run § 1's question and § 6's three needs; accept a Transaction Script, an Active Record or current-state persistence where they fit.
- **"Keep the total/count field always in step with the lines."** *Reason:* a derived value fails the three-question test (it can be recomputed or projected, Q2/Q3), and keeping it in lockstep widens the boundary and its contention. *Instead:* compute at query time or project into a Read Model; record it as a rejected candidate.
- **"Check the other Aggregate first, then save ours — that enforces it."** *Reason:* the other Aggregate can change between the read and the commit; each version check guards only its own row, so the rule breaks under write skew (Kleppmann). *Instead:* redraw the boundary around the rule, express it as a database constraint, scope serialisable isolation to it, or accept eventual consistency with a compensating action, and say which.
- **"Small Aggregates is the rule, so split the debit from the credit."** *Reason:* Vernon is not absolutist; a genuine cross-object invariant such as a balanced entry is Exception 1, and splitting it creates accounting errors. *Instead:* make the entry that holds both postings the Aggregate, so the rule sits inside one boundary; if the rule really spans two existing Aggregates, take Exception 1 and document it.
- **"Conflicts are frequent; raise the retry limit."** *Reason:* routine conflicts on ordinary traffic are the collaboration angle showing that unrelated actions share one Aggregate. *Instead:* re-size the boundary; keep retries small and bounded.
- **"This multi-Aggregate step needs a Saga."** *Reason:* a Saga is for a named process whose later step can fail after earlier ones committed; a rule that can't tolerate an in-between state is a boundary drawn in the wrong place. *Instead:* run the smell-or-Saga tree; each step changes one Aggregate, each compensation is a Command on its root.
- **"Publish every event from the event-sourced stream."** *Reason:* internal events mirror how the Aggregate stores itself, so publishing them couples other contexts to that storage choice (Khononov). *Instead:* translate to coarser, business-meaningful events; keep some internal only.
- **Writing structs or classes in the design.** *Reason:* design skills are stack-neutral (D047-10). *Instead:* name members, rules, Commands and events; the code is `go-domain-model`.

## References

| Question | File |
|---|---|
| Which pattern? Is event sourcing justified? Internal vs published events? | `./references/business-logic-patterns.md` |
| True Invariant? One Aggregate or two? The exceptions? Assertions? | `./references/invariants-and-boundaries.md` |
| How big? Optimistic or pessimistic? Write skew? Identity? | `./references/sizing-and-concurrency.md` |
| Entity or Value Object? Local identity? Factory, Specification? | `./references/building-blocks.md` |
| Event, choreography or Saga? Compensations? | `./references/coordination-and-sagas.md` |
| Checking before hand-off | `./resources/aggregate-checklist.md` |
