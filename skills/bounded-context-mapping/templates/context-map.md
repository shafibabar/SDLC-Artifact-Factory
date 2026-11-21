---
name: context-map
product: [product slug]
version: 1.0.0
phase: design
owner: domain-modeler
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: how many contexts, the strongest boundary evidence, and anything legacy or external]
profile: [lean | standard | enterprise]
mode: [agent-run | workshop on YYYY-MM-DD with <roles>]
traces-to: [design/subdomain-classification.md, design/event-storming/big-picture.md, design/<context>/ubiquitous-language.md, …]
---

# Context Map: [Product]

Version rule: MINOR when a context gains an Aggregate, an event or a term; MAJOR when a boundary moves or a line's pattern changes (review `container-diagram` and the event catalogue).

## Contexts

### [Context name]

| Field | Value |
|---|---|
| **Responsibility** | [one sentence] |
| **Subdomain(s)** | [name (Core / Supporting / Generic)] |
| **Boundary evidence** | [the word whose meaning changes, the Event Storming hint, the story group, the record-ownership split; cite each, or *assumed*] |
| **Language** | `design/[context]/ubiquitous-language.md` |
| **Owns (Aggregates)** | [candidates until aggregate-design] |
| **Publishes** | [Domain Events] |
| **Consumes** | [events or read models, and from which context] |
| **Owner** | [the owning team, or "domain-modeler (agent-built)"] |
| **Candidate split** | [a possible later split and its trigger, or "none"] |

[Repeat per context]

## External Systems

| System | Used by | What it provides |
|---|---|---|

## Current Map (existing systems only)

```
[plain-text boxes and lines, as it is today]
```

## Target Map

```
[plain-text boxes and lines; U = upstream, D = downstream]
```

## Relationships

One row per line on the target map. Pattern, reason (naming the pattern considered and rejected) and contract are filled by `context-map-patterns`.

| Upstream | Downstream | Pattern | Reason | Contract |
|---|---|---|---|---|
| [context] | [context] | [ ? ] | [ ? ] | [ ? ] |

## Open Questions for the Product Owner

| # | Question | Why it matters | Boundary assumed meanwhile |
|---|---|---|---|
