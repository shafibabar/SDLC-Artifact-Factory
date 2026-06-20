# Skill: strategy/competitive-analysis

## Purpose
Map the competitive landscape: direct competitors, indirect alternatives, and the status quo. Identify where the product wins, where it loses, and what competitive moats must be built. This artifact directly informs the GTM positioning and the product roadmap's differentiation choices.

## Inputs
Read before generating:
- `artifacts/strategy/vision.md` — must exist
- `sdlc-config.json` — product_name, problem_statement
- Ask the user: "Do you know of specific competitors or alternatives customers currently use? List any you're aware of."

## Output
**File:** `artifacts/strategy/competitive-analysis.md`
**Registers in manifest:** yes

## Competitor Categories to Cover
1. **Direct competitors** — same problem, same category
2. **Indirect competitors** — different approach to the same underlying job
3. **Status quo / incumbent** — what customers do today without a dedicated product
4. **Potential future entrants** — who could enter this market if it proves valuable

## Process
1. Read vision and problem statement.
2. Identify all competitor categories. Add any provided by the user.
3. For each competitor: describe their approach, target segment, strengths, and weaknesses.
4. Score the product against each competitor on 5–7 key dimensions.
5. Identify the top 3 competitive moats the product must build.
6. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# Competitive Analysis

**Product:** {product_name}
**Phase:** Strategy
**Artifact:** Competitive Analysis
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Market Overview
{2–3 sentences on the competitive landscape. How mature is this market? Are there dominant players or is it fragmented? What is the primary buying trigger?}

---

## Competitor Profiles

### {Competitor 1 Name}
- **Category:** Direct / Indirect / Status quo
- **Approach:** {how they solve the problem}
- **Target segment:** {who they serve primarily}
- **Pricing model:** {if known}
- **Strengths:** {what they do well}
- **Weaknesses:** {where they fall short — be specific}
- **Why customers choose them:** {their primary selling point}
- **Why customers leave them:** {common complaints or gaps}

### {Competitor 2 Name}
{same structure}

### {Competitor 3 Name}
{same structure}

### Status Quo (What customers do without a product like ours)
- **Current approach:** {manual process, spreadsheets, internal tooling, consultants}
- **Cost of the status quo:** {time, risk, missed opportunity}
- **Why they haven't switched yet:** {switching cost, awareness, budget, trust}

---

## Competitive Scoring Matrix

Dimensions chosen based on what matters most to the ICP. Rate each on 1–5.

| Dimension | {Product Name} | {Competitor 1} | {Competitor 2} | {Competitor 3} | Status Quo |
|-----------|---------------|----------------|----------------|----------------|------------|
| {e.g. Data residency control} | 5 | 2 | 3 | 1 | 5 |
| {e.g. Time to first insight} | 4 | 3 | 4 | 2 | 1 |
| {e.g. Compliance framework depth} | 5 | 4 | 3 | 3 | 1 |
| {e.g. Ease of deployment} | 4 | 3 | 2 | 4 | 5 |
| {e.g. Total cost of ownership} | 4 | 2 | 3 | 3 | 3 |
| {e.g. Natural language querying} | 5 | 1 | 2 | 1 | 1 |
| **Total** | {sum} | {sum} | {sum} | {sum} | {sum} |

---

## Competitive Moats to Build

The following are the durable advantages the product must establish to defend its position:

| Moat | Description | Time to build | Priority |
|------|-------------|--------------|----------|
| {moat 1, e.g. Data network effect} | {why this becomes harder for competitors to replicate over time} | {short/medium/long term} | Critical / High / Medium |
| {moat 2, e.g. Compliance certification stack} | {description} | {timeline} | {priority} |
| {moat 3, e.g. Integration ecosystem} | {description} | {timeline} | {priority} |

---

## Positioning Summary

**Where we win:** {3 scenarios where the product is the clear best choice}

**Where we lose (and why that is acceptable):** {segments or scenarios where a competitor is a better fit — be honest. Trying to win everywhere loses everywhere.}

**The competitive bet we are making:** {One paragraph on the core hypothesis about why this product will win in its chosen segment, what competitors are unable or unwilling to copy, and what the product must execute on to make that hypothesis true.}
```

## Quality Checks
Before writing:
- [ ] Status quo is treated as a competitor (the "do nothing" option)
- [ ] Weaknesses of the product are honestly documented, not just competitor weaknesses
- [ ] Competitive moats are structural advantages, not just current features
- [ ] "Where we lose" is explicitly stated — a positioning that wins everywhere is not a positioning
- [ ] No undefined ubiquitous language terms
