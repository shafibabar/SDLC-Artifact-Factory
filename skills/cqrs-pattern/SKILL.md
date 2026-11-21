---
name: cqrs-pattern
description: >
  Decide the read side of each Bounded Context and of every query that spans
  services, on one escalation ladder: a Simple Read Model inside the service
  (separate query types over the write tables, joins allowed, immediately
  consistent) by default; Read Models projected from Domain Events only on a
  named, evidenced trigger; API Composition first for queries across
  services, a CQRS view fed by events only on a named trigger. Covers CQRS
  as independent of event sourcing, the staleness each view accepts,
  read-your-writes and monotonic reads, why rules never check a Read Model,
  and the CQRS decisions record, made before Read Models are designed. Use
  when deciding whether to build projections, separate read stores or
  event sourcing for reads, answering a cross-service query, or reviewing a
  read-side choice. Read Model shapes and projectors are read-model-design;
  handler code is go-service-layer. Used by enterprise-architect.
version: 3.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, cqrs, read-side, read-model, write-model, projections, api-composition, eventual-consistency]
produces: cqrs-design
domain: domain-modeling
status: stable
related: [read-model-design, aggregate-design, domain-event-catalog, command-catalog, container-diagram, workflow-orchestration, api-contract-design, event-driven-patterns, go-service-layer, go-event-consumer]
sources:
  - research/domain-driven-design/learning-ddd-khononov.md
  - research/software-architecture/microservices-patterns-richardson.md
  - research/software-architecture/designing-data-intensive-applications-kleppmann.md
  - research/software-architecture/designing-data-intensive-applications-kleppmann-part2-consistency-consensus.md
  - research/domain-driven-design/domain-driven-design-evans.md
---

# CQRS Pattern

## Purpose

Command Query Responsibility Segregation (the term is Greg Young's) gives writes and reads separate models. Commands change state through Aggregates and return only an acknowledgement (`command-catalog`). Queries read through their own types and change nothing (Evans: side-effect-free queries). The question this skill answers is **how far apart the read side sits**, per Bounded Context and per query that spans services. The answer goes in one record, decided by enterprise-architect **before** `read-model-design` runs (D047-4).

What this skill does **not** hold:
- the shapes of Read Models, projector mechanics and rebuilds, which are `read-model-design`'s;
- the business-logic pattern per use case and event sourcing, decided in `aggregate-design` (§ 1 and § 6);
- code, which is `go-service-layer` (handlers) and `go-event-consumer` (projectors) (D047-10).

At **lean** the record is skipped: every context uses a Simple Read Model, listed in the Read Models table of `domain-model.md`. A lean product that names a trigger moves to standard for that context.

## 1. The Ladder

One ladder for every product (D047-4). Start at the bottom; go up a rung only on a **named trigger with evidence** from the NFRs, the screens or measurements.

| Rung | Within one service | Consistency | Go up when |
|---|---|---|---|
| 1 (default) | **Simple Read Model:** query types separate from the Aggregate, reading the write tables; joins allowed | immediate | a trigger in § 2 is named |
| 2 | **Projections:** Read Models built from Domain Events into their own tables or store | eventual: staleness stated per view | — |

| Rung | Across services | Consistency | Go up when |
|---|---|---|---|
| 1 (default) | **API Composition:** a composer calls each owning service and joins in memory (Richardson) | each source's own | a trigger in § 2 is named |
| 2 | **CQRS view:** one service keeps a Read Model fed by the other services' events | eventual | — |

A Simple Read Model is real CQRS, not a stopgap (Khononov): the write and read sides already have separate types and responsibilities. "Never read the write tables" is wrong as a rule. Exposing the **Aggregate** to queries is what is wrong.

## 2. Named Triggers

A trigger names the query, the evidence and why rung 1 fails it:
- **Shapes diverge:** several screens need structurally different shapes of the same data (a list, a search index, a dashboard) and query-time joins over write tables are slow or complex. Evidence: the screens, and a measured or estimated query cost.
- **Load differs:** reads outnumber writes by an order of magnitude, or need a different store (full-text search, a graph), and would slow the write path.
- **Combines many Aggregates or contexts:** the view folds events from several Aggregates (or services) where a join or composition is too costly or too wide.
- **History:** new views must be built from what already happened, or the write side is event-sourced, so no current-state table exists to query (projections are then required, not chosen).
- **Across services:** the composed result is large, the fan-out is wide, or the query must still answer when a source service is down (Richardson).

"It might need to scale", "best practice", "Core subdomain" and "we already have a broker" are not triggers. Write down what would move each context up a rung (*revisit when*), so the decision is reopened on evidence, not taste.

## 3. CQRS Is Not Event Sourcing

Projections can be fed by Domain Events from current-state Aggregates through the Transactional Outbox (`event-driven-patterns`). Event sourcing is a write-side persistence choice made in `aggregate-design` § 6 for its own reasons (temporal queries, history as the record); it forces projections, never the reverse. Adopting projections never means dropping the state table.

## 4. Consistency Each View Accepts

- **Eventual consistency alone promises nothing a person can rely on:** neither how soon a change appears nor that the person who made it sees it (Kleppmann). So for each projected view state **how stale it may be**, and **which guarantees it gives**: read-your-writes, monotonic reads, consistent prefix (each below).
- **What decides the lag a view may have is whether anyone acts on it unprotected.** A displayed account balance can lag when every charge against it is checked by the Aggregate's rule: the customer may see an older figure, but is never charged wrongly, and sees their own change through read-your-writes. A view stays on rung 1 only when a person acts on it and no rule in the Aggregate protects that action. Heavy load on such a view is a trigger like any other.
- **Read-your-writes** (Kleppmann): the person who just wrote must see their own change. The Command returns the new version; the writer's view shows the change as pending, or waits until the view has applied that version. Other readers may lag.
- **Monotonic reads:** where a view is served from replicas or regions, one reader must not see a newer state and then an older one; pin a reader to one copy or compare versions.
- **Rules never check a Read Model.** A projection lags the write side, so a guard checked against it races reality. Rules are checked in the Aggregate, against the state it loaded (`aggregate-design`).
- **Queries change nothing:** if the business cares that something was viewed, that is a Command recording an event.

Detail, anomalies and the writer's view: `./references/consistency-and-read-your-writes.md`.

## Producing the Decisions

One `design/architecture/cqrs-decisions.md` for the product (`./templates/cqrs-decisions.md`). No code.

1. **Read** each context's `aggregates.md` (business-logic pattern per use case, event sourcing), `domain-event-catalog.md`, the screens and user stories (which queries exist), the NFR specification (load, latency, staleness, availability) and the context map. This runs before the container diagram: list queries that cross Bounded Contexts now, and settle them as cross-service queries once the container diagram has placed contexts in services (contexts in one service query each other in-process).
2. **List the queries** per context, and every query that needs data from more than one service.
3. **Place each context on the ladder** (§ 1): rung 1 unless a § 2 trigger is named with evidence. Event-sourced Aggregates force projections for their context.
4. **For each projected view:** its staleness and why; how the writer sees their own write; replicas or regions (monotonic reads).
5. **For each cross-service query:** API Composition unless a trigger is named; for a CQRS view, which service owns it and which events feed it.
6. **Record *revisit when*** for each context: the signal that would move it up.
7. **Validate, then loop.** Run `./scripts/validate-cqrs-decisions.sh design/architecture/cqrs-decisions.md`. Fix every FAIL and re-run until it exits clean, then go through `./resources/decision-checklist.md`.
8. **Present** the decisions, and for every request you declined, its reason in full (§ Gotchas). Then hand the record to the domain-modeler for `read-model-design`.

Ladder reasoning, the business-logic patterns and cross-service detail: `./references/ladder-and-triggers.md`. Examples: `./examples/01-lean-no-projections.md` (lean: no record), `./examples/02-standard-league-table.md` (one projected view on a named trigger; composition across services), `./examples/03-enterprise-event-sourced-marking.md` (event-sourced context, regional views, read-your-writes).

## Gotchas

Each trap comes with the reason to give in full.

- **"Build projections for every context from day one; it's best practice."** *Reason:* projectors, a broker path and eventual consistency are cost and failure modes that buy nothing until a query needs them (Khononov). *Instead:* a Simple Read Model, with the trigger that would move each context up written down.
- **"CQRS means we drop the state table and event-source."** *Reason:* the two are independent; event sourcing brings replay, snapshots and upcasting for its own reasons. *Instead:* current-state Aggregates feed projections through the outbox; event sourcing only where `aggregate-design` § 6 justifies it.
- **"Check the balance against the Read Model before accepting the Command."** *Reason:* the view lags the write side, so the check passes on stale data. *Instead:* the rule is checked in the Aggregate against the state it loaded.
- **"Never join the write tables for a read."** *Reason:* a query type over the write tables is legitimate CQRS; what breaks the split is loading the Aggregate for a query. *Instead:* rung 1 until a trigger is named.
- **"Read the other service's tables directly for the report."** *Reason:* each service owns its data; a shared-table read couples their schemas and deployments. *Instead:* API Composition, or a CQRS view fed by that service's events on a named trigger.
- **"Return the updated state from the Command so the screen isn't stale."** *Reason:* the write path takes on read concerns. *Instead:* return the new version; the writer's view waits for it or shows the change as pending (read-your-writes).
- **"It's eventually consistent; that's fine everywhere, they can pull to refresh."** *Reason:* eventual consistency promises neither how soon nor that the writer sees their own change; a customer who adds funds and still sees the old figure adds them again. *Instead:* per view, the staleness it may have and the guarantees it gives: read-your-writes for the writer, monotonic reads across replicas or regions, consistent prefix where causes and effects both show.
- **"The balance must never lag, so it can't be a projection."** *Reason:* if the charge is checked by the Aggregate, the displayed balance is information, not the guard; keeping a heavily read view on the write tables puts that load on the write path. *Instead:* project it, with read-your-writes for the person who changed it; keep on rung 1 only views someone acts on with no rule behind them.
- **"Design the Read Models first; we'll pick CQRS later."** *Reason:* the rung decides whether a Read Model is a query over the write tables or a projection with lag and rebuilds, so designing it first means redesigning it. *Instead:* decide the read side first (D047-4), then `read-model-design`.

## References

| Question | File |
|---|---|
| Which rung? Is this a real trigger? Business-logic pattern? Cross-service queries? | `./references/ladder-and-triggers.md` |
| Staleness, read-your-writes, monotonic reads, why rules don't read views | `./references/consistency-and-read-your-writes.md` |
| Checking before hand-off | `./resources/decision-checklist.md` |
