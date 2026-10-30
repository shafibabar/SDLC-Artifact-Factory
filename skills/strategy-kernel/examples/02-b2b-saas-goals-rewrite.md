# Example 2 — A B2B SaaS product: rewriting a goals-only "strategy" (standard profile)

Self-contained. A growing SaaS product at the **standard** profile, where the stakeholder map and competitive analysis exist and the kernel reads them. The draft the team brought was a list of goals, the commonest failure Rumelt names. This example shows the rewrite.

## Input

> Product: **Ledgerline**, accounts-receivable software for accounting firms. Firms use it to chase their own clients' unpaid invoices.
>
> Vision (approved): "Small accounting firms get paid for every hour they bill, on time, without a partner spending evenings chasing clients."
>
> Competitive analysis (approved), summarised: the alternatives are (a) a spreadsheet and email reminders (most firms), (b) the AR module bundled in the two big practice-management suites, (c) doing nothing and writing off late fees. Unique attributes that survived "real and valued": Ledgerline imports a firm's full invoice and payment history from the two most common bookkeeping tools in minutes; the suites need a consultant and weeks.
>
> Stakeholder map (approved), summarised: the managing partner buys; the office manager uses it daily; firms change tools almost only at financial year-end, when the partner has time.

## The draft the team wrote

> **Strategy 2027:** Grow to 500 paying firms and $1M ARR. Become the #1 AR tool for accounting firms. Achieve 95% gross retention. Launch a mobile app, a partner program, AI reminder drafting, and expand to the UK.

Run the checklist:
- **Goals as strategy.** "500 firms", "$1M", "#1", "95%" are all *how much*. Nothing says *how*.
- **No challenge faced.** What stops firms buying today? The draft never says.
- **Dog's dinner.** Four initiatives, one from each function, none linked to another or to an obstacle.
- **Rules nothing out.** Mobile, partners, AI and the UK all at once.

These targets are not wasted: once there is a kernel, some of them become Key Results in the OKR set, under objectives the guiding policy implies.

## Working the diagnosis

| Challenge | Important? | Addressable? | Verdict |
|---|---|---|---|
| Firms only switch tools at year-end | Yes: caps how fast anyone can adopt | Yes: switching cost is what makes waiting rational | **Crux** |
| The suites have strong brands | Yes | Not by a small team | Set aside |
| Office managers distrust automated reminders to clients | Partly | Yes | Follows from the crux: solved by the same trial on real data |
| UK firms have different invoicing norms | No, not yet | Yes | Set aside: a later expansion question |

## Output — the kernel artifact

```markdown
---
name: strategy-kernel
product: ledgerline
version: 1.0.0
phase: strategy
created: 2026-10-19
summary: Strategy: firms switch AR tools only at year-end because moving history is painful, so we make switching a same-day import and win firms of 5–50 staff.
owner: product-strategist
traces_to: strategy/vision-statement.md; strategy/competitive-analysis.md; strategy/stakeholder-map.md
---

# Strategy Kernel

## Diagnosis
Small firms know they lose money to late payers, and most already tolerate a spreadsheet. They don't switch because moving years of invoice history is a project only a partner can approve, and partners only have time at year-end. So the market moves once a year, and anyone who needs a consultant to migrate misses the window.
**Crux:** switching costs a firm weeks; it must cost an afternoon.

| Challenge set aside | Why not the crux |
|---|---|
| The suites' brand strength | Important but not addressable by us |
| Office-manager trust in automated reminders | Follows from the crux: a same-day import lets them see reminders on their own clients before committing |
| UK invoicing norms | Not important until the home market is won |

## Guiding Policy
Make switching a same-day import and concentrate on firms of 5–50 staff that bill hourly.
**Relies on:** our minutes-long history import from the two common bookkeeping tools, which the suites lack (competitive analysis, unique attributes) — an advantage, used at the pivot point where firms decide.
**Rules out:**
- A partner/consultant implementation program — because it rebuilds the weeks-long switch the crux says must go.
- Firms over 50 staff — because they buy suites for reasons beyond AR, and serving them would pull the import work toward custom migrations.
- UK expansion in 2027 — because a second set of norms splits the import work before the first market is won.

## Coherent Actions
| # | Action | Reinforces |
|---|---|---|
| 1 | Make the history import cover 100% of the two common tools' invoice data, including partial payments | The policy's advantage |
| 2 | A trial that starts from the imported history, so the first reminder goes to a real overdue client on day one | 1 (the import is the trial's raw material) |
| 3 | Year-end campaign: ready-made switch guides timed for the window firms actually change tools | 1, 2 |
| 4 | Reminder templates the office manager approves before they send | 2 (turns the trial into trust) |

## Proximate Objectives
- Firms that start a trial see their own overdue clients on day one.
- Win the coming year-end switching window among 5–50-staff firms.

## Review Trigger
**Wrong if:** firms with a successful import still don't convert, citing something other than switching effort — **watched in:** trial exit survey and lost-deal notes.
```

## What changed, and why

- The goals moved down a level. "500 firms" can become a Key Result under "Win the coming year-end switching window" — a proximate objective, reachable this cycle, that tells the team what to do next.
- The mobile app, partner program and AI drafting are gone. Mobile and AI reinforce nothing in the list; the partner program is ruled out by name because it works *against* the crux.
- The advantage is the import, and it is backed by the competitive analysis. The positioning statement in `gtm-strategy` will be built from that same evidence (the alternatives and the import attribute), not from a slogan in this kernel.
- The 5–50-staff focus is the policy; the GTM strategy's beachhead segment carries it out.
