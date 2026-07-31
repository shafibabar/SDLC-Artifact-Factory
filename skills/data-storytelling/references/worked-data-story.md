# Worked Data Story — Classification Coverage Crossed the SOC 2 Target

A complete, end-to-end explanatory data story built with every technique in this skill, grounded in
this repo's product (a data-estate / compliance platform: Google Drive + S3 ingestion, PII entity
extraction, PostgreSQL-backed classification, SOC 2 as the MVP compliance target). The audience is
**Shafi** — a PM, not a programmer, reviewing without IDE tooling — and the pending decision is
whether to cite automated classification coverage as SOC 2 audit evidence.

---

## Step 0 — Exploratory vs. explanatory

The data-engineer has spent a week in *exploratory* mode: coverage by source, by tenant, by file
type, by week, confidence distributions, backlog trends. That work found the story. **None of it is
presented.** What follows is the *explanatory* subset — one point, one audience, one decision.

---

## Step 1 — Context framing (Lesson 1)

- **Who:** Shafi (PM), reviewing in plain Markdown.
- **What decision:** whether automated coverage is now solid enough to cite as SOC 2 evidence instead
  of the current manual quarterly sampling.
- **What action:** approve citing automated coverage in the audit evidence package — or hold for
  another quarter.
- **Mechanism:** a standalone written brief (no live narration), so every takeaway must sit on the page.

---

## Step 2 — The Big Idea (one sentence)

> **Classification coverage crossed the 90% SOC 2 target in week 9 of Q2 and has held above it since,
> so we can cite automated coverage as audit evidence and retire the manual quarterly sample.**

It states a point of view, conveys the stake, and is one sentence. Every chart below serves it.

---

## Step 3 — The query behind the visual

OLAP on PostgreSQL. One row per week, one measure — shaped like the message ("coverage over time"),
so there is nothing extra to declutter later:

```sql
SELECT date_trunc('week', classified_at)                          AS week,
       count(*) FILTER (WHERE classification IS NOT NULL)          AS classified,
       count(*)                                                    AS total,
       round(100.0 * count(*) FILTER (WHERE classification IS NOT NULL)
             / count(*), 0)                                        AS coverage_pct
FROM   assets
WHERE  classified_at >= date_trunc('quarter', now())
GROUP  BY 1
ORDER  BY 1;
```

Note `total` is selected alongside `coverage_pct` — the denominator is kept so the story can pair the
percentage with the base (integrity: no denominator hiding).

Illustrative result:

| week | classified | total | coverage_pct |
|---|---|---|---|
| Q2-w1 | 74,100 | 98,800 | 75 |
| Q2-w5 | 91,300 | 110,000 | 83 |
| Q2-w9 | 108,900 | 119,700 | 91 |
| Q2-w13 | 122,400 | 131,600 | 93 |

---

## Step 4 — Chart choice (Lesson 2)

The message is "coverage **changed over time** and crossed a line" → a **line chart**, not a bar per
week, not a pie, not a gauge. It passes the five-second test: the slope rising through a labeled
threshold line reads instantly.

---

## Step 5 — Declutter and focus (Lessons 3–4)

- Gridlines removed; plot border removed (whitespace already encloses the plot — Gestalt *enclosure*).
- Legend removed; the single coverage line is **labeled directly** at its right end.
- Y-axis rounded to whole percentages (no precision theater), starts at 0 (no truncation).
- The coverage line is the single **accent color** against an otherwise gray chart.
- The **90% SOC 2 target** drawn as a faint labeled reference line.
- A **marker + annotation** at week 9: "coverage crosses 90% target" — size and position (preattentive)
  put the eye on the exact crossing, which is the climax of the story.

---

## Step 6 — The assembled story (the artifact)

```markdown
---
name: data-storytelling
product: data-estate-compliance-platform
story: classification-coverage-crosses-soc2-target
version: 2.0.0
phase: data
created: 2026-07-31
owner: data-engineer
audience: Shafi (PM) — SOC 2 evidence decision
---

# Data Story — Classification Coverage Crossed the SOC 2 Target

**Big Idea:** Classification coverage crossed the 90% SOC 2 target in week 9 of Q2 and has held
above it since, so we can cite automated coverage as audit evidence and retire the manual sample.

## Context (setup)
For SOC 2 we must show that discovered assets are classified. All quarter we relied on a manual
quarterly sample because automated coverage sat in the mid-70s at the start of Q2 — below the 90%
target auditors expect, so automated numbers were not yet citable.

## Insight (tension -> climax)
Coverage rose steadily as the OCR fallback and Google Drive incremental sync matured, crossing the
90% target in week 9 and reaching 93% (122,400 of 131,600 assets) by week 13 — and it has stayed
above target every week since the crossing.

[Chart: single line, Q2 by week, y-axis 0-100% starting at zero, gridlines and border removed, line
labeled directly and in the one accent color, faint labeled 90% target line, annotated marker at the
week-9 crossing. Takeaway title: "Coverage crossed the 90% SOC 2 target in week 9 and held."]

## Recommendation (resolution)
Automated coverage is now consistently above target with a stable, explained upward trend — not a
one-week spike. We can cite automated coverage in the SOC 2 evidence package and retire the manual
quarterly sample, which frees steward time and gives auditors a continuous rather than point-in-time
measure. The one caveat: coverage is an aggregate; before citing it, confirm no single high-risk
tenant sits below target (disaggregation check).

## Call to Action
- data-engineer: run the per-tenant breakdown this week to confirm no tenant is below 90%; if all
  clear, wire the coverage query into the SOC 2 evidence export by end of sprint.
- Shafi: approve citing automated coverage as evidence, contingent on the per-tenant check passing.

## Integrity Check
| Pattern | Checked? | Notes |
|---|---|---|
| Truncated axis | Yes | Y-axis starts at 0 |
| Cherry-picked window | Yes | Full quarter shown, not just the weeks above target |
| Denominator hidden | Yes | 122,400 of 131,600 stated, not just "93%" |
| Cause implied from correlation | Yes | Rise attributed to named mechanisms (OCR fallback, incremental sync), not left implied |
| Aggregation hiding a bad segment | Open | Explicitly deferred to the per-tenant check in the call to action |
| Precision theater | Yes | Whole percentages; base counts stated |
| Favorable comparison period | Yes | Start-of-quarter baseline, not the worst prior week |
```

---

## Why this works

Shafi gets, on one page and in reading order: what was normal (mid-70s, manual sample), the tension
(target unmet), the climax (week-9 crossing, annotated on the chart), the resolution (cite it, retire
the sample), and the next action with owners and a deadline. The integrity check is not decoration —
it visibly flags the one unresolved risk (aggregation possibly hiding a below-target tenant) and
routes it into the call to action rather than burying it. That is the difference between a chart that
is *correct* and a story that *changes a decision*.
