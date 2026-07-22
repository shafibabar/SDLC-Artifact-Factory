# TanStack Query Patterns

Full server-state code — unchanged from the single-app model; split out
here as substantial worked code, not because it's microfrontend-specific.
Self-contained — loadable without reading `SKILL.md` first.

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
