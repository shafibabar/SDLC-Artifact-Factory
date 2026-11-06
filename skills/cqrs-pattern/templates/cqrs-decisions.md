---
name: cqrs-design
product: [product slug]
version: 1.0.0
phase: design
owner: enterprise-architect
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: which contexts are projected and on what trigger; the rest use a Simple Read Model]
profile: [standard | enterprise]
traces-to: [design/<context>/aggregates.md, design/<context>/domain-event-catalog.md, ideate/nfr-specification.md, design/context-map.md]
---

# CQRS Decisions: [Product]

Decided before Read Models are designed (D047-4). The ladder: Simple Read Model by default, projections only on a named trigger; across services, API Composition by default, a CQRS view only on a named trigger.

<!-- The read-side choice only. Read Model shapes, projectors and rebuilds are read-model-design's; code is go-service-layer / go-event-consumer. No code. -->

## Contexts

| Bounded Context | Read side | Trigger | Staleness accepted |
|---|---|---|---|
| [context] | [simple read model | projections] | [none — rung 1 | the trigger in a few words] | [immediate | N seconds] |

## Context: [name]

| Field | Value |
|---|---|
| **Read side** | [simple read model | projections] |
| **Business-logic pattern** | [from aggregates.md: Transaction Script | Active Record | Domain Model | Event-sourced Domain Model] |
| **Event sourced** | [no | yes — <Aggregates>; projections are required] |
| **Trigger** | [none — a Simple Read Model serves every query | <the query>: <the evidence>; <why rung 1 fails it>] |
| **Staleness accepted** | [immediate | <N> — <why the business accepts it>] |
| **Read-your-writes** | [immediate (same tables) | the Command returns the version; the writer's view shows pending until it is applied | …] |
| **Replicas or regions** | [one copy | <how monotonic reads are kept>] |
| **Revisit when** | [the signal that would move this context up (or down) a rung] |

### Queries

| Query (screen or question) | Served by | Why |
|---|---|---|
| [query] | [simple read model | projection: <view name> | write side (cannot lag)] | [reason] |

## Cross-service queries

| Query | Services | Approach | Trigger | Owner of the view |
|---|---|---|---|---|
| [query] | [services] | [API Composition | CQRS view] | [none — composition | <the query>: <the evidence>] | [— | <service>, fed by <published events>] |

## Open questions

- [question for the product owner]
