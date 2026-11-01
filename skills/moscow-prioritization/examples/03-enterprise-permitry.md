# Example 3 — Enterprise: a contractual Must for one tenant added to the skeleton, a regulatory Must confirmed, a 9/9 epic judged story by story, and a scope escalation when the Musts outgrow the skeleton (hardest case)

Self-contained. **Permitry** is a multi-tenant SaaS platform for local councils to receive and decide building and planning permit applications. Each council is a tenant; three pilot councils (A, B, C) are replacing a fifteen-year-old on-premises system. At the **enterprise** profile `ideate/moscow.md` adds: provisional (project-level) value / penalty beside the release bins, legal and contractual Musts per tenant marked with their rule, a re-cut handed to the story map, an optional report-only Must share, a priority change log, and any scope escalation with the product owner's decision.

## Input

> **Story map (ideate/story-map.md, approved):** Release 1 is council A only. Walking skeleton: (manual: operations creates council A's tenant from the runbook), US-40 · US-11 · US-70, US-42 (regulatory: personal data, NFR-SEC-01) · US-80, US-81 · US-82 · (manual: council A's open cases finish in the legacy system). Release 2 "council A: complete first submissions": US-10, US-12, US-13, US-15, US-14, US-20–US-22, US-71, US-30–US-32, US-50–US-53. Release 3 "councils B and C go live": US-41, US-44, US-54–US-61. Later: US-23, US-43.
>
> **Provisional priorities (value / penalty):** EPIC-1 checklist 9/9 (US-10 9/9, US-11 9/9, US-12 9/8, US-13 7/9, US-14 5/4, US-15 6/8); EPIC-4 isolation 6/9 (US-40–US-42 6/9, US-43 4/6, US-44 5/6); EPIC-6 submit and track (US-70, US-71; from the second impact map, unscored).
>
> **New evidence:** council A's signed service agreement, schedule 2: "Applicants can see the status of their application online from the first day of service." The FRD has no rule for it yet.
>
> **User (first turn):** "Council A launches on 1 March. EPIC-1 is 9/9, so US-10, US-12, US-14 and US-15 are Musts, and put the drawing checks (US-20 to US-22) in too. Council A's people expect the lot."

## Working it

- **Agreement first.** The date is fixed by the product owner. The quality bar is NFR-SEC-01, BR-4 retention, BR-6 data separation and council A's contract terms. The review budget is two weeks of the product owner's and council A's service manager's UAT review. Council A's service manager is consulted for evidence; the product owner decides.
- **A contractual Must not on the skeleton.** The contract term is a legal obligation: shipping without online status would breach it (DSDM's *illegal* signal). Is there a workaround? Officers emailing status does not meet "online", so none that meets the obligation. **US-71 becomes a Must and is added to the skeleton** at "Submit and track", marked with its rule. Propose BR-8 (contractual, council A) to the FRD, and hand the re-cut to `story-mapping` (US-71 moves from Release 2 to the skeleton; re-cut log entry).
- **The regulatory Must is confirmed.** US-42: an applicant seeing another's drawings would breach data protection; no workaround meets the obligation. Stays on the skeleton.
- **US-41 is not a Must of this release.** With council A the only tenant, no officer can see another council's work. It becomes a regulatory Must (BR-6) of Release 3, which brings council B live: recorded in the change log now so it is not lost.
- **"EPIC-1 is 9/9" does not make its stories Musts.** DSDM judges each story. US-11 (type checklist) is on the skeleton: Must. US-12 designations: workaround, the officer confirms designations at validation, so Should. US-15 outage fallback only matters once a GIS call exists (US-12), and US-10 is the spike that unblocks US-12: the three are one Should bundle that is built together and dropped together, with the spike first (Cohn: knowledge gained, risk removed). US-14 tick-off: workaround, the applicant reads the checklist; least pain, Could. US-13 council-specific rules: with one council there is one rule set; Won't this time until Release 3.
- **The user's list would break two structural checks.** Promoting US-10, US-12, US-14, US-15 and US-20–US-22 puts seven Musts off the skeleton, each with a workaround, and leaves **no Should or Could** to drop before 1 March. That is a scope decision for the product owner, so the agent stops and puts the options instead of choosing:
  1. Keep the Musts at the skeleton (now with US-71); the designation bundle and tick-off are the contingency, built first.
  2. Make the designation checklist part of the release goal: then it is a different release, with a later date or a narrower first council journey.
  3. Accept a release with no contingency, recorded as a risk to 1 March.
  **The user (as product owner), 2026-11-24:** "Option 1. Build the designation checklist first; drawing checks stay in Release 2."
- **Report-only share.** 8 Musts of 35 stories in scope, 23% by count. A prompt, not a gate.

## Output — `ideate/moscow.md`

````markdown
---
name: moscow-prioritized-backlog
product: permitry
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-11-24
summary: Permitry Release 1 (council A, 1 March): 8 Musts = the walking skeleton, adding contractual US-71; the designation checklist bundle is contingency; one scope escalation recorded.
profile: enterprise
status: draft
release: Release 1 — Walking Skeleton (council A)
linked-story-map: ideate/story-map.md
linked-backlog: ideate/user-stories.md
traces_to: strategy/okrs.md (KR-1.2, KR-2.1); ideate/story-map.md (walking skeleton); ideate/user-stories.md (US-10–US-82); ideate/requirements.md (BR-4, BR-6, BR-8 proposed); ideate/nfr-specification.md (NFR-SEC-01)
---

# MoSCoW Prioritisation — Permitry, Release 1 (council A)

Priorities here are **final for this release**. They replace the provisional value / penalty scores for Release 1 only; Releases 2 and 3 are prioritised again when they come.

## Prioritisation Agreement

- **Constraint:** council A goes live 2027-03-01 (set by the product owner); quality bar NFR-SEC-01, BR-4, BR-6 and council A's service agreement; review budget two weeks of UAT review by the product owner and council A's service manager.
- **Who decides:** the product owner. The requirements-analyst facilitates and records. Consulted: council A's service manager (contract terms, evidence).
- **What drops first:** the Contingency list below, in its order.
- **Escalation:** a disputed Must goes to the product owner with the Must test, the workaround found and the skeleton consequence; recorded under Scope Escalations.

## Must Have (Minimum Usable SubseT = walking skeleton)

| Story | Journey step | Why Must (DSDM signal) | Workaround |
|---|---|---|---|
| US-40 Officers sign in with their own council's accounts | Bring the council on | Not viable: no officer can work without it | none |
| US-11 Applicant sees the checklist for their application type | Prepare an application | No point delivering: the release exists to raise first-submission validity | none |
| US-70 Applicant submits with documents | Submit and track | No point delivering: nothing reaches the council otherwise | none |
| US-42 Applicants see only their own applications | Submit and track | Illegal: applications hold personal data (NFR-SEC-01) | none that meets the obligation |
| US-71 Applicant tracks the application's status online | Submit and track | Illegal: council A's service agreement, schedule 2 (BR-8 proposed) | none that meets the obligation: emailed status is not "online" |
| US-80 Officer sees new applications in a queue | Validate | No point delivering: submissions are never picked up | none |
| US-81 Officer marks valid or invalid with missing items | Validate | No point delivering: no validation decision exists | none |
| US-82 Applicant is told what is missing | Hear the outcome | No point delivering: the applicant cannot fix the submission | none |

## Should Have

| Story | Pain if left out (value lost, who is affected) | Workaround this release | Kano (persona) |
|---|---|---|---|
| US-10 Spike: what council A's GIS returns for a site boundary | Unblocks US-12; carries its priority | — (a spike; see US-12) | not classified |
| US-12 Checklist adds the items the site's designations require | Invalid first submissions continue on designated sites (KR-1.2); applicants and officers both affected | Officer confirms designations at validation | Delighter (P-2 householder), directional |
| US-15 Applicant still gets a checklist when the GIS is down | Needed only with US-12 (NFR-REL-03) | Type-only checklist (US-11) while the GIS is down | Basic (P-2), directional |

## Could Have

| Story | Pain if left out | Workaround this release | Kano (persona) |
|---|---|---|---|
| US-14 Applicant ticks off documents as they upload them | Small: one convenience step | Applicant reads the checklist | Performance (P-2), directional |

## Won't Have this time

| Story | Why not now | Look again |
|---|---|---|
| US-13 Checklist follows the site's own council's rules | Only council A is live: one rule set | Release 3 |
| US-20, US-21, US-22 Drawing checks before submitting | Officers check drawings at validation, as today | Release 2 |
| US-23 Agent shares the drawing report with the architect | Needs the drawing checks | Later |
| US-30, US-31, US-32 Validation report for officers | Officers validate in full, as today | Release 2 |
| US-41 Officers see only their own council's applications | Only council A is live; becomes a regulatory Must (BR-6) when council B goes live | Release 3 |
| US-43 The public sees only the public register | No public register in Release 1; no rule requires it yet | Later |
| US-44 Council admins see refused cross-council attempts | Only one council | Release 3 |
| US-50, US-51, US-52, US-53 Council A moves off the legacy system | Open cases finish in the legacy system (manual skeleton cell); US-53 is a regulatory Must (BR-4) before switch-off | Release 2 |
| US-54, US-55, US-56, US-57, US-58, US-59, US-60, US-61 Councils B and C move off legacy | Councils B and C are not live | Release 3 |

## Contingency (cut order)

Dropped in this order if the release is under pressure. Build order: the US-10 → US-12 → US-15 bundle first (the product owner's decision, 2026-11-24).

1. US-14 Applicant ticks off documents as they upload them (Could) — least pain
2. US-10, US-12, US-15 Designation checklist bundle (Should) — built together, dropped together; the householder's Delighter, protected last

## Skeleton Check (two-way)

- **Skeleton → Must:** US-40, US-11, US-70, US-42, US-80, US-81 and US-82 are Musts. The tenant set-up and the open-cases migration stay manual cells (workarounds).
- **Must → skeleton:** US-71 is a contractual Must not on the skeleton; it is **added** at "Submit and track", marked "(contractual: BR-8)". US-42 (regulatory) is already marked there.
- **Re-cut for the story map:** move US-71 from Release 2 to the walking skeleton; add a re-cut log entry; propose BR-8 to the FRD (`requirements-analysis`).
- **Structural checks:** usable yes (council A's journey walks end to end); droppable tier present and ordered yes; every Must workaround-free yes.

## Priority Levels (project → release)

| Story | Provisional (value / penalty) | Release 1 | Note |
|---|---|---|---|
| US-11 | 9 / 9 | Must | On the skeleton |
| US-10, US-12 | 9 / 9, 9 / 8 | Should | Same 9/9 epic as US-11; judged story by story |
| US-13 | 7 / 9 | Won't this time | One council |
| US-14 | 5 / 4 | Could | |
| US-15 | 6 / 8 | Should | Bundled with US-12 |
| US-40, US-42 | 6 / 9 | Must | US-42 regulatory |
| US-41 | 6 / 9 | Won't this time | Must of Release 3 |
| US-70, US-71 | unscored (second impact map) | Must | US-71 contractual |

Report-only (never a gate): Musts are 8 of the 35 stories in scope (23%) by count.

## Priority Change Log

| Date | Story | From → to | Why | Decided by |
|---|---|---|---|---|
| 2026-11-24 | US-71 | Release 2 slice → Must R1 | Council A's service agreement, schedule 2 | the product owner |
| 2026-11-24 | US-41 | 6 / 9 → Won't R1; Must R3 | BR-6 binds once a second council is live | the product owner |
| 2026-11-24 | US-10, US-12, US-15 | 9 / 9, 9 / 8, 6 / 8 → Should R1, built first | Escalation decision below | the product owner |

## Scope Escalations

| Date | Check that failed | Options put to the product owner | Decision |
|---|---|---|---|
| 2026-11-24 | Proposed promotion of US-10, US-12, US-14, US-15, US-20–US-22: Musts off the skeleton with workarounds, and no Should / Could left to drop | Keep Musts = skeleton · redefine the release goal (later date or narrower journey) · accept no contingency as a risk | "Option 1. Build the designation checklist first; drawing checks stay in Release 2." |
````

## Why this is right at enterprise

| Choice | Reason |
|---|---|
| US-71 a Must, added to the skeleton | A contract term is a legal obligation; a workaround that fails it does not count; the two lists must stay equal |
| Re-cut handed to the story map | MoSCoW confirms the skeleton; it never leaves the map disagreeing |
| US-41 deferred, its future Must recorded | Priority is per release (DSDM); the rule binds when a second tenant exists |
| A 9/9 epic split across Must, Should, Could, Won't | DSDM decomposition, story by story |
| Spike and fallback bundled with US-12 | Stories that only work together drop together; Cohn's knowledge and risk factors set the build order |
| The agent stopped and offered options | Priority belongs to the product owner; the analyst records the decision |
| 23% by count, labelled report-only | The optional enterprise signal, never a gate (D045) |
| Value / penalty kept beside the bins | Project-level and release-level priorities are different levels |
