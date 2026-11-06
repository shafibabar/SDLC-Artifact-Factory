---
name: command-catalog
product: [product slug]
bounded-context: [context name]
version: 1.0.0
phase: design
owner: domain-modeler
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: how many Commands, on which Aggregates, issued by whom]
profile: [standard | enterprise]
traces-to: [design/<context>/aggregates.md, design/event-storming/process-<name>.md, design/<context>/ubiquitous-language.md, design/<context>/domain-event-catalog.md]
---

# Command Catalog: [Context name]

Version rule: MINOR when a Command, input or rejection is added; MAJOR when a Command is renamed, retired, changes its intent, its target or its idempotency key (review with `api-contract-design` and the callers).

<!-- Intent, inputs, rejections, idempotency. HTTP methods, paths and status codes are api-contract-design's;
     code is go-service-layer / go-domain-model / go-chi-handler. No code, no HTTP. -->

## Commands

| Command | Aggregate | Issued by | Records |
|---|---|---|---|
| [ImperativeIntent] | [Aggregate] | [actor role | Policy | schedule] | [PastTenseEvent] |

## Command: [ImperativeIntent]

| Field | Value |
|---|---|
| **Intent** | [one sentence in the language: what the issuer wants to happen] |
| **Aggregate** | [the one Aggregate it targets] — [how the instance is identified] |
| **Issued by** | [actor role, with the permission it needs | Policy: Whenever [Fact], then [this Command] | schedule: …] |
| **Records** | [PastTenseEvent, from aggregates.md; a second only when it is a distinct fact] |
| **Idempotency key** | [client request ID kept across retries of one intent | triggering event ID | schedule + period | natural key: …] |
| **On a duplicate** | returns the first outcome, rejection included; keys kept [N] ([the longest retry horizon, failover included]) |
| **Already in effect** | [succeeds and records nothing | rejected as rule violated] — [why] |
| **Concurrency** | [version the actor saw; a mismatch is a conflict | none needed — why] |
| **Caller needs** | [the outcome now | an acknowledgement now, the outcome via event or Read Model] |
| **Source** | [artifact it came from | *assumed* — see Open questions] |

### Inputs

| Input | Meaning (in the language) | From | Input rule (checked before the Aggregate) |
|---|---|---|---|
| [input] | [what it means, including what "absent" means] | [request | target | authenticated context | triggering event | clock] | [present, range, allowed values; "—" if none] |

### Rejections

| Rejection (in the language) | Kind | Checked where |
|---|---|---|
| [what the issuer is told] | [invalid input | not permitted | not found | reference invalid | rule violated | conflict] | [input | access check | loading the target | application | Aggregate | Aggregate version] |

## Open questions

- [question for the product owner or a calling context]
