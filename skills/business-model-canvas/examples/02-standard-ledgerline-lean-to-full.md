# Example 2 — A B2B SaaS product: alternative drafts, a Lean Canvas, then the move to a full canvas (standard profile)

Self-contained. A growing SaaS product at the **standard** profile. It shows the three things a standard canvas adds over a lean one: alternative drafts before choosing, a Value Proposition Canvas per stakeholder role, and the evidence-driven move from a Lean Canvas to the full nine blocks. It also shows the Revenue block stating the charging unit and willingness-to-pay evidence while leaving the price list to the GTM strategy.

## Input

> Product: **Ledgerline**, accounts-receivable software for small accounting firms, which use it to chase their own clients' unpaid invoices.
>
> Vision (approved): "Small accounting firms get paid for every hour they bill, on time, without a partner spending evenings chasing clients."
>
> Competitive analysis (approved): alternatives are a spreadsheet plus email reminders (most firms), the AR module in the two big practice-management suites, and doing nothing. Unique, valued attribute: Ledgerline imports a firm's full invoice and payment history from the two most common bookkeeping tools in minutes.
>
> Strategy kernel (approved): crux, switching costs a firm weeks and must cost an afternoon. Guiding policy: make switching a same-day import and concentrate on firms of 5–50 staff that bill hourly; relies on the import. Rules out a consultant implementation programme, firms over 50 staff, and UK expansion this year.
>
> Stakeholder map: the managing partner buys; the office manager uses it daily.

## Step 1 — three alternative drafts (before choosing)

| Draft | Epicentre | Core idea | Top risk | Decision |
|---|---|---|---|---|
| A | Offer | Self-serve subscription per firm; the import is the trial | Will partners pay before seeing recovered cash? (market) | **Chosen** — carries the kernel's import advantage and its 5–50-staff focus |
| B | Finance | Free tool; a share of each late fee recovered | Firms dislike a vendor taking a cut of client money; revenue swings with clients' behaviour | Rejected — the charging unit punishes the firm's best clients |
| C | Customer | Sold through the suites' marketplaces as an add-on | Depends on the suites, which the kernel names as the alternative to beat | Rejected — the kernel rules out weeks-long partner implementations, and the suites control the channel |

## Step 2 — the Lean Canvas (Plan A)

Before any design partner, problem and price were guesses, so the first artifact was a Lean Canvas at `strategy/lean-canvas.md`. Its key blocks, abbreviated:

| Block | Entry | Evidence |
|---|---|---|
| Problem | 1. Partners spend evenings chasing late clients (alternative: spreadsheet and email). 2. Switching AR tools takes weeks (alternative: stay put) | hypothesis |
| Segments | Hourly-billing firms of 5–50 staff. Early Adopters: firms whose year-end is in the next quarter | hypothesis |
| UVP | "Your whole invoice history in this afternoon; your first reminder to a real late client today." High-level concept: a same-day switch for AR | hypothesis |
| Revenue | Subscription. Charging unit: per firm per month, tiered later by active clients chased. WTP: unknown: tested by quoting a price in solution interviews | hypothesis |
| Unfair Advantage | The minutes-long history import (the kernel's advantage). Could a suite copy it? Not within a year without rebuilding their import | tested (competitive analysis) |
| Top risk | Product: firms will start a trial if the import works same-day. Test: five design-partner imports; pass if ≥ 4 finish the same day and send a real reminder within a week; 6 weeks | — |

## Step 3 — what triggered the move

After eight weeks with five design partners: problem interviews ranked "chasing late clients" first in all five; four imports finished the same day; three firms signed a paid pilot at the quoted price. The Problem/Solution Fit exit criteria were checked, so the full canvas was written to `strategy/business-model-canvas.md` and the Lean Canvas marked superseded.

## Output — the full canvas artifact (key sections)

```markdown
---
name: business-model-canvas
product: ledgerline
version: 2.0.0
phase: strategy
created: 2026-10-22
summary: Ledgerline business model: per-firm subscription for 5–50-staff hourly firms, won by a same-day history import; WTP committed by 3 paid pilots; expansion pricing untested.
owner: product-strategist
canvas-type: bmc
traces_to: strategy/vision-statement.md; strategy/strategy-kernel.md; strategy/competitive-analysis.md
supersedes: strategy/lean-canvas.md (Problem/Solution Fit criteria met: 5/5 ranked problem 1 first, 4/5 same-day imports, 3 paid pilots)
---

# Business Model Canvas — Ledgerline

## Alternatives Considered
Drafts A (offer-led subscription, chosen), B (share of recovered late fees, rejected), C (suite marketplace add-on, rejected). Reasons as recorded in the Lean Canvas.

Pattern: none.

## Value Proposition Canvas — [S1] hourly-billing firms, 5–50 staff — managing partner (economic buyer)
Jobs from: hypothesis for `jtbd-analysis` (Ideate has not run); confirmed by design-partner problem interviews.
| Kind | Item | Rank |
|---|---|---|
| Job | Get paid for billed hours without personally chasing clients | 1 |
| Pain | P1 Evenings lost to chasing | extreme |
| Pain | P2 Fear that reminders damage client relationships | high |
| Pain | P3 Switching tools is a weeks-long project | high |
| Gain | G1 Cash collected within terms | essential |

| Products and services | Reliever / creator | Addresses |
|---|---|---|
| Same-day history import | Removes the switching project | P3 |
| Reminder sequences | Chases without the partner | P1, G1 |
| ~~AI-written reminder tone~~ | — | cut: addresses no ranked pain for the buyer |

## Value Proposition Canvas — [S1] — office manager (user)
| Kind | Item | Rank |
|---|---|---|
| Job | Keep the receivables list current and send reminders | 1 |
| Pain | P4 Reminders that go to the wrong client or amount | extreme |
| Gain | G2 Approve reminders before they send | essential |

| Products and services | Reliever / creator | Addresses |
|---|---|---|
| Reminder templates approved before sending | Removes wrong sends; gives control | P4, G2 |

Fit: problem/solution (interviews, pilots); product/market not yet shown.

## 2. Value Propositions
- [S1 buyer] Get paid on time without chasing, starting this afternoon, unlike a spreadsheet and weeks of migration — P1, P3, G1
- [S1 user] Every reminder checked before it goes — P4, G2

Evidence: tested

## 5. Revenue Streams
- [S1] Type: subscription (recurring) · Mechanism: fixed, list price · Charging unit: per firm per month, tier by active clients chased (tracks value: more late clients chased, more cash recovered; predictable; grows with the firm)
- Value anchor: partner hours no longer spent chasing, plus late fees recovered
- Willingness to pay: stated range from 5 solution interviews; **committed**: 3 paid pilots at the quoted price
- Price levels, tiers, strategy: `gtm-strategy` Pricing Model

Evidence: validated (paid pilots)

## 8. Key Partnerships
| Partner | Type | Motivation | Provides | Status |
|---|---|---|---|---|
| The two bookkeeping tools' public APIs | buyer–supplier | acquisition of resources | Invoice and payment history for the import | exists (public API terms) |

No reseller or implementation partner: the kernel rules out a consultant programme.

Evidence: tested

## Riskiest Assumptions → Tests
| Rank | Block | Risk type | We believe | Test | Pass if | Time box |
|---|---|---|---|---|---|---|
| 1 | Channels | customer | A year-end switch campaign reaches firms in their switching window | Campaign to 200 firms with year-ends next quarter | ≥ 10 trials started | 8 weeks |
| 2 | Revenue | market | The active-client tier does not push firms to under-chase | Pilot firms' clients chased per month before and after tiering | No drop > 10% | 1 quarter |
| 3 | Cost Structure | market | Same-day import support stays under 2 hours per firm | Log support time on the next 20 imports | median ≤ 2 h | 2 months |

## Coherence Check (excerpt)
- C3 Revenue ↔ segment ↔ WTP: pass — the buyer receives the value and committed in a pilot.
- C5 Copy-or-buy: pass — the import, as in the kernel.
- C8 Kernel's rules-out: pass — no implementation partners, no 50+ firms.
- B3 Partnerships real: pass — public APIs only.
```

## What this example teaches

- **Alternatives earn their space** when they are different *models* (B's charging unit, C's channel), not different wordings.
- **The two profiles differ.** The buyer cares about cash and switching cost; the user about wrong sends. One blended proposition would have served neither, and the AI-tone feature was cut because no ranked pain asked for it.
- **Revenue stops at the charging unit and the evidence.** The tier prices sit in the GTM strategy; the canvas says what is charged *per* and why anyone would pay.
- **The move to the full canvas is triggered by exit criteria**, written down, not by the calendar.
