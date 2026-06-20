# Skill: strategy/gtm-strategy

## Purpose
Produce a Go-to-Market (GTM) strategy covering target segments, positioning, channel strategy, pricing model, and launch approach. The GTM strategy answers: who buys this, why they buy it, how they find it, and what they pay.

## Inputs
Read before generating:
- `artifacts/strategy/vision.md` — must exist
- `artifacts/strategy/okrs.md` — must exist
- `sdlc-config.json` — product_name, compliance_frameworks, tenancy_model
- Ask the user: "Do you have a preferred pricing model in mind (subscription, usage-based, per-seat, one-time)? Do you have a preferred sales motion (self-serve, sales-led, partner-led)?"

## Output
**File:** `artifacts/strategy/gtm.md`
**Registers in manifest:** yes

## Process
1. Read vision, OKRs, and config.
2. Derive the ICP (Ideal Customer Profile) from the vision's target customer.
3. Define the positioning statement following the structured format.
4. Determine channel strategy based on ICP characteristics and sales motion preference.
5. Propose a pricing model with rationale and pricing tiers.
6. Define the launch approach: what constitutes a successful launch, who are the first 10 customers.
7. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# Go-to-Market Strategy

**Product:** {product_name}
**Phase:** Strategy
**Artifact:** GTM Strategy
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Ideal Customer Profile (ICP)

| Attribute | Description |
|-----------|-------------|
| **Company size** | {e.g. 50–500 employees} |
| **Industry** | {primary verticals} |
| **Compliance obligation** | {regulatory pressures the ICP faces} |
| **Technical maturity** | {in-house engineering capability} |
| **Budget authority** | {who controls the budget for this category} |
| **Trigger event** | {what event causes them to go looking for a solution} |

## Buyer Personas (Summary)
{Reference the Stakeholder Map. Summarise the 2–3 primary buyers and their primary concern.}

| Persona | Role | Primary concern | Decision weight |
|---------|------|----------------|-----------------|
| {persona 1} | {title} | {what keeps them up at night} | {champion / approver / influencer} |
| {persona 2} | {title} | {concern} | {role in deal} |

## Positioning Statement
> For **{ICP description}** who **{have this problem}**, **{product name}** is a **{product category}** that **{primary benefit}**. Unlike **{primary alternative}**, our product **{key differentiator}**.

## Why We Win
| Against | Their weakness | Our counter-position |
|---------|---------------|----------------------|
| {competitor / alternative 1} | {where they fall short} | {our strength} |
| {competitor / alternative 2} | {where they fall short} | {our strength} |
| {status quo (doing nothing)} | {cost of inaction} | {our minimum viable value} |

## Channel Strategy

**Primary motion:** {Self-serve / Sales-led / Partner-led}

| Channel | Role | Investment level | Expected contribution |
|---------|------|-----------------|----------------------|
| {channel 1, e.g. inbound content} | {awareness / acquisition / expansion} | {low/med/high} | {% of pipeline at 12 months} |
| {channel 2, e.g. direct outbound} | {role} | {investment} | {contribution} |
| {channel 3, e.g. integration partners} | {role} | {investment} | {contribution} |

## Pricing Model

**Model:** {Subscription / Usage-based / Per-seat / Hybrid}
**Rationale:** {Why this model fits the ICP's buying behaviour and the product's value delivery pattern.}

| Tier | Target customer | Included | Price |
|------|----------------|----------|-------|
| {Tier 1, e.g. Starter} | {ICP sub-segment} | {features/limits} | {$/month or basis} |
| {Tier 2, e.g. Professional} | {ICP sub-segment} | {features/limits} | {$/month or basis} |
| {Tier 3, e.g. Enterprise} | {ICP sub-segment} | {custom / negotiated} | {contact sales} |

## Launch Strategy

**Definition of a successful launch:** {What does success look like at 90 days post-launch?}

**First 10 customers strategy:**
- {How will the first 10 customers be acquired? (design partners, beta program, personal network, etc.)}
- {What will be offered to first 10 customers that public customers will not receive?}
- {What validation will be collected from them?}

**Launch milestones:**
| Milestone | Target date | Success metric |
|-----------|-------------|----------------|
| Private beta launch | {T+0} | {N design partners active} |
| Public launch | {T+X weeks} | {first paid customers} |
| First expansion revenue | {T+Y weeks} | {upsell KR} |
```

## Quality Checks
Before writing:
- [ ] ICP is specific enough to reject customers — if everyone fits, it fits no one
- [ ] Positioning statement follows the required format
- [ ] Pricing model is justified by ICP buying behaviour, not by what competitors charge
- [ ] First 10 customers strategy is concrete and actionable
- [ ] No undefined ubiquitous language terms
