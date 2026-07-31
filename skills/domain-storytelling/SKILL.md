---
name: domain-storytelling
description: >
  Teaches the domain-modeler to facilitate Domain Storytelling sessions — a collaborative
  modelling method where domain experts narrate how they work, using subject-verb-object
  sentences that the facilitator captures as pictographic models (actors, work objects,
  activities, arrows, annotations). Covers the pure vs. annotated storytelling modes,
  when to use each granularity level (coarse-grained for BC discovery, fine-grained for
  Aggregate design), the pictogram notation rules, the story collection facilitation
  procedure, and how Domain Stories feed into Event Storming and Ubiquitous Language
  extraction. Used during Design before Event Storming when the domain experts' workflow
  is not yet understood.
version: 2.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: ["design","domain-modeling","domain-storytelling","facilitation","actor","work-object","ubiquitous-language"]
related:
  - event-storming
  - ubiquitous-language
  - bounded-context-mapping
  - acceptance-criteria
---

# Domain Storytelling

## What It Is

Domain Storytelling (Stefan Hofer & Henning Schwentner) is a collaborative modelling
method where a domain expert narrates how they work while a facilitator draws the story
as a pictographic model. Every sentence in a Domain Story has exactly three parts:

| Component | Role | Examples from this repo's domain |
|---|---|---|
| **Actor** | Subject — the person, system, or role doing the work | Compliance Officer, Storage Connector, Google Drive |
| **Activity** | Verb — the action the Actor performs | classifies, reviews, requests, sends |
| **Work Object** | Object — the thing the Actor works with or produces | DataAsset, Classification Alert, Audit Record |

Each sentence is drawn as a numbered arrow: Actor → (numbered, activity-labelled arrow) →
Work Object. The numbers create a readable left-to-right sequence. The model IS the
sentence — nothing more, nothing less.

Where Event Storming asks "what happened?", Domain Storytelling asks "who does what
with what?" The two are complementary: Domain Storytelling establishes the human workflow
narrative first; Event Storming then lays the event-and-command layer on top.

---

## Two Storytelling Modes

| Mode | When to use | Language rule |
|---|---|---|
| **Pure** | First pass — while the workflow is being discovered | Domain-expert language only; no software concepts, no "the system" as actor |
| **Annotated** | After the pure story is validated | Software labels added to actors and work objects to bridge from domain to design |

Always start pure. Only transition to annotated after the domain expert has confirmed
the pure story is an accurate picture of how they actually work.

---

## Granularity Levels

| Level | Typical story length | Primary purpose |
|---|---|---|
| **Coarse-grained** | 5–10 steps | Bounded Context discovery — understand the big-picture workflow before Event Storming |
| **Fine-grained** | 15–30 steps | Aggregate design — expose business rules, approval flows, and exception paths not visible at coarse level |

Start coarse-grained. After Bounded Context candidates emerge, zoom into fine-grained
for each complex or contested workflow. Fine-grained stories are where Aggregate
operations and invariant candidates first become visible in a domain expert's own words.

---

## Sequencing with Event Storming

Use Domain Storytelling **before** Event Storming when:
- The domain experts' workflow is unfamiliar and needs narration before events can be named
- Bounded Context boundaries are unclear — Domain Stories surface handoff points
- Ubiquitous Language candidates are needed before placing Event Storming sticky notes

Use Event Storming **after** Domain Storytelling to:
- Add the command and Domain Event layer on top of the validated workflow narrative
- Surface domain policies that the storytelling sessions revealed but did not fully define
- Verify that the Domain Events on the board match the activities from the Domain Stories

---

## Outputs

A Domain Storytelling session produces three categories of downstream material:

| Output | Feeds downstream |
|---|---|
| Named Actors and Work Objects | Ubiquitous Language candidates → `ubiquitous-language` skill |
| Numbered Activity sequence | Event Storming command/event flow — confirms or challenges sticky-note order |
| Boundary markers (handoffs between teams or external systems) | Bounded Context boundary candidates → `bounded-context-mapping` skill |

Every story ends with a completed "Feeds Forward To" table naming the artifact each
discovery feeds. A Domain Story that produces no downstream references is shelfware.

---

## Signals to Watch For

While drawing, actively watch for these domain signals:

| Signal | Implication |
|---|---|
| Expert uses an unfamiliar term | New Ubiquitous Language candidate — record the exact word they used |
| Same work object called two names | Synonym conflict — ask which is canonical; feed to `ubiquitous-language` |
| Expert says "then IT does something" | System or team boundary — Bounded Context candidate |
| Story stops at "it depends..." | Policy or business rule — run a variation scenario |
| Activity crosses to an external system | Context boundary; model the integration pattern |
| Expert corrects the drawing | The model was wrong — update it; draw what was said, not what was intended |

---

## References

Detailed content for facilitation, notation, and worked examples lives in `references/`.
Read the relevant file when facilitating a session, reviewing notation, or studying a
fully worked story:

- **`references/notation-guide.md`** — complete pictogram specification: Actor shapes
  (human, system, external), Work Object shapes, Activity (labelled arrow), Annotation,
  Sequence number placement, concurrent activities, the one-sentence-per-arrow rule,
  anti-patterns (flowchart shapes, decision diamonds, swim lanes), Miro element mapping.

- **`references/facilitation-guide.md`** — full session facilitation procedure:
  pre-session setup, participant count and roles, session opening script with example
  prompts, story collection protocol, validation pass, pure-to-annotated transition,
  variation scenario procedure, and common failure modes.

- **`references/worked-examples.md`** — two fully worked Domain Stories from this
  repo's data-estate/compliance domain: (1) a coarse-grained story for DataAsset BC
  discovery, (2) a fine-grained story exposing Aggregate operations in the classification
  workflow, each with Ubiquitous Language extractions, BC boundary markers, and Aggregate
  operation candidates in Go method form.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Concrete scenario | A specific, remembered occasion with real roles and real objects | General description ("usually what happens is...") |
| Story read back | Facilitator reads the model back; domain expert corrects it | Story drawn but never validated with the expert |
| New terms captured | All Ubiquitous Language candidates noted verbatim in the expert's words | Terms used by the expert but not recorded |
| Variation scenarios | At least one exception or alternate flow explored after the primary story | Happy path only |
| Boundary markers | Handoffs between teams or external systems are marked on the drawing | All activities treated as within one boundary |
| Feeds forward | Session output explicitly maps to downstream artifacts | Domain Story filed and unreferenced by any later artifact |

---

## Output Format

```markdown
---
name: domain-story
product: [product name]
domain: [domain or subdomain name]
scenario: [one-line description of the story]
scope: [coarse-grained | fine-grained]
mode: [pure | annotated]
version: 1.0.0
phase: design
created: [date]
owner: domain-modeler
---

# Domain Story: [Scenario Name]

## Participants
- **Domain expert:** [role]
- **Facilitator:** domain-modeler agent
- **Observers:** [roles]

## The Story (narrative)
[Written narrative of the story as told by the domain expert — in their language]

## Story Steps (structured)

| Step | Actor | Activity | Work Object | Annotation |
|---|---|---|---|---|
| 1 | [Actor] | [Action] | [Work Object] | [Condition / context] |

## Boundary Markers
[Where did the story cross a team or system boundary? What was on each side?]

## Variation Scenarios
### Variation 1: [Scenario name]
[Steps for the variation]

## Terms Discovered
| Term as used | Type (Actor / Work Object / Activity) | Canonical? | Action |
|---|---|---|---|

## Synonym Conflicts
| Term A | Term B | Context | Resolution |
|---|---|---|---|

## Feeds Forward To
| Output | Target artifact |
|---|---|
| [Named element] | [Downstream artifact] |
```
