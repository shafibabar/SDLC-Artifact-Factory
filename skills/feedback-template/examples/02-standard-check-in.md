# Example 2 — Standard: a design-partner check-in turned into items, with the compliment discarded, an idea converted to a need, positioning sent to win/loss, and the commitment recorded

Self-contained. **Tallyroom** runs stock-takes and reorders for independent bookshops, at the **standard** profile. Each shop is a tenant. The product owner held a bi-weekly check-in with the manager of Wren & Page, one of three design partners, using a guide drafted from the check-in template.

## Input — the product owner's notes

> "Really love it, honestly the best thing we've bought this year." · Last Thursday's stock-take: scanned 2,300 books in 3 hours, used to take a day with two staff. · Got stuck on the reorder screen: couldn't find how to change the supplier for one title, rang the publisher instead. · "You should add a bestseller chart to the reorder list." Asked why: on Monday mornings she checks the trade bestseller list by hand to decide what to reorder. · Their sister shop in Hexham "went with the till system's built-in stock module because it came free with the till". · Agreed: I can sit in on next month's stock-take, and she'll introduce me to the Hexham manager.

> **User:** "Great call! Log 'best thing we've bought' as our headline positive, add the bestseller chart to the backlog, and the Hexham thing is just them, ignore it."

## Working it

- **The compliment is not the positive signal.** The **behaviour** is: 2,300 books in 3 hours against a day with two staff. That is logged as the positive signal; the quote is not.
- **The idea becomes a need.** "Bestseller chart" is a solution. The need: on Monday mornings she wants to know which titles are about to sell before deciding what to reorder. Routed to the requirements-analyst as a missing capability and placed on the tree as an opportunity; the chart is one possible solution of several.
- **UX friction goes to the ux-architect.** She couldn't find how to change a supplier and phoned instead: Medium, on a Should flow.
- **Hexham is positioning.** A shop in the target segment chose an alternative (the till's free stock module). That goes in `competitive-analysis`'s win/loss log and is flagged to `gtm-strategy` as a possible Positioning Refresh Trigger: a bundled, free alternative won on price. Ignoring it throws away market evidence.
- **The commitment is recorded.** A seat at next month's stock-take and an introduction: real advancement.

## Output — the reply, and `customer-validation/feedback/2026-06-12.md`

> Good call, and the strongest evidence is what she did, not what she said: a stock-take in 3 hours instead of a day. I've logged that as the positive signal rather than the quote. The bestseller chart is logged as the need behind it (knowing what's about to sell before Monday's reorder), for the requirements-analyst to compare with other ways of meeting it. The supplier-change friction goes to the ux-architect. I wouldn't ignore Hexham: a shop like hers chose the till's free stock module, so that goes in the win/loss log and is flagged to the GTM strategy as a possible trigger to revisit positioning. Her commitments (next stock-take, the Hexham intro) are recorded too.

````markdown
---
name: feedback-log-tallyroom-2026-06-12
product: tallyroom
release-slice: r1
version: 1.0.0
phase: customer-validation
owner: requirements-analyst
created: 2026-06-12
summary: Tallyroom check-in with Wren & Page: stock-take in 3 h (positive signal); supplier change friction; reorder-timing need; Hexham loss to the till's stock module sent to win/loss.
profile: standard
traces_to: customer-validation/beta-program/tallyroom-r1.md; check-in notes 2026-06-12
---

# Feedback Log — tallyroom 2026-06-12

## Sources
Bi-weekly check-in, Wren & Page (manager), 2026-06-12.

## Items

### FB-14: Couldn't find how to change a title's supplier
**Source:** beta check-in
**Reporter:** Hana Okafor, manager, Wren & Page
**Date:** 2026-06-12
**Context — what happened:** On 10 June, reordering a title now distributed by a different wholesaler, she looked for a supplier field on the reorder screen, didn't find one, and phoned the publisher to order instead.
**Expected vs. Actual:**
- Expected: change the supplier from the reorder line
- Actual: supplier is only editable in the title record, two screens away
**Category:** UX friction
**Severity:** Medium
**Underlying need:** n/a
**Supporting detail:** US-7 (Should); reorder screen
**Routed to:** ux-architect
**Rollup:** symptom "supplier not editable at reorder"; single reporter

### FB-15: Knowing what is about to sell before Monday's reorder
**Source:** beta check-in
**Reporter:** Hana Okafor, manager, Wren & Page
**Date:** 2026-06-12
**Context — what happened:** Every Monday morning she checks the trade bestseller list by hand against stock before placing the week's reorder.
**Expected vs. Actual:**
- Expected: see likely sellers while reordering
- Actual: a separate manual check of the trade list
**Category:** missing capability
**Severity:** Low
**Underlying need:** "On Monday mornings I want to know which titles are about to sell before I decide what to reorder." (weekly reorder)
**Supporting detail:** proposed feature: a bestseller chart on the reorder list
**Routed to:** requirements-analyst
**Rollup:** need "anticipate demand at reorder"; one story

### FB-16: Sister shop chose the till's built-in stock module
**Source:** beta check-in
**Reporter:** Hana Okafor, manager, Wren & Page (about Wren & Page Hexham)
**Date:** 2026-06-12
**Context — what happened:** The Hexham shop adopted the stock module bundled free with its till system rather than trialling Tallyroom.
**Expected vs. Actual:**
- Expected: (n/a)
- Actual: lost to a bundled alternative on price
**Category:** positioning
**Severity:** N/A
**Underlying need:** n/a
**Supporting detail:** alternative: till system's bundled stock module; stated reason: free with the till
**Routed to:** competitive-analysis win/loss log; flagged to gtm-strategy as a possible Positioning Refresh Trigger
**Rollup:** positioning; one encounter

### FB-17: Stock-take in three hours instead of a day
**Source:** beta check-in
**Reporter:** Hana Okafor, manager, Wren & Page
**Date:** 2026-06-12
**Context — what happened:** On 5 June she scanned 2,300 books alone in 3 hours; the last manual stock-take took two staff a full day.
**Expected vs. Actual:**
- Expected: a faster stock-take
- Actual: as expected
**Category:** positive signal
**Severity:** N/A
**Underlying need:** n/a
**Supporting detail:** US-1, US-2 (Must)
**Routed to:** logged as evidence
**Rollup:** evidence for US-1/US-2

## Rollup by Symptom and Cause
| Group | Items | Independent reporters | Cause | Severity | Owner | Status |
|---|---|---|---|---|---|---|
| Supplier not editable at reorder | FB-14 | 1 | field only in title record | Medium | ux-architect | open |

## Rollup by Customer Need
| Customer need | Stories mentioning it (independent) | Items | Parent opportunity |
|---|---|---|---|
| Anticipate demand at reorder | 1 | FB-15 | Reorder the right titles with less effort |

## Patterns for the Sign-Off
None yet; FB-14 is watched for a second independent report.

## Positive Signals
- FB-17: a solo stock-take of 2,300 books in 3 hours (previously two staff, one day).
- Commitment: the product owner sits in on July's stock-take; introduction to the Hexham manager agreed.

## Sent Elsewhere
- FB-16 to the competitive-analysis win/loss log (bundled till module, lost on price), flagged to gtm-strategy as a possible Positioning Refresh Trigger.
````

## What the weak first draft looked like

"Positive: 'best thing we've bought this year'. Backlog: bestseller chart." It logged the compliment as evidence while the real evidence, three hours against a day, sat unrecorded. The solution went on the backlog with no need behind it, and the Hexham loss, the one piece of market evidence in the call, was thrown away.
