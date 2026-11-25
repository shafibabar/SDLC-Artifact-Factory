# Example 1 (lean): Choir Rehearsal Sign-Up

Self-contained input and output. The point: the smallest product still gets a map and a criteria file; requests to drop the edge case and to number differently are declined with the work done.

## Input

- Product: a rehearsal sign-up page one volunteer runs for a community choir. Profile **lean**.
- Request: "Write the criteria for signing up. It's tiny, so number them AC-1, AC-2 and don't bother with edge cases."
- `ideate/user-stories.md`, US-2: "As a singer (P-1), I want to sign up for a rehearsal, so that I have a seat." Rules: BR-1. Seed example: Dev signs up for 3 December and sees his name on the list.
- The map, `ideate/example-maps/US-2.md` (ready):

````markdown
---
name: example-map
story-id: US-2
readiness: ready
---

# Example Map: US-2 Sign up for a rehearsal

## Rules and Examples

### R1: A rehearsal takes at most 30 singers (BR-1)

| Example | Type | Case | Expected outcome | Source |
|---|---|---|---|---|
| R1.E1 | Happy | 12 are signed up for 3 Dec; Dev signs up | Dev is on the list of 13 | ideate/user-stories.md (US-2 seed) |
| R1.E2 | Negative | 30 are signed up; Mara tries | Mara is refused and told the rehearsal is full | product owner, 2026-11-25 (Q-1) |
| R1.E3 | Edge | 29 are signed up; Mara signs up | Mara takes the 30th seat | ideate/user-stories.md (BR-1) |

## Questions for the Product Owner

| ID | Question | Affects | Why it matters | Recommendation | Status | Answer |
|---|---|---|---|---|---|---|
| Q-1 | What happens when it is full? | R1 | Whether there is a waiting list | Refuse and say why | answered | Refuse and say it is full — product owner, 2026-11-25 |
````

## The reply

"**Drafted, awaiting your approval.** A small product still gets an example map and a criteria file for each story, short ones. I used `ideate/example-maps/US-2.md` (ready). Two things I did not do: your numbering `AC-1, AC-2` is replaced by `AC-US-2.1` to `AC-US-2.3`, the only ID form here, which tests and acceptance scenarios trace to; and I kept an edge criterion, which every story has: `AC-US-2.3`, the 30th seat. Happy: `AC-US-2.1`; negative: `AC-US-2.2`. Out of scope: a waiting list. Open questions: none. I drafted this alone; no workshop was held. Next: your approval, then the feature file."

## Output: `ideate/acceptance-criteria/US-2.md`

````markdown
---
name: acceptance-criteria
product: choirseat
story-id: US-2
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-11-25
summary: Signing up for a rehearsal, three criteria covering the 30-singer limit.
profile: lean
run: agent-run
traces_to: ideate/user-stories.md (US-2, BR-1); ideate/example-maps/US-2.md
---

# Acceptance Criteria: US-2 Sign up for a rehearsal

## Story Reference

As a singer (P-1), I want to sign up for a rehearsal, so that I have a seat.

## Derived From

- Example map: ideate/example-maps/US-2.md (Ready, 0 open questions)
- Fit criteria and business rules covered: BR-1
- Quality targets cited, not restated: none

## How These Were Made

Agent-run: one agent (requirements-analyst) drafted these from the example map; no workshop was held.

## Happy Path

### AC-US-2.1: Sign up while seats remain
- From: R1 (R1.E1)

```gherkin
Given 12 singers are signed up for the 3 December rehearsal,
When Dev signs up for it,
Then Dev sees his name on a list of 13 singers.
```

## Error / Negative Scenarios

### AC-US-2.2: A full rehearsal refuses a sign-up
- From: R1 (R1.E2)

```gherkin
Given 30 singers are signed up for the 3 December rehearsal,
When Mara tries to sign up,
Then Mara is told the rehearsal is full
But the list still shows 30 singers.
```

## Boundary / Edge Cases

### AC-US-2.3: The last seat can be taken
- From: R1 (R1.E3)

```gherkin
Given 29 singers are signed up for the 3 December rehearsal,
When Mara signs up,
Then Mara sees her name on a list of 30 singers.
```

## Explicitly Out of Scope

- A waiting list for a full rehearsal: a full rehearsal refuses (product owner, Q-1).
````

## What to notice

- The edge came from the map; nothing was invented to satisfy the rule.
- Two singers taking the last seat at once is not on the map. Had the story needed it, it would go back to the map as a question.
