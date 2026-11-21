---
name: aggregate-design
product: [product slug]
bounded-context: [context name]
version: 1.0.0
phase: design
owner: domain-modeler
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: the context's Aggregates, the invariants that shaped them, and any exception or event sourcing]
profile: [standard | enterprise]
traces-to: [design/<context>/ubiquitous-language.md, design/event-storming/software-design.md, design/subdomain-classification.md, design/context-map.md]
---

# Aggregate Design: [Context name]

Version rule: MINOR when an Aggregate gains a Command, an event or a member; MAJOR when a boundary moves, an invariant is added or dropped, or a pattern changes (review `domain-event-catalog` and `command-catalog`).

<!-- One "## Aggregate:" block per Domain Model or Event-Sourced Domain Model Aggregate.
     One "## Use case:" block per use case that needs only a Transaction Script or Active Record.
     No code (D047-10): names, rules and events only. Implementation is go-domain-model's. -->

## Aggregate: [Name]

| Field | Value |
|---|---|
| **Root** | [root Entity and its responsibility in one sentence] |
| **Pattern** | [Domain Model | Event-Sourced Domain Model] — [the True Invariant that earned it] |
| **Identity** | [client-generated | business identifier via the Repository | storage-generated] — [reason if not client-generated] |
| **Concurrency** | [optimistic | pessimistic | scoped serialisable] — [the condition, if not optimistic] |
| **Event sourcing** | [not used — checked temporal query / retroactive projection / audit-as-record: none applies] or [used — which need, and the costs accepted] |
| **Contention** | [low | medium | high] — [writers, frequency, bursts] |
| **Cohesion buys / coupling costs** | [rules this size enforces together] / [independent operations it forces to contend] |

### Invariants

| Invariant (one sentence) | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Verdict |
|---|---|---|---|---|
| [rule] | yes | no | no | True Invariant |

### Rejected candidates

| Rule considered | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Handled instead by |
|---|---|---|---|---|
| [rule] | [yes/no] | [yes/no] | [yes/no] | [eventual consistency via X / query / Read Model / external system] |

### Members

| Member | Kind | Identity or equality | Why inside this Aggregate |
|---|---|---|---|
| [name] | [Entity (local) | Value Object | Value Object, self-validating] | [local id within root | all attributes] | [the invariant it takes part in] |

### Commands and events

| Command | Requires (guard) | Guarantees | Domain Event | Published |
|---|---|---|---|---|
| [Command] | [precondition] | [postcondition] | [PastTenseEvent] | [as-is | translated to X | internal only] |

### Relationships to other Aggregates

| Other Aggregate | Has-a? | Must be atomic? | Conclusion | Reference |
|---|---|---|---|---|
| [name] | [yes/no] | [no / yes: the invariant] | [separate | merged | exception] | [by ID | by ID + read-only copy (Exception 2)] |

### Coordination

[For each consequence in another Aggregate: the event, who reacts (idempotently), what the user sees meanwhile. Or a Saga: its steps with compensatable / pivot / retryable and the semantic-lock states. Or "none".]

### Exceptions taken

[None] or [rule broken — Exception 1 (cross-object invariant) or Exception 2 (measured read bottleneck) — why, in one or two sentences]

## Use case: [Name]

| Field | Value |
|---|---|
| **Pattern** | [Transaction Script | Active Record] — [why no Domain Model: the rule checked and why it fails, or "no rule across records"] |
| **Records touched** | [the table(s) or record(s)] |
| **Rules** | [single-record rules, e.g. a uniqueness constraint; or "none"] |

## Open questions

- [question for the product owner, e.g. whether a staleness window is acceptable for a named rule]
