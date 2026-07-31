# OKR Rules and Grading

Reference material for `okr-authoring`. Covers the quality tests for Objectives and Key Results, the honest-baseline rule, the 0.0-1.0 grading method with what each band means, cadence, and the sandbagging-vs-moonshot tension. Grading conventions here follow the widely-taught Google/Doerr OKR practice (John Doerr, *Measure What Matters*); the outcome-over-output discipline follows Marty Cagan (*Inspired* / *Empowered*, `inspired-cagan`) and Matt LeMay's hypothesis framing (*Product Management in Practice*, `product-management-in-practice-lemay`).

---

## 1. Writing a good Objective

An Objective is a **qualitative, inspiring, time-bound statement of direction**. It is where you are trying to go, not how far or by when in numbers.

| Test | Pass | Fail |
|---|---|---|
| **Qualitative** | No numbers appear in it | A metric or target is embedded ("reach 500 users") |
| **Inspiring** | Someone reading it understands *why it matters* without a footnote | Flat, internal, jargon-only ("improve the funnel") |
| **Time-bound** | Scoped to a named cycle (a quarter, a half) | Open-ended, could apply to any period |
| **Outcome-oriented** | Names a destination — a state of the world | Names an activity or a deliverable ("launch v2") |
| **Ambitious but real** | Set at ~70% confidence; a genuine stretch | Either a sure thing, or pure fantasy |

**Good:** "Make it effortless for any SMB to understand their data-compliance posture within hours of deploying the product."

**Bad — task list:** "Launch onboarding improvements and the Google Drive connector."

**Bad — vague:** "Improve the product." (not inspiring, not specific, not time-bound)

A useful sharpening from LeMay: an Objective is worth writing only if a reasonable person could have chosen a *different* direction for the same cycle. If no alternative direction was ever on the table, the Objective is describing inevitable work, not a strategic bet.

---

## 2. Writing a good Key Result

A Key Result is a **measurable outcome that proves the Objective was reached**. Five tests, all must pass:

| Test | What it means | Rejected example → repaired |
|---|---|---|
| **Measurable** | Expressible as a number or a clean binary | "Improve satisfaction" → "CSAT from paying customers rises from 3.9 to 4.4" |
| **Outcome-based** | Measures a change in customer/business *behavior*, not team activity | "Ship the connector" → "60% of new accounts connect a second source within 14 days" |
| **Owned** | Exactly one accountable person/team | (unowned) → "Owner: Shafi" |
| **Independently verifiable** | Checkable from data, without the team's self-assessment | "Team feels onboarding is smoother" → "Median setup time drops below 30 min (from telemetry)" |
| **Not gameable** | Cannot be technically hit while the Objective's spirit is missed | "10 features shipped" → tie the count to the behavior those features were meant to produce |

### The outcome-not-output test, stated as one question

> *If the team delivered exactly what this KR names, but nothing changed for the customer or the business, could the KR still be marked complete?*

If **yes**, it is an **output** — reject it. Rewrite it as the behavior change the output was meant to cause, and demote the original wording to an **Initiative** (a bet on *how* to move the KR).

Worked rejections:

- ❌ "Launch the improved onboarding flow" — a wizard nobody finishes still counts as launched. → ✅ "80% of trial users reach their first compliance-gap discovery within 30 minutes of connecting a source."
- ❌ "Ship the Google Drive connector" — shippable and ignorable. → ✅ "Median time from Google Drive connection to full sensitivity classification (estates ≤ 100k files) ≤ 30 minutes."
- ❌ "Publish 12 blog posts" → ✅ "Organic trial signups rise from 20/week to 60/week."
- ❌ "Number of features shipped: 10" — pure output count. → ✅ "Weekly active compliance officers rise from 40 to 120."

This is the same rule `impact-mapping` applies at the deliverable level ("feature usage is not an impact") and that Cagan names as the difference between an empowered team (given a KR to move) and a feature factory (given a feature list to ship).

---

## 3. The honest-baseline rule

Every KR needs a **baseline** — the current value of the metric before the cycle starts — not just a target. A target without a baseline is uninterpretable: "reach 70%" means nothing if today is 68% (trivial) or 10% (a moonshot).

Rules for baselines:

1. **Measure, don't guess.** Pull the baseline from real telemetry, analytics, or a prior period. If it genuinely cannot be measured yet (pre-launch), write `n/a (pre-launch)` explicitly rather than inventing a number.
2. **A pre-launch KR is a first-run target, graded honestly.** For a brand-new metric, the "baseline" is 0 or unknown and the target is a first hypothesis. Grade it against the target you set, and treat a low grade as calibration data for next cycle, not as failure.
3. **Never move the baseline mid-cycle to flatter the grade.** If the baseline was wrong, note the correction openly; do not silently re-anchor.
4. **Direction must be explicit.** State whether higher or lower is better ("median setup time ≤ 30 min" vs "activation rate ≥ 80%") so the grade is unambiguous.

Baseline + target + direction together make a KR *falsifiable* — LeMay's test that a Key Result is a real hypothesis, not a restatement of intent.

---

## 4. Grading on the 0.0-1.0 scale

At the end of the cycle each KR is graded from **0.0 to 1.0** as its achievement against target, using linear interpolation between baseline and target:

```
grade = (final_value − baseline) / (target − baseline)   [clamped to 0.0-1.0]
```

The **Objective's grade is the simple average of its Key Results' grades.** (If some KRs matter more, a weighted average is acceptable, but keep the weighting decided *before* the cycle, never after the numbers land.)

### What each band means

| Band | Meaning | What to do about it |
|---|---|---|
| **0.7 – 1.0** (green) | On or near target. For an aspirational OKR, **0.7 is a win, not a shortfall.** | Bank the learning; if consistently 1.0, the targets were too safe — raise ambition next cycle. |
| **0.4 – 0.6** (amber) | Real progress, target missed. The most *informative* band. | Diagnose: was the target wrong, the bet wrong, or the execution short? Feed the answer into next cycle. |
| **0.0 – 0.3** (red) | Little to no movement. | Treat as a strong signal the assumption behind the KR was false — this is valuable, not shameful, if surfaced honestly. |

### The 0.7 aspirational sweet spot

OKRs are deliberately set so that a strong team lands a **full set around 0.7 on average**. This is the calibration signal:

- A team that consistently scores **1.0** is **sandbagging** — targets were guaranteed, so the OKRs did no work directing effort.
- A team that consistently scores near **0.0** set **fantasy** targets disconnected from any plausible path.
- A team landing around **0.7** calibrated its ambition correctly: genuine stretch, genuine reach.

### Binary Key Results

Some KRs are inherently pass/fail ("achieve SOC 2 Type II certification"). Grade these **1.0 if achieved, 0.0 if not** — no partial credit for effort. Use binary KRs sparingly; a set made entirely of binaries loses the calibration signal the continuous scale provides. Where a "binary" hides a spectrum ("3 of 3 design partners deployed without support contact"), express it as the fraction (2/3 = 0.67) instead.

---

## 5. The sandbagging-vs-moonshot tension

The hardest judgment in OKR authoring is calibrating ambition. Two failure modes pull in opposite directions:

| | **Sandbagging** | **Moonshot / fantasy** |
|---|---|---|
| **Symptom** | Targets you're ~100% sure to hit | Targets with no plausible path |
| **Grade signature** | Clusters at 1.0 every cycle | Clusters near 0.0 every cycle |
| **Root cause** | OKRs treated as commitments to be safely met (often when tied to reward) | Ambition performed for show; no theory of how to get there |
| **Damage** | OKRs stop directing effort — everything was already going to happen | Team demoralized; grades become noise, ignored |
| **Fix** | Set to ~70% confidence; a KR you're sure of is not a KR | Anchor every target to a baseline and a plausible mechanism (an Initiative that could move it) |

Resolving the tension: set each target at the level where your honest confidence of hitting it is about **70%**. Not 90% (sandbagged), not 20% (fantasy). The confidence figure is itself tracked (see cadence below) and is the earliest warning that a target was mis-calibrated.

**Decoupling from performance review.** Sandbagging is worst when OKR grades feed compensation or ratings — people rationally lowball. Keep OKR grading a *learning* instrument, explicitly separate from performance evaluation. In this repo's solo-operator context (Shafi grades his own OKRs) there is no reward-gaming incentive, so the discipline reduces to intellectual honesty: set targets you're genuinely ~70% confident of, and read a 0.5 as information, not as a bad mark.

---

## 6. Cadence — quarterly set, weekly check-in

| Rhythm | What happens |
|---|---|
| **Quarterly (set)** | Author the OKR set for the cycle: ≤3 Objectives, 2-5 KRs each, baselines and ~70%-confidence targets, North Star Metric named, roadmap items linked. |
| **Weekly (check-in)** | Lightweight — update each KR's running **confidence** (a % that moves week to week), flag blockers, note early metric movement. No re-writing of KRs. 15 minutes, not a status theatre. |
| **Quarter-end (grade & retro)** | Grade every KR 0.0-1.0, average to the Objective, write a one-line "what we learned" per Objective, carry the learning into next quarter's set. |

**Confidence is the leading indicator; the grade is the lagging one.** A KR whose confidence has drifted from 70% to 30% by week 5 is telling you to act *now* — reallocate Initiatives, or accept and document the miss — long before the end-of-quarter grade confirms it.

**Do not change Key Results mid-cycle** except when a foundational assumption is invalidated (e.g., the market moved, the metric was found to be measuring the wrong thing). Initiatives, by contrast, are *expected* to change as the team learns what actually moves a KR. Keeping the KR fixed while the Initiatives flex is what makes the KR a real target rather than a moving goalpost.

---

## 7. Cascade and alignment

- Every **product** OKR names the **company** Objective it serves. A product OKR that supports no company Objective is either misaligned or evidence the company OKRs are incomplete.
- Alignment is by **reference, not literal copy** — a product KR need not restate a company KR; it must show how moving it advances a company Objective.
- **Solo operator:** for Shafi as sole operator, product and company OKRs collapse into one set — document them once, and note explicitly that the two levels are unified so the "which company Objective?" check is satisfied by design.

---

## 8. Common failure modes (diagnostic table)

| Failure | Tell | Fix |
|---|---|---|
| KRs are tasks/outputs | "Launch X", "hire 2", "ship Y" | Rewrite as the outcome; demote wording to an Initiative |
| Too many OKRs | 4+ Objectives, 20+ KRs | Cut to ≤3 / 2-5; unfocused OKRs move nothing |
| Sandbagging | Grades cluster at 1.0 | Recalibrate to ~70% confidence |
| Moonshot noise | Grades cluster at 0.0 | Anchor targets to baseline + a plausible mechanism |
| Vanity KR | Looks impressive, tracks no real value | Tie to a customer/business behavior |
| Missing baseline | Target with no "from" value | Measure the current value or mark `n/a (pre-launch)` |
| No owner | KR with nobody accountable | Assign exactly one owner |
| Set and forgotten | Written once, never reviewed | Weekly confidence check-in |
| Roadmap-as-OKRs | A feature-and-date list relabeled "KRs" | Express each as an outcome to move (Cagan) |
