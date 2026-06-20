# Skill: strategy/vision-statement

## Purpose
Produce a Vision Statement artifact that defines what the product is, who it is for, what problem it solves, and what success looks like. This is the northernmost anchor for all downstream artifacts.

## Inputs
Read before generating:
- `sdlc-config.json` — product_name, problem_statement, target market context
- Any prior strategy artifacts if this is a revision

## Output
**File:** `artifacts/strategy/vision.md`
**Registers in manifest:** yes (call core/artifact-manifest → register artifact)

## Process
1. Read `sdlc-config.json` to load product name and problem statement.
2. Ask the user (if not already provided): "Who is the primary customer? What is the single most important outcome they get from this product?"
3. Generate the artifact following the template below.
4. Run core/glossary → validate on the artifact before saving.
5. Write the file. Register with core/artifact-manifest.

## Artifact Template

```markdown
# Vision Statement

**Product:** {product_name}
**Phase:** Strategy
**Artifact:** Vision Statement
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## The One-Liner
> {A single sentence: For [target customer] who [have this problem], [product name] is a [category] that [key benefit]. Unlike [primary alternative], our product [primary differentiator].}

## Problem We Solve
{2–3 sentences. Describe the current state of the world without the product. What pain exists? What is the cost of that pain to the customer?}

## Our Solution
{2–3 sentences. Describe the product's approach at the highest level. Not features — the fundamental mechanism by which value is created.}

## Target Customer
{Who is the primary customer? Describe in terms of role, situation, and motivation — not just demographic. Reference the Stakeholder Map for full detail.}

## Key Differentiators
| Differentiator | Why it matters |
|---------------|----------------|
| {differentiator 1} | {customer value} |
| {differentiator 2} | {customer value} |
| {differentiator 3} | {customer value} |

## What Success Looks Like (3–5 Year Horizon)
{Describe the future state if the product fulfils its vision. What is different in the customer's world? What market position has been achieved? Link to North Star Metric.}

## What This Product Is NOT
{Explicitly scope out: what problems this product does not solve, what customers it does not serve. Prevents scope creep at the ideation phase.}

## Alignment to Problem Statement
{One paragraph explicitly connecting this vision back to the problem statement in `sdlc-config.json`. Confirms no drift between the original intent and the articulated vision.}
```

## Quality Checks
Before writing:
- [ ] The one-liner follows the format: For / who / is a / that / Unlike / our product
- [ ] No undefined ubiquitous language terms (run core/glossary → validate)
- [ ] "What This Product Is NOT" section is populated — vague scope is a defect
- [ ] The vision is aspirational but not disconnected from the problem statement
