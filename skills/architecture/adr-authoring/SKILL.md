---
name: adr-authoring
description: >
  Teaches how to write Architecture Decision Records (ADRs) — the authoritative
  log of every significant architectural choice, the context that prompted it,
  the options considered, and the rationale for the decision made. ADRs are
  mandatory for every non-obvious architecture decision in this plugin. They
  prevent re-litigating settled decisions and give future engineers (and future
  Claude sessions) the context needed to understand why the system is built the
  way it is. Used by the enterprise-architect agent throughout the Design phase.
version: 1.1.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, adr, decision-records, governance]
---

# ADR Authoring

## Purpose

An Architecture Decision Record (ADR, Michael Nygard) is a short document that captures one significant architectural decision. It records the context that made the decision necessary, the options that were considered, the decision that was made, and the consequences — both positive and negative.

ADRs serve two purposes:
1. **Prevent re-litigation.** Once a decision is recorded as `Accepted`, it is settled. Teams stop re-arguing settled decisions and spend that energy building.
2. **Enable informed change.** When circumstances change and a decision needs to be revisited, the ADR gives the context needed to understand what was originally intended and why. Changing the decision means superseding the ADR, not deleting it.

---

## When to Write an ADR

Write an ADR for every decision that is:
- **Non-obvious** — a reasonable engineer could have made a different choice
- **Consequential** — changing the decision later would require significant rework
- **Contested** — there was disagreement about the right approach
- **Cross-cutting** — the decision affects multiple services or teams

Do NOT write an ADR for:
- Implementation details that follow obviously from the architecture (e.g., "we will use pgx for PostgreSQL" — this follows from the tech stack decision)
- Decisions that can be trivially reversed with no architectural impact
- Code style or formatting choices

**In this plugin:** Every major architecture decision captured during the Design phase is an ADR. The enterprise-architect writes ADRs for: service decomposition decisions, context map pattern selections, event schema design choices, API versioning strategy, data residency enforcement mechanisms, and technology choices that deviate from the defaults in `sdlc-context.json`.

---

## ADR Format

```markdown
---
adr-id: ADR-[NNN]
title: [Short imperative title — "Use Transactional Outbox for Event Publication"]
status: [Proposed | Accepted | Deprecated | Superseded by ADR-NNN]
date: [YYYY-MM-DD]
deciders: [Who made this decision]
---

# ADR-[NNN]: [Title]

## Status
[Proposed | Accepted | Deprecated | Superseded by ADR-NNN]

## Context
[The situation that made this decision necessary. What forces are at play?
What problem are we solving? What constraints exist? What would happen
if we did nothing?]

## Decision
[The decision that was made, stated as a clear, active declarative sentence.
"We will..." or "We have decided to..."]

## Options Considered

### Option A: [Name]
**Description:** [What this option entails]
**Pros:** [Benefits]
**Cons:** [Drawbacks]

### Option B: [Name]
[Repeat]

### Option C: [Name] (if applicable)
[Repeat]

## Rationale
[Why was this option chosen over the others? Which criteria were most important?
What trade-offs were deliberately accepted?]

## Consequences

### Positive
- [Benefit that results from this decision]

### Negative / Trade-offs
- [Cost or constraint this decision introduces]

### Risks
- [What could go wrong; how it is mitigated]

## Related ADRs
- [ADR-NNN — related or dependent decision]
```

---

## ADR Status Lifecycle

| Status | Meaning |
|---|---|
| **Proposed** | Under consideration — not yet accepted. May be discussed and revised. |
| **Accepted** | The decision is settled. Implement accordingly. Do not re-argue without new information. |
| **Deprecated** | The decision is no longer relevant — the context has changed. Not superseded; just no longer active. |
| **Superseded by ADR-NNN** | A newer ADR has replaced this one. This ADR is kept for historical context — never deleted. |

ADRs are never deleted. Even superseded ADRs remain in the record because they show what was decided before and why the team changed course.

### Superseding Chains

Superseding has mechanics that keep the record navigable years later:

- **Links are bidirectional.** The new ADR carries `Supersedes: ADR-NNN` in its Related ADRs; the old ADR's status becomes `Superseded by ADR-MMM`. Updating the old ADR's status line is part of accepting the new one — an unlinked supersession is a defect.
- **Supersede whole decisions, never fractions.** If only part of a decision changes, the new ADR restates the parts being kept alongside the parts being changed, and supersedes the old ADR entirely. An ADR that is "half active" cannot be trusted by a reader who finds it first.
- **Supersede the head of the chain.** A new decision replaces the *current* ADR, not one already superseded. Chains read `ADR-003 → superseded by ADR-017 → superseded by ADR-041`; a reader landing anywhere in the chain can walk forward to the live decision in one direction.
- **A superseding ADR must say what changed.** Its Context section names the original decision, what shifted since (new constraint, new information, changed scale), and why the original rationale no longer holds. "We changed our minds" without new information is re-litigation, not evolution.
- **Deprecated ≠ Superseded.** Use `Deprecated` when the decision's subject no longer exists (the feature was removed); use `Superseded` when a replacement decision exists. A Deprecated ADR has no forward link.

---

## ADR Numbering

ADRs are numbered sequentially: `ADR-001`, `ADR-002`, ...

Within a product, ADR numbering is product-scoped. The SDLC Artifact Factory plugin itself also has ADRs for its own design decisions (already captured in `sdlc-context.json → decisions` — those will be formalised as ADRs when the remaining governance skills are built).

---

## Example ADR

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
Option A (Transactional Outbox) provides the guaranteed delivery semantics required
for the compliance use case (a missed event could mean a compliance gap is never
detected) while remaining within the operational complexity constraints. The
at-least-once delivery trade-off is acceptable because all consumers are designed
to be idempotent using the `eventId` field.

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

## ADR Storage

ADRs are stored at: `artifacts/[product]/design/decisions/ADR-[NNN]-[slug].md`

The enterprise-architect maintains an ADR index at: `artifacts/[product]/design/decisions/README.md`

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Context is neutral | Context states facts and forces — does not argue for a conclusion | Context written to justify the chosen option |
| Multiple options | At least two options considered with honest pros/cons | Single-option "decision" with no alternatives |
| Honest consequences | Negative consequences and trade-offs explicitly listed | Only positive consequences listed |
| Active decision statement | "We will..." or "We have decided to..." | Passive or hedged decision statements |
| Status current | Status field reflects actual state | ADR still marked Proposed after it was implemented |
| Never deleted | Superseded ADRs link to the superseding ADR; both exist | ADRs deleted when decisions change |
| Chain integrity | Supersession links are bidirectional and always point to the chain head | One-way links, or an ADR superseding an already-superseded ADR |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **The retrofitted ADR** — writing the ADR after implementation to bless what was built | Options were never really considered; the "rationale" is reverse-engineered justification | Write the ADR at `Proposed` before implementation; acceptance is the gate to building |
| **Advocacy context** — a Context section that argues for the chosen option | Readers cannot evaluate whether the forces still hold; the ADR loses its power to enable informed change | Context states facts, forces, and constraints neutrally; the argument belongs in Rationale |
| **Straw-man options** — alternatives listed only to be knocked down | The decision looks considered but is not; when circumstances change, no genuine fallback exists in the record | Each option gets its honest best case; the chosen option must win against real competition |
| **The consequences-free decision** — only positive consequences listed | Every architectural decision buys something by giving something up; hiding the cost guarantees surprise later | Negative consequences and accepted trade-offs are mandatory; an ADR with no downsides is incomplete |
| **ADR as documentation dump** — recording tutorials, diagrams, and how-to content in an ADR | The decision drowns; nobody can find what was actually decided | One decision per ADR; reference designs and diagrams live in their own artifacts, linked |
| **Editing an Accepted ADR in place** — updating the decision text as things change | The historical record is destroyed; "why did we believe X in June?" becomes unanswerable | Accepted ADRs are immutable except for status-line updates; changes require a superseding ADR |
| **The mega-ADR** — one record covering event publication, API versioning, and tenancy | The parts have different lifecycles; superseding one aspect falsely invalidates the rest | Split into one ADR per independently reversible decision, cross-linked in Related ADRs |

---

## Output Format

See ADR format above. Each ADR is a standalone Markdown file:
`artifacts/[product]/design/decisions/ADR-[NNN]-[kebab-case-title].md`
