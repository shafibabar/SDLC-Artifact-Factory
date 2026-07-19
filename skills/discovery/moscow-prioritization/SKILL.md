---
name: moscow-prioritization
description: >
  Teaches how to apply MoSCoW prioritisation (Must / Should / Could / Won't) to
  user stories and requirements — covering the correct meaning of each category,
  how to set and enforce time/resource constraints, the negotiation process for
  disputed priorities, and how MoSCoW connects to the MVP release slice in the
  story map. Used by the requirements-analyst agent during the Ideate phase after
  the story map and epic list are complete.
version: 1.1.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, moscow, prioritisation, mvp, backlog-management]
---

# MoSCoW Prioritisation

## Purpose

MoSCoW is a prioritisation technique that forces explicit decisions about what matters most in a defined delivery window. It replaces vague priority levels ("high / medium / low") with categories that have agreed-upon meanings tied to a specific scope constraint (time, budget, or both).

The key constraint: **MoSCoW only works when there is a defined scope limit.** Without a fixed delivery window or budget, "Must" expands to fill all available time, "Should" becomes an afterthought, and the technique loses its forcing function.

---

## The Four Categories

### Must Have

**Definition:** The requirement must be included in the delivery. Without it, the release fails — either it cannot be shipped, it delivers no value to the primary persona, or it violates a legal or regulatory obligation.

**Test for Must:**
> "If this is not included, does the release fail to meet its stated goal?"
> "Is there a legal, safety, or contractual obligation that requires this?"
> "Without this, will the primary persona be unable to complete their core job?"

If all three answers are no, it is not a Must — demote it.

**The 60% rule:** Must Haves should account for no more than 60% of available capacity. If Musts exceed 60%, either the scope constraint is too loose (narrow the delivery window) or requirements are being incorrectly promoted to Must (be more rigorous). A backlog where everything is a Must is not prioritised — it is a wish list.

---

### Should Have

**Definition:** The requirement is important and expected, but the release could ship without it and still deliver the core value. The absence of a Should creates a degraded but functional experience.

**Distinction from Must:**
- A Must's absence means the product fails to deliver on its primary promise
- A Should's absence means the product delivers, but not as well as it should

**Common Should candidates:** secondary personas' core workflows, error messages and empty states that improve experience, export and sharing capabilities that extend core value, non-critical configuration options.

---

### Could Have

**Definition:** The requirement is desirable but not important. It will only be included if time and resources allow after Musts and Shoulds are complete.

Also called "nice to have". The distinction from Should: a Should would be missed; a Could would be barely noticed in its absence.

**Common Could candidates:** cosmetic improvements, additional data views that duplicate existing information in a different format, convenience shortcuts that save a step.

---

### Won't Have (this time)

**Definition:** The requirement will NOT be included in this delivery window. It is explicitly acknowledged, recorded, and deferred.

**Critical nuance:** "Won't" does not mean "never" — it means "not in this release." Recording Won't items prevents:
- Scope creep from stakeholders who keep re-raising the same requests
- Wasted discovery work by making the exclusion visible and intentional
- Team confusion about what is in scope

A Won't item that is genuinely never going to be built should be closed, not left as Won't. Won't means "not now, but acknowledged."

---

## Applying MoSCoW to the Story Backlog

### Step 1: Set the constraint

Define the delivery window and capacity:
- "MVP: 8 weeks, 1 senior engineer, 1 full-stack contributor"
- Must Haves: maximum 60% of that capacity (approx. 4.8 weeks of work)
- Should Haves: 20% (approx. 1.6 weeks)
- Could Haves: 20% — only if Musts and Shoulds complete early

### Step 2: Apply the Must test to every story

For each story: apply the three Must tests. If any answer is yes, mark Must. Otherwise, start at Should.

### Step 3: Negotiate Shoulds

For each Should: "Would the MVP receive negative feedback from the primary persona if this were missing?" If yes, promote to Must and re-run the 60% check. If no, confirm as Should.

### Step 4: Assign Coulds

Remaining stories that are not deferred become Coulds.

### Step 5: Explicitly assign Won'ts

Stories that are known and valid but explicitly deferred — assign Won't with a one-line rationale. These go into the future backlog, not the trash.

### Step 6: Validate against the story map

The story map's MVP slice and the Must Have stories must be consistent. If a story is in the MVP slice but ranked Should or Could, either the slice is wrong or the priority is wrong — resolve the conflict before closing the Ideate phase.

---

## MoSCoW Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Everything is a Must | No forced trade-offs; Musts exceed 100% of capacity | Apply the 60% rule; challenge every Must |
| Nothing is a Won't | Scope is unconstrained; backlog expands indefinitely | Explicitly assign Won't to out-of-scope items |
| Priority without a delivery window | MoSCoW applied to a timeless backlog — meaningless | Define a specific release window first |
| Priority by committee consensus | Everyone agrees everything is important | Tie every Must to the Must test — if it fails the test, it's not a Must |
| "Should" used as a soft Must | Shoulds are consistently delivered, making them functionally Musts | Re-evaluate: if it's always delivered, promote it to Must and tighten the constraint |

---

## Connection to Story Map

MoSCoW and the story map resolve the same question from different angles:

| Tool | Question answered |
|---|---|
| Story map | What stories must work together to enable the user's end-to-end journey? |
| MoSCoW | Which of those stories are essential to the minimum viable version of that journey? |

The **Must Have** stories are the top row of the story map's MVP slice. The MVP slice defines which activities the user can complete; MoSCoW defines which stories within each activity are non-negotiable.

---

## Worked Example

Constraint: MVP window of 8 weeks. Sample decisions from the first product's backlog (Data Estate Mapping and Compliance Intelligence):

| Story | Category | Reasoning |
|---|---|---|
| US-001 Connect Google Drive via OAuth | Must | Without a connected source there is no product; the primary persona cannot start her core job — passes Must test 3 |
| US-005 Trigger initial scan and classify files by sensitivity level | Must | The release goal is "first compliance gap within 30 minutes"; fails without classification — passes Must test 1 |
| US-009 View compliance gap report | Must | The gap report *is* the first-value moment the release exists to deliver — passes Must test 1 |
| US-010 Export gap report as PDF | Should | Maya can present from the app in the meantime; absence degrades the audit-prep job but does not block it |
| US-006 Monitor scan progress in real time | Could | A static "scan running" state suffices; live progress is a comfort feature whose absence would barely be noticed |
| US-003 Connect SharePoint | Won't (this release) | Design-partner evidence shows Google Drive + S3 covers the ICP; acknowledged and targeted for Release 3 |

**Capacity check:** the three Musts estimate at ~4.5 weeks of the 8-week window — 56%, inside the 60% rule. If US-010 were promoted to Must (as the primary persona's negative feedback might argue), the check must be re-run before accepting the promotion.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Defined constraint | A specific delivery window or budget is stated | MoSCoW applied without a scope constraint |
| 60% Must rule | Must Haves are ≤ 60% of estimated capacity | Must Haves account for 80%+ of capacity |
| Won't items documented | Out-of-scope stories are explicitly assigned Won't with rationale | Scope exclusions are implicit or verbal only |
| Must test applied | Every Must traces to a Must-test pass | Musts that fail all three Must-test questions |
| Story map alignment | Musts match the MVP slice on the story map | Discrepancies between Must list and MVP slice |

---

## Output Format

```markdown
---
name: moscow-prioritisation
product: [product name]
delivery-window: [e.g. MVP — 8 weeks]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
must-capacity-pct: [estimated % of capacity consumed by Musts]
---

# MoSCoW Prioritisation

## Delivery Constraint
**Window:** [dates or sprint count]
**Capacity:** [estimated available effort]
**Must Have capacity limit:** [60% of above]

## Must Have

| Story ID | Title | Must-test justification |
|---|---|---|

## Should Have

| Story ID | Title | Why Should and not Must |
|---|---|---|

## Could Have

| Story ID | Title | Condition for inclusion |
|---|---|---|

## Won't Have (this release)

| Story ID | Title | Rationale for deferral | Target release |
|---|---|---|---|

## Capacity Check
**Estimated Must effort:** [X weeks / story points]
**Must % of total capacity:** [X%]
**Status:** [Within 60% target / Exceeds target — action required]

## Story Map Alignment
[Confirm Musts match the MVP slice, or document any discrepancies]
```
