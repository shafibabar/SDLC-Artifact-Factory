---
name: impact-map
product: <product>
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: <yyyy-mm-dd>
summary: <one sentence, ≤ 200 chars: the goal, the selected path (actor → impact → deliverables) and what it bets on>
profile: <standard | enterprise>
goal: <metric, baseline → target, deadline>
linked-kr: <KR ID from strategy/okrs.md>
linked-tree: <ideate/opportunity-solution-tree.md | ideate/opportunity-solution-trees/<outcome>.md>
target-opportunity: <OPP-n.m from the tree>
selected-path: <actor → impact → deliverable(s), in a few words>
traces_to: strategy/okrs.md (<KR ID>); <linked-tree>; ideate/personas.md; ideate/jtbd-analysis.md
---

<!-- Copy into ideate/impact-map.md (standard) or ideate/impact-maps/<outcome-slug>.md
     (enterprise: one file per product outcome in scope this cycle) and fill. Lean: no map.
     Draft Goal, Actors and the Map's Impact column first and confirm them with the user
     before writing any deliverable (for a one-request map, write it all and mark them awaiting confirmation). Delete these comments. -->

# Impact Map — <Product>: <goal in a few words>

## Goal (WHY)

<!-- Copied field by field from the tree's desired outcome and the linked KR. Never invent a number:
     a missing field says "not set in KR" and goes back to okr-authoring. -->

| Field | Value |
|---|---|
| Metric | <what is measured> |
| Meter | <how it is measured> |
| Baseline | <value, date> |
| Target | <value> |
| Deadline | <date> |
| Constraint | <a level that must not fall, or —> |
| Linked KR | <KR ID>: "<KR as written>" |
| Source | Desired outcome of <linked-tree>; <product outcome, as classified there> |

## Actors (WHO)

<!-- Ask in order: who can produce it, who can obstruct it, who uses the product, who is affected by it.
     At least one Blocker, or a "No blocker:" line with the reason.
     Enterprise: one shared actor register across maps: the same actor names and persona IDs in every map;
     an actor already described in another map is cited ("as in impact-maps/<outcome>.md"), not redescribed. -->

| Actor | Type | Why on the map | Source |
|---|---|---|---|
| <role / persona> | Primary | <produces the effect: how> | <ideate/personas.md P-n> |
| <role> | Secondary | <supports the primary actor> | <…> |
| <role> | Blocker | <can obstruct it: by withholding what> | <…> |
| <role> | Off-stage | <affected / decides, but does not use the product> | <…> |

## Map

<!-- Impact: [actor] starts / stops / does more / less / faster / differently [behaviour] instead of [current behaviour].
     Opportunity: the tree's OPP-ID behind the impact; the selected path cites the target opportunity; otherwise "— not on tree (<reason>)".
     Deliverable: an option, marked (software) or (non-software). Under the target opportunity's impact, the tree's carried-forward solutions.
     Elsewhere: two passes, the second under a constraint; at least one non-software option.
     Path: selected | option. No Must/Should/Could column: MoSCoW finalises priority later.
     Assumption: "[type] if …, then …", type = desirability | viability | feasibility | usability | ethical.
     Signal: "we would see it in …", a measurable behaviour of the actor. -->

### Actor: <name> — Primary

| Impact (HOW: behaviour change) | Opportunity (tree) | Deliverable (WHAT: option) | Path | Assumption | Signal |
|---|---|---|---|---|---|
| <behaviour> instead of <current> | <OPP-n.m> "<customer's voice>" | <SOL-n from the tree> (software) | selected | [desirability] <if …, then …> | <we would see it in …> |
| | | <SOL-n> (non-software) | selected | [viability] <…> | <same signal> |
| | | <other option> (software) | option | [feasibility] <…> | <same signal> |
| <prevent impact: stops …> | — not on tree (<reason>) | <option> | option | [usability] <…> | <…> |

### Actor: <name> — Blocker

| Impact (HOW: behaviour change) | Opportunity (tree) | Deliverable (WHAT: option) | Path | Assumption | Signal |
|---|---|---|---|---|---|
| <removes the obstruction: …> instead of <…> | — not on tree (<reason>) | <cheapest unblocking option> (non-software) | <selected / option> | [<type>] <…> | <…> |

### Actor: <next actor> — <Secondary | Off-stage>

<!-- repeat; keep the map small: detail only where the next choice is, one-line placeholders elsewhere -->

## Selected Path

**<Actor> → <impact> → <OPP-n.m> → <deliverables>.** <One or two sentences: why this path, from the tree's comparison and the map. Confirmed by the user on <date>.>

| ID | Link | Assumption | Type | Evidence today | Test |
|---|---|---|---|---|---|
| PA-1 | <deliverable> → <impact> | <if …, then …> | desirability | <none / snapshot ref> | <T-n in the tree / new: criterion set before it runs> |
| PA-2 | <deliverable> → <impact> | <…> | ethical | none | <…> |
| PA-3 | <impact> → goal | <if the behaviour changes, the metric moves because …> | viability | <…> | <…> |

<!-- Order by importance × evidence; at least one ethical assumption considered.
     Results go in ideate/assumption-tests/<yyyy-mm-dd>-<slug>.md, never into this file. -->

## Re-plan Trigger

- **Deliverable guess wrong:** if <impact signal> has not reached <level> by <date>, try <next option> under the same impact.
- **Impact → goal link wrong:** if <impact signal> moves but <goal metric> has not moved by <date>, return to this map (<other actor or impact>) or to the tree.

## Not Mapped This Cycle

<!-- Standard: other KRs or outcomes not mapped, one line each. Enterprise: the other maps in ideate/impact-maps/. -->

- <KR ID / outcome>: <why not this cycle>

## Hand-off

- `requirements-analysis`: functional requirements trace to <selected deliverables>.
- `epic-definition`: candidate epics <deliverable → epic>, each with its impact as hypothesis and signal as success measure.
- `story-mapping`: the epics form the backbone; the walking skeleton is decided there. Options stay off the story map.
- `moscow-prioritization`: finalises priority on the resulting stories.
- Next discovery cycle: <impacts "not on tree", failed assumptions, open options>.

## Version Log

| Version | Date | Change | Trigger |
|---|---|---|---|
| 1.0.0 | <date> | First map | Ideate, cycle <n> |
