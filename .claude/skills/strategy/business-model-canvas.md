# Skill: strategy/business-model-canvas

## Purpose
Produce a Business Model Canvas (BMC) — a single-page view of how the product creates, delivers, and captures value. The BMC makes the business model explicit and reviewable, revealing dependencies and gaps before they become expensive.

## Inputs
Read before generating:
- `artifacts/strategy/vision.md` — must exist
- `artifacts/strategy/gtm.md` — recommended (use if exists)
- `sdlc-config.json` — product_name

## Output
**File:** `artifacts/strategy/bmc.md`
**Registers in manifest:** yes

## Process
1. Read vision and GTM if available.
2. Fill all 9 BMC blocks in the defined order: Customer Segments → Value Propositions → Channels → Customer Relationships → Revenue Streams → Key Resources → Key Activities → Key Partnerships → Cost Structure.
3. Check for internal consistency: do the Key Resources support the Key Activities? Do the Key Activities deliver the Value Propositions?
4. Identify the top 3 business model risks.
5. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# Business Model Canvas

**Product:** {product_name}
**Phase:** Strategy
**Artifact:** Business Model Canvas
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## 1. Customer Segments
*Who are we creating value for? Who are our most important customers?*

- **Primary segment:** {description}
- **Secondary segment (if any):** {description}
- **Segment characteristics:** {size, commonalities, distinctions}

## 2. Value Propositions
*What value do we deliver? Which customer problems do we solve? Which needs do we satisfy?*

| Customer job / problem | Value we deliver | Value type |
|----------------------|-----------------|------------|
| {job 1} | {how we solve it} | Functional / Social / Emotional |
| {job 2} | {how we solve it} | Functional / Social / Emotional |
| {job 3} | {how we solve it} | Functional / Social / Emotional |

**Primary value proposition (one sentence):** {statement}

## 3. Channels
*How do we reach our Customer Segments to deliver our Value Proposition?*

| Phase | Channel | Type |
|-------|---------|------|
| Awareness | {channel} | Owned / Paid / Partner |
| Consideration | {channel} | Owned / Paid / Partner |
| Purchase | {channel} | Direct / Self-serve / Reseller |
| Delivery | {channel} | {how the product is delivered} |
| After-sales | {channel} | {support / expansion / community} |

## 4. Customer Relationships
*What type of relationship does each Customer Segment expect?*

- **Acquisition model:** {self-serve onboarding / high-touch sales / partner-referred}
- **Retention model:** {what keeps customers — outcomes delivered, switching cost, community}
- **Expansion model:** {upsell / cross-sell / usage growth}

## 5. Revenue Streams
*For what value are our customers willing to pay? How do they currently pay?*

| Stream | Model | Pricing basis | % of total revenue (est.) |
|--------|-------|--------------|--------------------------|
| {stream 1, e.g. SaaS subscription} | Recurring | {per seat / per tenant / flat} | {%} |
| {stream 2, e.g. professional services} | One-time | {per engagement} | {%} |

## 6. Key Resources
*What Key Resources does our Value Proposition require?*

- **Intellectual:** {proprietary technology, data assets, algorithms}
- **Human:** {key skills — engineering, domain expertise, sales}
- **Physical:** {infrastructure, hardware if applicable}
- **Financial:** {capital requirements, runway needed}

## 7. Key Activities
*What Key Activities does our Value Proposition require?*

- {activity 1 — e.g. entity extraction model development and maintenance}
- {activity 2 — e.g. customer onboarding and integration support}
- {activity 3 — e.g. compliance framework mapping and updates}
- {activity 4 — e.g. platform reliability and security operations}

## 8. Key Partnerships
*Who are our Key Partners and Suppliers? What Key Resources do we acquire from them?*

| Partner type | Partner example | What we get from them |
|-------------|-----------------|----------------------|
| Technology partner | {e.g. cloud provider} | {infrastructure, marketplace listing} |
| Channel partner | {e.g. reseller / MSP} | {distribution, customer trust} |
| Integration partner | {e.g. GRC tool vendor} | {data integration, co-marketing} |

## 9. Cost Structure
*What are the most important costs inherent in our business model?*

| Cost category | Type | Scale driver |
|--------------|------|-------------|
| {e.g. Cloud infrastructure} | Variable | Customer count / data volume |
| {e.g. Engineering team} | Fixed | Headcount |
| {e.g. Compliance certifications} | Fixed (annual) | — |
| {e.g. Customer success} | Variable | Customer count |

**Unit economics (early estimate):**
- CAC (Customer Acquisition Cost): {estimate or TBD}
- LTV (Lifetime Value): {estimate or TBD}
- LTV:CAC target ratio: {e.g. >3:1}

---

## Business Model Consistency Check

| Check | Status | Note |
|-------|--------|------|
| Key Resources support Key Activities | ✓ / ✗ | |
| Key Activities deliver the Value Proposition | ✓ / ✗ | |
| Channels reach the correct Customer Segments | ✓ / ✗ | |
| Revenue Streams are priced to Value Propositions | ✓ / ✗ | |
| Cost Structure is sustainable relative to Revenue Streams | ✓ / ✗ | |

## Top 3 Business Model Risks
1. {risk 1 — e.g. CAC too high for SMB segment at current pricing}
2. {risk 2 — e.g. key partnership dependency creates single point of failure}
3. {risk 3 — e.g. compliance certification cost front-loaded before revenue}
```

## Quality Checks
Before writing:
- [ ] All 9 BMC blocks are populated — no block is left empty
- [ ] Business model consistency check passes (all ✓)
- [ ] Top 3 risks identified and honest
- [ ] Unit economics section populated (even if estimates)
- [ ] No undefined ubiquitous language terms
