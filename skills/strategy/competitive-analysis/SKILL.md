---
name: competitive-analysis
description: >
  Teaches how to map the competitive landscape, build a capability matrix,
  draw a positioning map, run a SWOT for competitive positioning, and articulate
  defensible differentiation points. Covers direct competitors, indirect competitors,
  and substitutes. Used by the product-strategist agent during the Strategy phase
  to ground GTM strategy and roadmap prioritisation in market reality.
version: 1.0.0
phase: strategy
owner: product-strategist
tags: [strategy, competitive-analysis, positioning, differentiation, gtm]
---

# Competitive Analysis

## Purpose

A product that does not understand its competitive context will misprice, misposition, and build features that do not differentiate. Competitive analysis is not about copying competitors — it is about understanding the landscape well enough to occupy a position no one else owns.

This analysis feeds directly into GTM strategy (positioning and messaging), roadmap prioritisation (build what competitors cannot easily copy), and architecture decisions (the differentiation must be technically defensible).

---

## Competitive Landscape Taxonomy

| Type | Definition | Example for a data estate product |
|---|---|---|
| **Direct competitors** | Solve the same problem for the same user | BigID, Varonis, Securiti.ai |
| **Indirect competitors** | Solve a related problem or a subset of the problem | DLP tools, CASB platforms, manual spreadsheet audits |
| **Substitutes** | Address the same user need through a completely different means | Hiring a Data Privacy Officer, engaging a compliance consultant |
| **Future entrants** | Players not yet in the space but with the capability to enter | Cloud providers (AWS Macie, Google DLP), existing GRC platforms |

---

## Step-by-Step Production

### Step 1 — Define the competitive dimensions

Identify 6–10 capability dimensions that matter to the target user. These are the axes on which the product competes. Examples for a compliance/data platform:

- Deployment model (SaaS vs private vs hybrid)
- Data residency guarantees
- Supported storage connectors
- Compliance frameworks covered
- Time to first insight
- Pricing model
- SMB fit (vs enterprise-only)
- Graph/visualisation capability

### Step 2 — List competitors across all four types

Aim for 3–6 direct competitors, 3–4 indirect, and 2–3 substitutes. Do not list more than you can analyse thoroughly.

### Step 3 — Build the capability matrix

Rate each competitor on each dimension: ✓ (strong), ~ (partial), ✗ (absent), ? (unknown).

See `references/competitive-analysis-template.md` for the matrix format.

### Step 4 — Draw the positioning map

Select the two most important dimensions where your product has a distinct position. Plot all competitors on a 2×2 map with these as the axes. The position where your product sits should have low competitor density.

If your product and a competitor occupy the same position on the map, the differentiation is insufficient.

### Step 5 — Run competitive SWOT

Focus the SWOT on competitive positioning, not general business health:

| Quadrant | Question |
|---|---|
| **Strengths** | Where do you outperform all identified competitors on dimensions that matter to the target user? |
| **Weaknesses** | Where are you behind on dimensions the target user values? |
| **Opportunities** | What needs are underserved by all current competitors? |
| **Threats** | Which competitors are moving toward your position? Which future entrants could enter? |

### Step 6 — Articulate differentiation points

From the capability matrix and positioning map, identify 2–3 differentiation points that meet all three criteria:

1. **Valued** — the target user explicitly cares about this dimension
2. **Real** — you genuinely outperform all competitors on this dimension today or will within the roadmap horizon
3. **Defensible** — competitors cannot easily copy it (requires architectural choices, regulatory relationships, distribution advantages, or time investment)

### Step 7 — Identify competitive risks

Flag any competitor that: is moving toward your position, has recently announced relevant features, has a distribution advantage in your target segment, or is backed by a platform that could bundle a competing capability.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Landscape coverage | All four competitor types analysed | Only direct competitors listed |
| Capability dimensions | 6–10 dimensions relevant to the target user | Generic dimensions (pricing, support, features) |
| Positioning map | Blank space exists where your product sits | Every quadrant of the map is occupied |
| Differentiation | 2–3 points that are valued, real, and defensible | "Better UX" or "lower price" without evidence |
| Threat identification | At least one credible future entrant assessed | No threats identified |
| Recency | Based on market research dated within the last 6 months | Based on assumptions or outdated information |

---

## Common Anti-Patterns

**The flattering matrix:** Rating every competitor as weak on every dimension. Either the dimensions were chosen to favour you, or the analysis is dishonest.

**No substitutes:** Ignoring "do nothing" or manual alternatives. For SMBs especially, the real competitor is often a spreadsheet maintained by a consultant.

**Positioning without a map:** Claiming a differentiated position without placing yourself and all competitors on a positioning map. Undisciplined positioning claims drift.

**Imitation as strategy:** Building a capability matrix that reveals the product is following every competitor rather than leading in any direction.

---

## Output Format

```markdown
---
artifact: competitive-analysis
product: [product name]
version: 1.0.0
phase: strategy
created: [date]
owner: product-strategist
---

# Competitive Analysis

## Competitive Landscape

[Table: Competitor | Type | Brief description | Key strength | Key weakness]

## Capability Matrix

[Table: Dimension | Your product | Competitor 1 | Competitor 2 | ... ]

## Positioning Map

[2×2 diagram: axes = two most important differentiating dimensions; plotted positions for all competitors and your product]

## Competitive SWOT

[Strengths | Weaknesses | Opportunities | Threats]

## Differentiation Points

[2–3 differentiation points, each with: dimension, evidence of outperformance, defensibility rationale]

## Competitive Risks

[Table: Risk | Competitor | Probability | Impact | Mitigation]
```
