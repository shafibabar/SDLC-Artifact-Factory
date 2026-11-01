---
name: story-map
product: <product>
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: <yyyy-mm-dd>
summary: <one sentence, ≤ 200 chars: whose journey, the walking skeleton's outcome, and how many release slices>
profile: <lean | standard | enterprise>
status: <draft | approved>
primary-persona: <P-n name>
linked-kr: <KR ID(s) from strategy/okrs.md>
linked-impact-map: <ideate/impact-map.md | ideate/impact-maps/<outcome>.md, … | none>
linked-epics: <ideate/epics.md | ideate/user-stories.md (lean epic headings)>
traces_to: strategy/okrs.md (<KR>); <linked-impact-map> (selected path); <linked-epics> (<EPIC-n>); ideate/user-stories.md (<US-n…>)
---

<!-- Copy into ideate/story-map.md and fill. Lean (only when the user asks for a map):
     keep Narrated Spine and Story Map (activity, tasks, skeleton, Later) and drop the rest;
     the Must / Won't-this-time block in ideate/user-stories.md carries the skeleton list.
     Delete these comments. -->

# User Story Map — <Product>

## Big Picture

- **Outcome:** <KR-n.m and its target>
- **Selected path:** <actor → impact → deliverables (SOL-n), from the impact map; "none: traced to the KR" when there is no map>
- **Primary persona:** <P-n>; also acting: <P-m (where)>
- **Not on this map:** <option branches and non-software deliverables, with where they live>

## Narrated Spine

<"First <persona> …, then …, then …" — the backbone read as one story.>

**Narrated with the user on <date>:** <what changed: a step added, the order fixed, or "no change">

## Story Map

<!-- Columns are activities in journey order. Skeleton cells are never blank: a story,
     several stories, "(existing: …)" or "(manual: …)". Mark regulatory additions. -->

| | <Activity 1 (persona)> | <Activity 2 (persona)> | <Activity 3 (persona)> | <Activity 4 (persona)> |
|---|---|---|---|---|
| **Tasks** | <task; task> | <task> | <task> | <task> |
| **Walking skeleton (Release 1)** | <US-n> | <US-n> | <(manual: …)> | <US-n> |
| **Release 2 — <outcome>** | <US-n> | — | <US-n> | <US-n> |
| **Later** | <US-n> | <US-n> | — | — |

Epic tags: <EPIC-1: US-…; EPIC-2: US-…>

## Release Slices

The first slice is the first concrete test of the roadmap's Now horizon; this map's arrival is a roadmap revision trigger (`roadmap-authoring`).

### Release 1 — Walking Skeleton

**Outcome:** <what the primary persona can now complete, start to finish>
**Stories:** <US-n, …> · manual steps: <…>
**Walks end to end:** <the top row read as one sentence>
**MVP kind:** Release-MVP (ships to real users), not a learning experiment
**Signal:** <from the impact map's selected path, or the KR>
**Re-cut trigger:** <from the impact map's re-plan trigger: the result that would reshape later slices>

### Release 2 — <outcome>

**Outcome:** <what it adds, for whom; still end to end with Release 1>
**Stories:** <US-n, …>
**Signal:** <…>
**Re-cut trigger:** <…>

## Must Check (walking skeleton = Minimum Usable SubseT)

Proposed for `moscow-prioritization`, which confirms it at release level. Priorities shown are provisional.

| Story | Activity | On skeleton? | Provisional priority | Must for Release 1? | Note |
|---|---|---|---|---|---|
| <US-n> | <activity> | yes | <high> | yes | <> |
| <US-n> | <activity> | no | <high> | no | <workaround: … — or "regulatory: added to skeleton (rule)"> |

- **Skeleton → Must:** <every skeleton story is a Must; any moved down because of a workaround, and the manual cell that replaced it>
- **Must → skeleton:** <no Must off the skeleton; any legal, safety or regulatory Must added, with its rule>

## Gaps, Orphans and Open Questions

| Item | Kind | Proposed action |
|---|---|---|
| <step with no story> | Gap | <proposed story for user-story-writing, awaiting the user> |
| <US-n> | Orphan | <place it, or challenge it> |

<!-- Enterprise adds:
## NFR Hand-off on the Skeleton
| Story | NFR | Why it matters for Release 1 |

## Re-cut Log
| Date | What moved | Why (signal or trigger) | -->
