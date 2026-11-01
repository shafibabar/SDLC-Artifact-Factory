# Example 1 — Lean: the volunteer is the only tester, so the plan records a solo-operator exception, keeps the full sign-off open, and declines to let the agent "explore" (simplest case)

Self-contained. **Toolshed** is a tool-loan tracker one volunteer is building for a 60-member community makerspace, replacing a shared Google Sheet. It runs at the **lean** profile: `uat-plan` and `acceptance-sign-off` are required, `beta-program-design` is skipped, and Deploy is a single small setup with no canary. Release 1's Musts are the walking skeleton in the Must / Won't-this-time block closing `ideate/user-stories.md`: US-1 see whether a tool is in · US-8 steward records a loan · US-3 see my own loans · US-9 steward records a return · US-2 Friday overdue list. US-4 (reminder) was built as contingency.

## Input

> **User:** "Release 1 is deployed. I'm the only person working on this, so I'll test it myself. Can you do the exploratory testing for me, since you can read the screens? Put the reminder (US-4) in UAT too, now it's built. And I assume a solo test means conditional sign-off at best, so just write that."

## Working it

- **Acceptance types.** UAT, yes. Toolshed holds members' names and emails, so **OAT is a three-line smoke**: restore works, rollback works, someone gets alerted. No contract, no compliance scope, and beta is skipped at lean. Each "no" carries its reason.
- **Scope = the Must block.** Five Musts, six scenarios (US-2 gets two: a tool one day overdue, and a member with two overdue tools). **US-4 stays out**: it is contingency, not a Must. If the volunteer notices something about the reminder, it goes in as feedback.
- **Solo-operator exception, not a cap.** The volunteer executes and accepts, so the independence level is **"none"** and the plan records the exception. A **full sign-off stays possible** (D045); the exception record carries the risk. The scenarios come from Ideate's acceptance criteria, frozen before the build was seen. Every scenario gets a screenshot. One **borrowed session**: a steward who has never seen the app runs UAT-8a and UAT-9a cold on club night.
- **The agent does not explore.** An agent reading screenshots is running a script with an exploratory label. The agent drafts the charter and takes notes; the volunteer explores.
- **Environment.** No canary at lean: production, with the release flag on for the volunteer and the one borrowed steward only.
- **Two days**, with re-test on day 2.

## Output — the reply, and `customer-validation/uat-plan.md`

> I can't do the exploratory testing myself. Without a person driving, it would just be scripted testing with a different label. I've written one charter for you to run (about an hour), and I'll take the notes. The reminder stays out of UAT because it's contingency, not one of the Musts; anything you notice about it goes in as feedback. Being the only tester doesn't cap you at a conditional sign-off. The plan records a solo-operator exception (independence "none"), and a full sign-off is still possible. I've also planned a 20-minute session where one steward tries two scenarios cold.

````markdown
---
name: uat-plan
product: toolshed
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-11-02
summary: Toolshed Release 1 UAT: six scenarios over the five Musts plus a three-line OAT smoke, run in two days by the volunteer under a solo-operator exception.
profile: lean
release: Release 1 — the walking skeleton (US-1, US-8, US-3, US-9, US-2)
traces_to: ideate/user-stories.md (Must / Won't-this-time block); ideate/acceptance-criteria/*.md; quality/features/*.feature
---

# UAT Plan — Toolshed, Release 1

## Acceptance Types in Scope
| Type | In scope | Scope | Executor | Evidence | Sign-off line |
|---|---|---|---|---|---|
| User acceptance (UAT) | yes | The five Musts | The volunteer (solo exception) | Scenario results, EX-1 debrief | The volunteer |
| Operational acceptance (OAT) | yes: three-line smoke (holds member emails) | Restore works; rollback works; someone gets alerted | The volunteer | One dated observation each | The volunteer |
| Contractual | no, because there is no contract | — | — | — | — |
| Regulatory | no, because Toolshed is in no compliance scope | — | — | — | — |
| Alpha / beta | no: skipped at lean | — | — | — | — |

## Scope Traceability
| Must story | Acceptance criteria | Feature file | UAT scenarios | Risk |
|---|---|---|---|---|
| US-1 See whether a tool is in | AC-US-1 | features/tool-status.feature | UAT-1a | normal |
| US-8 Steward records a loan | AC-US-8 | features/loans.feature | UAT-8a | high: no loan, no due date |
| US-3 See my own loans | AC-US-3 | features/my-loans.feature | UAT-3a | normal |
| US-9 Steward records a return | AC-US-9 | features/loans.feature | UAT-9a | high |
| US-2 Friday overdue list | AC-US-2 | features/overdue.feature | UAT-2a, UAT-2b | high: moves KR-1.1 |

## Out of Scope
Contingency US-4 (reminder) and US-5 (block an overdue member); Won't-this-time US-6, US-7. Observations about them are logged as feedback.

## Roles and Independence
- **Executor:** the volunteer (product owner) · **UAT lead:** requirements-analyst · **Accepting authority:** the volunteer
- **Independence level (ISTQB):** none

## Exception: solo operator
- Executor and accepting authority: the product owner · Independence level (ISTQB): none
- Why no second party: Toolshed has one builder and no design partner; members start using it after sign-off
- Independence in time: scenarios frozen from the acceptance criteria on 2026-10-30, before the build was seen
- Evidence per scenario: screenshot, date, environment, version, flag state
- Borrowed session: one steward runs UAT-8a and UAT-9a cold on club night, 2026-11-04 (20 min)

## Environment
Production, release flag `release-1` on for the volunteer and the borrowed steward only · version 1.0.0 · test tools TEST-DRILL, TEST-SAW · two test member accounts

## Entry Criteria
- [x] Quality gates passed (CI run #41) · [x] deployed at 1.0.0, the version that will ship · [x] six scenarios traced to the five Musts
- [x] Pass threshold and defect bar agreed by the volunteer on 2026-11-02, before execution · [x] EX-1 drafted

## Exit Criteria
- Every scenario Pass, Fail, Blocked or Not run; Blocked and Not run fail this criterion until run
- Pass threshold: 100% of Must scenarios (the Musts are the release's promise)
- Open defects: per the defect rule in acceptance-sign-off
- EX-1 run and debriefed; the three OAT smoke lines recorded; residual risk written below

## Schedule
Day 1 (2026-11-03): six scenarios, EX-1, OAT smoke · Day 2 (2026-11-04): borrowed session, re-test fixes, completion summary, acceptance decision

## Exploratory Charters
- EX-1: Explore lending and returning a tool, with a loan recorded on one phone and returned on another and a return made twice, to discover whether the member's loan list and the Friday overdue list ever disagree (60 min, the volunteer; heuristics: interruptions, CRUD, saboteur)

## Completion Summary
- Planned vs run: [filled after execution] · Open defects: [ … ] · Residual risk: no independent tester apart from one 20-minute steward session · Recommendation: [ … ]
````

## What the weak first draft looked like

```markdown
# UAT Plan — Toolshed
Executor: Claude (exploratory testing of the screens) · Sign-off: product owner (conditional, solo)
Scope: US-1, US-2, US-3, US-4, US-8, US-9
Exit: zero open Critical/High defects
```

The agent named as explorer; a contingency story in scope; the outcome capped at conditional against D045; a defect bar of the plan's own; no independence level, no exception record, no OAT, no result states, no re-test day.

## Why this is right at lean

| Choice | Reason |
|---|---|
| One page, two days | Lean: fewer, shorter artifacts; the method is unchanged |
| Solo exception recorded, full sign-off still open | D045: the record carries the risk, not a cap |
| Borrowed steward session | Second eyes at almost no cost (independence without headcount) |
| Three-line OAT smoke | It holds user data: can it be restored, rolled back, and does anyone hear when it breaks? |
| Production behind a flag | Lean has no canary; this is still the version that ships |
| The agent drafts, a human explores | Hendrickson: exploration is human judgement in the moment |
