# Example 2 (standard): Repeat Prescription Request

Self-contained input and output. The point: the rule format beside Given/When/Then, a fit criterion covered, a speed target cited instead of written, one criterion citing two examples, and a case that belongs to another story.

## Input

- Product: an online service for a veterinary practice. Profile **standard**.
- US-5: "As a pet owner (P-1), I want to request a repeat prescription, so that my animal does not run out." Rules: BR-3. Request: "Include that the request page loads in under 2 seconds."
- `ideate/requirements.md`: BR-3 "A repeat is accepted only within 6 months of the last vet check." FR-2.1 fit criterion: "an accepted request appears in the vet's approval list with the animal, medicine and owner." NFR-PERF-01 governs page loading.
- The map (ready):

````markdown
---
name: example-map
story-id: US-5
readiness: ready
---

# Example Map: US-5 Request a repeat prescription

## Rules and Examples

### R1: A repeat is accepted only within 6 months of the last vet check (BR-3)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R1.E1 | Happy | Bruno was checked on 10 September; Sam asks on 25 November | The request goes to the vet's approval list | ideate/requirements.md (FR-2.1) |
| R1.E2 | Negative | Bruno was checked on 2 April; Sam asks on 25 November | Refused; Sam is asked to book a check | product owner, 2026-11-25 (Q-1) |
| R1.E3 | Edge | Bruno was checked on 25 May; Sam asks on 25 November | Accepted | product owner, 2026-11-25 (Q-2) |

### R2: One request per medicine may be waiting at a time

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R2.E1 | Happy | Bruno has nothing waiting; Sam asks for his thyroid tablets | One request is waiting | product owner, 2026-11-25 (Q-3) |
| R2.E2 | Negative | A thyroid-tablet request is waiting; Sam asks again | No second request; Sam sees the one waiting | product owner, 2026-11-25 (Q-3) |

## Questions for the Product Owner

| ID | Question | Affects | Why it matters | Recommendation | Status | Answer |
|---|---|---|---|---|---|---|
| Q-1 | What does an owner see when the check is too old? | R1 | Whether they can act | Ask them to book | answered | Yes — product owner, 2026-11-25 |
| Q-2 | Is exactly 6 months still inside? | R1 | The limit | Inside | answered | Inside — product owner, 2026-11-25 |
| Q-3 | May the same medicine be requested twice? | R2 | Double dispensing | One waiting | answered | One waiting — product owner, 2026-11-25 |
| Q-4 | Can an owner cancel a request? | story | Another behaviour | Own story | moved | moved to US-12 — agreed by product owner, 2026-11-25 |
````

## The reply

"**Drafted, awaiting your approval.** Criteria and an example map are required for this story. Map used: `ideate/example-maps/US-5.md` (ready). IDs `AC-US-5.1` to `AC-US-5.4`: happy 5.1 and 5.2, negative 5.3, edge 5.4. Your 'the request page loads in under 2 seconds' is not written as a criterion: it is a quality target, so the file cites NFR-PERF-01 instead; check that the figure there is the one you mean. Out of scope: cancelling (US-12). Open questions: none. Agent-run; no workshop was held. Next: your approval, then the feature file."

## Output: `ideate/acceptance-criteria/US-5.md`

````markdown
---
name: acceptance-criteria
product: pawpath
story-id: US-5
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-11-25
summary: Repeat prescription requests, four criteria on the 6-month check and one waiting request.
profile: standard
run: agent-run
traces_to: ideate/user-stories.md (US-5); ideate/example-maps/US-5.md; ideate/requirements.md (BR-3, FR-2.1); ideate/nfr-specification.md (NFR-PERF-01)
---

# Acceptance Criteria: US-5 Request a repeat prescription

## Story Reference

As a pet owner (P-1), I want to request a repeat prescription, so that my animal does not run out.

## Derived From

- Example map: ideate/example-maps/US-5.md (Ready, 0 open questions)
- Fit criteria and business rules covered: FR-2.1, BR-3
- Quality targets cited, not restated: NFR-PERF-01

## How These Were Made

Agent-run: one agent (requirements-analyst) drafted these from the example map; no workshop was held.

## Happy Path

### AC-US-5.1: A request within 6 months reaches the vet
- From: R1 (R1.E1)

```gherkin
Given Bruno's last vet check was on 10 September,
When Sam requests a repeat of Bruno's thyroid tablets on 25 November,
Then the vet's approval list shows Bruno, the thyroid tablets and Sam.
```

### AC-US-5.2: One waiting request per medicine
- From: R2 (R2.E1, R2.E2)

**Rule:** At most one request for the same animal and medicine is waiting at a time.
**Verify:** Request a medicine, request it again before the vet decides, and count the waiting requests.
**Example:** Sam asks twice for Bruno's thyroid tablets; one request is waiting and Sam is shown it.

## Error / Negative Scenarios

### AC-US-5.3: A check older than 6 months refuses the request
- From: R1 (R1.E2)

```gherkin
Given Bruno's last vet check was on 2 April,
When Sam requests a repeat on 25 November,
Then Sam is asked to book a vet check
But nothing is added to the vet's approval list.
```

## Boundary / Edge Cases

### AC-US-5.4: Exactly 6 months is still inside
- From: R1 (R1.E3)

```gherkin
Given Bruno's last vet check was on 25 May,
When Sam requests a repeat on 25 November,
Then the request appears in the vet's approval list.
```

## Explicitly Out of Scope

- Cancelling a request: US-12 (product owner, Q-4).
````
