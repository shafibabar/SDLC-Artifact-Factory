# Example 2 — Standard: the walking skeleton confirmed as the Musts, "it's Kano-Basic, so it's a Must" taken apart, and a Delighter protected in the cut order

Self-contained. **Rebound** is appointment software for independent physiotherapy clinics (one to eight practitioners), at the **standard** profile, where `ideate/moscow.md` is **required**. It continues Rebound's story map: a three-story walking skeleton (US-1 confirm request, US-2 reply, US-4 unconfirmed list), an existing cell (appointments already booked in Rebound's diary) and a manual cell (the front desk phones the waitlist). MoSCoW confirms the skeleton at release level, bins the other eight stories, and orders the contingency.

## Input

> **User:** "Two changes before we sign off Release 1. US-5 has to be a Must: the front desk hates phoning the waitlist. And the reminder, US-6: our Kano pass says patients rate it Basic, everyone expects a reminder, so that's a Must too. We pilot at the two partner clinics from 11 January."
>
> **Story map (ideate/story-map.md, approved):** backbone Fill the diary → Ask long-gap patients → Patients answer → Act before the cut-off → Refill the slot. Walking skeleton: (existing: appointments booked in Rebound's diary) · US-1 · US-2 · US-4 · (manual: front desk phones waitlisted patients from the US-4 list). Release 2 "refills run themselves": US-6, US-7, US-8, US-3, US-5. Release 3 "paper-diary clinics join": US-9, US-11, US-10.
>
> **Stories (provisional):** EPIC-1 (high): US-1 patient receives a confirm request for a long-gap appointment; US-2 patient's reply confirms or cancels; US-3 front desk sees unrecognised replies; US-4 front desk sees who is still unconfirmed at the cut-off; US-5 waitlisted patients are offered a freed slot in order. EPIC-2 (high): US-6 patient receives a reminder the day before; US-7 patient cancels by replying to the reminder; US-8 patient gets a cancellation confirmation. EPIC-3 (medium): US-9 front desk enters the day's paper bookings; US-10 clash warning; US-11 bring future paper bookings in before go-live.
>
> **Kano pass (interview snapshots, 6 front desks and 9 patients, directional):** US-6 Basic (P-3 patient); US-5 Delighter (P-2 front desk); US-3 Indifferent for patients, Performance for the front desk; US-8 Performance (P-3).
>
> **Rules:** BR-1 confirm request 72 h before for bookings made 14+ days ahead; BR-2 48 h cut-off; BR-3 reminder text names clinic, date and time only.

## Working it

- **Agreement first.** The date (11 January) is the product owner's, so it is fixed; the quality bar is BR-3 and the pilot's acceptance criteria; the review budget is one week of the product owner's review at both clinics. Scope is what varies.
- **The skeleton stories pass the Must test.** Without US-1, US-2 or US-4 the front desk cannot know who is not coming before the cut-off: no point delivering. No workaround: there is no other channel to ask long-gap patients at scale, and the unconfirmed list is the only thing the manual refill step works from.
- **US-5 fails the workaround clause.** The front desk *can* phone the waitlist from the US-4 list: painful, but a workaround, so not a Must (DSDM). The skeleton's "Refill the slot" cell stays the manual step. The pain is real, and the Kano pass says US-5 is the front desk's **Delighter**, so it is a Should placed **last** in the cut order: the differentiator to protect.
- **"Kano-Basic, therefore Must" mixes two axes.** Kano says how satisfaction responds to the reminder; MoSCoW says what this release guarantees. A Basic that is not a Must gets a **second look**, not a promotion. Second look: the long-gap patients behind most no-shows already get the confirm request (US-1), which they can cancel from; patients booked under 14 days ahead carry on as today. That is a workaround, so US-6 is a Should. Because a missing Basic is felt sharply, it is cut late, just before US-5.
- **US-7 and US-8 only work with US-6.** They are Coulds and sit first in the cut order; if US-6 is dropped, they drop with it.
- **US-3 is cheap to drop but worth building early.** Its workaround (read odd replies in the SMS inbox) is easy, so it is the first Should to go under pressure. Cohn's factors still say build it first among the contingency: it removes the most risk (unknown reply formats) and gains knowledge US-2's reply handling needs.
- **US-9 to US-11 are Won't this time.** Both partner clinics book in Rebound already; a paper-diary clinic is Release 3's outcome.
- **Two-way check.** Skeleton stories = Musts = US-1, US-2, US-4. No Must off the skeleton, no regulatory story to add (BR-3 is a rule inside US-1 and US-6). The story map needs no re-cut.

## Output — `ideate/moscow.md`

````markdown
---
name: moscow-prioritized-backlog
product: rebound
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-29
summary: Rebound Release 1 (two-clinic pilot): the 3-story walking skeleton is the Must set; 3 Shoulds and 2 Coulds form the cut order, with the waitlist Delighter (US-5) protected last.
profile: standard
status: draft
release: Release 1 — Walking Skeleton (two partner clinics)
linked-story-map: ideate/story-map.md
linked-backlog: ideate/user-stories.md
traces_to: strategy/okrs.md (KR-2.1); ideate/story-map.md (walking skeleton: US-1, US-2, US-4); ideate/user-stories.md (US-1–US-11); ideate/requirements.md (BR-1–BR-3)
---

# MoSCoW Prioritisation — Rebound, Release 1

Priorities here are **final for this release**. They replace the provisional priorities on the stories; Release 2 and 3 are prioritised again when they come.

## Prioritisation Agreement

- **Constraint:** pilot at the two partner clinics from 2027-01-11 (set by the product owner); quality bar BR-3 and every Must's acceptance criteria; review budget one week of the product owner's review at both clinics before the pilot.
- **Who decides:** the product owner. The requirements-analyst facilitates and records. Consulted: the partner clinics' front desks (the Kano snapshots).
- **What drops first:** the Contingency list below, in its order.
- **Escalation:** a disputed Must goes to the product owner with the Must test, the workaround found and the skeleton consequence.

## Must Have (Minimum Usable SubseT = walking skeleton)

| Story | Journey step | Why Must (DSDM signal) | Workaround |
|---|---|---|---|
| US-1 Patient receives a confirm request for a long-gap appointment | Ask long-gap patients | No point delivering: without it nobody is asked whether they are coming | none |
| US-2 Patient's reply confirms or cancels the appointment | Patients answer | No point delivering: a request nobody can answer tells the front desk nothing | none |
| US-4 Front desk sees who is still unconfirmed at the cut-off | Act before the cut-off | No point delivering: the manual refill step works only from this list | none |

## Should Have

| Story | Pain if left out (value lost, who is affected) | Workaround this release | Kano (persona) |
|---|---|---|---|
| US-3 Front desk sees unrecognised replies | Small: a few odd replies a day at two clinics | Front desk reads them in the SMS inbox | Performance (P-2), directional |
| US-6 Patient receives a reminder the day before | Patients booked under 14 days ahead get nothing new | Long-gap patients already get the confirm request (US-1) and can cancel from it | Basic (P-3), directional |
| US-5 Waitlisted patients are offered a freed slot in order | Front desk phones each freed slot by hand | Manual skeleton cell: phone the waitlist from the US-4 list | Delighter (P-2), directional |

## Could Have

| Story | Pain if left out | Workaround this release | Kano (persona) |
|---|---|---|---|
| US-8 Patient gets a cancellation confirmation | Patients who cancel are unsure it worked | Front desk calls back on request | Performance (P-3), directional |
| US-7 Patient cancels by replying to the reminder | Only with US-6; reminder readers phone to cancel | Phone the clinic, as today | not classified |

## Won't Have this time

| Story | Why not now | Look again |
|---|---|---|
| US-9 Front desk enters the day's paper bookings | Both partner clinics book in Rebound already | Release 3, or when a paper-diary clinic signs |
| US-10 Front desk is warned of a clashing booking | Only matters with paper copying (US-9) | Release 3 |
| US-11 Front desk brings future paper bookings in before go-live | No paper-diary clinic in the pilot | Release 3 |

## Contingency (cut order)

Dropped in this order if the release is under pressure. Build order differs: US-3 is built first among these (Cohn: most risk removed, reply formats learned).

1. US-8 Patient gets a cancellation confirmation (Could) — least pain; Performance, buy later
2. US-7 Patient cancels by replying to the reminder (Could) — drops with US-6 if US-6 goes
3. US-3 Front desk sees unrecognised replies (Should) — cheapest workaround of the Shoulds
4. US-6 Patient receives a reminder the day before (Should) — Kano-Basic: its absence is felt sharply, so cut late
5. US-5 Waitlisted patients are offered a freed slot in order (Should) — the front desk's Delighter, protected last

## Skeleton Check (two-way)

- **Skeleton → Must:** US-1, US-2 and US-4 are the skeleton's stories and the Musts. "Fill the diary" is an existing capability; "Refill the slot" stays the manual cell because US-5 has a workaround.
- **Must → skeleton:** no Must off the skeleton. No legal, safety or regulatory story to add: BR-3 is a rule inside US-1 and US-6.
- **Re-cut for the story map:** none; the map and this list agree.
- **Structural checks:** usable yes (the journey walks with the Musts and two named cells); droppable tier present and ordered yes (5 stories); every Must workaround-free yes.
````

## What the weak first draft looked like

```markdown
| Must | US-1, US-2, US-4, US-5, US-6 | Kano Basic + front desk request |
| Should | US-3, US-7, US-8 |
| Could | — |
| Won't | US-9, US-10, US-11 |
Musts = 5 of 11 stories = 45%, under the 60% ceiling ✔
```

Two Musts with workarounds; a Must list that no longer equals the skeleton (US-5 and US-6 are not on it); Kano used as a promotion rule; a count-based "60%" gate passed as if it meant something; no agreement, no cut order, no reasons on the Won'ts.

## Why this is right at standard

| Choice | Reason |
|---|---|
| Musts = the three skeleton stories | DSDM's Minimum Usable SubseT, checked both ways with the story map |
| US-5 a Should despite the pain | The workaround clause: phoning is painful, but it works |
| US-6 a Should despite Kano-Basic | Different axes; Basic earns a second look, which found a workaround |
| Delighter last, Basic next-to-last in the cut order | Kano orders the contingency; it never makes a Must |
| US-7 drops with US-6 | Stories that only work together drop together |
| Build order noted separately | Cohn's risk and knowledge factors decide what to build first |
| Should vs Could argued as pain | DSDM's measure: value lost, people affected |
