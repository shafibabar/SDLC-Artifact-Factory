---
name: react-state-management
description: >
  Teaches how to architect state in a React app within this plugin's shell
  + remotes microfrontend layout — the server-state vs client-state
  distinction (server data is a cache, managed by TanStack Query; client
  state is local UI state), state co-location to the closest shared
  ancestor, when to reach for a client-state library (Zustand/Jotai) vs
  Context, optimistic updates, cache invalidation, and — the question the
  single-app version of this skill was silent on — cross-fragment state:
  why both the query cache and any client-state store stay fragment-local,
  never shared, and what actually crosses a fragment boundary (the shell
  context, custom events). Wrong state architecture is the root of most
  React performance and correctness bugs. Used by the frontend-engineer
  during Implement.
version: 2.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, state, tanstack-query, zustand, server-state, caching, microfrontend]
---

# React State Management

## Purpose

Most React bugs — stale data, re-render storms, impossible UI states —
come from treating all state as one thing. It isn't. The single most
important decision is recognising that **server state and client state
are different problems** with different tools — and in this plugin's
microfrontend layout, both are additionally scoped **per fragment**, never
shared across fragment boundaries. Get both splits right and the rest of
the architecture falls into place.

This skill defines how state is organised; `react-performance-optimization`
covers the rendering consequences, `typescript-types` covers modeling
state shape with discriminated unions, and
`microfrontend-architecture`/`react-routing` cover the shell context and
fragment boundaries this skill's cross-fragment rules depend on.

---

## The Core Distinction: Server State vs Client State

| | Server state | Client state |
|---|---|---|
| Source of truth | The backend | The browser/session |
| Examples | data assets, compliance gaps, reports | modal open, selected tab, form draft, filters |
| Lifetime | Can become stale; must be re-fetched/invalidated | Lives and dies with the UI |
| Tool | **TanStack Query** (cache) | local `useState` → Context → Zustand, by need |
| Scope | **One fragment's own `QueryClient`** — never shared | **One fragment** — never a cross-fragment store |

**Server data is a cache, not application state.** You do not "own" it —
the server does. Copying server data into a client store (Redux, Zustand)
and hand-syncing it is the classic mistake: it creates two sources of
truth that drift. Let a query cache own server data — and let each
fragment's cache stay that fragment's own.

---

## Server State with TanStack Query

TanStack Query manages the server cache: fetching, caching, background
refetch, retry, polling, and invalidation. Data-fetching hooks live in
each fragment's own feature's `api.ts` and wrap the typed API client
(`packages/api-client`, see `react-api-client`). Structured query keys,
request cancellation via `signal`, pagination/Suspense refinements, and
optimistic updates: `references/tanstack-query-patterns.md`.

---

## Client State: Co-locate First

The default for client state is `useState` in the component that needs
it. Only lift it when more than one component **within the same
fragment** must share it — and only as far as the closest common
ancestor. Lifting state higher than necessary causes unrelated subtrees to
re-render; lifting it across a fragment boundary isn't possible at all
(see Cross-Fragment State below).

```
Selected-rows state needed by Toolbar + Table, both inside one fragment?
  → lift to their nearest shared parent (the list page), not to the app root.
```

This is **state co-location**: keep state as close as possible to where
it's used.

---

## When to Reach for a Client-State Library

Escalate only when co-location and Context genuinely fall short — and
only within one fragment:

| Need | Tool |
|---|---|
| Single component's state | `useState` / `useReducer` |
| A few nearby components, same fragment | Lift to nearest common ancestor |
| Low-frequency value shared across one fragment (a modal's open state) | Context |
| Cross-cutting client state read/written widely **within one fragment**, where Context causes re-render storms | **Zustand** (default) or Jotai — fragment-local |

The trigger for Zustand/Jotai is specifically **excessive re-rendering
from Context** — Zustand lets components subscribe to just the slice they
use. **A Zustand/Context/any store spanning more than one fragment is not
on this table at any tier** — see Cross-Fragment State. Full code example:
`references/tanstack-query-patterns.md`.

---

## Cross-Fragment State

The question the single-app version of this skill didn't need to answer:
what happens when two independently-built, independently-deployed
fragments both need state? Short answer — **neither the query cache nor
any client-state store ever spans a fragment boundary.** Each fragment
owns its own `QueryClient`; a duplicated fetch across fragments is an
accepted cost, not a bug to engineer around by sharing a cache. The only
things that legitimately cross a boundary are the shell context (narrow,
versioned, read-mostly — current user, tenant, feature flags) and custom
events for the rare cross-fragment notification. Full rationale, code, and
the accepted-cost framing: `references/cross-fragment-state.md`.

---

## URL as State

Filters, sort, pagination, and the selected record belong in the **URL**,
not a store — so views are shareable, bookmarkable, and survive refresh
(see `react-routing`). This applies at both the shell's top-level mapping
and within each fragment's own route tree — the IA's URL structure
defines these query params regardless of which app owns that segment.
Read them from the router and feed them into query keys.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Server/client split | Server data in TanStack Query; client state separate | Server data mirrored into a client store |
| Query cache scope | Each fragment owns its own `QueryClient` | A shared `QueryClient` across fragment boundaries |
| Client-state store scope | Zustand/Jotai/Context stores stay within one fragment | A store spanning more than one fragment |
| Co-location | State lifted only to the nearest shared ancestor within one fragment | State hoisted to the root "just in case" |
| Library justified | Zustand/Jotai only when Context re-renders hurt | Redux/Zustand for everything by default |
| Precise invalidation | Structured query keys; targeted invalidation, per-fragment | Blanket cache clears / manual refetch sprawl |
| Cross-fragment reads | Shell context only, narrow and read-mostly | A fragment reading another fragment's store/cache directly |
| URL state | Filters/sort/pagination in the URL, at every level | Shareable view state trapped in component state |

---

## Anti-Patterns

| Anti-pattern | Instead |
|---|---|
| Server data copied into Zustand/Redux and hand-synced | Let TanStack Query own server data |
| Sharing a `QueryClient` instance across fragments to avoid duplicate fetches | Each fragment owns its cache; accept the duplication |
| A Zustand/Context store imported by more than one fragment | Fragment-local only; shell context or events for the rare cross-fragment need |
| One giant global store for everything within a fragment | Co-locate; store only true cross-cutting client state for that fragment |
| Context for high-frequency values | Zustand with slice selectors |
| `useEffect` to "sync" derived data | Derive during render; or use a query |
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
