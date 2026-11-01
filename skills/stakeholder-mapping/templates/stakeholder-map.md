# Stakeholder Map — Template

Copy the block below to `strategy/stakeholder-map.md` and fill it. Keep the section headings and table headers as written: `../scripts/check-stakeholder-map.py` reads them. Delete the enterprise-only parts at standard. At lean the artifact is skipped (see `../SKILL.md` § Scale).

```markdown
---
name: stakeholder-map
product: [product-slug]
version: 1.0.0
phase: strategy
owner: product-strategist
created: [YYYY-MM-DD]
summary: [one sentence, ≤ 200 chars: who must cooperate to deliver, who decides to buy in the target segment, and the riskiest relationship]
profile: [standard | enterprise]
traces_to: strategy/vision-statement.md
---

# Stakeholder Map

## 1. Delivery Stakeholders

Real people whose cooperation the product needs to be built and launched. Roles, not personal names.

### Register

Scale: High / Low on each axis with a reason [or: scored 1–5, where 3 and above is High].

| Stakeholder | Power | Interest | Quadrant | Salience | Engagement need |
|---|---|---|---|---|---|
| [the product owner] | High — [reason] | High — [reason] | Manage Closely | Definitive | [what they need] |
| [design partners (n companies)] | | | | | |
| [reviewer / approver / internal team] | | | | | |

### Grid

[Four quadrants: Manage Closely (Players) · Keep Satisfied (Context setters) · Keep Informed (Subjects) · Monitor (Crowd). Mark moving stakeholders with →.]

### Engagement Plan

| Stakeholder | What they need from us | Channel | Cadence | Owner (a person) | Re-score trigger |
|---|---|---|---|---|---|
| | | | | | [the urgency event: deadline, incident, audit, request] |

### Pre-wiring Order

Before [the next gate review]: 1. [stakeholder] — [why first] · 2. … · then the group review.

### Influence Links (enterprise)

- [A] → [B]: [how A's view reaches B]

### Decision Rights

Exactly one Accountable per decision, and it is a person. Agents and hooks may be Responsible only. Agree = a formal veto (RAPID).

| Decision | Responsible | Accountable | Agree (veto) | Consulted | Informed |
|---|---|---|---|---|---|
| [product direction changes] | product-strategist agent | The product owner | — | | |
| [release gate] | | | [security / compliance reviewer, if they can block] | | |

## 2. Customer Buying Committee

Hypothesised roles in the target segment, not people. No cadence, channel or newsletter. Every profile is "likely" until design partners confirm it.

### Segment: [segment from the vision]

| Role | Must believe to say yes | Likely objection | Proof that answers it | Likely profile | Loses by staying put | Confirmed by |
|---|---|---|---|---|---|---|
| [economic buyer] | | | | [Mobilizer / Talker / Blocker profile — likely] | | |
| [user / champion] | | | | | | |
| [reviewer: security / finance / legal] | | | | | | |

**Mobilizer hypothesis:** [role] — [why]; tested by [which conversation, with which insight].
**Blocker:** [role] — handled by [the Mobilizer, with which proof].
**Cost of no decision:** [what the status quo costs the organisation; which role it costs nothing].
**Collective-learning plan (enterprise):** [how the committee agrees on the problem before solutions].
**Consensus kit (enterprise):** [one page per role: concern, answer, proof].

[Repeat per segment or tenant type at enterprise. Outside parties with salience: regulator, auditor — class and trigger.]

## 3. Blocker Risk Register

| Stakeholder or role | Half | Concern (their words) | Kind of trust | Risk | Mitigation, delivered before the ask |
|---|---|---|---|---|---|
| | Delivery / Committee | | Security / Automated decisions / Change | High / Medium / Low | [fact; plus a change story for a powerful, unmotivated reader] |

## 4. Re-score Log

| Date | Stakeholder | Change | Trigger |
|---|---|---|---|
```
