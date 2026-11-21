# Building Blocks: Entities, Value Objects, Factories, Specifications

The detail behind `SKILL.md` § 3: what goes inside an Aggregate and how its members are shaped. Grounded in Evans (*Domain-Driven Design*, Ch. 5–6, 9–10) and Johnsson, Deogun & Sawano (*Secure by Design*, Ch. 5–6), as summarised in `research/domain-driven-design/domain-driven-design-evans.md` and `research/security/secure-by-design.md`. Stack-neutral: code shapes are in `go-domain-model`.

## 1. Entity or Value Object, per Bounded Context

Evans's test is behavioural: does **continuity of identity** matter to this context? Should two objects with the same attributes be treated as interchangeable (Value Object) or as distinct individuals whose history is tracked through change (Entity)? The answer belongs to the context, not to the concept. A `Customer` is an Entity in the account context; the customer recorded on an invoice is a Value Object snapshot (`name, address, taxNumber` *as they were when invoiced*), because the invoice must not change when the customer moves.

A snapshot rather than an ID reference is the right choice whenever a record must say *what was true at the time* (an audit actor's role when they acted, a price when it was quoted). An ID resolves to today's state, which may have drifted.

## 2. Prefer Value Objects: the cost asymmetry

Every Entity pays costs a Value Object never pays:

| Cost | Entity | Value Object |
|---|---|---|
| Identity | needs a generation strategy | none |
| Equality | by identity, ignoring attribute drift | by all attributes, always correct |
| Concurrent change | needs concurrency control if mutable | immutable: nothing to race |
| Lifecycle | states to model and enforce | none: a change is a new value |
| Test setup | identity, often persistence, first | one constructor call |

Ask of every candidate: does anything need to track *this instance specifically* through change over time? Only a "yes" earns an Entity. **Immutability is what makes a Value Object safe to share:** any number of Aggregates can hold the same value with no risk one holder's action changes another's view.

## 3. Local or global identity: what belongs inside

An **Aggregate root** has global identity: it can be looked up from anywhere. An **Entity inside an Aggregate** has local identity: unique within its root, reached only through it. The test for every Entity candidate inside a cluster: *would anything outside this Aggregate legitimately look this object up directly by its own identity* (a deep link, a query across all of them, another context reacting to it on its own)? If yes, it wants to be its own Aggregate, referenced by ID. If no, it is a local child with no Repository of its own. **One Repository per Aggregate, never per Entity**: a repository for a child lets callers change it without the root.

## 4. Value Objects are Domain Primitives

*Secure by Design*'s Domain Primitive is the same concept as Evans's Value Object, with one guarantee made load-bearing: **an invalid instance cannot exist**. It is immutable, has no identity, and can be built only through a constructor that rejects invalid input. A Value Object that can hold an invalid value and relies on callers to remember a validity check is not yet a Domain Primitive. In the design, mark which Value Objects are self-validating and state the rule each enforces at construction (an `EmailAddress` that must parse; a `Money` whose currency must be known; a `DateRange` whose end may not precede its start). `access-control-model` applies the same discipline to access-control attributes.

## 5. Reference by ID, one level deeper

Rule 3 applies inside Value Objects too: a Value Object that embeds another Aggregate's Entity is the same boundary violation as the root holding it. Value Objects composed of other Value Objects are fine (`DateRange` from two dates); a Value Object holding *another Aggregate* is not. Check every member's attributes, not only the root's. A denormalised display copy (another Aggregate's name next to its ID) is allowed only under Exception 2 (`./invariants-and-boundaries.md` § 4) and is never authoritative.

## 6. Factories

A plain constructor is enough when construction validates only the new object's own attributes. Evans's three reasons for a Factory (usually a factory method, a dedicated object only when no created type is the natural home):

1. construction enforces a rule across several objects created together;
2. construction chooses between several concrete shapes based on input;
3. **reconstitution from storage** differs from creation: it must not re-run creation-time checks against today's rules and must not record a creation event again.

Reason 3 applies to almost every Aggregate: name a creation path and a separate reconstitution path in the design.

## 7. Specifications

When one business rule is checked in several places (a batch selection, a Command's guard, an eligibility badge in the UI), it drifts the first time someone changes one copy. Evans's **Specification** is a named, testable predicate ("eligible for renewal", "overdue") that every place uses. It localises the problem rather than removing it: a database query may still need a second, paired form of the rule, kept in step by one shared set of tests. Name each Specification in the design with the places that use it.

## 8. Closure of operations

An operation on a Value Object that returns the same type composes cleanly and needs no reinterpretation: `Money.add(Money) → Money`, `DateRange.overlap(DateRange) → DateRange`. Prefer it over operations that drop to bare numbers or strings the caller must revalidate.
