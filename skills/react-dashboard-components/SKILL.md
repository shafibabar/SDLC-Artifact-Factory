---
name: react-dashboard-components
description: >
  Teaches how to build compliance dashboards and reporting UI in React —
  composing aggregate read models into KPI cards, charts (Recharts/visx)
  with an exact chart-library-selection and text/table-accessibility
  standard, data tables with a concrete row-count virtualization
  threshold (cross-referencing react-component-design's VirtualizedList
  render-props pattern), the compliance gap report view, a discriminated-
  union loading/empty/error state standard for every widget, real-time
  live-data widgets with a re-render/diffing discipline that avoids
  full-widget re-renders on every tick, and export (CSV/PDF). Implements
  the ux-architect's dashboard specs over the data-architect's aggregate
  read models. Used by the frontend-engineer during Implement.
version: 2.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, dashboard, charts, recharts, reporting, data-table, virtualization, accessibility, real-time]
related: [react-component-design, react-accessibility, react-performance-optimization, react-state-management, react-api-client, react-observability]
---

# React Dashboard Components

## Purpose

Dashboards turn the estate's aggregate data into decisions: where are the
compliance gaps, which sources carry the most risk. This skill builds
the dashboard/reporting UI — KPI cards, charts, data tables — over the
aggregate Read Models the data-architect defined, implementing the
ux-architect's `ui-component-spec` and the compliance officer's
audit-preparation journey (`user-journey-mapping`).

Dashboards read **aggregate Read Models**, never raw Aggregates — the
backend pre-computes summaries, so a widget fetches one payload, not
thousands of rows:

```ts
const useEstateOverview = (tenantId: string) => useQuery({
  queryKey: ["estate-overview", tenantId],
  queryFn: ({ signal }) => api.getEstateOverview(tenantId, signal),
  staleTime: 60_000,
});
```

---

## KPI Cards

One metric per card, labelled in the Ubiquitous Language; a trend arrow
requires a baseline — never decoration. Colour is reinforced by icon/text,
never colour alone (`react-accessibility`):

```tsx
<KpiCard label="Restricted assets" value={overview.restrictedCount}
  trend={overview.restrictedTrend} intent={overview.restrictedCount > 0 ? "warning" : "ok"} />
```

---

## Charts

Choose the type by the question, never by decoration:

| Question | Chart |
|---|---|
| Distribution across categories | Bar |
| Composition of a whole | Stacked bar (avoid pie for >3 slices) |
| Trend over time | Line / area |
| Gaps by framework + severity | Grouped/stacked bar |

**Data storytelling:** headline first, order by value (not alphabetically
unless order is meaningful), no chart junk. Library choice (Recharts
default vs. visx) and the exact accessibility requirement — every chart,
no exceptions, ships a real `<table>` alternative carrying the same data
points plus a content-describing `aria-label` — are a full standard:
`references/chart-accessibility-standard.md`.

---

## Data Tables and Virtualization

Sort, filter, and pagination live in the **URL** (`react-routing`), never
local state. Semantic `<table>` markup with `<th scope>` and `aria-sort`
(`react-accessibility`) — never `<div>` grids:

```tsx
<DataTable columns={gapColumns} rows={gaps} sort={sort} onSortChange={setSort}
  virtualized empty={<NoGapsState />} />
```

`virtualized` follows a concrete threshold: **virtualize once a table's
realistic unfiltered row count can reach 200 rows** — this skill's anchor
within `react-performance-optimization`'s and `react-component-design`'s
"a few hundred rows" guidance; below that, plain pagination is sufficient.
Default to `react-virtuoso`, or — when the table's header/sort UI needs
one shared scroll container — `react-component-design`'s `VirtualizedList`
render-props shape (call it by name; never reimplement it here). Full
criteria: `references/data-density-and-virtualization-standard.md`.

The centrepiece instance is the **Compliance Gap Report**: severity-scored
and sorted (highest-risk first), grouped by framework (SOC 2 CC6/CC7/A1),
drillable to the evidence/lineage behind each gap (`data-lineage-design`),
and carrying review status (reviewed/unreviewed) with the review action.

---

## Widget States: Loading, Empty, Error

Every widget models its render state as one **discriminated union** —
`loading | empty | error | populated`, never independent booleans
(`react-component-design`'s discriminated-union standard applies here
too): a sized skeleton (never a bare spinner — prevents CLS), a specific
empty message with a next action (never the error copy reused), and an
actionable error — a retry that re-triggers only that widget's query,
hidden for non-retryable failures (`react-api-client`'s `AppError`
kinds). Each widget owns its own query and error boundary (`react-
observability`) so one failure never blanks the dashboard. Full standard:
`references/widget-state-standard.md`.

---

## Real-Time Updates

A widget subscribing to live data (WebSocket/polling) keeps the
subscription in a custom hook, and each tick patches **only the changed
data point** — keyed state, unchanged entries keep the same object
reference — never a full-dataset replace, which would defeat `React.memo`
(`react-performance-optimization`) widget-wide. Also throttle bursty
streams, reconcile via the query cache rather than forking state, and
surface connection health (reconnecting/stale) as its own signal. Exact
diffing discipline: `references/realtime-update-standard.md`.

---

## Export (CSV / PDF)

CSV is client-side generation from already-loaded data. PDF prefers
**server-side rendering** for audit fidelity — the frontend only triggers
and downloads it, never shipping a heavy PDF library to every user.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Aggregate Read Models | Widgets read pre-computed summaries | Client-side aggregation of raw rows |
| Right chart, right library, real alternative | Type matches the question; visx only for a bespoke visual Recharts can't express; every chart ships a real `<table>` alternative + content-describing `aria-label`, not colour-alone | Pie for many slices; visx for polish; a generic "unavailable" message or colour-only legend |
| Virtualization threshold applied | Tables virtualize at the 200-row anchor; KPI/chart widgets exempt | Needless virtualization, or a 2,000-row table left plain |
| Every widget state modelled | Discriminated union; sized skeleton; actionable error; specific empty | Boolean soup; spinner-only; generic error |
| Widget independence, URL-backed tables | Per-widget query + error boundary; sort/filter/pagination in the URL | One failure blanks the dashboard; state trapped in `useState` |
| Real-time diffing | Keyed patch on the changed point; memoized rows actually skip | Full-dataset replace every tick; no cleanup |

---

## Anti-Patterns

- **Client-side aggregation** of raw rows to compute what the Read Model
  already holds.
- **The wall of pies / alphabetical order**, or **a chart with no real
  table alternative** — decoration over the question, or a screen reader
  that can't reach an `aria-hidden`/generic-message "alternative."
- **Misapplied virtualization threshold**, or **status as boolean soup**
  (`isLoading && hasError && data`) instead of one discriminated field.
- **Spinner-only loading, or a retry on a non-retryable error** — unsized
  layout shift, or a fix that deterministically won't work.
- **One query to rule the dashboard**, and **full-dataset replace on
  every live tick** — defeat per-widget independence and `React.memo`.
- **Un-shareable views** — filter/sort in `useState` instead of the URL.

---

## Output Format

Produces dashboard/report components, live-data hooks, and their tests:

```
src/features/compliance/ComplianceDashboard.tsx
src/features/compliance/GapReport.tsx
src/shared/ui/charts/*.tsx          (accessible chart wrappers + table alternatives)
src/shared/ui/DataTable.tsx
src/features/compliance/hooks/useLive*.ts   (live-data widgets only)
src/features/compliance/*.test.tsx   (states + a11y; written first)
```
