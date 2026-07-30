# Loading, Empty, and Error State Standard

Self-contained reference for `react-dashboard-components`. Deepens the
SKILL.md body's States table into an exact, per-widget standard: what
each of the three states must render, and how they are modelled so they
cannot be combined into invalid boolean soup.

---

## 1. Model Status as a Discriminated Union, Not Booleans

A widget's render state is exactly one of four values at any moment —
`loading | empty | error | populated` — modelled as a discriminated union
tag, the same standard `react-component-design`'s Prop and Input Design
Standard applies to variant props: `isLoading && hasError && data` boolean
soup can represent contradictory combinations (loading *and* error *and*
data all true) that have no correct render path. A `status` field keyed
on one literal makes the invalid combination unrepresentable:

```tsx
type WidgetState<T> =
  | { status: "loading" }
  | { status: "empty" }
  | { status: "error"; error: AppError; retry: () => void }  // AppError: react-api-client
  | { status: "populated"; data: T };
```

TanStack Query's own `status`/`fetchStatus` (react-state-management) maps
onto this directly for the loading/error/success cases; `empty` is a
widget-level derivation on top of `"success"` — zero rows is a successful
fetch, not an error, and must be classified explicitly rather than falling
through to a shared "no data" render shared with the error path.

## 2. Loading — Skeleton Sized to Final Content

**Never** a bare, unsized spinner — an unsized loading indicator causes
layout shift (CLS) the instant real content lands, because the browser
had no box to reserve. The loading render must occupy the same
dimensions the populated render will:

```tsx
function KpiCardSkeleton() {
  return (
    <div className="kpi-card" style={{ minHeight: KPI_CARD_HEIGHT }}>
      <div className="skeleton-block" style={{ width: "60%", height: "2rem" }} /> {/* value */}
      <div className="skeleton-block" style={{ width: "40%", height: "1rem" }} /> {/* label */}
    </div>
  );
}
```

A chart's loading skeleton occupies the chart's full `ResponsiveContainer`
height; a table's loading skeleton renders the expected initial page size
in skeleton rows (e.g., 10 skeleton `<tr>`s for a 10-row default page),
not one centered spinner floating in an otherwise-empty table body.

## 3. Empty — Distinct From Error, With a Next Action

Empty is a **successful** response describing zero matching rows. It must
never share a component or message with the error state — collapsing
both into "No data available" tells the user nothing about which
happened, and nothing about what to do next.

```tsx
function GapReportEmptyState({ hasActiveFilters }: { hasActiveFilters: boolean }) {
  return hasActiveFilters
    ? <EmptyState message="No gaps match these filters" action={{ label: "Clear filters", onClick: clearFilters }} />
    : <EmptyState message="No gaps found — run a scan" action={{ label: "Run scan", onClick: runScan }} />;
}
```

The message is specific to *why* the widget is empty (no data has ever
been produced vs. the current filter excludes everything) — a single
generic empty message across every widget fails this standard even if it
is grammatically distinct from the error message.

## 4. Error — Actionable, Not "Something Went Wrong"

An error state names what happened at the level `react-api-client`'s
`AppError` discriminated union already distinguishes, and offers the
action that actually applies to that error kind — a retry button is only
useful, and only shown, for a **retryable** failure:

```tsx
function WidgetError({ error, retry }: { error: AppError; retry: () => void }) {
  if (error.kind === "forbidden") {
    return <ErrorState message="You don't have access to this report." />; // no retry — retrying won't change the outcome
  }
  if (error.kind === "network" || error.kind === "server") {
    return <ErrorState message="Couldn't load this widget." action={{ label: "Retry", onClick: retry }} />;
  }
  return <ErrorState message={error.message} action={{ label: "Retry", onClick: retry }} />;
}
```

`retry` re-triggers **only this widget's query** (react-query's
`refetch`), never a full-page reload — a full reload throws away every
sibling widget's already-loaded state to fix one failure. Showing a retry
button on a non-retryable error (permissions, validation) that will
deterministically fail again is itself a failure of this standard — it
teaches the user that retrying is the fix when it never will be.

## 5. Widget Independence — Partial Failure Never Blanks the Dashboard

Each widget owns its own query and its own error boundary (`react-
component-design`'s error-boundary minimum bar; full placement mechanics
in `react-observability`). A dashboard composed of five widgets issuing
five independent queries, each rendering its own `WidgetState` above, is
the only shape that satisfies both this standard and the SKILL.md body's
Widget Independence rule — one slow or failing widget's `error` state
renders in its own boundary while the other four continue rendering
`loading` or `populated` normally.
