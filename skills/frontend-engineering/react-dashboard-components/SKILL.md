---
name: react-dashboard-components
description: >
  Teaches how to build compliance dashboards and reporting UI in React — composing
  aggregate read models into KPI cards, charts (Recharts/visx), data tables with
  sorting/filtering/virtualization, the compliance gap report view, data
  storytelling principles, loading/empty/error states, accessible charts, and
  export (CSV/PDF). Implements the ux-architect's dashboard specs over the
  data-architect's aggregate read models. Used by the frontend-engineer during
  Implement.
version: 1.1.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, dashboard, charts, recharts, reporting, data-table]
---

# React Dashboard Components

## Purpose

Dashboards turn the estate's aggregate data into decisions: where are the compliance gaps, what's the sensitivity distribution, which sources carry the most risk. A good dashboard answers a question at a glance and lets the user drill into detail. This skill builds the dashboard and reporting UI — KPI cards, charts, and data tables — over the aggregate Read Models the data-architect defined.

This implements the ux-architect's dashboard component specs (`ui-component-spec`) and serves the compliance officer's journey (the audit-preparation journey from `user-journey-mapping`).

---

## Source: Aggregate Read Models

Dashboards read **aggregate Read Models** (`read-model-design` / `data-model-design`), never raw Aggregates — the backend pre-computes the summaries, so the dashboard fetches one optimised payload, not thousands of rows.

```ts
function useEstateOverview(tenantId: string) {
  return useQuery({
    queryKey: ["estate-overview", tenantId],
    queryFn: ({ signal }) => api.getEstateOverview(tenantId, signal), // an aggregate Read Model
    staleTime: 60_000,
  });
}
```

Each dashboard widget maps to an aggregate Read Model: `EstateOverview`, `ComplianceGapReport`, `SensitivityDistribution`.

---

## KPI Cards

A KPI card states one number and its context (trend, target). Keep them scannable and honest.

```tsx
<KpiCard
  label="Restricted assets"
  value={overview.restrictedCount}
  trend={overview.restrictedTrend}            // ▲/▼ vs last period
  intent={overview.restrictedCount > 0 ? "warning" : "ok"}
/>
```

Rules: one metric per card; label in the Ubiquitous Language; trend needs a baseline (no trend arrow without a comparison period); colour is reinforced by icon/text (never colour alone — see `react-accessibility`).

---

## Charts

Default to **Recharts** (declarative, React-native, accessible-friendly) for standard charts; **visx** when bespoke/custom visuals are needed. Choose the chart type by the question, not by decoration:

| Question | Chart |
|---|---|
| Distribution across categories | Bar |
| Composition of a whole | Stacked bar (avoid pie for >3 slices) |
| Trend over time | Line / area |
| Gaps by framework + severity | Grouped/stacked bar |

```tsx
<ResponsiveContainer width="100%" height={280}>
  <BarChart data={gapsByFramework} aria-label="Compliance gaps by framework">
    <XAxis dataKey="framework" /><YAxis allowDecimals={false} />
    <Tooltip /><Legend />
    <Bar dataKey="open" name="Open gaps" fill="var(--color-warning)" />
  </BarChart>
</ResponsiveContainer>
```

**Data storytelling** (from the analytics discipline): lead with the headline, order categories meaningfully (by value, not alphabetically, unless order has meaning), label directly where possible, and avoid chart junk. The chart should make the point, not just plot the data.

---

## The Compliance Gap Report

The gap report is the centrepiece reporting view — it must be prioritised, drillable, and audit-credible (the compliance officer's core job, `user-journey-mapping`):

- **Severity-scored and sorted** — highest-risk gaps first, not raw order (a friction point identified in the journey map).
- **Grouped by framework** (SOC 2 CC6/CC7/A1 for the MVP).
- **Drill-down** — a gap links to the evidence/lineage that produced it (the lineage trail from `data-lineage-design`), so it's defensible to an auditor.
- **Status** — reviewed/unreviewed, with the review action.

---

## Data Tables

Reporting tables support sort, filter, and pagination — all in the **URL** (`react-routing`) so a filtered report is shareable. Large tables are **virtualized** (`react-performance-optimization`).

```tsx
<DataTable
  columns={gapColumns}
  rows={gaps}
  sort={sort} onSortChange={setSort}      // URL-backed
  virtualized                              // react-virtuoso for large result sets
  empty={<NoGapsState />}
/>
```

Tables use semantic `<table>` markup with `<th scope>` and `aria-sort` (see `react-accessibility`) — not `<div>` grids.

---

## States — Every Widget, Every State

Every widget implements loading/empty/error per its spec — a dashboard full of spinners or blank panels is a failure:

| State | Treatment |
|---|---|
| Loading | Skeleton **sized to the content** (prevents layout shift — CLS) |
| Empty | Meaningful empty state with a next action ("No gaps found — run a scan") |
| Error | Inline error in the widget with retry — one failed widget never blanks the whole dashboard |
| Partial | Widgets load independently; a slow widget doesn't block the others (parallel queries) |

Widget independence matters: each widget is its own query/error boundary, so the dashboard degrades gracefully (see `react-observability`).

---

## Export (CSV / PDF)

Reports are exportable for sharing with auditors (the journey's "closure" stage):

- **CSV** — client-side generation from the loaded data for tabular exports.
- **PDF** — for formatted audit reports, prefer **server-side rendering** of the report (backend) for fidelity and to keep heavy PDF libraries out of the bundle; the frontend triggers and downloads it. Document the choice; don't ship a multi-hundred-KB PDF lib to every user for an occasional export.

---

## Accessible Charts

Charts are not just pixels (see `react-accessibility`):
- Provide a **text/table alternative** of the chart's data (`<figure>` + visually-hidden data table, or a toggle).
- `aria-label` describing the chart's content.
- Never encode meaning in colour alone — use labels, patterns, or direct annotation.
- Ensure series colours meet contrast and are distinguishable for colour-blind users.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Aggregate Read Models | Widgets read pre-computed summaries | Dashboards aggregating raw rows client-side |
| Right chart for the question | Chart type matches the data question | Pie charts for many slices; chart junk |
| Gap report prioritised | Severity-sorted, drillable to lineage | Unordered gap list with no evidence trail |
| Every state handled | Loading/empty/error/partial per widget | Spinners-only or blank panels |
| Widget independence | Per-widget query + error boundary | One failed widget blanks the dashboard |
| URL-backed tables | Sort/filter/pagination in the URL; virtualized | View state trapped in component state |
| Accessible charts | Text alternative; not colour-only; contrast | Inaccessible canvas/colour-only charts |

---

## Anti-Patterns

- **Client-side aggregation** — fetching thousands of DataAsset rows to compute a count the backend's Read Model already holds. The dashboard reads summaries; the Write Model side computes them.
- **The wall of pies** — pie charts for five-plus slices, or any chart chosen for looks over the question. Distribution → bar; trend → line; composition → stacked bar.
- **Alphabetical category order** — sorting frameworks A–Z when severity or magnitude is the story buries the headline. Order by the value the user must act on.
- **One query to rule the dashboard** — a single mega-endpoint means one slow widget stalls everything and one failure blanks the page. Widgets query and fail independently.
- **Trend arrows without a baseline** — "▲ 12" against nothing is decoration, not information. No comparison period, no trend.
- **Spinner-only loading** — unsized spinners cause layout shift when content lands (CLS). Skeletons sized to the final content.
- **Colour-only severity in the gap report** — red/amber/green chips without text fail both accessibility and audit credibility; the SensitivityLevel word always accompanies the colour.
- **Un-shareable views** — filter/sort state in `useState` means a compliance officer can't send an auditor the exact filtered report. View state lives in the URL.

---

## Output Format

Produces dashboard/report components and their tests:

```
src/features/compliance/ComplianceDashboard.tsx
src/features/compliance/GapReport.tsx
src/shared/ui/charts/*.tsx          (accessible chart wrappers)
src/shared/ui/DataTable.tsx
src/features/compliance/*.test.tsx   (states + a11y; written first)
```
