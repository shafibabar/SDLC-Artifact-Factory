# Skill: strategy/north-star-metric

## Purpose
Define the single North Star Metric — the one number that best captures the core value the product delivers to customers. All OKRs, roadmap decisions, and feature prioritisation will be evaluated against impact on this metric.

## Inputs
Read before generating:
- `artifacts/strategy/vision.md` — must exist
- `sdlc-config.json` — product_name, problem_statement

## Output
**File:** `artifacts/strategy/north-star.md`
**Registers in manifest:** yes

## Process
1. Read the vision statement. Identify the core value exchange: what does the customer get, and at what frequency?
2. Apply the North Star Metric test: a good NSM (a) reflects customer value (not business revenue), (b) is measurable, (c) leads revenue (not lags it), (d) is actionable by the product team.
3. Generate three candidate metrics with scoring against the four criteria above.
4. Recommend the strongest candidate with justification.
5. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# North Star Metric

**Product:** {product_name}
**Phase:** Strategy
**Artifact:** North Star Metric
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## The North Star Metric
> **{Metric Name}** — {one-sentence definition of what this metric measures and how it is calculated}

## Why This Is the North Star
{2–3 sentences. Explain why this metric, above all others, captures the core value the product creates for customers. Connect explicitly to the vision statement.}

## Candidate Metrics Evaluated

| Metric | Reflects customer value? | Measurable? | Leads revenue? | Actionable? | Score |
|--------|------------------------|-------------|----------------|-------------|-------|
| {candidate 1} | ✓ / ✗ | ✓ / ✗ | ✓ / ✗ | ✓ / ✗ | {/4} |
| {candidate 2} | ✓ / ✗ | ✓ / ✗ | ✓ / ✗ | ✓ / ✗ | {/4} |
| {candidate 3} | ✓ / ✗ | ✓ / ✗ | ✓ / ✗ | ✓ / ✗ | {/4} |

## How It Is Measured
- **Data source:** {where does this data come from?}
- **Calculation:** {exact formula or method}
- **Frequency:** {how often is it measured and reported?}
- **Instrumentation required:** {what events or metrics must the product emit to calculate this?}

## Current Baseline
{What is the metric today? If the product does not yet exist, describe how the baseline will be established at launch.}

## Target (12 months)
{Specific, numeric target for this metric at 12 months post-launch. Tied to OKRs.}

## Input Metrics
{3–5 leading indicators that drive the North Star Metric. These are the levers the product team can pull.}

| Input Metric | Relationship to NSM |
|-------------|---------------------|
| {input 1} | {how it drives the NSM} |
| {input 2} | {how it drives the NSM} |
| {input 3} | {how it drives the NSM} |
```

## Quality Checks
Before writing:
- [ ] The NSM reflects customer value, not revenue or internal metrics
- [ ] Measurement method is specific enough to implement in the instrumentation plan
- [ ] At least three candidates were evaluated and documented
- [ ] Input metrics are identified — the NSM alone is not actionable
- [ ] No undefined ubiquitous language terms
