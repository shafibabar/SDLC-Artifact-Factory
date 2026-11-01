# Example 2 — Standard: two pilot clinics, five days on the canary, the Shoulds kept out, OAT added, and the user's own High-defect bar replaced by a pointer

Self-contained. **Rebound** is appointment software for independent physiotherapy clinics (one to eight practitioners), at the **standard** profile. Release 1's Musts are the three-story walking skeleton confirmed by MoSCoW: US-1 patient receives a confirm request for a long-gap appointment · US-2 patient's reply confirms or cancels · US-4 front desk sees who is still unconfirmed at the cut-off. Rules: BR-1 the confirm request goes 72 h before, for bookings made 14+ days ahead; BR-2 48 h cut-off; BR-3 the text names clinic, date and time only. Two partner clinics (C-1, C-2) run the pilot from 11 January. Each clinic is a tenant; Deploy put Release 1 on the canary for both.

## Input

> **User:** "Plan UAT for Release 1. Since US-5 (waitlist offers) and US-6 (reminders) got built too, test those as well; the front desks care most about the waitlist. Exit criteria: zero open Critical or High defects. C-2's practice manager can't be at the testing week, only at the decision meeting. We don't need the ops stuff; platform did that in Deploy."

## Working it

- **Acceptance types.** UAT, yes. **OAT, yes**: Rebound is hosted, and the clinics would lose patient bookings if a restore failed. Deploy proved the pipeline, not that a restore works, that rollback works, or that anyone is alerted. Those three go to platform-engineer, using `disaster-recovery-plan`, `runbook-authoring` and `slo-definition`. Contractual: no acceptance clauses in the pilot agreements. Regulatory: no for this release, with the reason given (patient data controls are verified in Quality by `compliance-verification`; BR-3 is tested here as a UAT scenario). The pilot cohort itself is the design-partner beta, which `beta-program-design` covers.
- **Scope = the three Musts.** US-5 and US-6 are Shoulds. Putting them in scope dilutes the week the Musts need. Front-desk comments on the waitlist are captured as feedback, which gives the user the signal they want without making it a UAT result.
- **1:N scenario IDs.** US-1 needs two business scenarios: a long-gap booking that gets a request, and a short-gap booking that must not (BR-1). So UAT-1a and UAT-1b. US-2 likewise: UAT-2a confirms, UAT-2b cancels.
- **The user's exit bar is replaced by a pointer.** "Zero open Critical or High" would be a second defect rule, and it disagrees with the sign-off's rule. The plan points to `acceptance-sign-off`'s defect rule and keeps no bar of its own.
- **Independence.** C-1's front desk executes on C-1's tenant, and C-2's front desk on C-2's tenant (level 4: the user community). C-2's practice manager accepts at the decision meeting after reviewing the per-scenario evidence. Two parties, so no solo exception.
- **Repeatability (Blank).** Were both clinics onboarded with the same runbook and the same support? If C-2 needed hand-holding C-1 did not, that is noted. It weakens the evidence more than a pass count shows.

## Output — `customer-validation/uat-plan.md`

````markdown
---
name: uat-plan
product: rebound
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-12-14
summary: Rebound Release 1 UAT: five scenarios over the three Musts at two pilot clinics on the canary, plus OAT (restore, rollback, alerting); decision on 2027-01-08.
profile: standard
release: Release 1 — Walking Skeleton (two partner clinics)
traces_to: ideate/moscow.md; ideate/story-map.md (US-1, US-2, US-4); ideate/acceptance-criteria/*.md; quality/features/*.feature
---

# UAT Plan — Rebound, Release 1

## Acceptance Types in Scope
| Type | In scope | Scope | Executor | Evidence | Sign-off line |
|---|---|---|---|---|---|
| User acceptance (UAT) | yes | US-1, US-2, US-4 | Front desks at C-1 and C-2 | uat-scenario results, EX-1 and EX-2 debriefs | Product owner + C-2 practice manager |
| Operational acceptance (OAT) | yes | Restore within RPO 1 h / RTO 4 h; rollback to 0.9; no-show alert reaches on-call | platform-engineer | Timed restore drill; rollback runbook run; test alert received | Product owner |
| Contractual | no, because the pilot agreements state no acceptance criteria | — | — | — | — |
| Regulatory | no, because patient-data controls are verified in Quality (compliance-verification); BR-3 is UAT-1a's check | — | — | — | — |
| Alpha / beta | no: the two clinics are the design-partner cohort in beta-program-design | — | — | — | — |

## Scope Traceability
| Must story | Acceptance criteria | Feature file | UAT scenarios | Risk |
|---|---|---|---|---|
| US-1 Confirm request for a long-gap appointment | AC-US-1 | features/confirm-request.feature | UAT-1a, UAT-1b | high: wrong timing annoys or misses patients |
| US-2 Reply confirms or cancels | AC-US-2 | features/reply.feature | UAT-2a, UAT-2b | high |
| US-4 Unconfirmed list at the cut-off | AC-US-4 | features/unconfirmed.feature | UAT-4a | normal |

## Out of Scope
Shoulds US-3, US-5, US-6; Coulds US-7, US-8; Won'ts US-9–US-11. Front-desk observations on the waitlist (US-5) are logged as feedback.

## Roles and Independence
- **Executor:** front desk at C-1 (on tenant c1) and at C-2 (on tenant c2)
- **UAT lead:** requirements-analyst
- **Accepting authority:** the product owner + C-2's practice manager (attends the decision only, reviews the per-scenario evidence)
- **Independence level (ISTQB):** business or user community

## Environment
- **Environment:** canary, tenants c1 and c2
- **Version / digest:** rebound 1.0.0 @ sha256:4e7a…
- **Feature flags:** confirm-requests = on for c1, c2 only
- **Test data:** three seeded patients per clinic (bookings 20 days, 10 days and 3 days ahead), the clinics' own SMS test numbers

## Entry Criteria
- [ ] Quality-phase gates passed (pipeline run #212)
- [ ] Deployed to both tenants at the digest that will ship
- [ ] confirm-requests flag on for c1 and c2 only
- [ ] Five uat-scenarios traced to AC-US-1, AC-US-2, AC-US-4
- [ ] Pass threshold and defect bar agreed by the product owner and C-2's practice manager on 2026-12-18, before execution
- [ ] Two charters drafted
- [ ] Both front desks briefed and booked; platform-engineer booked for the OAT window

## Exit Criteria
- Every scenario has a result: Pass, Fail, Blocked or Not run; Blocked and Not run fail this criterion until run
- Pass threshold: 100% of Must scenarios (the Musts are the release's promise)
- Open defects: per the defect rule in acceptance-sign-off
- All feedback triaged (feedback-template)
- Exploratory charters run and debriefed: 2 of 2
- OAT: restore, rollback and alert each recorded
- Residual risk evaluated and written in the Completion Summary

## Schedule
| Day | Date | Activity |
|---|---|---|
| 0 | 2027-01-04 | Entry criteria verified; front desks briefed; charters handed over |
| 1–3 | 2027-01-05 to 2027-01-07 | Scenarios and charters at both clinics; OAT drill on 2027-01-06 |
| 4 | 2027-01-07 (pm) | Compile results; triage feedback |
| 4–5 | 2027-01-07 to 2027-01-08 | Re-test fixes; regression-check neighbouring scenarios |
| 5 | 2027-01-08 | Acceptance decision (acceptance-sign-off) |

## Exploratory Charters
| # | Charter | Time-box | Explorer | Heuristics |
|---|---|---|---|---|
| EX-1 | Explore replying to a confirm request, with replies in unexpected words, emoji, and a second reply that reverses the first, to discover how the front desk learns what the patient meant | 60 min | C-1 front desk | saboteur, CRUD |
| EX-2 | Explore the unconfirmed list around the cut-off, with a reply arriving one minute before and one after the 48 h mark, to discover whether a patient can be on the list and confirmed at once | 45 min | C-2 front desk | boundaries, interruptions |

## Repeatability
Both clinics onboarded with runbook RB-onboard-1 by the same steps. Note any help either needed that the runbook does not cover.

## Completion Summary
- **Planned vs run:** [filled after execution]
- **Open defects:** [ … ]
- **Residual risk:** [ … ]
- **Recommendation:** [ … ]
````

## What the weak first draft looked like

```markdown
Scope: US-1, US-2, US-4, US-5, US-6 → UAT-001…UAT-005
Exit: 100% pass; zero open Critical or High defects
Ops testing: done in Deploy
```

Shoulds in scope; IDs that do not trace back to their stories; a second defect rule; OAT waved away by a pipeline that never restored anything; no independence level; no Blocked / Not run; no re-test time.

## Why this is right at standard

| Choice | Reason |
|---|---|
| Three Musts, five scenarios | Scope = the walking skeleton; 1:N IDs keep each scenario tied to its story |
| Waitlist observations as feedback | The user gets the signal without diluting the Must week |
| OAT added | Hosted product holding bookings: Deploy proved the pipeline, not that restore works |
| Pointer to the sign-off's defect rule | One rule in one place (`acceptance-sign-off`) |
| C-2 accepts from evidence | An absent party can still accept against the per-scenario records |
| Repeatability note | Blank: Customer Validation means a repeatable process, not two bespoke wins |
