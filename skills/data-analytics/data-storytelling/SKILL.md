---
name: data-storytelling
description: >
  Teaches how to turn analysis into a narrative stakeholders act on — the context,
  insight, recommendation, call-to-action structure, a chart-choice-to-message
  mapping table that avoids chart-first thinking, and an integrity checklist against
  manipulative presentation (truncated axes, cherry-picked windows, misleading
  aggregation). Applies to any analysis presented to a stakeholder, from a one-off
  finding to a recurring metrics review. Used by the data-engineer during Data.
version: 1.0.0
phase: data
owner: data-engineer
created: 2026-07-20
tags: [data, analytics, storytelling, narrative, charts, integrity, presentation]
---

# Data Storytelling

## Purpose

A correct analysis that nobody acts on has failed just as completely as a wrong one. Data storytelling is the discipline of presenting analysis so that the person receiving it understands what happened, why it matters, and what to do about it — without requiring them to be a data professional themselves. It is the last mile between "the number is right" and "the number changed a decision."

This is distinct from `dashboard-specification` and `reporting-spec`, which define what data a dashboard or report contains on an ongoing basis. Data storytelling is about a specific act of communication — presenting a finding, a trend, or an anomaly to a specific stakeholder at a specific moment, usually outside the standing dashboard.

---

## The Narrative Structure: Context → Insight → Recommendation → Call to Action

Every data story follows this shape. Skipping a step produces a story that is technically complete but does not move anyone.

| Step | Answers | Failure mode when skipped |
|---|---|---|
| **Context** | What was the situation before this analysis? What did we expect? | Listener has no baseline to judge the finding against |
| **Insight** | What did the data actually show, stated as a finding, not a chart description | "Here's a chart" instead of "here's what the chart means" |
| **Recommendation** | What should change, specifically, based on the insight | Insight presented with no implied action — interesting, not useful |
| **Call to action** | Who does what, by when | Recommendation floats without an owner or deadline and dies in the meeting |

```
Context:        Extraction confidence for PDF sources has historically
                 averaged 0.91.

Insight:         Over the last two weeks, PDF extraction confidence
                 dropped to 0.74 — specifically for scanned (image-based)
                 PDFs, which now make up 30% of newly discovered assets,
                 up from 8% a month ago.

Recommendation:  The extraction pipeline's OCR fallback path needs
                 tuning before this becomes a customer-visible accuracy
                 problem — low-confidence assets are currently routed
                 to manual review, and that queue is growing faster
                 than stewards can clear it.

Call to action:  data-engineer to profile OCR fallback accuracy this
                 week; if the fix isn't fast, raise the confidence
                 threshold that triggers manual review so the queue
                 doesn't silently back up further.
```

Without the context, "0.74" means nothing. Without the recommendation, the insight is trivia. Without the call to action, it is trivia with a shrug attached.

---

## Chart-Choice-to-Message Mapping

Chart-first thinking — picking a chart type because it looks sophisticated, then finding data to put in it — produces charts that obscure the message. Choose the chart from the message, not the other way around.

| The message you need to land | Chart | Avoid |
|---|---|---|
| "X changed over time" | Line or area chart | A bar chart per time period (obscures the trend shape) |
| "X is made of these parts" | Stacked bar (or a simple list of numbers if precision matters more than shape) | Pie chart with more than 3–4 slices — angle comparison is a weak perceptual task |
| "X compares across categories" | Horizontal or vertical bar, sorted by value | Radar/spider chart — multi-axis comparison is hard to read accurately |
| "X correlates with Y" | Scatter plot | A dual-axis line chart with mismatched scales, which fabricates a visual correlation |
| "X is one number, in context" | A single stat with explicit baseline/target, not a chart at all | A gauge/speedometer chart — visually heavy for one number |
| "Here is the exact distribution" | Histogram or box plot | A single averaged bar that hides the spread |

The test for every chart choice: **could someone unfamiliar with the underlying query state the message correctly just from looking at it, in under five seconds?** If not, either the chart type is wrong for the message, or there is no clear single message yet — go back to the insight step.

(`react-dashboard-components` restates a condensed version of this table for the specific case of building dashboard chart components in React; this skill covers the broader discipline of any presented analysis, including one-off narratives that never become a permanent dashboard widget.)

---

## Integrity: Avoiding Manipulation

A data story that persuades through distortion rather than through the honest shape of the data is a defect, whether or not the distortion was intentional. Check every story against this list before presenting it:

| Manipulation pattern | What it does | Fix |
|---|---|---|
| **Truncated y-axis** | Starts the axis above zero, exaggerating the visual size of a small change | Start bar-chart axes at zero; for line charts where zero is genuinely uninformative (e.g., a metric that only ranges 90–99%), label the axis start explicitly and say so in the narration |
| **Cherry-picked window** | Choosing a start/end date that makes a trend look better or worse than the fuller history | Show enough history to reveal whether the current window is representative; state why this window was chosen |
| **Denominator hiding** | Presenting a count without the base it's drawn from ("500 gaps closed!" without saying out of how many) | Always pair a count with its rate or its total when the total changes the interpretation |
| **Cause implied from correlation** | Two lines moving together, presented as if one caused the other, with no causal mechanism stated | State the mechanism, or explicitly flag "correlated, cause not established" |
| **Silent aggregation that hides a bad segment** | An improving average that masks one severely worsening subgroup (the disaggregation check from `analytics-requirements`) | Show the breakdown, not just the aggregate, whenever a subgroup could plausibly diverge |
| **Precision theater** | Reporting "94.37%" from a small sample to imply a rigor the data doesn't support | Round to the precision the sample size actually supports; state the sample size |
| **Favorable comparison period** | Comparing against the worst prior period to make current performance look better by contrast | Use a consistent, pre-agreed comparison period (same period last cycle), not the most flattering one available |

None of these require intent to be harmful — a truncated axis chosen because "it made the chart look cleaner" still misleads the reader about magnitude. The check applies regardless of motive.

---

## Worked Example — Extraction-Confidence Trend, Presented to Shafi

A data-engineer notices extraction confidence has been declining and needs to brief Shafi (the sole operator, reviewing the finding without IDE tooling — CLAUDE.md's reviewability standard applies to narrative artifacts too).

**Draft 1 (chart-first, fails the integrity check):**

> Here's a line chart of extraction confidence over the last 5 days, axis starting at 0.70. [Chart shows a steep-looking drop from 0.78 to 0.74.]

This fails on three counts: the window is too short to show whether this is a blip or a trend (cherry-picked window), the axis is truncated to exaggerate the visual drop, and there's no context, recommendation, or call to action — it's a chart, not a story.

**Draft 2 (applies the full discipline):**

```
Context:  Extraction confidence across all sources has held at
          0.89–0.92 for the last quarter — stable and above our
          0.85 manual-review threshold.

Insight:  Over the last 5 days specifically, confidence for PDF
          sources dropped to 0.74, driven by a new customer whose
          estate is 80% scanned (image-based) PDFs — a source type
          our OCR fallback handles worse than native-text PDFs.
          [Chart: 90-day line, y-axis 0–1, annotated at the point
          the new customer's estate started ingesting, so the
          viewer sees this is a step change tied to a specific
          cause, not gradual drift.]

Recommendation:  This isn't a general regression — it's a known gap
          in OCR handling that this customer's mix exposed sooner
          than expected. Two options: (a) tune the OCR fallback
          before it affects more scanned-PDF-heavy customers, or
          (b) temporarily lower the auto-classification confidence
          threshold for this source type so more of it routes to
          manual review instead of silently degrading trust.

Call to action:  data-engineer to scope OCR tuning effort this week;
          if it's more than 2 days of work, apply option (b) as an
          interim measure today so no low-confidence extraction is
          silently auto-classified in the meantime.
```

The second version gives Shafi (a PM, not a programmer, per CLAUDE.md) everything needed to make the call without needing to query the pipeline himself: what's normal, what changed, why, and what the options are.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Full narrative structure | Context, insight, recommendation, and call to action all present | Any step missing — especially a chart with no stated recommendation |
| Chart matches message | Chart type chosen from the mapping table for the specific message | Chart type chosen for visual variety or sophistication |
| Five-second readability | An unfamiliar viewer can state the message from the chart alone | Chart requires narration to be understood at all |
| Integrity checklist applied | Every pattern in the manipulation table checked and cleared | Any pattern present without an explicit justification |
| Denominator shown | Any count paired with its base when the base matters | Bare counts presented as if self-evidently good/bad |
| Disaggregation checked | Subgroup behaviour shown when it could diverge from the aggregate | An improving average masking a worsening segment |
| Actionable owner and deadline | Call to action names who and by when | Recommendation with no named owner |

---

## Anti-Patterns

- **Chart-first construction.** Picking an impressive-looking chart type, then reverse-engineering which data fits it. The message determines the chart, never the other way around.
- **The insight-free chart dump.** Presenting a chart and letting the audience infer the point. "Here's the data" is not a data story — state the insight in words, explicitly.
- **Truncated axes for drama.** Starting a bar chart's y-axis above zero to make a modest change look dramatic. This is the single most common integrity violation and the easiest to catch — check every axis start before presenting.
- **The cherry-picked window.** Choosing exactly the date range that supports the pre-decided conclusion. If the window choice needs justifying to someone who hasn't seen the data yet, it was chosen for the wrong reason.
- **Recommendation-less insight.** Landing a genuinely interesting finding with no "so what should we do." Interesting is not the bar; actionable is.
- **Ownerless calls to action.** "We should look into this" with no name and no date is a wish, not a call to action, and it will not happen.
- **Averaging away the bad news.** Reporting an overall metric that has improved while a specific, important segment has gotten worse, without disclosing the split. This is functionally the same failure as `analytics-requirements`' vanity-metric disaggregation check, applied to a one-off narrative instead of a standing metric.

---

## Output Format

```markdown
---
name: data-storytelling
product: [product name]
story: [short title]
version: 1.0.0
phase: data
created: [date]
owner: data-engineer
audience: [who this is presented to]
---

# Data Story — [Title]

## Context
[What was the situation before this finding?]

## Insight
[What did the data show, stated as a finding — with the supporting
chart, chosen per the chart-choice-to-message table]

## Recommendation
[What should change, and why this follows from the insight]

## Call to Action
[Who does what, by when]

## Integrity Check
| Manipulation pattern | Checked? | Notes |
|---|---|---|
| Truncated axis | | |
| Cherry-picked window | | |
| Denominator hidden | | |
| Cause implied from correlation | | |
| Aggregation hiding a bad segment | | |
| Precision theater | | |
| Favorable comparison period | | |
```
