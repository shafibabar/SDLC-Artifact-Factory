---
name: react-state-management
description: >
  Teaches how to architect state in a React app within this plugin's shell
  + remotes microfrontend layout — the server-state-vs-client-state
  boundary standard (a precise litmus test: did this value originate from
  the backend and can it go stale, or is it UI-only with no server source
  of truth), the TanStack Query cache-invalidation standard (the exact
  invalidateQueries-on-mutation convention and staleTime/gcTime tuning
  rationale), the Context performance-cost model (why a fresh
  object-literal Provider value re-renders every consumer regardless of
  which field it reads, and its fix via context-splitting, value
  memoization, or a selector-based store), state co-location to the
  closest shared ancestor, when to reach for a client-state library
  (Zustand/Jotai) vs Context, and — the question the single-app version of
  this skill was silent on — cross-fragment state isolation: why both the
  query cache and any client-state store stay fragment-local, never
  shared, and what actually crosses a fragment boundary (the shell
  context, custom events). Wrong state architecture is the root of most
  React performance and correctness bugs. Used by the frontend-engineer
  during Implement.
version: 2.1.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, state, tanstack-query, zustand, server-state, caching, microfrontend]
related: [microfrontend-architecture, react-performance-optimization, typescript-types, react-routing, react-component-design]
---

# React State Management

## Purpose

Most React bugs — stale data, re-render storms, impossible UI states —
come from treating all state as one thing. It isn't: **server state and
client state are different problems** with different tools, additionally
scoped **per fragment** in this plugin's microfrontend layout, never
shared across boundaries. Get both splits right and the rest falls into
place. `react-performance-optimization` covers rendering consequences;
`typescript-types` covers modeling state shape; `microfrontend-
architecture`/`react-routing` own the shell context and fragment
boundaries this skill's cross-fragment rules depend on.

---

## The Litmus Test: Server State vs Client State

**Did this value originate from the backend, and can it become stale
relative to the server's own copy? If yes, TanStack Query owns it — never
copy it into `useState`/Zustand and hand-sync it, which creates two
sources of truth that drift. If it's UI-only with no server source of
truth, local state or a client store owns it, full stop.**

| | Server state | Client state |
|---|---|---|
| Source of truth | The backend | The browser/session |
| Examples | data assets, compliance gaps, reports | modal open, selected tab, form draft, filters |
| Lifetime | Can become stale; must be re-fetched/invalidated | Lives and dies with the UI |
| Tool | **TanStack Query** (cache) | local `useState` → Context → Zustand, by need |
| Scope | **One fragment's own `QueryClient`** — never shared | **One fragment** — never a cross-fragment store |

Three ambiguous-looking cases resolve cleanly under the test: a
**derived/sorted view of server data** stays server state (derive during
render, never `useEffect`-sync a copy); an **optimistic edit** is
transiently client-shaped until submit, then a cache write; a **form
draft** is pure client state until submit, even though its destination is
the server. Full reasoning: `references/tanstack-query-patterns.md`.

---

## Server State with TanStack Query

Data-fetching hooks live in each fragment's own feature's `api.ts`,
wrapping the typed API client (`packages/api-client`, see
`react-api-client`). Structured query keys, request cancellation via
`signal`, pagination/Suspense refinements, and optimistic updates:
`references/tanstack-query-patterns.md`.

**Cache-invalidation standard, in one rule**: every mutation's
`onSuccess` invalidates the precise query key(s) it affects — never a
bare `invalidateQueries()` with no key, never `queryClient.clear()`.
`staleTime` (freshness before a background refetch) and `gcTime` (v5;
`cacheTime` in v4 — how long *unused* data survives before garbage
collection) are different knobs: tune `staleTime` by how often data
changes from *outside* this client's own actions, and let explicit
invalidation handle changes this client causes itself. Concrete per-query
values and rationale: same reference file.

---

## Client State: Co-locate First, Escalate Only When Justified

The default is `useState` in the component that needs it — **state
co-location**. Lift only when more than one component **within the same
fragment** must share it, only as far as the closest common ancestor;
lifting further than necessary widens the re-render blast radius, and
lifting across a fragment boundary isn't possible at all (Cross-Fragment
State below). Escalate past co-location only when the next tier's
specific condition holds:

| Need | Tool |
|---|---|
| Single component's state | `useState` / `useReducer` |
| A few nearby components, same fragment | Lift to nearest common ancestor |
| Low-frequency value shared across one fragment (a modal's open state) | Context |
| Cross-cutting client state read/written widely **within one fragment**, where Context causes re-render storms | **Zustand** (default) or Jotai — fragment-local |

The trigger for Zustand/Jotai is **excessive re-rendering from Context**,
never that a pattern looks more sophisticated. **No tier on this table
spans more than one fragment** — see Cross-Fragment State. Code example:
`references/tanstack-query-patterns.md`.

---

## Context Performance Cost

**Context's cost is structural, not incidental: `useContext` gives no way
to select a slice of the Provider's value, so every consumer re-renders on
any change to it — whether or not the field it reads changed.** The
sharpest, easiest-to-miss version: a Provider `value` recreated as a fresh
object literal every render defeats React's bail-out optimizations, since
the reference changes regardless of whether any field inside it did —
the exact model Banks & Porcello's *Learning React* (2nd ed.) independently
describes; this skill's Client-State Library table and Anti-Patterns
already matched it before the book was consulted to ground it.

Three fixes, ascending cost — worked before/after (three filters, one
Context, fixed by memoizing, then splitting, then escalating):
`references/context-cost-and-mitigation.md`.

| Fix | Solves | Doesn't solve |
|---|---|---|
| Memoize the value (`useMemo`) | Phantom re-renders from an unrelated Provider re-render | Consumers still all re-render when any genuinely-independent field changes |
| Split into narrower Contexts | Independent fields stop re-rendering each other's consumers | Large consumer sets or high-frequency updates |
| Escalate to a selector-based store | Per-consumer subscription regardless of store size/frequency | Nothing past this tier within one fragment |

---

## Cross-Fragment State

The question the single-app version of this skill didn't need to answer:
what happens when two independently-built, independently-deployed
fragments both need state? Short answer — **neither the query cache nor
any client-state store ever spans a fragment boundary.** Each fragment
owns its own `QueryClient`; a duplicated fetch is an accepted cost, not a
bug to engineer around by sharing a cache. Only the shell context (narrow,
versioned, read-mostly) and custom events (the rare cross-fragment
notification) legitimately cross a boundary. Full rationale, the worked
failure mode of sharing a `QueryClient` anyway, and the reviewer
checklist: `references/cross-fragment-state.md`.

---

## URL as State

Filters, sort, pagination, and the selected record belong in the **URL**,
not a store — shareable, bookmarkable, and refresh-survivable (see
`react-routing`). Applies at the shell's top-level mapping and within each
fragment's own route tree alike. Read them from the router; feed them
into query keys.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Server/client split, incl. edge cases | Server data in TanStack Query, derived views/optimistic edits/drafts placed per the litmus test | Server data mirrored into a client store; a derived value effect-synced |
| Query cache scope | Each fragment owns its own `QueryClient` | A shared `QueryClient` across fragment boundaries |
| Cache invalidation, `staleTime`/`gcTime` | Every mutation invalidates the precise key(s) it affects; both knobs tuned per query with a stated rationale | Bare `invalidateQueries()`/`queryClient.clear()`; defaults left everywhere unexamined |
| Client-state store scope | Zustand/Jotai/Context stores stay within one fragment | A store spanning more than one fragment |
| Co-location | State lifted only to the nearest shared ancestor within one fragment | State hoisted to the root "just in case" |
| Library and Context-cost fix escalation order | Memoize → split → Zustand/Jotai, each tried before the next | Reaching for a store before trying memoization/splitting; Redux/Zustand by default |
| Cross-fragment reads | Shell context only, narrow and read-mostly | A fragment reading another fragment's store/cache directly |
| URL state | Filters/sort/pagination in the URL, at every level | Shareable view state trapped in component state |

---

## Anti-Patterns

| Anti-pattern | Instead |
|---|---|
| Server data copied into Zustand/Redux and hand-synced, or `useEffect`-synced into local state | Let TanStack Query own server data; derive during render or via the query's `select` |
| Sharing a `QueryClient` instance across fragments to avoid duplicate fetches | Each fragment owns its cache; accept the duplication |
| A blanket `invalidateQueries()`/`queryClient.clear()`, or `staleTime`/`gcTime` left at defaults for data with an obvious change cadence | Invalidate the precise key(s) affected; tune both knobs per query with a stated rationale |
| A Zustand/Context store imported by more than one fragment | Fragment-local only; shell context or events for the rare cross-fragment need |
| A Context `value` recreated as a fresh object literal every render | Memoize it; split narrower; or escalate to a selector-based store |
| One giant global store for everything within a fragment | Co-locate; store only true cross-cutting client state for that fragment |
| Filters in component state | Filters in the URL |

---

## Output Format

Produces state hooks/stores and their tests, per fragment:

```
apps/<fragment>/src/features/<feature>/api.ts   (TanStack Query hooks, own QueryClient)
apps/<fragment>/src/shared/stores/*.ts           (Zustand stores, fragment-local only)
apps/shell/src/shell-context/                    (the narrow, versioned, read-mostly shared context)
*.test.ts(x)                                     (hook tests with MSW; written first)
```
