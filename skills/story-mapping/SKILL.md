---
name: story-mapping
description: >
  Teaches how to build the user story map in Ideate (Patton): a backbone of
  user activities in the order the primary persona meets them, seeded only
  from the impact map's selected-path deliverables through the epics; the
  stories under each step ordered by necessity; the walking skeleton, the
  thinnest slice that works end to end and is the release's Must set (DSDM's
  Minimum Usable SubseT, checked both ways with MoSCoW); and release slices
  cut by outcome, never by component or service. Use when building or
  reviewing a story map, narrating the backbone, finding the walking skeleton
  or the MVP, cutting release slices, rejecting a vertical-slice MVP or a
  system-pipeline backbone, telling a release MVP from a learning MVP (fake
  door, concierge test), finding gaps or orphan stories, or re-cutting slices
  after a release. Used by the requirements-analyst agent in Ideate
  (/sdlc-ideate) after the stories, example maps and acceptance criteria and
  before MoSCoW; required at standard and enterprise, optional at lean, where
  the walking skeleton is the backlog's Must / Won't-this-time block.
version: 3.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, requirements, story-map, backbone, walking-skeleton, release-slicing, minimum-usable-subset, patton]
produces: user-story-map
domain: discovery
status: stable
related: [epic-definition, user-story-writing, user-persona, acceptance-criteria, moscow-prioritization, impact-mapping, opportunity-solution-tree, okr-authoring, roadmap-authoring, glossary-management, methodology-review]
sources:
  - research/requirements-and-user-stories/user-story-mapping-patton-economy.md
  - research/requirements-and-user-stories/dsdm-agile-project-framework.md
  - research/product-strategy-and-gtm/inspired-cagan.md
---

# Story Mapping

## Purpose

The story map answers: **how do the stories fit together into one journey the user can complete, and what is the smallest release that lets them complete it?** Jeff Patton (*User Story Mapping*, with Peter Economy) lays stories out in two dimensions because a flat backlog hides the journey: sorted by priority, it invites finishing one feature perfectly while the user still cannot get from start to finish.

Patton's central claim is that **the map is a conversation, not an artifact**: its value is the shared understanding built while mapping. This plugin cannot run his live whole-team session, so it makes two named adaptations. (1) The agent **narrates the backbone aloud with the user** before the map is final, a step distinct from the ordinary "present and approve". (2) Patton generates stories *from* the map; here the stories already exist (written from the epics), so the map rearranges them and **reveals gaps**, and each gap goes back to `user-story-writing` as a proposed story the user approves.

## Where It Sits

```
Ideate: … impact map ─► FRD ─► NFRs ─► epics ─► stories ─► example maps ─► acceptance criteria ─► STORY MAP ─► MoSCoW
```

| Reads | What it takes |
|---|---|
| `epic-definition` | Epics (backbone candidates) with story titles in narrative order, provisional priority and size. At lean: epic headings in `ideate/user-stories.md`, or none |
| `impact-mapping` | The **selected path** only: its deliverables, through the epics, seed the backbone. Option branches never appear on the map. The impact's signal and re-plan trigger become the learning checkpoint |
| `user-story-writing`, `acceptance-criteria` | The stories (US-n) placed in the body |
| `user-persona` | The primary persona whose journey the backbone narrates; other personas where they act |
| `okr-authoring` | The Key Result the walking skeleton should start moving (at lean, the trace with no map) |

| Feeds | What it gives |
|---|---|
| `moscow-prioritization` | The walking skeleton as the Must set, for the two-way check |
| `roadmap-authoring` | Release slices: the first concrete test of the roadmap's Now horizon, and a named roadmap revision trigger |
| `user-story-writing` | Gap stories and orphan challenges, for the user to approve |

## The Two Axes

- **Backbone (left to right, time):** **activities** the persona does, in the order they do them, each decomposed into **tasks** at the grain of a user goal ("connect a source", "offer a freed slot"), never a UI click and never a system stage. Read aloud, it must narrate as a story: "first the front desk…, then the patient…, then…". Several personas share **one** backbone, each named on the activity where they act.
- **Body (top to bottom, necessity):** under each activity, the stories ordered by what makes the step **minimally whole**: the top story makes the step work at all; lower rows add options, personas, edge cases. Not a priority number and not depth of detail. If every row looks equally important, the body has been dumped, not ordered.

**Backbone seeding.** Each epic usually becomes one backbone task. Narrative order beats epic grouping: when an epic's stories happen at different points of the journey, each story goes to its step and keeps its epic tag. A story about a rule that protects a step (tenant isolation, access) sits at the step where the user meets it. Only selected-path deliverables reach the map, and a transition epic sits where the user meets the change.

Backbone vs body in depth, facilitation order, the narration step, multi-persona backbones and gap reading: `./references/map-structure-and-backbone.md`. Read it before laying the backbone, and whenever the spine does not narrate or more than one persona acts.

## The Walking Skeleton Is the Must Set

The **walking skeleton** (Patton credits Alistair Cockburn) is the top row read across the **whole** backbone: the thinnest slice that **works end to end**, however ugly. It is the first release slice and the **release-MVP**. If any activity has no functioning top-row cell, the skeleton is **broken**, not merely thin. A cell may be met by an existing capability or a named manual step ("front desk phones the waitlist"), because ugly still walks. It may never be blank.

**Must = Minimum Usable SubseT = walking skeleton (D045).** The DSDM Agile Project Framework expands MUST as the *Minimum Usable SubseT*: the guaranteed set that together gives a usable solution. "Usable" means end to end, which is the skeleton's own test. So the check runs **both ways**:

1. **Every skeleton story is a Must.** If MoSCoW finds a workaround for one (DSDM's rule: any workaround, even manual, means not a Must), that story moves down to a later slice and the workaround becomes a named manual cell. The skeleton must still walk.
2. **Every Must sits on the skeleton.** A Must off the skeleton is either not a Must (demote it) or a **legal, safety or regulatory Must**, which is **added to the skeleton** at the step it protects and marked with its rule. Never leave a gap between the two lists.

A pile of Musts with a hole in the journey is not a slice, and it is not a Minimum *Usable* SubseT either. The map proposes the skeleton; `moscow-prioritization` confirms it at release level (at lean, the backlog's Must / Won't-this-time block). Slices below the skeleton are not Musts of this release: they get their own MoSCoW when their release comes (DSDM prioritises per release).

## Slice by Outcome, Never by Layer

Below the skeleton, horizontal cuts mark **release slices**. Each slice, added to those above it, leaves the journey complete for the users it targets and names the **outcome** it adds ("paper-diary clinics join", "council B goes live"). A slice may leave a column empty where nothing changes.

- **Right:** a thin cut across every activity: connect one source → scan it → see the gaps → set one policy.
- **Wrong, the vertical-slice MVP:** finishing one activity ("all four connectors, perfectly", "onboard every tenant completely") while later steps wait. The user does step one flawlessly, then hits a wall.
- **Wrong, the component or service slice:** "the API first", "the tenant service release". No user can complete anything.

Each slice carries a **learning checkpoint**: the signal to read after it ships (the impact map's signal) and what would re-cut later slices (the map's re-plan trigger). Slices are re-cut on evidence, and the map is kept in agreement with the backlog. Skeleton tests, slice rules, the two-way Must check worked through, and re-cutting: `./references/slicing-and-walking-skeleton.md`. Read it before cutting any slice and whenever Musts and the skeleton disagree.

## Release MVP vs Learning MVP

| | Release-MVP | Learning-MVP |
|---|---|---|
| Is | The walking skeleton: smallest thing real users can complete the journey with | Cheapest way to test a belief: fake door, concierge or Wizard-of-Oz test, a prototype |
| Lives | On this map | Upstream: assumption tests on the `opportunity-solution-tree`, typed assumptions on the impact map |
| Rigour | Production quality, minimal scope | Throwaway by design |

Patton keeps the two apart, and Marty Cagan (*Inspired*) places prototypes in discovery, before delivery is committed. A fake-door test is never a release slice, and a skeleton is never "just a prototype".

## Producing the Artifact

1. **Check the profile** (Scale, below).
2. **Read** the epics (or lean epic headings), the stories, the selected path (or KR), the personas.
3. **Lay the backbone** from the primary persona's journey: activities, then tasks. No stories yet.
4. **Narrate the spine with the user** and fix the order before going deeper.
5. **Place every story** under its step, ordered by necessity. Any step with nothing under it is a gap: propose the missing story.
6. **Read for gaps and orphans**; a story that fits no step is challenged.
7. **Cut the walking skeleton**; run the end-to-end test and the two-way Must check.
8. **Cut release slices** by outcome, each with its learning checkpoint.
9. **Validate** against `./resources/story-map-checklist.md` and run `python3 ./scripts/check-story-map.py <map> [--backlog ideate/user-stories.md] [--musts <file>]`.
10. **Write** from `./templates/story-map.md` to `ideate/story-map.md`; note the roadmap revision trigger.

## Scale

`phase-requirements.json`: story map **optional** at lean, **required** at standard and enterprise.

| Profile | Shape |
|---|---|
| **lean** | **No `story-map.md` by default.** Narrate the spine and write the skeleton as the backlog's closing **Must / Won't-this-time block** in `ideate/user-stories.md`: one line of spine, the skeleton stories (one per journey step), the Won'ts with a reason. Write a one-page map only when the user asks: backbone, skeleton row, one "Later" row. `./examples/01-lean-toolshed.md` |
| **standard** | `ideate/story-map.md`: big picture traced to the KR and selected path, narrated spine, the map, skeleton plus at least Release 2, release definitions with outcome and learning checkpoint, the two-way Must check, gaps and orphans. `./examples/02-standard-rebound.md` |
| **enterprise** | Adds one backbone for several personas (named per activity), a skeleton that crosses tenant set-up for **one** tenant, regulatory Musts added to the skeleton and marked, per-tenant or per-segment slices, epics from more than one impact map, NFR hand-off items noted against skeleton stories, and a re-cut log. `./examples/03-enterprise-permitry.md` |

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **Backlog turned sideways** | Columns in priority order, no necessity gradient: not a map |
| **System-perspective spine** ("Ingest → Process → Store → Serve") | The pipeline's journey, not the persona's; it can never show where a user gets stuck |
| **Vertical-slice MVP** | One activity perfect, the journey unwalkable |
| **Musts that are not the skeleton** | A Must off the map, or a skeleton story ranked Should: the release is either not usable or not guaranteed |
| **Option branches on the map** | Unselected impact-map options become scope |
| **Learning MVP as a release** | A fake door shipped, or production rigour demanded of an experiment |
| **Blank skeleton cell** | The skeleton does not walk; name the manual step or write the story |
| **Orphan stories** | Built work no journey needs |
| **The frozen map** | Never re-cut after a release; trusted and wrong |
| **Product rules as skill rules** | A compliance persona or tenant rule belongs in that product's map, not every product's |

Use canonical terms from `glossary-management`: **Backbone**, **Walking Skeleton**, **Release Slice**, **Minimum Usable SubseT**, **Selected Path**, **Epic**, **Provisional Priority**. MoSCoW is DSDM's, INVEST is Bill Wake's via Mike Cohn, and the "skateboard → car" sketch is Henrik Kniberg's: none is Patton's. Run `methodology-review` before hand-off.
