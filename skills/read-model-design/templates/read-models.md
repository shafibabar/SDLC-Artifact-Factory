---
name: read-model-design
product: [product slug]
bounded-context: [context name]
version: 1.0.0
phase: design
owner: domain-modeler
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: which questions this context's Read Models answer, which are projected and how fresh they are]
profile: [standard | enterprise]
traces-to: [design/architecture/cqrs-decisions.md, design/<context>/aggregates.md, design/<context>/domain-event-catalog.md, ideate/nfr-specification.md]
---

# Read Models: [Context]

**Read side (from `cqrs-decisions.md`):** [simple read model | projections — the trigger in a few words]

<!-- Design only. The rung is cqrs-pattern's; tables and indexes are data-model-design's; endpoints are api-contract-design's; code is go-repository-pattern / go-event-consumer. No code. -->

## Read Models

| Read Model | Answers | Rung | Staleness accepted |
|---|---|---|---|
| [Name] | [the question, and who asks it] | [simple read model | projection] | [immediate | <N>, from cqrs-decisions] |

<!-- Rung 1: copy this block for each Read Model served by a query over the write tables. -->
## Read Model: [Name]

| Field | Value |
|---|---|
| **Answers** | [the screen or question, and who asks it] |
| **Rung** | simple read model |
| **Built from** | [the write tables and joins, read through a query type — never by loading the Aggregate] |
| **Filters and order** | [what the caller filters, sorts and pages by] |
| **Tenant scope** | [tenant on every row; every query filters on it | single tenant] |

### Fields

| Field | Meaning | Source |
|---|---|---|
| [field] | [what the caller sees, in the context's language] | [table.column, or the join] |

<!-- Rung 2: copy this block for each projected Read Model. -->
## Read Model: [Name]

| Field | Value |
|---|---|
| **Answers** | [the screen or question, and who asks it] |
| **Rung** | projection |
| **Mechanic** | [from published events | in the write transaction | change data capture] — [why] |
| **Store** | [the context's database | a search index | … ; a cache in front only with a time-to-live within the staleness] |
| **Keyed on** | [what one row answers for: an identity, a tenant and day, …] |
| **Staleness accepted** | [<N> in normal running, from cqrs-decisions; what readers see during a rebuild] |
| **Freshness shown** | [the version applied per row | an *as of* time the caller sees] |
| **Read-your-writes** | [how the writer sees their own change: the Command returns the version, the view shows pending until applied | the writer does not read this view: <why>] |
| **Idempotency** | [apply only if newer, by <version> | processed-event record for <events>] |
| **Lag alert** | [the threshold below the accepted staleness, and who is told] |
| **Rebuild source** | [where the full history is: event store | outbox archive | compacted topic | … ; what it cannot recover] |
| **Rebuild** | [build into a copy beside the live view from the first event, catch up, switch in one step, drop the old; never patched by hand] |
| **Old event types** | [replaced types still handled on replay: <OldType → handled | read through upcaster> | none yet] |
| **Tenant scope** | [tenant on every row; every query filters on it; region, if per-region] |

### Fields

| Field | Meaning | Source | Copied from |
|---|---|---|---|
| [field] | [what the caller sees] | [Event.field] | [— | <other Aggregate or context> (its change event: <Event>)] |

### Events

| Event | Effect on the view |
|---|---|
| [Event] | [creates a row | updates <fields> | removes the row | re-projects rows holding <copied value>] |

## Open questions

- [question for the product owner or another agent]
