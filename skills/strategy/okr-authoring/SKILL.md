---
name: okr-authoring
description: >
  Teaches how to write well-formed OKRs (Objectives and Key Results) — covering
  the structure of good Objectives, the criteria for measurable Key Results,
  cascading from company to product level, OKR health checks, and the most common
  failure modes. Used by the product-strategist agent after roadmap direction is
  established, to define the measurable outcomes the Strategy phase commits to.
version: 1.1.0
phase: strategy
owner: product-strategist
created: 2026-06-24
tags: [strategy, okr, metrics, product-metrics, north-star, outcome-driven]
---

# OKR Authoring

## Purpose

OKRs (Objectives and Key Results) translate the vision and roadmap direction into measurable commitments. They answer: **what are we trying to achieve, and how will we know we achieved it?**

OKRs are not a task list. They are not a performance review tool. They are an alignment mechanism — ensuring that all product, engineering, design, and go-to-market work is pointed at the same outcomes.

From the canonical glossary: **OKRs** — a goal-setting framework that pairs a qualitative Objective with measurable Key Results, used to align and focus effort at organisational and team levels.

---

## Structure

```
Objective
  └── Key Result 1
  └── Key Result 2
  └── Key Result 3
  └── [Optional] Initiatives — what we'll do to achieve the KRs
```

**Maximum per cycle:** 3 Objectives, 3–5 Key Results per Objective.

---

## Writing Good Objectives

An Objective is a qualitative, inspiring, time-bound statement of direction.

| Criterion | Description |
|---|---|
| **Qualitative** | Does not contain numbers. Numbers belong in Key Results. |
| **Inspiring** | A team member reading it understands why it matters. |
| **Time-bound** | Has a defined period (quarterly, half-year, annual). |
| **Outcome-oriented** | Describes a destination, not an activity. |
| **Achievable but ambitious** | Set at ~70% confidence of achievement. 100% confident = not ambitious enough. |

**Good Objective:** "Make it effortless for any SMB to understand their data compliance posture within hours of deploying the product."

**Bad Objective:** "Launch the onboarding improvements and the Google Drive connector." — This is a task list, not an Objective.

**Bad Objective:** "Improve the product." — Not inspiring, not specific, not time-bound.

---

## Writing Good Key Results

A Key Result is a measurable outcome that proves the Objective was achieved.

| Criterion | Test |
|---|---|
| **Measurable** | Can be expressed as a number or a binary (achieved/not achieved) |
| **Outcome-based** | Measures what changed for the user, not what the team did |
| **Owned** | One team or person is accountable for it |
| **Independently verifiable** | Can be checked without asking the team whether they "feel" it was achieved |
| **Not gameable** | Cannot be technically achieved while the spirit of the OKR is missed |

**Good KR:** "80% of trial users reach their first compliance gap discovery within 30 minutes of setup."

**Bad KR:** "Launch the improved onboarding flow." — This is an output (task completed), not an outcome (what changed for users).

**Bad KR:** "Improve user satisfaction." — Unmeasurable without defining the metric and target.

**Bad KR:** "Number of features shipped: 10." — Measures output, not outcome.

---

## Distinguishing Objectives from Key Results from Initiatives

| Term | Type | Contains | Example |
|---|---|---|---|
| **Objective** | Direction | Qualitative aspiration | "Be the most trusted private-deployment data intelligence platform for SMBs" |
| **Key Result** | Measurement | Specific metric + target + time | "NPS > 50 from paying customers by end of Q3" |
| **Initiative** | Action | What we plan to do | "Build automated SOC 2 evidence collection" |

Initiatives are how we plan to hit Key Results. They may change. The Key Results should not change within a cycle unless fundamental assumptions are invalidated.

---

## Cascade and Alignment

Product OKRs must align to company-level OKRs. Each product OKR should answer: "Which company Objective does this support?"

If a product team produces OKRs with no company-level Objective they support, the OKRs are either misaligned or the company-level OKRs are incomplete.

For a solo product (Shafi as sole operator), the product OKRs and company OKRs are the same. Document them as one set.

---

## Step-by-Step Production

1. **Read the vision and roadmap.** The Objectives translate the roadmap themes into time-bound aspirations.

2. **Draft no more than 3 Objectives.** Each should map to a major roadmap theme or a critical business outcome for the period.

3. **For each Objective, draft 3–5 Key Results.** Ask for each one: "If we achieve this metric at this level, is the Objective genuinely accomplished?"

4. **Run the health check** (see below).

5. **Identify the North Star Metric.** From the canonical glossary: the single metric that best captures the core value delivered to customers. It should be derivable from or consistent with the Key Results.

6. **Link each OKR to the roadmap.** Every roadmap item should trace to at least one Key Result.

---

## Worked Example

One Objective for the first product (Data Estate Mapping and Compliance Intelligence), Q3 2026:

**Objective 1 — Prove that an SMB can go from zero to a trustworthy compliance picture in a single session.**

*Roadmap link: Now — "Frictionless Onboarding"*

| Key Result | Metric | Baseline | Target | Owner | Confidence |
|---|---|---|---|---|---|
| KR1.1 | % of trial users who discover their first compliance gap within 30 minutes of connecting a storage source | n/a (pre-launch) | 80% | Shafi | 70% |
| KR1.2 | Median time from Google Drive connection to full sensitivity classification (estates ≤ 100k files) | n/a | ≤ 30 min | Shafi | 60% |
| KR1.3 | % of design-partner deployments completed without any support contact | n/a | 3 of 3 | Shafi | 70% |

**Why this passes:** the Objective is qualitative and time-bound; if all three KRs land, "zero to trustworthy compliance picture in one session" is genuinely accomplished; every KR is measurable from product telemetry with no self-assessment; and none can be gamed without actually delivering the onboarding outcome (shipping an onboarding wizard that users abandon fails KR1.1 regardless of effort spent).

---

## OKR Health Check

For each Objective, answer all five questions. Fail on any one = revise.

1. Is this Objective qualitative (no numbers)?
2. Would a team member reading this understand why it matters?
3. If we achieve all Key Results, does the Objective feel genuinely accomplished?
4. Are all Key Results outcome-based (not task lists)?
5. Can every Key Result be measured without asking the team to self-assess?

---

## Common Failure Modes

| Failure | Description | Fix |
|---|---|---|
| **KRs are tasks** | "Launch feature X", "Hire 2 engineers" | Replace with the outcome the task is meant to produce |
| **Too many OKRs** | 6+ Objectives, 20+ KRs | Ruthlessly cut to 3 Objectives, 3–5 KRs each |
| **Sandbagging** | KRs set so low they are guaranteed | Set targets at ~70% confidence; 100% = too easy |
| **Vanity KRs** | Metrics that look good but do not measure value | Replace with metrics directly tied to user outcomes |
| **No accountability** | No owner assigned to each KR | Every KR has exactly one accountable owner |
| **Set and forgotten** | OKRs written but never reviewed | Schedule monthly check-ins; update confidence scores |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Objective count | ≤ 3 per cycle | 4 or more Objectives |
| KR count | 3–5 per Objective | 1–2 KRs (under-specified) or 6+ (unfocused) |
| Objective form | Qualitative, time-bound, no numbers | Contains a metric, or is a task list |
| KR form | Every KR has metric, baseline, target, owner, and confidence | Any of the five fields missing |
| Outcome orientation | Every KR measures a change for users or the business | Any KR that is a task, launch, or feature count |
| Ambition | Targets set at ~70% confidence | Targets at 100% confidence (sandbagged) or below 30% (fantasy) |
| North Star Metric | Named, and consistent with the Key Results | Absent, or contradicted by the KRs |
| Health check | All 5 questions answered for every Objective | Health check skipped or partially applied |

---

## Output Format

```markdown
---
name: okr-set
product: [product name]
cycle: [Q3 2026 / H2 2026 / Annual 2026]
version: 1.0.0
phase: strategy
created: [date]
owner: product-strategist
north-star-metric: [single metric]
---

# OKRs — [Cycle]

## North Star Metric

[Single metric that best captures core value delivered]
Current baseline: [value] | Target: [value] | By: [date]

---

## Objective 1 — [Qualitative statement]

*Roadmap link: [Now/Q3 theme name]*

| Key Result | Metric | Baseline | Target | Owner | Confidence |
|---|---|---|---|---|---|
| KR1.1 | | | | | |
| KR1.2 | | | | | |
| KR1.3 | | | | | |

**Initiatives (how we plan to achieve this):**
- [Initiative 1]
- [Initiative 2]

---

## Objective 2 — [Qualitative statement]
[Repeat structure]

## Objective 3 — [Qualitative statement]
[Repeat structure]

---

## OKR Health Check

[Checklist: all 5 health check questions answered for each Objective]
```
