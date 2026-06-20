# Skill: strategy/stakeholder-map

## Purpose
Identify and map all stakeholders — internal and external — who have influence over or interest in the product. The Stakeholder Map informs persona development, the GTM strategy, and the communication plan. It prevents key voices from being overlooked during discovery.

## Inputs
Read before generating:
- `artifacts/strategy/vision.md` — must exist
- `sdlc-config.json` — product_name, target market context, compliance_frameworks

## Output
**File:** `artifacts/strategy/stakeholders.md`
**Registers in manifest:** yes

## Process
1. Read the vision and config.
2. Identify all stakeholder categories: buyers, users, influencers, gatekeepers, internal team, partners, regulators.
3. For each stakeholder, determine: their role, their primary concern, their level of influence over the product's success, and their level of interest in the product.
4. Map stakeholders on the influence/interest matrix.
5. Define the engagement approach per quadrant.
6. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# Stakeholder Map

**Product:** {product_name}
**Phase:** Strategy
**Artifact:** Stakeholder Map
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Stakeholder Register

| Stakeholder | Category | Role in decision | Primary concern | Influence | Interest | Quadrant |
|-------------|----------|-----------------|----------------|-----------|----------|----------|
| {e.g. CISO} | Buyer / Gatekeeper | Approver | Compliance posture, audit readiness | High | High | Manage Closely |
| {e.g. CFO} | Buyer | Budget authority | Cost reduction, ROI | High | Medium | Keep Satisfied |
| {e.g. IT Admin} | User | Day-to-day operator | Ease of deployment, reliability | Low | High | Keep Informed |
| {e.g. Compliance Officer} | User / Influencer | Requirements input | Framework coverage, evidence quality | Medium | High | Manage Closely |
| {e.g. Legal counsel} | Gatekeeper | Contractual approval | Data residency, liability | High | Low | Keep Satisfied |
| {e.g. Regulator / auditor} | External | Audit authority | Standards adherence | High | Low | Keep Satisfied |
| {e.g. Integration partner} | Partner | Distribution / referral | Technical fit, revenue share | Medium | Medium | Keep Informed |

**Influence:** High / Medium / Low — their ability to block or accelerate adoption
**Interest:** High / Medium / Low — how much they care about the product's success

---

## Influence / Interest Matrix

```
           HIGH INTEREST
                │
 Keep Informed  │  Manage Closely
 (Low/High)     │  (High/High)
────────────────┼────────────────
 Monitor        │  Keep Satisfied
 (Low/Low)      │  (High/Low)
                │
           LOW INTEREST
```

### Manage Closely (High Influence, High Interest)
{List stakeholders in this quadrant. These are your champions and potential blockers. Engage frequently, involve in decisions, address concerns proactively.}

### Keep Satisfied (High Influence, Low Interest)
{List stakeholders. These can veto or significantly delay. Provide regular, concise updates. Surface issues before they reach them through another channel.}

### Keep Informed (Low Influence, High Interest)
{List stakeholders. Valuable sources of feedback and product intelligence. Involve in beta, gather requirements, but do not burden with operational decisions.}

### Monitor (Low Influence, Low Interest)
{List stakeholders. Minimum engagement. Notify of major decisions only.}

---

## Key Stakeholder Profiles

### {Stakeholder 1 Name / Role}
- **Organisation type:** {buyer company, partner, regulator}
- **Primary job to be done:** {what they are trying to accomplish}
- **Their definition of success:** {what a successful outcome looks like to them}
- **Their greatest fear:** {what would make them block or abandon the product}
- **Communication preference:** {how and how often to engage}
- **Engagement owner:** {who on the product team owns this relationship}

### {Stakeholder 2 Name / Role}
{same structure}

---

## Stakeholder Risk Register

| Risk | Stakeholder | Probability | Impact | Mitigation |
|------|-------------|-------------|--------|------------|
| {e.g. CISO blocks on data residency concerns} | CISO | High | High | Ensure data residency is architectural, not a feature — document in security architecture |
| {e.g. Legal delays contract due to liability clauses} | Legal | Medium | High | Engage legal early with data processing agreement template |
```

## Quality Checks
Before writing:
- [ ] All four quadrants of the matrix are populated
- [ ] At least one "Manage Closely" stakeholder profile is fully detailed
- [ ] Gatekeeper stakeholders (those who can block the deal) are explicitly identified
- [ ] Stakeholder risk register is populated with at least two risks
- [ ] No undefined ubiquitous language terms
