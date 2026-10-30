# Pricing and Packaging — Artifact Template

Self-contained. Copy everything below the line into `artifacts/<product>/strategy/pricing-and-packaging.md` and replace every `[bracketed]` value. This is the **standard** shape. Sections marked *(enterprise)* are deleted below enterprise. At lean the artifact is skipped.

---

```markdown
---
name: pricing-and-packaging
product: [product name]
version: 1.0.0
phase: strategy
created: [YYYY-MM-DD]
summary: [one sentence, ≤ 200 chars — the tiers, what fences them and the price basis, e.g. "Three tiers fenced by active clients and partner reporting, $79/$149/$279 per firm per month from 3 paid pilots; give-get discounts only."]
owner: product-strategist
profile: [standard | enterprise]
traces_to: [strategy/gtm-strategy.md; strategy/business-model-canvas.md; strategy/competitive-analysis.md]
---

# Pricing and Packaging

## 1. From the GTM (cited, not restated)

Monetisation model: [from GTM §7] · Charging unit: [from GTM §7] · Price strategy: [maximisation / penetration / skimming, from GTM §7] · Range per tier: [from GTM §7]

## 2. Willingness-to-Pay Evidence

| Segment | Who was asked (role) | How many | Label | Range | Date |
|---|---|---|---|---|---|
| [segment] | [economic buyer / user] | [n] | [stated / committed / observed] | [acceptable – expensive – too expensive] | [date] |

**Still to confirm:** [stated-only figures and the step that will confirm them]

## 3. Segments (needs and WTP first, firmographics second)

| Segment | Needs that differ | WTP range | Found by (firmographics) |
|---|---|---|---|
| [segment] | [what it values that others don't] | [range] | [size / industry / region] |

## 4. Leaders, Fillers and Killers

| Feature | [Segment A] | [Segment B] | [Segment C] | Evidence |
|---|---|---|---|---|
| [feature] | [L / F / K] | | | [interview ranking, pilot behaviour] |

## 5. Tiers and Fences

| | [Tier 1] | [Tier 2 — intended best-seller] | [Tier 3] |
|---|---|---|---|
| Aimed at | [segment] | [segment] | [segment] |
| Leaders inside | | | |
| Charging-unit limit | | | |
| List price | [price per unit per period] | | |

| Boundary | Fence | Holds which segment |
|---|---|---|
| [Tier 1 → Tier 2] | [usage limit / leader / contract term] | [segment that would otherwise buy down] |

**Add-ons and bundles:** [item — reason]. *(enterprise)*

**Price basis:** value anchor [amount, inputs, label] · WTP [range, label] · cost-to-serve floor [amount]. [How the strategy is applied: none extra for maximisation; exit condition for penetration; step-down schedule for skimming.]

## 6. Business Case

[Paste the output of the skill's calculate-business-case script: base case per segment, net, break-even adoption, price × adoption sensitivity grid.]

**Inputs and their labels:** [segment size source; adoption from which evidence; cost to serve from canvas]
**Pessimistic row in words:** [if price and adoption are both 20% below, net is …]
**Gate:** [proceed / reshape (how) / stop]

## 7. Presentation *(enterprise; one line at standard)*

Order shown: [top tier first?] · Middle option: [tier] · Partitioning: [per what, per month or year] · No fake reference prices, hidden fees or resetting countdowns.

## 8. Discounts and Price Integrity

| Get | Give | Granted by | Limit |
|---|---|---|---|
| [annual term] | [x%] | [role] | [max] |

**Not a get:** end-of-period closing, matching a competitor without a value answer.
**Tracked:** realised price vs list; discount depth; share of deals discounted.

## 9. Value Brief by Buying-Group Role *(enterprise)*

| Role | What "too expensive" means | Value line | Proof |
|---|---|---|---|
| [finance] | | | |

## 10. Launch and Change Rules

- Introductory or pilot prices end: [date / renewal]
- Existing customers at a price rise: [grandfathered for …; notice …]
- Feature moved between tiers: [rule]
- Review triggers: [price losses in win/loss > …; average discount > …; middle-tier share < …; cost to serve moves > …]

## 11. Four-Failure Check

Feature shock: [result] · Minivation: [result] · Hidden gem: [result] · Undead: [result]
```
