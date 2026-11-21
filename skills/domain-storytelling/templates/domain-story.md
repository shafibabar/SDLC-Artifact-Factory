---
name: domain-story-[story-slug]
product: [product slug]
scenario: [one line: the concrete case this story tells]
granularity: [coarse-grained | fine-grained]
point_in_time: [as-is | to-be]
purity: [pure | digitalised]
run: [agent-run | workshop on YYYY-MM-DD with <storyteller roles>]
variant_of: [the story slug this is a variant of, or "none"]
version: 1.0.0
phase: design
owner: domain-modeler
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: the case, its scope, and what it showed (a hand-over, a boundary hint, a gap)]
traces-to: [the artifacts it was drawn from; for a workshop, the session notes]
---

# Domain Story: [Scenario]

**Scope:** [granularity] / [point in time] / [purity]. **How it was made:** [agent-run from the artifacts in `traces-to`: a draft, N of M sentences *assumed* | told by <roles> on <date>, moderated by <role>, drawn by <role>]

## Roles

- **Storytellers:** [roles, or "none: agent-run"]
- **Moderator / modeller:** [roles, or "domain-modeler (agent-run)"]

## The Story

One concrete case, no branches. Actor – activity – work object, with a recipient where something is handed over.

| # | Actor | Activity | Work object | To (recipient) | Annotation | Source |
|---|---|---|---|---|---|---|
| 1 | [role] | [verb] | [thing] | [role, or —] | [condition, example data, or —] | [artifact item, session, or *assumed*] |

## Variants

| Variant | Told as | Why |
|---|---|---|
| [what else can happen] | [`domain-story-<slug>` (its own story) or "annotation on sentence N"] | [important enough for its own story, or minor] |

## Groups (candidate boundaries)

| Group | Sentences | Hint: word changes · role takes over · pace or trigger changes · hand-over |
|---|---|---|

## Terms Found

| Term | Kind (actor / work object / activity) | Whose word | Note |
|---|---|---|---|
| [term] | [kind] | [storyteller's word, or "document term" if agent-run] | [synonym or meaning question] |

## Open Questions for the Product Owner

| # | Question | Why it matters | Assumed meanwhile |
|---|---|---|---|

## Retelling (agent-run: for the product owner to check)

1. [Sentence 1 in plain words]
2. [...]

## Feeds Forward

| Output | Goes to |
|---|---|
| Terms | `ubiquitous-language` |
| Groups | `bounded-context-mapping` |
| Person-and-software sentences (to-be digitalised) | Candidate user stories |
| Variants | `acceptance-criteria` |
