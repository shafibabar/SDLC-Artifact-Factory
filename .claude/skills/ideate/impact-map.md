# Skill: ideate/impact-map

## Purpose
Produce an Impact Map — a visualisation that links a business goal to the actors who influence it, the impacts those actors need to have, and the deliverables (features/capabilities) that produce those impacts. Impact Mapping prevents building features disconnected from outcomes by making the goal-to-feature chain explicit and reviewable.

## Inputs
Read before generating:
- `artifacts/strategy/okrs.md` — must exist (OKRs are the goals)
- `artifacts/strategy/stakeholders.md` — must exist (stakeholders are the actors)
- `artifacts/ideate/personas/` — read all existing personas

## Output
**File:** `artifacts/ideate/impact-map.md`
**Registers in manifest:** yes

## Impact Map Structure
```
GOAL (from OKR)
├── ACTOR 1 (who can affect the goal?)
│   ├── IMPACT 1.1 (how should this actor's behaviour change?)
│   │   ├── DELIVERABLE 1.1.1 (what can we build to create this impact?)
│   │   └── DELIVERABLE 1.1.2
│   └── IMPACT 1.2
│       └── DELIVERABLE 1.2.1
└── ACTOR 2
    └── IMPACT 2.1
        └── DELIVERABLE 2.1.1
```

## Process
1. Select the primary OKR goal for the impact map (ask user if multiple OKRs exist).
2. Identify all actors who can positively or negatively affect that goal.
3. For each actor, identify the behaviour changes (impacts) that would move the goal.
4. For each impact, identify 1–3 minimum deliverables that would create that impact.
5. Challenge each deliverable: "If we build this and the actor behaves differently, does the goal move?" If no, remove it.
6. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# Impact Map

**Product:** {product_name}
**Phase:** Ideate
**Artifact:** Impact Map
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Goal
> **{OKR Objective + Key Result being targeted}**
> Metric: {specific KR metric} | Target: {KR target} | Horizon: {OKR horizon}

---

## Impact Map

### Actor: {Actor 1 — e.g. CISO}
*Role: {buyer / champion / daily user}*

#### Impact 1.1: {Behaviour change — e.g. Uses the product to prepare for audits proactively rather than reactively}
*Why this impact moves the goal: {explicit connection to the KR metric}*

| Deliverable | Hypothesis | Priority |
|-------------|-----------|----------|
| {e.g. Audit-readiness score dashboard} | If the CISO can see their compliance posture at a glance, they will use the product weekly rather than only before audits | MUST |
| {e.g. Evidence package export} | If evidence packages can be generated in one click, the CISO will share them with auditors directly from the product | SHOULD |

#### Impact 1.2: {Behaviour change — e.g. Champions internal adoption to the IT team}
*Why this impact moves the goal: {connection to KR}*

| Deliverable | Hypothesis | Priority |
|-------------|-----------|----------|
| {deliverable} | {hypothesis} | {priority} |

---

### Actor: {Actor 2 — e.g. IT Administrator}
*Role: {deployer / operator}*

#### Impact 2.1: {Behaviour change — e.g. Deploys the product to additional storage locations without IT vendor support}
*Why this impact moves the goal: {connection to KR}*

| Deliverable | Hypothesis | Priority |
|-------------|-----------|----------|
| {e.g. One-click storage registration wizard} | If registration takes < 5 minutes with no engineering knowledge, the IT Admin will register all locations at onboarding | MUST |

---

### Actor: {Actor 3 — Negative Actor (who could work against the goal?)}
*Role: {gatekeeper / blocker}*

#### Impact 3.1: {Behaviour change — e.g. Legal approves data processing agreement without extended review cycle}
*Why this impact moves the goal: {if legal blocks the deal, the KR cannot be met}*

| Deliverable | Hypothesis | Priority |
|-------------|-----------|----------|
| {e.g. Pre-built DPA template and data residency documentation} | If legal concerns about data handling are pre-answered in signed documentation, they will approve faster | HIGH |

---

## Deliverable Priority Summary

| Deliverable | Actor | Impact | Priority | OKR linkage |
|-------------|-------|--------|----------|-------------|
| {deliverable 1} | {actor} | {impact} | MUST | {KR ref} |
| {deliverable 2} | {actor} | {impact} | SHOULD | {KR ref} |
| {deliverable 3} | {actor} | {impact} | COULD | {KR ref} |

## Rejected Deliverables
{List deliverables that were considered and removed — with the reason. This prevents re-proposing them.}

| Rejected deliverable | Reason |
|---------------------|--------|
| {feature idea} | {could not be linked to a behaviour change that moves the goal} |
```

## Quality Checks
Before writing:
- [ ] Every deliverable traces to an impact, which traces to an actor, which traces to the goal
- [ ] At least one negative actor (who could block the goal) is included
- [ ] Rejected deliverables are documented
- [ ] Every deliverable has a testable hypothesis, not just a description
- [ ] No undefined ubiquitous language terms
