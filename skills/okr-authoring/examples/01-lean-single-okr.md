# Example 1 — A lean internal tool: one OKR (simplest case)

Self-contained. A product built by one person for one office, at the **lean** profile. It shows the whole set at its smallest: one Objective from the kernel's single proximate objective, three KRs with pre-launch baselines, one health metric, and a check-in log a solo product owner keeps in the file.

## Input

> Problem statement: "A lunch-order tracker for a 20-person office. People pick from a daily menu by 10:30, an admin sends one combined order, and costs are split per person."
>
> Vision (approved), North Star implication: *on-time, fully-settled order days per month*.
>
> Strategy kernel (approved): **Crux:** getting 20 people to act before 10:30 without opening anything new. **Guiding policy:** do everything inside the office chat; rules out a separate app and menu management. **Proximate objective handed on:** "Every regular orders through the chat command, with no chasing."

## Working it

- **One Objective.** Lean means Wodtke's one OKR. The kernel hands on exactly one proximate objective, so the Objective is that line, made a little more specific. A second Objective ("make menus easy to update") would be something the policy rules out.
- **Type: aspirational.** Nobody depends on a delivery date; the team has never achieved this behaviour. Starting confidence about 50%.
- **The North Star is not redefined.** The set says which part of it this cycle moves (the "on time" half, through orders before the cutoff).
- **Outputs demoted.** The first draft had "Ship the /lunch chat command" as a KR. It ships whether or not anyone uses it, so it became an Initiative.

## Output — the OKR artifact

```markdown
---
name: okr-set
product: lunch-tracker
cycle: Q1 2027
version: 1.0.0
phase: strategy
created: 2026-10-21
summary: Q1 2027 OKRs for lunch-tracker: every regular orders through the chat command without being chased (one aspirational Objective, three KRs).
owner: product-strategist
traces_to: strategy/vision-statement.md; strategy/strategy-kernel.md
---

# OKR Set — Q1 2027

## Strategy this set serves
**Crux:** getting 20 people to act before 10:30 without opening anything new.
**Guiding policy:** do everything inside the office chat.
**North Star (from the vision):** on-time, fully-settled order days per month — this cycle moves the "on time" part.
**Levels:** solo product owner; product and company OKRs are one set.

## Objective 1 — Lunch orders itself through the chat, and nobody has to chase anyone
**Type:** aspirational
**From the kernel's proximate objective:** "Every regular orders through the chat command, with no chasing."

| KR | Metric | Baseline | Target | Dir | Owner | Start confidence |
|---|---|---|---|---|---|---|
| KR1.1 | Share of regulars' orders placed through the chat command | n/a (pre-launch) | 90% | ↑ | the product owner | 50% |
| KR1.2 | Share of order days with every regular's order in by 10:30 | n/a (pre-launch) | 80% | ↑ | the product owner | 50% |
| KR1.3 | Reminder messages the admin sends by hand per week | 15 (admin's count, last 4 weeks) | 2 | ↓ | the product owner | 50% |

**We believe** a 10:00 reminder sent only to people who haven't picked **will move** KR1.2, **and we will know when** late orders fall in the first two weeks.

**Candidate Initiatives:**
- Ship the /lunch chat command → KR1.1
- Automatic 10:00 reminder to non-pickers → KR1.2, KR1.3
- Exact split posted in the order thread → health metric below

## Health Metrics
| Metric | Healthy range | Status |
|---|---|---|
| Open unpaid shares older than a week | 0 | green |

## Weekly Check-in Log
| Week of | KR | Confidence | Note |
|---|---|---|---|

## Grading (quarter-end)
| KR | Type | Expected | Final value | Grade | Committed miss: what happened and recovery plan |
|---|---|---|---|---|---|

| Objective | Grade (avg) | What we learned |
|---|---|---|
```

## Six weeks in — what the log looks like

| Week of | KR | Confidence | Note |
|---|---|---|---|
| 2027-01-04 | KR1.1 | 50% | Command live Monday; 9 of 18 regulars used it |
| 2027-01-04 | KR1.2 | 50% | Reminder not yet built |
| 2027-02-08 | KR1.2 | 25% | Fridays still late: people work from home and miss the chat. Priority: Friday reminder by direct message |

The drop to 25% on KR1.2 is the leading signal. The KR stays fixed; the Initiative changes.

## What a weak first draft looked like

> "O1: Launch the lunch bot. O2: Make ordering fun. O3: 100% adoption. KR: ship the bot by January; 20 users."

Three Objectives at lean (one is a number, one is fluff), an output KR, a raw count with no baseline, and no type. It also reads like the kernel never existed.
