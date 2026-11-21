---
name: domain-event-catalog
product: [product slug]
bounded-context: [context name]
version: 1.0.0
phase: design
owner: domain-modeler
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: how many events, which are published, and to whom]
profile: [standard | enterprise]
traces-to: [design/<context>/aggregates.md, design/event-storming/process-<name>.md, design/<context>/ubiquitous-language.md, design/context-map.md]
---

# Domain Event Catalog: [Context name]

Version rule: MINOR when an event or a consumer is added; MAJOR when an event's meaning changes, it is renamed or retired, or its visibility changes (review `design/data/event-schemas.md`).

<!-- Meaning only. The envelope, types, versioning and registry are event-schema-design's (design/data/event-schemas.md);
     delivery is event-driven-patterns'; code is go-event-publisher / go-event-consumer. No code, no DDL. -->

## Events

| Event | Aggregate | Visibility | Consumers |
|---|---|---|---|
| [PastTenseFact] | [Aggregate] | [published | internal | stored] | [contexts, or "none yet"] |

## Event: [PastTenseFact]

| Field | Value |
|---|---|
| **Means** | [one sentence in the language: what happened in the business] |
| **Aggregate** | [the Aggregate that records it] |
| **Raised by** | [Command X | Policy "whenever Y, then Z" | time: … | external: …] |
| **Visibility** | [published | internal | stored (event-sourced)] |
| **Published as** | [published: see design/data/event-schemas.md | internal/stored: translated to <PublishedFact>, or not published — why] |
| **Ordering** | [per Aggregate | none needed] |
| **Retention need** | [audit evidence N years | consumer replay N days | operational only] — [the business reason] |
| **Sensitive data** | [none | which facts are carried as references, and why] |

### Payload meaning

| Field | Meaning (in the language) | Why a consumer needs it |
|---|---|---|
| [field] | [what it means, including what "absent" means] | [the reaction it enables] |

### Guarantees (optional)

- [a rule that always holds for this event, e.g. "raised only when the level actually changes", "previous and new values differ"]

### Consumers

| Consumer | Reaction (policy) | Idempotent on | If an event is stuck |
|---|---|---|---|
| [context] | Whenever [Fact], then [Command in that context] | [event id within source | business key] | [halts this Aggregate's partition | tolerates out-of-order replay] |

## Translations

| Internal or stored events | Published as | Never published |
|---|---|---|
| [InternalFactA, InternalFactB] | [PublishedFact] | [InternalFactC — why] |

## Open questions

- [question for the product owner or a consuming context]
