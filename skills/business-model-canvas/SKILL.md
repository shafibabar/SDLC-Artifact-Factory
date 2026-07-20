---
name: business-model-canvas
description: >
  Teaches how to complete a Business Model Canvas (BMC) for a product — covering
  all nine blocks, the logical dependencies between blocks, common traps per block,
  and how to use the canvas to identify business model risks before committing to
  architecture or roadmap. Includes a Lean Canvas variant for early-stage products.
  Used by the product-strategist agent during the Strategy phase.
version: 1.1.0
phase: strategy
owner: product-strategist
created: 2026-06-24
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

## Worked Example (Condensed)

Canvas excerpts for the first product (Data Estate Mapping and Compliance Intelligence):

| Block | Entry |
|---|---|
| Customer Segments | Primary: SMBs of 50–500 employees with SOC 2 obligations and data spread across Google Drive and AWS S3. Users: compliance officers (the Maya Chen archetype). Buyers: CTO / VP Engineering — distinct needs, both must be served. |
| Value Propositions | "Know exactly what sensitive data you hold, where it lives, and which SOC 2 controls it puts at risk — within 30 minutes, without a single file leaving your infrastructure." (Pain relieved: audit blindness. Gain: evidence on demand.) |
| Channels | Sales: content/SEO plus compliance-community presence. Delivery: private deployment into the customer's own Kubernetes cluster — the delivery channel is itself part of the differentiation. |
| Customer Relationships | Self-service onboarding + light human support; co-creation with 3–5 design partners during closed beta. |
| Revenue Streams | Flat annual subscription per tenant, tiered by connected storage source count. Value anchor: compliance-officer hours of audit-prep saved per quarter. |
| Key Resources | Entity extraction pipeline, SOC 2 control-mapping rule engine, relationship graph design — the intellectual moat. |
| Key Activities | Building and hardening the scanning/classification pipeline; maintaining connector coverage; compliance rule curation. |
| Key Partnerships | Cloud providers (deployment substrate); open-source model providers for extraction; no reseller motion at this stage. |
| Cost Structure | Value-driven. Top items: engineering time, per-customer deployment support, CI/CD and test infrastructure. Zero paid third-party APIs (frugality constraint). |

**Coherence check result:** every Revenue Stream traces to the Value Proposition; the private-deployment delivery Channel is the item competitors' SaaS architectures cannot copy without rebuilding (check 7 passes).

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Block completeness | Every one of the nine blocks has at least one substantive entry | Any block empty or marked "TBD" |
| Segment specificity | Segments defined by size band, vertical, and regulatory exposure | "All SMBs" (or equivalent) as a single segment |
| Value proposition form | States pain relieved + gain created, differentiated from competitors | Product features listed in the value proposition block |
| Buyer/user split | Users and buyers distinguished wherever they differ | A single undifferentiated "customer" |
| Revenue traceability | Every revenue stream traces to a value proposition a segment will pay for | Revenue streams with no value justification |
| Cost realism | CAC and cost-to-serve appear alongside build/run costs | Only infrastructure and engineering costs listed |
| Coherence | All 7 coherence questions answer yes (or the gap block is revised) | Canvas finalised with failing coherence answers |
| Defensibility | At least one canvas item competitors cannot easily replicate | Nothing a competitor could not copy within a quarter |

---

## Anti-Patterns

**Nine unconnected lists:** each block filled in isolation and the coherence check skipped. The canvas's value is the fit between blocks, not the blocks themselves — a beautiful canvas with incoherent flows is a decorated risk register.

**Feature-first value propositions:** copying the feature list into the Value Propositions block. If the entry does not name a customer pain or gain, it is not a value proposition.

**Aspirational partnerships:** listing partners you hope to sign as Key Partnerships. Only relationships that exist, or are realistically closable within the planning horizon, belong on the canvas.

**Frozen canvas:** completing the canvas once and never revisiting it. Re-validate at every launch stage transition (closed beta → soft launch → GA) — the blocks that survive contact with paying customers are rarely the blocks you drew.

**Full BMC before validation:** using the complete BMC while the problem and solution are still hypotheses. It projects false certainty into blocks (Partnerships, Relationships) that cannot yet be known. Use the Lean Canvas until Stage 2, as specified above.

---

## Output Format

```markdown
---
name: business-model-canvas
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
