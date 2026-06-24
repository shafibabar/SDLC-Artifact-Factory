---
name: gtm-strategy
description: >
  Teaches how to build a Go-to-Market strategy — covering Ideal Customer Profile
  definition, positioning statement, channel strategy, sales/distribution model,
  pricing model, launch sequencing, and GTM success metrics. Grounds marketing and
  sales decisions in the competitive analysis and vision. Used by the product-strategist
  agent after competitive analysis is complete.
version: 1.0.0
phase: strategy
owner: product-strategist
tags: [strategy, gtm, positioning, pricing, channels, launch, product-discovery]
---

# Go-to-Market Strategy

## Purpose

A GTM strategy defines how the product reaches its target user and converts them into customers. It answers: who do we reach first, how do we reach them, what do we say, what do we charge, and how do we sequence the launch.

It is not a marketing plan. A GTM strategy is a product-level document that constrains how marketing, sales, and product must work together. It is derived from the vision, mission, competitive analysis, and stakeholder map.

---

## Components

A complete GTM strategy contains seven components:

1. Ideal Customer Profile (ICP)
2. Positioning Statement
3. Messaging Framework
4. Channel Strategy
5. Sales and Distribution Model
6. Pricing Model
7. Launch Sequencing and Success Metrics

---

## 1. Ideal Customer Profile (ICP)

The ICP is not a persona. It is a description of the organisation (for B2B) or individual (for B2C) most likely to buy, succeed with, and advocate for the product.

**ICP for B2B products must include:**

| Attribute | Description |
|---|---|
| Company size | Revenue range or headcount band |
| Industry | Primary verticals where the pain is acute |
| Geography | Regions — relevant if data sovereignty or compliance differs |
| Technical maturity | Sophistication level required to adopt the product |
| Regulatory exposure | Compliance frameworks they must satisfy |
| Buying triggers | Events that make them ready to buy now (e.g. failed audit, rapid growth, new regulation) |
| Disqualifiers | Attributes that make a prospect a bad fit |

---

## 2. Positioning Statement

Derived from competitive analysis. Uses this format:

```
For [ICP],
who [acute pain or buying trigger],
[product name] is the [category]
that [primary value delivered in measurable terms].
Unlike [named alternative],
[product name] [key differentiator that the alternative cannot match].
```

The positioning statement is internal. It informs messaging but is not customer-facing verbatim.

---

## 3. Messaging Framework

Three layers of message, derived from positioning:

| Layer | Purpose | Audience |
|---|---|---|
| **Headline** | The single sentence that captures why to care (5–10 words) | All audiences |
| **Value proposition** | 2–3 sentences expanding the headline into benefit + differentiation | Buyers and evaluators |
| **Proof points** | 3–5 specific, credible claims that support the value proposition | Technical evaluators, security/compliance reviewers |

Proof points must be factual and verifiable. "Complete data estate visibility in under 30 minutes" is a proof point. "The best data governance solution" is not.

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

Select the primary channel (where 70%+ of early acquisition will come from) and 1–2 supporting channels.

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

For an SMB-focused product with a private deployment model, self-serve with a guided POC is typically the right starting motion.

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

**Anchor the price to value, not cost.** If the product saves an SMB 40 hours of compliance audit prep per quarter, pricing should be set relative to that value (what an hour of a compliance officer's time costs × hours saved), not relative to infrastructure cost.

State the pricing model chosen and the rationale. Exact price points are set in the commercial plan, not the GTM strategy.

---

## 7. Launch Sequencing

A three-stage launch sequence reduces risk and generates validated learning:

| Stage | Name | Goal | Audience | Duration |
|---|---|---|---|---|
| Stage 1 | Closed beta / design partners | Validate ICP, core value prop, onboarding | 3–5 pre-selected customers who helped shape requirements | 4–8 weeks |
| Stage 2 | Soft launch / limited availability | Validate GTM motion, pricing, and messaging | ICP outreach, limited inbound, no broad marketing | 6–12 weeks |
| Stage 3 | General Availability (GA) | Scale acquisition | Full channel activation, public announcement | Ongoing |

Define exit criteria for each stage. Stage 1 → 2 requires: ICP confirmed, core value delivered, onboarding completable without support. Stage 2 → 3 requires: repeatable acquisition motion, acceptable CAC, measurable retention.

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

## Output Format

```markdown
---
artifact: gtm-strategy
product: [product name]
version: 1.0.0
phase: strategy
created: [date]
owner: product-strategist
---

# Go-to-Market Strategy

## Ideal Customer Profile
[ICP table]

## Positioning Statement
[Full positioning statement]

## Messaging Framework
[Headline | Value proposition | Proof points]

## Channel Strategy
[Primary channel | Supporting channels | Rationale]

## Sales and Distribution Model
[Sales motion | Contract model | Trial model | Expansion motion]

## Pricing Model
[Model chosen | Value anchor | Rationale]

## Launch Sequencing
[Stage 1 → Stage 2 → GA with exit criteria per stage]

## GTM Success Metrics
[Metrics table with targets]
```

See `references/gtm-template.md` for a fully worked example.
