# The Read-Side Ladder and Its Triggers

The detail behind `SKILL.md` § 1–3. Grounded in Khononov (*Learning Domain-Driven Design*: CQRS as a spectrum; the business-logic patterns), Richardson (*Microservices Patterns*, Ch. 7: API Composition vs CQRS) and Evans (*Domain-Driven Design*, Ch. 10: commands and side-effect-free queries), as summarised in `research/domain-driven-design/learning-ddd-khononov.md`, `research/software-architecture/microservices-patterns-richardson.md` and `research/domain-driven-design/domain-driven-design-evans.md`.

## 1. The rungs compared

| | Simple Read Model (rung 1) | Projections (rung 2) |
|---|---|---|
| What it is | Query types and handlers separate from the Aggregate, reading the write tables; joins allowed | Read Models built by folding Domain Events into their own tables or store |
| Storage | The write side's tables | Its own tables, schema, database or a different store (search, graph) |
| Moving parts | None beyond the query code | Event delivery (the Transactional Outbox, a broker or an in-process dispatcher), projectors, rebuilds |
| Consistency | Immediate | Eventual: lag stated per view |
| New view from history | No | Yes, by replaying events (or the stream, if event-sourced) |
| Load on the write path | Shared | Separate |
| Fits | Most contexts; shapes close to the write model; modest load | A named trigger (§ 3) |

Both are CQRS. Rung 1 keeps the split at the type level: commands go through the Aggregate, queries never load it. Khononov names the lighter form as a deliberate starting point, not a lesser one.

**The across-services rungs** follow the same shape. API Composition joins in memory at query time (a gateway, a backend-for-frontend or a dedicated query service calls each owner). A CQRS view is a projection in one service, fed by the other services' published events (`domain-event-catalog`), so the query is answered from one store.

## 2. Business-logic pattern and the read side

The pattern per use case is decided in `aggregate-design` § 1 (Khononov's four). It narrows the read-side choice; it does not make it.

| Pattern (from `aggregates.md`) | Typical read side | Note |
|---|---|---|
| Transaction Script | Rung 1: query the same records through a read type | No Aggregate; no events to project unless the script records them |
| Active Record | Rung 1 | Same |
| Domain Model | Rung 1 unless a trigger is named | Events exist, so rung 2 is cheaper to reach, but still needs a trigger |
| Event-sourced Domain Model | Rung 2 for that context, required | There is no current-state table to query; reads come from projections of the stream |

Applying Domain Model plus projections to a Transaction Script use case is the over-engineering Khononov warns about: rich patterns applied uniformly, regardless of what the subdomain needs. "It's our Core subdomain" is not a trigger; Core status justifies modelling effort, not read infrastructure.

## 3. Triggers, with the evidence each needs

| Trigger | Evidence that makes it real | Not evidence |
|---|---|---|
| Shapes diverge | Two or more screens or consumers need structurally different shapes; the rung-1 query needs many joins or aggregation per request | "We might add a search page" |
| Load differs | NFR read and write rates an order of magnitude apart, or measured query cost slowing writes; a view needs a different store | "It has to scale" |
| Combines many Aggregates or contexts | The view folds data from several Aggregates or services, and the join or the composition fan-out is large | One extra lookup |
| History | A view must cover what happened before it existed; or the write side is event-sourced | "Events are nice to have" |
| Across services | Large composed results, wide fan-out, or the query must answer while a source service is down | "Composition is old-fashioned" |

Write each trigger as: **the query, the evidence, and why rung 1 fails it.** Record *revisit when* for every context on rung 1: the signal (a new screen, a load figure, a measured latency) that would bring a trigger into being.

## 4. Across services: composition first

API Composition costs:
- latency and availability coupled to every source (if one is down, the query fails or degrades);
- in-memory joins that are poor for large results;
- fan-out that multiplies calls per request.

A CQRS view costs:
- eventual consistency between the sources and the view;
- the projection machinery, in the service that owns the view;
- a dependency on the sources' published events, which must carry what the view needs (`domain-event-catalog` § 3).

Name which service owns a CQRS view (usually the one whose users ask the question) and which published events feed it. Never read another service's tables: it couples schemas and deployments, and bypasses that service's language and rules.

## 5. Moving down a rung

A projected view that no longer earns its cost (the screen was dropped, load fell) can move back to rung 1. Record the change like any other decision; the view's consumers lose the lag and the rebuild duty.
