---
name: domain-model
product: [product slug]
version: 1.0.0
phase: design
owner: domain-modeler
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: the contexts, which use cases needed a Domain Model and which a Transaction Script or Active Record]
profile: lean
traces-to: [design/event-storming/big-picture.md, design/subdomain-classification.md, design/context-map.md, design/<context>/ubiquitous-language.md]
---

# Domain Model: [Product]

Lean only: one document in place of the per-context `aggregates.md`, Domain Event catalogue, Command catalogue and Read Model designs. Shorter, never a skipped methodology: every Aggregate still passes the three-question test, every event is past tense, every Command names its guard.

Version rule: MINOR when a Command, event or Read Model is added; MAJOR when a boundary moves, an invariant is added or dropped, or a pattern changes.

<!-- Same blocks as templates/aggregates.md: "## Aggregate:" for Domain Model / Event-Sourced Domain Model,
     "## Use case:" for Transaction Script / Active Record. Add a **Context** row to each block's table.
     A lean product with no True Invariant has only "## Use case:" blocks; that is a valid result. -->

## Aggregate: [Name]

| Field | Value |
|---|---|
| **Context** | [Bounded Context] |
| **Root** | [root Entity and its responsibility] |
| **Pattern** | [Domain Model | Event-Sourced Domain Model] — [the True Invariant that earned it] |
| **Identity** | [client-generated, or the reason for another strategy] |
| **Concurrency** | [optimistic, or the condition for another strategy] |
| **Event sourcing** | [not used — none of the three needs applies] or [used — which need] |
| **Contention** | [low | medium | high] — [why] |

### Invariants

| Invariant (one sentence) | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Verdict |
|---|---|---|---|---|
| [rule] | yes | no | no | True Invariant |

### Rejected candidates

| Rule considered | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Handled instead by |
|---|---|---|---|---|

### Members

| Member | Kind | Identity or equality | Why inside this Aggregate |
|---|---|---|---|

### Relationships to other Aggregates

| Other Aggregate | Has-a? | Must be atomic? | Conclusion | Reference |
|---|---|---|---|---|

## Use case: [Name]

| Field | Value |
|---|---|
| **Context** | [Bounded Context] |
| **Pattern** | [Transaction Script | Active Record] — [why no Domain Model] |
| **Records touched** | [records] |
| **Rules** | [single-record rules, or "none"] |

## Domain Events

| Context | Event (past tense) | Raised by | Carries | Who reacts |
|---|---|---|---|---|
| [context] | [PastTenseEvent] | [Command or use case] | [the facts a reaction needs] | [reaction, idempotent] |

## Commands

| Context | Command | Guard | Handled by | Idempotency |
|---|---|---|---|---|
| [context] | [Command] | [precondition] | [Aggregate or use case] | [key or natural, e.g. "same request id ignored"] |

## Read Models

| Context | Read Model | Answers | Built from | Staleness accepted |
|---|---|---|---|---|
| [context] | [name] | [the screen or question] | [events or tables] | [e.g. seconds] |

## Open questions

- [question for the product owner]
