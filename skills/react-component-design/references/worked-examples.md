# React Component Design — Worked Examples

Self-contained worked examples for the four situations `SKILL.md` names:
implementing a `ui-component-spec` exactly, extracting logic into a custom
hook, sharing implicit state via a Compound Component, and the one case
where a render prop is still the better tool than a hook. Read `SKILL.md`
first for the decision criteria — this file is the code each decision
resolves to.

---

## 1. Implementing a `ui-component-spec` Exactly

A spec enumerates every state variant, every interaction, and the
accessibility requirements. The implementation realizes all of them —
every state gets a render path, not just the happy one:

```tsx
// from ui-component-spec: DataAssetTable (Organism) → DataAssetListView Read Model
interface DataAssetTableProps {
  readonly assets: ReadonlyArray<DataAsset>;
  readonly isLoading: boolean;
  readonly error: AppError | null;
  readonly onClassify: (id: string) => void;
}

export function DataAssetTable({ assets, isLoading, error, onClassify }: DataAssetTableProps) {
  if (isLoading) return <TableSkeleton rows={10} />;        // Loading state (spec)
  if (error)     return <ErrorBanner error={error} />;       // Error state (spec)
  if (assets.length === 0) return <DataAssetEmptyState />;    // Empty state (spec)
  return (
    <table aria-label="Data assets">                         {/* a11y from spec */}
      <tbody>
        {assets.map((a) => (
          // key={a.id}, never key={index} — reconciliation uses key to decide
          // whether a child element IS the same logical row across renders
          // (preserving its instance/state) or a new one (fresh mount). An
          // index is only a stable identity while the list never reorders,
          // filters, or inserts anywhere but the end; the moment it does,
          // index-as-key mismatches state (an open menu, a focused cell) to
          // the wrong row. `a.id` is a stable identity from the data itself.
          <DataAssetRow key={a.id} asset={a} onClassify={onClassify} />
        ))}
      </tbody>
    </table>
  );
}
```

Every state variant from the spec maps to a render path; every interaction
maps to a handler. These same states become the test cases — see
`react-component-testing`.

---

## 2. Custom Hook — Extracting Logic from Markup

A component should read like a description of the UI. Non-trivial logic
(data fetching, derived state, effect wiring) moves into a `useX` hook so
the component body stays declarative and the logic is independently
testable — this is the hooks-era realization of the container/
presentational split (Roldán; Banks & Porcello): a component stays
"presentational" in spirit while a hook does the container's job, with no
extra wrapper component in the tree.

```tsx
// feature hook: encapsulates the classify workflow (mutation + optimistic update + toast)
function useClassifyDataAsset(assetId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ level, idempotencyKey }: { level: SensitivityLevel; idempotencyKey: string }) =>
      api.classifyDataAsset(assetId, level, idempotencyKey),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["data-assets"] }),
  });
}

// the component just declares intent:
function ClassificationModal({ assetId, onClose }: ClassificationModalProps) {
  const classify = useClassifyDataAsset(assetId);
  // …render; on submit: classify.mutate({ level, idempotencyKey: crypto.randomUUID() })
  // The key lives in the mutation variables — generated once per user intent, so a
  // TanStack Query retry re-runs mutationFn with the SAME variables and the same key.
}
```

Rules for hooks: name them `useX`; one responsibility each; return a
stable, typed object; follow the Rules of Hooks (top level, unconditional
— see `react-project-structure`'s `eslint-plugin-react-hooks` enforcement
of this as a lint-time check, not a prose-only convention). The mechanical
reason the rule exists: React tracks each hook call by its **call order**
within a render, matching this render's second `useState` call to the
previous render's second call to return the same state cell. A hook called
inside an `if`/`map`/after an early `return` changes how many calls happen
on some renders and not others, desynchronizing that slot list — silently
reading the wrong state, or crashing when the count changes.

---

## 3. Compound Components — Shared Implicit State, Fixed Structure

Several sub-components share state via a small, feature-private Context;
the parent owns the Context provider and the state, each named
subcomponent reads it — the caller composes a declarative API instead of
threading props through every layer:

```tsx
<Tabs defaultValue="assets">
  <Tabs.List>
    <Tabs.Trigger value="assets">Assets</Tabs.Trigger>
    <Tabs.Trigger value="lineage">Lineage</Tabs.Trigger>
  </Tabs.List>
  <Tabs.Panel value="assets"><DataAssetTable …/></Tabs.Panel>
</Tabs>
```

This is the fix for boolean-prop proliferation (`<Table compact bordered
selectable withActions>`), not a bigger union of `variant` strings — a
compound-component family exposes a small, composable set of
subcomponents instead of a combinatorial flag surface. It applies when
the relationship between the pieces is genuinely fixed and structural
(a `Tabs.Panel` only makes sense inside a `Tabs`) — see `SKILL.md`'s
composition-pattern decision table for when this beats a custom hook or
render prop instead.

**Note on Context's cost**: every consumer re-renders on any change to the
`Provider`'s value, with no built-in slice-selection — a `Tabs` Context
recreated as a fresh object literal on every parent render defeats even
React's own bail-out. Memoize the Context value; this is a low-frequency,
narrowly-scoped Context (open tab, within one component family), not a
cross-cutting store (see `react-state-management` for that boundary).

---

## 4. Render Props — When the Caller Must Control Rendering

For most reusable-logic problems, a **custom hook is the more idiomatic
default** (see §2 and `SKILL.md`'s decision table) — it composes more
freely, doesn't add a wrapper level to the component tree, and reads as
ordinary function calls rather than JSX indirection. Render props remain
the right tool specifically when the caller needs to **control rendering
itself**, not just consume a value or a callback — the reusable part owns
behavior and measurement, the caller owns markup:

```tsx
// The virtualiser owns scroll-position tracking and range calculation;
// the caller owns what each visible row actually renders. Reach for this
// shape only when what gets MOUNTED, not just what data is used, varies
// by caller — the caller here decides the very shape of each row's DOM,
// which a hook returning `visibleRange` alone can't hand back.
function VirtualizedList<T>({ items, rowHeight, children }: {
  items: T[]; rowHeight: number; children: (item: T, index: number) => React.ReactNode;
}) {
  const { visibleRange, containerProps } = useVirtualRange(items.length, rowHeight);
  return (
    <div {...containerProps}>
      {items.slice(visibleRange.start, visibleRange.end).map((item, i) => children(item, visibleRange.start + i))}
    </div>
  );
}

// Caller controls the row markup; VirtualizedList controls what's mounted at all.
<VirtualizedList items={dataAssets} rowHeight={48}>
  {(asset) => <DataAssetRow key={asset.id} asset={asset} />}
</VirtualizedList>
```

A custom hook could expose `visibleRange` too, but every caller would then
own the `.slice()` call and the wrapper `<div>` — fine for one caller,
repetitive across many. Render props centralize that repetition once, in
exchange for one extra render-prop indirection. If nothing about *what
gets mounted* varies by caller, that is the signal a custom hook fits
better — don't reach for render props by default. Any list this component
renders that can realistically exceed a few hundred rows should be
virtualized regardless of which composition tool wraps it — see
`react-performance-optimization` for the windowing threshold and the
`React.memo` shallow-comparison trap that would otherwise defeat it.
