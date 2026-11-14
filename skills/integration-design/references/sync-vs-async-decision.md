# Sync vs Async: The Decision

Reference for `integration-design`. Self-contained: the interaction shapes, the four criteria for choosing, the three separate questions a "sync or async" toggle conflates, contract strictness, and worked decisions.

## 1. Three Interaction Shapes

| Shape | On the wire | Caller waits for | When it fails | Use for |
|---|---|---|---|---|
| **Request / response** | HTTP, gRPC | The result | The caller can't proceed; the failure travels up | A query feeding the current request; a command whose outcome the user must see now |
| **Request / acknowledge** | HTTP `202` plus a status resource | Only acceptance | Accepted, not done; the caller polls or is notified | Long work started in a request (an import, a report); the first leg of an async flow |
| **Event** | A topic | Nothing: it publishes a fact | Each consumer's failure is its own | Domain Events, state propagation across contexts, one-to-many fan-out |

Request/acknowledge is the bridge: the caller gets a bounded, immediate answer (an operation id), and the slow work runs behind it (the long-running-operation shape in `api-contract-design`).

## 2. The Four Criteria

1. **Does the caller need the answer to finish?** Showing a quote to the user needs the pricing answer now: request/response. "Update loyalty points when an order ships" needs no answer: an event. Publishing an event and then waiting for a reply event means you chose the wrong shape.
2. **Can both sides be up at the same moment?** Request/response needs both up together. Availability multiplies down a chain: three 99.9% services in series give `0.999³ ≈ 99.7%`, about triple the downtime. With events, a consumer outage becomes lag that drains later, not a failure upstream.
3. **How far does a failure spread?** Under request/response, a callee failure walks up the chain; a dependency many services call is a single point of failure for all of them. Under events, a failed consumer leaves the event on the topic or in its Dead Letter Queue; nobody else notices. The wider the spread, the stronger the case for async.
4. **Fan-out.** One caller, one answer: request/response. One fact several contexts react to differently: publish once rather than make N calls and couple to N services.

**Default:** events across Bounded Contexts; synchronous is the justified exception, inside the current request's flow.

## 3. Three Separate Questions (Ford, *Hard Parts*)

`research/software-architecture/software-architecture-hard-parts-ford.md` separates three dynamic-coupling axes; decide each:
1. **Communication:** sync or async (§ 1, § 2).
2. **Consistency:** atomic (all or nothing across services) or eventual. A separate question from communication, and easy to conflate. Most cross-context flows are eventual.
3. **Coordination:** for a multi-step flow, orchestrated (a coordinator directs each step) or choreographed (each reacts to the last event). Richards & Ford call these the mediator and broker topologies (`fundamentals-of-software-architecture-richards-ford.md`). Choreography design: `event-driven-patterns`; orchestration and when to choose it: `workflow-orchestration` (D047-3).

Crossing the three gives Ford's saga archetypes; three are worth naming:
- **Parallel saga** (async, eventual, orchestrated): a complex flow that still needs central visibility.
- **Anthology saga** (async, eventual, choreographed): genuinely independent reactions; the most decoupled.
- **Horror story** (async, atomic, choreographed): all-or-nothing across uncoordinated async steps. Avoid it: accept eventual consistency openly, or orchestrate.

In an artifact, classify by the three axes; the archetype name is a parenthetical cross-reference.

## 4. Contract Strictness (Static Coupling)

| Contract | Coupling | Trade-off |
|---|---|---|
| **Strict** (typed: Protobuf over gRPC, a schema-registry-enforced event) | High | Compile-time safety; producer and consumer evolve together |
| **Loose** (JSON read by a tolerant reader) | Low | Independent evolution; runtime risk if a field vanishes |

The default for HTTP is loose JSON with a **tolerant reader** (consumers ignore unknown fields; Newman, `building-microservices-newman.md`), paired with a **Consumer-Driven Contract** test that catches removal of a field a consumer actually reads. Events are usually strict at the schema level (`event-schema-design`). Record strictness per integration.

## 5. Worked Decisions

**Checkout → Payment Provider (external).** The order can't be confirmed without the authorisation: **request/response**. Consistency: the order and the charge must agree, so the call carries an **idempotency key** and an unknown outcome is reconciled, not retried blind. Loose JSON, a Consumer-Driven Contract on the fields read.

**Orders → Loyalty (two contexts).** Loyalty updates points when an order ships. Orders needs no answer and must not fail when Loyalty is down; Analytics reacts to the same fact: **event**, eventual, choreographed. Published through the Transactional Outbox; Loyalty consumes idempotently with a Dead Letter Queue (`event-driven-patterns`).

**Bulk menu import (user-facing).** Takes minutes: **request/acknowledge**, `202` with an import operation the UI polls; the import runs async and emits progress events.

## 6. Decision Record per Integration

1. Shape, and the criterion that decided it.
2. Consistency: atomic or eventual.
3. Multi-step: orchestrated or choreographed (and the archetype).
4. Contract: strict or loose, and its Consumer-Driven Contract test.
5. Sync: the resilience, sized per `resilience-patterns.md`.
6. Foreign model: the anti-corruption layer (`integration-patterns.md`).
