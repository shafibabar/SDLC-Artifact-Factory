---
name: pricing-and-packaging
description: >
  Teaches how to write the pricing and packaging plan that turns the GTM's pricing
  decision into a sellable price book: a willingness-to-pay (WTP) evidence register
  per segment (stated vs committed), segments formed by needs and WTP, the leaders /
  fillers / killers matrix, good-better-best or other tier architecture with price
  fences, bundles and add-ons, list prices inside the GTM's range, the bottom-up
  pricing business case with sensitivity on price and adoption, behavioural
  presentation (anchor tier, middle option) used honestly, the discount give-get
  policy and approval ladder, price objections by buying-group role, and launch,
  grandfathering and price-change rules. Use when designing or reviewing pricing
  tiers, a tier matrix, price fences, a pricing business case, a discount policy,
  a price increase, or a draft priced cost-plus or with every tier carrying the same
  leader. Used by the product-strategist agent in the Strategy phase
  (/sdlc-strategy), after the GTM strategy and before the OKR set; required at
  enterprise, optional at standard, skipped at lean.
version: 1.0.0
phase: strategy
owner: product-strategist
created: 2026-10-23
tags: [strategy, pricing, packaging, monetisation, willingness-to-pay, tiers, discount-policy, business-case]
produces: pricing-and-packaging-plan
domain: strategy
status: stable
related: [gtm-strategy, business-model-canvas, competitive-analysis, stakeholder-mapping, strategy-kernel, beta-program-design, okr-authoring, roadmap-authoring, glossary-management, methodology-review]
sources:
  - research/product-strategy-and-gtm/monetizing-innovation-ramanujam.md
  - research/product-strategy-and-gtm/business-model-generation-osterwalder.md
  - research/product-strategy-and-gtm/running-lean-maurya.md
  - research/product-strategy-and-gtm/the-mom-test-fitzpatrick.md
  - research/product-strategy-and-gtm/challenger-customer-adamson-dixon.md
---

# Pricing and Packaging

## Purpose

The GTM strategy decides **how** the product charges: the monetisation model, the charging unit, whether there is one offer or tiers, the price strategy and a price **range** per tier. This artifact answers what comes next: **which features go in which tier for which segment, what stops a customer buying down, what each tier lists at, whether the numbers add up, and how the price is defended once salespeople and renewals get hold of it.**

It rests on one idea from Ramanujam and Tacke, *Monetizing Innovation*: **design the product around the price, not the price around the product.** Willingness to pay (WTP) is gathered before the offer is configured, and it decides what goes in each box. A price book written after the build, from cost or from a competitor's page, is the book's commonest failure.

## Where It Sits

```
… Canvas ─► GTM STRATEGY ─► PRICING AND PACKAGING ─► OKRs ─► Roadmap
```

| Reads | What it takes |
|---|---|
| `gtm-strategy` | Model, charging unit, packaging choice, price strategy, the **price range per tier**, the beachhead and next segment, the buying group. This artifact works **inside** them; a list price outside the GTM range reopens the GTM, it is never quietly changed here |
| `business-model-canvas` | Revenue type, WTP evidence, value anchor, cost structure and cost to serve per segment |
| `competitive-analysis` | Competitors' published prices with source and date, and price-related outcomes in the win/loss log |
| `stakeholder-mapping` | The buying-group roles whose price objections the value brief answers |

| Feeds | What it gives |
|---|---|
| `okr-authoring` | Revenue and mix Key Results (share of new customers on the middle tier, realised price vs list) |
| `roadmap-authoring` | Leaders a tier needs that do not exist yet; fillers to stop building |
| `beta-program-design` | The paid pilot or signed price that upgrades stated WTP to committed |

**One home per decision.** GTM owns model, unit, strategy and range; the canvas owns revenue type and evidence status; this artifact owns the tier matrix, fences, list prices, business case, discount policy and price-change rules. Cite the others; never restate them.

## Scale

`phase-requirements.json` **skips** this artifact at **lean**, makes it **optional** at **standard** and **requires** it at **enterprise**.

| Profile | Shape |
|---|---|
| **lean** (skipped) | No artifact. The Lean Canvas Revenue block holds "not monetised" with the reason, or one price point with its WTP basis. Write the artifact only if the product grows a second paying segment: `./examples/01-lean-skipped.md` |
| **standard** (optional) | Write it when the GTM has **two or more tiers aimed at different segments**, when anyone other than the product owner can grant a discount, or when the user asks. Otherwise the GTM's pricing section is enough. Shape: WTP register, leaders / fillers / killers for each segment, tier matrix with fences, list prices, a one-table business case with price and adoption sensitivity, a short give-get list, launch and change rules |
| **enterprise** (required) | Everything in standard, plus: add-ons and bundles with reasons, regional or residency fences where cost to serve differs, a business case per segment and region with a sensitivity grid, the discount **approval ladder**, a value brief per buying-group role, behavioural presentation choices, and price review triggers |

## The Rules

**1. Evidence before configuration.** Every segment in the matrix carries a WTP range labelled **stated** (from conversations: a hypothesis) or **committed** (a pre-order, letter of intent, paid pilot or signed price). Stated WTP is directional evidence that beats internal guessing (Ramanujam and Tacke), but Fitzpatrick's *The Mom Test* warns that "how much would you pay?" invites polite fiction, so it is only upgraded by a commitment (Maurya, *Running Lean*: ask for money early). The agent drafts the conversation guide; the user runs it. Detail: `./references/wtp-and-segments.md`; guide: `./templates/wtp-conversation-guide.md`.

**2. Segment by needs and WTP, then describe by firmographics.** Segments are groups that value different things and pay differently; size or industry is attached afterwards so sales can find them. If two "segments" share leaders and WTP, they are one segment and need one tier.

**3. Sort every feature per segment: leader, filler or killer.** **Leaders** are what the segment pays for; **fillers** have little stand-alone WTP; **killers** make the segment *less* likely to buy (complexity, an unwanted commitment, a cost they won't carry). A feature can be a leader for one segment and a killer for another. Fillers never drive a tier's price or cost; killers never sit in that segment's tier. Skipping this sort produces **feature shock**.

**4. Each tier is built around its segment's leaders, and every boundary is a fence.** In good-better-best, each tier aims at one segment. A **fence** is the rule that stops a high-WTP customer buying the cheaper tier: a usage limit tied to the charging unit, a leader only that segment values, or a contract term (SLA, residency, support). **If every tier carries the same leader and differs only in fillers, there is no fence**: the high-WTP segment buys down and the top tier sells to nobody. Name each fence and the customer it holds. Detail: `./references/packaging-and-fences.md`.

**5. List prices sit between WTP and the value anchor; cost is a floor, never the basis.** The value anchor (the customer's quantified economic gain) is the ceiling; the WTP range says where the price sits; cost to serve is the viability floor. Cost-plus pricing hands the gap between cost and value to the customer for good. Each list price sits inside the GTM's range and its segment's WTP range; if the evidence says it cannot, reopen the GTM.

**6. Apply the GTM's price strategy at tier level.** Maximisation: list prices at the level the evidence supports. Penetration: only with the GTM's named network effect, scale economy or lock-in, and with the **exit condition** that ends the low price written down. Skimming: the premium segment and the dated **step-down** schedule. A low price with none of these is planned **minivation**.

**7. The business case is bottom-up, tested, and a gate.** Segment size × adoption at this price (from WTP evidence) × price, minus cost to serve, minus the fixed cost to build and run, per segment. Then sensitivity on the two weakest inputs, **price and adoption**. "If we get 1% of the market" is the pattern the book warns against. A case that is not credible at its pessimistic row reshapes the offer (reconfigure, reprice, retarget) or stops it. Run `./scripts/calculate-business-case.py` for the arithmetic; structure in `./references/business-case.md`.

**8. Behavioural presentation amplifies a sound structure; it never rescues a bad one, and it never deceives.** Show the top tier first so it anchors; put the intended best-seller in the middle (the compromise effect); partition the price the way the buyer budgets. A decoy tier must be a real, purchasable offer. Fake "was" prices, countdowns that reset, hidden fees and pre-ticked add-ons are deception, not design, and are defects.

**9. Every discount is a give-get, with a named limit on who grants it.** A discount is traded for something the business values: a longer term, prepayment, volume, a case study or reference, a faster signature with a real reason. Each rung of the **approval ladder** names who may grant how much. "To close this quarter" is not a get; it teaches buyers to wait. Realised price against list is tracked (**price integrity**). Detail: `./references/price-integrity-and-change.md`.

**10. A price objection is answered with value, per buying-group role.** In a B2B group each role weighs the price differently: finance against budget, procurement against the last quote, the user team against effort saved. Give each role its value line and proof (the consensus kit the GTM names) before any discount. "Too expensive" from a group that has not agreed on the problem is often **no decision** in disguise (Adamson and Dixon, *The Challenger Customer*); a discount does not fix it.

**11. Launch and change by rule, not by mood.** Write down: how existing customers are treated at a price change (grandfathered, for how long, with how much notice), that introductory prices carry an end date, and the **review triggers** that reopen the price book (win/loss price losses, discount depth, tier mix, cost-to-serve shifts). Lowering a price is easy; raising one is not, so start at the evidence, not below it.

## How to Build One

1. **Read the inputs** (Where It Sits). No approved GTM: stop and say so; this artifact works inside its range.
2. **Register the WTP evidence** per segment, labelled stated / committed; where there is none, draft the conversation guide for the user (rule 1).
3. **Confirm the segments** by needs and WTP (rule 2).
4. **Fill the leaders / fillers / killers matrix** (rule 3).
5. **Design the tiers and name every fence**; decide add-ons and bundles (rule 4).
6. **Set list prices** inside the GTM range, between WTP and the value anchor, with the strategy applied (rules 5–6).
7. **Run the business case** and sensitivity; reshape if the pessimistic row fails (rule 7).
8. **Choose the presentation**, the discount ladder, the value brief per role and the change rules (rules 8–11).
9. **Run the four-failure check** (feature shock, minivation, hidden gem, undead) and validate against `./resources/pricing-checklist.md`, then write the artifact from `./templates/pricing-and-packaging.md` at `strategy/pricing-and-packaging.md`.

**Examples, simple to complex:**
- Lean paid consumer app where the artifact is skipped, and the trigger that would bring it in: `./examples/01-lean-skipped.md`.
- Standard B2B SaaS where a fenceless two-tier draft is rebuilt into three fenced tiers from paid-pilot evidence, with a give-get list: `./examples/02-standard-ledgerline.md`.
- Enterprise multi-tenant, multi-region platform: two segments, a residency fence, an add-on, a per-region business case with a sensitivity grid, an approval ladder and a value brief per buying-group role: `./examples/03-enterprise-platform.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Inside the GTM | Model, unit, strategy cited from the GTM; every list price inside its range | A new charging unit or price outside the range with the GTM untouched |
| WTP evidence | Range per segment, labelled stated / committed, with who and how many | "Customers will pay about $50"; no source |
| Leaders / fillers / killers | A matrix per segment; no killer in its segment's tier; fillers don't set price | Tiers built from "everything we have" |
| Fences | Every tier boundary names its fence and the segment it holds | Same leader in every tier; tiers differ only in fillers |
| Price basis | Between WTP and value anchor; cost only as floor | Cost-plus margin; a competitor's price copied |
| Business case | Bottom-up per segment; sensitivity on price and adoption; gate stated | "1% of the market"; one optimistic line |
| Discounts | Every discount has a get and an approver with a limit | "Sales may discount as needed"; end-of-quarter cuts |
| Honest presentation | Anchor and middle option on real offers | Fake reference prices, hidden fees, resetting countdowns |
| Change rules | Grandfathering, notice, intro-price end date, review triggers | Price changed with no rule for existing customers |
| Shape and scale | Frontmatter `name`, `version`, `phase`, `owner`, `created`, `summary`; matches the Scale table | Missing `summary`; a lean product given a tier matrix |

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **Pricing last** | The product is built before anyone asks who pays for what; the price book becomes a sticker |
| **Fenceless tiers** | The leader is in every tier; high-WTP buyers buy down and the top tier is decoration |
| **Feature shock** | Every feature in the top tier; nobody can say what they are paying for |
| **Cost-plus** | Price tracks your cost, not the customer's value; the gap is given away permanently |
| **Minivation** | A penetration price with no network effect, lock-in or exit condition |
| **Top-down business case** | "1% of a $2B market" tests nothing and hides the adoption assumption |
| **Discount drift** | Discounts with no get, granted by anyone, train buyers to wait for the quarter end |
| **Dark-pattern pricing** | Fake anchors and hidden fees win a sale and lose trust, and can breach consumer law |
| **Silent price change** | Existing customers learn of a rise from their invoice; churn and no reference |

Use canonical terms from `glossary-management`: **Willingness to Pay**, **Value Anchor**, **Charging Unit**, **Leader / Filler / Killer**, **Good-Better-Best**, **Fence**, **Price Strategy**, **Give-Get**, **Price Integrity**, **No Decision**. Run `methodology-review` before hand-off.
