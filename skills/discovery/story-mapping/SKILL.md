---
name: story-mapping
description: >
  Teaches how to build a User Story Map (Jeff Patton) — a two-dimensional backlog
  view that arranges user activities horizontally (the narrative spine) and
  decomposed stories vertically by depth of detail. Story mapping reveals the user
  journey, identifies MVP by horizontal slice, and prevents building features in
  isolation without regard to the user's end-to-end experience. Used by the
  requirements-analyst agent during the Ideate phase after user stories and epics
  are defined.
version: 1.0.0
phase: ideate
owner: requirements-analyst
tags: [ideate, story-mapping, user-journey, mvp, backlog, product-discovery]
---

# Story Mapping

## Purpose

A story map (Jeff Patton, *User Story Mapping*) is a two-dimensional arrangement of user stories that makes visible what a flat backlog hides: the user's end-to-end journey. It answers the question: **how do all these stories fit together into a coherent user experience?**

A flat backlog is sorted by priority. A story map is sorted by time (user journey) and depth (level of detail). This makes it possible to:
- See the whole product journey at a glance
- Identify which stories must work together to enable any user outcome
- Define a minimum viable slice by cutting horizontally across the map
- Spot gaps in the journey where a user would get stuck

---

## Story Map Structure

A story map has three levels:

```
LEVEL 1 — ACTIVITIES (horizontal — the narrative spine)
Broad user activities that describe the high-level steps of the user journey.
These are the categories — not stories, not tasks.

       ↓ decompose ↓

LEVEL 2 — TASKS / EPICS
The main things users do within each activity. These map to epics.
Walking through these left-to-right tells the user's story.

       ↓ decompose ↓

LEVEL 3 — STORIES (vertical — depth of detail)
Individual user stories under each task, arranged top-to-bottom
by depth: the top row is the backbone (minimum viable); deeper
rows are enhancements and edge cases.
```

---

## Story Map Example (Data Estate Mapping Product)

```
─── ACTIVITY ──────────────────────────────────────────────────────────────────
  Connect Sources   │  Scan & Classify  │  Review & Report  │  Manage & Govern
─── TASKS ─────────────────────────────────────────────────────────────────────
  Connect           │  Trigger initial  │  View compliance  │  Set retention
  Google Drive      │  scan             │  gap report       │  policies

  Connect           │  Monitor scan     │  Export gap       │  Manage user
  AWS S3            │  progress         │  report           │  access

  Connect           │  View scan        │  Schedule         │  Configure
  SharePoint        │  results summary  │  recurring scan   │  data residency

─── MVP SLICE (horizontal cut) ────────────────────────────────────────────────
  [US-001]          │  [US-005]         │  [US-009]         │  ← above this line
  Connect Google    │  Trigger initial  │  View gap report  │  = MVP
  Drive             │  scan             │
─── RELEASE 2 ─────────────────────────────────────────────────────────────────
  [US-002]          │  [US-006]         │  [US-010]         │  [US-013]
  Connect S3        │  Monitor progress │  Export report    │  Set retention
─── RELEASE 3 ─────────────────────────────────────────────────────────────────
  [US-003]          │  [US-007]         │  [US-011]         │  [US-014]
  Connect           │  Scan results     │  Schedule scans   │  User access
  SharePoint        │  summary          │                   │  management
```

---

## How to Build the Map

### Step 1: Define the Narrative Spine (Activities)

Walk through the product from the user's perspective:
- "First, the user does X..."
- "Then, the user does Y..."
- "Then, the user does Z..."

These high-level activities become the horizontal columns. For a data estate product: Connect Sources → Scan & Classify → Review & Report → Manage & Govern.

The spine must be sequential (left to right = order the user encounters them), but loops and branches are allowed. Mark them with an annotation.

### Step 2: Decompose to Tasks

Under each activity, list the specific tasks the user performs. These should map to epics defined earlier. Tasks are at the level of "Connect Google Drive", "Trigger a scan", "View the gap report" — not at the level of a UI interaction.

Walk the spine again: "To [Activity 1], the user does [Task 1.1], [Task 1.2]... To [Activity 2], the user does [Task 2.1]..." If the story sounds natural and sequential, the spine is correct.

### Step 3: Place Stories

Under each task, place all the user stories that belong to it. Arrange them top-to-bottom by depth of value:
- Top row: the minimum story that makes the task workable at all
- Middle rows: improvements and additional personas
- Bottom rows: edge cases, configuration options, and nice-to-haves

### Step 4: Define the MVP Slice

Draw a horizontal line across the map at the level that represents the minimum viable product. Everything above the line must be built for the MVP. Everything below is future.

The MVP slice must enable the user to complete the full journey from left to right without getting stuck. A user who hits a gap in the spine — an activity they cannot complete — has not experienced a product; they've experienced an incomplete prototype.

### Step 5: Define Releases

Draw additional horizontal lines to mark release boundaries. Each release slice must also enable a complete journey for a subset of users or use cases.

---

## Reading the Map for Gaps

After placing all stories, walk the spine and ask for each activity:
- Can the user complete this activity with only the stories in the top row?
- If not, which stories must move up to make the minimum viable?
- Is there a step in the journey that has no stories at all? (A gap — means discovery is incomplete)
- Are there activities with stories piled deep but other activities with no depth? (Imbalanced discovery — investigate the shallow areas)

---

## Connection to Other Skills

| Connects to | How |
|---|---|
| `epic-definition` | Tasks on the map correspond to epics |
| `user-story-writing` | Stories placed on the map are written stories with INVEST compliance |
| `user-persona` | The spine is walked from the perspective of the primary persona |
| `moscow-prioritization` | MoSCoW priority informs vertical placement (Must → top row) |
| `impact-mapping` | Activities on the spine correspond to HOW impacts and WHAT deliverables from the impact map |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Complete spine | Narrative spine covers the full user journey from start to value | Spine stops before the user has achieved their goal |
| No gaps in MVP | User can complete the full journey using only MVP-slice stories | At least one activity in the MVP slice has no stories |
| Depth, not priority | Stories are arranged vertically by depth of detail, not arbitrary priority | Flat rows — no visible depth gradient |
| Release slices | At least MVP and Release 2 are defined | Single horizontal cut with everything else undefined |
| Story placement | Every story from the backlog appears on the map | Orphan stories not placed on any activity |
| Journey walkthrough | Map can be narrated as a user journey without breaking | Spine has logical jumps or unexplained sequences |

---

## Output Format

```markdown
---
artifact: story-map
product: [product name]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
primary-persona: [name]
mvp-boundary: [row at which MVP slice is cut]
---

# User Story Map

## Narrative Spine

[Walk the spine in prose: "First, [Persona] does X... then Y... then Z..."]

## Story Map

| Activity → | [Activity 1] | [Activity 2] | [Activity 3] | [Activity 4] |
|---|---|---|---|---|
| **Tasks** | [Task 1.1] / [Task 1.2] | [Task 2.1] | [Task 3.1] | [Task 4.1] |
| **MVP** | US-[ID] | US-[ID] | US-[ID] | US-[ID] |
| **Release 2** | US-[ID] | US-[ID] | US-[ID] | US-[ID] |
| **Release 3** | US-[ID] | — | US-[ID] | US-[ID] |

## Release Definitions

### MVP — [Release name and goal]
**Enables:** [What a user can do end-to-end with only the MVP stories]
**Stories included:** US-[IDs]

### Release 2 — [Release name and goal]
**Enables:** [Additional capability or user type]
**Stories included:** US-[IDs]

## Map Gaps and Open Questions
[Any activities with no stories, or stories not yet placed on the map]
```
