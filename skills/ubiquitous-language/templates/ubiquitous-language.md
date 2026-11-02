---
name: ubiquitous-language-[context-slug]
product: [product slug]
bounded-context: [Bounded Context name]
version: 1.0.0
phase: design
owner: domain-modeler
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: the context, how many terms, and the key bans or homonyms it settles]
profile: [lean | standard | enterprise]
traces-to: [the Event Storming output, subdomain-classification and Ideate artifacts it was drawn from]
---

# Ubiquitous Language: [Bounded Context name]

## Context Boundary

[One paragraph: what this Bounded Context is responsible for, and where its boundary lies, meaning the point at which its words would start to mean something else. Name the neighbouring contexts.]

**How this language was found:** [human workshop on <date> with <roles> | agent-run from the artifacts in `traces-to`; terms marked *assumed* are unconfirmed]

## Terms

| Term | Type | Meaning in this context | Rules that always hold | Behaviour (event, command or scenario) | Source |
|---|---|---|---|---|---|
| [Term] | [Entity / Value Object / Aggregate Root / Domain Event / Command / Read Model / Policy / Concept] | [Domain words; no implementation] | [Invariants; required for an Entity or Aggregate Root] | [`EventName`, `CommandName` or feature-file scenario] | [artifact path, workshop, or *assumed*] |

<!-- standard and enterprise: key Aggregate Roots only -->
### [Term]: example and counter-example

- **Is:** [a concrete case with real-looking data]
- **Is not:** [the nearest thing that doesn't qualify, and why]

## Key Scenarios

At least one per key term (each Aggregate Root and Policy), at every profile. Short; they seed the feature files later.

```gherkin
Scenario: [the rule, in the language]
  Given [state, in this context's terms]
  When [Command or event]
  Then [outcome, in this context's terms]
```

## Banned Synonyms

The `terminology-drift-detector` hook reads the first two columns: one or more banned words (comma-separated), then the term to use instead.

| Banned | Use instead | Renamed in (code · API · events · tests · docs) |
|---|---|---|
| [word, word] | [Term] | [✔ code · ✔ API · ✘ events · ✔ tests · ✔ docs, or "nothing built yet"] |

## Homonyms at the Boundary

| Term | Meaning here | Other context | Meaning there | Translation (Context Map relationship) |
|---|---|---|---|---|
| [Term] | [meaning] | [context] | [meaning] | [e.g. ACL in this context maps their `X` to our `Y`] |

## Open Questions for the Product Owner

Agent-run: also list the sentences for the product owner (or someone they name) to read aloud; any that sound wrong are findings.

| # | Question | Why it matters | Assumed meanwhile |
|---|---|---|---|
| 1 | [question] | [what changes in the model depending on the answer] | [the assumption in use] |

## Retired Terms

| Term | Retired on | Reason | Successor (if merged) |
|---|---|---|---|
