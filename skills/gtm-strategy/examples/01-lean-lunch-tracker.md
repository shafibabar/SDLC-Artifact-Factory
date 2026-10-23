# Example 1 — A lean internal tool: GTM skipped, rollout note on request (simplest case)

Self-contained. A product built by one person for one 20-person office, at the **lean** profile, where `phase-requirements.json` **skips** the GTM strategy. It shows what happens instead: monetisation is one line in the Lean Canvas, and when the user later asked "how do we get people to actually use it?", the GTM collapsed to a half-page rollout and adoption note. It also lists which GTM components were left out, and why.

## Input

> Problem statement: "A lunch-order tracker for a 20-person office. People pick from a daily menu by 10:30, an admin sends one combined order to the restaurant, and costs are split per person."
>
> Strategy kernel (approved): crux, getting 20 people to act before 10:30 without opening anything new. Guiding policy: do everything inside the office chat, relying on the habit everyone already has. Rules out a separate app and menu management.
>
> Lean Canvas (approved), Revenue block: "not monetised — an internal tool for one office". Riskiest assumption: regulars will order through a chat command.
>
> Competitive analysis (optional at lean, written): alternatives are everyone ordering alone (doing nothing) and the admin's chat-and-notes habit.
>
> The user, later: "Can you write the go-to-market for this? I want people to actually use it."

## Working it

- **Default at lean: no GTM artifact.** The phase plan skips it, and nothing is sold. The monetisation decision already sits in the Lean Canvas ("not monetised", with the reason).
- **The user asked directly**, so a note is written, in the lean shape: rollout and adoption. It reuses the kernel (the chat *is* the channel) and the canvas's riskiest-assumption test (it *is* Stage 1).
- **Left out, and why:**

| GTM component | At lean, for this product | Why |
|---|---|---|
| Beachhead scorecard | One line: the 6 daily regulars first | One office; no segments to choose between |
| ICP and buying group | Left out | No organisation buys; the admin is the only "approver" |
| Positioning statement and category | Left out | No market; the only alternative is the current habit |
| Message house | One message line | Twenty colleagues need one sentence, not a house |
| Sales model | Left out | Nothing is sold |
| Pricing | "Not monetised" (in the canvas) | Internal tool; no WTP to gather |
| Launch | Two stages, not three | No public launch exists |
| Metrics | One adoption metric | The canvas's bottleneck metric |

## Output — the rollout note

```markdown
---
name: gtm-strategy
product: lunch-tracker
version: 1.0.0
phase: strategy
created: 2026-10-23
summary: Lunch-tracker rollout: start with the six daily regulars in the office chat, then the whole office once they order without chasing for two weeks.
owner: product-strategist
profile: lean
traces_to: strategy/strategy-kernel.md; strategy/lean-canvas.md
---

# Rollout and Adoption (lean GTM)

**Who first:** the admin and the six people who order every day (Lean Canvas early adopters).
**Channel:** the office chat, the kernel's guiding policy. Announced by the admin at the Monday stand-up. No other channel.
**Message:** "Order lunch with one command before 10:30 — the split posts itself."
**Monetisation:** not monetised (internal tool); see the Lean Canvas.

| Stage | Who | Exit criteria |
|---|---|---|
| 1 — Regulars | Admin + 6 regulars, 2 weeks | ≥ 5 of 6 regulars order through the command on ≥ 8 of 10 days; the admin chases ≤ 1 order a day |
| 2 — Whole office | All ~20 | Every regular's order is in before 10:30 on 9 of 10 days for a month |

**Adoption metric:** share of order days with every regular's order in before 10:30 (from the canvas's Key Metrics).
**If Stage 1 fails:** the kernel's review trigger fires (people still miss the cutoff after reminders); revisit the policy, not the message.
```

## What this example teaches

- At lean the GTM's job shrinks to **getting the first users to change a habit**. The exit criteria still need numbers; nothing else from the standard shape earns its place.
- The rollout note copies its channel from the kernel and its first stage from the canvas's riskiest-assumption test, so the three artifacts cannot drift.
- Positioning, pricing tiers and an ICP would have been padding: nothing is sold and nobody is choosing between vendors.
