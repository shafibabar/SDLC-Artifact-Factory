---
name: react-performance-optimization
description: >
  Teaches measure-first React performance work — profiling with React DevTools and
  browser tooling (flame graphs, heap snapshots, network waterfalls), then applying
  the right fix: re-render minimization (React.memo/useMemo/useCallback by reference
  stability, not guesswork), DOM virtualization for large lists/graphs, route- and
  component-level code-splitting, bundle budgets and tree-shaking, and memory-leak
  prevention (cleaning effects, listeners, timers). The critical-rendering-path
  mindset from the blueprint. Used by the frontend-engineer during Implement.
version: 1.0.0
phase: implement
owner: frontend-engineer
tags: [implement, frontend, react, performance, memoization, virtualization, code-splitting, profiling]
---

# React Performance Optimization

## Purpose

Frontend performance is the discipline of cooperating with the browser's critical rendering path and React's reconciliation model — combined, like its backend counterpart, with measurement. The two are inseparable: you do not memoize code you have not profiled, and you do not claim a speedup you have not measured in React DevTools or a browser profile.

The governing rule, ahead of every technique: **measure first.** Premature `useMemo`/`useCallback` everywhere adds complexity and its own overhead while fixing nothing. Profile to find the actual expensive render or the actual large chunk, then fix that.

---

## Part 1 — Measure First

### React DevTools Profiler
The primary tool. Record an interaction, read the flame graph:
- **Which components rendered, and why** ("Why did this render?" shows prop/state/hook changes).
- **Commit duration** — the expensive commits and the components dominating them.
- **Stale dependency arrays** — effects/memos re-running because a dependency's reference changes every render.

### Browser DevTools
| Tool | Finds |
|---|---|
| Performance panel | Long tasks (>50ms), layout thrash, the critical rendering path |
| Memory → heap snapshots | Leaks: detached DOM nodes, retained closures, growing listener counts |
| Network waterfall | Render-blocking CSS/JS, slow/oversized API responses, missing compression |
| Coverage panel | Unused JS/CSS shipped to the user (code-splitting candidates) |

### Bundle analysis
`rollup-plugin-visualizer` (Vite) shows what's in each chunk and which dependency is heavy — the input to code-splitting decisions and bundle budgets.

Measure, identify the real bottleneck, fix that one thing, **re-measure** to confirm. Don't optimise on intuition.

---

## Part 2 — Re-Render Minimization

React re-renders a component when its state, context, or props change. Wasted renders come from **new references** to props that are semantically equal. Fix them based on profiling, with the right tool:

| Tool | Stabilises | Use when |
|---|---|---|
| `React.memo` | A component (skips render if props are referentially equal) | A pure component re-renders with unchanged props (profiler-confirmed) |
| `useMemo` | A computed **value**'s reference | An expensive computation, or an object/array passed as a prop to a memo'd child |
| `useCallback` | A **function**'s reference | A callback passed as a prop to a memo'd child / effect dependency |

```tsx
// Profiled: DataAssetRow re-rendered on every parent render because onClassify was a new fn each time.
const handleClassify = useCallback((id: string) => classify.mutate({ id }), [classify]);

const columns = useMemo(() => buildColumns(t), [t]); // stable object prop for a memo'd table

const DataAssetRow = memo(function DataAssetRow({ asset, onClassify }: RowProps) {
  /* now skips re-render when asset & onClassify are referentially stable */
});
```

**Do not** wrap everything in `memo`/`useMemo`/`useCallback`. Each has a cost (comparison, cache) and clutters the code. Apply them where the profiler shows a real, repeated wasted render — and prefer the cheaper fixes first: **co-locate state** (so fewer components are in the render path — see `react-state-management`) and **pass JSX as children** (children don't re-render when the parent's state changes).

---

## Part 3 — Virtualization (Windowing)

The estate has thousands of data assets; rendering thousands of DOM rows freezes the main thread. Virtualization renders only the rows in (and near) the viewport — DOM node count stays constant regardless of data size. **Mandatory** for any large list, table, or infinite scroll.

```tsx
import { Virtuoso } from "react-virtuoso";

<Virtuoso
  data={assets}                                  // 10,000 rows
  itemContent={(_i, asset) => <DataAssetRow asset={asset} onClassify={handleClassify} />}
/>  // only ~visible rows are mounted; DOM footprint is small and bounded
```

Default to `react-virtuoso` (handles variable heights, infinite loading); `react-window` for simple fixed-height cases. The estate graph has its own large-data strategy (WebGL canvas, not DOM — see `react-graph-visualization`).

---

## Part 4 — Code-Splitting & Bundle Budgets

The fastest code is the code you don't ship on first load.

- **Route-level splitting** (`lazy` + `Suspense`) — the primary boundary (see `react-routing`). Each page is its own chunk.
- **Component-level splitting** — for heavy components not always shown: the estate graph, a rich editor, a charting bundle. `lazy()` them so they load on demand.
- **Tree-shaking** — side-effect-free ES modules and explicit type-only imports (see `react-project-structure`) let the bundler drop unused code. Import named members, not whole namespaces.
- **Bundle budgets** — set a size budget in CI (e.g., initial JS < 200KB gzipped). A PR that blows the budget fails, forcing a deliberate decision. The bundle visualizer shows the culprit.

```tsx
const EstateGraph = lazy(() => import("@/features/estate-graph/EstateGraph")); // heavy WebGL chunk, on demand
```

---

## Part 5 — Memory-Leak Prevention

The blueprint's §4: orphaned listeners, un-cleared timers, and detached DOM nodes leak memory in a long-lived SPA. Every effect that subscribes must clean up.

```tsx
useEffect(() => {
  const ctrl = new AbortController();
  window.addEventListener("resize", onResize, { signal: ctrl.signal });
  const id = setInterval(poll, 30_000);
  return () => { ctrl.abort(); clearInterval(id); }; // cleanup — no orphaned listener/timer
}, [onResize]);
```

Rules: every `addEventListener`/`setInterval`/`setTimeout`/subscription has a matching cleanup in the effect's return; abort in-flight fetches on unmount (the API client forwards the signal — see `react-api-client`); verify with a heap snapshot before/after mounting and unmounting a screen repeatedly — live node count must return to baseline.

---

## Core Web Vitals Connection

These techniques map directly to the user-experienced metrics tracked in `react-observability`:
- Code-splitting + bundle budgets → **LCP** (faster first paint)
- Re-render minimization + avoiding long tasks → **INP** (responsive interactions)
- Reserved space for async content (skeletons sized to content) → **CLS** (no layout shift)

Optimisation targets the metric, not a vanity number.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Measure-first | Optimisations backed by a profile/flame graph | Memoization sprinkled on by guesswork |
| Targeted memoization | `memo`/`useMemo`/`useCallback` where profiled | Everything memoized; or nothing stabilised |
| Virtualization | Large lists/tables windowed | Thousands of DOM rows rendered |
| Code-split | Routes + heavy components lazy-loaded; budget enforced | One giant initial bundle; no budget |
| Leak-free | Every subscription/timer/fetch cleaned up | Orphaned listeners/timers; growing heap |
| Vitals-oriented | Work tied to LCP/INP/CLS | Optimising numbers users don't feel |

---

## Output Format

Produces optimised React code plus the evidence for non-obvious optimisations:

```
src/**/*.tsx                       (virtualized lists, lazy boundaries, justified memoization)
vite.config.ts                     (manualChunks, visualizer, bundle budget)
docs/perf/<screen>-profile.md      (DevTools/flame-graph evidence for non-trivial optimisations)
```
