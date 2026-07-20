---
name: impact-mapping
description: >
  Teaches how to build an Impact Map — a structured visual of the goal → actors →
  impacts → deliverables hierarchy. Impact mapping links every deliverable to a
  measurable business goal, ensures nothing is built that doesn't affect behaviour,
  and identifies which actors and impacts to focus on first. Used by the
  requirements-analyst agent during the Ideate phase to scope and prioritise
  requirements before epic definition.
version: 1.1.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, impact-mapping, discovery, prioritisation, goal-alignment]
---

# Impact Mapping

## Purpose

Impact mapping answers the question: **why are we building this, and is this the right thing to build to achieve the business goal?**

An impact map is a mind-map structured around four questions:
1. **WHY** — what business goal are we trying to achieve?
2. **WHO** — who can cause or block the goal?
3. **HOW** — what behaviour changes from those actors would cause (or prevent) the goal?
4. **WHAT** — what deliverables can we produce to support or create those behaviour changes?

The critical insight: deliverables (features) only matter if they cause a behaviour change in an actor that advances the business goal. If a deliverable doesn't change any actor's behaviour, it is waste.

---

## The Four Levels

### Level 1: WHY — The Goal

State the business goal in measurable terms. This must be a business goal — not a product goal or a feature goal.

- Business goal: "80% of trial users reach their first compliance gap discovery within 30 minutes of connecting their first storage source"
- Not a goal: "Ship the compliance dashboard" (that's a deliverable, not a goal)
- Not a goal: "Improve the product" (unmeasurable)

The goal should come directly from the OKR Key Results. Each Key Result becomes a separate impact map.

---

### Level 2: WHO — Actors

Actors are people or groups who can cause or block the goal. They include:
- **Primary actors** — those whose behaviour directly causes the goal (users)
- **Secondary actors** — those who support primary actors (implementation partners, customer IT teams)
- **Off-stage actors** — those whose decisions affect the goal but who don't use the product (regulators, CISO as sponsor, board as buyer authoriser)

List every relevant actor. Explicitly include actors who could block the goal — understanding blockers is as important as understanding supporters.

---

### Level 3: HOW — Impacts

For each actor, ask: **what behaviour must change (or remain the same) for this actor to help us achieve the goal?**

Impacts are behaviour changes, not activities or features:
- "Maya Chen (Compliance Officer) connects all storage sources within the first session" — behaviour change
- "Maya uses the compliance report feature" — this is a feature, not a behaviour
- "IT Lead deploys the product without raising a support ticket" — behaviour change

For blocking actors: "IT Security approves the deployment request without blocking it" — the impact is removing a blocker behaviour.

---

### Level 4: WHAT — Deliverables

For each impact, ask: **what can we build (or do) to cause this behaviour change?**

Deliverables are features, content, processes, or configuration options that enable the behaviour change:
- Impact: "Maya connects all storage sources within the first session"
- Deliverable: "Guided onboarding wizard that connects a storage source in < 5 minutes"
- Deliverable: "Pre-built connector for Google Drive with OAuth 2.0 single-click authorization"
- Deliverable: "In-app progress indicator showing setup completion percentage"

More than one deliverable can contribute to an impact. List all candidates, then prioritise — not all must be built to achieve the impact.

---

## Impact Map Structure (ASCII)

```
GOAL: [Measurable business goal]
│
├── WHO: [Actor 1]
│   ├── HOW: [Behaviour change 1]
│   │   ├── WHAT: [Deliverable A]
│   │   └── WHAT: [Deliverable B]
│   └── HOW: [Behaviour change 2]
│       └── WHAT: [Deliverable C]
│
├── WHO: [Actor 2 — potential blocker]
│   └── HOW: [Remove blocking behaviour]
│       └── WHAT: [Deliverable D]
│
└── WHO: [Actor 3]
    └── HOW: [Behaviour change 3]
        ├── WHAT: [Deliverable E]
        └── WHAT: [Deliverable F — optional / deferred]
```

---

## Prioritisation from the Map

An impact map is a prioritisation tool. After the full map is drawn:

1. **Identify the highest-impact actors** — which actors, if they changed their behaviour, would most directly cause the business goal?
2. **Identify the highest-impact behaviours** — for the priority actors, which behaviour changes have the most leverage?
3. **Select minimum viable deliverables** — for the priority behaviours, what is the smallest set of deliverables that would reliably cause the behaviour change?

This gives the MVP scope: the minimum set of deliverables that, if built, would cause the behaviour changes in the key actors that would achieve the business goal.

Deliverables left on the map but not selected for MVP become the backlog for subsequent phases — they are already traced to a business goal, so prioritisation is cheap.

---

## Connection to Other Skills

| Connects to | How |
|---|---|
| `okr-authoring` | Each OKR Key Result becomes a WHY goal |
| `user-persona` | Personas map to WHO actors |
| `jtbd-analysis` | Job stories identify the HOW behaviour changes for primary actors |
| `epic-definition` | WHAT deliverables become epics |
| `moscow-prioritization` | Must/Should/Could prioritisation of WHAT deliverables uses the impact map as the forcing function |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Measurable goal | WHY goal has a numeric target or binary condition | "Improve user experience" |
| Goal-OKR link | WHY goal traces to a KR | Impact map goal not in the OKR set |
| Behaviour, not activity | HOW impacts are behaviour changes, not tasks or features | "Users use the feature" |
| Blocking actors | At least one blocking actor identified and addressed | Only supporters — no blockers |
| Deliverable minimalism | Deliverables are candidates, not commitments — minimum set selected | Every deliverable treated as required |
| MVP identification | A minimum set of deliverables is explicitly marked as the MVP cut | Full map delivered without a scope cut |

---

## Anti-Patterns

**Backwards mapping:** starting from an existing feature list and drawing goal → actor → impact branches to justify it. The tell: every WHAT on the map was already on the backlog. The map exists to challenge deliverables, not launder them.

**Deliverable as goal:** "GOAL: ship the compliance dashboard." Shipping is under your control; goals must be outcomes that actors' behaviour produces. If achieving the "goal" requires no one outside the team to change behaviour, it is a deliverable.

**Actor soup:** "the customer", "IT", "the market" as actors. An actor must be specific enough to have observable behaviour — Maya Chen the Compliance Officer can connect a storage source; "the customer" cannot do anything observable.

**Feature usage as impact:** "Maya uses the report feature" restates a deliverable as an impact. The impact is the behaviour change the feature enables ("Maya briefs the CISO from live data instead of a stale spreadsheet").

**The complete-map fallacy:** treating every branch on the map as committed scope. The map is a menu of options traced to the goal; the MVP cut selects the cheapest path through it. A map delivered without a cut has skipped its entire purpose as a prioritisation tool.

---

## Output Format

```markdown
---
name: impact-map
product: [product name]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
linked-kr: [OKR Key Result ID]
---

# Impact Map: [Goal statement]

## Goal
[Measurable goal statement with metric]

## Impact Map

### Actor: [Actor 1 Name / Role]
**Actor type:** [Primary / Secondary / Off-stage / Blocker]

| Impact (HOW) | Deliverable (WHAT) | Priority |
|---|---|---|
| [Behaviour change] | [Feature or capability] | Must / Should / Could / Won't |

### Actor: [Actor 2]
[Repeat]

---

## MVP Scope
[Explicitly list the WHAT deliverables selected for the minimum viable scope, with rationale for each inclusion]

## Deferred Deliverables
[WHAT items on the map that are valid but not selected for MVP — trace to which impact they address]
```
