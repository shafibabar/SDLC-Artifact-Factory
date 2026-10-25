# Example 2 — Standard: epics from the selected path, a procedure that is not an epic, and a hypothesis that can fail while the epic succeeds

Self-contained. **Rebound** is appointment software for independent physiotherapy clinics (one to eight practitioners), at the **standard** profile. It continues Rebound's impact map and functional requirements document: the epics carry the FRD's user requirements and serve the map's selected path, nothing else. It shows one epic per selected software deliverable, every UR landing in exactly one epic, a non-software deliverable listed under "Not epics", four-risk lines drawn from the tree's assumption tests, epic criteria with concrete examples, a cross-context flag, and provisional priority.

## Input

> **Impact map (ideate/impact-map.md, approved):** KR-2.1, no-show rate 12% → 7% by 2027-03-31. Selected path: patient booked 2+ weeks ahead → confirms or cancels ahead instead of silently not turning up → OPP-3.1 → **SOL-3** reply-to-confirm request 72 h before, unconfirmed slots offered to the waitlist; **SOL-1** SMS reminder 24 h before; **SOL-2** front desk phones long-gap bookings (a procedure); blocker branch: **day-end diary copy** of paper bookings. Signal: reply rate per confirm request; no-show rate. Re-plan trigger: reply rate under 70% after four weeks → try the calendar-file option on the same impact. Options: calendar file; deposit at booking.
>
> **JTBD analysis:** J-1 "keep every practitioner's diary full without chasing patients" with JS-1.1 (know whether a long-gap patient is still coming) and JS-1.2 (fill a freed slot from the waitlist); J-2 "keep my physio appointments without having to remember them" with JS-2.1 (cancel from the reminder).
>
> **FRD (ideate/requirements.md, approved):** UR-1 (SOL-3; FR-1.1 confirm request, FR-1.2 record reply, FR-1.3 unconfirmed list at the 48 h cut-off, FR-1.4 waitlist offer); UR-2 (SOL-1; FR-2.1 reminder, FR-2.2 cancel by reply); UR-3 (day-end copy; FR-3.1 checklist entry, FR-3.2 clash flag). BR-1 to BR-6. TR-1 enter future paper bookings, TR-2 front-desk training, TR-3 paper diary retired. ASM-1 patients reply to an SMS (test T-1); ASM-2 front desks have ten minutes at day end (test T-2). CON-1 existing SMS account.
>
> **NFR specification:** QA-1 reply registered and slot released within 2 minutes (NFR-PERF-01); no High architecture hand-off item.

## Working it

- **Three epics, not four.** SOL-3, SOL-1 and the day-end copy are software deliverables, so each gets an epic. SOL-2 (the front desk phones long-gap patients) is a procedure: it goes under "Not epics", documented for the clinics, never decomposed into stories. The calendar file and deposits are options: they stay on the map.
- **Each UR in exactly one epic.** UR-1 → EPIC-1, UR-2 → EPIC-2, UR-3 and TR-1 → EPIC-3. TR-2 (training) and TR-3 (retiring the diary) are procedures.
- **Hypotheses from the map, not invented.** Each copies the impact and signal of its deliverable.
- **Risks from the tree.** T-1 and T-2 have not run yet, so value and usability are "assumed" with the test named. Nothing is marked tested without a result.
- **No numbers the NFRs own.** "Within 2 minutes" stays in NFR-PERF-01; the epic criterion cites it.

## The hypothesis that can fail while the epic succeeds

After four weeks, every confirm request is sent, replies are recorded and the front desk sees the unconfirmed list: EPIC-1's criteria are all met, so **the epic succeeded**. But only 52% of patients reply, under the map's 70% trigger, and the no-show rate has barely moved: **the hypothesis failed**. Because the two are written separately, the team reads this correctly: the bottleneck is patients not replying, so the re-plan trigger sends it to the next option on the same impact (the calendar file), not to "improve the confirm screen".

## Output — `ideate/epics.md`

````markdown
---
name: epic-list
product: rebound
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-25
summary: Three epics for Rebound's no-show path (confirm requests with waitlist refill, cancellable reminders, paper-diary copy), traced to SOL-1, SOL-3, UR-1–UR-3 and KR-2.1.
profile: standard
status: draft
linked-kr: KR-2.1
linked-impact-map: ideate/impact-map.md
linked-jtbd: ideate/jtbd-analysis.md
linked-requirements: ideate/requirements.md
traces_to: strategy/okrs.md (KR-2.1); ideate/impact-map.md (selected path: SOL-1, SOL-3, day-end copy); ideate/jtbd-analysis.md (J-1, JS-1.1, JS-1.2, J-2, JS-2.1); ideate/requirements.md (UR-1–UR-3, TR-1)
---

# Epic List — Rebound

**Translation.** The selected path's three software deliverables, with the user requirements written for them, become three epics for `user-story-writing`, `story-mapping` and the domain-modeler; the phoning procedure (SOL-2) is not an epic.

Priorities in this document are **provisional** and are finalised by `moscow-prioritization`. Sizes are structural (S = 3–4 stories, M = 5–7, L = 8–10).

## Epic Summary

| ID | Epic (outcome) | Deliverable | Job story | URs / TRs | Bounded Context | Priority (provisional) | Size |
|---|---|---|---|---|---|---|---|
| EPIC-1 | Front desk refills the slots of long-gap patients who aren't coming | SOL-3 | JS-1.1, JS-1.2 | UR-1 | Booking (flagged) | high | M |
| EPIC-2 | Patients cancel from the reminder instead of not turning up | SOL-1 | JS-2.1 | UR-2 | Booking (flagged) | high | S |
| EPIC-3 | Paper-diary bookings get reminders too | Day-end diary copy | JS-1.2 | UR-3, TR-1 | Booking | medium | S |

## Epics

### EPIC-1: Front desk refills the slots of long-gap patients who aren't coming

As a result of this epic, the front desk will be able to see which patients booked 14+ days ahead are still coming, and offer the slots of those who are not to the waitlist.

**Hypothesis:** If we send patients booked 14+ days ahead a reply-to-confirm request, we believe they will confirm or cancel ahead instead of silently not turning up, shown by reply rate per confirm request, which moves KR-2.1.

**Traces to:** deliverable SOL-3 (selected path, ideate/impact-map.md) · job J-1 "keep every practitioner's diary full without chasing patients" → job stories JS-1.1, JS-1.2 · UR-1 · KR-2.1
**Personas:** P-2 front desk (primary); P-3 patient; P-1 clinic owner
**Bounded Context (candidate):** Booking

**Risks:** value — assumed (patients reply to an SMS; T-1 on the tree, success = 60% reply) · usability — assumed (patients understand "Reply C or X"; read in T-1's replies) · feasibility — low (existing SMS account, CON-1; no High architecture hand-off) · viability — assumed (clinics accept two messages per appointment; the user asks the two design-partner owners)

**Epic acceptance criteria:**
- [ ] Every appointment booked 14+ days ahead gets a confirm request at the time BR-1 sets. *Example: of 100 Thursday appointments, the 60 booked a fortnight or more ahead get a request on Monday; the 40 booked later get none.*
- [ ] Each reply changes the appointment's status, and anything unrecognised reaches the front desk. *Example: "C" confirms Mrs Okafor's 10:00; "can I come at 11?" appears on the front desk's list unchanged.*
- [ ] Before the 48 h cut-off (BR-2) the front desk sees exactly who has not confirmed. *Example: 4 of 10 requests unanswered on Tuesday morning; the list shows those 4 with patient and slot.*
- [ ] A cancelled slot is offered to the waitlist in order and filled once (BR-4), within NFR-PERF-01. *Example: three patients waiting; the first to accept gets Friday 14:00, the other two are told it has gone.*

**Story titles:**
1. Patient receives a confirm request for a long-gap appointment (UR-1)
2. Patient's reply confirms or cancels the appointment
3. Front desk sees unrecognised replies
4. Front desk sees who is still unconfirmed at the cut-off
5. Waitlisted patients are offered a freed slot in order

**Size:** M
**Priority (provisional):** high

---

### EPIC-2: Patients cancel from the reminder instead of not turning up

As a result of this epic, a patient who can no longer make an appointment will be able to cancel it from the reminder itself, without signing in.

**Hypothesis:** If the 24 h reminder can be answered with a cancellation, we believe patients who cannot come will cancel instead of not turning up, shown by late cancellations per no-show, which moves KR-2.1.

**Traces to:** deliverable SOL-1 (selected path, ideate/impact-map.md) · job J-2 "keep my physio appointments without having to remember them" → job story JS-2.1 · UR-2 · KR-2.1
**Personas:** P-3 patient (primary); P-2 front desk
**Bounded Context (candidate):** Booking

**Risks:** value — assumed (patients would rather cancel than ignore; T-1 replies show it) · usability — assumed (cancelling by "X" needs no instructions; read in T-1) · feasibility — low (same SMS account, CON-1) · viability — low (BR-5: no fee 24 h or more ahead, already the clinics' policy)

**Epic acceptance criteria:**
- [ ] Every appointment gets a reminder at the time BR-1 sets, naming clinic, date and time only (BR-3). *Example: Mr Lund's Wednesday 09:30 reminder arrives Tuesday 09:30 and does not mention his knee.*
- [ ] A patient can cancel by replying, without signing in, and is told it is done. *Example: Mr Lund replies "X"; the slot is released and he gets "Cancelled: Wed 09:30, no fee".*
- [ ] A cancellation from a reminder releases the slot to the waitlist (EPIC-1). *Example: Mr Lund's 09:30 is offered to the first waitlisted patient.*

**Story titles:**
1. Patient receives a reminder the day before
2. Patient cancels by replying to the reminder
3. Patient gets a cancellation confirmation

**Size:** S
**Priority (provisional):** high

---

### EPIC-3: Paper-diary bookings get reminders too

As a result of this epic, the front desk at a clinic still using a paper diary will be able to bring each day's paper bookings into Rebound, so those patients get reminders and confirm requests.

**Hypothesis:** If copying a day's paper bookings takes one short checklist, we believe front desks at paper-diary clinics will copy them in every day instead of leaving them on paper, shown by bookings found only on paper in a weekly spot check, which moves KR-2.1.

**Traces to:** deliverable "day-end diary copy" (selected path, blocker branch, ideate/impact-map.md) · job J-1 → job story JS-1.2 · UR-3, TR-1 · KR-2.1
**Personas:** P-2 front desk (primary)
**Bounded Context (candidate):** Booking

**Risks:** value — assumed (front desks copy daily; T-2, ASM-2) · usability — assumed (12 bookings in one sitting; T-2 walkthrough) · feasibility — low · viability — low (no added cost)

**Epic acceptance criteria:**
- [ ] A front desk enters a day's paper bookings from one checklist. *Example: 12 bookings for 3 practitioners entered in one sitting all appear in the diary.*
- [ ] A clash with an existing booking is caught before it is saved (BR-6). *Example: a second patient at Dr Shah's 15:00 is refused until moved.*
- [ ] Future bookings already in the paper diaries are in Rebound before go-live. *Example: clinic B's 87 future paper bookings appear, counted per practitioner.*

**Story titles:**
1. Front desk enters the day's paper bookings from a checklist
2. Front desk is warned of a clashing booking
3. Front desk brings future paper bookings in before go-live (TR-1)

**Size:** S
**Priority (provisional):** medium

## Coverage

| Source | Epic |
|---|---|
| SOL-3 (selected path) | EPIC-1 |
| SOL-1 (selected path) | EPIC-2 |
| Day-end diary copy (selected path) | EPIC-3 |
| UR-1 / UR-2 / UR-3 | EPIC-1 / EPIC-2 / EPIC-3 |
| TR-1 | EPIC-3 |
| TR-2, TR-3 | Not epics |

## Not Epics

| Item | Why not an epic | Where it goes |
|---|---|---|
| SOL-2 front desk phones long-gap bookings | Non-software deliverable (a procedure) | Written up as a front-desk procedure for the design-partner clinics |
| TR-2 front-desk training | Procedure | Go-live checklist |
| TR-3 paper diary retired | Procedure | Go-live checklist |
| Calendar file; deposit at booking | Option branches, not selected | Stay on the impact map (the calendar file is the re-plan option) |

## Cross-Context Flags (for the domain-modeler)

| Epic | Contexts involved | Why it still crosses after the outcome split | Question for the domain-modeler |
|---|---|---|---|
| EPIC-1, EPIC-2 | Booking, Patient Messaging | A patient's SMS reply changes a booking | Is a reply a Domain Event published by Patient Messaging and consumed by Booking, and does Booking need an Anti-Corruption Layer over the SMS provider (IF-1)? |
````

## Why this is right at standard

| Choice | Reason |
|---|---|
| One epic per selected software deliverable | The selected path is the scope; options stay on the map |
| SOL-2 under "Not epics" | A procedure has no stories an agent can build |
| Each UR in exactly one epic | The FRD's trace carries through to stories without gaps or doubles |
| Hypotheses copied from the map's impacts | The epic can be judged against the same signal and re-plan trigger |
| Risks "assumed" with T-1 and T-2 | No test has run; nothing is claimed as tested |
| Criteria with examples, numbers cited | Concrete enough to check; NFR targets stay in the NFR specification |
| Provisional priority | MoSCoW finalises it at the end of Ideate |
