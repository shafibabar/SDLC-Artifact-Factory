# Example 1 — Two options, a prose trade-off (simplest real case)

Self-contained — loadable without reading `SKILL.md` first. The standard format: neutral Context, two or three honest options, and the required Rationale `**Trade-off:**` line. It passes every check `../scripts/validate-adr.sh` runs.

## Example 1: Two Options, Prose Trade-offs

```markdown
---
name: adr-001-use-transactional-outbox
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
summary: Publish Domain Events via a Transactional Outbox so an event is never lost or emitted for a rolled-back write; trades latency for durability.
adr-id: ADR-001
title: Use Transactional Outbox Pattern for Domain Event Publication
status: Accepted
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
