# Sizing, Contention, and Concurrency

Self-contained — loadable without reading `SKILL.md` first.

**STATUS: STUB — full content to be written in sub-issue #180 (d5).** This file's job: give a modeler the full sizing methodology and the concurrency-strategy decision, grounded in `research/domain-driven-design/implementing-ddd-vernon.md` (the three sizing angles, the has-a-vs-atomic diagnostic extended to eager-loading), `research/domain-driven-design/learning-ddd-khononov.md` (coupling/cohesion framing), and `research/software-architecture/designing-data-intensive-applications-kleppmann*.md` (write skew, isolation levels).

## The Three Sizing Angles — Performance, Scalability, Collaboration
[Stub: Vernon's three genuinely separate arguments for small Aggregates, kept distinct rather than blended into one "small is good" instinct.]

## Sizing as a Coupling/Cohesion Trade-off
[Stub: Khononov's reframing — a larger Aggregate buys cohesion (more rules enforced by one mechanism) at the direct cost of coupling (every operation touching any part now contends). The same vocabulary that governs Bounded Context and service-boundary sizing elsewhere.]

## Write Skew and Why Optimistic Concurrency Isn't Automatically Safe
[Stub: Kleppmann's write-skew concept applied precisely to a version-field compare-and-swap — the specific scenario where two transactions each read a consistent snapshot, each individually satisfy an invariant against what they read, and the invariant is violated once both commit. Concrete Go/pgx example.]

## Decision Tree: Optimistic Concurrency, Pessimistic Locking, or Serializable Isolation
[Stub: an explicit if/then branching structure — not prose to infer branches from — covering when each of the three is the right choice for a given Aggregate's expected contention profile.]

## Unbounded Collections and the Eager-Loading Trap
[Stub: Vernon's own example (a root that must eagerly load an unbounded child-ID collection "for convenience") connected explicitly to this skill's existing "unbounded collections force a split" rule — Vernon frames this as the same underlying mistake as oversized Aggregates, not a separate concern.]

## Retry-on-Conflict: Normal Operation vs. a Boundary Smell
[Stub: existing content to preserve and deepen — if conflict retries appear in normal operation rather than edge cases, the boundary is wrong, not the retry logic.]
