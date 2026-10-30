# Example 2 — Standard: a full tree for a B2B clinic-booking product, rooted after a traction-metric KR

Self-contained. **Rebound** is appointment software for independent physiotherapy clinics (one to eight practitioners), at the **standard** profile, where the tree is **required**. It shows the root reclassified from a traction metric, the opportunity space built from five snapshots and a feedback log, a level-by-level comparison, three solutions carried forward, typed assumptions and tests with criteria set first.

## Input

> **KR (strategy/okrs.md, KR-2.1):** "70% of active clinics enable SMS reminders by end of Q1."
>
> **Evidence:** five snapshots from design-partner clinic owners and front-desk staff (`2026-10-02-c-1` … `2026-10-13-c-5`), each with opportunities heard tagged by experience step; one beta feedback log, items FB-007 and FB-011.
>
> **JTBD analysis (approved):** J-1 "keep every practitioner's diary full without chasing patients"; its target desired-outcome statement O-1.2 "Minimize the number of slots that go unused because a patient did not attend".

## Working it

- **The KR is a traction metric.** "Enable SMS reminders" is the usage of one feature: assigning it decides the solution. Asked what reminders were for, the OKR owner says "fewer no-shows". The root becomes the **product outcome** "no-show rate in clinics' diaries, 12% → 7%", which the team can move directly and which responds within weeks. SMS reminders return as a candidate solution, and the belief that lower no-shows drive the KR's intent is recorded.
- **Desired outcome vs desired-outcome statement.** O-1.2 is Ulwick's customer measure inside J-1. It informs how important OPP-3.1 is (customer factors); it does not become the root.
- **Top level from the experience map**: *Book → Wait → Attend → Miss or cancel → Refill*. The snapshots' experience-step tags already use these steps.
- **Compare siblings, level by level**, then let the user pick the target.

## Output — `ideate/opportunity-solution-tree.md`

````markdown
---
name: opportunity-solution-tree
product: rebound
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-20
summary: Tree for cutting clinic no-shows from 12% to 7%; target is patients forgetting appointments booked weeks ahead; three solutions under test.
profile: standard
desired-outcome: no-show rate in clinics' diaries, 12% → 7% by 2027-03-31
outcome-type: product outcome
linked-kr: KR-2.1
evidence: ideate/interviews/snapshots/2026-10-02-c-1.md … 2026-10-13-c-5.md; customer-validation/feedback/2026-10-15.md
target-opportunity: OPP-3.1
cycle: 2026-Q4 cycle 1
traces_to: strategy/okrs.md (KR-2.1); ideate/jtbd-analysis.md (J-1, O-1.2)
---

# Opportunity Solution Tree — Rebound: fewer no-shows

## Desired Outcome

| Field | Value |
|---|---|
| Metric | Share of booked appointments marked "did not attend" |
| Meter | Diary status, all active clinics, rolling 4 weeks |
| Baseline | 12% (September 2026) |
| Target | 7% |
| Deadline | 2027-03-31 |
| Constraint | Cancellation-fee disputes must not rise above 1% of appointments |
| Linked KR | KR-2.1: "70% of active clinics enable SMS reminders by end of Q1" |
| Kind | **Product outcome.** KR-2.1 is a traction metric (use of one feature); its owner confirmed the intent is fewer no-shows. SMS reminders are SOL-1 below |

## Evidence

| ID | Kind | Date | Participant / source | Segment / role | Interviewer |
|---|---|---|---|---|---|
| [2026-10-02-c-1] | snapshot | 2026-10-02 | C-1 | 2-practitioner clinic, owner | the user |
| [2026-10-06-c-2] | snapshot | 2026-10-06 | C-2 | 6-practitioner clinic, front desk | the user |
| [2026-10-08-c-3] | snapshot | 2026-10-08 | C-3 | solo practitioner | the user |
| [2026-10-10-c-4] | snapshot | 2026-10-10 | C-4 | 4-practitioner clinic, owner | the user |
| [2026-10-13-c-5] | snapshot | 2026-10-13 | C-5 | 8-practitioner clinic, front desk | the user |
| [FB-007] | feedback item | 2026-10-15 | customer-validation/feedback/2026-10-15.md | beta clinic | — |
| [FB-011] | feedback item | 2026-10-15 | customer-validation/feedback/2026-10-15.md | beta clinic | — |

## Tree at a Glance

```text
OUTCOME: no-show rate 12% → 7%
├─ OPP-1 Book
│  └─ OPP-1.1 "Patients book the next six weeks at the desk and forget which ones they booked"
├─ OPP-2 Wait
│  └─ OPP-2.1 "Patients' plans change and they don't think the clinic needs to know"
├─ OPP-3 Attend
│  ├─ OPP-3.1 "Patients forget appointments booked weeks ahead"  ◄ TARGET
│  │  ├─ SOL-1 SMS reminder 24 h before
│  │  ├─ SOL-2 Front desk phones the next day's long-gap bookings
│  │  └─ SOL-3 Reply-to-confirm message 72 h before
│  └─ OPP-3.2 "Patients feel better and decide they don't need the session"
└─ OPP-4 Miss or cancel
   └─ OPP-4.1 "We only learn about a cancellation when the slot is already gone"
```

## Opportunity Space

| ID | Parent | Opportunity (customer's voice) | Experience step | Evidence | Stories |
|---|---|---|---|---|---|
| OPP-1 | — | Book | Book | — | — |
| OPP-1.1 | OPP-1 | "Patients book the next six weeks at the desk and forget which ones they booked" | Book | [2026-10-06-c-2], [2026-10-13-c-5] | 2 |
| OPP-2 | — | Wait | Wait | — | — |
| OPP-2.1 | OPP-2 | "Patients' plans change and they don't think the clinic needs to know" | Wait | [2026-10-08-c-3] | 1 |
| OPP-3 | — | Attend | Attend | — | — |
| OPP-3.1 | OPP-3 | "Patients forget appointments booked weeks ahead" | Attend | [2026-10-02-c-1], [2026-10-06-c-2], [2026-10-10-c-4], [2026-10-13-c-5], [FB-007] | 5 |
| OPP-3.2 | OPP-3 | "Patients feel better and decide they don't need the session" | Attend | [2026-10-08-c-3], [2026-10-10-c-4] | 2 |
| OPP-4 | — | Miss or cancel | Miss or cancel | — | — |
| OPP-4.1 | OPP-4 | "We only learn about a cancellation when the slot is already gone" | Miss or cancel | [2026-10-02-c-1], [FB-011] | 2 |

<!-- FB-007 asked for "an SMS integration"; recorded as evidence for OPP-3.1, and SMS returns as SOL-1. -->

## Prioritisation

### Level 1: Book, Wait, Attend, Miss or cancel

| Opportunity | Sizing | Market | Company | Customer | Choice |
|---|---|---|---|---|---|
| OPP-1 Book | 2 of 5 clinics | Table stakes | Fits | Medium | next |
| OPP-2 Wait | 1 of 5 | Not addressed by rivals | Fits | Low | park |
| OPP-3 Attend | 5 of 5, weekly | Rivals send reminders; a gap if we don't | Guiding policy: "full diaries for small clinics" | High: lost income every week | **chosen** |
| OPP-4 Miss or cancel | 2 of 5 | Differentiator | Fits | Medium | next |

### Level 2: children of OPP-3

| Opportunity | Sizing | Market | Company | Customer | Choice |
|---|---|---|---|---|---|
| OPP-3.1 Forgetting | 4 snapshots + 1 feedback item | Table stakes | Fits | High; supports O-1.2 | **target** |
| OPP-3.2 Feeling better | 2 snapshots | Clinical, not product | Clinicians' call | Medium | park; share with clinics |

**Target opportunity:** OPP-3.1. Every clinic raised it, it costs them income weekly, and it moves the outcome most directly. Chosen by the user on 2026-10-20; reversible, revisited after T-1.

## Solutions for OPP-3.1

| ID | Solution | Kind | Pass | Carried forward? |
|---|---|---|---|---|
| SOL-1 | SMS reminder 24 h before | software | 1 | yes |
| SOL-2 | Front desk phones tomorrow's bookings made more than two weeks ago | non-software | 2: "no new code" | yes |
| SOL-3 | Reply-to-confirm message 72 h before; unconfirmed slots offered to the waitlist | software | 1 | yes |
| SOL-4 | Calendar-file attachment on the booking email | software | 1 | parked |
| SOL-5 | Deposit at booking | policy | 2: "one week" | parked; viability and ethics doubts |

## Assumptions

| ID | Solution | Assumption | Type | Importance | Evidence today | Test first? |
|---|---|---|---|---|---|---|
| A-1 | SOL-1, SOL-3 | Patients read a text from the clinic within a day | desirability | high | none | yes |
| A-2 | SOL-2 | Front desks have ten free minutes a day to phone | viability | high | [2026-10-13-c-5] says no | yes |
| A-3 | SOL-3 | Patients reply to confirm when asked | usability | high | none | yes |
| A-4 | SOL-1, SOL-3 | The text reveals nothing about treatment to someone else reading the phone | ethical | high | none | yes |
| A-5 | SOL-3 | A slot released 72 h ahead can be re-filled | feasibility | medium | waitlist data, 3 clinics | later |
| A-6 | all | Fewer no-shows keeps clinics subscribed (the KR's intent) | viability | medium | KR owner's belief | later |

## Assumption Tests

| ID | Tests | Across | Test | Success criterion (set before running) | Runs it | Record |
|---|---|---|---|---|---|---|
| T-1 | A-1, A-3 | SOL-1, SOL-3 | Two clinics send manual texts for two weeks; half the patients get the 24 h text, half the 72 h confirm request | At least 70% of 72 h requests get a reply; no-shows in both groups below 8% | the user, with C-2 and C-4 | not yet run |
| T-2 | A-2 | SOL-2 | Front desk at C-5 logs phoning time for one week | Calls take under 10 minutes a day on 4 of 5 days | the user, with C-5 | not yet run |
| T-3 | A-4 | SOL-1, SOL-3 | Message wording reviewed with 5 patients via C-1 | 0 of 5 say the text reveals more than they'd want a family member to see | the user | not yet run |

## Re-plan Trigger

If no-shows in the test clinics stay above 10% after four weeks of the chosen solution, or new snapshots keep reporting forgotten appointments, return to OPP-3 and compare OPP-3.2 and OPP-4.1.

## Hand-off

- `impact-mapping`: WHY = the outcome above (fields from KR-2.1); for the actor "patient with a long-gap booking", the impact "confirms or cancels ahead instead of missing" is explained by OPP-3.1; SOL-1…3 are the WHAT candidates, with A-1…A-6 and T-1…T-3.
- Next cycle: OPP-4.1, OPP-1.1 and parked SOL-4.

## Version Log

| Version | Date | Change | Trigger |
|---|---|---|---|
| 1.0.0 | 2026-10-20 | First tree | Ideate, cycle 1 |
````

## Why this is right at standard

| Choice | Reason |
|---|---|
| Root reclassified from "enable SMS reminders" | A traction metric decides the solution; SMS stays as SOL-1, compared fairly |
| O-1.2 informs sizing but is not the root | Desired-outcome statement and desired outcome are different things |
| Compared level by level | Attend vs Book is one decision; forgetting vs feeling better is another |
| Five solutions generated, three carried forward, one non-software | Tests compare options instead of voting on SMS |
| A-4 is ethical | A reminder text can reveal treatment to whoever reads the phone |
| Criteria have numbers and dates set before the runs | The verdict cannot be argued after the fact |
