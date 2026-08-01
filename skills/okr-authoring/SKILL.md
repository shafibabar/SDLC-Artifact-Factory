---
name: okr-authoring
description: >
  Author OKRs during Strategy — an aspirational qualitative Objective plus 2-5
  measurable Key Results. Apply the outcome-not-output rule (a Key Result
  measures a change in customer or business behavior, never a shipped feature,
  launch, or roadmap item), grade Key Results on a 0.0-1.0 scale with the ~0.7
  aspirational sweet spot, set quarterly cadence with weekly check-ins, and
  cascade/align product OKRs to company Objectives. Reject an output masquerading
  as a Key Result ("launch the onboarding flow", "ship the connector",
  "features shipped: 10"). Sets the measurable goals downstream discovery
  (impact-mapping, story-mapping) traces back to.
version: 2.0.0
phase: strategy
owner: product-strategist
created: 2026-06-24
related: [impact-mapping, story-mapping, vision-statement, roadmap-authoring, methodology-review, glossary-management]
tags: [strategy, okr, objectives, key-results, outcomes, goal-setting]
produces: okr
domain: strategy
status: stable
---

# OKR Authoring

## Purpose

OKRs translate vision and roadmap direction into measurable commitments. They answer: **what are we trying to achieve, and how will we know we achieved it?** OKRs are an alignment mechanism, not a task list and not a performance-review tool.

From the glossary: **OKRs** — a goal-setting framework pairing a qualitative Objective with measurable Key Results, used to align and focus effort at organisational and team levels.

The discipline this skill enforces is Cagan's empowered-team stance (`inspired-cagan`): a team is handed a **Key Result to move — an outcome with a target and a deadline — not a feature list**. A KR-driven team is structurally incapable of being a "feature factory". Lemay (`product-management-in-practice-lemay`) sharpens this: phrase each Key Result as a *falsifiable hypothesis* — "we believe [action] will cause [outcome], measured by [signal]" — not a stated future fact.

---

## Structure

```
Objective  (qualitative, inspiring, time-bound direction)
  ├── Key Result 1  (measurable outcome — behavior change)
  ├── Key Result 2
  └── Key Result 3
      [Initiatives — what we'll do to move the KRs; may change mid-cycle]
```

**Ceiling per cycle:** 3 Objectives, 2-5 Key Results each. More than that is a focus failure, not a scheduling one — "the essence of strategy is saying no" (Cagan).

---

## The Central Discipline: Outcome, Not Output

This is the one rule that most OKR sets get wrong. A Key Result measures **what changed for the customer or the business**, never **what the team shipped**.

| This is an OUTPUT (reject as a KR) | This is an OUTCOME (valid KR) |
|---|---|
| "Launch the improved onboarding flow" | "80% of trial users reach first compliance-gap discovery within 30 min of setup" |
| "Ship the Google Drive connector" | "Median time from connection to full classification ≤ 30 min" |
| "Features shipped: 10" | "Flagged compliance gaps resolved within 5 days rises from 40% to 70%" |

The test: **if the team shipped exactly what the KR names but nothing changed for users, could the KR still be marked done?** If yes, it is an output — rewrite it as the behavior change the output was meant to cause. A shipped-but-abandoned onboarding wizard fails an outcome KR regardless of effort spent; that is the point. This is the same discipline `impact-mapping` enforces ("feature usage is not an impact") and that downstream discovery traces back to.

Outputs are not worthless — they become **Initiatives** (bets on how to move a KR), which live below the KRs and are allowed to change mid-cycle.

Full quality tests for Objectives and Key Results, and the honest-baseline rule: `references/okr-rules-and-grading.md`.

---

## Grading: 0.0-1.0

Key Results are scored continuously, not pass/fail. At cycle end each KR gets a grade from **0.0 to 1.0** (achievement against target), and the Objective's grade is the average of its KRs.

- **~0.7 is the target, not 1.0.** OKRs are set aspirationally: a full set landing near 0.7 means the ambition was calibrated right. Consistently scoring 1.0 means the targets were sandbagged.
- A grade is a **learning signal**, not a verdict on the team — a 0.4 that surfaces a wrong assumption is more useful than a safe 1.0.

What each grading band means (0.0-0.3 / 0.4-0.6 / 0.7-1.0), the sandbagging-vs-moonshot tension, and how to grade a binary KR: `references/okr-rules-and-grading.md`.

---

## Cadence and Alignment

- **Set quarterly**, review with a lightweight **weekly check-in** (update confidence, flag blockers) — set-and-forget is the most common failure mode.
- **Cascade:** every product OKR names the company Objective it supports. For a solo operator (Shafi), product and company OKRs are one set — document them once.
- **Confidence, not just target:** each KR carries a running confidence (start ~70%) that moves week to week and is the earliest signal a KR is off track.

---

## Step-by-Step

1. Read the vision and roadmap. Objectives translate roadmap themes into time-bound aspirations.
2. Draft ≤3 Objectives — qualitative, inspiring, no numbers.
3. For each, draft 2-5 Key Results. For every KR ask: *"If this metric hits this target, is the Objective genuinely accomplished?"* and *"Is this a behavior change or a shipped thing?"*
4. Convert any output-shaped KR into the outcome it was meant to cause; demote the output to an Initiative.
5. Set baselines honestly (see references) and targets at ~70% confidence.
6. Run the health check (below).
7. Name the North Star Metric; confirm it is consistent with the KRs.
8. Link each roadmap item to at least one Key Result so downstream discovery can trace it.

The artifact template and full worked outcome-vs-output examples grounded in this product: `references/okr-template-and-examples.md`.

---

## OKR Health Check

For each Objective, all five must pass — fail any one, revise:

1. Is the Objective qualitative (no numbers)?
2. Would a team member reading it understand why it matters?
3. If all Key Results land, is the Objective genuinely accomplished?
4. Is every Key Result an outcome (behavior change), not an output (task/launch/feature count)?
5. Can every Key Result be measured without asking the team to self-assess?

---

## Anti-Patterns

| Anti-pattern | Why it fails | Fix |
|---|---|---|
| **Output as a KR** | "Launch X" / "ship Y" measures effort, not change | Rewrite as the behavior change; demote the output to an Initiative |
| **Roadmap masquerading as OKRs** | A feature-and-date list handed down as "KRs" makes a feature team (Cagan) | Express each as an outcome to move, not a solution to build |
| **Sandbagging** | Targets guaranteed to hit; grades cluster at 1.0 | Calibrate to ~0.7 aspirational; 100% confidence = too easy |
| **Vanity KR** | Looks good, measures no real value | Tie to a customer/business behavior |
| **Too many OKRs** | 4+ Objectives, 20+ KRs — no focus | Cut ruthlessly to ≤3 / 2-5 |
| **Set and forgotten** | Written, never revisited | Weekly check-in; update confidence |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Objective count | ≤3 per cycle | 4+ |
| KR count | 2-5 per Objective | 1 (under-specified) or 6+ (unfocused) |
| Objective form | Qualitative, time-bound, no numbers | Contains a metric, or is a task list |
| KR fields | Metric, baseline, target, owner, confidence all present | Any missing |
| Outcome orientation | Every KR is a behavior change | Any KR is a task/launch/feature count |
| Ambition | Targets at ~70% confidence, ~0.7 target grade | Sandbagged (1.0) or fantasy (<0.3) |
| North Star Metric | Named, consistent with KRs | Absent or contradicted |
| Health check | All 5 answered per Objective | Skipped or partial |

---

## References

- `references/okr-rules-and-grading.md` — Objective/Key-Result quality tests, honest-baseline rule, the 0.0-1.0 grading method with per-band meaning, quarterly + weekly cadence, sandbagging-vs-moonshot tension.
- `references/okr-template-and-examples.md` — the OKR artifact template plus worked outcome-based examples for this product, each contrasted with its output anti-example.
