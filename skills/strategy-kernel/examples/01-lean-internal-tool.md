# Example 1 — A lean internal tool (simplest case)

Self-contained. A product built by one person for one office, at the **lean** profile: no market, no competitor analysis, no stakeholder map. It shows that a kernel still earns its place at this size, and that it fits in about 150 words.

## Input

> Problem statement: "A lunch-order tracker for a 20-person office. People pick from a daily menu by 10:30, an admin sends one combined order to the restaurant, and costs are split per person."
>
> Vision (already approved): "Every working day, everyone in the office gets the lunch they chose, on time, and nobody owes or chases anybody. The person who used to coordinate it gets their morning back, because ordering is one choice before a cutoff and paying is one exact split."

## Working it

**Challenges listed (lean: a short list):**
1. People forget to order by 10:30, so the admin still chases them.
2. Small debts pile up because splitting by hand is tedious.
3. The restaurant changes its menu without notice.
4. Nobody will install another app for lunch.

**Crux.** Challenge 4 sits under the others: if the tool is one more thing to open, people forget (1) and the admin is back to chasing. It is important, because every other benefit depends on people actually using it, and addressable, because the office already lives in one chat tool. Challenge 3 is real but rare and is set aside.

## Output — the kernel artifact

```markdown
---
name: strategy-kernel
product: lunch-tracker
version: 1.0.0
phase: strategy
created: 2026-10-19
summary: Strategy: colleagues won't open another app for lunch, so ordering and settling happen inside the office chat with one cutoff reminder.
owner: product-strategist
traces_to: strategy/vision-statement.md
---

# Strategy Kernel

## Diagnosis
Lunch fails when someone forgets to order or to pay, and they forget because ordering lives outside where they already are.
**Crux:** getting 20 people to act before 10:30 without opening anything new.

## Guiding Policy
Do everything inside the office chat. **Relies on:** the habit everyone already has (leverage).
**Rules out:**
- A separate web or mobile app — because a new place to go is the crux itself.
- Menu management features — because menu changes are rare and the admin can paste them.

## Coherent Actions
| # | Action | Reinforces |
|---|---|---|
| 1 | Chat command to pick from today's menu | The policy |
| 2 | One automatic reminder at 10:00 to people who haven't picked | 1 |
| 3 | The exact split posted in the same thread after the order | 1, and the vision's "nobody owes anybody" |

## Proximate Objectives
- Every regular orders through the chat command, with no chasing.

## Review Trigger
**Wrong if:** people still miss the cutoff after reminders — **watched in:** the admin's count of late orders.
```

**About 150 words in the body.** Note what is *not* there: no "strategy: get 100% adoption" (a goal), no number in the proximate objective (the OKR set adds the Key Result, e.g. on-time order days), and no mission line (the vision already says what the tool is for).

## What a weak first draft looked like

> "Strategy: make lunch ordering simple, fast and fun for everyone, increase adoption to 100%, and reduce admin time by 80%."

It fails three hallmarks at once. "Simple, fast and fun" is fluff: delete the adjectives and nothing is decided. "100%" and "80%" are goals, not a strategy: they say how much, not how. And it names no challenge, so nobody could tell whether a separate app or a chat command is the right call.
