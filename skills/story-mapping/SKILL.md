---
name: story-mapping
description: >
  Teaches the requirements-analyst to build a User Story Map (Patton) — the
  horizontal backbone of user activities/steps in narrative flow, the vertical
  stories under each step ordered by priority/necessity, the walking skeleton
  (the thinnest end-to-end slice), and release slicing by outcome rather than by
  component. Match when the prompt involves a story map, narrative backbone,
  walking skeleton, MVP slice, release slicing, cutting a horizontal slice,
  sequencing epics/stories into releases, seeing the whole product journey at a
  glance, or turning a flat backlog into a two-dimensional view during Ideate.
version: 2.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
related: [epic-definition, user-story-writing, user-persona, moscow-prioritization, impact-mapping, roadmap-authoring, acceptance-criteria]
tags: [ideate, requirements, story-map, backbone, walking-skeleton, release-slicing, patton]
---

# Story Mapping

## Purpose

A story map (Jeff Patton, *User Story Mapping*) arranges user stories in two
dimensions to make visible what a flat backlog hides: the user's end-to-end
journey. It answers **how do all these stories fit together into a coherent user
experience, and where do we cut a first release?**

Patton's central thesis: **the map is a conversation, not an artifact.** The
value is the shared understanding a cross-functional team builds *while* mapping
— not the diagram it leaves behind. A map produced solo and handed over as a
document has captured a picture, not the understanding that matters. In this
repo's single-agent-then-Shafi-approves workflow that live session cannot happen
literally; the deliberate adaptation is to **narrate the spine aloud with Shafi**
before the map is treated as final (see `references/map-structure-and-backbone.md`).

## The Two Axes

A story map is sorted by **time** (horizontal) and **priority/necessity**
(vertical) — not by flat priority.

```
BACKBONE  →  user activities & tasks, left-to-right in narrative order
              ("first the user does X, then Y, then Z")
   │
   ▼ under each backbone step
BODY      ↓  the stories for that step, top-to-bottom by necessity
              (top = needed for the story to be minimally whole; below = refinements)
```

- **Backbone** = the narrative spine. Big-picture *activities* decompose into
  *tasks* — the level of "Connect Google Drive", "Trigger a scan", not a UI click.
  Read left-to-right it must narrate as a coherent user story.
- **Body** = the stories under each backbone step, ordered vertically by what the
  step needs to be *minimally whole*, not by arbitrary priority. Deeper rows are
  enhancements, additional personas, and edge cases.

Backbone-vs-body detail, facilitation steps, and the "backlog turned sideways"
failure live in `references/map-structure-and-backbone.md`.

## The Walking Skeleton

The **walking skeleton** (Patton credits Alistair Cockburn) is the top row read
across the *entire* backbone: the thinnest possible slice that actually **works
end-to-end**, however ugly — not "the minimum viable stuff", but one complete
functioning path through the whole journey. If any activity's top row is missing
or non-functional, the skeleton is *broken*, not merely incomplete.

This is more precise than "MVP slice": the boundary is defined by end-to-end
function, not by a wish-list cut. Definition, the end-to-end test, and a full
worked Data Steward estate-review skeleton are in
`references/slicing-and-walking-skeleton.md`.

## Slice by Outcome, Not by Layer

Below the walking skeleton, horizontal cuts mark **releases**. Each slice must
itself be end-to-end viable — it must deliver a user *outcome*, not a completed
component.

- **Correct:** a thin horizontal slice crossing *every* backbone step, so the
  user can complete the whole journey (connect → scan → review), just with fewer
  options.
- **Wrong (the vertical-slice MVP):** finishing one activity completely ("all
  four connectors, perfectly") while later steps are "next quarter" — the user
  connects flawlessly and then hits a wall.

A release slice is **not** the same as a MoSCoW "Must" cut: a slice must be
end-to-end viable, not merely the collection of Must-Haves. Release-slicing
mechanics and how a slice maps to an MVP are in
`references/slicing-and-walking-skeleton.md`.

## Two Kinds of MVP — Do Not Conflate

Patton keeps these separate, and so must this skill:

| Kind | What it is | In this repo |
|---|---|---|
| **Release-MVP** | The walking skeleton — smallest thing you can actually *ship* | What a story map's MVP slice describes |
| **Learning-MVP** | Cheapest thing to *test a belief* (fake door, concierge, throwaway prototype) | Belongs upstream with `impact-mapping` / JTBD, not on the map |

A story map produces a release-MVP. Never let a validated-learning experiment be
treated as shippable, or demand production rigor from a learning experiment.

## When to Use

| Use story mapping when | Do not reach for it when |
|---|---|
| Stories and epics exist and need sequencing into a coherent first release | No stories yet — do `user-story-writing` / `epic-definition` first |
| You need to see the whole product journey at a glance | You only need to rank a flat list — use `moscow-prioritization` |
| You must choose *what ships together* to give a user a complete outcome | You're framing *why* to build — use `impact-mapping` / JTBD |

## Connection to Other Skills

| Connects to | How |
|---|---|
| `epic-definition` | Backbone tasks are the pre-decomposition form of an epic |
| `user-story-writing` | Body stories are INVEST-compliant written stories |
| `user-persona` | The backbone is walked from the primary persona's viewpoint |
| `moscow-prioritization` | MoSCoW informs vertical placement, but a slice ≠ a Must cut |
| `impact-mapping` | Impact-map WHAT deliverables seed backbone activities |
| `roadmap-authoring` | Release slices seed Now/Next/Later horizons directly |

## Anti-Patterns

- **The pasted backlog** — columns filled from the flat backlog in priority
  order with no necessity gradient. A backlog turned sideways is not a map.
- **The vertical-slice MVP** — completing one activity instead of cutting a thin
  horizontal slice across every backbone step (see above).
- **The system-perspective spine** — "Ingest → Process → Store → Serve" is the
  pipeline's journey, not the user's. Narrate what the *persona* does.
- **Orphan stories** — stories in the backlog appearing nowhere on the map.
- **The frozen map** — built once, never re-cut. After a slice ships, run a
  learning checkpoint and be willing to re-cut later slices.

## References & Output

- `references/map-structure-and-backbone.md` — backbone vs. body, narrative
  flow, facilitation, common mistakes, and the map gap-reading checklist.
- `references/slicing-and-walking-skeleton.md` — walking skeleton, outcome-based
  release slicing, slice-to-MVP mapping, the full Data Steward worked map, the
  Quality Criteria table, and the copyable `## Output Format` template.
