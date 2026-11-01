---
name: gtm-strategy
description: >
  Teaches how to write the go-to-market (GTM) strategy that carries the strategy
  kernel's guiding policy into the market: choosing the beachhead segment against
  explicit criteria, the Ideal Customer Profile (ICP) and the customer's buying
  group, positioning built from the competitive analysis's alternatives (doing
  nothing and "no decision" included), the market category choice, a reframe
  above the message house, channel strategy, the sales motion, pricing split into
  monetisation model, charging unit and packaging with willingness-to-pay
  evidence, and launch stages with evidence-backed exit criteria and GTM metrics.
  Use when writing or reviewing a GTM strategy, positioning statement, beachhead
  or ICP, messaging framework, channel plan, sales motion, pricing model or launch
  plan, or when deciding whether a product that finished its launch stages has
  crossed the chasm. Used by the product-strategist agent in the Strategy phase
  (/sdlc-strategy), after the business model canvas and before the OKR set;
  required at standard and enterprise, skipped at lean.
version: 3.2.0
phase: strategy
owner: product-strategist
created: 2026-06-24
tags: [strategy, gtm, positioning, beachhead, messaging, pricing, channels, launch]
produces: go-to-market-strategy
domain: strategy
status: stable
related: [strategy-kernel, competitive-analysis, business-model-canvas, pricing-and-packaging, vision-statement, stakeholder-mapping, user-persona, beta-program-design, okr-authoring, roadmap-authoring, glossary-management, methodology-review]
sources:
  - research/product-strategy-and-gtm/crossing-the-chasm-moore.md
  - research/product-strategy-and-gtm/obviously-awesome-dunford.md
  - research/product-strategy-and-gtm/loved-lauchengco.md
  - research/product-strategy-and-gtm/the-mom-test-fitzpatrick.md
  - research/product-strategy-and-gtm/four-steps-to-the-epiphany-blank.md
  - research/product-strategy-and-gtm/challenger-customer-adamson-dixon.md
  - research/product-strategy-and-gtm/monetizing-innovation-ramanujam.md
  - research/storytelling-and-narrative/the-best-story-wins.md
  - research/storytelling-and-narrative/business-storytelling-for-dummies.md
---

# Go-to-Market Strategy

## Purpose

A GTM strategy answers: **which segment do we win first, what do we tell them, how do we reach them, how do they buy, what do we charge, and how do we know each launch stage is done?** It is the strategy kernel's guiding policy carried into the market: where the kernel says *concentrate on X, relying on Y*, the beachhead is X and the positioning leads with Y. It is not a marketing plan; it constrains how product, marketing and sales work together.

Positioning is **derived from evidence, not from a slogan.** It starts from the competitive analysis's alternatives and the differentiation points that survived its filters (Dunford, *Obviously Awesome*), never from the vision or a mission line. A vision says where the product is going; positioning says what it is unlike, today, for whom.

## Where It Sits

```
Vision ─► Stakeholder map ─► Competitive analysis ─► Strategy kernel ─► Canvas ─► GTM STRATEGY ─► OKRs ─► Roadmap
```

| Reads | What it takes |
|---|---|
| `strategy-kernel` | The guiding policy (the focus the beachhead carries out), the advantage it relies on, and what it rules out (segments and channels GTM may not choose) |
| `competitive-analysis` | The **one** competitive alternatives list (doing nothing and no decision included), the surviving differentiation points with their evidence status, the category lens, and the **win/loss log**. Cite them; never build a second list |
| `business-model-canvas` | Segments, value propositions, the charging unit and willingness-to-pay (WTP) evidence. GTM sets the price; the canvas points here |
| `stakeholder-mapping` | The **buying committee** per segment (roles, belief, objection, proof, likely profile, cost of no decision). Its one home: cite it for the beachhead, never copy the table |
| `vision-statement` | The protagonist and the job, so the ICP and the message are about the same customer |

| Feeds | What it gives |
|---|---|
| `okr-authoring` | GTM metrics that become Key Results (time to first value, ICP hit rate) |
| `roadmap-authoring` | The beachhead and the next segment (bowling alley) as the roadmap's target customer; whole-product gaps as themes |
| `beta-program-design` | Stage 1 is the **plan** for the closed beta; the beta program is its **execution** in Customer Validation (Blank, *The Four Steps to the Epiphany*) |
| `user-persona` | The ICP and buying-group roles that requirements-analyst turns into personas in Ideate |

## Scale

`phase-requirements.json` **skips** this artifact at **lean** and **requires** it at standard and enterprise.

| Profile | Shape |
|---|---|
| **lean** (skipped) | No GTM artifact. Monetisation lives in the Lean Canvas's Revenue block: "not monetised" with the reason, or the model, charging unit and one price point with its WTP basis. If the user asks for a GTM anyway, it collapses to **rollout and adoption**: who first, one channel, one message line, a two-stage trial with exit criteria, one adoption metric. No ICP firmographics, positioning statement, sales model, tiers or buying group: `./examples/01-lean-lunch-tracker.md` |
| **standard** | The full artifact for **one** beachhead: scorecard, ICP with disqualifiers, buying group (from the first paid commitment, even self-serve), positioning statement, reframe + message house, one primary channel, sales motion, pricing (model, charging unit, packaging, WTP evidence, value anchor, price strategy, a price **range** per tier), three launch stages with exit criteria, metrics |
| **enterprise** | Everything in standard, plus: a buying group **per segment** with Mobilizer and Blocker hypotheses and a consensus kit; a whole-product map with gaps (certifications, integrations, references); the bowling-alley next segment; leaders / fillers / killers per segment, good-better-best tiers with fences, and a discount policy. The full tier matrix, list prices, bottom-up pricing business case, approval ladder and price-change rules go in the separate pricing-and-packaging artifact (`pricing-and-packaging`), which works inside this artifact's ranges |

## The Components, in Order

1. **Beachhead segment**: one narrow segment, scored against six criteria (Moore, *Crossing the Chasm*), that carries out the kernel's focus. Record the WTP evidence per candidate: it is a segmentation input too.
2. **ICP and buying group**: the organisation (or individual, B2C) most likely to buy and succeed, with at least two disqualifiers; then who in it takes part in the purchase.
3. **Positioning**: competitive alternatives (cited) → unique attributes → value themes → best-fit customer → **market category** (fit, create, or subcategory) → trends; compressed into the positioning statement.
4. **Messaging**: a **Reframe** line, then the message house: headline, value proposition, proof points.
5. **Channel strategy**: one primary channel that reaches the whole beachhead, at most two supporting.
6. **Sales and distribution model**: motion, contract, procurement path, trial model, expansion motion, buying group.
7. **Pricing**: model, charging unit, packaging; value anchor, WTP evidence, price strategy, price range per tier.
8. **Launch sequencing and GTM metrics**: closed beta → soft launch → GA, each with exit criteria; metrics with targets or where the target will be set.

Pricing is written seventh but **decided from evidence gathered at step 1**: the WTP conversation happens with the beachhead, before configuration (Ramanujam and Tacke, *Monetizing Innovation*: design the product around the price).

## The Rules

**1. One beachhead, chosen against criteria, carrying the kernel's policy.** Score candidate segments on: compelling reason to buy now, one coherent channel, an accessible economic buyer, no entrenched competitor, winnable with the resources you have, and a reference base for the next segment. The winner is often the smaller segment. A segment the kernel rules out is not a candidate. Detail: `./references/positioning-and-segments.md`.

**2. The ICP is an organisation; the buying group is the people.** Persona attributes in the ICP hide the buyer/user split. For any B2B purchase, name the buying group: who takes part, the likely **Mobilizer** (who can move the organisation), the likely **Blocker**, and what each loses by staying put. In B2B the commonest loss is **no decision**, not a rival (Adamson and Dixon, *The Challenger Customer*). Profiles are attitudes, not job titles: label them "likely" until Stage 1 confirms them. The committee table lives in the stakeholder map (`stakeholder-mapping`); the GTM cites it for the beachhead and adds only the motion decisions: the Mobilizer target, the Blocker plan, where consensus is built and how Stage 1 confirms it. If the map has no committee for the chosen beachhead, add one there first; only when no stakeholder map exists (lean) does the GTM record the hypotheses itself. Detail: `./references/channels-and-sales-motion.md`.

**3. Positioning starts from the competitive analysis.** Cite its alternatives list (doing nothing first) and use only differentiation points that passed "real" and "valued". A point marked *hypothesis* there is a hypothesis here. The `Unlike [alternative]` slot names the alternative the beachhead actually uses, often a spreadsheet or doing nothing, not the best-known vendor. The `[category]` slot is a deliberate choice among fit, create or subcategory, with the evaluation criteria each imports. Detail: `./references/positioning-and-segments.md`.

**4. Reframe first, then the message house; the customer is the hero.** Above the headline, write one **Reframe**: an insight that changes how the ICP sees its own problem and leads to a strength only this product has (Dixon and Adamson's commercial teaching). If any alternative could deliver it, it is education, not a reframe. In the value proposition the customer is the protagonist and the product the enabler (Luhn, *The Best Story Wins*). Proof points are verifiable today; a **customer story** proof point (named customer, real before/after, confirmed outcome) is allowed only once a real design partner exists (Dietz and Silverman, *Business Storytelling For Dummies*). Detail: `./references/messaging-and-launch.md`.

**5. One primary channel.** It must reach the whole beachhead and carry 70%+ of early acquisition; at most two supporting channels; everything else deferred with a revisit point.

**6. Pricing is three decisions, from evidence.** (a) **Monetisation model** (subscription, usage, freemium…), (b) **charging unit**, the "per what" (tracks the customer's value, predictable bill, grows as the customer succeeds), (c) **packaging** (one offer or good-better-best, each tier carrying its segment's **leaders** and none of its **killers**, features that make the segment less likely to buy; the full leaders / fillers / killers table per segment at enterprise). The **value anchor** (quantified value to the customer) is the ceiling; **WTP evidence** (a range, labelled *stated* or *committed*) is where the price sits; name the **price strategy** (maximisation by default; penetration only with a named network effect, scale economy or lock-in; skimming only with a premium early segment and a planned step-down). State a **price range per tier**; list prices are refined in Stage 2. Never defer prices to an undefined "commercial plan". Detail and the failure-mode check: `./references/pricing.md`. The tier matrix with fences, list prices, the pricing business case and the discount policy belong to `pricing-and-packaging` (enterprise; standard when tiers serve different segments).

**7. Exit criteria rest on evidence, not goodwill.** Every launch stage has measurable exit criteria. Stage 1's "ICP confirmed" and "core value delivered" count only if the design-partner conversations meet the Mom Test (Fitzpatrick): about their life, not the pitch; past specifics, not hypotheticals; commitments, not compliments. Stage 1 also records the WTP range per segment and whether the Mobilizer hypothesis held. Stage 2 exits on price accepted within the stated range without structural discounting. Detail: `./references/messaging-and-launch.md`.

**8. Launch stage and the chasm are different axes.** Finishing beta → soft launch → GA says nothing about whether the product sells to pragmatists. Run the chasm diagnostic (deal cycle time, mutual referenceability, won on vision or on proof) before scaling. Detail: `./references/positioning-and-segments.md`.

**9. Metrics carry targets the team sets, never borrowed benchmarks.** A target is set at planning from the product's own economics or evidence, or the artifact says where it will be set. Do not quote an industry conversion benchmark without a source. Include **trials or deals lost to no decision**.

**10. Positioning is a living hypothesis.** Re-examine positioning and messaging at each stage transition and whenever an outcome in the competitive analysis's win/loss log contradicts a differentiation point (Lauchengco, *Loved*).

## How to Build One

1. **Read the inputs** (Where It Sits). No approved kernel or competitive analysis at standard+: stop and say which is missing.
2. **Score the beachhead** candidates, including what WTP evidence exists for each (rule 1).
3. **Write the ICP**, disqualifiers, and the buying group, citing the stakeholder map's committee (rule 2).
4. **Work the positioning sequence** from the cited alternatives; choose the category; write the statement (rule 3).
5. **Write the Reframe and the message house**; tailor which proof points lead per buying-group role (rule 4).
6. **Choose the channel and the sales motion** (rule 5; options in `./references/channels-and-sales-motion.md`).
7. **Write the pricing** and run the failure-mode check in `./references/pricing.md` (rule 6).
8. **Sequence the launch** with exit criteria and set metric targets (rules 7–9).
9. **Validate** against `./resources/gtm-checklist.md`, then produce the artifact from `./templates/gtm-strategy.md` at `strategy/gtm-strategy.md`.

**Examples, simple to complex:**
- Lean internal tool where the GTM is skipped, and the rollout note written when the user asked for one anyway: `./examples/01-lean-lunch-tracker.md`.
- Standard B2B SaaS, product-assisted self-serve, pricing from three paid pilots, a no-decision loss in the buying group: `./examples/02-standard-ledgerline.md`.
- Enterprise multi-tenant platform, two segments, sales-led into a regulated vertical: buying committee, whole-product gaps, tier fences, a positioning refresh fired by a lost deal, and the next bowling-alley pin: `./examples/03-enterprise-platform.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Kernel carried out | Beachhead is the kernel's focus; nothing the kernel rules out is chosen | A segment or channel the kernel rules out |
| Beachhead | Scored against the six criteria before the ICP | ICP for "the whole market" |
| ICP and buying group | ≥2 disqualifiers; B2B buying group with likely Mobilizer and Blocker | Persona traits in the ICP; one "buyer" assumed |
| Positioning from evidence | Cites the competitive analysis's alternatives (doing nothing / no decision included) and only filtered points | Its own alternatives list; "Unlike other tools…"; derived from the vision |
| Messaging | Reframe above the headline; customer as hero; verifiable proof points | Adjectives as proof; an invented customer story |
| Pricing | Model, charging unit, packaging separate; value anchor; WTP labelled stated / committed; strategy named; range per tier | "Set in the commercial plan"; cost-plus; tiers with no evidence |
| Exit criteria | Measurable; Stage 1 evidence passes the Mom Test | Durations only; "partners loved it" as evidence |
| Metrics | Every target set or its setting point stated; no unsourced benchmark; no-decision losses counted | "Industry benchmark 15–25%" with no source |
| Shape and scale | Frontmatter `name`, `version`, `phase`, `owner`, `created`, `summary`; matches the Scale table | Missing `summary`; lean padded with tiers and an ICP |

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **Everything-channel GTM** | Five channels "to see what works" gives no signal on any of them |
| **Positioning by adjective** | "The best, easiest, next-generation": no named alternative, nothing to test |
| **Second alternatives list** | GTM re-derives competitors; it drifts from the competitive analysis and the win/loss log |
| **Selling to the Friend** | The design partner who answers every email is mistaken for the champion; they cannot move their organisation, and the deal ends in no decision |
| **Pricing last** | Price picked after the product is built and the channel chosen; WTP never asked |
| **Feature shock** | Tiers built from everything the team can add; no one asked which features a segment pays for |
| **Minivation** | A penetration price with no network effect or lock-in leaves most of the value uncaptured |
| **Discount drift** | Ad-hoc discounts with nothing given in return train buyers to wait |
| **Big-bang launch** | Straight to GA scales an unvalidated ICP, message and price at once |
| **Write-once positioning** | A lost deal that contradicts the differentiator changes nothing |

Use canonical terms from `glossary-management`: **Beachhead Segment**, **Ideal Customer Profile**, **Competitive Alternative**, **Message House**, **Reframe**, **Mobilizer**, **No Decision**, **Charging Unit**, **Value Anchor**, **Willingness to Pay**, **Whole Product**, **Win/Loss Log**.
