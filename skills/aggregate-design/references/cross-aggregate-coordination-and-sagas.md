# Cross-Aggregate Coordination and Sagas

Self-contained — loadable without reading `SKILL.md` first.

**STATUS: STUB — full content to be written in sub-issue #181 (d6).** This file's job: full depth on Vernon's Rule 4 (eventual consistency outside the boundary) and multi-Aggregate business processes, grounded in `research/domain-driven-design/implementing-ddd-vernon.md` (reliability/idempotency requirements, the two publication mechanisms), `research/software-architecture/software-architecture-hard-parts-ford.md` (distributed transaction patterns), and this repo's existing `event-driven-patterns`/`domain-event-catalog` terminology (choreography vs. orchestration — cross-reference, don't duplicate).

## Why Eventual Consistency Is the Correct Outcome, Not a Compromise
[Stub: Vernon's framing — everything correctly pushed outside the Aggregate boundary is exactly the set of things that never belonged inside it.]

## Reliability Requirements for the Publishing Side
[Stub: at-least-once, durable delivery (crash-safe between the source Aggregate's commit and the event reaching the consumer) — and how this repo's existing Transactional Outbox (go-event-publisher) already satisfies it, traced to Vernon's own IDDD Ch. 8 guidance, predating the popularized "Transactional Outbox" term.]

## Idempotency Requirements for the Consuming Side
[Stub: at-least-once delivery means the same event may be processed more than once — the consumer must be idempotent. Cross-reference existing processed_events dedup pattern.]

## In-Process vs. Durable Publication
[Stub: Vernon's distinction between a simple, synchronous in-process publisher for same-process subscribers and the full durable/async mechanism for cross-process or cross-context subscribers — when each is actually the right choice.]

## The Saga Pattern for Multi-Aggregate Business Processes
[Stub: compensating actions, choreography vs. orchestration trade-offs for coordinating several Aggregates through an ordered, possibly-reversible business process — cross-referencing this repo's existing event-driven-patterns/integration-design content rather than re-deriving it.]

## Decision Tree: Is This a Modeling Smell or a Genuine Business Process?
[Stub: explicit if/then branches distinguishing "this cross-Aggregate operation reveals the boundary is wrong" from "this is a genuinely multi-step business process that legitimately needs a Saga."]
