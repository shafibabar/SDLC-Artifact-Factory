---
name: integration-design
description: >
  Design how each pair of services, modules or external systems talks: the
  interaction shape (request/response, request/acknowledge, event), decided
  apart from consistency (atomic or eventual) and coordination (orchestrated
  or choreographed); the contract and how strict it is, guarded by a
  Consumer-Driven Contract test (never abbreviated CDC); resilience sized to
  the call's risk and the profile (an external call always has a timeout;
  retry only idempotent calls or with an idempotency key; the full stack of
  timeout, retry with jitter, circuit breaker and bulkhead per downstream,
  and an observable fallback for cross-service and external calls at standard
  and enterprise; in-process module calls need none); the anti-corruption
  layer for a foreign model; and how one context reads another's data (API
  composition, event replication, Change Data Capture), never a shared
  database. Request/reply over a broker is avoided. Async mechanics point to
  event-driven-patterns, orchestration to workflow-orchestration. Use when
  designing, reviewing or changing an integration, an integration inventory,
  retries, timeouts or circuit breakers. Used by enterprise-architect.
version: 3.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, integration, synchronous, asynchronous, resilience, circuit-breaker, idempotency, anti-corruption-layer, consumer-driven-contract]
produces: integration-design
domain: architecture
status: stable
related: [context-map-patterns, container-diagram, event-driven-patterns, workflow-orchestration, event-schema-design, api-contract-design, grpc-contract-design, api-gateway-design, go-contract-test, data-model-design, read-model-design, nfr-specification, opentelemetry-instrumentation, adr-authoring, glossary-management, methodology-review]
sources:
  - research/software-architecture/software-architecture-hard-parts-ford.md
  - research/software-architecture/fundamentals-of-software-architecture-richards-ford.md
  - research/software-architecture/building-microservices-newman.md
  - research/software-architecture/system-design-interview-xu.md
  - research/software-architecture/software-architecture-in-practice-bass.md
  - research/software-architecture/just-enough-software-architecture-fairbanks.md
---

# Integration Design

## Purpose

Every integration is a dependency; an undesigned one becomes hidden coupling that surfaces as an incident. This skill makes each interaction a recorded decision: its shape, its consistency and coordination, its contract, the resilience it needs, and where a foreign model is translated. **Readers:** enterprise-architect, backend-engineer, platform-engineer, the product owner (what fails when a partner is down). **Question:** for every arrow on the container diagram and every external system, how does it talk, what does it promise, and what happens when the other side is slow or down?

Runs after the context map (`context-map-patterns`: who talks, in what relationship) and the container diagram (which arrows cross a process boundary). One artifact: `design/architecture/integration-design.md` (`./templates/integration-design.md`).

| Profile | Artifact |
|---|---|
| Lean | Optional, only when the product calls an external system: a short inventory of those calls with their timeouts, idempotency and any risk-accepted choice. Module-to-module calls inside the monolith are in-process; none is listed |
| Standard | Optional: every cross-service and external integration, sized by risk |
| Enterprise | Required: every integration, the full stack on cross-service and external calls, timeout budgets across chains |

## 1. Three Questions per Integration (Ford, *Hard Parts*)

Decide each separately; conflating them is the common error:
1. **Communication shape.** **Request/response** when the caller can't finish its work without the answer; **request/acknowledge** (`202` and a status to poll) when the work is long; **event** when the caller needs no answer, many react, or the other side's failure must not reach the caller. Across Bounded Contexts, events are the default and sync is the justified exception. Availability multiplies down a sync chain: three 99.9% services in series give 99.7%.
2. **Consistency.** Atomic or eventual. Most cross-context flows are eventual; atomic across services means one transaction boundary was drawn wrong, or a saga.
3. **Coordination.** For a multi-step flow: choreographed (each reacts to the last event; `event-driven-patterns`) or orchestrated (a coordinator; `workflow-orchestration`, D047-3). Never atomic and choreographed together (Ford's "Horror Story").

**Request/reply over the broker** (publish, then wait for a reply event) is the wrong shape: it keeps the temporal coupling and loses the timeout and backpressure. Use a sync call with resilience; events are facts, fire and forget.

Detail and worked decisions: `./references/sync-vs-async-decision.md`.

## 2. Contracts

- **Strictness** (static coupling, Ford): **strict** (typed, e.g. Protobuf: compile-time safety, producer and consumer evolve together) or **loose** (JSON read by a **tolerant reader** that ignores unknown fields: independent evolution, runtime risk). Record it per integration; two Customer/Supplier relationships can carry very different risk.
- **Consumer-Driven Contract** on every integration (Newman): the consumer states the fields it reads; the provider's build fails if it stops honouring them (`go-contract-test`, `event-schema-design`). Always spelled out: **CDC means Change Data Capture**, never this.
- **Stamp coupling:** send and translate only the fields a named consumer needs.
- **Smart endpoints, dumb pipes:** no routing or business rules in the broker, gateway or a topic.

## 3. Resilience Sized to Risk (Fairbanks)

Spend design effort where being wrong is expensive, and record what was consciously left light.

| Call | Minimum |
|---|---|
| In-process (modules of one deployable) | Nothing network-related; it isn't a remote call |
| Any external system, any profile | A **timeout**; retry only if idempotent or carrying an **idempotency key** the provider deduplicates on; a defined failure response |
| Cross-service or external, standard and enterprise | The full stack: timeout, retry with backoff and jitter, **circuit breaker per downstream**, **bulkhead** (own pool per downstream), an **observable fallback** |
| Hot path or long chain | Also a **timeout budget**: each caller's deadline exceeds its downstream's whole retry envelope; the remaining deadline is passed down |

- **A timeout is an unknown outcome.** Retrying a non-idempotent write (a payment, an order) can duplicate it. Without an idempotency key, don't auto-retry: surface the uncertainty and reconcile.
- **Nesting order:** timeout inside retry inside breaker inside bulkhead; fallback catches what the stack refuses.
- **A lighter choice is recorded as risk-accepted** with its reason ("hacked, not designed", Fairbanks), never silently skipped.
- Overload protection names its rate-limiting algorithm and where it is enforced (gateway, service), and rejects with `429` and rate-limit headers (Xu); fault detection and recovery tactics come from Bass.

Breaker states, thresholds, budgets, fallbacks: `./references/resilience-patterns.md`.

## 4. Foreign Models and Other Contexts' Data

- **Anti-corruption layer** for every external system and any context whose model differs: the domain declares a port in its own language; the adapter calls the foreign API and translates. A foreign type never reaches the domain.
- **Reading another context's data**, named per read path: **API composition** (call the owner live: fresh, adds a sync hop), **event replication** (project the owner's Domain Events locally: eventual, independent), **Change Data Capture** (stream the owner's database log: only when the owner can't publish events; it leaks the owner's schema).
- **Never a shared database.** Two services writing or reading one schema can't deploy apart. If they seem to need it, the boundary is wrong.

Detail: `./references/integration-patterns.md`.

## 5. Async Integrations: What This Artifact Records

This skill records **which mechanism** each async integration uses; the design lives in `event-driven-patterns` (outbox, idempotent consumer, dead-letter queue, ordering) and the code in `go-event-publisher` / `go-event-consumer`. Per async row: publisher via the Transactional Outbox (or Change Data Capture and why); each consumer idempotent, with its own consumer group, retry policy and Dead Letter Queue. A synchronous external call inside a consumer's critical path gets its own resilience, or becomes its own step. **Inbound webhooks and callbacks** from external systems are at-least-once and may arrive out of order: handle them idempotently (record the event id, ignore repeats, move state only forward).

## Procedure

1. **Read** the context map, the container diagram (communication matrix and topics), the NFR specification (availability, latency, RTO), `sdlc-config.json`, existing API contracts and the event catalog.
2. **List** every integration: each cross-process arrow and each external system. Lean: only the external calls.
3. **Decide** the three questions for each (§ 1), and the contract and its strictness (§ 2).
4. **Size the resilience** (§ 3) and write the risk-accepted reason for anything below the profile's default. Write timeout budgets for chains.
5. **Foreign models and data reads** (§ 4); async rows point to `event-driven-patterns` (§ 5).
6. **Validate, then loop.** Run `./scripts/validate-integration-design.sh design/architecture/integration-design.md`, fix every FAIL, re-run until clean; then `./resources/checklist.md`.
7. **Present** with the reason for every request declined (§ Gotchas). Consequential choices (a sync dependency on a critical partner, a Change Data Capture integration) get an ADR. Answering in a reply: the declined requests and their reasons once, then the artifact once.

Examples: `./examples/01-lean-external-calls.md` (a dog-walking booking app: two external calls, timeouts and an idempotency key, one call risk-accepted), `./examples/02-standard-payment-and-events.md` (a meal-kit subscription service: a payment call with the full stack and an idempotency key, events with outbox and dead-letter queue, an anti-corruption layer for the courier API), `./examples/03-enterprise-budgets-and-orchestration.md` (a cross-border remittance platform: a timeout budget across a three-hop chain, per-region partners, an orchestrated payout pointing to workflow-orchestration).

## Gotchas

Each trap comes with the reason to give in full.

- **"Retry the POST to the payment provider three times on timeout."** *Reason:* a timeout is an unknown outcome; the charge may have gone through, and a retry can charge twice. *Instead:* retry only with an idempotency key the provider deduplicates on; without one, don't auto-retry: mark it pending and reconcile.
- **"Use request/reply over the broker for this lookup."** *Reason:* waiting for a reply event keeps the temporal coupling and loses timeouts and backpressure. *Instead:* a synchronous call with resilience; events state facts.
- **"Let the two services share the table; it's simpler."** *Reason:* neither can change the schema without the other, and invariants leak. *Instead:* API composition, event replication, or Change Data Capture.
- **"One circuit breaker for all downstreams."** *Reason:* one failing partner opens it for the healthy ones. *Instead:* one breaker and one pool per downstream.
- **"Wrap every call in the full stack, module calls too."** *Reason:* an in-process call has no network to fail; the stack adds cost and noise (Fairbanks). *Instead:* resilience on remote calls, sized by risk.
- **"We're small; skip the timeouts."** *Reason:* an external call without a timeout inherits the partner's worst case and hangs the caller. *Instead:* a timeout on every external call, at every profile.
- **"Call the partner API inside the event consumer."** *Reason:* the consumer's lag grows behind the slowest partner and redeliveries multiply the load. *Instead:* its own resilience, or a separate step and topic.
- **"Use CDC on our new service to publish events."** *Reason:* Change Data Capture leaks the table schema; a service you own can publish intentional Domain Events. *Instead:* the Transactional Outbox (log tailing may relay the outbox table); Change Data Capture of business tables only for a source that can't publish.
- **"Write CDC for the contract test."** *Reason:* CDC already means Change Data Capture here. *Instead:* spell out Consumer-Driven Contract.
- **"Async and consistency are the same choice."** *Reason:* an async flow can still need a coordinator or atomicity (Ford). *Instead:* record shape, consistency and coordination separately.

## References

| Question | File |
|---|---|
| Interaction shapes, the three questions, contract strictness, worked decisions | `./references/sync-vs-async-decision.md` |
| Timeouts and budgets, retry and jitter, breaker states, bulkheads, fallbacks, sizing | `./references/resilience-patterns.md` |
| Anti-corruption layer, the three data-reading options, why no shared database | `./references/integration-patterns.md` |
| The artifact skeleton | `./templates/integration-design.md` |
| Checking before hand-off | `./resources/checklist.md` |
