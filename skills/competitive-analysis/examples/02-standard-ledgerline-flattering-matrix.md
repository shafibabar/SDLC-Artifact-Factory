# Example 2 — A B2B SaaS product: rebuilding a flattering matrix (standard profile)

Self-contained. A growing SaaS product at the **standard** profile. The team's first draft chose its axes where the product sat alone and scored every alternative ✗; it also stated competitor prices from memory. This example shows the rebuild: alternatives first, criteria from the buyer, honest substitute scores, labelled evidence, and the hand-off the strategy kernel then relied on. (Vendor names are anonymised as Suite A, Suite B and AR tool C; in a real artifact they are named.)

## Input

> Product: **Ledgerline**, accounts-receivable software for accounting firms of 5–50 staff. Firms use it to chase their own clients' unpaid invoices.
>
> Vision (approved): "Small accounting firms get paid for every hour they bill, on time, without a partner spending evenings chasing clients."
>
> Stakeholder map (approved), summarised: the managing partner buys; the office manager uses it daily; firms change tools almost only at financial year-end.
>
> Evidence the user supplied: notes from 9 discovery calls; a demo of Suite A's AR module the user attended on 2026-09-14; Suite B's public pricing page, pasted on 2026-10-02.

## The draft the team brought

> **Positioning map axes:** AI-drafted reminders (x) × modern UI (y). Ledgerline alone in the top-right.
>
> | Dimension | Ledgerline | Suite A | Suite B | AR tool C | Spreadsheet |
> |---|---|---|---|---|---|
> | AI reminder drafting | ✓ | ✗ | ✗ | ~ | ✗ |
> | Modern UI | ✓ | ✗ | ✗ | ~ | ✗ |
> | Price | $49/mo | $180/mo | $150/mo | $99/mo | ✗ |
> | Ease of use | ✓ | ✗ | ✗ | ~ | ✗ |

Run the checklist:
- **Row 1, alternatives first:** doing nothing (writing off late fees) is missing, and the spreadsheet is a column, not where the analysis starts.
- **Row 3, axes from the buyer:** none of the nine discovery calls mentioned AI or the UI. The axes were chosen because the product is alone there.
- **Row 4, every claim labelled:** the four competitor prices came from model memory, stated as fact. Only Suite B's has a source (the pasted page), and it says $129, not $150.
- **Row 6, honest substitutes:** the spreadsheet costs nothing, needs no switching and leaves the firm writing every email itself. It scores ✗ on "price".

## Working the rebuild

**Criteria from the buyer.** From the call notes, in the buyers' words: "moving our history would take weeks" (7 of 9 calls), "I won't let a robot email my clients" (6 of 9), "it has to pay for itself in recovered fees" (5 of 9), "it must read from our bookkeeping tool" (9 of 9: every alternative except the spreadsheet does this, so it is table stakes).

**The axes become** switching effort (x) × control over client contact (y): the two heaviest. On those axes Ledgerline is **not** alone: the spreadsheet shares the "no switching, full control" corner. That is the finding: against the spreadsheet the difference is not effort or control but recovered fees without a partner's evenings, and against the suites it is the import.

## Output — the competitive analysis artifact (abridged: sections 5, 6 and 8 shortened)

```markdown
---
name: competitive-analysis
product: ledgerline
version: 2.0.0
phase: strategy
created: 2026-10-22
summary: Most small firms chase invoices by spreadsheet or write fees off; Ledgerline's same-day history import is the one real, valued, defensible edge over the suites.
owner: product-strategist
profile: standard
traces_to: strategy/vision-statement.md; strategy/stakeholder-map.md
---

# Competitive Analysis

## 1. Competitive Alternatives

| # | Alternative | Type | What the firm does today | Evidence |
|---|---|---|---|---|
| A1 | Write off late fees | Doing nothing | Partner chases only the largest debts; the rest are absorbed | 4 of 9 calls |
| A2 | No decision | Status quo | Partner agrees the problem but defers the switch to year-end, then year-end is too busy | 3 of 9 calls |
| A3 | Spreadsheet + email reminders | Substitute | Office manager tracks overdue invoices and writes each reminder | 6 of 9 calls |
| A4 | Suite A AR module | Indirect (bundled) | Bundled in the practice-management suite some firms already pay for | Demo, 2026-09-14 |
| A5 | Suite B AR module | Indirect (bundled) | Same, other suite | Pricing page, 2026-10-02 |
| A6 | AR tool C | Direct | Dedicated AR automation for small businesses generally | model knowledge |

## 2. Buyer's Evaluation Criteria

| # | Criterion | Whose | Weight | Where it came from | Table stakes? |
|---|---|---|---|---|---|
| C1 | Time to move our invoice history | Partner | high | 7 of 9 calls | no |
| C2 | Control over what clients receive | Office manager, partner | high | 6 of 9 calls | no |
| C3 | Pays for itself in recovered fees | Partner | medium | 5 of 9 calls | no |
| C4 | Reads from our bookkeeping tool | Office manager | high | 9 of 9 calls | yes |

## 3. Evidence Register

| ID | Claim | Source | Date | Status |
|---|---|---|---|---|
| E1 | Suite A's history import is run by a certified consultant over several weeks | User's demo notes | 2026-09-14 | verified |
| E2 | Suite B AR module lists at $129 per firm per month | Pasted pricing page | 2026-10-02 | verified |
| E3 | Suite B imports history only through a paid migration service | model knowledge | unknown | unverified (model knowledge) |
| E4 | AR tool C sends reminders automatically with no approval step | model knowledge | unknown | unverified (model knowledge) |
| E5 | AR tool C has no accounting-firm-specific import | model knowledge | unknown | unverified (model knowledge) |

**Evidence requested from the user:** Suite B's migration terms (E3), a trial of AR tool C or its help pages on approvals and imports (E4, E5), and AR tool C's current price (left `?` until then).

## 4. Capability Matrix

| Criterion (weight) | Ledgerline | A1 Write off | A3 Spreadsheet | A4 Suite A | A5 Suite B | A6 AR tool C |
|---|---|---|---|---|---|---|
| C1 Move history (high) | ✓ same day | ✓ nothing to move | ✓ nothing to move | ✗ weeks [E1] | ✗ [E3] | ? [E5] |
| C2 Control of client contact (high) | ✓ approve before send | ✓ | ✓ writes every email | ~ | ~ | ✗ [E4] |
| C3 Pays for itself (medium) | ~ (unproven) | ✗ fees lost | ~ costs staff time | ~ | ~ $129/mo [E2] | ? |
| C4 Reads bookkeeping tool (table stakes) | ✓ | — | ✗ | ✓ | ✓ | ✓ |

## 5. Positioning Map

**Axes:** C1 switching effort (x) × C2 control over client contact (y).
**Who shares our space:** the spreadsheet (A3) and writing off fees (A1) sit with us in "no switching, full control". Against them the difference is C3, recovered fees without partner time, which is still unproven.

## 7. Differentiation Points

| # | Point | Real (evidence) | Valued (criterion) | Defensible | Evidence status |
|---|---|---|---|---|---|
| D1 | Full invoice history imported the same day from the two common bookkeeping tools | E1 verified; E3 unverified | C1 (high) | The suites sell consultant-led migration; matching a self-serve same-day import undercuts that revenue and their partner channel | verified vs Suite A; hypothesis vs Suite B |
| D2 | Reminders the office manager approves before they send | E4 unverified | C2 (high) | Weak: a funded rival could add an approval step in a quarter | hypothesis; feeds positioning, not the kernel |

**Considered and cut:** AI reminder drafting and the modern UI: valued by no listed criterion.

## 9. Win/Loss Log

| Date | Account / trial | Weighed against | Outcome | Stated reason (source) | Differentiation point |
|---|---|---|---|---|---|
| 2026-08-30 | Design partner 1 (12 staff) | A3 Spreadsheet | won | "We saw our overdue clients the first afternoon" (call notes) | D1 confirmed |
| 2026-09-20 | Design partner 2 (30 staff) | A2 No decision | no decision | Partner: "revisit at year-end" (email) | D1 not touched: timing, the kernel's crux |

## 10. Hand-off to the Strategy Kernel

- **Advantage candidates:** D1 (verified against Suite A; hypothesis against Suite B until E3 is checked).
- **The alternative to beat:** A2 no decision and A3 the spreadsheet: most firms never shortlist a vendor.
- **The advantage is not real if:** firms with a successful same-day import still don't convert, citing something other than switching effort — watched in the win/loss log.
- **Table stakes for requirements:** C4.
```

## What changed, and why

- The analysis now starts with what firms actually do: write fees off, defer, or keep the spreadsheet. The kernel's diagnosis ("firms switch only at year-end") came straight from A2 and design partner 2's row.
- The axes are the buyers' two heaviest criteria, and on them Ledgerline is not alone. That honest finding is why D1, not "control", became the kernel's advantage.
- Three prices disappeared. One is verified with its date; the others are `?` with a request to the user.
- D2 survived "real" and "valued" but not "defensible", so it goes to `gtm-strategy` for messaging and stays out of the kernel and the canvas's Unfair Advantage.
