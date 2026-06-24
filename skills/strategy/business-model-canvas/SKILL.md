---
name: business-model-canvas
description: >
  Teaches how to complete a Business Model Canvas (BMC) for a product — covering
  all nine blocks, the logical dependencies between blocks, common traps per block,
  and how to use the canvas to identify business model risks before committing to
  architecture or roadmap. Includes a Lean Canvas variant for early-stage products.
  Used by the product-strategist agent during the Strategy phase.
version: 1.0.0
phase: strategy
owner: product-strategist
tags: [strategy, business-model-canvas, lean-canvas, revenue, product-discovery]
---

# Business Model Canvas

## Purpose

A Business Model Canvas (Alexander Osterwalder) maps the nine building blocks of a business on a single page. For a product team, it answers the question: **is this a viable business, and do the nine blocks fit together coherently?**

Completing the canvas before committing to architecture or roadmap surfaces business model risks early — before they become expensive to change.

---

## The Nine Blocks

The canvas is divided into two halves: **Value** (centre and right — what customers experience) and **Efficiency** (left — what the business does internally). The **Revenue Streams** and **Cost Structure** run across the bottom.

```
┌─────────────────┬──────────────┬──────────────────┬──────────────────┬─────────────────┐
│ Key Partners    │ Key          │ Value            │ Customer         │ Customer        │
│                 │ Activities   │ Propositions     │ Relationships    │ Segments        │
│                 ├──────────────┤                  │                  │                 │
│                 │ Key          │                  │ Channels         │                 │
│                 │ Resources    │                  │                  │                 │
├─────────────────┴──────────────┴──────────────────┴──────────────────┴─────────────────┤
│ Cost Structure                                     Revenue Streams                      │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Block-by-Block Instructions

### 1. Customer Segments

**Who are you creating value for? Who are your most important customers?**

- List every distinct customer segment (not user personas — segments are groups with distinct needs and willingness to pay)
- For B2B: segment by company profile (size, industry, regulatory exposure)
- Rank by priority: which segment is the primary ICP?
- Distinguish between users (who use the product) and buyers (who pay for it) if they differ

**Common trap:** Listing "all SMBs" as a single segment. Break down by: size band, industry vertical, regulatory exposure, technical maturity.

---

### 2. Value Propositions

**What value do you deliver to each customer segment? What problem do you solve? What need do you satisfy?**

- One value proposition per customer segment (they may differ)
- State it as: what the customer gains + what pain is relieved
- Must be differentiated — if a competitor offers the same value, it is not a proposition

**Connection:** Value Propositions are the bridge between Customer Segments and all other blocks. If a value proposition is weak, every other block is building on a flawed foundation.

**Common trap:** Listing product features as value propositions. "Real-time compliance scanning" is a feature. "Know within 30 minutes whether your estate has a SOC 2 CC6 violation — without sending a single file outside your infrastructure" is a value proposition.

---

### 3. Channels

**How do you reach and communicate with your customer segments? How do you deliver your value propositions?**

Channels cover two activities: reaching prospects (awareness and sales) and delivering the product (deployment and support).

For a private-deployment product: the delivery channel is the deployment mechanism (self-hosted, customer cloud, managed private). The sales channel determines how prospects discover and buy.

**Common trap:** Conflating the sales channel with the product delivery channel.

---

### 4. Customer Relationships

**What type of relationship does each customer segment expect you to establish and maintain?**

| Relationship type | Description | Fit for |
|---|---|---|
| Self-service | Customer helps themselves | PLG products with simple setup |
| Automated | System-driven personalisation | SaaS with data-driven onboarding |
| Dedicated account management | Human relationship | Enterprise, high-touch B2B |
| Community | Peer-to-peer support | Developer tools, open-source |
| Co-creation | Customer participates in product development | Design partner programs |

For SMB private-deployment products: self-service onboarding + community + light human support scales best.

---

### 5. Revenue Streams

**For what value are your customers willing to pay? How do they currently pay? How would they prefer to pay?**

- State the pricing model (from the GTM strategy)
- State the revenue mechanism: subscription, one-time licence, usage-based, transaction fee
- Estimate the relative contribution of each revenue stream if there are multiple
- Note the pricing rationale: what value anchor justifies the price?

**Common trap:** Listing a revenue stream without connecting it to the value proposition. Every revenue stream must be traceable to a value proposition that justifies a customer's willingness to pay.

---

### 6. Key Resources

**What key assets does the value proposition require to deliver?**

| Resource type | Examples |
|---|---|
| Physical | Servers, customer-deployed infrastructure |
| Intellectual | Proprietary algorithms, trained models, patents, data |
| Human | Domain expertise, engineering capability, sales relationships |
| Financial | Capital, credit lines |

For a private-deployment data product: the key intellectual resources are the entity extraction model, the compliance rule engine, and the graph database design. These are the moat.

---

### 7. Key Activities

**What key activities does the value proposition require? What activities are most important in distribution, customer relationships, and revenue streams?**

- List only the activities without which the business cannot deliver its value proposition
- Distinguish between: production (building/running the product), problem-solving (domain expertise applied to complex customer needs), platform/network management

**Common trap:** Listing every activity the company does. Key Activities are the ones that, if stopped, would directly prevent value delivery.

---

### 8. Key Partnerships

**Who are your key partners and suppliers? What key resources do they provide? What key activities do they perform?**

Types of partnerships:
- **Buyer/supplier optimisation:** negotiated access to resources you cannot or should not own (cloud providers, open-source LLM providers)
- **Reduction of risk and uncertainty:** partners who provide credibility, distribution, or insurance (compliance certification bodies, channel partners)
- **Acquisition of resources or activities:** partners who fill capability gaps (implementation partners, resellers)

Note: partnerships are not customers. Do not list customers as partners.

---

### 9. Cost Structure

**What are the most important costs inherent in the business model? Which key resources and key activities are most expensive?**

- Categorise as: Cost-driven (optimise every cost) vs Value-driven (invest in premium value delivery)
- List the three to five highest-cost line items
- Distinguish fixed costs (infrastructure, core team) from variable costs (per-customer deployment, support)

**Common trap:** Ignoring customer-acquisition cost (CAC) and customer-success cost as line items. For a B2B SaaS, CAC and cost-to-serve are often the two largest cost drivers.

---

## Lean Canvas (for pre-revenue / early-stage)

When the product is pre-revenue or the business model is highly uncertain, use the Lean Canvas (Ash Maurya) instead. It replaces four BMC blocks with problem-focused alternatives:

| Replaced with | Reason |
|---|---|
| Key Partners → Problem | At early stage, the problem hypothesis is more uncertain than partner relationships |
| Key Activities → Solution | The solution needs validation before activities can be defined |
| Key Resources → Key Metrics | The metrics that indicate product-market fit are more important early |
| Customer Relationships → Unfair Advantage | The sustainable competitive moat matters more than relationship type |

Use Lean Canvas for Stage 1 (closed beta). Migrate to full BMC at Stage 2 (soft launch) once the problem and solution are validated.

---

## Business Model Coherence Check

After completing all nine blocks, run the coherence check:

1. Does every Value Proposition directly address a named Customer Segment's problem?
2. Does every Channel reach the Customer Segments the Value Propositions are designed for?
3. Do the Key Activities produce the Value Propositions — and nothing else in the canvas?
4. Do the Key Resources enable the Key Activities?
5. Do the Revenue Streams flow from Customer Segments who receive the Value Propositions?
6. Do the Cost Structure items map to Key Activities and Key Resources?
7. Is there at least one item in the canvas that competitors cannot easily replicate?

If any answer is no, the block containing the gap must be revised.

---

## Output Format

```markdown
---
artifact: business-model-canvas
product: [product name]
version: 1.0.0
phase: strategy
created: [date]
owner: product-strategist
canvas-type: [bmc | lean-canvas]
---

# Business Model Canvas

## Customer Segments
[Segments with priority ranking]

## Value Propositions
[One per segment, pain relieved + gain created]

## Channels
[Sales channels and delivery channels]

## Customer Relationships
[Relationship type per segment]

## Revenue Streams
[Model, mechanism, value anchor]

## Key Resources
[Physical | Intellectual | Human | Financial]

## Key Activities
[Production | Problem-solving | Platform management]

## Key Partnerships
[Partner | Type | What they provide]

## Cost Structure
[Type | Top 5 cost items | Fixed vs variable]

## Coherence Check
[7-question checklist results]
```
