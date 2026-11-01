# Example 3 — Enterprise: four tenants report overlapping symptoms; the same symptom with two causes stays as two items, a confirmed pattern on a Must flow is named for the sign-off, and one missing capability is escalated because it challenges the ICP (hardest case)

Self-contained. **Gridwell** plans maintenance for onshore wind-farm operators, at the **enterprise** profile. Each operator is a tenant. Release 3's UAT window has closed across four tenants (T1–T4); the product owner also has two check-in notes and one exploratory debrief.

## Input

> **User:** "Lots of overlap this time. Three tenants say work orders 'vanish' from the planner, so merge those into one High pattern. T2 and T4 both want regulator reporting; put it on the Must list for this release. And the mobile assign-crew thing is just a couple of people grumbling."

Raw findings:
- **"Work orders vanish from the planner."** T1 (Australia): orders scheduled after 14:00 local disappear from today's view; investigation found the date filter uses UTC. T3: orders merged during a duplicate-turbine clean-up lost their planner link. T4: same symptom as T1, also a non-UTC timezone, same filter.
- **Assign crew on mobile.** UAT-31 (assign a crew from a phone, Must) failed at T1, T2 and T3: each site lead independently could not find the action, which sits behind an unlabelled overflow menu; two phoned the office to assign instead. T4 does not use mobile.
- **Regulator reporting.** T2 and T4 need to file outage reports with a grid regulator, which Gridwell does not do. Both are larger operators with grid-connection obligations; the ICP in the strategy is "independent operators with 1–5 sites".
- **Exploratory debrief EX-4** (charter: bulk rescheduling): a 400-order reschedule silently skipped 12 orders. The tester asks for a follow-up session on partial failures.

## Working it

- **Dedupe by cause.** "Vanish" has two causes: the UTC date filter (T1 and T4, independent reporters, same cause: one item, two tenants) and broken links after a turbine merge (T3: a separate item). Merging all three would send one fix to one engineer and leave T3 broken. The filter bug is in the planner view (`frontend-engineer`); the merge bug is in the data clean-up job (`data-engineer`). Both are High: a Must flow (see today's work) gives the wrong result.
- **The assign-crew finding is a confirmed pattern, not grumbling.** Three independent site leads, same cause, on a Must flow, and two fell back to phoning. That is named in words for the sign-off; `acceptance-sign-off` treats a blocking pattern on a Must flow as High. Route: `ux-architect`.
- **Regulator reporting is escalated, not added to this release's Musts.** A missing capability goes to the requirements-analyst for a later release. This one is raised only by operators **outside** the ICP, so it challenges who the product is for: it is escalated to the `product-strategist`. It never becomes a silent Must for this release.
- **EX-4.** The skipped orders are a High item for the `backend-engineer`; the follow-up session goes back to `uat-plan` as a new charter, not into the log.
- **Severity words** are this plugin's house scale, not an external standard.

## Output — the reply, and `customer-validation/feedback/2026-09-18.md`

> I've kept "vanish" as two items, not one pattern. T1 and T4 share one cause (the planner's date filter uses UTC), and that goes to the frontend-engineer. T3's cause is different (links broken by the turbine merge), and that goes to the data-engineer. Merging them would have fixed two tenants and left T3 broken. The mobile assign-crew problem is a real pattern: three site leads at three tenants independently couldn't find the action on a Must flow, and two phoned the office instead. I've named it for the sign-off, where it counts as High. Regulator reporting doesn't go on this release's Must list. Only operators outside the target profile asked for it, so I've escalated it to the product-strategist as a question about who Gridwell is for. EX-4's skipped orders are a High for the backend-engineer, and the follow-up session goes back to the UAT plan as a new charter.

````markdown
---
name: feedback-log-gridwell-2026-09-18
product: gridwell
release-slice: release-3
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-09-18
summary: Gridwell release 3 feedback: two causes behind vanishing work orders; confirmed assign-crew pattern on a Must flow for the sign-off; regulator reporting escalated as an ICP question.
profile: enterprise
traces_to: customer-validation/uat-plan.md; customer-validation/beta-program/gridwell-release-3.md; EX-4 debrief
---

# Feedback Log — gridwell 2026-09-18

## Sources
Release 3 UAT window (T1–T4); check-ins with T2 and T4; exploratory session EX-4.

## Items

### FB-41: Today's planner drops orders scheduled after 14:00 local (non-UTC tenants)
**Source:** UAT-12 failure
**Reporter:** Mia Lowe, planning lead, T1; Jonas Berg, maintenance manager, T4
**Date:** 2026-09-16
**Context — what happened:** On 15 September, T1 scheduled a gearbox inspection for 15:30 local; it was missing from today's view. T4 saw the same on 16 September with a 17:00 job.
**Expected vs. Actual:**
- Expected: all of today's local orders in today's view
- Actual: orders late in the local day shown under tomorrow
**Category:** bug
**Severity:** High
**Underlying need:** n/a
**Supporting detail:** cause: date filter uses UTC; US-4 (Must)
**Routed to:** frontend-engineer
**Rollup:** symptom "orders vanish", cause A; 2 independent reporters

### FB-42: Orders lose their planner link after a duplicate-turbine merge
**Source:** UAT-12 failure
**Reporter:** Ravi Shah, site lead, T3
**Date:** 2026-09-16
**Context — what happened:** After T3 merged 14 duplicate turbine records on 14 September, 9 open work orders no longer appeared in the planner.
**Expected vs. Actual:**
- Expected: orders follow the surviving turbine record
- Actual: orders orphaned
**Category:** bug
**Severity:** High
**Underlying need:** n/a
**Supporting detail:** cause: merge job does not re-point work-order links; US-4 (Must)
**Routed to:** data-engineer
**Rollup:** symptom "orders vanish", cause B; 1 reporter

### FB-43: Assign-crew action not found on mobile
**Source:** UAT-31 failure
**Reporter:** site leads at T1 (Mia Lowe), T2 (Erin Doyle), T3 (Ravi Shah)
**Date:** 2026-09-17
**Context — what happened:** Each, during their UAT session, tried to assign a crew from a phone, could not find the action (behind an unlabelled overflow menu), and two phoned the office to do it.
**Expected vs. Actual:**
- Expected: assign a crew from the work-order screen on a phone
- Actual: action hidden; task abandoned or done by phone
**Category:** UX friction
**Severity:** High
**Underlying need:** n/a
**Supporting detail:** US-9 (Must); T4 does not use mobile
**Routed to:** ux-architect
**Rollup:** confirmed pattern, 3 of 3 mobile tenants, same cause

### FB-44: File outage reports with the grid regulator
**Source:** beta check-in (T2, T4)
**Reporter:** Erin Doyle, operations director, T2; Jonas Berg, maintenance manager, T4
**Date:** 2026-09-12
**Context — what happened:** Both described last quarter's regulator outage filing, assembled by hand from Gridwell exports and a spreadsheet.
**Expected vs. Actual:**
- Expected: produce the regulator's outage report from maintenance records
- Actual: manual assembly
**Category:** missing capability
**Severity:** Low
**Underlying need:** "At quarter end I need to file outage data with the grid regulator without rebuilding it by hand." (regulatory reporting)
**Supporting detail:** both reporters operate 12+ sites with grid-connection obligations, outside the ICP (1–5 sites)
**Routed to:** requirements-analyst, escalated to product-strategist (challenges the ICP)
**Rollup:** need "regulatory outage reporting"; 2 independent stories

### FB-45: Bulk reschedule silently skips orders
**Source:** exploratory debrief EX-4
**Reporter:** Tom Reid, tester (charter: bulk rescheduling)
**Date:** 2026-09-17
**Context — what happened:** Rescheduling 400 orders by a week reported success; 12 orders kept their old dates, with no error.
**Expected vs. Actual:**
- Expected: all 400 moved, or a clear list of failures
- Actual: 12 silently skipped
**Category:** bug
**Severity:** High
**Underlying need:** n/a
**Supporting detail:** reproduction steps in the EX-4 notes
**Routed to:** backend-engineer
**Rollup:** single reporter

## Rollup by Symptom and Cause
| Group | Items | Independent reporters | Cause | Severity | Owner | Status |
|---|---|---|---|---|---|---|
| Orders vanish — UTC date filter | FB-41 | 2 (T1, T4) | filter uses UTC | High | frontend-engineer | open |
| Orders vanish — merge orphans links | FB-42 | 1 (T3) | merge job | High | data-engineer | open |
| Assign crew hidden on mobile | FB-43 | 3 (T1, T2, T3) | unlabelled overflow menu | High | ux-architect | open |
| Bulk reschedule skips orders | FB-45 | 1 | unknown | High | backend-engineer | open |

## Rollup by Customer Need
| Customer need | Stories mentioning it (independent) | Items | Parent opportunity |
|---|---|---|---|
| Regulatory outage reporting | 2 | FB-44 | Meet grid obligations with less effort (outside current ICP) |

## Patterns for the Sign-Off
- FB-43: 3 of 3 mobile tenants' site leads independently could not assign a crew on a Must flow; two fell back to phoning the office. A blocking pattern: acceptance-sign-off treats it as High.

## Positive Signals
- T2 planned September's blade inspections for 4 sites in Gridwell alone, with no spreadsheet (check-in, 2026-09-12).

## Sent Elsewhere
- New charter to uat-plan: partial failures in bulk operations (from EX-4).
- FB-44 escalated to product-strategist: demand from operators outside the ICP.
````

## What the weak first draft looked like

"FB-41: Work orders vanish (3 tenants, High pattern) → engineering. Regulator reporting → Must. Mobile: minor." One fix would have closed T1 and T4 and left T3 broken. A capability from outside the ICP became a Must for this release without anyone asking whether Gridwell serves those operators. And the one real pattern on a Must flow was waved away, so it never reached the sign-off.
