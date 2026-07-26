# TanStack Query Patterns

Full server-state code — unchanged from the single-app model; split out
here as substantial worked code, not because it's microfrontend-specific.
Self-contained — loadable without reading `SKILL.md` first.

---

## The Server-State vs Client-State Litmus Test, With Edge Cases

`SKILL.md`'s core rule: if a value originated from the backend and can
become stale relative to the server, TanStack Query owns it; if it's
UI-only with no server source of truth, local `useState`/`useReducer` or a
fragment-local client store owns it. Three cases that look ambiguous but
aren't:

- **A derived/sorted/filtered view of server data** (a sorted column, a
  filtered subset) is still server state — derive it from the query's
  `data` during render (or via `select` on the query itself), never copy
  it into `useState` and `useEffect`-sync it. Syncing is the stale-closure
  trap: the copy silently drifts from the query cache the moment the
  server data refetches and the effect hasn't re-run yet.
- **An in-progress optimistic edit** (a table cell mid-inline-edit) is the
  one case client and server state cooperate: it's transiently
  client-shaped until submit, then becomes an optimistic cache write (see
  Optimistic Updates below) — not a permanent client-state home.
- **A multi-step form wizard's draft** has no server source of truth until
  final submit — pure client state for its entire lifetime up to that
  point, even though its *eventual* destination is the server.

---

## Basic Query and Mutation

```ts
// apps/data-assets/src/features/data-assets/api.ts
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

Query keys are structured and consistent (`["data-assets", filter]`) so
invalidation is precise. The `signal` is forwarded to the client so an
in-flight request is **cancelled** when the component unmounts or the
query key changes — no wasted work, no setting state on an unmounted
component.

Two refinements worth knowing:

- **Paginated/filterable lists**: `placeholderData: keepPreviousData` (the
  v5 idiom) keeps the previous page's rows on screen while the next page
  loads — no flash to a skeleton on every filter change.
- **Detail views**: `useSuspenseQuery` guarantees `data` is defined and
  moves pending/error handling out to the nearest `<Suspense>` / error
  boundary — the component body reads as the success case only. Use it
  where a Suspense boundary already exists (e.g., a routed detail page);
  plain `useQuery` with `isPending` elsewhere.

---

## Cache-Invalidation Standard

**The convention: every mutation's `onSuccess` (or `onSettled`) invalidates
the precise query key(s) it affects — never a bare `invalidateQueries()`
with no key, and never `queryClient.clear()`.** Both blanket forms
re-fetch (or discard) data the mutation had no effect on, turning one
user's classify action into a network storm across every screen holding a
query. The `useClassifyDataAsset` example above is the standard's minimum
shape: it scopes the invalidation to `["data-assets"]`, not to every query
in the cache.

A mutation that affects more than one resource invalidates each key it
actually touches, individually:

```ts
onSuccess: (_, { id }) => {
  qc.invalidateQueries({ queryKey: ["data-assets", id] });      // the detail view
  qc.invalidateQueries({ queryKey: ["compliance-gaps"] });      // classifying can close a gap
},
```

### `staleTime` vs `gcTime`: Two Different Knobs

These tune different things and are frequently confused:

| Knob | Governs | Effect when exceeded |
|---|---|---|
| `staleTime` | How long fetched data is considered **fresh** | Once stale, the next mount/window-refocus triggers a background refetch |
| `gcTime` (TanStack Query v5; `cacheTime` in v4) | How long **unused** data (zero active observers) stays in memory | Once exceeded with no observer, the cache entry is garbage-collected — the next mount is a full fetch, not a cache hit |

`staleTime: 0` (the default) means every mount refetches in the
background — fine for cheap, frequently-changing data; wasteful for data
that rarely changes. `gcTime` is irrelevant while a query has an active
observer (a mounted component reading it); it only matters for data
sitting inactive — a detail page the user navigated away from and might
return to.

### Tuning Rationale for This App's Domain

| Query | `staleTime` | `gcTime` | Why |
|---|---|---|---|
| `data-assets` list/detail | 30s | 5 min (default) | Changes via classification actions taken elsewhere in the UI; explicit `invalidateQueries` handles the moment of change, so `staleTime` only bounds the gap for changes this client didn't cause itself (another user, another tab) |
| `compliance-gaps` | 30s | 5 min (default) | Same reasoning — a remediation action elsewhere should surface here within one background-refetch window, not just on an explicit invalidation this screen happens to receive |
| Reference/taxonomy data (classification levels, frameworks) | 5 min | 10 min | Changes rarely, if ever, within a session; a longer `staleTime` avoids pointless refetch traffic for data that's effectively static |
| Current user/tenant profile | 5 min | 30 min | Rarely changes mid-session; when it does (a role change), it's invalidated explicitly via the cross-fragment event pattern (`references/cross-fragment-state.md`), not by waiting for `staleTime` to lapse |

The pattern across every row: **`staleTime` is set by how often the data
changes from *outside* this client's own actions; explicit invalidation
handles changes *this* client causes.** Data this client's own mutations
keep current doesn't need a short `staleTime` to feel fresh — it needs
correct invalidation. A short `staleTime` compensates only for drift the
client can't see coming.

---

## Optimistic Updates

For instant-feeling mutations, update the cache before the server responds
and roll back on error:

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

This pairs with the backend's idempotency (the same classify command is
safe to retry — see `go-service-layer`).

## Client-State Library Example

```ts
// A Zustand store for cross-cutting UI state (selection that spans features WITHIN one fragment)
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

Zustand is the default (tiny, hook-based, no boilerplate, no provider).
Jotai (atomic) is an acceptable alternative for fine-grained
derived-atom graphs. Redux is not a default — its boilerplate rarely
justifies itself here. **This store is scoped to one fragment** — see
`references/cross-fragment-state.md` for why a store never spans fragment
boundaries.
