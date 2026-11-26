# Example 3 (enterprise): Marketplace Returns

Self-contained input and output in three turns. The point: tenant isolation as an edge criterion, a tenant-set limit, a missing behaviour sent back to the map before anything is drafted, and a request to change agreed criteria to match the build.

## Input

- Product: a returns platform used by many retailers (tenants). Profile **enterprise**.
- US-31: "As a retailer's returns clerk (P-2), I want to approve a return, so that the buyer is refunded." Rules: BR-7, BR-9. NFR-SEC-02: tenant isolation.
- `ideate/requirements.md`: BR-7 "A clerk approves alone up to the retailer's approval limit; above it a supervisor approves." BR-9 "Every approval is recorded with who and when."
- The map (ready):

````markdown
---
name: example-map
story-id: US-31
readiness: ready
---

# Example Map: US-31 Approve a return

## Rules and Examples

### R1: A clerk approves alone up to the retailer's limit (BR-7)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R1.E1 | Happy | Fernhill's limit is €200; Noor approves a €80 return | Refund of €80 is started | ideate/requirements.md (BR-7) |
| R1.E2 | Negative | Noor approves a €350 return | It waits for a Fernhill supervisor | ideate/requirements.md (BR-7) |
| R1.E3 | Edge | Noor approves exactly €200 | Refund is started | product owner, 2026-11-25 (Q-1) |

### R2: Every approval is recorded with who and when (BR-9)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R2.E1 | Happy | Noor approves return RT-90 at 14:02 | The audit record shows Noor and 14:02 | ideate/requirements.md (BR-9) |
| R2.E2 | Negative | Noor opens RT-90 and leaves | No approval is recorded | product owner, 2026-11-25 (Q-2) |

### R3: A clerk sees only their own retailer's returns

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R3.E1 | Happy | Noor (Fernhill) opens Fernhill return RT-90 | She can approve it | ideate/nfr-specification.md (NFR-SEC-02) |
| R3.E2 | Negative | Noor opens Oakmart return RT-91 by its reference | She is told no such return exists | product owner, 2026-11-25 (Q-3) |
| R3.E3 | Edge | Noor and a colleague at Oakmart both hold a return numbered 1001 | Noor sees only Fernhill's 1001 | product owner, 2026-11-25 (Q-3) |

## Questions for the Product Owner

| ID | Question | Affects | Why it matters | Recommendation | Status | Answer |
|---|---|---|---|---|---|---|
| Q-1 | Is the limit itself allowed? | R1 | The boundary | Allowed | answered | Allowed — product owner, 2026-11-25 |
| Q-2 | Is viewing recorded as approving? | R2 | Audit accuracy | No | answered | No — product owner, 2026-11-25 |
| Q-3 | What does a clerk see for another retailer's return? | R3 | Leaking that it exists | "No such return" | answered | Agreed — product owner, 2026-11-25 |
````

## Turn 1: "Draft the criteria for US-31."

"**Not drafted.** Criteria and an example map are required for this story. I read `ideate/example-maps/US-31.md`; it is marked ready, but checking the edges shows two cases it does not cover, and I will not decide them. I have added them to the map as questions, so it is now not ready. **For you:** Q-4: if two clerks approve one return at the same moment, is one refund paid and the second clerk told? (I recommend yes.) Q-5: if the refund cannot be started, does the return stay awaiting approval? (I recommend yes.) Answer them, or agree to move either into its own story. The IDs will be `AC-US-31.n`. Agent-run; no workshop was held. Next: your answers."

## Turn 2: "Both are separate stories."

The map gains two rows with status `moved` (to US-44 and US-45, agreed by the product owner, 2026-11-25) and is ready again. Then:

"**Drafted, awaiting your approval.** Map used: `ideate/example-maps/US-31.md` (ready). IDs `AC-US-31.1` to `AC-US-31.6`: happy .1 and .2, negative .3 and .4, edge .5 and .6 (.4 and .6 are tenant isolation, NFR-SEC-02). Not written here: two approvals at once (US-44) and the refund service being unavailable (US-45). Open questions: none. Agent-run; no workshop was held. Next: your approval, then the feature file."

## Output: `ideate/acceptance-criteria/US-31.md`

````markdown
---
name: acceptance-criteria
product: sendback
story-id: US-31
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-11-25
summary: Approving a return within a retailer's limit, recorded and isolated per retailer; six criteria.
profile: enterprise
run: agent-run
traces_to: ideate/user-stories.md (US-31); ideate/example-maps/US-31.md; ideate/requirements.md (BR-7, BR-9); ideate/nfr-specification.md (NFR-SEC-02)
---

# Acceptance Criteria: US-31 Approve a return

## Story Reference

As a retailer's returns clerk (P-2), I want to approve a return, so that the buyer is refunded.

## Derived From

- Example map: ideate/example-maps/US-31.md (Ready, 0 open questions)
- Fit criteria and business rules covered: BR-7, BR-9
- Quality targets cited, not restated: NFR-SEC-02

## How These Were Made

Agent-run: one agent (requirements-analyst) drafted these from the example map; no workshop was held.

## Happy Path

### AC-US-31.1: Approve within the limit
- From: R1 (R1.E1), R3 (R3.E1)

```gherkin
Given Fernhill's approval limit is €200
And Noor, a Fernhill clerk, has opened Fernhill's return RT-90 for €80,
When Noor approves it,
Then a refund of €80 is shown as started.
```

### AC-US-31.2: The approval is on the audit record
- From: R2 (R2.E1, R2.E2)

**Rule:** Every approval, and nothing short of an approval, is on the audit record with the approver and the time.
**Verify:** Approve one return and open a second without approving it, then read both audit records.
**Example:** Noor approves RT-90 at 14:02, and its record shows Noor and 14:02; a return she only opens shows no approval.

## Error / Negative Scenarios

### AC-US-31.3: Above the limit waits for a supervisor
- From: R1 (R1.E2)

```gherkin
Given Fernhill's approval limit is €200,
When Noor approves a return of €350,
Then the return is shown as waiting for a Fernhill supervisor
But no refund is started.
```

### AC-US-31.4: Another retailer's return does not appear
- From: R3 (R3.E2)

```gherkin
Given RT-91 is a return belonging to Oakmart,
When Noor, a Fernhill clerk, opens RT-91 by its reference,
Then she is told "No such return"
But nothing about RT-91 is shown.
```

## Boundary / Edge Cases

### AC-US-31.5: Exactly the limit is allowed
- From: R1 (R1.E3)

```gherkin
Given Fernhill's approval limit is €200,
When Noor approves a return of exactly €200,
Then a refund of €200 is shown as started.
```

### AC-US-31.6: The same number at two retailers
- From: R3 (R3.E3)

```gherkin
Given Fernhill and Oakmart each have a return numbered 1001,
When Noor, a Fernhill clerk, searches for 1001,
Then she sees only Fernhill's return.
```

## Explicitly Out of Scope

- Two clerks approving one return at the same moment: US-44.
- The refund service being unavailable: US-45.
````

## Turn 3: "The build lets a clerk approve €220 on a €200 limit. Just change AC-US-31.3 and .5 to match."

"**Not changed.** An agreed criterion is not edited to match the build; `AC-US-31.3` and `AC-US-31.5` stand. What differs: the build allows €20 above the limit. If you want a tolerance, answer this as a new question on `ideate/example-maps/US-31.md`: may a clerk approve above the retailer's limit, and by how much? My recommendation: no, treat it as a defect. If your answer changes the rule, I update the map, then these two criteria (same IDs, new version, back to you for approval), and name the feature files and acceptance scenarios that trace to them."

## What to notice

- A case the map did not cover stopped the draft: an edge is never filled in by the writer.
- Isolation appears as criteria because the map has the rule; the speed of the search would be an NFR.
