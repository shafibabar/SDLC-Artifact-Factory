# Example 2 — Standard: the clinics are happy but a High is open, so the outcome is conditional with a full fix plan, the rollout holds at a named stage, and an uneven onboarding is recorded as residual risk

Self-contained. **Rebound** is appointment software for independent physiotherapy clinics, at the **standard** profile. Release 1's Musts: US-1 patient receives a confirm request for a long-gap appointment · US-2 patient's reply confirms or cancels · US-4 front desk sees who is still unconfirmed at the 48 h cut-off. Two partner clinics (C-1 and C-2, each a tenant) ran UAT on the canary. The accepting authority is the product owner plus Dr Helen Achebe, clinic lead at C-1, named as customer representative in the plan.

## Input

> **User:** "Both clinics loved it. There's one High: when a patient cancels by text, the front-desk list keeps showing them as unconfirmed for up to 20 minutes. We'll fix it next sprint. Can we call it a full sign-off and roll out to everyone? Helen's happy."

Completion summary: 7 scenarios, 6 Pass, 1 Fail (UAT-4b, the 20-minute lag, FB-07 High); 0 Blocked, 0 Not run; charters 2 of 2, which produced FB-09 (Medium: the reply text is cut off on older Android phones). OAT: restore drill and rollback passed (platform-engineer, 2026-01-06). Repeatability note: C-1 set up from the onboarding guide alone; C-2 needed a 40-minute call to configure its SMS sender name.

## Working it

- **Defect rule, all of it.** No Critical. One High, so the outcome is **conditional at best, and only with a fix plan**: owner, target date, a workaround a receptionist can follow, the re-test, and the rollout pace meanwhile. "Next sprint" is not a fix plan. A Medium (FB-09) is allowed under conditional or full, and is listed either way. Helen being happy does not change what an open High allows.
- **Workaround.** Before calling an "unconfirmed" patient, the front desk checks the Replies tab, which updates at once. That keeps US-4's outcome reachable, but it needs each new clinic briefed.
- **Rollout pace.** Because the workaround needs a briefing, the release does not go to 100%. The canary widens to the next tenant wave (ten clinics that get the briefing) and **holds** there until UAT-4b re-runs green.
- **Repeatability (Blank).** C-2 needed bespoke help, so the onboarding guide is not yet repeatable. This does not decide the outcome. It goes under residual risk, and the onboarding guide gets fixed before the next wave.
- **One sign-off.** There is no beta stage here. The rollout action states the whole path to GA, and no further sign-off is needed when the condition closes.

## Output — the reply, and `customer-validation/sign-off/release-1.md`

> It can't be a full sign-off while FB-07 is open. An open High allows a conditional sign-off only, and only with a fix plan. Here is the whole rule: Critical means no-go; High means conditional with a plan; Medium and Low allow either. I've drafted it as conditional. Backend-engineer owns the fix, the target is 20 January, the front desk checks the Replies tab meanwhile, and UAT-4b re-runs at both clinics. The canary widens to the next ten clinics (who get the workaround briefing) and holds there until the re-test passes. Then it goes to 100% with no new sign-off. I need your approval of that date, and Helen's agreement recorded in her own words.

````markdown
---
name: acceptance-sign-off-release-1
product: rebound
release-slice: Release 1 — confirm requests and replies
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: 2027-01-08
summary: Rebound Release 1 conditionally signed off: one High (reply lag) with a fix plan due 2027-01-20; canary widens to wave 2 and holds until UAT-4b re-runs green.
profile: standard
traces_to: customer-validation/uat-plan.md; customer-validation/feedback/2027-01-07.md
---

# Acceptance Sign-Off — Release 1 — confirm requests and replies

## Evidence
- UAT plan completion summary: customer-validation/uat-plan.md — 7 scenarios: 6 Pass, 1 Fail, 0 Blocked, 0 Not run; charters 2 of 2
- Feedback log: customer-validation/feedback/2027-01-07.md — open: 0 Critical, 1 High (FB-07), 1 Medium (FB-09)
- Beta graduation records: beta not in scope for this release

## Sign-Off Criteria Checklist

- [x] Every UAT scenario for a Must story has a result, and none is Blocked or Not run
- [ ] The pass threshold agreed before execution is met — 6 of 7; UAT-4b failed (FB-07), handled as a condition
- [x] Every planned exploratory session ran and was debriefed; its findings triaged — EX-1, EX-2; EX-2 produced FB-09
- [x] Every acceptance type in scope (OAT, contractual, regulatory) has a result, accepted by its signatory — OAT
- [x] Zero open Critical defects
- [x] Every open High has a fix plan: owner, target date, workaround, re-test, rollout pace — FB-07, below
- [x] All feedback items triaged, scripted and exploratory alike
- [x] No unaddressed blocking pattern on a Must flow
- [ ] Repeatability: every executor or cohort was set up the same documented way (if more than one) — C-2 needed a bespoke setup call; see Residual Risk
- [x] Beta stage graduation records exist for each stage passed (if beta is in scope) — not in scope
- [x] Residual risk evaluated and written down

## Acceptance Types
| Type | Result | Accepted by |
|---|---|---|
| User acceptance (UAT) | 6 of 7 Pass; UAT-4b Fail (FB-07) | signatories below |
| Operational acceptance (OAT) | Restore drill and rollback passed, 2027-01-06 (platform-engineer) | Lena Ward, product owner |

## Sign-Off Authority
- Lena Ward (product owner) — agreed 2027-01-08, review meeting
- Dr Helen Achebe, clinic lead, Riverside Physio (C-1) (customer representative) — agreed 2027-01-08, by email: "Usable for us with the Replies-tab check until the fix lands."

## Decision: CONDITIONAL SIGN-OFF

**Conditions (if conditional):**
- FB-07 (High) — workaround: before calling an unconfirmed patient, check the Replies tab, which updates at once — owner: backend-engineer — target date: 2027-01-20 — re-test: UAT-4b re-run at C-1 and C-2, UAT-4a regression-checked

## Residual Risk
- FB-09 (Medium): on older Android phones the reply text is cut off after 140 characters; the confirm and cancel keywords still show. Accepted by Lena Ward; fix scheduled for Release 2.
- Repeatability: C-2 needed a 40-minute call to set its SMS sender name, so onboarding is not yet repeatable from the guide alone. Owner: requirements-analyst updates the guide before wave 2. Accepted by Lena Ward.

## Rollout Action
canary-deployment: widen from the two pilot tenants to wave 2 (ten clinics, each briefed on the Replies-tab workaround), then hold. After the FB-07 re-test passes, widen to 100% and terminate; no further sign-off is needed. feature-flag-design: `confirm-requests.v1` scope follows the canary; removed only after FB-07 closes.

## Follow-Up
- 2027-01-20: UAT-4b re-run by the same front-desk executors at C-1 and C-2; UAT-4a regression-checked. If the date slips, the canary stays at wave 2 and the new date goes to the user.
````

## What the weak first draft looked like

"FULL SIGN-OFF — clinics happy; FB-07 to be fixed next sprint." It recorded an open High under a full sign-off, which the defect rule forbids. "Next sprint" has no owner, date, workaround or re-test. The rollout went to everyone with no pace. And C-2's bespoke onboarding was missing, so the next ten clinics would have hit the same wall.
