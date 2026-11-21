---
name: read-model-design
description: >
  Design the Read Models of a Bounded Context after its read side is decided
  in cqrs-design: one Read Model per query shape, shaped by what the caller
  shows and filters on, never by the Aggregate. A context on the Simple Read
  Model rung gets short entries (the query, its shape, the write tables and
  joins it reads); a projected Read Model gets the full design (the events
  that feed it and what each does, idempotent apply, position tracking,
  staleness and how freshness is shown, read-your-writes, store, rebuild
  source and a rebuild into a copy that swaps in, never rows patched by
  hand, replays that meet every historical event type). Covers copied
  display values and their change events, tenant scoping, cross-service
  CQRS views, and the read-models document. Use when designing query
  shapes, dashboards, search or list views, projectors, or fixing a
  projection that drifted or fell behind. The rung is cqrs-pattern's;
  physical schema is data-model-design; code is go-repository-pattern and
  go-event-consumer. Used by domain-modeler.
version: 3.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: [design, domain-modeling, cqrs, read-model, projections, denormalization, rebuild]
produces: read-model
domain: domain-modeling
status: stable
related: [cqrs-pattern, aggregate-design, domain-event-catalog, command-catalog, event-schema-design, data-model-design, api-contract-design, multi-tenancy-design, go-repository-pattern, go-event-consumer]
sources:
  - research/domain-driven-design/learning-ddd-khononov.md
  - research/software-architecture/designing-backend-systems-go-campbell.md
  - research/software-architecture/designing-data-intensive-applications-kleppmann.md
  - research/software-architecture/designing-data-intensive-applications-kleppmann-part2-consistency-consensus.md
  - research/software-architecture/microservices-patterns-richardson.md
  - research/domain-driven-design/versioning-event-sourced-system-young.md
  - research/domain-driven-design/introducing-eventstorming-brandolini.md
---

# Read Model Design

## Purpose

A Read Model is the information someone looks at before deciding (Brandolini's green sticky): a screen, a list, a dashboard, a search, an answer another system asks for. This skill designs each one: what it answers, what it holds, where it comes from and how it stays correct.

It runs **after** enterprise-architect's CQRS decisions (`design/architecture/cqrs-decisions.md`, `cqrs-pattern`), which put each Bounded Context on a rung and give each projected view its accepted staleness and read-your-writes method (D047-4). This skill applies that decision and never re-decides the rung. Where the record is missing, or gives no figure for a view, the design still states one: propose it, mark it as an assumption and send it to enterprise-architect to confirm.

What this skill does **not** hold:
- the rung, triggers and per-view guarantees (`cqrs-pattern`);
- tables, indexes and store choice in detail (`data-model-design`); GET endpoints (`api-contract-design`);
- code: queries in `go-repository-pattern`, projectors in `go-event-consumer` (D047-10).

At **lean** there is no document: Read Models are a table in `design/domain-model.md` (each a query over the write tables). A lean context that a named trigger puts on projections moves to standard for that context (`cqrs-pattern`) and gets its own `read-models.md`. At **standard** and **enterprise**, every context with queries gets one `design/<context>/read-models.md` (`./templates/read-models.md`).

## 1. Every Read Model, Either Rung

- **One Read Model per query shape.** A screen, a caller or a question with its own fields gets its own Read Model; a mobile list and an admin table are two. One event may feed many Read Models.
- **Shaped by the query, not the Aggregate** (Khononov). The Aggregate boundary is drawn for a rule that must hold in one transaction; a Read Model is drawn for a caller. It may combine data from several Aggregates; an Aggregate-shaped "reusable view" makes every caller fetch and reshape what it doesn't need.
- **Only what the caller shows, filters or sorts on.** Nothing "in case". Carry the display values the caller needs, not just IDs it would resolve one at a time (an N+1 read).
- **The API returns it as stored.** If the response needs reshaping at query time, the Read Model is the wrong shape.
- **Named for what it answers** in the context's Ubiquitous Language (`ShiftsNeedingPeople`, `KitchenPrepSheet`), not `<Aggregate>View`.
- **Tenant-scoped:** every row carries the tenant and every query filters on it, under the isolation `multi-tenancy-design` chose; per-region views keep each tenant's data in its region.
- **Queries change nothing,** and **rules never check a Read Model**: a guard against a view races the write side; the Aggregate checks it (`cqrs-pattern` § 4).

How to shape and when to split: `./references/denormalization-patterns.md`.

## 2. Rung 1: A Query Over the Write Tables

The default (Khononov's lighter CQRS). The entry records the query, the caller, the shape, and the write tables and joins it reads through its own query type, never by loading the Aggregate. Joins are fine. Consistency is immediate: no projector, no staleness, no rebuild.

If a query cannot be served this way at the load or shape the NFRs need, do not project it here: send the query and the evidence to enterprise-architect to update `cqrs-decisions.md` (a named trigger), then design the projection.

## 3. Rung 2: A Projection

For each Read Model the decision puts on projections, record:
1. **Events and their effect.** Every event that creates, changes or removes rows, including events from other Aggregates or published by other contexts that supply copied values. A copied value (a dish name, a product title) needs the event that changes it, re-projecting the rows that hold it.
2. **Mechanic:** from published events (the usual one); in the write transaction (immediate, every write pays for it); or change data capture (no events to read; payload is table rows). `./references/projection-mechanics.md`.
3. **Idempotent apply.** Delivery is at-least-once. Key rows on what they answer and apply an event only when it is newer than the version stored, so duplicates and late arrivals cannot roll a row back; deletes and multi-row updates record the processed event ID. The consumer position is written in the same transaction as the view.
4. **Staleness and freshness.** State how stale each projected Read Model may be **as a figure with its reason** ("30 seconds: the kitchen refreshes every 10 s and cooks by the hour"): the one in `cqrs-decisions.md`, or, where it gives none or cannot be read, one proposed from who acts on the view and how soon, marked *assumption, to confirm with enterprise-architect*. "Per the decision" or "eventually consistent" is not a staleness. Each row carries the version it has applied; summaries carry an *as of* time the caller sees; a lag alert fires before the accepted staleness is exceeded. **Read-your-writes**, named per view: the decided method, or the usual one (the Command returns the new version, the writer's view shows *pending* until the row reaches it); or why the writer never reads this view.
5. **Store.** The context's own database by default. A search index or cache only when the query needs it: a cache is cache-aside with a time-to-live no longer than the staleness accepted (Campbell).
6. **Rebuild.** Every projection can be rebuilt from its events, from the start: build into a copy beside the live view, let it catch up, swap, drop the old one. Name the **rebuild source**: a broker topic with a seven-day retention cannot rebuild a year of history. A replay meets **every historical event type** (Young): an old type that was replaced keeps its handler or is read through an upcaster; only a type the projector has never had is ignored. A drifted view is rebuilt, never patched by hand.
7. **Projectors only write the view.** They never issue Commands or publish events, so a rebuild cannot re-fire behaviour; reactions are Policies on the write side.

Freshness detail and anomalies per view: `./references/consistency-patterns.md`.

## 4. Cross-Service CQRS Views

When `cqrs-decisions.md` gives a service a CQRS view over other services' data (Richardson), design it in that service's `read-models.md`. It is fed by their **published** events, never their tables. Their terms are translated at the projector into this context's language, and their event changes reach it through `event-schema-design`'s compatibility rules.

## Producing the Document

1. **Read** `cqrs-decisions.md` (rung, staleness, read-your-writes, cross-service views), the context's `aggregates.md`, `domain-event-catalog.md` and the published events of other contexts it copies from, `command-catalog.md` (versions returned), the screens, user stories and Event Storming read models, the NFRs and the tenancy design. If any is missing, carry on: state each assumption where it is used and list it under *Open questions*.
2. **List the queries:** each screen, caller and question, with who asks it.
3. **Shape** one Read Model per query shape (§ 1): fields, sources, name.
4. **Write** rung-1 entries (§ 2), full projection designs (§ 3) and any cross-service views (§ 4).
5. **Validate, then loop.** Run `./scripts/validate-read-models.sh design/<context>/read-models.md`, fix every FAIL and re-run until it exits clean; then go through `./resources/checklist.md`.
6. **Present** the document and, for every request declined, its reason in full (§ Gotchas). Hand on to data-architect (tables and indexes), `api-contract-design` (a GET per Read Model) and backend-engineer.

Examples: `./examples/01-lean-domain-model-table.md` (lean: a table, no document), `./examples/02-standard-kitchen-prep-sheet.md` (rung-1 entries beside one projected summary, with a drift fixed by a rebuild), `./examples/03-enterprise-gear-search-and-regional-dashboards.md` (a search index fed by three Aggregates across services, per-region views with a lag alert, a swap-in rebuild).

## Gotchas

Each trap comes with the reason to give in full.

- **"Shape the Read Model like the Aggregate so every screen can reuse it."** *Reason:* the Aggregate is drawn for a transactional rule, not a caller; every screen then fetches fields it doesn't show and reshapes at query time. *Instead:* one Read Model per query shape, combining whatever the caller needs.
- **"Never join the write tables; make every view a projection."** *Reason:* on rung 1 a query type over the write tables is the decided design; projections add lag, rebuilds and a projector to run, for nothing the decision asked for. *Instead:* follow the rung in `cqrs-decisions.md`.
- **"This list is slow; I'll just make it a projection here."** *Reason:* the rung is enterprise-architect's decision, and projecting changes consistency for every reader. *Instead:* send the query and the evidence back to update `cqrs-decisions.md`.
- **"The projection is wrong (or fell behind); patch the rows by hand."** *Reason:* the next replay brings the error back, and a hand fix hides the projector bug. *Instead:* fix the projector, rebuild into a copy from the events, swap.
- **"Truncate the view and replay into it."** *Reason:* readers see an empty or half-built view for the whole replay. *Instead:* build the copy beside the live view and swap when it has caught up.
- **"Rebuild from the topic."** *Reason:* a topic keeps only its retention window; older events are gone. *Instead:* name a rebuild source that holds the full history (an event store, an outbox archive) or say what the rebuild can and cannot recover.
- **"We don't emit `OrderPlaced` any more; skip it on replay."** *Reason:* the stored history still holds it; skipping it silently drops every order placed before the change. *Instead:* keep its handler or read it through the upcaster (Young).
- **"Leave staleness and read-your-writes as 'per cqrs-decisions' until the architect fills them in."** *Reason:* a view with no stated lag promises nothing (Kleppmann), and the writer who just booked sees their booking vanish. *Instead:* a figure and a method for every projected view, proposed and labelled as an assumption where the record has none.
- **"Check stock against the Read Model before accepting the order."** *Reason:* the view lags; two orders can pass against the same stale count. *Instead:* the Aggregate checks; the view only shows likely availability.
- **"Let the Command handler update the view too,"** or **"have the projector send the email."** *Reason:* a view written by Command handlers can't be rebuilt from events, and a projector that acts re-fires on every replay. *Instead:* only projectors write the view; reactions are Policies.
- **"Store IDs; the screen can look up the names."** *Reason:* one lookup per row, on every page load. *Instead:* copy the display values and project the event that changes them.

## References

| Question | File |
|---|---|
| What goes in, what to copy, when to split, naming | `./references/denormalization-patterns.md` |
| Which mechanic, idempotency, store, cache, rebuild, replaying old event types | `./references/projection-mechanics.md` |
| Versions, *as of*, read-your-writes and anomalies for one view | `./references/consistency-patterns.md` |
| Checking before hand-off | `./resources/checklist.md` |
