---
name: dashboard-specification
description: >
  Teaches how to write a dashboard's data content specification — per-widget metric
  definition, aggregation logic, source Read Model, drill-down semantics, and
  refresh/staleness contract. This is explicitly the DATA half of a dashboard, not
  the UI: layout, visual design, and component behaviour belong to the ux-architect's
  `ui-component-spec`, and the React implementation to `react-dashboard-components`.
  Builds on `analytics-requirements` and hands off to both. Used by the data-engineer
  during Data.
version: 1.0.0
phase: data
owner: data-engineer
created: 2026-07-20
tags: [data, analytics, dashboard, metrics, aggregation, read-model, drill-down, handoff]
---

# Dashboard Specification

## Purpose

A dashboard specification defines what a dashboard **says** — the exact metric behind each widget, how it is computed, where it comes from, and how fresh it is guaranteed to be. It does not define what the dashboard **looks like**. That distinction is the whole point of this skill: layout, visual hierarchy, component states, and interaction affordances are the ux-architect's `ui-component-spec`; the resulting React implementation over Read Models is the frontend-engineer's `react-dashboard-components`. A dashboard-specification with a grid layout or a colour palette in it has wandered out of scope.

This skill takes the elicited requirements from `analytics-requirements` and turns each one into a precise, buildable widget-level data contract — the thing a data-engineer can implement unambiguously and a ux-architect can lay out without having to guess what the number means.

---

## What Belongs Here vs. What Doesn't

| In scope (this skill) | Out of scope (elsewhere) |
|---|---|
| The metric's exact definition and formula | Widget size, position, grid layout (`ui-component-spec`) |
| Aggregation logic (SQL/pseudocode) | Chart type, colour, typography (`ui-component-spec`, `react-dashboard-components`) |
| Which Read Model / table the data comes from | The React component and its props (`react-dashboard-components`) |
| Drill-down semantics — what deeper data a click reveals | Click animation, modal styling |
| Refresh/staleness contract | Polling implementation detail (frontend concern once the contract is set) |
| Empty-state **data** condition (when there is genuinely no data) | Empty-state illustration and copy (`ui-component-spec`) |

If a question is "what should this widget contain and when is it correct," it belongs here. If the question is "how should this widget look or animate," redirect to `ui-component-spec`.

---

## Per-Widget Specification Format

Every widget on a dashboard gets this structure:

```
Widget: [name]
Answers requirement: [reference to the analytics-requirements entry]

Metric definition:
  [Precise, unambiguous statement of what number(s) this widget shows]

Aggregation logic:
  [SQL or pseudocode — the exact computation]

Data source:
  [Read Model / table / event stream, with the Bounded Context it belongs to]

Drill-down:
  [What a click/expand reveals, and where that data comes from]

Refresh / staleness contract:
  [How often the underlying data is recomputed; how stale a rendered
   value is allowed to be before it must be marked stale or refetched]

Empty-state data condition:
  [The precise data condition that counts as "empty" — not the visual
   treatment, just when it applies]
```

---

## Metric Definition — Precision Rules

A metric definition is not "compliance gap count." It states, unambiguously enough to reimplement from scratch and get the same number:

- The exact source table/Read Model and field(s)
- Every filter applied (status, sensitivity, tenant scope)
- The grouping/bucketing, if any
- The time window, if any, and whether it is rolling or fixed
- The unit and whether it is a count, a rate, or a ratio

```
Bad:  "Number of compliance gaps"

Good: "Count of rows in the compliance_gap_summary Read Model where
       status = 'open' AND tenant_id = :tenant, grouped by
       framework_control. Not time-windowed — reflects current state."
```

The "Good" version can be implemented identically by two different engineers on two different days. That reproducibility is the test of whether a metric definition is complete.

---

## Aggregation Logic

State the aggregation as SQL against the Read Model (preferred — Read Models are pre-aggregated so this is usually a simple `SELECT`) or as pseudocode when the aggregation genuinely requires application-layer logic (e.g., a weighted severity score).

```sql
-- Widget: Open Gaps by Framework Control
SELECT framework_control,
       severity,
       count(*) AS open_gap_count
  FROM compliance_gap_summary
 WHERE tenant_id = $1
   AND status = 'open'
 GROUP BY framework_control, severity
 ORDER BY
   CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2
                 WHEN 'medium' THEN 3 ELSE 4 END,
   open_gap_count DESC;
```

**Aggregate in the Read Model, not in the browser.** If a widget's SQL would need to scan raw `data_assets` or `extracted_entities` rows to compute a count, that computation belongs in a Read Model projection (`read-model-design`, maintained by the data-architect's design and the data-engineer's pipeline — see `data-pipeline-implementation`), not as a client-side reduction over a large fetched payload. `react-dashboard-components` reads pre-computed summaries; this skill is where "pre-computed" gets defined.

---

## Data Source

Every widget names its Read Model or table explicitly, and the Bounded Context that owns it. This is what lets the frontend-engineer generate a typed API client and the data-engineer know which pipeline stage's output the widget depends on (traced back through `data-pipeline-design`'s stage contracts).

```
Data source: compliance_gap_summary (Read Model)
Bounded Context: Compliance
Populated by: Compliance Rule Engine pipeline stage (see data-pipeline-implementation)
Underlying events: ComplianceGapOpened, ComplianceGapClosed, DataAssetReclassified
```

---

## Drill-Down Semantics

A dashboard summary invites the next question — "which specific assets?" Drill-down semantics define what data answers that question, not how the UI reveals it (accordion, modal, navigation — `ui-component-spec`'s call).

```
Drill-down: click a framework_control row
  → reveals: individual ComplianceGap rows for that framework_control,
    each showing data_asset_id, opened_at, and a link to its lineage
    trail (data-lineage-design) for audit defensibility
  → data source: compliance_gap_detail (Read Model), filtered by
    framework_control = [selected]
```

Every drill-down in a compliance product should terminate at something an auditor can be shown — a specific record, timestamp, and (where relevant) the lineage trail proving where the finding came from. A drill-down that bottoms out in "trust us" fails the compliance officer's actual job.

---

## Refresh / Staleness Contract

State two numbers: how often the underlying Read Model is recomputed, and how stale a value on screen is allowed to become before the UI must indicate staleness or refetch. These are independent — a Read Model updated every 15 minutes can still be shown with a 60-second client staleness tolerance (`staleTime` in the frontend's query cache).

| Field | Meaning | Example |
|---|---|---|
| Source recompute cadence | How often the pipeline/Read Model updates | Every 15 min (matches Compliance Rule Engine stage cadence) |
| Client staleness tolerance | How long a cached value may be shown before refetch | 60 s |
| Staleness indicator required? | Whether the UI must show "as of [time]" when data could be stale | Yes — compliance data always carries an as-of timestamp |

A widget with no staleness contract silently becomes "whatever the last successful fetch happened to return" — indistinguishable, to the compliance officer, from current truth.

---

## Empty-State Data Condition

State precisely what data condition counts as empty — not "no gaps found" as prose, but the condition a query returns:

```
Empty-state data condition: zero rows where
  tenant_id = :tenant AND status = 'open'
(Distinct from: query error, or "no scan has ever run" —
 those are error and onboarding-empty states respectively,
 handled per ui-component-spec's state variants.)
```

Conflating "genuinely zero results" with "no data has ever been computed" is a common defect — the first is good news (no open gaps), the second means the pipeline hasn't run yet. They need different empty-state treatments, and this skill's job is only to state which data condition triggers which case; the visual treatment is `ui-component-spec`'s.

---

## Handoff Format

The completed dashboard-specification hands off to two different roles for two different purposes:

| To | Consumes | For |
|---|---|---|
| **ux-architect** (`ui-component-spec`) | The widget list, metric labels (in Ubiquitous Language), drill-down existence (not its data), and the staleness-indicator requirement | Designing layout, states, and interaction |
| **frontend-engineer** (`react-dashboard-components`) | The Read Model/API contract, the staleness numbers, and the empty-state data conditions | Implementing the data-fetching and rendering logic |

Neither downstream role should need to re-derive a metric's meaning — if the ux-architect has to ask "wait, what exactly does this number count?", the specification was incomplete.

---

## Worked Example — Sensitivity Distribution Widget

From `analytics-requirements`' compliance officer audit-prep dashboard, a widget answering "what is the sensitivity mix of my estate, and is it trending toward more Restricted content?"

```
Widget: Sensitivity Distribution
Answers requirement: "What is my estate's sensitivity mix, and is Restricted
  content growing faster than I'm reviewing it?" (analytics-requirements)

Metric definition:
  Count of DataAsset rows per SensitivityLevel (Public, Internal, Confidential,
  Restricted), as of now, scoped to the current tenant. A second series shows
  the same breakdown 30 days prior for trend comparison.

Aggregation logic:
  SELECT sensitivity_level, count(*) AS asset_count
    FROM data_assets
   WHERE tenant_id = $1 AND deleted_at IS NULL
   GROUP BY sensitivity_level;
  -- 30-days-prior comparison reads the same aggregation from a
  -- daily snapshot table, estate_sensitivity_snapshot, not a live
  -- historical scan (avoids scanning full history on every render).

Data source: data_assets (current); estate_sensitivity_snapshot (trend)
Bounded Context: Data Estate
Populated by: Classification pipeline stage + a daily snapshot job

Drill-down: click the Restricted segment
  → reveals: DataAsset rows at Restricted, sorted by classified_at descending
  → data source: data_asset_list Read Model, filtered by
    sensitivity_level = 'Restricted'

Refresh / staleness contract:
  Source recompute cadence: current counts are live (query on render);
    snapshot table updates once daily at 02:00 UTC
  Client staleness tolerance: 60 s on the current-count query
  Staleness indicator required: yes, on the trend comparison
    ("compared to [snapshot date]")

Empty-state data condition: zero rows in data_assets for the tenant
  (distinct from "no source connected yet" — the onboarding-empty case)
```

This is handed to the ux-architect to lay out (likely a stacked bar per `react-dashboard-components`' chart-choice table) and to the frontend-engineer to implement against `data_asset_list` and `estate_sensitivity_snapshot`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Data-only scope | No layout, colour, or component detail present | Spec dictates grid position or chart colour |
| Metric precision | Definition is reproducible by an independent implementer | Vague label with no formula |
| Aggregation stated | SQL or pseudocode given for every widget | "Backend will figure out the query" |
| Read Model sourced | Widget reads a pre-aggregated Read Model, not raw rows | Client-side aggregation over raw tables implied |
| Drill-down terminates in evidence | Drill-down reaches a specific, auditable record | Drill-down that dead-ends in another summary |
| Staleness contract explicit | Recompute cadence and client tolerance both stated | Refresh behaviour left implicit |
| Empty-state condition precise | Exact query/data condition given, distinct from error/onboarding states | "Show empty state when there's no data" with no condition |
| Traced to a requirement | Every widget references its `analytics-requirements` entry | Widget with no originating requirement |

---

## Anti-Patterns

- **Layout creep.** Specifying widget size, chart colour, or grid position "just to be helpful." This is `ui-component-spec`'s job; a dashboard-specification that dictates pixels has started making decisions the ux-architect owns, and the two documents will drift out of sync the first time either changes independently.
- **The vague metric label.** "Compliance health score" with no formula. If two engineers implementing it independently would produce different numbers, the definition is not done.
- **Client-side aggregation by default.** Specifying a widget against raw `data_assets` rows "because the frontend can just count them." Aggregation belongs in the Read Model; shipping thousands of rows to compute a count in the browser is both a performance and a correctness risk (a paginated fetch will undercount).
- **Drill-down to nowhere.** A click that reveals another summary number instead of the underlying record and its lineage. In a compliance product, every drill-down should be able to end at "here is the exact evidence."
- **Missing staleness contract.** Leaving refresh cadence unstated on the assumption "the frontend will just poll reasonably." A compliance officer briefing a CISO needs to know whether the number on screen is definitely current or possibly 15 minutes old.
- **Empty-state conflation.** Treating "zero open gaps" (good news) and "pipeline never ran" (onboarding problem) as the same empty state. They require different data conditions and different downstream treatments.
- **Un-traced widgets.** Adding a widget because it "seemed useful for a dashboard" with no entry in `analytics-requirements`. Every widget exists because a decision needs it — trace it or cut it.

---

## Output Format

```markdown
---
name: dashboard-specification
product: [product name]
dashboard: [dashboard name]
version: 1.0.0
phase: data
created: [date]
owner: data-engineer
---

# Dashboard Specification — [Dashboard Name]

## Widget: [name]
Answers requirement: [analytics-requirements reference]

### Metric Definition
[Precise statement]

### Aggregation Logic
```sql
[query or pseudocode]
```

### Data Source
Read Model / table: [name]
Bounded Context: [name]
Populated by: [pipeline stage / event(s)]

### Drill-Down
[What deeper data is revealed, and its source]

### Refresh / Staleness Contract
| Field | Value |
|---|---|
| Source recompute cadence | |
| Client staleness tolerance | |
| Staleness indicator required | |

### Empty-State Data Condition
[Precise data condition]

## Handoff Notes
- To ux-architect (`ui-component-spec`): [widget list, labels, drill-down existence]
- To frontend-engineer (`react-dashboard-components`): [Read Model contracts, staleness numbers]
```
