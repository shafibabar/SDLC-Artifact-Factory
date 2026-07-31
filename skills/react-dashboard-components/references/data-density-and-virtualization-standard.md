# Data Density and Virtualization Standard

Self-contained reference for `react-dashboard-components`. Governs when a
dashboard widget's row/point count requires virtualization versus when
plain pagination is sufficient, and how that decision interacts with the
URL-backed table state the skill's body requires.

---

## 1. Which Widgets Even Face This Decision

Dashboards read pre-computed **aggregate Read Models** (`react-dashboard-
components` §"Source: Aggregate Read Models") for KPI cards and charts —
a handful of numbers or series points, never thousands of raw rows.
Row-count density is therefore not a KPI-card or chart problem; it is a
**reporting-table** problem specifically: any widget (the Compliance Gap
Report, an evidence list, an asset list scoped to one gap) whose backing
Read Model can return one row per underlying record rather than one
pre-aggregated summary.

## 2. The Concrete Threshold

`react-performance-optimization` states virtualization is "mandatory for
any large list, table, or infinite scroll," and `react-component-design`'s
`VirtualizedList` render-props worked example (`references/worked-
examples.md` §4 in that skill) states the same trigger as "any list … that
can realistically exceed a few hundred rows." This skill's concrete
anchor within that stated range, chosen for dashboard/report tables
specifically: **virtualize once a widget's row count can realistically
reach 200 rows**, not only once it already has. "Realistically reach"
means the *unfiltered* dataset size for the tenant, not the count visible
after the user's current filter — a gap report that is usually 40 rows
but can hit 2,000 rows for a large tenant's unfiltered view is a
virtualize case, evaluated against the ceiling, not the common case.

Below 200 realistic rows, a plain paginated `<table>` is simpler and
sufficient — do not virtualize a table that will never be large just
because virtualization exists.

## 3. How to Virtualize — Cross-Reference, Don't Reinvent

Do not re-implement windowing logic in a dashboard table. Two composition
tools already own it, and the choice between them is the same one
`react-component-design`'s Composition-Pattern Selection Standard makes:

- **Default:** `react-virtuoso`'s `<Virtuoso>` component (`react-
  performance-optimization` Part 3) for the common case — the caller
  supplies `data` and an `itemContent` render function; no bespoke
  wrapper needed.
- **When the dashboard's own `DataTable` organism needs to own the
  windowing mechanics itself** (e.g., column headers, sort UI, and rows
  must share one measured scroll container that a third-party component
  doesn't expose the right seams for): use the render-props shape
  `react-component-design`'s `VirtualizedList` worked example
  establishes — the reusable part owns scroll-range measurement, the
  caller owns each row's markup via a children-as-function prop. Do not
  copy that example's code into this skill; call it by name and follow
  its shape.

Either way, apply `react-performance-optimization`'s `React.memo`
shallow-comparison rule to the row component: a virtualized row that
still re-renders on every parent render because the row-click handler is
a fresh closure each render defeats the point of windowing.

## 4. Virtualized Infinite Scroll vs. URL-Backed Pagination

These are two different, mutually exclusive answers to "how does the user
move through a large result set," and a widget picks exactly one:

| Approach | Choose when | Because |
|---|---|---|
| **URL-backed pagination** (SKILL.md body's Data Tables section) | The user needs a **shareable, addressable** view — "page 3, sorted by severity" sent to an auditor | Virtualized infinite scroll has no stable "page N" URL state; pagination does |
| **Virtualized infinite/continuous scroll** | The user's task is **scanning downward through a ranked list**, not jumping to an arbitrary page | The Compliance Gap Report is read top-to-bottom by severity; no auditor asks for "page 7 of gaps" |

The Compliance Gap Report defaults to virtualized continuous scroll for
this reason. A reporting table whose value is a shareable filtered/sorted
URL (the general case in the SKILL.md body) defaults to pagination
instead, and only adds virtualization once its row count crosses the
threshold in §2 — at which point it still keeps the URL-backed sort/filter
state, it just replaces client-side pagination with windowing under the
same filtered result set.
