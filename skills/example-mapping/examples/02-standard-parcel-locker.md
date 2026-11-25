# Example 2 (standard): Parcel Locker Pickup Expiry

Self-contained input and output. The point: counter-examples and limits, a quality target cited instead of mapped, and a case moved to a new story with the product owner's agreement.

## Input

- Product: parcel lockers for apartment blocks. Profile **standard**.
- US-7: "As a resident (P-1), I want my parcel held for a known time, so that I can collect it when I get home." Rules: BR-4, BR-5. NFR-PERF-02 governs how quickly a collection code is checked. Seed example: a parcel dropped Monday 18:00 is still collectable Wednesday 20:00.
- `ideate/requirements.md`: BR-4 "A parcel is held for 72 hours from drop-off." BR-5 "An expired parcel's locker is released to the courier for return." FR-3.2 fit criterion: "at expiry the resident's code is refused with the reason."
- Round 1 questions: Q-1 (is a reminder sent?), Q-2 (can a resident away from home extend the hold, and does it cost?) and Q-3 (is 18:00 exactly still inside the hold, and does a collection then beat the courier?).
- Product owner, 2026-11-25: "Q-1: yes, one, 24 hours before expiry, only if the parcel is still there. Q-2: extension is a separate thing, make it its own story. Q-3: yes to both."

## Output: `ideate/example-maps/US-7.md` (after the answers)

````markdown
---
name: example-map
product: dropbay
story-id: US-7
version: 1.1.0
phase: ideate
owner: requirements-analyst
created: 2026-11-25
summary: Parcel hold and expiry, three rules; ready, with hold extension moved to US-19.
profile: standard
run: agent-run
readiness: ready
traces_to: ideate/user-stories.md (US-7); ideate/requirements.md (BR-4, BR-5, FR-3.2); ideate/nfr-specification.md (NFR-PERF-02)
---

# Example Map: US-7 Parcel held for a known time

## Story

As a resident (P-1), I want my parcel held for a known time, so that I can collect it when I get home.

- Seed example: a parcel dropped Monday 18:00 is still collectable Wednesday 20:00.
- Cited rules and targets: BR-4, BR-5, NFR-PERF-02

## How This Map Was Made

Agent-run: one agent (requirements-analyst) played all three perspectives in turn; no workshop was held.

- Read: ideate/user-stories.md (US-7); ideate/requirements.md (BR-4, BR-5, FR-3.2); ideate/nfr-specification.md (NFR-PERF-02)

| Perspective | What it raised |
|---|---|
| Customer | Q-1, Q-2: warning before expiry, being away |
| Developer | R2.E3: collection and courier release at the same moment |
| Tester | R1.E2, R1.E3: one minute past and exactly on 72 hours |

## Rules and Examples

### R1: A parcel can be collected for 72 hours from drop-off (BR-4)
- Source: ideate/requirements.md (BR-4)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R1.E1 | Happy | Dropped Mon 18:00; Ana enters her code Wed 20:00 | The locker opens | ideate/user-stories.md (US-7 seed) |
| R1.E2 | Negative | Same parcel; Ana enters her code Thu 18:01 | The code is refused and she is told it expired Thu 18:00 | ideate/requirements.md (FR-3.2) |
| R1.E3 | Edge | Same parcel; Ana enters her code Thu 18:00 exactly | The locker opens; the hold ends after 18:00 | product owner, 2026-11-25 (Q-3) |

### R2: An expired parcel's locker is released to the courier for return (BR-5)
- Source: ideate/requirements.md (BR-5)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R2.E1 | Happy | Locker 12 expired Thu 18:00; the courier arrives Fri 09:00 | The courier can open locker 12 and it is marked for return | ideate/requirements.md (BR-5) |
| R2.E2 | Negative | The courier tries locker 12 on Wed 09:00, before expiry | Locker 12 stays shut | ideate/requirements.md (BR-5) |
| R2.E3 | Edge | Ana's locker was opened by her at Thu 18:00 as the courier's round begins | The parcel is recorded as collected and is not listed for return | product owner, 2026-11-25 (Q-3) |

### R3: The resident gets one reminder 24 hours before expiry
- Source: product owner, 2026-11-25 (Q-1)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R3.E1 | Happy | Ana's parcel expires Thu 18:00 and is still there Wed 18:00 | Ana gets one reminder naming Thu 18:00 | product owner, 2026-11-25 (Q-1) |
| R3.E2 | Negative | Ana collected on Tue 08:00 | No reminder is sent | product owner, 2026-11-25 (Q-1) |

## Questions for the Product Owner

| ID | Question | Affects | Why it matters | Recommendation | Status | Answer |
|---|---|---|---|---|---|---|
| Q-1 | Is the resident reminded before expiry? | story | Decides whether expiry surprises people | One reminder 24 hours before | answered | Yes, one, 24 hours before, only if still there — product owner, 2026-11-25 |
| Q-2 | Can a resident extend the hold, and at what cost? | story | Adds payment and a second limit | Separate story | moved | moved to US-19 — agreed by product owner, 2026-11-25 |
| Q-3 | Is 18:00 exactly still inside the hold, and does a collection then beat the courier? | R1, R2 | Decides who gets a parcel on the limit | Yes to both | answered | Yes to both — product owner, 2026-11-25 |

## Split Check

- Rules: 3 · Open questions: 0
- Decision: split agreed: hold extension is US-19, with its own map

## Readiness

**Verdict:** Ready
- Blocking: none
````

## What to notice

- How fast the code is checked is not a rule here; NFR-PERF-02 is cited.
- BR-4 did not say which side of the limit 18:00 falls on, so the tester's edge became Q-3.
- Extension left no rule behind in this map. US-19 is proposed through the story backlog and mapped separately.
- Next step: the product owner approves the map, then acceptance criteria are drafted from it.
