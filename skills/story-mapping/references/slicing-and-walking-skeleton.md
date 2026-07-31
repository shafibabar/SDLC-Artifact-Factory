# Slicing and the Walking Skeleton

Reference for the *vertical* dimension of a User Story Map (Jeff Patton, *User
Story Mapping*): the walking skeleton, how to slice the map horizontally into
releases by outcome, how a slice becomes an MVP, and a full worked map for this
repo's Data Steward end-to-end estate-review flow. Read alongside
`map-structure-and-backbone.md`, which covers the backbone and the body.

---

## The walking skeleton

**Definition.** The walking skeleton (Patton credits Alistair Cockburn) is the
**thinnest possible slice of the map that actually functions end-to-end across
the entire backbone** — one complete working path through the whole user journey,
even if every step is ugly, manual, or minimal.

It is *read as the top row across every backbone step at once*. The name is
literal: a skeleton that can already **walk** — move under its own power from one
end of the journey to the other — before any flesh is added.

### Why "walking skeleton" is more precise than "MVP slice"

"MVP slice" invites the reading "the minimum viable set of stuff," which teams
satisfy by picking their favourite must-haves. The walking-skeleton framing fixes
a harder, testable bar: the slice must **work end-to-end**. A pile of high-value
stories that does not connect into a complete path is not a walking skeleton, no
matter how "minimum viable" it feels.

### The end-to-end test

Read the candidate top row across the *whole* backbone and ask: **does this form
one complete, functioning path from the first activity to the delivered outcome?**

- If *any* backbone step's top row is missing or non-functional, the skeleton is
  **broken**, not merely incomplete — the user hits a wall mid-journey.
- A broken skeleton is the single most common release-scoping failure and is
  exactly what the "vertical-slice MVP" anti-pattern produces.

---

## Slice by outcome, not by layer

Below the walking skeleton, additional horizontal cuts mark **releases**. The
governing rule: **each slice must itself be end-to-end viable — it delivers a user
*outcome*, not a completed component.**

| | Outcome slice (correct) | Layer/component slice (wrong) |
|---|---|---|
| Shape | Thin cut crossing *every* backbone step | Deep cut completing *one* backbone step |
| User experience | Can finish the whole journey, with fewer options | Can perfect one step, then hits a wall |
| Example | "Connect one source → scan it → see the gap report" | "All four connectors, perfectly — scanning next quarter" |

### A release slice is not a MoSCoW "Must" cut

MoSCoW (a DSDM technique, not Patton's) ranks stories by category. A release slice
is a different operation: it must be **end-to-end viable**, not "the collection of
Must-Haves." A set of Musts scattered across three backbone steps with a gap in
between is a broken slice even though every story in it is a Must. Use MoSCoW to
inform *vertical placement* within a step; use the end-to-end test to decide the
*horizontal cut*.

### Re-cutting as learning happens

Slices are not frozen. After a slice ships, Patton expects an explicit **"what did
we learn"** checkpoint that may reshape later slices. The map is a living tool
revisited across releases, not a one-time discovery output.

---

## How a slice maps to an MVP — and the two MVPs

The **MVP slice** of a story map is the walking skeleton: the smallest thing you
can actually **ship** to real users and have them complete the journey. That is a
**release-MVP**.

Patton is careful to distinguish it from a **learning-MVP** — the *cheapest thing
you can build to test a belief* (a fake-door test, a concierge/manual experiment,
a throwaway prototype), which may never ship at all:

| | Release-MVP | Learning-MVP |
|---|---|---|
| Purpose | Ship a usable outcome | Validate a hypothesis cheaply |
| On the map? | Yes — the walking-skeleton cut | No — lives upstream (`impact-mapping` / JTBD) |
| Rigour | Production-worthy (if minimal) | Deliberately throwaway |
| Failure mode | Treating it as a mere prototype | Treating it as shippable |

A story map produces a **release-MVP**. Never let a validated-learning experiment
be treated as shippable, or demand production rigour from a learning experiment.

---

## Worked map — Data Steward end-to-end estate review

Primary persona: the **Data Steward** at an SMB, using the data-estate/compliance
platform. Narrated spine: *connect a source → scan & classify it → review the
compliance gap report → manage & govern the estate.*

### The map

```
BACKBONE →  Connect Sources     │  Scan & Classify      │  Review & Report        │  Manage & Govern
TASKS    →  Connect a source    │  Run a scan           │  See compliance gaps    │  Act on findings
────────────────────────────────┼───────────────────────┼─────────────────────────┼──────────────────────────
WALKING SKELETON (Release 1 — the shippable MVP; read across = one working path)
  US-001 Connect Google Drive   │  US-005 Trigger a scan │  US-009 View gap report │  US-013 Set retention policy
  (OAuth, one source)           │  (manual, one source)  │  (on-screen, top risks) │  (one policy, applied)
────────────────────────────────┼───────────────────────┼─────────────────────────┼──────────────────────────
RELEASE 2 — broaden sources & sharing (still end-to-end for more users)
  US-002 Connect AWS S3         │  US-006 Monitor scan   │  US-010 Export gap      │  US-014 Manage user
                                │        progress        │        report (PDF)     │        access
────────────────────────────────┼───────────────────────┼─────────────────────────┼──────────────────────────
RELEASE 3 — automate & govern at scale
  US-003 Connect SharePoint     │  US-007 Schedule       │  US-011 Schedule        │  US-015 Configure data
                                │        recurring scan  │        recurring report │        residency
  US-004 Connect local upload   │  US-008 Scan results   │  US-012 Trend view      │  US-016 Audit log of
                                │        summary         │        over time        │        actions
```

### Why the walking skeleton is genuinely a skeleton

Read the top row across all four steps: **the Data Steward connects Google Drive,
triggers a scan over it, reads the compliance gaps it finds on screen, and sets a
retention policy to start closing them.** That is a complete, if bare, compliance
review — the persona achieves the outcome the product exists to deliver. Remove
*any* one of the four and the skeleton no longer walks: connect-and-scan with no
report leaves the Steward with data and no insight; a report with no policy action
leaves them informed but unable to act.

### Why the vertical-slice alternative fails

"Ship all four connectors first, perfectly" would complete the **Connect Sources**
column down to US-004 while **Scan & Classify** stays empty. The Data Steward can
connect Google Drive, S3, SharePoint, and local uploads flawlessly — and then has
nowhere to go, because nothing scans them. Impressive column, no outcome.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Complete backbone | Narrative spine covers the full journey from start to delivered value | Spine stops before the persona achieves their goal |
| Walking skeleton walks | Top row read across the *entire* backbone forms one functioning end-to-end path | An activity in the skeleton has no functioning top-row story |
| Necessity, not priority | Body stories ordered vertically by what makes the step minimally whole | Flat rows with no necessity gradient |
| Outcome slices | Every release slice is end-to-end viable, not a completed component | A slice completes one activity and leaves later steps empty |
| Release slices defined | At least the MVP (skeleton) and Release 2 are cut | A single cut with everything else undefined |
| Every story placed | Each backlog story appears on the map | Orphan stories placed nowhere |
| MVP kind is explicit | The map's MVP is stated as a release-MVP (shippable), not a learning experiment | "MVP" used ambiguously for a throwaway experiment |

---

## Output Format

```markdown
---
name: story-map
product: [product name]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
primary-persona: [name]
walking-skeleton: [the release name of the top-row end-to-end slice]
---

# User Story Map

## Big Picture
- **Opportunity:** [business objective this map serves]
- **Primary persona:** [name]
- **Outcome hypothesis:** [the outcome shipping the skeleton should produce]

## Narrative Spine
[Walk the backbone in prose: "First, [Persona] does X... then Y... then Z..."]

## Story Map

| Activity → | [Activity 1] | [Activity 2] | [Activity 3] | [Activity 4] |
|---|---|---|---|---|
| **Tasks** | [Task 1.1] | [Task 2.1] | [Task 3.1] | [Task 4.1] |
| **Walking skeleton (MVP)** | US-[ID] | US-[ID] | US-[ID] | US-[ID] |
| **Release 2** | US-[ID] | US-[ID] | US-[ID] | US-[ID] |
| **Release 3** | US-[ID] | — | US-[ID] | US-[ID] |

## Release Definitions

### Release 1 — Walking Skeleton (MVP)
**Walks end-to-end:** [what the persona can complete start-to-finish with only these stories]
**Stories:** US-[IDs]
**MVP kind:** Release-MVP (shippable) — not a learning experiment.

### Release 2 — [name and outcome]
**Enables:** [additional outcome or user type, still end-to-end]
**Stories:** US-[IDs]

## Map Gaps, Learning Checkpoints, and Open Questions
[Backbone steps with no stories; orphan stories; what to re-check after Release 1 ships]
```
