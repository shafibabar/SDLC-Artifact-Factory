---
name: epic-definition
description: >
  Teaches how to write the epic list in Ideate: outcome-named epics, each a
  falsifiable hypothesis traced to a selected-path deliverable on the impact
  map (or the Key Result where there is no map), to a job statement and the
  job story beneath it, and to the user requirements it carries; with a
  four-risk line (value, usability, feasibility, viability), 3–5 high-level
  epic acceptance criteria each with a concrete example, a Bounded Context
  candidate (cross-context epics flagged to the domain-modeler), story titles
  in narrative order, a structural size and a provisional priority that
  MoSCoW finalises. Use when writing or reviewing epics, deciding epic vs
  story vs theme, sizing or splitting an oversized or component-named epic,
  writing epic acceptance criteria, or turning impact-map deliverables and
  functional requirements into a backlog. Used by the requirements-analyst
  agent in Ideate (/sdlc-ideate) after the NFR specification and before
  user-story-writing and story-mapping; required at standard and enterprise,
  folded into the backlog as epic headings at lean.
version: 3.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, requirements, epic, epic-list, hypothesis, four-risks, story-decomposition, traceability]
produces: epic-list
domain: discovery
status: stable
related: [impact-mapping, requirements-analysis, jtbd-analysis, nfr-specification, okr-authoring, roadmap-authoring, opportunity-solution-tree, user-story-writing, story-mapping, example-mapping, acceptance-criteria, moscow-prioritization, glossary-management, methodology-review]
sources:
  - research/requirements-and-user-stories/user-stories-applied-cohn.md
  - research/requirements-and-user-stories/user-story-mapping-patton-economy.md
  - research/product-strategy-and-gtm/inspired-cagan.md
  - research/requirements-and-user-stories/lean-agile-atdd-pugh.md
  - research/requirements-and-user-stories/dsdm-agile-project-framework.md
---

# Epic Definition

## Purpose

The epic list answers: **which outcomes will the backlog deliver, what does each bet on, and roughly what is involved?** It turns the bet chosen upstream (the impact map's selected path, the jobs behind it and the functional requirements written for it) into a small number of outcome-named units that `user-story-writing` decomposes and `story-mapping` lays out. An epic is the last place the *why* is written beside the *what*: below it, stories carry the trace but not the argument.

**The plugin's epic is richer than Cohn's, on purpose.** In Mike Cohn's *User Stories Applied* an epic is just a story too big to plan yet, and a theme is a looser grouping label. This plugin layers a hypothesis, upstream traces, a four-risk line and a Bounded Context candidate on top, for discovery rigour. Say so rather than attributing that apparatus to Cohn. Jeff Patton (*User Story Mapping*, with Peter Economy) has no "epic": his **backbone tasks** are the closest equivalent, which is why epics become the story map's backbone.

## Where It Sits

```
Ideate: personas ─► JTBD ─► opportunity solution tree ─► impact map ─► functional requirements ─► NFRs ─► EPICS ─► stories ─► example maps ─► acceptance criteria ─► story map ─► MoSCoW
```

| Reads | What it takes |
|---|---|
| `impact-mapping` | The **selected path**: each selected deliverable (SOL-n or named) and the impact it should cause. That impact becomes the epic's hypothesis. Option branches are never epics |
| `jtbd-analysis` | Job statements (J-n) and the job stories beneath them (JS-n.m) |
| `requirements-analysis` | User requirements (UR-n, each already traced to a deliverable and a job story) and transition requirements (TR-n). Each UR lands in one epic, or is split by FR |
| `nfr-specification` | Architecture hand-off items that raise an epic's feasibility risk |
| `okr-authoring`, `roadmap-authoring` | The Key Result (KR-n.m) every epic serves; the roadmap Theme it sits under, when a roadmap exists |

| Feeds | What it gives |
|---|---|
| `user-story-writing` | Story titles in narrative order; each story inherits the epic's traces |
| `story-mapping` | Epics as backbone candidates. The walking skeleton is decided there, not here |
| `moscow-prioritization` | Provisional priority and structural size. MoSCoW finalises priority at the end of Ideate |
| domain-modeler (Design) | Bounded Context candidates and every cross-context flag |

## Epic, Story, Theme, Task

| Level | Is | Carries |
|---|---|---|
| **Theme** | In this plugin, the roadmap **Theme** (a customer problem) that epics sit under; never a separate invented label | Nothing of its own: the roadmap owns it |
| **Epic** | One coherent outcome needing 3–10 stories | Hypothesis, traces, four-risk line, 3–5 high-level criteria |
| **Story** | One user-visible behaviour an agent can build and verify against its own acceptance criteria | Given/When/Then, written later (`acceptance-criteria`) |
| **Task** | A technical step inside a story (a migration, a handler) | No user value of its own |

**Size is structural, not a sprint count.** Agents build this product and there are no sprints or person-week estimates, so "too big for one sprint" means nothing here. An epic's size is its decomposition: **S** = 3–4 story titles, **M** = 5–7, **L** = 8–10. Over 10 means two epics. Add **+spike** when a story cannot be sized until an unknown is investigated. One story means it is not an epic; promote the story.

The hierarchy, the full sizing table, Cohn's and Patton's vocabulary, and the rules for splitting an epic into epics: `./references/hierarchy-sizing-and-splitting.md`. Read it when deciding whether something is an epic, when an epic is over 10 stories or has a component name, and before writing the decomposition.

## What Every Epic Carries

| Field | Rule |
|---|---|
| **Title** | The outcome, never a feature or component. "Front desk refills the slots of patients who aren't coming", not "Confirmation service" |
| **Outcome** | "As a result of this epic, [user class] will be able to [outcome]" |
| **Hypothesis** | "If we deliver [this], we believe [actor] will [behaviour change, from the map's impact], shown by [signal], moving [KR]". Falsifiable: the epic can **succeed** (shipped, criteria met) while the hypothesis **fails** (the behaviour did not change). That is the re-plan signal |
| **Traces to** | Selected-path deliverable (or KR, with no map) · job J-n → job story JS-n.m · UR-n it carries (TR-n for a transition epic) · KR |
| **Four-risk line** | Cagan's four risks (*Inspired*): value, usability, feasibility, viability. Each is *tested* (evidence cited), *assumed* (with the test that would settle it) or *low* (with a reason). None blank |
| **Bounded Context** | One candidate. Two or more: flag to the domain-modeler and split by outcome first (below) |
| **Epic acceptance criteria** | 3–5 high-level conditions true when the whole outcome is delivered, **each with one concrete example**. Never Given/When/Then |
| **Decomposition** | 3–10 story titles, outcome-named, in the order the user meets them |
| **Size** | S / M / L from the story count, +spike if needed |
| **Priority (provisional)** | high / medium / low (standard), value and penalty scores (enterprise). **Never Must / Should / Could / Won't**: `moscow-prioritization` finalises it, and a high epic's stories are each judged on their own (DSDM) |

Writing the hypothesis, the four-risk line and the epic acceptance criteria in full, with worked good and bad versions: `./references/hypothesis-risks-and-criteria.md`. Read it before writing the first hypothesis, whenever a risk has no evidence, and whenever criteria start to read like test steps.

**Criteria altitude is load-bearing.** Cohn's Three Cs (Card, Conversation, Confirmation, after Ron Jeffries) defer detail on purpose. Given/When/Then at epic time freezes guesses before the conversation that should shape them. But a criterion with no example is untestable: Ken Pugh (*Lean-Agile Acceptance Test-Driven Development*) holds that work is not ready without a concrete example. So each epic criterion is a plain condition plus one real-feeling example, and the Given/When/Then comes later, per story, from the example map.

## Splitting: Outcome First, Never by Layer or Service

- **An epic that is too big** splits into **epics** by outcome, by user class, by selected deliverable, by tenant or segment, or new capability vs transition. Each half must be able to succeed or fail on its own.
- **An epic that crosses Bounded Contexts** is split by outcome first. Splitting it into one epic per service or context is a layer split at a larger scale. Whatever still crosses contexts after the outcome split is **flagged to the domain-modeler**: a row in the epic list's Cross-Context Flags table naming the epic, the contexts and the question for Design (a missing context? an Anti-Corruption Layer?). The analyst flags; the domain-modeler decides contexts and service boundaries.
- **An epic becoming stories** uses `user-story-writing`'s splitting patterns (workflow step, business rule, data, paths, CRUD; SPIDR is Cohn's later material, not *User Stories Applied*). Here, list titles only. Never frontend / backend / database "stories": those are tasks.

## Producing the Artifact

1. **Check the profile** (Scale, below). At lean, write no `epics.md`.
2. **Read** the selected path (or the KR), the JTBD analysis, the FRD's URs and TRs, and the NFR architecture hand-off. Inputs the user gives in the conversation count. If a profile-required input is missing altogether, name it, write what can be traced and mark the rest TBD; never invent a trace.
3. **One candidate epic per selected software deliverable.** A non-software deliverable (a procedure, a message, training) is not an epic: list it under "Not epics". Option branches stay on the map.
4. **Assign every UR to an epic** (one epic, unless its FRs serve two outcomes: then split it by FR and say so in the coverage table) and every TR to an epic or "Not epics". A UR that fits none means a missing epic or an unmapped requirement: say which.
5. **Name** each epic by its outcome; write outcome, hypothesis (from the map's impact and signal) and traces.
6. **Write the four-risk line** from the tree's assumption tests, the map's typed assumptions and the NFR hand-off.
7. **Write 3–5 epic criteria with examples**, then the story titles; size from the count; split anything over 10.
8. **Name the Bounded Context**; flag cross-context epics.
9. **Set the provisional priority.** No MoSCoW words.
10. **Validate** against `./resources/epic-readiness-checklist.md` and run `python3 ./scripts/check-epic-list.py <artifact>`.
11. **Write** from `./templates/epic-list.md` to `ideate/epics.md` and present it before story writing.

## Scale

`phase-requirements.json`: epic list **skipped** at lean, **required** at standard and enterprise.

| Profile | Shape |
|---|---|
| **lean** | **No `epics.md`**: no impact map and no FRD either; the backlog is the requirements. When stories cluster, group them under epic headings in `ideate/user-stories.md`, each with an outcome title, one trace line (KR → actor → behaviour change, typed assumption, signal) and a provisional priority. Few stories: no epics at all, stories trace to the KR. `./examples/01-lean-toolshed.md` |
| **standard** | `ideate/epics.md`: every field above, traces to the selected path (or the KR when the map was not produced), a coverage table (deliverables, URs, TRs → epics), "Not epics", high / medium / low priority. `./examples/02-standard-rebound.md` |
| **enterprise** | Adds epics grouped by impact map (one section per product outcome) and roadmap Theme, value and penalty scores, transition epics per tenant traced to TR-n, a cross-context flag table for the domain-modeler, and a forward-trace column (stories) filled by `user-story-writing`. `./examples/03-enterprise-permitry.md` |

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **The component epic** ("API layer", "Auth service") | No user outcome, no hypothesis to test; components are built inside outcome epics |
| **The everything epic** | Its "done" is the whole product, so it can never fail informatively |
| **Hypothesis-free epic** | When it ships, nobody can say whether it worked |
| **Orphan epic** | No selected deliverable or KR behind it: unjustified scope, or a trace not recorded |
| **Option as epic** | An unselected branch on the map becomes committed scope |
| **Procedure as epic** | A non-software deliverable gets stories nobody can build |
| **MoSCoW at epic time** | Pre-empts `moscow-prioritization`, which runs last |
| **Sprint-sized epics** | This pipeline has no sprints; size by decomposition |
| **Blank risk line** | An untested value or viability risk enters delivery unseen (Cagan) |
| **Premature story detail** | Given/When/Then at epic time hardens guesses |
| **Layer-cake or per-service split** | Frontend / backend / database, or one epic per service: tasks, not outcomes |
| **Product rules as skill rules** | A compliance persona or tenant rule belongs in that product's epics, not every product's |

Use canonical terms from `glossary-management`: **Epic**, **Selected Path**, **Job Statement**, **Job Story**, **User Requirement**, **Transition Requirement**, **Provisional Priority**, **Bounded Context**, **Theme**, **Four Product Risks**. Run `methodology-review` before hand-off.
