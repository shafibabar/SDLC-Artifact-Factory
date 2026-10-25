# Example 2 — Standard: an FRD from the impact map's selected path and the job stories

Self-contained. **Rebound** is appointment software for independent physiotherapy clinics (one to eight practitioners), at the **standard** profile. It continues the impact map in `impact-mapping`'s standard example: the requirements serve that map's selected path and nothing else. It shows URs per selected deliverable, each traced to a deliverable and to a job statement → job story; functional fit criteria with the timing numbers handed to the NFR specification; business rules catalogued once; a paper-diary transition; options and a want in the waiting room; provisional priority.

## Input

> **Impact map (ideate/impact-map.md, approved):** KR-2.1; goal no-show rate 12% → 7% by 2027-03-31. Selected path: patient (2+ weeks ahead) → confirms or cancels ahead → OPP-3.1 → **SOL-3** reply-to-confirm 72 h before, unconfirmed slots offered to the waitlist; **SOL-1** SMS reminder 24 h before; **SOL-2** front desk phones long-gap bookings (non-software: a procedure, documented, not built); blocker branch: **paper-diary bookings copied in at day end** (non-software procedure plus a checklist screen). Options: calendar file; deposit at booking (tree SOL-5, parked).
>
> **JTBD analysis (approved):** J-1 "keep every practitioner's diary full without chasing patients" (clinic owner P-1, front desk P-2) with JS-1.1 "When a patient booked weeks ago hasn't been in touch, I want to know whether they're still coming, so I can offer the slot to someone else in time" and JS-1.2 "When a slot frees up at short notice, I want to fill it from the waitlist without phoning round, so the practitioner isn't idle". J-2 "keep my physio appointments without having to remember them" (patient P-3) with JS-2.1 "When I get a reminder about an appointment I can't make any more, I want to cancel it there and then, so I don't get charged or forget again".
>
> **Want from the clinic owner at C-2 (snapshot 2026-10-09-c-2):** "Can it send me a daily PDF of no-shows?"

## Working it

- **Only the selected path.** SOL-1, SOL-3 and the day-end copy become user requirements. SOL-2 is a procedure: documented in the hand-off, not a software requirement. The calendar file and deposits stay options: waiting room.
- **Two traces on every UR**: the deliverable, and the job statement with the job story beneath it.
- **Timing numbers are quality attributes.** "Within 24 h", "72 h before" are business rules of the reminder schedule (computation), not response times, so they are BR rows. How quickly a reply registers is a quality concern handed off.
- **The PDF want.** Why? "To see which patients to chase." That is JS-1.1, already served by UR-1's unconfirmed list. A daily PDF fails the necessity test as a format: waiting room.
- **Transition.** The blocker branch replaces paper diaries for two clinics: import of existing future bookings, training for front desks, and the paper diary retired.

## Output — `ideate/requirements.md`

````markdown
---
name: functional-requirements-document
product: rebound
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-24
summary: Requirements for Rebound's selected path (SOL-3 confirm requests, SOL-1 reminders, day-end diary copy), traced to J-1/J-2 job stories, for clinic staff and patients.
profile: standard
status: draft
linked-kr: KR-2.1
linked-impact-map: ideate/impact-map.md
linked-jtbd: ideate/jtbd-analysis.md
traces_to: strategy/okrs.md (KR-2.1); ideate/impact-map.md (selected path: SOL-1, SOL-3, day-end copy); ideate/jtbd-analysis.md (J-1, JS-1.1, JS-1.2, J-2, JS-2.1); ideate/user-personas.md (P-1, P-2, P-3)
---

# Functional Requirements — Rebound

**Translation.** The impact map's selected path (SOL-3, SOL-1, day-end copy) and job stories JS-1.1, JS-1.2 and JS-2.1 become requirements that `nfr-specification`, `epic-definition` and the Design phase can act on without asking again.

Priorities in this document are **provisional** and are finalised by `moscow-prioritization`.

## Scope and Exclusions

**In scope:** confirm requests with waitlist offers (SOL-3); reminders (SOL-1); a day-end checklist for copying paper-diary bookings in.

**Excluded:** deposits at booking (option on the map, parked on viability and ethics); calendar files (option); online self-booking (not on the map this cycle).

**Business requirements (cited):** KR-2.1, via the impact map's goal "no-show rate 12% → 7% by 2027-03-31".

## User Classes

| User class | Favoured / disfavoured / ignored | Persona | Champion |
|---|---|---|---|
| Front desk | favoured | P-2 | the product owner |
| Clinic owner | favoured | P-1 | the product owner |
| Patient | favoured | P-3 | the product owner |
| Anyone else holding the patient's phone | disfavoured | — | the product owner |

## User and Functional Requirements

### UR-1: The front desk must be able to see which long-gap patients are still coming, and refill the slots of those who are not

- **Traces to:** deliverable SOL-3 (selected path, ideate/impact-map.md) · job J-1 "keep every practitioner's diary full without chasing patients" → job story JS-1.1 · KR-2.1
- **Rationale:** patients confirming or cancelling ahead is the impact on the path; the front desk can only refill a slot it knows is free.

| ID | Functional requirement | Fit criterion | Verify by | Rules / NFRs | Priority (provisional) |
|---|---|---|---|---|---|
| FR-1.1 | The system must send a confirm request to the patient of every appointment booked 14+ days ahead, at the time BR-1 sets | For 100 seeded appointments (60 booked 14+ days ahead, 40 fewer), exactly 60 confirm requests are queued, each at BR-1's time; none for cancelled appointments | Acceptance test | BR-1, BR-3 | high |
| FR-1.2 | The system must record the patient's reply as confirmed or cancelled | Replies "C" and "X" set confirmed and cancelled for all 50 seeded replies; any other reply leaves the status unchanged and is shown to the front desk | Acceptance test | QA-1 | high |
| FR-1.3 | The front desk must be able to list appointments still unconfirmed at BR-2's cut-off | Given 10 requests of which 4 unanswered at the cut-off, the list shows exactly those 4 with patient and slot | Acceptance test | BR-2 | high |
| FR-1.4 | The system must offer a cancelled or released slot to waitlisted patients in waitlist order | Given a 3-patient waitlist and a cancelled slot, offers go out in order, the first acceptance books the slot, and later acceptances are told it is taken | Acceptance test | BR-4 | medium |

### UR-2: A patient must be able to cancel an appointment they can no longer make from the reminder itself

- **Traces to:** deliverable SOL-1 (selected path, ideate/impact-map.md) · job J-2 "keep my physio appointments without having to remember them" → job story JS-2.1 · KR-2.1
- **Rationale:** a reminder the patient cannot act on produces a late no-show instead of a cancellation.

| ID | Functional requirement | Fit criterion | Verify by | Rules / NFRs | Priority (provisional) |
|---|---|---|---|---|---|
| FR-2.1 | The system must send a reminder to the patient of every appointment at the time BR-1 sets | For 100 seeded appointments, one reminder each at BR-1's time; none for appointments already cancelled | Acceptance test | BR-1, BR-3 | high |
| FR-2.2 | The patient must be able to cancel by replying to the reminder, without signing in | A reply "X" cancels the appointment and releases the slot (FR-1.4) for all 30 seeded cases; the patient receives a cancellation confirmation | Acceptance test | BR-5 | high |

### UR-3: The front desk must be able to bring a practitioner's paper-diary bookings into Rebound at the end of each day

- **Traces to:** deliverable "day-end diary copy" (selected path, blocker branch, ideate/impact-map.md) · job J-1 "keep every practitioner's diary full without chasing patients" → job story JS-1.2 · KR-2.1
- **Rationale:** bookings kept on paper get no reminder or confirm request, so the path fails at two of five clinics.

| ID | Functional requirement | Fit criterion | Verify by | Rules / NFRs | Priority (provisional) |
|---|---|---|---|---|---|
| FR-3.1 | The front desk must be able to enter a day's paper-diary bookings from one checklist screen | 12 bookings for 3 practitioners entered in one session all appear in the diary with patient, practitioner and slot | Usability walkthrough with one front desk | — | medium |
| FR-3.2 | The system must flag a new booking that clashes with an existing one | Entering a booking for an occupied slot shows the clash and saves nothing until resolved, in all 5 seeded clash cases | Acceptance test | BR-6 | medium |

## Business Rules

| ID | Rule | Kind | Source | Cited by |
|---|---|---|---|---|
| BR-1 | Confirm request 72 h before the appointment; reminder 24 h before | computation | Impact map selected path (SOL-1, SOL-3) | FR-1.1, FR-2.1 |
| BR-2 | An appointment unconfirmed 48 h before start is shown to the front desk for follow-up | inference | Product owner, 2026-10-23 | FR-1.3 |
| BR-3 | Messages name the clinic, date and time only, never the treatment | constraint | Tree assumption A-4 (ethical); clinic confidentiality policy | FR-1.1, FR-2.1 |
| BR-4 | A released slot goes to the waitlist in the order patients joined it | action enabler | Clinic owners' current practice (snapshots c-1, c-3) | FR-1.4 |
| BR-5 | A cancellation 24 h or more before start carries no fee | constraint | Clinics' published cancellation policy | FR-2.2 |
| BR-6 | A practitioner has at most one appointment per slot | fact | — | FR-3.2 |

## Constraints

| ID | Constraint | Imposed by |
|---|---|---|
| CON-1 | Patient messages go by SMS through the clinic's existing SMS account | Design-partner clinics (contracts already in place) |

## External Interfaces and Data

| ID | Interface or data requirement | Direction / retention | Source |
|---|---|---|---|
| IF-1 | SMS provider: outbound confirm requests and reminders; inbound replies | both | CON-1 |
| DR-1 | Each confirm request and reply, with time, kept with the appointment | kept as long as the appointment record | BR-2 audit of follow-ups |

## Transition Requirements

| ID | Requirement | Kind | Fit criterion |
|---|---|---|---|
| TR-1 | Future bookings in the two clinics' paper diaries are entered before go-live | data migration | Count of future paper bookings equals count entered, per practitioner, checked by the front desk |
| TR-2 | Each front desk is shown the day-end checklist | training | Each front desk enters a day's bookings unaided in the walkthrough |
| TR-3 | Paper diaries stop being the record of future bookings | decommission | From go-live, no booking exists only on paper in a spot check of one week |

## Quality-Attribute Hand-off (to `nfr-specification`)

| ID | Quality concern | Constrains | Why it matters here |
|---|---|---|---|
| QA-1 | How quickly a reply registers and the slot is released | FR-1.2, FR-2.2, FR-1.4 | A late release cannot be refilled the same day |
| QA-2 | Delivery reliability of outbound messages | FR-1.1, FR-2.1 | A reminder that never arrives is a no-show |
| QA-3 | Privacy of message content on a shared phone | FR-1.1, FR-2.1 | BR-3; tree assumption A-4 |

## Assumption Log

| ID | Assumption | Requirements that depend on it | Impact if false | How it will be confirmed |
|---|---|---|---|---|
| ASM-1 | Patients reply to an SMS confirm request | FR-1.2 | UR-1 does not move the impact; try the next option | Tree test T-1 |
| ASM-2 | Front desks have ten minutes at day end for the copy | FR-3.1 | Paper bookings stay off the system | Tree test T-2 |

## TBD List

| ID | Question | Blocks | Who can answer | Resolve by |
|---|---|---|---|---|
| TBD-1 | How long does a waitlist offer stay open before going to the next patient? | FR-1.4 | the product owner | Before the Design phase gate |

## Waiting Room

| Item | Reason deferred | Would return if |
|---|---|---|
| Deposit at booking (tree SOL-5) | Option on the map; viability and ethics doubts | T-1 and T-2 fail and the user re-plans |
| Calendar file with the confirm request | Option on the map | Reply rate under 70% after four weeks (re-plan trigger) |
| Daily PDF of no-shows for the clinic owner | Want; the need (JS-1.1) is met by FR-1.3; a PDF fails the necessity test | An owner needs the list off-line |

## Traceability

| Source | Served by |
|---|---|
| SOL-3 (selected path) | UR-1 |
| SOL-1 (selected path) | UR-2 |
| Day-end diary copy (selected path) | UR-3 |
| SOL-2 front desk phoning (selected path, procedure) | Not software: documented for `epic-definition` as a procedure |
| JS-1.1 | UR-1 |
| JS-1.2 | UR-1 (FR-1.4), UR-3 |
| JS-2.1 | UR-2 |
| KR-2.1 | UR-1, UR-2, UR-3 |

## Change Log

| Version | Date | Change | Reason | Impact | Decided by |
|---|---|---|---|---|---|
| 1.0.0 | 2026-10-24 | First draft | Ideate, cycle 1 | — | awaiting the user |
````

## Why this is right at standard

| Choice | Reason |
|---|---|
| URs only for selected deliverables | Options stay on the map; the waiting room records them |
| Deliverable and job story on every UR | Both traces the profile asks for |
| Timing as business rules, speed as hand-off | 72 h and 24 h are policy; how fast a reply registers is a quality attribute owned by `nfr-specification` |
| PDF want to waiting room | The need was already met; the format failed the necessity test |
| Transition for paper diaries | The blocker branch replaces paper in two clinics |
| Provisional priority | MoSCoW finalises it later |
