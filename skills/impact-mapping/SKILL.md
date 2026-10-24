---
name: impact-mapping
description: >
  Teaches how to build an impact map (Gojko Adzic, Impact Mapping) in Ideate:
  a measurable goal (WHY: the opportunity solution tree's product outcome, with
  the Key Result's metric, meter, baseline, target and deadline) → the actors
  who can produce, obstruct or are affected by it (WHO, blockers included) →
  the behaviour changes wanted from them (HOW, each with an observable signal)
  → the customer opportunity that explains each gap → deliverables as options
  to test, software or not (WHAT), ending in one selected path whose
  assumptions (desirability, viability, feasibility, usability, ethical) and
  re-plan trigger are written down. Use when drawing or reviewing an impact
  map, tracing features or deliverables to a goal, choosing what to build first
  for a Key Result, cutting a backlog nobody can justify, or naming the
  assumptions behind a plan. Used by the requirements-analyst agent in Ideate
  (/sdlc-ideate) after the opportunity solution tree and before the functional
  requirements; required at enterprise, optional at standard, skipped at lean.
version: 3.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, discovery, impact-map, outcomes, actors, goal, deliverables, selected-path, assumptions]
produces: impact-map
domain: discovery
status: stable
related: [opportunity-solution-tree, okr-authoring, user-persona, jtbd-analysis, requirements-analysis, epic-definition, moscow-prioritization, story-mapping, glossary-management, methodology-review]
sources:
  - research/requirements-and-user-stories/impact-mapping-adzic.md
  - research/product-strategy-and-gtm/continuous-discovery-habits-torres.md
  - research/product-strategy-and-gtm/inspired-cagan.md
  - research/product-strategy-and-gtm/lean-product-playbook-olsen.md
  - research/human-ai-collaboration/unleash-creativity-with-ai-bier.md
---

# Impact Mapping

## Purpose

An impact map answers: **is this the right thing to build to move this goal, and what are we betting on?** Gojko Adzic (*Impact Mapping*) presents it as a planning tool for choosing what to build, not a requirements document. It is a mind map that ties delivery to a goal through the people whose behaviour has to change, so that the **assumptions** behind a plan are visible and can be tested. It cures two wastes: software delivered as specified that changes nothing, and backlogs where nobody can say why an item is there (Cagan's *feature factory*, *Inspired*).

```
WHY  Goal ─── WHO  Actor ─── HOW  Impact ─── Opportunity ─── WHAT  Deliverable (option)
(product      (produces,     (behaviour       (from the        (software or not;
 outcome)      obstructs,     change + signal)  tree: why the    droppable)
               affected)                        actor doesn't)
```

Build it from the goal outward; defend scope from the leaves inward. A deliverable that cannot trace up to a behaviour change that moves the goal is cut.

## Where It Sits

```
Ideate: personas ─► JTBD ─► opportunity solution tree ─► IMPACT MAP ─► functional requirements ─► NFRs ─► epics ─► stories … ─► story map ─► MoSCoW
```

| Reads | What it takes |
|---|---|
| `opportunity-solution-tree` | Its **desired outcome** becomes the WHY; its **target opportunity** explains why the primary actor does not already behave the HOW way; its carried-forward **solutions** (with their assumptions and tests) are WHAT candidates. Never re-generate what the tree already compared |
| `okr-authoring` | The Key Result the outcome serves: metric, meter, baseline, target, deadline. Its Initiatives enter as WHAT options, never as commitments |
| `user-persona`, `jtbd-analysis` | Actors and their current behaviour; job stories show what a behaviour change would look like |

| Feeds | What it gives |
|---|---|
| `requirements-analysis` | Functional requirements trace to **selected-path** deliverables. The map comes first so requirements are not written first and the map drawn backwards to justify them (Adzic) |
| `epic-definition` | Each selected deliverable becomes a candidate epic, its impact the epic's hypothesis |
| `story-mapping` | Selected deliverables, through epics, form the backbone. The **walking skeleton is decided on the story map, not here** |
| `moscow-prioritization` | Runs last in Ideate and finalises priority. The map does not pre-empt it: an option is not a "Could" |

## The Four Levels, Plus the Opportunity

| Level | Question | Rule |
|---|---|---|
| **WHY — Goal** | Why are we doing this? | One measurable goal per map, in fields: metric (scale), meter, baseline, target, deadline, optional constraint (Adzic, after Gilb). Copied from the tree's root and the KR; a missing field goes back to `okr-authoring`, never invented |
| **WHO — Actors** | Who can produce the effect? Who can obstruct it? Who uses the product? Who is affected by it? | Specific enough to observe. Types: primary, secondary, off-stage, **blocker**. At least one blocker, or a written reason why none exists |
| **HOW — Impacts** | How should the actor's behaviour change? | Start / stop / do more / less / faster / differently, *instead of* the current behaviour. Each has a **signal**: "we would see it in ___". Include a **prevent** impact where current behaviour harms the goal |
| **Opportunity** | Why doesn't the actor already do it? | The tree's opportunity (OPP-ID) behind the impact, in the customer's voice (Torres, *Continuous Discovery Habits*). The selected path cites the **target opportunity**; an impact with no tree opportunity says "— not on tree" and is a candidate for the next discovery cycle |
| **WHAT — Deliverables** | What could we do to cause it? | **Options, not commitments.** Software, content, process, training, policy, partnership. Ask for the cheapest non-software option first |

**The load-bearing rule: an impact is a behaviour change in an actor, never a feature.** "The clinic owner uses the reminders screen" is a deliverable restated as an impact. Adzic and Evans give the reason: deliverables sit in the team's **zone of control** (it ships them); impacts sit in its **sphere of influence** (it can make them likely, not guarantee them). If the goal can be reached with nobody outside the team changing behaviour, the "goal" is a deliverable.

The questions, actor types, impact phrasing and deliverable generation in full, with good and bad examples: `./references/impact-map-levels.md`. Read it before writing the WHO or HOW level, and whenever an impact reads like a feature.

## Generating Deliverables

An agent fills the WHAT level in one pass, anchored on the first plausible features. So, for each impact on or near the path:

1. **Start from the tree.** Under the impact the target opportunity explains, the tree's carried-forward solutions are the candidates. Do not add a fourth by habit.
2. **For other impacts**, generate two to three times as many candidates as will be kept, in **two passes**, the second under a constraint ("no new code", "one week", "the opposite of pass one") (Bier, *Unleash Your Creativity with AI*). At least one non-software option per impact (Adzic).
3. **Keep the map small**: one goal, a handful of actors, a few impacts each, deliverables detailed only under impacts the team might choose next. Deeper branches stay one-line placeholders. A map of hundreds of nodes has become a work-breakdown structure.

## The Selected Path, Not an MVP Scope

Adzic's prioritisation is **choosing one path**: the most promising actor → the impact most likely to move the goal → the cheapest deliverables likely to cause it. Every other branch stays on the map as an **option**, already traced to the goal. There is no Must/Should/Could column: that would pre-empt MoSCoW, which finalises priority at the end of Ideate.

Each map row carries three columns instead of a priority:

| Column | Holds |
|---|---|
| **Path** | `selected` or `option` |
| **Assumption** | The belief the link rests on, typed: "[desirability] if patients get a 72 h confirm request, they reply". Types: **desirability, viability, feasibility, usability** (Cagan's four risks, *Inspired*) and **ethical**: could it do harm, should it be done (Torres) |
| **Signal** | How the impact will be observed when the deliverable ships |

The **Selected Path** section then lists every assumption on the path: the deliverable → impact link and the impact → goal link, each typed, with its evidence today and its test (the tree's T-n where one exists, written with a success threshold set before it runs). At least one ethical assumption is considered on the path. Rank by importance × evidence (Bland, via Torres).

**Measure and re-plan.** The map is a living roadmap input. Write the **re-plan trigger**: if the impact signal does not move by a date, the deliverable was a wrong guess, so try the next option on the same impact; if the impact moves and the goal does not, the impact → goal assumption was wrong, so go back to the map or the tree.

Assumption typing, selecting the path, signals and the re-plan loop in full: `./references/selected-path-and-replanning.md`. Read it before writing the Selected Path section.

## Solo Adaptation: Confirm Before Deliverables

Adzic runs the map as a facilitated, timeboxed workshop with business sponsors and delivery people; the facilitator refuses deliverables until goal, actors and impacts exist. This plugin has one agent and one user, so the adaptation (this plugin's, not Adzic's) is: **draft WHY → WHO → HOW before any WHAT, and have the user confirm both the levels and the selected path.** In a working session, pause for that confirmation before writing deliverables. When the user asks for the whole map in one request, do not stop half-way: write the complete map, and mark WHY / WHO / HOW and the selected path as awaiting the user's confirmation.

## Producing the Artifact

1. **Check the profile** (Scale, below). At lean, write no map.
2. **Read** the opportunity solution tree, the OKR set, personas and JTBD analysis. If there is no tree, or the KR is a business outcome or traction metric, stop: classify it with `opportunity-solution-tree` first. If functional requirements already exist, do not map from them; that is backwards mapping.
3. **Write WHY** as fields from the tree's root and the KR.
4. **Write WHO** by asking the four questions; name at least one blocker.
5. **Write HOW** per actor with a signal and the opportunity (OPP-ID) behind it; **confirm with the user** (or, for a one-request map, mark it awaiting confirmation and carry on).
6. **Generate WHAT** (tree solutions first, then two passes elsewhere).
7. **Mark the selected path**; type its assumptions; write signals and the re-plan trigger.
8. **Validate** against `./resources/impact-map-checklist.md` and run `python3 ./scripts/check-impact-map.py <artifact>`.
9. **Write the file** from `./templates/impact-map.md` to `ideate/impact-map.md` (enterprise: `ideate/impact-maps/<outcome>.md`) and present it before the functional requirements.

## Scale

`phase-requirements.json`: **skipped** at lean, **optional** at standard, **required** at enterprise.

| Profile | Shape |
|---|---|
| **lean** | **No map.** Epics and requirements trace straight to the Key Result. The agent still applies the thinking: one trace line per epic, KR → actor → behaviour change → this epic, with its assumption and signal. If the user asks for a map at lean, say the profile skips it and offer the trace lines: `./examples/01-lean-internal-rota-tool.md` |
| **standard** | When produced: **one map** for the tree's outcome the first release serves; other KRs listed under "Not mapped this cycle": `./examples/02-standard-clinic-no-shows.md` |
| **enterprise** | **One map per product outcome in scope this cycle** (one per tree, `ideate/impact-maps/<outcome>.md`), not one per KR in the OKR set, with a **shared actor register** (the same names and persona IDs in every map; an actor described in one map is cited, not redescribed, in the next): `./examples/03-enterprise-freight-marketplace.md` |

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **Backwards mapping** | Branches drawn to justify an existing feature list or written requirements; every WHAT was already on the backlog. The map exists to challenge deliverables (Olsen calls the same failure a need that is secretly a decided feature, *The Lean Product Playbook*) |
| **Deliverable as goal** | "Ship the reminders feature" is in the team's control; a goal needs actors to behave differently |
| **Feature usage as impact** | "Uses the dashboard" names the deliverable, not the behaviour it enables |
| **Actor soup** | "The customer", "IT", "the market" have no observable behaviour |
| **No blocker** | Removing an obstacle is often the cheapest path to the goal |
| **Impact with no signal** | It cannot be checked when its deliverable ships |
| **Software only** | A process change or a message may cause the impact for a tenth of the cost |
| **A priority column** | Must/Should/Could at this step pre-empts MoSCoW; options are not "Could"s |
| **The complete-map fallacy** | Every branch treated as committed scope: a disguised work-breakdown structure |
| **Map too big** | Detail under impacts nobody will choose next |
| **Calling the path an MVP** | The walking skeleton is a story-map decision; the path is a bet to test |
| **Ignoring the tree** | Re-generating solutions the tree already compared, or an impact on the path with no opportunity behind it |
| **Product rules as skill rules** | A compliance actor required of every product belongs in an example |

Use canonical terms from `glossary-management`: **Impact Mapping**, **Impact**, **Selected Path**, **Opportunity**, **Target Opportunity**, **Desired Outcome**, **Assumption Test**, **Product Outcome**. Run `methodology-review` before hand-off.
