# Willingness-to-Pay Evidence and Segments — Reference

Self-contained. Read this when recording willingness-to-pay (WTP) evidence, deciding whether a WTP figure is strong enough to set a list price on, preparing the conversation guide the user will run, or checking whether two segments really need two tiers. Sources: Madhavan Ramanujam and Georg Tacke, *Monetizing Innovation*; Rob Fitzpatrick, *The Mom Test*; Ash Maurya, *Running Lean*. The stated-versus-committed reconciliation below is this plugin's synthesis of those books, not a quotation of any of them.

---

## 1. Why WTP comes first

Ramanujam and Tacke's central claim is that most new products fail to make money because pricing is the last step: build, then ask what to charge. They invert the order: the WTP conversation happens before the offer is configured, and it decides what goes in each box, for whom, and at what price. In this plugin the Strategy phase runs before Ideate, so the price book can still shape what is built.

## 2. The question set

Never ask a single "how much would you pay?". For a **described offer** (what it does, for whom, what it replaces), ask:

| Question | What it gives |
|---|---|
| At what price would this be **acceptable**? | The comfortable end of the range |
| At what price would it be **expensive**, but you'd still consider it? | Where resistance starts |
| At what price would it be **too expensive** to consider at all? | The ceiling of stated WTP |
| Rank these benefits, or split 100 points across them | Leaders vs fillers; stops "everything matters" |
| Is there anything here that would make you *less* likely to buy? | Candidate killers |
| At [price A] / [price B], how likely are you to buy, and what would have to change? | Purchase likelihood at real candidate prices |

The spread across the three price questions gives a **range**, not a point. Formal trade-off studies (conjoint-style) belong to enterprise-scale budgets, if at all; the frugality constraint usually rules them out.

**The agent cannot hold these conversations.** It drafts the guide (`../templates/wtp-conversation-guide.md`) and the user, or a design-partner session, runs it.

## 3. Stated versus committed

Fitzpatrick's *The Mom Test* names "how much would you pay for X?" as a bad question: people are polite about a future they cannot see. Ramanujam and Tacke accept that stated WTP is biased and noisy, and still treat it as directional evidence that beats internal guessing when triangulated across questions. Maurya, *Running Lean*, argues for asking for money early, because a stated price is a stronger signal than stated interest and price is part of the product.

The plugin's rule reconciles the three:

| Label | Source | Use it for |
|---|---|---|
| **stated** | Answers to the question set above | A **range hypothesis**: where to test, not where to set |
| **committed** | Pre-order, letter of intent, paid pilot, signed price, observed upgrade | Evidence a list price can rest on |
| **observed** | Realised prices, upgrade and downgrade rates, discount depth after launch | Review triggers and price changes |

A list price with only stated evidence behind it is labelled "to confirm" with the step that will confirm it (usually a paid pilot in `beta-program-design`, or the GTM's Stage 2 price-acceptance exit).

**Record per segment:** who was asked (role, not names), how many, the label, the range, and the date.

## 4. Segments by needs and WTP

One price for everyone overcharges some customers, undercharges others and loses the rest. Ramanujam and Tacke form segments from **needs and WTP** (who values what, and how much) and attach a firmographic description (size, industry, region) afterwards so the segment can be found.

Tests for a real pricing segment:
- its **leaders** differ from the next segment's, or its WTP range does not overlap;
- it can be **fenced** from the cheaper offer by something it values or uses (see `./packaging-and-fences.md`);
- it is big enough to be worth a tier (the business case says so).

Two "segments" that fail the first test are one segment: one tier.

The GTM's beachhead (Moore) picks **which** segment to win first; WTP segmentation decides **what to sell each segment and at what price**, and shows which later segments are worth monetising differently. A high-WTP segment with no offer is a **hidden gem**; note it even if the strategy kernel defers it.

## 5. B2B: whose WTP?

In a B2B purchase the WTP that matters is the **economic buyer's**, inside a buying group whose members weigh price differently (Adamson and Dixon, *The Challenger Customer*). Record which role gave each figure. A user's enthusiasm at $X is not the budget holder's commitment at $X.
