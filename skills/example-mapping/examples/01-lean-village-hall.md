# Example 1 (lean): Village Hall Booking

Self-contained input and output. The point: a very small product, a request to skip the map, one unanswered question.

## Input

- Product: a booking page one volunteer runs for a village hall. Profile **lean**.
- Request: "It's tiny. Skip the example map, just write me the criteria for cancelling, and assume whatever makes sense."
- `ideate/user-stories.md`, US-3: "As a hall hirer (P-1), I want to cancel my booking, so that I am not charged for a date I cannot use." Rules: BR-2. Seed example: Maya booked Saturday 14 December for £60 and cancels on 1 December; she gets £60 back.
- Requirements header, BR-2: "A booking cancelled at least 7 days before its date is refunded in full. Source: hall committee minutes, 2025."
- The backlog says nothing about later cancellations.

## The reply

"The map comes before the criteria at every size, and I can't answer for you what happens inside 7 days. Here is the short map and one question. **Not ready** (Q-1). I made it alone, playing customer, developer and tester; no workshop was held. Assumption to confirm: R2, that a late cancellation refunds nothing. Reply to Q-1 and I will finish the map for your approval; criteria follow."

## Output: `ideate/example-maps/US-3.md`

````markdown
---
name: example-map
product: hallbook
story-id: US-3
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-11-25
summary: Cancelling a hall booking, two rules; not ready until the late-cancellation refund (Q-1) is decided.
profile: lean
run: agent-run
readiness: not-ready
traces_to: ideate/user-stories.md (US-3, BR-2)
---

# Example Map: US-3 Cancel a booking

## Story

As a hall hirer (P-1), I want to cancel my booking, so that I am not charged for a date I cannot use.

- Seed example: Maya booked Sat 14 Dec for £60 and cancels on 1 Dec; she gets £60 back.
- Cited rules and targets: BR-2

## How This Map Was Made

Agent-run: one agent (requirements-analyst) played all three perspectives in turn; no workshop was held.

- Read: ideate/user-stories.md (US-3, requirements header BR-2)

| Perspective | What it raised |
|---|---|
| Customer | Q-1: a hirer needs to know what a late cancellation costs |
| Developer | R1.E3: how the 7 days are counted |
| Tester | R1.E2, R2: just inside the limit |

## Rules and Examples

### R1: A cancellation at least 7 days before the booking date is refunded in full (BR-2)
- Source: ideate/user-stories.md (BR-2)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R1.E1 | Happy | Maya cancels her £60 booking for Sat 14 Dec on 1 Dec | £60 is refunded and the date is free again | ideate/user-stories.md (US-3 seed) |
| R1.E2 | Negative | Maya cancels the same booking on 8 Dec, 6 days before | unknown (Q-1) | assumption (Q-1) |
| R1.E3 | Edge | Maya cancels on 7 Dec, exactly 7 days before | £60 is refunded | ideate/user-stories.md (BR-2) |

### R2: A cancellation inside 7 days refunds nothing
- Source: assumption (Q-1)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R2.E1 | Happy | Tom cancels his £60 booking 2 days before | £0 is refunded and the date is free again | assumption (Q-1) |
| R2.E2 | Negative | Tom cancels 8 days before | The nil refund does not apply; £60 is refunded | ideate/user-stories.md (BR-2) |

## Questions for the Product Owner

| ID | Question | Affects | Why it matters | Recommendation | Status | Answer |
|---|---|---|---|---|---|---|
| Q-1 | What does a hirer get back when cancelling fewer than 7 days before? | R2 | Decides the money returned to every late canceller | Nothing back, shown before they confirm | open | — |

## Split Check

- Rules: 2 · Open questions: 1
- Decision: keep; one behaviour for one persona

## Readiness

**Verdict:** Not ready
- Blocking: Q-1
````

## What to notice

- The request to skip and to assume is answered with the map, not a refusal alone and not criteria.
- BR-2 settles the 7-day boundary, so that is not a question; it says nothing about late refunds, so that is, and R1.E2's outcome stays `unknown (Q-1)`.
- The assumed rule keeps its label until the product owner replies.
