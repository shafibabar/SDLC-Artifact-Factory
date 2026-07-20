---
name: stakeholder-mapping
description: >
  Teaches how to identify, categorise, and plan engagement for all stakeholders
  of a product — including users, buyers, influencers, blockers, and internal
  stakeholders. Covers the Power/Interest Grid, stakeholder register format,
  communication strategy per quadrant, and RACI for key decisions. Used by the
  product-strategist agent during the Strategy phase before GTM planning begins.
version: 1.1.0
phase: strategy
owner: product-strategist
created: 2026-06-24
tags: [strategy, stakeholders, communication, product-discovery]
---

# Stakeholder Mapping

## Purpose

Every product affects people beyond its direct users. Decisions made without understanding who holds influence, who is impacted, who can block progress, and who can accelerate it lead to preventable failures — failed launches, missing requirements, adoption resistance, and political obstacles.

Stakeholder mapping surfaces these relationships before they become problems.

---

## Stakeholder Categories

| Category | Definition | Examples |
|---|---|---|
| **Primary users** | People who use the product directly to get a job done | Operations analyst using the dashboard |
| **Buyers / economic decision-makers** | People who authorise purchase and renewal | CTO, VP of Engineering, CFO |
| **Influencers** | People whose opinion affects the buying decision | Security team, Legal/Compliance team |
| **Blockers** | People or roles whose objection can stop adoption | CISO, Data Privacy Officer, IT governance |
| **Beneficiaries** | People who benefit from outcomes without using the product directly | Auditors who receive compliance reports |
| **Internal stakeholders** | People inside your organisation with a stake in the product | Engineering, Sales, Support, Marketing |

---

## The Power/Interest Grid

Plot every stakeholder on two axes:

- **Power axis (vertical):** How much influence does this stakeholder have over product success or failure?
- **Interest axis (horizontal):** How much does this stakeholder care about the product outcomes?

```
High Power  │  Keep Satisfied     │  Manage Closely
            │  (low interest,     │  (high interest,
            │   high power)       │   high power)
            │─────────────────────│──────────────────
Low Power   │  Monitor            │  Keep Informed
            │  (low interest,     │  (high interest,
            │   low power)        │   low power)
            └─────────────────────┴──────────────────
                  Low Interest         High Interest
```

**Engagement strategy by quadrant:**

| Quadrant | Strategy | Frequency |
|---|---|---|
| Manage Closely | Continuous engagement, early input on decisions, regular updates | Weekly or bi-weekly |
| Keep Satisfied | Periodic updates, involve in high-stakes decisions, do not ignore | Monthly |
| Keep Informed | Light-touch updates, newsletters, release notes | Quarterly or at milestones |
| Monitor | Minimal effort, watch for changes in interest or power | As needed |

---

## Step-by-Step Production

1. **List all stakeholders.** Start by listing every person or role who: uses the product, buys the product, approves the budget, can block adoption, is affected by the outcomes, or whose team is impacted.

2. **Classify each.** Assign each to a category from the table above. A stakeholder can belong to more than one category (e.g. a CTO who is both a buyer and an influencer).

3. **Rate power and interest.** Score each stakeholder on Power (1–3: low/medium/high) and Interest (1–3: low/medium/high). Place them on the Power/Interest Grid.

4. **Define engagement needs.** For each stakeholder in "Manage Closely" and "Keep Satisfied," document: what they need to know, what decisions they should be consulted on, how they prefer to receive information.

5. **Identify risks.** Flag stakeholders who are blockers or who have high power and currently low/unknown interest — these are the highest-risk relationships.

6. **Build the stakeholder register.** See `references/stakeholder-register-template.md`.

7. **Define communication plan.** For each quadrant, define how updates are delivered, who is responsible, and at what frequency.

---

## RACI for Key Decisions

For major product decisions, define a RACI matrix:

| Role | Meaning |
|---|---|
| **R — Responsible** | Does the work to make the decision or produce the outcome |
| **A — Accountable** | Owns the decision; single person; cannot be delegated |
| **C — Consulted** | Provides input before the decision is made; two-way dialogue |
| **I — Informed** | Told of the decision after it is made; one-way communication |

Apply RACI to: product direction changes, major architecture decisions, release gates, budget requests, compliance sign-offs.

---

## Worked Example (Grid Placement)

For the first product (Data Estate Mapping and Compliance Intelligence — a private-deployment compliance platform sold into SMBs), a typical customer-side placement:

| Stakeholder | Category | Power | Interest | Quadrant |
|---|---|---|---|---|
| Maya Chen — Compliance Officer | Primary user | 2 | 3 | Keep Informed — cultivate into champion |
| CTO / VP Engineering | Buyer | 3 | 2 | Keep Satisfied |
| IT / DevOps Lead | Influencer + implementer | 2 | 3 | Keep Informed |
| CISO / IT Security | Blocker | 3 | 1 | Keep Satisfied — highest-risk relationship |
| External SOC 2 auditor | Beneficiary | 2 | 1 | Monitor |
| Shafi (product owner) | Internal | 3 | 3 | Manage Closely |

The CISO placement is the decisive one: high power, low current interest — exactly the profile that silently kills deployments. The mitigation belongs in the Blocker Risk Register: a security architecture brief showing zero data egress and mTLS-by-default, delivered *before* the deployment request is raised, not after it is blocked. Note also that the primary user (Maya) starts with less power than either the buyer or the blocker — a product that only satisfies her wins the evaluation and still loses the deal.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Completeness | All six stakeholder categories have at least one named person or role | Only primary users and buyers are listed |
| Blockers identified | At least one potential blocker is named with a mitigation approach | No blockers listed (they always exist) |
| Engagement strategy | Every "Manage Closely" stakeholder has a documented engagement plan | Grid is drawn but no engagement actions defined |
| RACI exists | Key decisions have accountability assigned | Decisions list exists with no ownership |
| Communication plan | Frequency and channel documented per quadrant | "We'll update stakeholders as needed" |

---

## Anti-Patterns

**Users-only map:** listing only the people who touch the product. The stakeholders who kill products — blockers, budget holders, security reviewers — mostly never log in.

**Grid without actions:** drawing the Power/Interest Grid and stopping. The grid is a routing device for engagement effort; a grid with no per-quadrant engagement plan is decoration.

**Static register:** scoring power and interest once. Both shift at every milestone — a CISO's interest jumps from 1 to 3 the day a deployment request lands on their desk. Re-score at each phase gate.

**Blocker denial:** a register with no blockers. Blockers always exist; a map without one means they have not been found yet, which is strictly worse than having them named with a mitigation.

**Shared accountability:** a RACI row with two "A"s. Accountability that is shared is accountability that is absent — every decision has exactly one Accountable person.

---

## Output Format

```markdown
---
name: stakeholder-map
product: [product name]
version: 1.0.0
phase: strategy
created: [date]
owner: product-strategist
---

# Stakeholder Map

## Stakeholder Register

[Table: Name/Role | Category | Power | Interest | Quadrant | Engagement Need]

## Power/Interest Grid

[Grid diagram or table showing quadrant placement for each stakeholder]

## Engagement Plan

[Per-quadrant: communication approach, frequency, responsible party]

## Blocker Risk Register

[Table: Stakeholder | Concern | Risk Level | Mitigation Approach]

## RACI — Key Decisions

[Table: Decision | Responsible | Accountable | Consulted | Informed]
```

See `references/stakeholder-register-template.md` for a filled example.
