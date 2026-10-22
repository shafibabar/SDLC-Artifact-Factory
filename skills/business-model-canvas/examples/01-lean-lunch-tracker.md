# Example 1 — A lean internal tool: a Lean Canvas with no revenue (simplest case)

Self-contained. A product built by one person for one office, at the **lean** profile, where the canvas is required as a Lean Canvas and the GTM strategy and JTBD analysis are skipped. It shows that the canvas still earns its place when nothing is sold: the risks it surfaces are product and customer risks, the Revenue block honestly says "not monetised", and the Unfair Advantage is honestly unknown.

## Input

> Problem statement: "A lunch-order tracker for a 20-person office. People pick from a daily menu by 10:30, an admin sends one combined order to the restaurant, and costs are split per person."
>
> Vision (approved): "Every working day, everyone in the office gets the lunch they chose, on time, and nobody owes or chases anybody." North Star: on-time, fully-settled order days per month.
>
> Strategy kernel (approved): crux, getting 20 people to act before 10:30 without opening anything new. Guiding policy: do everything inside the office chat, relying on the habit everyone already has. Rules out a separate app and menu management.

## Working it

- **Variant.** Nothing is validated, and there is only one segment: a Lean Canvas at `strategy/lean-canvas.md`. No Value Proposition Canvas and no alternative drafts at lean.
- **Fill order.** Problem and Segments first. The problems come from the problem statement and the kernel's challenge list; no JTBD artifact exists at lean, so they are hypotheses.
- **The kernel shapes two blocks.** The Channel *is* the guiding policy (the office chat). The kernel's advantage (an existing habit) is real but anyone could build a chat bot, so it does not survive the copy-or-buy filter, and for an internal tool that is fine.
- **Risks.** The canvas's real question is adoption (customer risk) and whether reminders change behaviour (product risk). There is no market risk to speak of.

## Output — the Lean Canvas artifact

```markdown
---
name: business-model-canvas
product: lunch-tracker
version: 1.0.0
phase: strategy
created: 2026-10-22
summary: Lean Canvas for lunch-tracker: office regulars miss the 10:30 cutoff and chase debts; ordering and splitting in the chat; adoption is the riskiest open guess.
owner: product-strategist
canvas-type: lean-canvas
segment: office regulars who order lunch together
traces_to: strategy/vision-statement.md; strategy/strategy-kernel.md
---

# Lean Canvas — lunch-tracker — office regulars

## 1. Problem
1. People forget to order by 10:30, so the admin chases them — Existing alternative: the admin messages everyone one by one.
2. Small debts pile up because splitting by hand is tedious — Existing alternative: a running note on the admin's phone; some debts are written off.

Source of ranking: hypothesis from the problem statement and the kernel; no interviews yet.
Evidence: hypothesis

## 2. Customer Segments
- Segment: the ~20 people in the office who order lunch together; the admin who sends the order.
- Early Adopters: the admin and the 5–6 people who order every day.

Evidence: tested (the admin confirmed the regulars by name)

## 3. Unique Value Proposition
- UVP: Order lunch with one chat command before 10:30; the split posts itself.
- High-Level Concept: a lunch poll that settles the bill.

Evidence: hypothesis

## 4. Solution
| Problem | Smallest capability that addresses it |
|---|---|
| 1 | Chat command to pick from today's menu, and one reminder at 10:00 to anyone who hasn't |
| 2 | The exact split posted in the same thread after the order |

Evidence: hypothesis

## 5. Channels
- The office chat workspace, where the tool lives (own channel; the kernel's guiding policy). The admin announces it at the Monday stand-up.

Evidence: hypothesis

## 6. Revenue Streams
- Revenue type: not monetised — an internal tool for one office.
- Value anchor: the admin's ~30 minutes each morning, and debts no longer written off.
- Willingness to pay: not applicable.

Evidence: hypothesis

## 7. Cost Structure
- Fixed: the builder's evenings; free tier of the chat platform's bot hosting.
- Variable: none at 20 users.
- Fermi check: zero running cost against ~10 admin hours a month saved — plausible.

Evidence: tested (the hosting tier's limits were checked)

## 8. Key Metrics
| AARRR step | Metric | Bottleneck? |
|---|---|---|
| Activation | Share of regulars who order through the command in week 1 | **Yes** |
| Retention | Share of order days with every regular's order in before 10:30 | |

Evidence: hypothesis

## 9. Unfair Advantage
- unknown: tested by whether the office keeps using it after the first month. The chat habit is leverage, but any bot could copy it; an internal tool needs no moat.

Evidence: hypothesis

---

## Riskiest Assumptions → Tests
| Rank | Block | Risk type | We believe | Test | Pass if | Time box |
|---|---|---|---|---|---|---|
| 1 | Segments / Channels | customer | Regulars will order through a chat command | Run the command for two weeks beside the admin's usual messages | ≥ 5 of 6 regulars order through it on ≥ 8 of 10 days | 2 weeks |
| 2 | Solution | product | One 10:00 reminder is enough to remove the chasing | Count orders the admin still chases in week 2 | ≤ 1 chased order per day | Week 2 |

## Problem/Solution Fit Exit Criteria
- [x] Early Adopter profile named from real conversations (the admin named them)
- [ ] Problem 1 ranked must-have by the regulars
- [ ] Existing alternative confirmed (the admin's one-by-one messages)
- [ ] The command and split used for two weeks

## Coherence Check
| Check | Result |
|---|---|
| C1 UVP ↔ top problem | pass |
| C2 Channel reaches early adopters | pass — they are all in the chat |
| C3 Revenue | pass — not monetised, reason stated |
| C4 Cost and Fermi | pass |
| C5 Unfair Advantage | pass — honestly unknown, with its test |
| C6 Evidence status, no bare TBD | pass |
| C7 Top two risks with tests | pass |
| C8 Nothing the kernel rules out | pass — no app, no menu management |
| L1–L6 | pass |

Pattern: none

## Hand-off
- To `okr-authoring`: risk 1's measure is a candidate Key Result (orders through the command before the cutoff).
```

## What a weak first draft looked like

> **Revenue Streams:** TBD. **Unfair Advantage:** first mover, and a passionate builder. **Key Metrics:** total orders placed.

Three failures. A bare TBD hides the decision that the tool is not monetised. "First mover" and "passionate" fail the copy-or-buy filter, and filling the block to avoid a blank hides the honest finding. "Total orders placed" is a running total that only goes up; the activation rate in week 1 is what tells the builder whether the tool is working.
