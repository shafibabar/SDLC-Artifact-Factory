# Example 2 — Standard: epics rearranged into a journey, a skeleton with existing and manual cells, and the two-way Must check against "the whole epic is high, so it's all Must"

Self-contained. **Rebound** is appointment software for independent physiotherapy clinics (one to eight practitioners), at the **standard** profile, where the story map is **required**. It continues Rebound's impact map and epic list: three epics from the selected path, eleven stories. It shows stories placed by journey step rather than by epic, a walking skeleton that uses an existing capability and a manual step, slices named by outcome with the impact map's signal and re-plan trigger, and the two-way check between the skeleton and the Musts.

## Input

> **User:** "Let's do the story map. EPIC-1 and EPIC-2 are both high, so all eight of their stories are Musts for the first release, and the reminder especially: no-shows are the whole point. Anyway, Patton says a release slice isn't a Must cut, so the map and MoSCoW don't have to agree."
>
> **Impact map (approved):** KR-2.1, no-show rate 12% → 7% by 2027-03-31. Selected path: patient booked 2+ weeks ahead → confirms or cancels ahead instead of silently not turning up. Deliverables: SOL-3 reply-to-confirm request 72 h before, unconfirmed slots offered to the waitlist; SOL-1 SMS reminder 24 h before; SOL-2 front desk phones long-gap bookings (procedure); day-end diary copy (blocker branch). Signal: reply rate per confirm request; no-show rate. Re-plan trigger: reply rate under 70% after four weeks → the calendar-file option. Options: calendar file; deposit at booking.
>
> **Epics and stories (provisional priority):** EPIC-1 Front desk refills the slots of long-gap patients who aren't coming (high): US-1 patient receives a confirm request; US-2 patient's reply confirms or cancels; US-3 front desk sees unrecognised replies; US-4 front desk sees who is unconfirmed at the cut-off; US-5 waitlisted patients are offered a freed slot in order. EPIC-2 Patients cancel from the reminder (high): US-6 reminder the day before; US-7 cancel by replying to the reminder; US-8 cancellation confirmation. EPIC-3 Paper-diary bookings get reminders too (medium): US-9 enter the day's paper bookings; US-10 clash warning; US-11 bring future paper bookings in before go-live.
>
> **Personas:** P-2 front desk (primary), P-3 patient. Both design-partner clinics book in Rebound's diary today; a third clinic still uses paper.

## Working it

- **The journey, not the epics, sets the columns.** EPIC-1's stories happen at three different points (the request goes out, the front desk follows up, the slot is refilled), so they spread across the backbone, tagged EPIC-1.
- **Narrated with the user:** "The appointment is in the diary. Long-gap patients get a confirm request and answer it. Before the cut-off, the front desk sees who hasn't answered. Freed slots go to the waitlist." The user added that patients also answer the 24 h reminder; it joined "Patients answer" as a lower row.
- **Skeleton cells.** "Fill the diary" is met by an **existing** capability (both partner clinics book in Rebound). "Refill the slot" is a **manual** step: the front desk phones waitlisted patients using the unconfirmed list. Ugly, but it walks.
- **"A slice isn't a Must cut" is the old wording; this plugin's rule is the opposite.** The release's Musts are DSDM's Minimum Usable SubseT, which is the walking skeleton. Checked both ways.
- **"High epic = all Must" fails the workaround clause.** DSDM judges a Must epic's stories one by one. US-3: the front desk can read odd replies in the SMS inbox. US-5: the front desk can phone the waitlist. US-6 to US-8: the confirm request already lets a long-gap patient cancel. Each has a workaround, so none is a Must, and none sits on the skeleton.
- **The reminder is on the selected path but not on the skeleton.** Selected means "in scope for the bet", not "first release".
- **Options stay off the map.** The calendar file appears only as the re-cut trigger's destination.

## Output — `ideate/story-map.md`

````markdown
---
name: story-map
product: rebound
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-28
summary: Rebound's front-desk no-show journey; a 3-story walking skeleton (confirm request, reply, unconfirmed list) as the Must set, then automatic refills and paper-diary clinics.
profile: standard
status: draft
primary-persona: P-2 front desk
linked-kr: KR-2.1
linked-impact-map: ideate/impact-map.md
linked-epics: ideate/epics.md
traces_to: strategy/okrs.md (KR-2.1); ideate/impact-map.md (selected path: SOL-1, SOL-3, day-end copy); ideate/epics.md (EPIC-1–EPIC-3); ideate/user-stories.md (US-1–US-11)
---

# User Story Map — Rebound

## Big Picture

- **Outcome:** KR-2.1, no-show rate 12% → 7% by 2027-03-31
- **Selected path:** patient booked 2+ weeks ahead → confirms or cancels ahead instead of silently not turning up → SOL-3, SOL-1, day-end diary copy
- **Primary persona:** P-2 front desk; also acting: P-3 patient (answers)
- **Not on this map:** SOL-2 phoning long-gap bookings (procedure, front-desk guide); calendar file and deposits (options, impact map)

## Narrated Spine

First the appointment is in the diary. Then the patient booked a fortnight or more ahead gets a confirm request, and answers it. Before the 48-hour cut-off, the front desk sees who has not answered. Then the front desk fills the slots of patients who are not coming from the waitlist.

**Narrated with the user on 2026-10-28:** the user added that patients also answer the 24 h reminder (US-7, lower row under "Patients answer"); order unchanged.

## Story Map

| | Fill the diary (front desk) | Ask long-gap patients (front desk) | Patients answer (patient) | Act before the cut-off (front desk) | Refill the slot (front desk) |
|---|---|---|---|---|---|
| **Tasks** | Book appointments; copy paper bookings | Send confirm request; send reminder | Confirm or cancel; get confirmation | See unconfirmed; handle odd replies | Offer freed slot to waitlist |
| **Walking skeleton (Release 1)** | (existing: appointments booked in Rebound's diary) | US-1 | US-2 | US-4 | (manual: front desk phones waitlisted patients from the US-4 list) |
| **Release 2 — refills run themselves** | — | US-6 | US-7, US-8 | US-3 | US-5 |
| **Release 3 — paper-diary clinics join** | US-9, US-11, US-10 | — | — | — | — |

Epic tags: EPIC-1: US-1–US-5 · EPIC-2: US-6–US-8 · EPIC-3: US-9–US-11

## Release Slices

The first slice is the first concrete test of the roadmap's Now horizon; this map's arrival is a roadmap revision trigger (`roadmap-authoring`).

### Release 1 — Walking Skeleton

**Outcome:** at the two partner clinics, the front desk knows before the cut-off which long-gap patients are not coming, and can fill those slots.
**Stories:** US-1, US-2, US-4 · existing: diary booking · manual: phoning the waitlist
**Walks end to end:** the appointment is in the diary → the patient gets a confirm request → replies "C" or "X" → the front desk sees the four who haven't answered → phones the waitlist for the freed slot.
**MVP kind:** Release-MVP (ships to real users), not a learning experiment
**Signal:** reply rate per confirm request; no-show rate
**Re-cut trigger:** reply rate under 70% after four weeks → bring the calendar-file option onto the map (through a new epic) before Release 2

### Release 2 — Refills run themselves

**Outcome:** freed slots reach the waitlist without phoning, and every patient can cancel from the day-before reminder.
**Stories:** US-6, US-7, US-8, US-3, US-5
**Signal:** late cancellations per no-show; slots refilled per week
**Re-cut trigger:** if Release 1's reply rate is under 70%, Release 2 is re-cut around the calendar-file option

### Release 3 — Paper-diary clinics join

**Outcome:** a clinic still on paper copies each day's bookings in, so its patients get the same requests and reminders.
**Stories:** US-9, US-11, US-10
**Signal:** bookings found only on paper in a weekly spot check
**Re-cut trigger:** front desks skip the day-end copy for two weeks running (ASM-2 fails) → revisit with the clinic before building more

## Must Check (walking skeleton = Minimum Usable SubseT)

Proposed for `moscow-prioritization`, which confirms it at release level. Priorities shown are provisional.

| Story | Activity | On skeleton? | Provisional priority | Must for Release 1? | Note |
|---|---|---|---|---|---|
| US-1 | Ask long-gap patients | yes | high | yes | |
| US-2 | Patients answer | yes | high | yes | |
| US-4 | Act before the cut-off | yes | high | yes | |
| US-3 | Act before the cut-off | no | high | no | Workaround: front desk reads odd replies in the SMS inbox |
| US-5 | Refill the slot | no | high | no | Workaround: front desk phones the waitlist (manual skeleton cell) |
| US-6 | Ask long-gap patients | no | high | no | Workaround: the confirm request already lets a long-gap patient cancel |
| US-7 | Patients answer | no | high | no | As US-6 |
| US-8 | Patients answer | no | high | no | As US-6 |
| US-9 | Fill the diary | no | medium | no | Partner clinics book in Rebound already |
| US-10 | Fill the diary | no | medium | no | As US-9 |
| US-11 | Fill the diary | no | medium | no | As US-9 |

- **Skeleton → Must:** US-1, US-2 and US-4 are the Musts. US-5 was a candidate for "Refill the slot"; it has a manual workaround, so the cell is the manual step instead and the skeleton still walks.
- **Must → skeleton:** no Must off the skeleton. No legal, safety or regulatory story needs adding (BR-3, reminder text names clinic, date and time only, is a rule inside US-1 and US-6).

## Gaps, Orphans and Open Questions

| Item | Kind | Proposed action |
|---|---|---|
| Patients booked under 14 days ahead get no request in Release 1 | Scope note | Intended (the selected path's actor); the reminder reaches them in Release 2 |
| None | Orphan | Every story US-1–US-11 is placed |
````

## Why this is right at standard

| Choice | Reason |
|---|---|
| EPIC-1 spread across three columns | Narrative order beats epic grouping |
| Existing and manual skeleton cells | The journey walks; nothing on the skeleton has a workaround |
| Three Musts, not eight | The workaround clause, story by story (DSDM), and the two-way check |
| The reminder in Release 2 | On the selected path, not needed to walk |
| Signal and re-cut trigger from the impact map | The map is re-cut on the same evidence the bet is judged on |
| Option branches named only in Big Picture | Kept off the map |
