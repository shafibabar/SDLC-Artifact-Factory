---
name: impact-mapping
description: >
  Teaches the requirements-analyst to build an Impact Map (Gojko Adzic) — the
  four-level structure Why (Goal) -> Who (Actors) -> How (Impacts, the behavior
  changes in actors) -> What (Deliverables) — which keeps deliverables traceable
  to a measurable goal and prevents building features nobody needs. Used during
  Strategy/Ideate to connect an OKR goal to the specific actor behavior changes
  and only then to candidate deliverables.
version: 2.0.0
phase: strategy
owner: requirements-analyst
created: 2026-06-24
tags: [strategy, requirements, impact-map, outcomes, actors, goal, deliverables]
produces: impact-map
domain: discovery
status: stable
related: [okr-authoring, user-persona, jtbd-analysis, epic-definition, moscow-prioritization, story-mapping]
---

# Impact Mapping

## What an Impact Map is for

An Impact Map (Gojko Adzic) answers one question: **why are we building this, and
is this the right thing to build to move a measurable goal?** It is a four-level
tree that forces every candidate feature to earn its place by tracing up to a
behavior change in a real actor that advances a goal — or be dropped.

The map exists to fight the **feature factory** (Cagan): a team that ships
continuously but rarely moves the metric that matters, because it works forward
from a pre-decided feature list instead of backward from a goal. The impact map's
whole discipline is **outcome over output** — a deliverable is worthless unless it
causes an actor behavior change (an outcome); shipping the feature (output) is not
the win.

## The four levels

Read top-down, each level answering a question about the level above:

| Level | Question | Holds | One-line definition |
|---|---|---|---|
| **WHY — Goal** | Why are we doing this? | The measurable business goal | The outcome we want, stated as a metric — sourced from an OKR Key Result |
| **WHO — Actors** | Who can cause or block the goal? | People/groups with observable behavior | Specific actors (Data Steward, Compliance Officer), including blockers |
| **HOW — Impacts** | How should the actor's behavior change? | Behavior changes in those actors | The **outcome** — what an actor starts, stops, or does differently |
| **WHAT — Deliverables** | What could we build to cause that? | Candidate features/content/config | **Hypotheses** that might cause the impact — droppable if they don't |

The load-bearing rule: **the HOW/Impacts level is a change in an actor's behavior — an
outcome — not a feature.** "Maya briefs the CISO from live data instead of a stale
spreadsheet" is an impact. "Maya uses the report feature" is a feature restated as
an impact, and is a defect. If achieving the goal requires no one outside the team
to change behavior, the "goal" is really a deliverable.

Full depth on each level — the exact questions to ask, primary/secondary/off-stage/
blocker actor types, and how to phrase impacts as behavior — is in
`references/impact-map-levels.md`.

## From OKR goal down to droppable deliverables

The map is a **chain of traceability from a single OKR Key Result to candidate
deliverables**, and it reads in both directions:

- **Top-down (building the map):** take one Key Result as the WHY goal → list the
  actors who can cause or block it → for each, name the behavior change (impact)
  that would move the goal → only then brainstorm deliverables that might cause each
  impact. Never start at WHAT.
- **Bottom-up (defending scope):** every deliverable must trace up through an impact
  to the goal. A deliverable that traces to no impact — or to an impact that doesn't
  move the goal — is waste and is cut.

Each Key Result becomes **its own impact map**. Deliverables are candidates, not
commitments: more than one can serve an impact, and the map's job is to find the
**smallest set that reliably causes the priority behavior changes** — that set is the
MVP scope. Everything else stays on the map, already traced to the goal, as a cheaply
prioritized backlog. The mechanics of pruning — why deliverables are droppable
hypotheses and how to select the minimum set — are in `references/impact-map-levels.md`.

## How the map connects to the rest of Ideate

The impact map is a hub artifact. It consumes goals and actors from upstream skills
and hands deliverables downstream:

| Skill | Relationship |
|---|---|
| `okr-authoring` | Each OKR Key Result becomes a WHY goal (one map per KR) |
| `user-persona` | Personas populate the WHO actors, including blockers |
| `jtbd-analysis` | Validated job stories identify the HOW behavior changes for primary actors |
| `epic-definition` | Selected WHAT deliverables become epics |
| `moscow-prioritization` | Must/Should/Could binning of WHAT deliverables uses the map as the forcing function |
| `story-mapping` | WHAT deliverables map onto story-map activities and release slices |

A worked, end-to-end example for this repo's product — an OKR goal → Data Steward and
Compliance Officer actors → the behavior changes wanted → candidate deliverables, and
how it feeds story-mapping and OKRs — is in `references/impact-map-example.md`.

## Quality criteria

| Criterion | Pass | Fail |
|---|---|---|
| Measurable goal | WHY goal has a numeric target or binary condition | "Improve user experience" |
| Goal-OKR link | WHY goal traces to a Key Result | Goal not in the OKR set |
| Behavior, not activity | HOW impacts are behavior changes | "Users use the feature" |
| Blocking actors | At least one blocking actor identified and addressed | Only supporters, no blockers |
| Deliverable minimalism | Deliverables are candidates; a minimum set is selected | Every deliverable treated as required |
| MVP cut made | A minimum deliverable set is explicitly marked as MVP | Full map delivered with no scope cut |

## Anti-patterns

**Backwards mapping.** Starting from an existing feature list and drawing goal → actor
→ impact branches to justify it. The tell: every WHAT was already on the backlog. The
map exists to *challenge* deliverables, not launder them. (This is the same failure
mode Olsen's problem-space/solution-space discipline catches: a "need" that is secretly
a decided feature.)

**Deliverable as goal.** "GOAL: ship the compliance dashboard." Shipping is under your
control; a goal must be an outcome that actors' behavior produces.

**Actor soup.** "The customer", "IT", "the market" as actors. An actor must be specific
enough to have *observable behavior* — the Data Steward can connect a storage source;
"the customer" cannot do anything observable.

**Feature usage as impact.** "Maya uses the report feature" restates a deliverable as an
impact. The impact is the behavior the feature enables, not the using of it.

**The complete-map fallacy.** Treating every branch as committed scope. The map is a menu
traced to the goal; the MVP cut selects the cheapest path through it. A map with no cut has
skipped its entire purpose as a prioritization tool.

## Output Format

```markdown
---
name: impact-map
product: [product name]
version: 1.0.0
phase: strategy
created: [date]
owner: requirements-analyst
linked-kr: [OKR Key Result ID]
---

# Impact Map: [Goal statement]

## Goal (WHY)
[Measurable goal statement with metric — sourced from linked-kr]

## Map

### Actor: [Name / Role]  — [Primary / Secondary / Off-stage / Blocker]

| Impact (HOW — behavior change) | Deliverable (WHAT — candidate) | Priority |
|---|---|---|
| [Behavior change] | [Feature/content/config] | Must / Should / Could / Won't |

### Actor: [next actor]
[repeat]

---

## MVP Scope
[The WHAT deliverables selected as the minimum set, each with the impact it causes]

## Deferred Deliverables
[Valid WHAT items not in MVP — each traced to the impact it would address]
```
