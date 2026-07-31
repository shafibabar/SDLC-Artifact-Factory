---
name: dashboard-specification
description: >
  Teaches the data-engineer to specify a dashboard — per-widget metric definitions
  (formula, grain, source Read Model), the chart-type selection for each metric
  question (Knaflic), aggregation and filter semantics, refresh cadence, and the
  dashboard specification artifact. Distinguishes an exploratory dashboard from an
  explanatory one. Used during the Data phase when a stakeholder needs an
  at-a-glance operational or analytics view.
version: 2.0.0
phase: data
owner: data-engineer
created: 2026-07-20
related:
  - analytics-requirements
  - read-model-design
  - data-storytelling
  - metrics-instrumentation-plan
  - react-dashboard-components
  - ui-component-spec
  - data-pipeline-implementation
tags: [data, analytics, dashboard, visualization, chart-selection, read-model, metrics]
---

# Dashboard Specification

A dashboard specification defines what each widget **says** and **which chart form
best says it** — the exact metric behind the widget, how it is computed, where it
comes from, how fresh it is, and the chart type that makes its answer easiest to
read. It does not define pixel layout, colour palette, typography, or component
states — those remain the ux-architect's `ui-component-spec` and the frontend's
`react-dashboard-components`. This skill owns the *data-and-form* contract: the
number, and the shape that shows it; the downstream roles own styling and placement.

It consumes elicited requirements from `analytics-requirements` and turns each into
a buildable widget-level contract a data-engineer can implement and a ux-architect
can lay out without guessing what a number means or which chart carries it.

---

## Exploratory vs. Explanatory — Decide First

Knaflic's load-bearing distinction (`research/data-and-analytics/storytelling-with-data-knaflic.md`)
frames every downstream choice. A **standing dashboard is exploratory-leaning**: the
user filters and browses on their own schedule, so most widgets monitor rather than
argue a single point. A widget that exists specifically to **prompt a decision** is
explanatory and needs an explicit **Intended takeaway** — the on-screen "so what."

| | Exploratory widget | Explanatory widget |
|---|---|---|
| Purpose | Monitor / let the user find the story | Make one specific point / prompt a decision |
| Takeaway | User-derived via filtering | Stated on screen (annotation, target line) |
| Density | May show several cuts | Curated to the single point |

Do not ship exploratory density (every cut, every filter) where an explanatory point
is intended, nor bolt an argumentative annotation onto a pure monitoring tile.

---

## Per-Widget Specification — the fields

Every widget carries these fields (full template + worked example in
`references/dashboard-spec-template.md`; precise definition rules and a repo widget
set in `references/widget-metric-definitions.md`):

- **Metric definition** — reproducible enough that two engineers get the same number:
  source Read Model + field(s), every filter (status, sensitivity, tenant scope),
  grouping, time window (rolling vs fixed), and unit (count / rate / ratio).
- **Grain** — the one row the metric counts (per DataAsset? per tenant-day snapshot?).
  Grain confusion is the top defect; state it explicitly.
- **Formula / aggregation** — SQL against the pre-aggregated Read Model (preferred),
  or pseudocode when application logic is genuinely required.
- **Source Read Model** — named Read Model / table + owning Bounded Context +
  populating pipeline stage/events (traced through `read-model-design` and
  `data-pipeline-implementation`). Aggregate in the Read Model, never in the browser.
- **Chart type** — the form that best answers the metric's question (see below).
- **Filters** — which filters the widget honours and their default state.
- **Refresh / staleness contract** — source recompute cadence AND client staleness
  tolerance (two independent numbers), plus whether an "as of" indicator is required.
- **Empty-state data condition** — the exact query condition that counts as empty,
  distinct from query error and from "pipeline never ran" (onboarding-empty).
- **Intended takeaway** — required for explanatory widgets, omitted for monitoring.

---

## Match the Chart to the Question (Knaflic)

The chart type is a **data decision**, not a styling one: pick the form that makes the
metric's answer easiest to see, before the ux-architect touches colour or layout.
The core rule — from Knaflic — is *does this chart make the point easy to see*, not
*does it look impressive*. Quick guide:

| The metric's question is… | Use |
|---|---|
| One number that stands alone | Single number / big text |
| Change over time | Line chart |
| Categorical comparison | Bar chart (length beats angle/area) |
| Ranked categories, long labels | Horizontal bar, sorted by value |
| Precise values, many dimensions | Table |

Full selection logic — including two-time-point comparisons, decluttering,
preattentive-attribute emphasis, and the charts to **never** specify — is in
`references/chart-selection-guide.md`. Specify the chart *type* and its emphasis
intent here; leave the exact hex colour, font, and grid position to `ui-component-spec`.

---

## The Metric Must Be Actionable, Not Vanity (Lean Analytics)

Before a widget earns a place, run Croll & Yoskovitz's four-part good-metric test
(`research/data-and-analytics/lean-analytics-croll-yoskovitz.md`): a metric should be
**comparative** (against a period, cohort, or target — a bare number is not enough),
**understandable** (a non-analyst can remember and argue about it), **a ratio or
rate** (a denominator resists gaming — "classification coverage %" beats a raw
"assets classified" count), and it should **change behaviour** (if no value would
change what the viewer does, it is vanity — cut it). For any retention/stickiness
widget, validate with a **cohort comparison** (segment by start date, compare
like-elapsed time) before building — a rising cumulative count can hide declining
per-cohort retention. Worked application to this repo's widgets:
`references/widget-metric-definitions.md`.

Every widget also traces to an `analytics-requirements` entry. A widget that "seemed
useful" with no originating requirement is un-traced — trace it or cut it.

---

## Scope Boundary

| This skill owns | `ui-component-spec` / `react-dashboard-components` own |
|---|---|
| Metric definition, formula, grain | Grid position, widget size |
| Source Read Model + Bounded Context | The React component and its props |
| Chart *type* + emphasis intent | Exact colour, typography, animation |
| Filter + drill-down *data* semantics | Modal/accordion styling, click animation |
| Refresh/staleness contract (the numbers) | Polling implementation detail |
| Empty-state *data* condition | Empty-state illustration and copy |

If the question is "what does this widget contain, when is it correct, and what chart
form shows it," it belongs here. If it is "what exact colour / where on the grid,"
redirect to `ui-component-spec`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Metric precision | Reproducible by an independent implementer | Vague label, no formula |
| Grain stated | Every widget names the row it counts | Grain left implicit |
| Read Model sourced | Reads a pre-aggregated Read Model | Client-side aggregation over raw rows |
| Chart matches question | Form chosen for the question (Knaflic guide) | A chart that hides the point |
| Metric actionable | Passes the four-part Lean test | Vanity metric with no behaviour change |
| Exploratory/explanatory set | Each widget classified; takeaway present when explanatory | Explanatory point shipped as raw density |
| Staleness contract explicit | Recompute cadence + client tolerance both stated | Refresh behaviour implicit |
| Empty-state precise | Exact condition, distinct from error/onboarding | "Show empty when no data," no condition |
| Traced to a requirement | Every widget cites its `analytics-requirements` entry | Widget with no originating requirement |

---

## Anti-Patterns

- **Impressive over legible.** Choosing a chart because it looks sophisticated
  instead of the form that makes the answer easy to see (see the reference guide's
  banned-chart list).
- **Vague metric label.** "Compliance health score" with no formula or grain — two
  engineers would produce different numbers.
- **Vanity widget.** A monotonic cumulative count ("total assets scanned") that no
  value would change anyone's behaviour over. Cut it or make it a rate.
- **Client-side aggregation.** Specifying a widget against raw `data_assets` rows
  because "the frontend can just count them" — a paginated fetch will undercount.
- **Layout / styling creep.** Dictating grid position, hex colour, or typography —
  that is `ui-component-spec`'s call and the two docs will drift.
- **Missing staleness contract.** Leaving refresh unstated; a compliance officer
  briefing a CISO must know if the number is current or 15 minutes old.
- **Empty-state conflation.** Treating "zero open gaps" (good news) and "pipeline
  never ran" (onboarding problem) as one empty state.
