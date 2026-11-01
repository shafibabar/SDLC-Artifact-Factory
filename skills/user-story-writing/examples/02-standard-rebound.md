# Example 2 — Standard: stories from the epic list, traced to UR and FR; a Paths split; a system-as-actor draft rewritten; Given/When/Then handed to the example map

Self-contained. **Rebound** is appointment software for independent physiotherapy clinics (one to eight practitioners), at the **standard** profile. It continues Rebound's epic list and functional requirements document: the FRD and the backlog run side by side on purpose (the FRD is the traceable record of what must be true, the stories are the units of conversation and build), so each story cites its UR and FRs instead of restating them. Priority is provisional; `moscow-prioritization` finalises it after the story map.

## Input

> **Epic list (ideate/epics.md, approved):** EPIC-1 "Front desk refills the slots of long-gap patients who aren't coming" (SOL-3; JS-1.1, JS-1.2; UR-1; high) with titles: patient receives a confirm request for a long-gap appointment; patient's reply confirms or cancels the appointment; front desk sees unrecognised replies; front desk sees who is still unconfirmed at the cut-off; waitlisted patients are offered a freed slot in order. EPIC-2 "Patients cancel from the reminder instead of not turning up" (SOL-1; JS-2.1; UR-2; high): reminder the day before; cancel by replying; cancellation confirmation. EPIC-3 "Paper-diary bookings get reminders too" (day-end copy; JS-1.2; UR-3, TR-1; medium): enter the day's paper bookings; clash warning; bring future paper bookings in before go-live.
>
> **FRD (ideate/requirements.md, approved):** UR-1: FR-1.1 confirm request, FR-1.2 record reply, FR-1.3 unconfirmed list at the 48 h cut-off, FR-1.4 waitlist offer. UR-2: FR-2.1 reminder, FR-2.2 cancel by reply. UR-3: FR-3.1 checklist entry, FR-3.2 clash flag. BR-1 send times (confirm request 72 h before for bookings made 14+ days ahead; reminder 24 h before); BR-2 48 h cut-off; BR-3 reminder text names clinic, date and time only; BR-4 waitlist offered in order, slot filled once; BR-5 no fee when cancelled 24 h or more ahead; BR-6 no double booking. TR-1 future paper bookings entered before go-live. **NFR:** NFR-PERF-01 reply registered and slot released within 2 minutes.
>
> **Personas:** P-1 clinic owner, P-2 front desk, P-3 patient. **JTBD:** J-1 "keep every practitioner's diary full without chasing patients" (JS-1.1 know whether a long-gap patient is still coming; JS-1.2 fill a freed slot from the waitlist); J-2 "keep my physio appointments without having to remember them" (JS-2.1 cancel from the reminder).
>
> **The user:** "My draft for the waitlist one is 'As the system, I want to auto-offer freed slots via the SMS API within 2 minutes so that slots are offered.' Also put the Given/When/Then on the reply story while you're there, and mark EPIC-1's stories Must."

## Working it

- **One story per epic story title,** in the order the user meets them. Each inherits its epic's traces and cites the FR it carries; the Coverage table shows every title and every FR has a home.
- **The reply story splits by Paths (SPIDR).** "Reply confirms or cancels" covers recognised replies ("C", "X"); a reply nobody can parse ("can I come at 11?") is a different path with a different user (the front desk), so it is its own story, US-3, which the epic already titled.
- **The waitlist draft fails three ways.** The system is the actor (systems have no wants: that is a task); "via the SMS API" names the implementation (Negotiable lost); "so that slots are offered" restates the want. And "within 2 minutes" is a quality target that `nfr-specification` owns as NFR-PERF-01. Rewritten for the front desk (JS-1.2), with the NFR cited.
- **No Given/When/Then on the card.** The reply story carries a seed example and the rules it touches (BR-2, BR-4). The criteria are drafted in `acceptance-criteria` from the example map, which runs first (Ken Pugh: examples before rules). The open question (a reply after the cut-off) goes to the example map as a question card.
- **Not Must.** EPIC-1 is high, but each story is judged on its own (DSDM), and `moscow-prioritization` finalises priority after the story map. All stay provisional.

## Output — `ideate/user-stories.md`

````markdown
---
name: user-story-backlog
product: rebound
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-27
summary: Rebound's 11 stories for the no-show path (confirm requests and waitlist refill, cancellable reminders, paper-diary copy), traced to EPIC-1–3, UR-1–UR-3 and KR-2.1.
profile: standard
status: draft
linked-kr: KR-2.1
linked-epics: ideate/epics.md
linked-requirements: ideate/requirements.md
linked-jtbd: ideate/jtbd-analysis.md
traces_to: strategy/okrs.md (KR-2.1); ideate/epics.md (EPIC-1–EPIC-3); ideate/requirements.md (UR-1–UR-3, TR-1); ideate/jtbd-analysis.md (J-1, JS-1.1, JS-1.2, J-2, JS-2.1)
---

# User Story Backlog — Rebound

**Translation.** The three epics' story titles, with the FRs of UR-1 to UR-3 and TR-1, become eleven stories for `example-mapping`, `acceptance-criteria` and `story-mapping`.

Priorities in this document are **provisional**; `moscow-prioritization` finalises them.

## Backlog Summary

| ID | Story | Epic | Persona | UR / FR | Job story | Priority (provisional) |
|---|---|---|---|---|---|---|
| US-1 | Patient receives a confirm request for a long-gap appointment | EPIC-1 | P-3 | UR-1 (FR-1.1) | JS-1.1 | high |
| US-2 | Patient's reply confirms or cancels the appointment | EPIC-1 | P-3 | UR-1 (FR-1.2) | JS-1.1 | high |
| US-3 | Front desk sees unrecognised replies | EPIC-1 | P-2 | UR-1 (FR-1.2) | JS-1.1 | high |
| US-4 | Front desk sees who is still unconfirmed at the cut-off | EPIC-1 | P-2 | UR-1 (FR-1.3) | JS-1.1 | high |
| US-5 | Waitlisted patients are offered a freed slot in order | EPIC-1 | P-2 | UR-1 (FR-1.4) | JS-1.2 | high |
| US-6 | Patient receives a reminder the day before | EPIC-2 | P-3 | UR-2 (FR-2.1) | JS-2.1 | high |
| US-7 | Patient cancels by replying to the reminder | EPIC-2 | P-3 | UR-2 (FR-2.2) | JS-2.1 | high |
| US-8 | Patient gets a cancellation confirmation | EPIC-2 | P-3 | UR-2 (FR-2.2) | JS-2.1 | high |
| US-9 | Front desk enters the day's paper bookings from a checklist | EPIC-3 | P-2 | UR-3 (FR-3.1) | JS-1.2 | medium |
| US-10 | Front desk is warned of a clashing booking | EPIC-3 | P-2 | UR-3 (FR-3.2) | JS-1.2 | medium |
| US-11 | Front desk brings future paper bookings in before go-live | EPIC-3 | P-2 | TR-1 | JS-1.2 | medium |

## Stories

### EPIC-1: Front desk refills the slots of long-gap patients who aren't coming

#### US-1: Patient receives a confirm request for a long-gap appointment
As a patient (P-3) who booked a fortnight or more ahead, I want to be asked a few days before whether I am still coming, so that I can say no while the clinic can still give the slot to someone else.
- Traces to: EPIC-1 · UR-1 (FR-1.1) · J-1 → JS-1.1 · KR-2.1
- Rules: BR-1 (72 h before, bookings made 14+ days ahead)
- Priority (provisional): high
- Seed example: Mrs Okafor booked Thursday 10:00 sixteen days ahead; on Monday 10:00 she gets "Reply C to confirm or X to cancel"; Mr Lund, who booked last Friday, gets none.
- Acceptance criteria: ideate/acceptance-criteria/US-1.md (from the example map)

#### US-2: Patient's reply confirms or cancels the appointment
As a patient (P-3), I want my "C" or "X" reply to confirm or cancel the appointment, so that I don't have to phone the clinic in working hours.
- Traces to: EPIC-1 · UR-1 (FR-1.2) · J-1 → JS-1.1 · KR-2.1
- Rules: BR-2 (48 h cut-off), BR-4 (a cancelled slot goes to the waitlist)
- Priority (provisional): high
- Seed example: Mrs Okafor replies "c"; her Thursday 10:00 shows confirmed. Mr Adeyemi replies "X"; his Thursday 11:00 is released.
- Acceptance criteria: ideate/acceptance-criteria/US-2.md (from the example map)
- Notes: Paths split (SPIDR): unrecognised replies are US-3. Question for the example map: what happens to a reply after the cut-off?

#### US-3: Front desk sees unrecognised replies
As the front desk (P-2), I want to see any reply the system could not read, so that I can act on it myself before the slot is lost.
- Traces to: EPIC-1 · UR-1 (FR-1.2) · J-1 → JS-1.1 · KR-2.1
- Rules: none
- Priority (provisional): high
- Seed example: Mrs Okafor replies "can I come at 11?"; it appears on the front desk's list unchanged, with her appointment beside it.
- Acceptance criteria: ideate/acceptance-criteria/US-3.md (from the example map)

#### US-4: Front desk sees who is still unconfirmed at the cut-off
As the front desk (P-2), I want to see which long-gap patients have not answered before the cut-off, so that I can phone them while the slot can still be filled.
- Traces to: EPIC-1 · UR-1 (FR-1.3) · J-1 → JS-1.1 · KR-2.1
- Rules: BR-2
- Priority (provisional): high
- Seed example: 10 requests went out for Thursday; 6 replied; on Tuesday morning the list shows the other 4 with patient, practitioner and slot.
- Acceptance criteria: ideate/acceptance-criteria/US-4.md (from the example map)

#### US-5: Waitlisted patients are offered a freed slot in order
As the front desk (P-2), I want a freed slot offered to the waitlist in order, so that the practitioner's diary stays full without me phoning round.
- Traces to: EPIC-1 · UR-1 (FR-1.4) · J-1 → JS-1.2 · KR-2.1
- Rules: BR-4 (in order, filled once) · NFR-PERF-01 (how fast the slot is released)
- Priority (provisional): high
- Seed example: Friday 14:00 is freed; three patients are waiting; the first to accept gets it and the other two are told it has gone.
- Acceptance criteria: ideate/acceptance-criteria/US-5.md (from the example map)
- Notes: rewritten from "As the system, I want to auto-offer freed slots via the SMS API within 2 minutes so that slots are offered".

### EPIC-2: Patients cancel from the reminder instead of not turning up

#### US-6: Patient receives a reminder the day before
As a patient (P-3), I want a reminder the day before my appointment, so that I either come or cancel instead of forgetting.
- Traces to: EPIC-2 · UR-2 (FR-2.1) · J-2 → JS-2.1 · KR-2.1
- Rules: BR-1 (24 h before), BR-3 (clinic, date and time only)
- Priority (provisional): high
- Seed example: Mr Lund's Wednesday 09:30 reminder arrives Tuesday 09:30 and does not mention his knee.
- Acceptance criteria: ideate/acceptance-criteria/US-6.md (from the example map)

#### US-7: Patient cancels by replying to the reminder
As a patient (P-3), I want to cancel by replying to the reminder, so that I can free the slot without signing in or phoning.
- Traces to: EPIC-2 · UR-2 (FR-2.2) · J-2 → JS-2.1 · KR-2.1
- Rules: BR-4, BR-5 (no fee 24 h or more ahead)
- Priority (provisional): high
- Seed example: Mr Lund replies "X" on Tuesday at 10:00; his Wednesday 09:30 is released to the waitlist.
- Acceptance criteria: ideate/acceptance-criteria/US-7.md (from the example map)

#### US-8: Patient gets a cancellation confirmation
As a patient (P-3), I want to be told my cancellation went through and that there is no fee, so that I don't phone the clinic to check.
- Traces to: EPIC-2 · UR-2 (FR-2.2) · J-2 → JS-2.1 · KR-2.1
- Rules: BR-5
- Priority (provisional): high
- Seed example: after his "X", Mr Lund gets "Cancelled: Wed 09:30, no fee".
- Acceptance criteria: ideate/acceptance-criteria/US-8.md (from the example map)

### EPIC-3: Paper-diary bookings get reminders too

#### US-9: Front desk enters the day's paper bookings from a checklist
As the front desk (P-2) at a paper-diary clinic, I want to copy the day's paper bookings in from one checklist, so that those patients get reminders and confirm requests too.
- Traces to: EPIC-3 · UR-3 (FR-3.1) · J-1 → JS-1.2 · KR-2.1
- Rules: BR-1
- Priority (provisional): medium
- Seed example: 12 bookings for 3 practitioners, entered in one sitting at 17:30, all appear in the diary.
- Acceptance criteria: ideate/acceptance-criteria/US-9.md (from the example map)

#### US-10: Front desk is warned of a clashing booking
As the front desk (P-2), I want to be stopped before saving a booking that clashes, so that two patients never turn up for one slot.
- Traces to: EPIC-3 · UR-3 (FR-3.2) · J-1 → JS-1.2 · KR-2.1
- Rules: BR-6
- Priority (provisional): medium
- Seed example: a second patient at Dr Shah's Thursday 15:00 is refused until moved to 15:30.
- Acceptance criteria: ideate/acceptance-criteria/US-10.md (from the example map)

#### US-11: Front desk brings future paper bookings in before go-live
As the front desk (P-2), I want the bookings already in our paper diaries to be in Rebound before we start, so that no booked patient misses their reminder in the first weeks.
- Traces to: EPIC-3 · TR-1 · J-1 → JS-1.2 · KR-2.1
- Rules: BR-6
- Priority (provisional): medium
- Seed example: clinic B's 87 future paper bookings appear, counted per practitioner, and the counts match the diaries.
- Acceptance criteria: ideate/acceptance-criteria/US-11.md (from the example map)

## Coverage

| Source | Stories |
|---|---|
| EPIC-1 titles (5) | US-1 to US-5 |
| EPIC-2 titles (3) | US-6 to US-8 |
| EPIC-3 titles (3) | US-9 to US-11 |
| UR-1 (FR-1.1, FR-1.2, FR-1.3, FR-1.4) | US-1; US-2, US-3; US-4; US-5 |
| UR-2 (FR-2.1, FR-2.2) | US-6; US-7, US-8 |
| UR-3 (FR-3.1, FR-3.2) | US-9; US-10 |
| TR-1 | US-11 |

## Intake Log (from the story map)

| Item | Kind | Decision |
|---|---|---|
| None yet | — | The story map runs after example maps and acceptance criteria |
````

## The hand-off to the example map

For US-2 the backlog gives `example-mapping` the story, its seed example, the rules it touches (BR-2, BR-4) and one question card: *a reply after the 48 h cut-off?* The agent plays customer, developer and tester alone and says so in the map. Only then does `acceptance-criteria` draft US-2's Given/When/Then, declaratively ("a confirmed appointment", not "click the reply"), and the test-strategist later turns them into a feature file (`bdd-feature-file`).

## Why this is right at standard

| Choice | Reason |
|---|---|
| One story per epic title, FRs cited | The FRD stays the record; stories carry the trace without restating it |
| Paths split for the reply | Each path has its own user and its own test |
| System-as-actor draft rewritten for the front desk | Systems have no wants; the need is JS-1.2 |
| NFR-PERF-01 cited, no number on the card | The quality target has one owner |
| No Given/When/Then, a question for the example map | Examples before rules (Pugh); the card is the promise |
| Everything provisional, no Must | DSDM judges each story; MoSCoW finalises after the map |
