---
name: integration-design
description: >
  Teaches the enterprise-architect to design the integration contract between
  services — the synchronous-vs-asynchronous decision, the resilience patterns
  that make a synchronous dependency safe (Circuit Breaker, Timeout, Retry with
  Backoff, Bulkhead, Fallback), the Anti-Corruption Layer for model translation
  across a boundary, and Change Data Capture as a non-invasive integration
  mechanism — with explicit selection criteria, failure-mode analysis, and the
  Go implementation on this platform. Used during Design when two Bounded
  Contexts or an external system must communicate.
version: 2.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, integration, synchronous, asynchronous, circuit-breaker, resilience, anti-corruption-layer, bulkhead, timeout]
produces: integration-design
domain: architecture
status: stable
related: [context-map-patterns, event-driven-patterns, event-schema-design, api-contract-design, go-contract-test, data-model-design]
---

# Integration Design

## Purpose

Every integration is a dependency, and every undesigned dependency becomes
implicit coupling that surfaces as a production incident. This skill makes each
service-to-service and service-to-external-system interaction an explicit,
deliberate, resilient design decision — with a declared communication style, a
resilience stack sized to its failure blast radius, and a translation boundary
that keeps a foreign model out of the domain.

Integration design runs during Design, **after the Context Map is complete**
(`context-map-patterns`): the Context Map decides *which* Bounded Contexts talk
and in what relationship; this skill decides *how* each of those relationships is
wired, made safe, and translated.

---

## The First Decision: Synchronous vs Asynchronous

For every interaction, choose the communication style before anything else. Four
criteria drive the choice:

| Criterion | Points to **synchronous** | Points to **asynchronous** |
|---|---|---|
| **Need for immediate response** | Caller cannot proceed without the result (a query feeding the current request) | Caller only needs the work to *eventually* happen |
| **Temporal coupling tolerance** | Both services acceptably co-available; short call chain | Producer must not depend on consumer being up right now |
| **Failure blast radius** | A single downstream, low fan-out, failure is containable | Downstream failure must not cascade upstream |
| **Data volume / fan-out** | One caller, one callee, small payload | One event, many independent consumers |

**Default rule:** asynchronous Domain Events are the default *across* Bounded
Contexts; synchronous is the justified exception, used only when a response is
required inside the current request's flow. Availability multiplies down a
synchronous call chain — three 99.9% dependencies in series is 99.7% — so every
added synchronous hop lowers the ceiling on the whole flow's availability.

Communication style is one axis, not the whole decision. **Consistency (atomic
vs. eventual) is a separate question** from sync-vs-async, and **coordination
(orchestrated vs. choreographed)** is a third. A flow can be async *and* need a
coordinator. The full three-axis framing, the request/response vs.
request/acknowledge vs. event-driven interaction shapes, their failure
semantics, and the worked decision for this repo's cross-BC calls are in
**`references/sync-vs-async-decision.md`**.

---

## Making a Synchronous Dependency Safe: Resilience Patterns

A synchronous call to another service is a shared-fate link unless every one of
these is in place. Each is required, not optional, for every remote sync call:

- **Timeout** — every remote call has an explicit deadline; none blocks
  indefinitely. Timeouts nest: a caller's budget must exceed its downstream's
  full retry envelope, propagated through `context.Context`.
- **Retry with Backoff and jitter** — transient failures (503/504, connection
  reset) retried with exponential backoff *and jitter* (to avoid a thundering
  herd), capped attempts. Only idempotent calls, or calls carrying an
  `Idempotency-Key`, may be retried — a timeout is an *unknown* outcome, and
  retrying a non-idempotent write duplicates the side effect.
- **Circuit Breaker** — after a failure threshold the circuit *opens* and calls
  fail fast instead of piling up on timeouts; it later *half-opens* to probe
  recovery. One breaker **per downstream**, never one global breaker.
- **Bulkhead** — each downstream gets its own connection pool / concurrency
  limit, so one slow dependency cannot exhaust the resources every other call
  needs.
- **Fallback / graceful degradation** — when the breaker is open or the call
  fails, a defined degraded response (cached value, empty default, queued-for-
  later) rather than propagating the failure upward.

These **compose in a fixed order**: timeout *inside* retry *inside* circuit
breaker *inside* bulkhead, with fallback outermost. The circuit-breaker state
machine (closed/open/half-open) with concrete thresholds and reset timeouts, the
timeout-budget calculation, the idempotency requirement, and the Go
implementation (hand-rolled and via `sony/gobreaker`) are all in
**`references/resilience-patterns.md`**.

---

## Anti-Corruption Layer: Never Let a Foreign Model Leak In

Every integration with an external system (Google Drive, AWS S3, a third-party
Source Catalog) — and any cross-BC call whose model differs from ours — goes
through an **Anti-Corruption Layer (ACL)**. The ACL is a translation adapter: a
`client.go` that speaks the foreign API's types and a `translator.go` that
converts foreign types to domain types and back. The domain depends only on a
port interface the ACL implements; it never imports the client.

The principle is absolute: **another Bounded Context's model, or a vendor's
model, must never appear in our domain layer.** The ACL is the single, named
place that boundary is enforced — this is `context-map-patterns`' ACL
relationship made concrete in Go. Boundary DTO vs. domain model separation, the
translation-adapter structure, and how to test the ACL in isolation are in
**`references/integration-patterns.md`**.

---

## Change Data Capture: Non-Invasive Read Integration

When a consuming context needs another context's data and the owning service
cannot (or should not) be modified to publish events, **Change Data Capture
(CDC)** reads the owner's PostgreSQL write-ahead log (via Debezium) and emits row
changes as events — integration without touching the source service's code. CDC
is the non-invasive alternative to two other cross-service data patterns: **API
composition** (call the owner live per read) and **data replication** (the owner
publishes events you project locally). The tradeoff between the three, the CDC-
via-Debezium mechanics on this stack, and why the **shared-database anti-pattern
is forbidden here** are in **`references/integration-patterns.md`**.

---

## Contracts Gate Every Integration

Sync or async, every integration has a **Consumer-Driven Contract**: the consumer
declares the request/response or event fields it depends on, and the provider's
CI fails if it stops honoring them (`go-contract-test`, `event-schema-design`).
"Smart endpoints, dumb pipes" — no routing or business logic leaks into the
broker, gateway, or a topic; all logic lives in the owning service's handlers.

---

## The Integration Inventory

The enterprise-architect maintains an Integration Inventory per product — every
service-to-service and external dependency, each row declaring style, protocol,
contract mechanism, and resilience stack:

| From | To | Style | Protocol | Contract | Resilience |
|---|---|---|---|---|---|
| API Gateway | Classification Service | Sync | HTTP/JSON | Consumer-Driven Contract | Timeout + Retry + Breaker + Bulkhead |
| DataAsset Mgmt | Source Catalog (external) | Sync | HTTP/JSON | ACL | Timeout + Retry + Breaker + Fallback |
| DataAsset Mgmt | Redpanda | Async | Kafka protocol | Event schema | Transactional Outbox + DLQ |
| Compliance | `dataasset.classified` topic | Async | Kafka protocol | Event schema | Idempotent consumer + DLQ |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Style declared | Every integration states sync/async **and** its consistency need, with justification | Style undocumented or conflated with consistency |
| Resilience complete | Every sync call has timeout + retry + breaker + bulkhead + fallback | Any sync call missing a layer |
| Per-downstream isolation | One breaker and one pool per downstream | A global breaker or shared pool |
| ACL for foreign models | Every external / cross-model integration uses an ACL | Foreign types in the domain layer |
| CDC vs. composition chosen | Cross-context read path names its pattern and why | Implicit "just call the API" |
| Contract defined | Every integration has a CDC/schema test plan gating CI | Verbal-only integration agreement |
| Idempotent consumers + DLQ | Every async consumer is idempotent with a DLQ | Duplicate-unsafe consumer or silent drop |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Sync by default across contexts** | Availability multiplies down the chain; every downstream incident becomes a platform incident | Async Domain Events default; sync is the justified exception |
| **Retry without jitter or budget** | Synchronized retries finish off the recovering downstream (thundering herd) | Exponential backoff + jitter, capped attempts, breaker in front |
| **Retrying non-idempotent calls** | A timeout is unknown; the retry duplicates the write | `Idempotency-Key`, or do not auto-retry |
| **One global Circuit Breaker (or none)** | One failing dependency opens the circuit for healthy ones; or threads pile on timeouts | One breaker + one pool (Bulkhead) per downstream |
| **Sync external call in an event consumer's critical path** | Broker lag balloons behind the slowest third party; redeliveries amplify load | External calls behind their own resilience stack; split into a separate step/topic |
| **Request/reply over the broker** | Recreates temporal coupling with worse latency and no backpressure | Use HTTP/gRPC + resilience for in-flow responses; events are fire-and-forget facts |
| **ACL bypass "just this once"** | The vendor model leaks in; the exception becomes the norm | All foreign calls go through `client.go`/`translator.go`; the domain sees only ports |
| **Shared database across services** | Both services couple to a schema neither owns; no independent deploy | CDC, API composition, or event replication — never a shared table |

---

## References

- **`references/sync-vs-async-decision.md`** — the full decision framework: interaction shapes, the three coupling axes, failure semantics, worked cross-BC decision.
- **`references/resilience-patterns.md`** — Circuit Breaker state machine with concrete thresholds, timeout budgeting, retry/backoff/jitter, Bulkhead, Fallback, Go implementation, pattern composition order.
- **`references/integration-patterns.md`** — ACL implementation in Go, CDC via Debezium, API composition vs. replication tradeoff, the forbidden shared-database anti-pattern.
- **`references/worked-example.md`** — a complete integration design for this repo (DataAsset Management → external Source Catalog via ACL + resilience; Compliance consuming DataAsset events async) with the full decision trail.

## Output Format

```markdown
---
name: integration-design
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: enterprise-architect
---

# Integration Design

## Integration Inventory
| From | To | Style | Consistency | Protocol | Contract | Resilience |

## Synchronous Integration Details
[Per-integration: timeout budget, retry config, Circuit Breaker config, fallback]

## Asynchronous Integration Details
[Per-topic: producer/outbox, consumer groups, retry policy, DLQ, idempotency key]

## Anti-Corruption Layers
| External System | ACL location | Domain port | Translation notes |

## Consumer-Driven Contract Plan
| Consumer | Provider | Contract type | Test location | CI gate |

## Related ADRs
[ADR IDs for integration decisions]
```
