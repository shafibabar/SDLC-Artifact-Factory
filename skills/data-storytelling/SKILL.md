---
name: data-storytelling
description: >
  Turn an analysis into an explanatory data story the data-engineer presents during Data —
  the narrative arc (setup, tension, resolution), audience and context framing (who, what
  decision, what action), chart selection and decluttering, preattentive attributes (color,
  size, position) to direct attention, the exploratory-vs-explanatory distinction, the Big
  Idea single-sentence exercise, takeaway-title and annotation strategy, and an integrity
  check against manipulative presentation (truncated axes, cherry-picked windows, misleading
  aggregation). Grounded in Knaflic, Storytelling with Data. Distinct from domain-storytelling
  (a DDD modeling technique). Use when analysis results must persuade or inform a decision.
version: 2.0.0
phase: data
owner: data-engineer
created: 2026-07-20
tags: [data, analytics, data-storytelling, visualization, knaflic, narrative, preattentive-attributes]
produces: data-story
domain: data
status: stable
related: [domain-storytelling, dashboard-specification, reporting-spec, react-dashboard-components, analytics-requirements]
---

# Data Storytelling

## Purpose

A correct analysis that nobody acts on has failed as completely as a wrong one. Data storytelling
is the discipline of presenting analysis so the receiver understands what happened, why it matters,
and what to do — without being a data professional themselves. It is the last mile between "the
number is right" and "the number changed a decision."

**Exploratory vs. explanatory (Knaflic's load-bearing distinction).** *Exploratory* analysis is the
private, messy, every-cut-of-the-data work you do to *find* the story. *Explanatory* analysis is the
small, curated subset you build to *communicate one point to one audience* once you've found it. This
skill governs explanatory communication only. The most common failure it prevents is shipping
exploratory density — every filter, every metric, the whole haystack — where an explanatory needle
was needed.

**Not `domain-storytelling`.** That is a DDD / Event-Storming modeling technique for capturing how
actors move work objects through a bounded context. This skill is about persuading a human with an
analysis result. They share a word and nothing else. This skill is also distinct from
`dashboard-specification` and `reporting-spec`, which define what data a standing artifact *contains*;
data storytelling is a specific act of communication at a specific moment, usually outside the
standing dashboard.

---

## The Six-Lesson Knaflic Spine

Knaflic's *Storytelling with Data* is the primary source. Its six lessons are the skill's backbone:

| Lesson | In one line | Depth |
|---|---|---|
| **1. Understand the context** | Who is the audience, what decision, what action, what delivery mechanism | this body, below |
| **2. Choose an effective visual** | Pick the chart from the message; default to text / bar / line | `references/knaflic-techniques.md` |
| **3. Eliminate clutter** | Remove every element that costs attention but adds no information | `references/knaflic-techniques.md` |
| **4. Focus attention** | Preattentive attributes (color, size, position) direct the eye before reading | `references/knaflic-techniques.md` |
| **5. Think like a designer** | Affordances, accessibility, aesthetics, acceptance | `references/knaflic-techniques.md` |
| **6. Tell a story** | Narrative arc + explicit takeaway on every visual | `references/narrative-and-annotation.md` |

---

## Audience and Context Framing (Lesson 1)

Before choosing any chart, answer four questions. Get these wrong and every downstream design choice
is wrong relative to the wrong target:

- **Who** is the audience? (For this repo, often Shafi — a PM, not a programmer, reviewing without IDE
  tooling. CLAUDE.md's reviewability standard applies to narrative artifacts too.)
- **What decision** does this analysis feed? An analysis with no pending decision is monitoring, not a
  story — reconsider whether a story is even the right artifact.
- **What action** do you want the audience to take? Name it. "Be informed" is not an action.
- **What mechanism** delivers it — a live briefing (you narrate, gaps get filled aloud) or a standalone
  document (an auditor reads a frozen PDF with no narration)? A standalone artifact must carry every
  takeaway *on the page*.

Then compress the point into the **Big Idea** — Knaflic's exercise for forcing clarity before you
build anything (`references/narrative-and-annotation.md`). If you cannot state your point crisply, no
chart choice will rescue it.

---

## The Narrative Arc -> the spec-writable structure

Knaflic borrows classic story structure: **setup** (context / the plot), **tension** (the rising
problem), **resolution** (the insight and what happens next). In this repo that arc is written as a
four-part structure — the same shape, made reviewable without a live narrator:

| Part | Arc role | Answers |
|---|---|---|
| **Context** | Setup | What was normal before this? What did we expect? |
| **Insight** | Tension -> climax | What did the data actually show, as a *finding* — not a chart description |
| **Recommendation** | Resolution | What should change, specifically, and why it follows from the insight |
| **Call to action** | Ending | Who does what, by when — named owner, named deadline |

Skipping a part yields a story that is technically complete but moves no one: without context "0.74"
means nothing; without a recommendation the insight is trivia; without a call to action it is trivia
with a shrug attached. Full treatment of the arc, horizontal vs. vertical logic, and annotation
strategy: `references/narrative-and-annotation.md`. A complete worked story for this repo:
`references/worked-data-story.md`.

---

## Chart Selection and Decluttering (Lessons 2-4, in brief)

Choose the chart **from the message**, never the message from an impressive chart. Default to
**simple text** (one number), **bar** (categorical comparison — length beats angle, so never a pie),
and **line** (change over time). Avoid pie / donut, radar, dual-axis, gauge, and all 3D effects as a
matter of course, not case-by-case. The full message->chart mapping table lives in
`references/knaflic-techniques.md`.

The five-second test: **could someone unfamiliar with the query state the message from the chart
alone, in under five seconds?** If not, the chart is wrong or there is no single message yet.

Then **declutter** and **focus attention**: strip gridlines, borders, redundant legends, and excess
precision; keep the whole visual in a muted base color and spend one deliberate accent color only on
the data the insight is about. The decluttering checklist, the Gestalt principles behind it, and the
preattentive-attribute technique are all in `references/knaflic-techniques.md`.

---

## Integrity: Persuading Honestly

Knaflic's craft makes a story land; it does not make it *true*. A story that persuades through
distortion is a defect regardless of intent. Check every story against these before presenting —
each is expanded with fixes in `references/narrative-and-annotation.md`:

- **Truncated y-axis** — start bar axes at zero; if a line axis genuinely can't, label it and say so.
- **Cherry-picked window** — show enough history to prove the window is representative; justify it.
- **Denominator hiding** — pair every count with its base when the base changes the reading.
- **Cause implied from correlation** — state the mechanism or flag "correlated, cause not established."
- **Silent aggregation hiding a bad segment** — show the breakdown when a subgroup could diverge (the
  disaggregation check from `analytics-requirements`, applied to a one-off narrative).
- **Precision theater** — round to what the sample supports; state the sample size.
- **Favorable comparison period** — use a pre-agreed comparison, not the most flattering one available.

---

## When to Use / Not Use

- **Use** when an analysis result must inform or persuade toward a decision — a one-off finding, an
  anomaly briefing, or a recurring metrics review presented (not just published).
- **Do not use** to define a standing dashboard's contents (`dashboard-specification`) or a recurring
  report's contents (`reporting-spec`) — those are exploratory-leaning artifacts; cross-reference this
  skill's decluttering / emphasis rules from their presentation layer, but the structure here is for
  the explanatory moment. `react-dashboard-components` restates the chart-choice rules for React widgets.
- **Do not confuse** with `domain-storytelling` (DDD modeling).

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Explanatory, not exploratory | One curated point for one audience | Every-cut density dumped on the reader |
| Full narrative structure | Context, insight, recommendation, call to action all present | Any part missing |
| Chart from message | Chart chosen for the specific message | Chart chosen for variety or sophistication |
| Decluttered and focused | Clutter removed; one accent color on the message point | Default gridlines / legends; contrast everywhere |
| Explicit takeaway | Stated "so what" in a title or annotation | Chart left to speak for itself |
| Integrity cleared | Every manipulation pattern checked | Any pattern present without justification |
| Actionable | Call to action names who and by when | Ownerless "we should look into this" |

---

## Anti-Patterns

- **Chart-first construction** — picking an impressive chart, then finding data for it.
- **The insight-free chart dump** — presenting a chart and letting the audience infer the point.
- **Exploratory density as communication** — the every-filter dashboard handed over as a "story."
- **Contrast everywhere** — color on everything draws the eye to nothing (see preattentive attributes).
- **Truncated axes for drama** — the most common integrity violation and the easiest to catch.
- **Recommendation-less insight** — interesting is not the bar; actionable is.
- **Ownerless calls to action** — "we should look into this," with no name and no date, will not happen.

---

## Output Format

```markdown
---
name: data-storytelling
product: [product name]
story: [short title]
version: 2.0.0
phase: data
created: [date]
owner: data-engineer
audience: [who this is presented to]
---

# Data Story — [Title]

**Big Idea:** [the single opinionated sentence — see references/narrative-and-annotation.md]

## Context      [setup: what was normal before this]
## Insight      [tension / climax: the finding, with the chosen + decluttered chart]
## Recommendation  [resolution: what should change and why]
## Call to Action  [ending: who does what, by when]

## Integrity Check
| Pattern | Checked? | Notes |
|---|---|---|
| Truncated axis | | |
| Cherry-picked window | | |
| Denominator hidden | | |
| Cause implied from correlation | | |
| Aggregation hiding a bad segment | | |
| Precision theater | | |
| Favorable comparison period | | |
```
