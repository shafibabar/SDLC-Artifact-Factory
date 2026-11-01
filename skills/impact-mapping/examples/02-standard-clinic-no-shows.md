# Example 2 — Standard: one map fed by the opportunity solution tree, with a blocker

Self-contained. **Rebound** is appointment software for independent physiotherapy clinics (one to eight practitioners), at the **standard** profile, where the impact map is **optional**; the user asked for one because a blocker was suspected. It continues the opportunity solution tree in `opportunity-solution-tree`'s standard example: the tree's outcome becomes the goal, its target opportunity explains the selected impact, and its three carried-forward solutions are the WHAT candidates on the path.

## Input

> **Tree (ideate/opportunity-solution-tree.md, approved):** desired outcome "no-show rate 12% → 7% by 2027-03-31", constraint "cancellation-fee disputes ≤ 1% of appointments"; product outcome reclassified from KR-2.1 "70% of active clinics enable SMS reminders by end of Q1" (a traction metric). Target **OPP-3.1** "Patients forget appointments booked weeks ahead". Carried forward: SOL-1 SMS reminder 24 h before; SOL-2 front desk phones tomorrow's long-gap bookings; SOL-3 reply-to-confirm 72 h before, unconfirmed slots offered to the waitlist. Assumptions A-1…A-6 (A-4 ethical: the text reveals nothing about treatment); tests T-1…T-3.
>
> **Personas:** P-1 clinic owner, P-2 front desk, P-3 patient. **Snapshot note:** at C-3 and C-4 one practitioner keeps their own paper diary.

## Working it

- **WHY from the tree, in fields.** Metric, meter, baseline, target, deadline and constraint are copied; nothing is invented.
- **WHO by the four questions.** Produce: patients with long-gap bookings. Obstruct: the practitioner who keeps a paper diary (bookings never reach the system, so no reminder goes out). Use: front desk. Affected: whoever else reads the patient's phone (the source of the ethical assumption).
- **WHY → WHO → HOW confirmed with the user** before any deliverable was written.
- **WHAT.** Under the patient's impact, the tree's SOL-1…3 are the candidates; nothing is re-generated. Under the blocker's impact, two passes: pass one "paper-diary import", pass two (constraint: "no new code") "front desk copies the paper diary in at day end" and "owner's rule: no booking outside Rebound".
- **Path.** Patient → confirms or cancels ahead → OPP-3.1 → SOL-1, SOL-3 (tested side by side in T-1) plus SOL-2 as the non-software arm; and the blocker's cheapest unblocking option, because without it the path fails at two of five clinics.

## Output — `ideate/impact-map.md`

````markdown
---
name: impact-map
product: rebound
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-22
summary: No-shows 12% → 7%; path is patients confirming or cancelling ahead (OPP-3.1) via reminders and confirm requests, with paper-diary bookings brought into Rebound.
profile: standard
goal: no-show rate in clinics' diaries, 12% → 7% by 2027-03-31
linked-kr: KR-2.1
linked-tree: ideate/opportunity-solution-tree.md
target-opportunity: OPP-3.1
selected-path: patient → confirms or cancels ahead → SOL-1/SOL-3 vs SOL-2; practitioner → books in Rebound
traces_to: strategy/okrs.md (KR-2.1); ideate/opportunity-solution-tree.md (OPP-3.1, SOL-1…3, A-1…A-6, T-1…T-3); ideate/personas.md (P-1…P-3)
---

# Impact Map — Rebound: fewer no-shows

## Goal (WHY)

| Field | Value |
|---|---|
| Metric | Share of booked appointments marked "did not attend" |
| Meter | Diary status, all active clinics, rolling 4 weeks |
| Baseline | 12% (September 2026) |
| Target | 7% |
| Deadline | 2027-03-31 |
| Constraint | Cancellation-fee disputes stay at or below 1% of appointments |
| Linked KR | KR-2.1: "70% of active clinics enable SMS reminders by end of Q1" |
| Source | Desired outcome of ideate/opportunity-solution-tree.md; a product outcome (KR-2.1 is a traction metric) |

## Actors (WHO)

| Actor | Type | Why on the map | Source |
|---|---|---|---|
| Patient with a booking 2+ weeks ahead | Primary | Turning up, or cancelling in time, is the metric | P-3 |
| Front desk | Secondary | Refills released slots; runs the phone option | P-2 |
| Practitioner with a paper diary | Blocker | Bookings kept on paper get no reminder and no confirm request | Snapshots 2026-10-08-c-3, 2026-10-10-c-4 |
| Clinic owner | Off-stage | Decides policy (deposits, booking rules); pays | P-1 |
| Someone else reading the patient's phone | Off-stage (affected) | Sees whatever the reminder says | Who-is-affected question |

## Map

### Actor: Patient with a booking 2+ weeks ahead — Primary

| Impact (HOW: behaviour change) | Opportunity (tree) | Deliverable (WHAT: option) | Path | Assumption | Signal |
|---|---|---|---|---|---|
| Confirms or cancels ahead instead of not turning up | OPP-3.1 "Patients forget appointments booked weeks ahead" | SOL-3 Reply-to-confirm 72 h before; unconfirmed slots to the waitlist (software) | selected | [usability] if asked to reply, most patients reply within a day | Share of 72 h requests answered; no-show rate in test clinics |
| | | SOL-1 SMS reminder 24 h before (software) | selected | [desirability] patients read a clinic text within a day | No-show rate in test clinics |
| | | SOL-2 Front desk phones tomorrow's long-gap bookings (non-software) | selected | [viability] front desks have ten free minutes a day | Same, in the phoning clinic |
| | | Calendar-file attachment on booking email (software) | option | [desirability] patients add it to their calendar | Share of bookings with the file opened |
| Stops booking six weeks out at the desk when unsure of their plans | OPP-1.1 "…forget which ones they booked" | Front desk offers "book one, we'll text you to book the next" (non-software) | option | [desirability] patients accept a shorter horizon | Median booking lead time |

### Actor: Practitioner with a paper diary — Blocker

| Impact (HOW: behaviour change) | Opportunity (tree) | Deliverable (WHAT: option) | Path | Assumption | Signal |
|---|---|---|---|---|---|
| Enters every booking in Rebound the same day instead of only in the paper diary | — not on tree (an in-clinic habit, not a patient need) | Front desk copies the paper diary into Rebound at day end (non-software) | selected | [viability] the front desk can absorb five minutes a day | Share of a clinic's attended appointments that were in Rebound beforehand |
| | | Owner's rule: no booking outside Rebound (non-software, policy) | option | [desirability] practitioners comply without resentment | Same |
| | | Paper-diary photo import (software) | option | [feasibility] handwriting is read reliably | Same |

### Actor: Front desk — Secondary

| Impact (HOW: behaviour change) | Opportunity (tree) | Deliverable (WHAT: option) | Path | Assumption | Signal |
|---|---|---|---|---|---|
| Offers a released slot to the waitlist the same day instead of leaving it empty | OPP-4.1 "We only learn about a cancellation when the slot is already gone" | Waitlist offer bundled with SOL-3 (software) | option | [feasibility] slots released 72 h ahead can be re-filled | Share of released slots refilled |

### Actor: Clinic owner — Off-stage

One-line placeholder: deposit at booking (tree SOL-5, parked on viability and ethics doubts). Not detailed this cycle.

## Selected Path

**Patient (2+ weeks ahead) → confirms or cancels ahead → OPP-3.1 → SOL-3 and SOL-1 compared, SOL-2 as the non-software arm; plus paper-diary bookings copied in at day end.** OPP-3.1 is the tree's target, chosen by the user; the blocker branch joins the path because two of five design-partner clinics would otherwise send no reminders at all. Confirmed by the user on 2026-10-22.

| ID | Link | Assumption | Type | Evidence today | Test |
|---|---|---|---|---|---|
| PA-1 | SOL-1 / SOL-3 → confirms or cancels ahead | Patients read a clinic text within a day | desirability | none | T-1 (tree) |
| PA-2 | SOL-3 → confirms or cancels ahead | Patients reply to confirm when asked | usability | none | T-1 (tree) |
| PA-3 | SOL-1 / SOL-3 → confirms or cancels ahead | The text reveals nothing about treatment to someone else reading the phone | ethical | none | T-3 (tree) |
| PA-4 | SOL-2 → confirms or cancels ahead | Front desks have ten free minutes a day to phone | viability | 2026-10-13-c-5 says no | T-2 (tree) |
| PA-5 | Day-end copy → books in Rebound | Front desk can copy a day's paper bookings in under 5 minutes | viability | none | New: C-3 logs copying time for one week; criterion set 2026-10-22: under 5 min on 4 of 5 days |
| PA-6 | Confirms or cancels ahead → no-show rate | Patients who cancel ahead free slots that get refilled, so no-shows fall | viability | waitlist data, 3 clinics | Measured through the T-1 clinics' no-show rate |

## Re-plan Trigger

- **Deliverable guess wrong:** if fewer than 70% of 72 h requests are answered and no-shows in the T-1 clinics stay above 10% after four weeks, drop SOL-3 and try the calendar-file option under the same impact.
- **Impact → goal link wrong:** if patients confirm or cancel ahead but no-shows stay above 10% by 2027-01-31, return to the tree: compare OPP-3.2 (feeling better) and OPP-4.1.
- **Blocker not removed:** if C-3 or C-4 still has under 90% of attended appointments in Rebound after two weeks, move to the owner's-rule option.

## Not Mapped This Cycle

- KR-2.2 (clinic onboarding time): no tree yet; next cycle.

## Hand-off

- `requirements-analysis`: functional requirements trace to SOL-1, SOL-3 and the day-end copy procedure (SOL-2 is a front-desk procedure, documented, not built).
- `epic-definition`: candidate epics "Reminders and confirm requests" (SOL-1 + SOL-3) and "Day-end diary catch-up" (a checklist screen for the copy), each with its impact as hypothesis and its signal as success measure.
- `story-mapping`: those epics form the backbone; the walking skeleton is decided there. Option rows stay off the story map.
- `moscow-prioritization`: finalises priority on the resulting stories.
- Next discovery cycle: the blocker impact (not on tree), OPP-1.1, results of T-1…T-3 and PA-5.

## Version Log

| Version | Date | Change | Trigger |
|---|---|---|---|
| 1.0.0 | 2026-10-22 | First map | Ideate, cycle 1 |
````

## Why this is right at standard

| Choice | Reason |
|---|---|
| Goal copied from the tree's root, in fields | The tree already reclassified the traction-metric KR; the map does not re-argue it |
| SOL-1…3 taken as given | The tree compared them; re-generating would bypass that comparison |
| A blocker the tree could not see | The tree holds patient needs; the paper diary is a clinic habit, so its row says "not on tree" |
| Non-software options selected | The day-end copy and the phone arm cost no code |
| Path / Assumption / Signal, no priority | MoSCoW finalises priority later; options are not "Could"s |
| PA-3 is ethical | Someone else reading the phone is an affected actor |
| Re-plan trigger names both failure kinds | Wrong deliverable vs wrong impact → goal link lead to different next moves |
