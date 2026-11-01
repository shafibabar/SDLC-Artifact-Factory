---
name: okr-authoring
description: >
  Teaches how to write, review and grade an OKR set during Strategy: Objectives
  that are proximate objectives implied by the strategy kernel's guiding policy,
  each labelled committed or aspirational, with 2-5 outcome Key Results (a change
  in customer or business behaviour, never a shipped feature, launch or roadmap
  item). Covers grading committed KRs against 1.0 and aspirational ones against
  about 0.7, keeping weekly confidence separate from the grade, health metrics,
  a weekly check-in log for a solo product owner, sizing by scale profile, and
  aligning (never cascading) team OKRs to company ones. Use when writing OKRs,
  rejecting an output posing as a Key Result, grading a quarter, or checking
  what the OKR step reads. Used by the product-strategist agent after the
  strategy kernel and before the roadmap; impact-mapping and story-mapping trace
  back to its Key Results.
version: 3.0.0
phase: strategy
owner: product-strategist
created: 2026-06-24
tags: [strategy, okr, objectives, key-results, outcomes, goal-setting]
produces: okr
domain: strategy
status: stable
related: [strategy-kernel, vision-statement, roadmap-authoring, impact-mapping, story-mapping, methodology-review, glossary-management]
sources:
  - research/product-strategy-and-gtm/measure-what-matters-doerr.md
  - research/product-strategy-and-gtm/good-strategy-bad-strategy-rumelt.md
  - research/product-strategy-and-gtm/inspired-cagan.md
  - research/product-strategy-and-gtm/product-management-in-practice-lemay.md
  - research/data-and-analytics/lean-analytics-croll-yoskovitz.md
---

# OKR Authoring

## Purpose

An OKR set answers two questions for one cycle: **what will we achieve next, and how will we know we got there?** The method is Andy Grove's, from Intel, and John Doerr's account of it at Google (*Measure What Matters*): an **Objective** is what is to be achieved; its **Key Results** show, with numbers, whether it was. An Objective with no Key Results is a wish.

OKRs are not a strategy. Rumelt (*Good Strategy / Bad Strategy*) names "goals mistaken for strategy" as a hallmark of bad strategy: targets with no theory of how the obstacle is overcome. In this plugin the strategy lives in the **strategy kernel** (`strategy-kernel`), and the OKR set sits under it:

```
Vision ──► Strategy kernel ──► OKR set ──► Roadmap
(North Star)  (crux, guiding      (proximate      (Initiatives that move
               policy, actions)    objectives+KRs)  the KRs, sequenced)
```

**Inputs: the vision and the strategy kernel, never the roadmap.** The roadmap is written *after* this set and sequences bets on how to move its Key Results. The one feedback loop runs upward: if the roadmap step finds no plausible Initiative could move a KR, that KR goes back here for recalibration. It is a check, not an input.

**The vision owns the North Star Metric.** Name it as the vision states it and say which part of it each Objective moves. Never define a second one here.

---

## Objectives come from the kernel

Each Objective is the next **proximate objective** the guiding policy implies (Rumelt): close enough to reach this cycle with the means at hand, and clear enough that the team knows what to do on Monday. Start from the kernel's "Proximate Objectives" hand-off list and turn each into an Objective; do not invent Objectives the policy does not imply.

Two tests every Objective must pass, before any Key Result is drafted:
- **Proximate.** Reachable this cycle, and it removes ambiguity. "Become the trusted leader in X" is **blue-sky**: an end state with no feasible next step.
- **Serves the one guiding policy.** All Objectives in the set follow from the same policy. Three Objectives, one per function, each sensible, still make a **dog's dinner** if no common policy links them.

Stretch belongs in the **Key Result targets**, not in a blue-sky Objective. That is how Doerr's aspirational OKRs and Rumelt's warning fit together.

**Focus is a choice.** Grove's claim is that the system's main value is focus: a few Objectives, chosen by saying no to everything else. Rumelt puts it as "strategy requires choice"; the line "the essence of strategy is saying no" is usually traced to Michael Porter's "What Is Strategy?" (1996). An Objective is worth writing only if another direction was genuinely possible.

---

## Committed or aspirational: label every Objective

Google's guidance, as Doerr reproduces it, splits OKRs into two types, and **not telling them apart is a classic OKR mistake**. Label each Objective with its type when it is written.

| | **Committed** | **Aspirational** (stretch) |
|---|---|---|
| Meaning | Will be delivered; others rely on it | A world we want, without yet knowing the full path |
| Typical cases | Certifications, contractual dates, compliance deadlines, a promise made to customers | Growth, adoption, behaviour change the team has not achieved before |
| Expected grade | **1.0** | **About 0.6–0.7** on average |
| A miss means | A failure that needs a written explanation and a recovery plan | Normal; 0.7 is a win. Constant 1.0 means the targets were timid |
| Starting confidence | **≥ 90%** | **About 50%** (Wodtke's 5 out of 10) |

**Confidence is not the grade.** Confidence is a *forecast*, updated weekly, of the chance the KR hits its target in full. The grade is a *measurement* taken once, at the end. Never derive one from the other: an aspirational KR set at 50% confidence is expected to grade around 0.7, and a committed KR at 90% is expected to grade 1.0. Writing "70% confidence" as if it meant "expect 0.7" is the conflation this skill exists to stop.

Grading bands, the interpolation convention, binary KRs and how to grade a missed committed KR: read `./references/okr-rules-and-grading.md` when grading, or when a KR is pass/fail.

---

## The central discipline: a KR is an outcome, never an output

A Key Result measures **what changed for the customer or the business**, never **what the team shipped**. This rule is Cagan's (*Inspired*), not Doerr's: Grove and Doerr allowed measurable milestones as KRs. Cagan makes it the line between an empowered team, handed a Key Result to move, and a "feature factory", handed a feature list to ship. The plugin takes Cagan's stricter stance on purpose.

The test: **if the team shipped exactly what the KR names and nothing changed for users, could the KR still be marked done?** If yes, it is an output. Rewrite it as the behaviour change the output was meant to cause, and demote the output to an **Initiative**: a bet on how to move the KR, which may change mid-cycle while the KR stays fixed. Initiatives are what the roadmap later sequences.

A good KR metric also passes Croll and Yoskovitz's four tests (*Lean Analytics*): comparative, understandable, a ratio or rate, and it changes what you would do. LeMay's hypothesis-driven stance (*Product Management in Practice*) suggests stating each KR's bet as something evidence could disprove; the template's "We believe [Initiative] will move [KR]" line is this plugin's phrasing of it.

---

## Health metrics and the weekly check-in

**Health metrics** (Wodtke, *Radical Focus*, as summarised in the Doerr research file) are 2–4 signals the set is *not* trying to improve but must not break while chasing it: reliability, support load, customer satisfaction, the operator's own hours. They are Grove's paired indicators made explicit; pair any volume or speed KR with one. Each is shown green / yellow / red at every check-in.

**The weekly check-in** follows Wodtke's four-square: this week's priorities, each KR's current confidence, the next few weeks, and the health metrics. For a solo product owner there is no meeting to hold it in, so it is a **dated log appended to the OKR artifact**: one line per KR with its confidence and a note. The product owner, or the product-strategist agent in a later session, reads the trend from the file. Confidence that falls from 50% to 20% by week five is the signal to change Initiatives now, not at quarter-end.

---

## Scale

Size follows the profile in `phase-requirements.json` (lean: one Objective). The disciplines never change.

| Profile | Shape |
|---|---|
| **lean** | **One Objective with about three KRs** (Wodtke's "one OKR"), usually aspirational; 1–2 health metrics; a short check-in log. Pre-launch baselines are written `n/a (pre-launch)` |
| **standard** | Up to **three** Objectives, 2–5 KRs each, each labelled committed or aspirational, all serving the one guiding policy; 2–4 health metrics |
| **enterprise** | **3–5 Objectives per level** (company, each product line; a team below a line may hold fewer), **aligned, not cascaded**: each lower-level Objective names the higher one it advances, writes its own KRs, and records a sideways dependency check with the teams it relies on. An optional annual layer gives quarterly sets their context |

**Alignment, not cascade.** Doerr warns against strict top-down cascading, where each level copies the level above and narrows the numbers. It is slow, turns every level into a translation exercise, and stops ideas coming from the front line. A team KR that is the parent's KR with a smaller target is a cascade defect.

---

## How to Write One

1. **Read the inputs**: the vision (its North Star and protagonist) and the strategy kernel (its crux, guiding policy and Proximate Objectives hand-off). If no kernel exists yet, stop: write the kernel first (`strategy-kernel`). Never read the roadmap.
2. **Draft the Objectives** from the kernel's proximate objectives, sized to the profile. Qualitative, no numbers. Run the proximate and one-policy tests.
3. **Label each** committed or aspirational, and note which part of the North Star it moves.
4. **Draft 2–5 KRs per Objective** (about three at lean). Convert every output to an outcome and demote the output to an Initiative.
5. **Set baselines honestly**: measured; `n/a (pre-launch)`; or, for a live product not yet measured, `not yet measured — first reading by <date>` with a provisional target. Then targets and direction; set starting confidence by type (aspirational ~50%, committed ≥90%).
6. **List candidate Initiatives per KR** for the roadmap to sequence, and name the health metrics.
7. **Validate** with `./resources/okr-health-check.md` before hand-off; every row is a hard stop.
8. **Produce the artifact** from `./templates/okr-set-template.md` at `strategy/okrs.md`, with an empty check-in log and grading table to fill later.

**Examples, simple to complex:**
- A lean internal tool, one Objective and three KRs, pre-launch baselines: read `./examples/01-lean-single-okr.md`.
- A standard B2B SaaS quarter with one committed and two aspirational Objectives, graded at quarter-end: read `./examples/02-standard-committed-and-aspirational.md`.
- An enterprise multi-tenant platform, company → product line → team, aligned rather than cascaded, with the cascade draft it replaced: read `./examples/03-enterprise-alignment.md`.

---

## Anti-Patterns

| Anti-pattern | Example | Fix |
|---|---|---|
| **Goals as strategy** (Rumelt) | An OKR set written with no kernel above it | Write the kernel first; Objectives come from its guiding policy |
| **Dog's dinner** (Rumelt) | Three Objectives, one per function, no common policy | Cut to Objectives the one policy implies |
| **Blue-sky Objective** (Rumelt) | "Become the leading platform for X" | Replace with the next proximate objective |
| **Business as usual** (Google) | "Keep the service running" | Work that would happen anyway is not an Objective; make it a health metric |
| **"Who cares?"** (Google) | An internal Objective nobody outside the team would notice | Rewrite around a customer or business change, or drop it |
| **Unlabelled type** (Google) | A SOC 2 deadline graded 0.7 and called a success | Label committed; grade against 1.0 |
| **Confidence equals grade** | "70% confidence, so expect 0.7" | Separate forecast from measurement; set confidence by type |
| **Output as a KR** (Cagan) | "Launch the onboarding flow" | Rewrite as the behaviour change; demote to an Initiative |
| **Roadmap as OKRs** (Cagan) | A feature-and-date list relabelled "KRs" | Outcomes to move, not solutions to build |
| **Cascade** (Doerr) | Team KR = parent KR with a smaller number | Align by reference; the team writes its own KR |
| **Second North Star** | A new North Star section with its own target | Use the vision's; say what this cycle moves |
| **Sandbagging / set and forgotten** | Every grade 1.0; no check-in since week one | Recalibrate; keep the weekly log |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Inputs | Traces to the vision and the strategy kernel | Reads the roadmap, or no kernel exists |
| Size | Matches the Scale table (lean: one Objective) | Lean with three Objectives; enterprise copied down |
| Objectives | Qualitative, proximate, all from one guiding policy | Numbers inside; blue-sky; dog's dinner |
| Type | Every Objective labelled committed or aspirational | Unlabelled |
| KRs | 2–5 per Objective, each an outcome with metric, baseline, target, direction, owner, starting confidence | Any output KR or missing field |
| Confidence vs grade | Confidence set by type and logged weekly; grade expected by type | One 0.7 rule for everything |
| North Star | The vision's, named once, with what this cycle moves | Redefined or absent |
| Health metrics | 2–4 named (1–2 at lean) | None |
| Alignment | Enterprise Objectives name the Objective they advance; no copied KRs | Strict cascade |

Use the canonical terms from `glossary-management`: **OKRs**, **Committed OKR**, **Aspirational OKR**, **Proximate Objective**, **Health Metric**, **Initiative**, **North Star Metric**, **Strategy Kernel**, **Guiding Policy**.
