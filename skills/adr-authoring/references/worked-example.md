# Worked ADR Examples

Self-contained — loadable without reading `SKILL.md` first. Two full
examples: the first shows the standard format including the required
Rationale trade-off line; the second adds the optional trade-off matrix
for a decision with three or more competing architecture characteristics
(per *Fundamentals of Software Architecture* Ch. 4 and Ch. 18 —
`research/software-architecture/fundamentals-of-software-architecture-richards-ford.md`).

---

## Example 1: Two Options, Prose Trade-offs

```markdown
---
adr-id: ADR-001
title: Use Transactional Outbox Pattern for Domain Event Publication
status: Accepted
date: 2026-06-25
deciders: enterprise-architect
---

# ADR-001: Use Transactional Outbox Pattern for Domain Event Publication

## Status
Accepted

## Context
Services must publish Domain Events to Redpanda when Aggregate state changes.
The naive approach — update the Aggregate table and then publish to Redpanda in
the same request handler — creates a dual-write problem: if the service crashes
between the database write and the Redpanda publish, the event is lost. The
Aggregate state is updated, but the downstream services never receive the event,
leaving the system in an inconsistent state.

A distributed transaction (two-phase commit across PostgreSQL and Redpanda) would
solve the atomicity problem but would introduce significant complexity, latency,
and a dependency on a transaction coordinator — unacceptable given our frugality
and reliability constraints.

## Decision
We will use the Transactional Outbox pattern for all Domain Event publication.
Domain Events are written to an `outbox_events` table in the same PostgreSQL
database as the Aggregate tables, within the same database transaction. A separate
Outbox Relay process reads unpublished events and publishes them to Redpanda,
then marks them published.

## Options Considered

### Option A: Transactional Outbox (chosen)
**Pros:** Guaranteed at-least-once delivery; no distributed transaction; uses
existing PostgreSQL; relay is independently restartable.
**Cons:** Adds latency (relay poll interval, default 1s); requires an outbox table
per service; consumers must be idempotent (at-least-once delivery).

### Option B: Dual-write (publish to Redpanda directly from handler)
**Pros:** Simpler code; lower latency.
**Cons:** Events lost on crash between DB write and Redpanda publish; inconsistency
cannot be detected without expensive reconciliation.

### Option C: Change Data Capture (CDC) via Debezium
**Pros:** Zero application code change; sub-second latency.
**Cons:** Adds Debezium as a dependency; requires Kafka Connect; increases
operational complexity; violates frugality constraint.

## Rationale
**Trade-off:** durability and consistency (no silently lost events) over latency
and implementation simplicity — the compliance use case makes a missed event a
potential compliance gap that is never detected, which outweighs the ~1 second
of added latency and the extra idempotency requirement on consumers.

Option A (Transactional Outbox) provides the guaranteed delivery semantics required
for the compliance use case while remaining within the operational complexity
constraints that rule out Option C. The at-least-once delivery trade-off is
acceptable because all consumers are designed to be idempotent using the
`eventId` field.

## Consequences

### Positive
- Domain Events are never silently lost
- No distributed transaction required
- Relay failure does not corrupt state — events accumulate in the outbox until the relay recovers

### Negative / Trade-offs
- ~1 second additional latency between event emission and consumer receipt (relay poll interval)
- All consumers must implement idempotency using `eventId`
- Each service requires an `outbox_events` table

### Risks
- Outbox table growth if relay is stopped for extended period — mitigated by relay monitoring and alerting on `published = false AND created_at < now() - interval '5 minutes'`

## Related ADRs
- ADR-002 — Idempotency strategy for Domain Event consumers
```

---

## Example 2: Three-Plus Characteristics, Trade-off Matrix

Per *Fundamentals of Software Architecture* Ch. 14, choreography (broker
topology — each service reacts to events and emits new ones, no central
coordinator) and orchestration (mediator topology — a central coordinator
directs an ordered, compensable multi-step process) are both legitimate
event-driven topologies. A workflow with several ordered steps and
compensating actions is a mediator-topology candidate worth an ADR either
way — including when the answer is "stay with the default." This example
has three competing characteristics, so the matrix earns its place; a
two-option, two-characteristic decision like Example 1 does not need one.

```markdown
---
adr-id: ADR-014
title: Use Mediator (Orchestration) Topology for Compliance Report Generation
status: Accepted
date: 2026-07-10
deciders: enterprise-architect
---

# ADR-014: Use Mediator (Orchestration) Topology for Compliance Report Generation

## Status
Accepted

## Context
Generating a compliance report requires five ordered steps across three
services: gather classified data assets, evaluate each against active
compliance gap rules, apply any legal holds that suppress inclusion,
render the report, and notify the requesting Compliance Officer. A
failure at step 3 (legal hold service unavailable) must not leave a
partially-rendered report reachable — the report must be entirely
generated or the whole workflow must roll back with a clear failure
reason, not silently emit an incomplete document.

The platform's default per `integration-design` is broker-topology
choreography: each service reacts to the prior step's event and emits
its own. That default works well for the platform's other flows, which
are single-step reactions. This flow is different — it has compensable,
ordered steps with a specific failure mode (partial report) that
choreography does not naturally prevent.

## Decision
We will use a Mediator (Orchestration) topology for the Compliance
Report Generation flow specifically: a `ReportGenerationOrchestrator`
directs each of the five steps in order, tracks workflow state, and
issues compensating actions (discard partial report, notify requester
of failure with a specific reason) if any step fails. This is a
deliberate, scoped exception to the platform's broker-topology default,
not a change to that default.

## Options Considered

### Option A: Mediator / Orchestration (chosen)
**Description:** A dedicated orchestrator service calls each step in
order, holds workflow state, and directs compensation on failure.
**Pros:** Centralized error handling; workflow state is visible in one
place; compensation logic is explicit and testable.
**Cons:** Sacrifices some decoupling (services know they're part of an
orchestrated flow); orchestrator is a new component with its own
availability requirement; less scalable than choreography under very
high fan-out (not a concern at this flow's actual volume).

### Option B: Broker / Choreography (platform default)
**Description:** Each service reacts to the prior step's event and
emits its own; no central coordinator.
**Pros:** Matches the platform default; maximum decoupling; scales
well under high event volume.
**Cons:** No natural place to hold cross-step workflow state or to
detect "step 3 of 5 failed, the first two must be rolled back" — each
service only knows its own step, so partial-completion detection and
compensation would need to be bolted on informally, most likely as
ad-hoc reconciliation logic that duplicates what an orchestrator does
by design.

### Option C: Saga with per-step compensating event choreography
**Description:** Choreography, but each step also emits a distinct
compensating event on failure that prior steps listen for and react to.
**Pros:** Keeps the broker topology; no new orchestrator component.
**Cons:** Compensation logic is scattered across five services instead
of centralized in one; a reader trying to understand "what happens if
step 3 fails" must trace five separate services' event handlers instead
of reading one orchestrator; workflow-progress visibility (which
Compliance Officer requests are mid-flight) has no natural home.

## Rationale
**Trade-off:** workflow visibility and centralized error handling over
decoupling and scalability — this flow's failure mode (a partially
generated compliance report reaching a Compliance Officer) is a
correctness risk this product cannot accept, and centralized
compensation logic is easier to verify correct than five services'
worth of scattered compensating-event handlers. Decoupling and raw
throughput, the characteristics choreography optimizes for, are not
scarce for this flow — report generation runs at low volume (per-request,
human-triggered), so the scalability cost of an orchestrator is
immaterial here.

| Characteristic | Option A: Mediator | Option B: Broker (default) | Option C: Saga (compensating events) |
|---|---|---|---|
| Workflow visibility | High — single orchestrator holds state | Low — no central view of in-flight workflows | Medium — state inferable from event history, not directly held |
| Error handling / compensation | Centralized, one place to verify | None built-in — would need ad-hoc reconciliation | Scattered across 5 services |
| Decoupling | Lower — services know they're orchestrated | Highest | High |
| Scalability under fan-out | Lower (not a concern at this flow's volume) | Highest | High |
| Operational complexity | New orchestrator component to run and monitor | None — reuses existing broker infra | None new, but debugging complexity shifts into event tracing |

## Consequences

### Positive
- A partially-generated compliance report can never reach a Compliance
  Officer — the orchestrator either completes all five steps or rolls
  back and reports a clear failure reason
- Workflow-in-progress state is queryable in one place, enabling a
  "report generation status" view with no additional instrumentation
- Compensation logic for this flow lives in one component, not five

### Negative / Trade-offs
- The orchestrator is a new deployable component with its own
  availability and scaling requirements
- This flow's services are coupled to the orchestrator's calling
  contract, unlike the platform's other choreographed flows
- This is a documented, scoped exception to the platform default —
  future engineers reading `integration-design` alone would not expect
  to find an orchestrator here without this ADR

### Risks
- If report-generation volume grows enough that orchestrator throughput
  becomes a real constraint (not the case today), this decision should
  be revisited — see Related ADRs for the superseding path if that
  happens

## Related ADRs
- ADR-005 — Choreography-based event flow for classification pipeline
  (the platform default this ADR deliberately deviates from, for this
  flow only)
```
