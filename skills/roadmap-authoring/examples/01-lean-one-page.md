# Example 1 — A lean internal tool: the whole roadmap on one page (simplest case)

Self-contained. A product built by one person for one office, at the **lean** profile. It shows the five primary components at their smallest: a vision line, the one Objective, Now / Next / Later, four themes written as problems, a disclaimer, plus critical-path prioritisation, policy-cited exclusions and the objections pre-listed for a solo product owner.

## Input

> Problem statement: "A lunch-order tracker for a 20-person office. People pick from a daily menu by 10:30, an admin sends one combined order, and costs are split per person."
>
> Vision (approved), North Star: *on-time, fully-settled order days per month*.
>
> Strategy kernel (approved): **Crux:** getting 20 people to act before 10:30 without opening anything new. **Guiding policy:** do everything inside the office chat; **rules out** a separate web or mobile app (a new place to go is the crux itself) and menu management (menus change rarely; the admin can paste them). **Coherent actions:** (1) chat command to pick from today's menu; (2) one automatic reminder at 10:00 to people who haven't picked; (3) the exact split posted in the same thread.
>
> OKR set Q1 2027 (approved): **O1** (aspirational) "Lunch orders itself through the chat, and nobody has to chase anyone." KR1.1 share of regulars' orders placed through the chat command (n/a → 90%); KR1.2 share of order days with every order in by 10:30 (n/a → 80%); KR1.3 hand-sent reminders per week (15 → 2). Health metric: open unpaid shares older than a week = 0. Candidate Initiatives: the /lunch command; the 10:00 reminder; the split in the thread.

## Working it

- **The first draft was a feature list with dates:** "Oct 30 — /lunch command. Nov 15 — reminders. Dec — mobile app. Jan — menu editor. Feb — payments integration." Two of the five are things the guiding policy rules out, every row is a solution, and the dates are guesses.
- **Rewrite each feature into the problem it answers.** "/lunch command" → "I forget to order because ordering lives outside the chat." The command becomes a Now candidate solution, one bet among possible others.
- **Critical path** (lean default): a person must (1) know today's menu, (2) pick, (3) be in before 10:30, (4) pay. Steps 2–3 block value today; step 4 is passable (people pay eventually) and is protected by the health metric.
- **Weakest link:** ordering inside the chat. If people don't order there, reminders and splits have nothing to act on. It goes first.
- **Every KR is served:** KR1.1 by theme 1, KR1.2 and KR1.3 by theme 2.
- **Four themes in total**, inside lean's two-to-five.

## Output — the roadmap artifact

```markdown
---
name: strategic-roadmap
product: lunch-tracker
version: 1.0.0
phase: strategy
created: 2026-10-22
summary: Roadmap for lunch-tracker: ordering inside the chat first (KR1.1), on-time orders without chasing next (KR1.2–1.3); a separate app and menu editing are excluded.
owner: product-strategist
profile: lean
format: now-next-later
traces_to: strategy/vision-statement.md; strategy/strategy-kernel.md; strategy/okrs.md
---

# Strategic Roadmap — lunch-tracker

## Disclaimer
This roadmap is a statement of intent and direction. It reflects our current understanding and will change as we learn. Confidence describes how sure we are about sequence and scope, not importance. Nothing here is a delivery date.

## Vision
Everyone gets the lunch they chose, on time, and nobody owes or chases anybody — North Star: on-time, fully-settled order days per month.

## Objectives this roadmap serves
**Guiding policy:** do everything inside the office chat.
| Objective | Type | Key Results |
|---|---|---|
| O1 — Lunch orders itself through the chat, and nobody has to chase anyone | aspirational | KR1.1 orders via chat command; KR1.2 order days complete by 10:30; KR1.3 hand-sent reminders per week |

## How this was prioritised
**Weakest link:** ordering inside the chat (theme 1); reminders and splits depend on it.
**Framework:** critical path — the steps a person takes from seeing the menu to paying; blocking steps first.

## Now — Q1 2027
| Theme (customer problem) | Serves | Candidate solutions (bets) | Confidence | Reinforces | Dependencies |
|---|---|---|---|---|---|
| "I forget to order because ordering lives outside the chat" | KR1.1 | We believe a /lunch command showing today's menu will move KR1.1 | High | Policy: everything in chat | Chat workspace allows a bot |
| "Nobody tells me I haven't picked until the admin chases me" | KR1.2, KR1.3 | We believe one 10:00 reminder sent only to non-pickers will move KR1.2 | High | Theme 1 (reminds people to use the command) | Theme 1 |

## Next
| Theme (customer problem) | Serves | Confidence | Dependencies |
|---|---|---|---|
| "After the order I don't know exactly what I owe, so I pay late or not at all" | Guiding policy: everything in chat (coherent action 3); protects the unpaid-shares health metric | Medium | Theme 1 |

## Later
| Theme (customer problem) | Serves | Confidence |
|---|---|---|
| "When the admin is out, nobody sends the combined order" | O1 (the "on time" half of the North Star) | Low |

## Not On This Roadmap
| Declined direction | Excluded by |
|---|---|
| A separate web or mobile app | Guiding policy rules it out: a new place to go is the crux itself |
| A menu editor | Guiding policy rules it out: menus change rarely; the admin pastes them |
| A payments integration | Diagnosis: the crux is acting before 10:30, not paying; the posted split is enough while the health metric stays green |

## Decisions you may question
- **No mobile app**, though it was in the first draft: the kernel rules it out because the crux is "nothing new to open".
- **The split is Next, not Now:** paying is passable today and the health metric is green; ordering is not.

## Revision history
Revise at: each OKR cycle · discovery results · a kernel revision · the story map (its first release slice tests Now) · a KR no theme can move.
| Date | Trigger | What moved | What was dropped | The learning |
|---|---|---|---|---|
| 2026-10-22 | First version | — | Mobile app, menu editor, payments (from the draft) | Ruled out by the guiding policy or not on the critical path |
```

**One page.** No stage column (optional at lean), no scores, no target customer (there is one), no audience views.

## Six weeks later — one revision

The check-in log shows KR1.2 confidence falling to 25%: Friday orders are late because people work from home and miss the channel. That is a **discovery result**, a named trigger:

| Date | Trigger | What moved | What was dropped | The learning |
|---|---|---|---|---|
| 2027-02-08 | Discovery result (KR1.2 check-in) | Theme 2 candidate solutions add "Friday reminder by direct message"; theme 2 stays Now | — | Remote days break the channel reminder; the KR stays, the bet changes |

The theme did not change; its candidate solution did. That is what grouping work under a problem buys.
