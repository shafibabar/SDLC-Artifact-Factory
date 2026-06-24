---
name: vision-statement
description: >
  Teaches how to craft a product vision statement — the single, enduring declaration
  of the future state a product is working toward. Covers the required components,
  proven formats, quality criteria, and anti-patterns. Used by the product-strategist
  agent at the start of every Strategy phase to anchor all subsequent artifacts.
version: 1.0.0
phase: strategy
owner: product-strategist
tags: [strategy, vision, product-discovery, north-star]
---

# Vision Statement

## Purpose

A vision statement answers one question: **what future are we building toward?**

It is written once, lasts years, and serves as the north star that prevents every subsequent decision — roadmap, GTM, architecture, backlog — from drifting away from the core purpose. Every other strategy artifact must be traceable back to it.

A vision is not a product description. It is not a feature list. It is not a mission. It describes the world as it will be when the product succeeds.

---

## Required Components

Every vision statement must contain all five:

| Component | Question it answers | Example |
|---|---|---|
| **Target user** | Who is this for? | "For security-conscious SMB operations teams…" |
| **Unmet need** | What problem persists today? | "…who have no reliable way to know what sensitive data they hold or where it lives…" |
| **Product category** | What kind of solution is this? | "…a data estate intelligence platform…" |
| **Key benefit** | What measurable change does it create? | "…that makes every file, entity, and compliance gap visible in minutes…" |
| **Differentiation** | Why this, not alternatives? | "…without requiring any data to leave the customer's own infrastructure." |

---

## Formats

### Format 1 — Moore's Elevator Test (recommended for B2B products)

```
For [target user]
who [unmet need],
[product name] is a [product category]
that [key benefit].
Unlike [primary alternative],
our product [primary differentiation].
```

### Format 2 — Aspirational Single Sentence (recommended for consumer or platform products)

A single future-tense statement describing the world after the product succeeds.

```
[Verb] [who] [from what current state] [to what future state] [by what means].
```

Example: "Enable every organisation to understand and govern their data estate completely, from any device, in any language, without surrendering control of their data."

### Format 3 — Simon Sinek Golden Circle (recommended when WHY is the differentiator)

Lead with purpose (Why), follow with approach (How), close with offering (What).

---

## Step-by-Step Production

1. **Gather inputs.** Read the problem statement from `sdlc-context.json → first_product`. Identify the target user, the pain they experience today, and the outcome they want.

2. **Draft the target user.** Be specific. "SMB operations teams at companies with 50–500 employees handling regulated data" is better than "businesses."

3. **State the unmet need as a pain, not a feature request.** "Cannot determine what personal data they hold or demonstrate compliance to auditors" is better than "need a compliance tool."

4. **Choose the product category.** This frames the solution in familiar terms without over-specifying implementation. "Data estate intelligence platform" not "SaaS dashboard with connectors."

5. **Define the key benefit as an outcome.** Quantify where possible. "Complete visibility in under 30 minutes of setup" is better than "easy to use."

6. **State the differentiator as a constraint the alternatives cannot or will not meet.** The constraint must be real and defensible.

7. **Write the vision using Format 1 or 2.** Keep it under 60 words.

8. **Validate against the quality criteria below.** Revise until it passes.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Length | ≤ 60 words | > 60 words |
| Horizon | 3–5 years ahead | Describes what the product does today |
| Specificity | Names a real, identifiable user group | "Everyone" or "all businesses" |
| Differentiation | States a real constraint competitors cannot match | Generic claim ("better", "faster", "easier") |
| Inspirational | A team member reading it would understand why the work matters | Reads like a product spec or a marketing tagline |
| Technology-agnostic | Describes outcomes, not implementation | Names a specific technology or platform |
| Stability | Could remain true for 3+ years without modification | Would be invalidated by a single product decision |

---

## Anti-Patterns

**Too vague:** "To be the leading platform for data management." — No user, no need, no differentiation.

**Too tactical:** "To provide a dashboard that scans Google Drive and generates a compliance report." — Describes a feature, not a future state.

**Too broad:** "To help every company manage their data better." — Unfalsifiable and unreachable.

**Disguised mission:** "To scan customer storage systems and classify sensitive data." — Describes what the product does today, not where it is going.

**Technology-locked:** "To be the best Kubernetes-native data governance tool." — Technology changes; vision must outlast it.

---

## Canonical Terms to Use

From `skills/governance/glossary-management/references/ubiquitous-language.md`:
- **North Star Metric** — the vision must imply a measurable north star
- **Jobs To Be Done (JTBD)** — the unmet need is the job the user is trying to do
- **Outcome-Driven Development** — the benefit is an outcome, not a feature

---

## Output Format

Produce the vision statement as a Markdown artifact with frontmatter:

```markdown
---
artifact: vision-statement
product: [product name]
version: 1.0.0
phase: strategy
created: [date]
owner: product-strategist
---

# Vision Statement

[The vision statement — 1–3 sentences, ≤ 60 words]

## Rationale

**Target user:** [who]
**Unmet need:** [the pain]
**Product category:** [category]
**Key benefit:** [outcome]
**Differentiation:** [constraint]

## North Star Implication

[What single metric, if improved, would signal the vision is being achieved]
```
