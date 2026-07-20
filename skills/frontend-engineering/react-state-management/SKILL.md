---
name: react-state-management
description: >
  Teaches how to architect state in a React app — the server-state vs client-state
  distinction (server data is a cache, managed by TanStack Query; client state is
  local UI state), state co-location to the closest shared ancestor, when to reach
  for a client-state library (Zustand/Jotai) vs Context, optimistic updates, cache
  invalidation, and avoiding re-render storms. Wrong state architecture is the
  root of most React performance and correctness bugs. Used by the frontend-engineer
  during Implement.
version: 1.1.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, state, tanstack-query, zustand, server-state, caching]
---

# React State Management

## Purpose

Most React bugs — stale data, re-render storms, impossible UI states — come from treating all state as one thing. It isn't. The single most important decision is recognising that **server state and client state are different problems** with different tools. Get that split right and the rest of the architecture falls into place.

This skill defines how state is organised; `react-performance-optimization` covers the rendering consequences, and `typescript-types` covers modeling state shape with discriminated unions.

---

## The Core Distinction: Server State vs Client State

| | Server state | Client state |
|---|---|---|
| Source of truth | The backend | The browser/session |
| Examples | data assets, compliance gaps, reports | modal open, selected tab, form draft, filters |
| Lifetime | Can become stale; must be re-fetched/invalidated | Lives and dies with the UI |
| Tool | **TanStack Query** (cache) | local `useState` → Context → Zustand, by need |

**Server data is a cache, not application state.** You do not "own" it — the server does. Copying server data into a client store (Redux, Zustand) and hand-syncing it is the classic mistake: it creates two sources of truth that drift. Let a query cache own server data.

---

## Server State with TanStack Query

TanStack Query manages the server cache: fetching, caching, background refetch, retry, polling, and invalidation. Data-fetching hooks live in each feature's `api.ts` and wrap the typed API client (see `react-api-client`).

```ts
// src/features/data-assets/api.ts
export function useDataAssets(filter: AssetFilter) {
  return useQuery({
    queryKey: ["data-assets", filter],          // cache key — refetches when filter changes
    queryFn: ({ signal }) => api.listDataAssets(filter, signal), // signal → request cancellation
    staleTime: 30_000,                          // fresh for 30s; no refetch storm on remount
  });
}

export function useClassifyDataAsset() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, level }: ClassifyArgs) => api.classifyDataAsset(id, level),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["data-assets"] }), // re-fetch the list
  });
}
```

Query keys are structured and consistent (`["data-assets", filter]`) so invalidation is precise. The `signal` is forwarded to the client so an in-flight request is **cancelled** when the component unmounts or the query key changes — no wasted work, no setting state on an unmounted component.

Two refinements worth knowing:

- **Paginated/filterable lists**: `placeholderData: keepPreviousData` (the v5 idiom) keeps the previous page's rows on screen while the next page loads — no flash to a skeleton on every filter change.
- **Detail views**: `useSuspenseQuery` guarantees `data` is defined and moves pending/error handling out to the nearest `<Suspense>` / error boundary — the component body reads as the success case only. Use it where a Suspense boundary already exists (e.g., a routed detail page); plain `useQuery` with `isPending` elsewhere.

### Optimistic updates

For instant-feeling mutations, update the cache before the server responds and roll back on error:

```ts
useMutation({
  mutationFn: classifyFn,
  onMutate: async ({ id, level }) => {
    await qc.cancelQueries({ queryKey: ["data-assets"] });
    const prev = qc.getQueryData<DataAsset[]>(["data-assets"]);
    qc.setQueryData<DataAsset[]>(["data-assets"], (old) => applyClassification(old, id, level)); // optimistic
    return { prev };
  },
  onError: (_e, _v, ctx) => qc.setQueryData(["data-assets"], ctx?.prev), // rollback
  onSettled: () => qc.invalidateQueries({ queryKey: ["data-assets"] }),  // reconcile with server
});
```

This pairs with the backend's idempotency (the same classify command is safe to retry — see `go-service-layer`).

---

## Client State: Co-locate First

The default for client state is `useState` in the component that needs it. Only lift it when more than one component must share it — and only as far as the **closest common ancestor**. Lifting state higher than necessary causes unrelated subtrees to re-render.

```
Selected-rows state needed by Toolbar + Table?
  → lift to their nearest shared parent (the list page), not to the app root.
```

This is **state co-location**: keep state as close as possible to where it's used. It minimises re-render scope and keeps features self-contained.

---

## When to Reach for a Client-State Library

Escalate only when co-location and Context genuinely fall short:

| Need | Tool |
|---|---|
| Single component's state | `useState` / `useReducer` |
| A few nearby components | Lift to nearest common ancestor |
| Low-frequency global value (theme, current user, tenant) | Context |
| **Cross-cutting client state read/written widely, where Context causes re-render storms** | **Zustand** (default) or Jotai |

The trigger for Zustand/Jotai is specifically **excessive re-rendering from Context** — when a frequently-changing value in Context re-renders every consumer. Zustand lets components subscribe to just the slice they use, so only those re-render.

```ts
// A Zustand store for cross-cutting UI state (selection that spans features)
const useSelectionStore = create<SelectionState>((set) => ({
  selectedIds: new Set<string>(),
  toggle: (id) => set((s) => {
    const next = new Set(s.selectedIds);
    if (!next.delete(id)) next.add(id);   // delete returns false if absent → add
    return { selectedIds: next };
  }),
}));

// component subscribes to ONLY what it needs → no re-render on unrelated changes
const count = useSelectionStore((s) => s.selectedIds.size);
```

Zustand is the default (tiny, hook-based, no boilerplate, no provider). Jotai (atomic) is an acceptable alternative for fine-grained derived-atom graphs. Redux is not a default — its boilerplate rarely justifies itself here.

---

## URL as State

Filters, sort, pagination, and the selected record belong in the **URL**, not a store — so views are shareable, bookmarkable, and survive refresh (see `react-routing`). The IA's URL structure defines these query params. Read them from the router and feed them into query keys.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Server/client split | Server data in TanStack Query; client state separate | Server data mirrored into a client store |
| Co-location | State lifted only to the nearest shared ancestor | State hoisted to the root "just in case" |
| Library justified | Zustand/Jotai only when Context re-renders hurt | Redux/Zustand for everything by default |
| Precise invalidation | Structured query keys; targeted invalidation | Blanket cache clears / manual refetch sprawl |
| Cancellation | `signal` forwarded; in-flight requests cancel | Requests racing on stale state |
| URL state | Filters/sort/pagination in the URL | Shareable view state trapped in component state |

---

## Anti-Patterns

| Anti-pattern | Instead |
|---|---|
| Server data copied into Zustand/Redux and hand-synced | Let TanStack Query own server data |
| One giant global store for everything | Co-locate; store only true cross-cutting client state |
| Context for high-frequency values | Zustand with slice selectors |
| `useEffect` to "sync" derived data | Derive during render; or use a query |
| Filters in component state | Filters in the URL |

---

## Output Format

Produces state hooks/stores and their tests:

```
src/features/<feature>/api.ts          (TanStack Query hooks)
src/shared/stores/*.ts                  (Zustand stores for cross-cutting client state)
*.test.ts(x)                            (hook tests with MSW; written first)
```
