---
name: react-performance-optimization
description: >
  Teaches measure-first React performance work as a hard gate plus four
  standards: the React DevTools Profiler workflow (record an interaction,
  read the flame graph and "why did this render" reasons before touching
  any code); the memoization standard — exact payoff criteria for
  React.memo/useMemo/useCallback and the shallow-comparison caveat that
  makes memo a silent no-op; code-splitting, which cross-references
  react-routing's lazy-loading standard rather than duplicating it;
  virtualization, which cross-references react-dashboard-components's
  windowing standard rather than duplicating it; memory-leak prevention
  (effect cleanup); and concurrent scheduling (useDeferredValue/
  useTransition) for renders that stay expensive after profiling-justified
  fixes. No optimization ships without a before/after Profiler or
  Lighthouse measurement. Used by the frontend-engineer during Implement.
version: 2.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, performance, memoization, virtualization, code-splitting, profiling]
produces: react-performance-optimization
domain: frontend
status: stable
related: [react-routing, react-dashboard-components, react-state-management, react-api-client, react-observability]
---

# React Performance Optimization

## Purpose

Frontend performance is the discipline of cooperating with the browser's critical rendering path and React's reconciliation model, combined with measurement — the two are inseparable. This skill states four standards plus the hard gate that governs all of them: the **Profiler workflow** (how to find the real bottleneck), the **memoization standard** (exact conditions under which `React.memo`/`useMemo`/`useCallback` earn their complexity cost), **code-splitting** and **virtualization** (each cross-referenced to the skill that owns its worked implementation, not duplicated here), **memory-leak prevention**, and **concurrent scheduling**. Full procedure and worked examples: `references/profiler-workflow-and-memoization-standard.md`, `references/memory-leak-and-concurrent-scheduling.md`.

---

## The Measure-First Gate

**No optimization change ships without a before/after measurement showing the actual improvement.** This mirrors `go-performance-optimization`'s own governing rule ("you do not optimise code you have not profiled, and you do not claim a speedup you have not benchmarked") applied to the frontend's tools: the React DevTools Profiler for render cost, the Performance panel / Lighthouse for page-level metrics. A `memo`, a `lazy()` boundary, or a virtualized list added on intuition — without a profile identifying it as the actual bottleneck, and a re-measurement confirming the fix — is a defect, not a stylistic preference, exactly as an unbenchmarked Go optimization is on the backend.

---

## Standard 1 — React DevTools Profiler Workflow

Record the exact interaction under investigation, find the commit with the longest bar, open that component's **"Why did this render?"** panel before writing any code. It reports one of four reasons: **props changed**, **state changed**, **parent re-rendered** (the case memoization targets), or **context changed**. Only a repeated, expensive "parent re-rendered" case justifies a memoization decision. Full step-by-step procedure: `references/profiler-workflow-and-memoization-standard.md`.

| Tool | Finds |
|---|---|
| React DevTools Profiler | Which components rendered, why, and the commit's expensive component |
| Performance panel | Long tasks (>50ms), layout thrash, the critical rendering path |
| Memory → heap snapshots | Leaks: detached DOM nodes, retained closures, growing listener counts |
| Coverage panel / bundle visualizer | Unused JS shipped on first load — code-splitting candidates |

---

## Standard 2 — Memoization: Exact Payoff Criteria

Each tool below adds a cost (a comparison or a cache) in exchange for skipping work — apply it **only** where the Profiler shows a real, repeated, expensive re-render it would fix:

| Tool | Earns its cost only when |
|---|---|
| `React.memo` | Component re-renders often with unchanged props (profiler-confirmed) **and** its render is expensive enough that skipping it beats the comparison cost |
| `useMemo` | The computation is expensive, **or** the value is a prop passed to a `memo`'d child, **or** it appears in another hook's dependency array |
| `useCallback` | The function is a prop passed to a `memo`'d child, **or** it appears in an effect's/hook's dependency array |

**The shallow-comparison caveat:** `React.memo` compares props with `Object.is`, one level deep. An inline object/array/function literal created fresh in the parent's render (`style={{ color: "red" }}`, `onClick={() => ...}`) has a new reference every render even when its content is identical — the comparison reports "changed" every time and the memoized child re-renders anyway, silently defeating the `memo`. Fix at the source: hoist the literal to module scope if it never varies, or wrap it in `useMemo`/`useCallback` in the parent if it does. A worked broken-then-fixed example (a `DataAssetRow` wrapped in `memo` that still re-renders on every keystroke in an unrelated search box, then fixed): `references/profiler-workflow-and-memoization-standard.md`.

**Do not** wrap everything in `memo`/`useMemo`/`useCallback` "for safety" — each has a real cost and clutters the code for zero benefit on a cheap component. Prefer the cheaper fixes first: **state co-location** (fewer components in the re-render path — see `react-state-management`) and **passing JSX as `children`** (children don't re-render when the parent's own state changes).

---

## Standard 3 — Code-Splitting

**Owned by `react-routing`'s Standard 2** (lazy-loading and code-splitting): route-level `lazy`/`Suspense` boundaries, component-level splitting for heavy features not always visible, and the distinction between Module Federation's own async-chunk boundary and an in-remote `React.lazy`. This skill does not restate that standard — apply it by name, and verify any split with a bundle visualizer (a new chunk that the initial bundle no longer contains), not by assumption. Set and enforce a bundle-size budget in CI (e.g., initial JS < 200KB gzipped); a PR that blows it fails, forcing a deliberate decision.

---

## Standard 4 — Virtualization

**Owned by `react-dashboard-components`'s data-table standard**: virtualize once a table's realistic unfiltered row count can reach roughly 200 rows; below that, plain pagination is sufficient. Default to `react-virtuoso`, or `react-component-design`'s `VirtualizedList` render-props shape when a shared scroll container is needed — call either by name, never reimplement windowing here. The estate graph has its own large-data strategy (WebGL canvas, not DOM windowing — see `react-graph-visualization`).

---

## Standard 5 — Memory-Leak Prevention

Every effect that subscribes to something external (`addEventListener`, `setInterval`/`setTimeout`, a WebSocket, an in-flight `fetch`) returns a cleanup that reverses it — an `AbortController` can cover both a listener and a fetch in one cleanup call. Verify with a heap snapshot before/after mounting and unmounting a screen repeatedly: live node count must return to the same baseline each cycle, not grow monotonically. Full worked cleanup example: `references/memory-leak-and-concurrent-scheduling.md`.

---

## Standard 6 — Concurrent Scheduling

Some renders stay expensive even after profiling-justified memoization and virtualization — re-filtering thousands of rows as the user types is real work that has to happen somewhere. `useDeferredValue` defers a **value** driving an expensive render (search/filter results); `startTransition`/`useTransition` mark a **state update** itself as non-urgent (a heavy tab switch), with `isPending` driving a busy indicator. These change **scheduling**, not the amount of work — they complement memoization and virtualization and never substitute for them; reach for them only after profiling confirms the interaction is still blocked once those are applied. Full worked example: `references/memory-leak-and-concurrent-scheduling.md`.

---

## Core Web Vitals Connection

- Code-splitting + bundle budgets → **LCP** (faster first paint)
- Memoization + virtualization + concurrent scheduling + avoiding long tasks → **INP** (responsive interactions)
- Reserved space for async content (skeletons sized to content) → **CLS** (no layout shift)

Optimisation targets the metric users feel, not a vanity number.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Measure-first gate | Every optimisation backed by a before/after Profiler/Lighthouse measurement | Optimisation shipped on intuition, with no re-measurement |
| Profiler workflow followed | "Why did this render?" checked before any memoization decision | Memoization applied without reading the reason React re-rendered |
| Memoization targeted | `memo`/`useMemo`/`useCallback` applied only where profiled-expensive and repeated | Everything memoized; or nothing stabilised where the profiler shows a real cost |
| Shallow-comparison caveat respected | Inline literals hoisted or memoized at the source before wrapping a child in `memo` | `memo`'d child still re-renders because the parent hands it a fresh literal every render |
| Code-splitting per `react-routing` | Routes + heavy components lazy-loaded; no redundant re-`lazy()` of a federation boundary; budget enforced | One giant initial bundle; no budget; double-wrapped federation import |
| Virtualization per `react-dashboard-components` | Tables at/above the ~200-row anchor windowed via `react-virtuoso`/`VirtualizedList` | Thousands of DOM rows rendered; windowing reimplemented ad hoc |
| Leak-free | Every subscription/timer/fetch cleaned up; heap snapshot confirms baseline returns | Orphaned listeners/timers; growing heap across mount/unmount cycles |
| Concurrent scheduling justified | `useDeferredValue`/`useTransition` applied only after memoization/virtualization still leave an interaction blocked | Reached for as a first response instead of fixing the underlying expensive render |
| Vitals-oriented | Work tied to LCP/INP/CLS | Optimising numbers users don't feel |

---

## Anti-Patterns

| Anti-pattern | Instead |
|---|---|
| `useMemo`/`useCallback` on everything "for safety" | Memoize only what the Profiler shows re-rendering wastefully |
| Memoizing a child but passing a fresh object/array/function literal each render | Hoist or memoize the literal at the source — the shallow comparison never passes otherwise |
| Reaching for `memo` before checking "Why did this render?" | Read the reason first; only "Parent re-rendered," repeated and expensive, justifies memoization |
| Rendering thousands of DOM rows because "it works on my machine" | Virtualize per `react-dashboard-components`'s threshold; test with production-scale data |
| Re-`lazy()`-wrapping a Module Federation remote already async-chunked | Apply `react-routing`'s Standard 2 as written — one boundary, not two |
| Reaching for `useDeferredValue`/`useTransition` before memoization/virtualization | Fix the underlying expensive or unvirtualized render first; scheduling APIs don't reduce work |
| Optimising without a before/after measurement | Profile, fix, **re-measure** — evidence or it didn't happen |
| `setInterval`/listener/subscription without cleanup | Every effect that subscribes returns a cleanup |

---

## Output Format

Produces optimised React code plus the evidence for non-obvious optimisations, covering both memory and execution-time work:

```
src/**/*.tsx                       (memoization justified by profile; lazy boundaries and
                                     virtualized lists applied per react-routing / react-
                                     dashboard-components rather than reimplemented; cleaned-
                                     up effects; useDeferredValue/useTransition where profiled)
vite.config.ts                     (manualChunks, bundle visualizer, bundle-size budget)
docs/perf/<screen>-profile.md      (before/after Profiler flame graph or Lighthouse score —
                                     the measure-first gate's evidence, per optimisation)
```
