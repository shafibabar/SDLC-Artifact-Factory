---
name: gtm-strategy
description: >
  GTM strategy, positioning, and target-segment/beachhead selection — the
  go-to-market document. Covers Ideal Customer Profile definition, beachhead
  segment selection, the positioning statement, messaging (the message house),
  channel strategy, sales/distribution model, value-anchored pricing, launch
  sequencing, and GTM success metrics. Trigger on go-to-market, GTM strategy,
  positioning, positioning statement, target segment, beachhead, ICP, messaging
  framework, channel strategy, pricing model, and launch plan/sequencing.
  Used by the product-strategist agent after competitive analysis is complete.
version: 2.0.0
phase: strategy
owner: product-strategist
created: 2026-06-24
related: [competitive-analysis, vision-statement, business-model-canvas, user-persona, glossary-management, methodology-review]
tags: [strategy, gtm, positioning, pricing, channels, launch, product-discovery]
---

# Go-to-Market Strategy

## Purpose

A GTM strategy defines how the product reaches its target user and converts them into customers. It answers: which segment do we win first, how do we reach them, what do we say, what do we charge, and how do we sequence the launch. It is not a marketing plan — it is a product-level document that constrains how marketing, sales, and product must work together, derived from the vision, mission, competitive analysis, and stakeholder map.

---

## Components

A complete GTM strategy contains seven components, produced in order — each constrains the next:

1. Ideal Customer Profile (ICP) — preceded by an explicit beachhead-segment choice
2. Positioning Statement
3. Messaging Framework
4. Channel Strategy
5. Sales and Distribution Model
6. Pricing Model
7. Launch Sequencing and Success Metrics

Component 1 is preceded by a beachhead choice — positioning, channel, and pricing are all chosen *for that one segment*, not the whole addressable market.

---

## Selecting the Beachhead Segment

Pick one narrow segment and win 100% of it before expanding — total domination of a small, well-chosen segment produces the references, word-of-mouth, and repeatable motion that a diluted multi-segment effort never does. Score candidate segments against these criteria; the winner is often the smaller one, not the largest addressable market:

| Criterion | Passes when |
|---|---|
| Compelling reason to buy now | A trigger event makes it urgent, not a nice-to-have |
| Coherent single channel | One channel reaches the whole segment |
| Accessible economic buyer | The budget owner is identifiable and reachable |
| No entrenched competitor | No incumbent already owns the segment |
| Winnable now | Achievable with the resources actually available |
| Reference base for expansion | Winning it credibly opens an adjacent segment next |

Then choose which market category frames the offering — fit an existing category, create a new one, or carve a subcategory ("the only X built for Y"); that choice sets the buyer's evaluation criteria before they read a word of the pitch. Full Dunford/Moore treatment — the chasm, whole product, category-as-lever, and bowling-alley expansion — is in `references/positioning-and-segments.md`.

---

## 1. Ideal Customer Profile (ICP)

The ICP is not a persona. It is a description of the organisation (for B2B) or individual (for B2C) most likely to buy, succeed with, and advocate for the product. Anchor at least one attribute in an observed best-fit customer, not assumption alone. A B2B ICP must include:

| Attribute | Description |
|---|---|
| Company size | Revenue range or headcount band |
| Industry | Primary verticals where the pain is acute |
| Geography | Regions — relevant if data sovereignty or compliance differs |
| Technical maturity | Sophistication level required to adopt the product |
| Regulatory exposure | Compliance frameworks they must satisfy |
| Buying triggers | Events that make them ready to buy now (failed audit, rapid growth, new regulation) |
| Disqualifiers | Attributes that make a prospect a bad fit |

## 2. Positioning Statement

Derived from competitive analysis, using this format:

```
For [ICP],
who [acute pain or buying trigger],
[product name] is the [category]
that [primary value delivered in measurable terms].
Unlike [named alternative],
[product name] [key differentiator that the alternative cannot match].
```

The positioning statement is internal. It informs messaging but is not customer-facing verbatim. Every claim must be defensible from the competitive analysis capability matrix — if the named alternative can in fact match the differentiator, the positioning collapses on the first competitive sales call.

The single sentence is the *compression* of a positioning exercise, not a substitute for one. Dunford's derivation (competitive alternatives → unique attributes → value themes → best-fit customer → market category → trends) and a fully worked example are in `references/positioning-and-segments.md` and `references/gtm-template.md`.

---

## 3. Messaging Framework

Three layers of message (a "message house"), derived from positioning:

| Layer | Purpose | Audience |
|---|---|---|
| **Headline** | The single sentence that captures why to care (5–10 words) | All audiences |
| **Value proposition** | 2–3 sentences expanding the headline into benefit + differentiation | Buyers and evaluators |
| **Proof points** | 3–5 specific, credible claims that support the value proposition | Technical, security/compliance evaluators |

Proof points must be factual and verifiable. "Complete data estate visibility in under 30 minutes" is a proof point; "the best data governance solution" is not. The same claims must appear on every customer-facing surface (trial copy, README, FAQ), and the message house is refreshed against win/loss evidence — see `references/positioning-and-segments.md`.

---

## 4. Channel Strategy

Define how the ICP is reached. For B2B products, channels typically include:

| Channel | Fit for SMB B2B | Notes |
|---|---|---|
| Direct sales (outbound) | Medium | High CAC; use for large accounts only |
| Product-led growth (PLG) | High | Free trial or freemium; ICP self-discovers and converts |
| Partner/reseller | Medium | Leverages existing relationships; trust transfer |
| Content/SEO | High | Reaches buyers at research stage; long lead time |
| Community (developer, ops, compliance) | High if technical buyer | Builds credibility and word-of-mouth |
| Events/conferences | Low initially | High cost; use after early traction to scale |

Select the primary channel (where 70%+ of early acquisition will come from) and 1–2 supporting channels. The primary channel must be the single coherent channel that reaches the chosen beachhead.

---

## 5. Sales and Distribution Model

Define the mechanics of how a prospect becomes a customer:

| Decision | Options |
|---|---|
| Sales motion | Self-serve (no sales team) / Product-assisted (sales supports trial) / Sales-led (AE-driven) |
| Contract model | Monthly SaaS / Annual SaaS / Perpetual licence / Consumption-based |
| Procurement path | Credit card / PO / Master Service Agreement |
| Trial model | Free trial (time-limited) / Freemium (feature-limited) / Proof of Concept (POC) / Demo-only |
| Expansion motion | Seat-based expansion / Usage-based expansion / Additional modules |

For an SMB-focused product with a private deployment model, self-serve with a guided POC is typically the right starting motion. Distinguish the economic buyer (owns budget and organizational risk) from the user/champion — a pragmatist economic buyer evaluates total cost of ownership and whole-product completeness, not technical elegance.

---

## 6. Pricing Model

Pricing must be aligned to the value delivered, not to cost. For B2B data products, common models:

| Model | How it works | Best when |
|---|---|---|
| Per seat | Price per user/month | Value scales with number of users |
| Per data volume | Price per GB scanned or stored | Value scales with data size |
| Per connector | Price per storage integration enabled | Value scales with coverage |
| Flat monthly/annual | Fixed price per tenant | Simplicity is a selling point; SMB buyers resist metered pricing |
| Tiered (starter/pro/enterprise) | Feature-differentiated tiers | Wide ICP range; need to fence by buyer segment |

**Anchor the price to value, not cost.** If the product saves an SMB 40 hours of compliance audit prep per quarter, pricing should be set relative to that value (a compliance officer's loaded hourly cost × hours saved), not relative to infrastructure cost. State the pricing model chosen and the rationale. Exact price points are set in the commercial plan, not the GTM strategy.

---

## 7. Launch Sequencing

A three-stage launch sequence reduces risk and generates validated learning:

| Stage | Name | Goal | Audience | Duration |
|---|---|---|---|---|
| Stage 1 | Closed beta / design partners | Validate ICP, core value prop, onboarding | 3–5 pre-selected customers who helped shape requirements | 4–8 weeks |
| Stage 2 | Soft launch / limited availability | Validate GTM motion, pricing, and messaging | ICP outreach, limited inbound, no broad marketing | 6–12 weeks |
| Stage 3 | General Availability (GA) | Scale acquisition | Full channel activation, public announcement | Ongoing |

Define exit criteria for each stage. Stage 1 → 2 requires: ICP confirmed, core value delivered, onboarding completable without support. Stage 2 → 3 requires: repeatable acquisition motion, acceptable CAC, measurable retention. Launch stage (audience size over time) and crossing the chasm (visionary → pragmatist buyer psychology) are different axes — a product can finish all three stages while still selling only to visionaries; see `references/positioning-and-segments.md`.

---

## GTM Success Metrics

| Metric | What it measures | Target (set at GTM planning) |
|---|---|---|
| Time to first value (TTFV) | Minutes from deployment to first meaningful insight | [TBD at product planning] |
| Trial-to-paid conversion rate | % of trials that convert to paid | [TBD; benchmark: 15–25% for PLG B2B] |
| Customer Acquisition Cost (CAC) | Total GTM spend / new customers acquired | [TBD based on pricing model] |
| Net Revenue Retention (NRR) | Revenue retained and expanded from existing customers | > 100% indicates expansion |
| ICP hit rate | % of new customers that match the ICP definition | > 80% to validate ICP accuracy |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Component completeness | All seven components present | Any component missing or marked "TBD" without a stated resolution path |
| Beachhead chosen | Segment selected against explicit criteria before the ICP is written | ICP written for "the whole market" with no narrow first segment named |
| ICP disqualifiers | At least two disqualifiers named | ICP defined only by who fits, never by who does not |
| Positioning honesty | Named alternative + a differentiator that alternative genuinely cannot match | "Unlike other tools…" with no named alternative, or a differentiator the alternative can copy |
| Proof points | Every proof point verifiable today or by launch | Aspirational or unmeasurable claims presented as proof points |
| Channel focus | One primary channel (70%+ of early acquisition) plus at most 2 supporting | Four or more channels pursued "in parallel" |
| Pricing anchor | Pricing model anchored to quantified customer value | Pricing derived from cost or from a competitor's list price alone |
| Stage exit criteria | Every launch stage has explicit, measurable exit criteria | Stages with dates or durations but no exit conditions |
| Metric targets | Every GTM metric has a target, or an explicit note of where the target will be set | Metrics listed with no targets and no plan to set them |

---

## Anti-Patterns

**The everything-channel GTM:** launching on five channels simultaneously because "we don't know which will work." Each channel needs enough sustained investment to produce a signal; spreading a solo operator across five produces noise on all of them. Pick one primary, measure, then expand.

**ICP/persona conflation:** describing an individual ("a compliance officer who…") in the ICP. The ICP is the company profile; the people inside it are personas. Conflating them hides the buyer/user split that B2B deals hinge on.

**Cost-plus pricing:** setting price from infrastructure cost plus margin. For a product that saves 40 hours of audit prep per quarter, the value anchor supports a price an order of magnitude above cost — cost-plus pricing donates that margin to the customer permanently.

**Big-bang launch:** skipping Stages 1 and 2 and going straight to GA. Without design-partner validation, GA scales an unvalidated ICP, unvalidated messaging, and unvalidated pricing simultaneously — and public launch attention is not refundable.

**Positioning by adjective:** "the best", "the easiest", "next-generation" — claims with no named alternative and no measurable dimension. If the positioning statement cannot name what it is unlike, it is not a position.

**Write-once positioning:** archiving the positioning statement after Strategy-phase authoring and never revisiting it. Positioning is a living hypothesis — re-examine it at each launch-stage transition and whenever a win/loss outcome contradicts a stated differentiator (`references/positioning-and-segments.md`).

---

## Output Format

Produce the seven components as a single Markdown artifact with a frontmatter block (`name`, `product`, `version`, `phase`, `created`, `owner`) followed by one section per component: Ideal Customer Profile, Positioning Statement, Messaging Framework, Channel Strategy, Sales and Distribution Model, Pricing Model, Launch Sequencing, and GTM Success Metrics — each with exit criteria or targets where the component calls for them. A fully worked example filling every section is in `references/gtm-template.md`.
