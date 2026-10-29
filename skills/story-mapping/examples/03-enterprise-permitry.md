# Example 3 — Enterprise: three personas on one backbone, a skeleton for one pilot council with a regulatory Must added, and "onboard every council first" rejected (hardest case)

Self-contained. **Permitry** is a multi-tenant SaaS platform for local councils to receive and decide building and planning permit applications. Each council is a tenant; three pilot councils (A, B, C) are replacing a fifteen-year-old on-premises permits system, each with its own data, rules and cut-over date. At the **enterprise** profile the story map is **required** and adds: several personas on one backbone, a skeleton that crosses tenant set-up for one tenant, regulatory Musts added to the skeleton and marked, per-tenant slices, epics from more than one impact map, NFR hand-off items against the skeleton, and a re-cut log.

## Input

> **User:** "Release 1 should be the whole council onboarding for all three councils (EPIC-4 and EPIC-5A, 5B and 5C) so the platform is solid before any applicant feature ships. And please do three maps, one each for the council admin, the applicant and the officer."
>
> **Impact maps:** *complete-first-submissions* (KR-1.2, first-submission validity 41% → 70% by 2027-09-30): selected path SOL-1 document checklist, SOL-2 pre-submission drawing validation, SOL-4 validation report; signal: first-submission validity rate per council; re-plan trigger: validity under 55% at council A after eight weeks → the pre-application advice option (SOL-3). *decide-within-statutory-period* (KR-2.1): selected path includes online submission and an officer validation queue.
>
> **Epics and stories (provisional value / penalty):** EPIC-1 checklist (9/9): US-10 spike on each council's GIS, US-11 checklist for the application type, US-12 items the site's designations add, US-13 the site's own council's rules, US-14 tick off documents on upload, US-15 checklist when the GIS is down. EPIC-2 drawings (8/6): US-20 drawings checked on upload, US-21 applicant sees which drawing fails and why, US-22 applicant replaces a failed drawing before submitting, US-23 agent shares the drawing report with the architect. EPIC-3 validation report (8/7): US-30 officer sees what the system already checked, US-31 items needing judgement first, US-32 decision recorded with reasons. EPIC-4 isolation (6/9): US-40 officers sign in with their own council's accounts, US-41 officers see only their own council's applications, US-42 applicants see only their own applications, US-43 the public sees only the public register, US-44 council admins see refused cross-council attempts. EPIC-5A/B/C per-council transition (7/9): US-50–US-53 (council A: open cases arrive, weekly reconciliation, rollback, closed cases archived before switch-off), US-54–US-57 (B), US-58–US-61 (C). From the second map: EPIC-6 applicants submit and track (US-70 submit with documents, US-71 track status); EPIC-7 officers work a validation queue (US-80 see new applications, US-81 mark valid or invalid with missing items, US-82 applicant told what is missing).
>
> **Rules and NFRs:** BR-4 15-year retention; BR-6 each council's data is its own; applications hold personal data (names, addresses, drawings). NFR-SEC-01 no cross-council or cross-applicant disclosure (H, H); NFR-REL-03 GIS failure must not block submission (H, H); NFR-PERF-02 one council's migration must not slow the others.

## Working it

- **One backbone, three personas.** Separate maps would hide the hand-offs (the applicant submits, the officer validates, the applicant hears back), which is where permit journeys fail. Each activity names its persona.
- **The journey crosses two impact maps.** Submission and the officer queue come from *decide-within-statutory-period*; without them the checklist has nowhere to go. Both maps' selected-path epics are placed; neither map's options appear.
- **"Onboard all three councils first" is the vertical slice at tenant scale.** A perfect onboarding activity with no applicant able to submit anything moves no Key Result and tests nothing. The skeleton walks end to end for **council A only**; councils B and C are a later slice.
- **Skeleton cells that are ugly but walk.** Council A's tenant is created by Permitry operations from a runbook (manual). Council A's open cases finish in the legacy system while Permitry takes new applications (manual): a workaround, so EPIC-5A is not a Release 1 Must (DSDM's workaround clause).
- **A regulatory Must added to the skeleton.** The journey walks without US-42, but applications carry personal data, so an applicant seeing another's drawings is a data-protection breach. It is a regulatory Must, so it is **added to the skeleton** at the step it protects, and marked. US-41 (officers see only their own council's work) is not needed while council A is the only tenant; it becomes a regulatory Must of the release that brings council B live.
- **The thinnest checklist is type-only.** US-11 alone gives a checklist for the application type, with no GIS call, so NFR-REL-03 does not bind Release 1. Designations, the GIS spike and the outage fallback come in Release 2.

## Output — `ideate/story-map.md`

````markdown
---
name: story-map
product: permitry
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-11-20
summary: Permitry's applicant-to-officer permit journey across two impact maps; council A's walking skeleton with a regulatory Must (US-42), then complete first submissions, then councils B and C.
profile: enterprise
status: draft
primary-persona: P-2 householder applicant
linked-kr: KR-1.2, KR-2.1
linked-impact-map: ideate/impact-maps/complete-first-submissions.md, ideate/impact-maps/decide-within-statutory-period.md
linked-epics: ideate/epics.md
traces_to: strategy/okrs.md (KR-1.2, KR-2.1); ideate/impact-maps/complete-first-submissions.md (SOL-1, SOL-2, SOL-4); ideate/impact-maps/decide-within-statutory-period.md (selected path); ideate/epics.md (EPIC-1–EPIC-7); ideate/user-stories.md (US-10–US-82)
---

# User Story Map — Permitry

## Big Picture

- **Outcome:** KR-1.2 first-submission validity 41% → 70% by 2027-09-30; KR-2.1 (decisions within the statutory period)
- **Selected paths:** applicant submits a complete application first time → SOL-1, SOL-2, SOL-4; officers validate from a queue → online submission and validation queue
- **Primary persona:** P-2 householder applicant; also acting: P-1 planning agent (applicant), P-3 validation officer, council admin, council records manager
- **Not on this map:** SOL-3 pre-application advice and chat help (options, impact map); TR-5 officer training (procedure, go-live checklist)

## Narrated Spine

First a council is brought onto Permitry and its staff sign in. An applicant then prepares an application against a checklist, submits it and tracks it. A validation officer picks it up from the queue, checks it and marks it valid or invalid. The applicant hears the outcome, including anything missing. Once Permitry is the council's record, the council moves its open cases over and switches the old system off.

**Narrated with the user on 2026-11-20:** the user asked for three maps; kept as one backbone with personas named per activity, because the hand-offs between applicant and officer are where the journey breaks. The user added "hear the outcome" as its own step (it was inside "Validate").

## Story Map

| | Bring the council on (council admin) | Prepare an application (applicant) | Submit and track (applicant) | Validate (officer) | Hear the outcome (applicant) | Move off the legacy system (records manager) |
|---|---|---|---|---|---|---|
| **Tasks** | Create the council; staff sign in; keep councils apart | See the checklist; check drawings | Submit; track status | Work the queue; see what is checked; decide | Told valid, or what is missing | Bring open cases over; reconcile; switch off |
| **Walking skeleton (Release 1)** | (manual: operations creates council A's tenant from the runbook), US-40 | US-11 | US-70, US-42 (regulatory: personal data, NFR-SEC-01) | US-80, US-81 | US-82 | (manual: council A's open cases finish in the legacy system; Permitry takes new applications) |
| **Release 2 — council A: complete first submissions** | — | US-10, US-12, US-13, US-15, US-14, US-20, US-21, US-22 | US-71 | US-30, US-31, US-32 | — | US-50, US-51, US-52, US-53 (regulatory: BR-4) |
| **Release 3 — councils B and C go live** | US-41 (regulatory: BR-6), US-44 | — | — | — | — | US-54–US-57, US-58–US-61 (regulatory: BR-4) |
| **Later** | — | US-23 | US-43 | — | — | — |

Epic tags: EPIC-1: US-10–US-15 · EPIC-2: US-20–US-23 · EPIC-3: US-30–US-32 · EPIC-4: US-40–US-44 · EPIC-5A/B/C: US-50–US-61 · EPIC-6: US-70, US-71 · EPIC-7: US-80–US-82

## Release Slices

The first slice is the first concrete test of the roadmap's Now horizon; this map's arrival is a roadmap revision trigger (`roadmap-authoring`).

### Release 1 — Walking Skeleton (council A)

**Outcome:** at council A, a householder submits an application from a type-based checklist, and the officer validates it from a queue and tells them what is missing.
**Stories:** US-40, US-11, US-70, US-42, US-80, US-81, US-82 · manual: tenant from runbook; open cases stay in legacy
**Walks end to end:** council A's officers sign in → a householder sees the checklist for an extension → submits → an officer picks it up and marks it invalid, missing a heritage statement → the householder is told exactly that.
**MVP kind:** Release-MVP (ships to council A's real applicants), not a learning experiment
**Signal:** first-submission validity rate at council A
**Re-cut trigger:** validity under 55% at council A after eight weeks → bring SOL-3 (pre-application advice) onto the map through a new epic before Release 3

### Release 2 — Council A: complete first submissions

**Outcome:** council A's applicants get site-specific checklists and drawing checks; officers check only what needs judgement; council A switches its legacy system off.
**Stories:** US-10, US-12, US-13, US-15, US-14, US-20, US-21, US-22, US-71, US-30, US-31, US-32, US-50–US-53
**Signal:** validity rate at council A; manual re-checks per application
**Re-cut trigger:** as Release 1; also, US-10 finding a GIS without designations re-cuts US-12 for that council

### Release 3 — Councils B and C go live

**Outcome:** councils B and C run the whole journey on Permitry, each seeing only its own work, and retire their legacy systems.
**Stories:** US-41, US-44, US-54–US-61
**Signal:** validity rate per council; refused cross-council attempts (expected zero)
**Re-cut trigger:** a reconciliation difference left unexplained for two weeks at either council holds that council's switch-off

## Must Check (walking skeleton = Minimum Usable SubseT)

Proposed for `moscow-prioritization`, which confirms it at release level. Priorities shown are provisional (value / penalty).

| Story | Activity | On skeleton? | Provisional priority | Must for Release 1? | Note |
|---|---|---|---|---|---|
| US-40 | Bring the council on | yes | 6 / 9 | yes | |
| US-11 | Prepare | yes | 9 / 9 | yes | |
| US-70 | Submit and track | yes | — (second map) | yes | |
| US-42 | Submit and track | yes | 6 / 9 | yes | Regulatory: personal data; added to the skeleton |
| US-80, US-81 | Validate | yes | — (second map) | yes | |
| US-82 | Hear the outcome | yes | — (second map) | yes | |
| US-50–US-53 | Move off legacy | no | 7 / 9 | no | Workaround: open cases finish in legacy; US-53 is a regulatory Must of Release 2, before switch-off (BR-4) |
| US-41 | Bring the council on | no | 6 / 9 | no | Only council A is live; regulatory Must of Release 3 (BR-6) |
| US-12, US-13 | Prepare | no | 9 / 9 | no | Workaround: officer confirms designations at validation |
| All other stories | — | no | — | no | Later slices; prioritised when their release comes |

- **Skeleton → Must:** US-40, US-11, US-70, US-42, US-80, US-81, US-82. The open-cases migration was a candidate for the last step; it has a workaround, so the cell is the manual step.
- **Must → skeleton:** no Must off the skeleton. US-42 (regulatory) was added at "Submit and track", the step where an applicant would otherwise see another's application.

## NFR Hand-off on the Skeleton

| Story | NFR | Why it matters for Release 1 |
|---|---|---|
| US-42 | NFR-SEC-01 | No applicant may open another's application |
| US-11 | NFR-REL-03 | Not bound: the type-only checklist makes no GIS call; binds US-12 and US-15 in Release 2 |
| — | NFR-PERF-02 | Not bound: no migration in Release 1 |

## Gaps, Orphans and Open Questions

| Item | Kind | Proposed action |
|---|---|---|
| Application fees | Gap? | No selected-path deliverable covers payment; the user confirms whether council A takes fees outside Permitry in Release 1 (manual) |
| US-43 public register | Placed in Later | Not needed to walk; no rule requires it before Release 3 |
| None | Orphan | Every story is placed |

## Re-cut Log

| Date | What moved | Why |
|---|---|---|
| 2026-11-20 | US-41 from the skeleton to Release 3 | Only council A is live in Release 1; it becomes a regulatory Must of the release that brings council B live |
| 2026-11-20 | EPIC-4 and EPIC-5A/B/C as Release 1 (user's proposal) not adopted | Vertical slice at tenant scale: no applicant could complete anything |
````

## Why this is right at enterprise

| Choice | Reason |
|---|---|
| One backbone, personas per activity | The hand-offs are where the journey fails; three maps hide them |
| Skeleton for council A only | One tenant walking end to end before others; other councils are an outcome slice |
| "Onboard all councils first" refused | A vertical slice at tenant scale, moving no Key Result |
| US-42 added to the skeleton, marked | A regulatory Must off the journey joins the skeleton (two-way check) |
| US-41 deferred to Release 3, where it becomes a Must | Priority is per release (DSDM); the rule binds once a second tenant exists |
| Migration as a manual cell | Workaround exists, so not a Release 1 Must |
| Epics from two impact maps | The journey crosses both; options from neither appear |
| NFR hand-off and re-cut log | Enterprise traceability for Design and later releases |
