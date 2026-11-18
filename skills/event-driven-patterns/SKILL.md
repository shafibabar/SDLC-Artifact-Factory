---
name: event-driven-patterns
description: >
  Choose and design how events move between Bounded Contexts and services,
  sized to the product: whether a flow needs a broker at all (in-process
  events inside one deployable at lean); each flow's communication,
  consistency and coordination decided separately, with Event Choreography as
  the default and orchestration sent to workflow-orchestration by Richardson's
  rule; publication by the Transactional Outbox (Change Data Capture only for
  a source that cannot publish); an Idempotent Consumer always, Retry and
  Backoff for transient failures only, and a Dead Letter Queue; the partition
  key chosen from the ordering the flow needs; Competing Consumers (the queue
  model) kept distinct from a consumer group (the log model); Eventual
  Consistency stated per flow and no distributed transaction. Use when
  designing, reviewing or changing asynchronous flows, topics, consumers,
  delivery guarantees or ordering. Used by enterprise-architect and
  backend-engineer.
version: 3.0.3
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, event-driven, choreography, idempotency, transactional-outbox, cdc, dead-letter-queue, partitioning, eventual-consistency]
produces: event-driven-pattern-decisions
domain: architecture
status: stable
related: [integration-design, workflow-orchestration, message-broker-selection, event-schema-design, domain-event-catalog, cqrs-pattern, container-diagram, context-map-patterns, data-pipeline-design, go-event-publisher, go-event-consumer, glossary-management, methodology-review]
sources:
  - research/software-architecture/microservices-patterns-richardson.md
  - research/software-architecture/software-architecture-hard-parts-ford.md
  - research/software-architecture/designing-data-intensive-applications-kleppmann.md
  - research/software-architecture/designing-data-intensive-applications-kleppmann-part2-consistency-consensus.md
  - research/software-architecture/building-microservices-newman.md
  - research/software-architecture/rabbitmq-in-depth-roy.md
  - research/domain-driven-design/implementing-ddd-vernon.md
---

# Event-Driven Patterns

## Purpose

Asynchronous flows fail in ways a synchronous call does not: an event lost between a write and a publish, the same event handled twice, one bad message stalling a partition, events seen out of order. This skill makes each asynchronous flow a recorded decision: whether it needs a broker, how it is coordinated, how it is published and consumed safely, and what order it guarantees. **Readers:** enterprise-architect, backend-engineer, the product owner (what a lost or repeated event does to the business). **Question:** for every flow between Bounded Contexts, what moves, who reacts, and what keeps it correct when something fails?

The output is **not a separate document**: it is the section `## Event-Driven Pattern Decisions` of the Integration Design (`./templates/event-driven-pattern-decisions.md`), so it carries no frontmatter of its own. This skill chooses the design; the code is `go-event-publisher` and `go-event-consumer`; the envelope and its versioning are `event-schema-design`; what an event means is `domain-event-catalog`; the broker is `message-broker-selection`; orchestration is `workflow-orchestration`.

| Profile | What this section holds |
|---|---|
| Lean | Short: flow classification and publication only. Modules of one deployable talk through an in-process event publisher (Vernon); a broker, topics and a Dead Letter Queue only if a flow leaves the deployable. Where an event must leave the process atomically with a write, the Transactional Outbox still applies |
| Standard | Every cross-service flow: classification, publication, topics and ordering, delivery and idempotency |
| Enterprise | As standard, plus a named owner per topic, retention and replay stated, and the orchestration decision for every flow that meets Richardson's rule |

## Procedure

1. **Read** the container diagram (which arrows cross a process boundary), the integration design inventory (its async rows), the NFR specification (ordering, loss tolerance, throughput), the event catalog, and `sdlc-config.json` (stack, `scale_profile`).
2. **Decide whether the flow needs a broker.** Inside one deployable the answer is no: an in-process publisher keeps the same events without topics or operations. A broker earns its place when a flow crosses a process boundary, a consumer must catch up from history, or fan-out is wide (`message-broker-selection`).
3. **Classify each flow on three axes** (Ford): communication (sync or async), consistency (atomic or eventual), coordination (choreographed or orchestrated). Write them on one line, e.g. "async · eventual · choreographed". Never atomic and choreographed together (the "Horror Story" archetype, `./references/choreography-and-sagas.md`). Atomic across services means a boundary was drawn wrong.
4. **Choose the coordination.** Event Choreography is the default: each service reacts to events and no one holds the flow. **Orchestrate** (hand the flow to `workflow-orchestration`) when Richardson's rule fires: the flow branches or loops, runs long (a human, an external signal, hours), someone must ask "where is this one right now?" and get one answer, or compensation must span 4 or more services in a defined order. Draw the event-flow graph; any cycle (A reacts to B reacts to A) is a defect: break it with a terminating condition.
5. **Choose the publication.** A service that emits an event together with its own write uses the **Transactional Outbox**: state change and outbox row in one local transaction, a relay publishes. Never a dual write. **Change Data Capture** only where the source cannot publish (legacy code, a vendor database); its events mirror table rows, not business facts. Inside one deployable, the in-process publisher.
6. **Choose the consumption.** Every consumer is idempotent: the dedup mark and the effect commit in one transaction. **Retry and Backoff** only for transient failures; a permanent failure (invalid message, rejected rule) goes straight to the **Dead Letter Queue**, which keeps the message's original content with the failure reason beside it, has an owner and a way to re-drive, and an alert on its depth. Once a message is parked, later events with the same key wait behind it, so a later change is never applied before an earlier one. At-least-once delivery plus an Idempotent Consumer is *effectively-once*; literal exactly-once across systems is not available (`./references/delivery-guarantees.md`).
7. **Choose the ordering.** Name what must stay in order (one Aggregate, one account, one tenant), and key the partition on that: the Aggregate id by default; the tenant id only for a multi-tenant product that needs per-tenant order. State the guarantee and its limits: order holds within one partition only, group members beyond the partition count get no work, and one hot key is capped at one partition's throughput (`./references/ordering-and-partitioning.md`). Whenever a key is named, even for a broker deferred to later, write those two limits beside it in the answer.
8. **State consistency per flow.** Eventual Consistency is acceptable where the in-between state is a tolerable fact; a synchronous call is required where the caller needs a current answer (an authorization check, a uniqueness rule that must hold now). No two-phase commit across services.
9. **Validate, then loop.** Run `./scripts/validate-event-driven-patterns.sh <file>`, fix every FAIL, re-run until clean; then `./resources/checklist.md`.
10. **Present** with the reason for every request declined (§ Gotchas). Say in one line that this is **a section of the Integration Design** (`design/architecture/integration-design.md`), not a separate artifact, and that it names patterns and no code (the code is `go-event-publisher` and `go-event-consumer`). Answering in a reply: the declined requests and their reasons once, then the section once.

Examples: `./examples/01-lean-in-process-events.md` (a homebrew tracker asking for a broker it doesn't need), `./examples/02-standard-work-orders-and-invoicing.md` (two contexts, choreography, an idempotent consumer, a per-account partition key), `./examples/03-enterprise-shipment-booking.md` (a six-service choreography with compensation diagnosed as a Horror Story and handed to orchestration).

## Gotchas

- **"Make the three services update atomically with a distributed transaction."** *Reason:* two-phase commit blocks: a coordinator crash after the "yes" votes leaves participants holding locks, and availability collapses (Kleppmann). *Instead:* not as asked: local atomicity per service (Outbox) and eventual consistency across them; compensation if one step can fail after others have committed, designed in `workflow-orchestration`. Tell the user plainly what changes: the whole flow is no longer all-or-nothing at one instant, and a customer may briefly see an in-progress state.
- **"Use CDC on our new service to publish events."** *Reason:* Change Data Capture publishes table rows, not business facts, and adds a second mechanism to run. *Instead:* the Transactional Outbox (a log-tailing relay may read the outbox table); CDC only for a source that cannot publish. Never abbreviate Consumer-Driven Contract to CDC.
- **"Set up Redpanda, outbox and DLQ topics for the whole app."** *Reason:* at lean, modules share one deployable; topics, a relay and a dead-letter topic are operations cost for no boundary. *Instead:* an in-process publisher; add a broker when a flow leaves the deployable (Fairbanks' risk-driven sizing, Vernon).
- **"Add competing consumers to the topic to scale and keep order."** *Reason:* Competing Consumers is the queue model: consumers race for messages and ordering across the pool is lost (Roy). A log scales with a **consumer group**, one partition per member, order kept within a partition. *Instead:* name which model the broker is, and scale with a consumer group over partitions, keyed on what must stay in order (the subscription or Aggregate id). Say the limits: members beyond the partition count get no work, and one hot key stays on one partition, so it caps that key's throughput.
- **"Partition by tenant_id."** *Reason:* only right if the product is multi-tenant and per-tenant order is the need; a single huge tenant becomes a hot key, and a single-tenant product has no such key. *Instead:* key on what must stay in order, usually the Aggregate id.
- **"Check processed-ids first, then do the work."** *Reason:* a crash between the check and the write repeats the work. *Instead:* the dedup mark and the effect commit in one transaction; a unique-constraint violation means already processed.
- **"Retry every failure until it works."** *Reason:* a permanent failure retried forever blocks its partition behind it. *Instead:* retry transient errors with backoff and jitter, then the Dead Letter Queue, with an alert.
- **"Orchestrate every multi-step flow."** *Reason:* the orchestrator is a component every participant depends on. *Instead:* choreograph the simple ones; orchestrate when Richardson's rule fires.
- **"The compensation can run without capturing anything; it will look up what to undo."** *Reason:* current state may have changed since. *Instead:* capture the compensation data on the way forward; step classes and compensation design are `workflow-orchestration`'s.

## References

| Question | File |
|---|---|
| Delivery semantics, the Outbox, Change Data Capture, the Idempotent Consumer, Retry and Backoff, the Dead Letter Queue, replay | `./references/delivery-guarantees.md` |
| Choreography in depth, circular chains, the three axes and the eight archetypes, choreographed sagas, eventual consistency, no two-phase commit | `./references/choreography-and-sagas.md` |
| Partition key, hot keys, ordering limits, consumer group versus Competing Consumers | `./references/ordering-and-partitioning.md` |
| The artifact section | `./templates/event-driven-pattern-decisions.md` |
| Checking before hand-off | `./resources/checklist.md` |
