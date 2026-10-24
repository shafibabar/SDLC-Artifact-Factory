# Example 1 — Lean: a ranked opportunity list for a one-studio booking app (simplest case)

Self-contained. A class-booking web app built by one person for one pottery studio (six wheels, about 120 members), at the **lean** profile. `phase-requirements.json` marks the tree **optional** at lean; the user has heard from customers, so the agent writes the short form: one product outcome and a ranked list, not a tree.

## Input

> **KR (strategy/okrs.md, KR-1.2):** "Re-fill at least half of the class spots freed by cancellations, from about 20% today, by the end of the spring term."
>
> **Evidence:** two interview snapshots the agent wrote from the user's notes (`2026-10-14-m-3`, `2026-10-16-m-7`), and the studio's first feedback log (`customer-validation/feedback/2026-10-20.md`, items FB-001 to FB-004).
>
> The user (the studio owner, who also built the app): "Members keep asking for an app with push notifications. Should I just build that?"

## Working it

- **Classify the KR.** Re-filled freed spots is something members do through the app, and the studio can move it directly: a **product outcome**. It can sit at the root as written.
- **"Push notifications" is a solution.** The need behind it, heard in both snapshots and two feedback items, is "I only find out a spot opened if I happen to check". It goes on the list in that form; push is one idea among several for it.
- **No tree at lean.** Five opportunities, each in the member's voice, compared with each other on how many raised it, how often, and how much it cost them. Ratings at n = 2 interviews plus four feedback items would be noise, so the ranking is a comparison with a one-line reason each.
- **A target, two ideas, one check.** The owner chooses the target. The agent lists two ideas, one of them non-software, and the riskiest assumption with a check whose bar is set first.

## Output — `ideate/opportunity-solution-tree.md`

```markdown
---
name: opportunity-solution-tree
product: kiln-room-bookings
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-10-21
summary: Lean ranked list for re-filling freed class spots; target is members not knowing a spot opened unless they happen to check.
profile: lean
desired-outcome: share of freed class spots re-filled, ~20% → 50% by end of spring term
outcome-type: product outcome
linked-kr: KR-1.2
evidence: ideate/interviews/snapshots/2026-10-14-m-3.md; ideate/interviews/snapshots/2026-10-16-m-7.md; customer-validation/feedback/2026-10-20.md
target-opportunity: OPP-1
traces_to: strategy/okrs.md (KR-1.2); ideate/user-personas.md (Priya, member)
---

# Opportunities — Kiln Room bookings

**Desired outcome (product outcome):** share of freed class spots re-filled, ~20% → 50%, by the end of the spring term. Linked KR: KR-1.2.

## Evidence

| ID | Kind | Date | Source |
|---|---|---|---|
| [2026-10-14-m-3] | snapshot | 2026-10-14 | Member M-3, interviewed by the user |
| [2026-10-16-m-7] | snapshot | 2026-10-16 | Member M-7, interviewed by the user |
| [FB-001], [FB-002], [FB-003], [FB-004] | feedback items | 2026-10-20 | customer-validation/feedback/2026-10-20.md |

## Ranked Opportunities

| Rank | ID | Opportunity (customer's voice) | Experience step | Evidence | Stories | Why this rank |
|---|---|---|---|---|---|---|
| 1 | OPP-1 | "I only find out a spot opened if I happen to check" | Find a spot | [2026-10-14-m-3], [2026-10-16-m-7], [FB-001], [FB-003] | 4 | Most heard; both members missed a class they wanted last month |
| 2 | OPP-2 | "Cancelling feels awkward, so I just don't turn up" | Cancel | [2026-10-16-m-7], [FB-002] | 2 | No-shows free nothing, so nothing can be re-filled |
| 3 | OPP-3 | "By the time I see the opening it's two hours away and I can't get there" | Find a spot | [2026-10-14-m-3] | 1 | Real, but one story; may shrink if OPP-1 is served |
| 4 | OPP-4 | "I don't know if a beginner can take an intermediate spot" | Book | [FB-004] | 1 | One item; a rule question as much as a product one |
| 5 | OPP-5 | "I'd swap my Tuesday for a Thursday if I could" | Rebook | [assumption] | 0 | The owner's hunch; ask in the next interview |

**Target opportunity:** OPP-1. Four independent stories, and every spot freed but not seen is a spot the outcome loses. Chosen by the user on 2026-10-21; revisit after the check below.

## Solution Ideas for the Target

- A waitlist on full classes that texts the first person when a spot frees (members asked for "push notifications"; a text is the same idea without an app install).
- The owner posts freed spots in the members' group chat, by hand, for two weeks (non-software).

**Riskiest assumption and how to check it:** members will take a spot offered at short notice (desirability) — run the group-chat version for two weeks — success if at least 6 of the first 10 spots posted are taken within two hours, set on 2026-10-21 before the first post.
```

## Why this is right at lean

| Choice | Reason |
|---|---|
| A ranked list, not a tree | The lean shape; five opportunities need no nesting |
| "Push notifications" recorded as an idea, not an opportunity | It admits one solution; the need behind it admits several |
| The non-software idea is tested first | It checks the riskiest assumption in two weeks with no code |
| OPP-5 kept, tagged `[assumption]` | The owner's hunch is not evidence; it becomes a question for the next interview |
| The bar was set before the first post | A result cannot be read as success after the fact |
