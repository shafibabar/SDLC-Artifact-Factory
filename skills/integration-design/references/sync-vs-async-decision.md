# Synchronous vs Asynchronous — The Full Decision Framework

Reference for `integration-design`. Self-contained: choose the communication
style for any service-to-service or service-to-external interaction, understand
the failure semantics of each, and separate the three coupling axes that a naive
"sync vs. async" toggle conflates.

---

## The three interaction shapes

Every integration is one of three shapes. They are not the same as "sync vs.
async" — request/acknowledge is technically synchronous on the wire but
semantically fire-and-forget.

| Shape | Wire | Caller waits for | Failure meaning | Use for |
|---|---|---|---|---|
| **Request / Response** | HTTP, gRPC | the *result* of the work | caller cannot proceed; failure propagates up | queries feeding the current request; a Command whose outcome the user must see now |
| **Request / Acknowledge** | HTTP 202, enqueue | only *acceptance* of the work | work accepted but not yet done; caller polls or is notified | long-running work triggered in-request (an estate scan); the initial leg of an async flow |
| **Event-Driven** | Redpanda topic | nothing — publishes a fact | producer is unaffected; each consumer's failure is its own | Domain Events, cross-context state propagation, one-to-many fan-out |

Request/Acknowledge is the bridge: a `POST /v1/estate-scans` returns `202` with a
scan ID immediately (Geewax's long-running `Operation` shape — `id`, `done`,
later `response`/`error`, polled via `GET`), while the actual scan proceeds
asynchronously behind the acknowledgement. It gives the caller an immediate,
bounded interaction *and* decouples the slow work.

---

## The four selection criteria, expanded

### 1. Need for immediate response
Ask: *can the caller complete its current unit of work without this result?* The
API Gateway serving a user's "show me this data asset's classification" request
genuinely needs the Classification Service's answer before it can respond — that
is request/response. But "the Compliance context should re-evaluate gaps when a
data asset is reclassified" needs no answer to the reclassifying caller — that is
an event. If you find yourself publishing an event and then *waiting for a
response event*, you have chosen the wrong shape: use request/response instead
(see the "Request/reply over the broker" anti-pattern).

### 2. Temporal coupling tolerance
Synchronous request/response requires both services be up *at the same instant*.
Availability composes multiplicatively down a call chain: a flow through three
independent 99.9%-available services is `0.999³ ≈ 99.7%` — roughly tripling the
expected downtime. Every synchronous hop lowers the ceiling on the whole flow's
availability. Asynchronous messaging removes temporal coupling entirely: the
producer writes to its outbox and moves on; the consumer processes whenever it is
healthy, and a consumer outage becomes broker lag (a queue that drains later),
not an upstream failure.

### 3. Failure blast radius
Trace what happens when the *callee* fails. Under request/response, the caller's
goroutine blocks until timeout, then fails its own caller — the failure walks *up*
the chain. A high-fan-in synchronous dependency (many services call it) is a
single point of failure for all of them. Under event-driven, a consumer failure
is contained: the event sits on the topic (or moves to the DLQ), the producer and
every other consumer are unaffected. **The larger the blast radius of the
downstream's failure, the stronger the case for async.**

### 4. Data volume and fan-out
One caller needing one answer from one callee is a clean request/response. One
fact that N independent contexts each react to differently (a `DataAsset
Classified` event that Compliance, Reporting, and the Graph projection all
consume) is event-driven — publishing once and letting each consumer subscribe is
far cheaper than the producer making N synchronous calls and coupling to all N.

---

## Separate the three coupling axes (Ford, *Hard Parts*)

"Sync vs. async" is only one of **three orthogonal dynamic-coupling axes**. A
robust integration design decides each independently:

1. **Communication** — synchronous or asynchronous (this document's main axis).
2. **Consistency** — does the interaction need *atomic* (all-or-nothing across
   services) or *eventual* consistency? This is a **separate question** from
   communication style and is easy to conflate. Most cross-BC flows on this
   platform are deliberately eventual.
3. **Coordination** — is the multi-step flow *orchestrated* (a central
   coordinator directs each step) or *choreographed* (each service reacts to the
   previous one's event with no central brain)? See `event-driven-patterns`.

Crossing the three axes yields Ford's eight named Saga archetypes. Two matter as
targets and one as a trap:

- **Parallel Saga** (async + eventual + orchestrated) — the recommended shape for
  a complex multi-step business process that still needs central visibility: a
  persistent orchestrator directs asynchronous, eventually-consistent steps.
- **Anthology Saga** (async + eventual + choreographed) — the most decoupled and
  scalable shape, correct when steps are genuinely independent reactions needing
  no central coordinator.
- **Horror Story** (async + *atomic* + choreographed) — the trap: attempting
  all-or-nothing atomicity across asynchronous, uncoordinated steps. Ford
  explicitly says avoid it. If a choreographed flow silently assumes every step
  completes together, either accept eventual consistency openly or move to a
  Parallel Saga.

The whimsical names are a cross-reference, not artifact vocabulary — in a
PM-reviewable artifact classify a flow by its three axes (communication /
consistency / coordination), and cite the archetype name only parenthetically.

---

## Static coupling: contract strictness (a second axis)

Beyond runtime (dynamic) coupling, classify each integration's **static
coupling** — how strict its contract is at rest:

| Contract | Coupling | Trade-off |
|---|---|---|
| Strict (gRPC/Protobuf, typed) | High | Compile-time safety; producer/consumer must evolve together |
| Loose (JSON + tolerant-reader) | Low | Independent evolution; runtime risk if a field vanishes |

Two integrations can be the same Context-Map pattern (e.g. Customer/Supplier) yet
carry very different risk depending on contract strictness. On this platform the
default is loose JSON over HTTP with tolerant-reader parsing (consumers ignore
unknown fields), which maximizes independent deployability — paired with
Consumer-Driven Contract tests to catch the removal of a field a consumer
actually reads.

---

## Worked decision: this repo's cross-BC calls

**DataAsset Management → Source Catalog (external).** The context needs the
catalog's metadata *before* it can register a data asset — immediate response
required, so **request/response (synchronous)**, wrapped in an ACL and the full
resilience stack with a cached fallback. Consistency is eventual (a slightly
stale catalog entry is acceptable); no multi-step coordination.

**DataAsset Management → Compliance.** When a data asset is classified,
Compliance must re-evaluate gaps. The classifying caller needs no answer, many
contexts react to the same fact, and a Compliance outage must not fail
classification — **event-driven (asynchronous)**, choreographed, eventual
consistency. `dataasset.classified` is published via the Transactional Outbox;
Compliance consumes idempotently with a DLQ. This is an Anthology Saga step.

**Estate scan trigger (user-facing).** A scan takes minutes. The user's request
cannot block that long — **request/acknowledge**: `202` + a scan `Operation` the
UI polls, with the scan itself proceeding asynchronously and emitting progress
events.

---

## Decision checklist

For each integration, record:

1. Which shape — request/response, request/acknowledge, or event-driven — and why
   (cite the criterion that decided it).
2. Consistency need: atomic or eventual (separate line from the shape).
3. If multi-step: orchestrated or choreographed, and the Saga archetype.
4. Static coupling: strict or loose contract, and the contract-test mechanism.
5. For synchronous shapes: the resilience stack (see `resilience-patterns.md`).
6. For external/foreign models: the ACL (see `integration-patterns.md`).
