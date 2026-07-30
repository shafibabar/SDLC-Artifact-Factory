# Profiler Workflow and Memoization Standard

Self-contained reference for `react-performance-optimization`. Covers the full React DevTools Profiler procedure and the worked, broken-then-fixed example behind the shallow-comparison caveat. Read this when actually running a profiling session or writing the code-review comment that justifies (or rejects) a `memo`/`useMemo`/`useCallback`.

---

## The React DevTools Profiler Workflow, Step by Step

1. **Open the Profiler tab**, click record, perform the exact user interaction under investigation (type in a search box, switch a tab, expand a row) — not an arbitrary click. Stop recording immediately after.
2. **Read the commit list** across the top: each bar is one render commit; height/color encodes duration. Click the tallest bar first — that commit dominates the interaction's total cost.
3. **Read the flame graph for that commit.** Each rectangle is a component; width is time spent in that component's render (including children). The widest rectangle at the top of the stack is the actual expensive render — not necessarily the component you assumed.
4. **Click that component and read "Why did this render?"** DevTools reports one or more of exactly four reasons:
   - **Props changed** — lists which prop(s), and whether by value or reference.
   - **State changed** — lists which state.
   - **Parent re-rendered** — the component re-rendered only because its parent did, with no relevant prop/state change of its own. This is the case `React.memo` targets.
   - **Context changed** — a consumed context's value changed, including consumers that don't read the changed field (see `react-state-management`'s Context cost model).
5. **Check the ranked/"stale dependency" view** for any effect or `useMemo`/`useCallback` re-running every commit — this usually means a dependency array holds a reference that changes every render (an inline object/array/function, or a value that should have been memoized upstream).
6. **Only after steps 1–5 identify a specific, repeated, expensive "parent re-rendered" case** does a `memo`/`useMemo`/`useCallback` decision belong on the table. Profiling first is not a formality — it is what separates a real fix from a guess.
7. **Re-record the same interaction after the change.** The previously-tallest commit bar must shrink, and "Why did this render?" for the fixed component must no longer report "Parent re-rendered" for that interaction. No before/after pair, no claimed win.

---

## Memoization Decision Criteria — Exact Payoff Conditions

`React.memo`, `useMemo`, and `useCallback` all add a cost (a comparison or a cache entry on every render) in exchange for skipping work on some renders. Each only pays for itself under a specific, checkable condition:

| Tool | Pays off only when | Does not pay off when |
|---|---|---|
| `React.memo` | The component re-renders often (profiler-confirmed "Parent re-rendered") **and** its own render is expensive enough that skipping it is worth the per-render prop comparison | The component is cheap to render (a `<span>`, a small styled div) — the comparison costs more than just re-rendering it |
| `useMemo` | The computed value is expensive to recompute, **or** the value is passed as a prop to a `memo`'d child, **or** the value appears in another hook's dependency array | Used reflexively on every derived value "for safety" — most derivations are cheaper than the memo bookkeeping itself |
| `useCallback` | The function is passed as a prop to a `memo`'d child, **or** the function appears in an effect's/another hook's dependency array | Wrapping every event handler "for consistency" when nothing downstream depends on its reference |

The recurring mistake this table is meant to prevent: memoizing a component or value with no profiled, repeated, expensive re-render to fix. Memoization added speculatively is pure cost — the comparison/cache runs every render, and the code is harder to read, for zero measured benefit.

---

## Worked Example: The Shallow-Comparison Caveat, Broken Then Fixed

`React.memo` performs a **shallow comparison** — `Object.is` per prop, one level deep. An object, array, or function literal created fresh inside the parent's render body has a new reference every time even when its contents are identical, so the shallow comparison reports "changed" on every render and the memoized child re-renders anyway. This is the single most common reason a `memo` "doesn't work."

**Broken** — profiled, `DataAssetRow` still re-renders on every keystroke in an unrelated search box in the parent, despite being wrapped in `memo`:

```tsx
const DataAssetRow = memo(function DataAssetRow({ asset, style, onClassify }: RowProps) {
  return <div style={style} onClick={() => onClassify(asset.id)}>{asset.name}</div>;
});

function AssetList({ assets }: { assets: DataAsset[] }) {
  const [query, setQuery] = useState("");
  return (
    <>
      <input value={query} onChange={(e) => setQuery(e.target.value)} />
      {assets.map((asset) => (
        <DataAssetRow
          key={asset.id}
          asset={asset}
          style={{ color: "red" }}                    // new object every render
          onClassify={(id) => classify.mutate({ id })} // new function every render
        />
      ))}
    </>
  );
}
```

Every keystroke re-renders `AssetList`, which re-creates `{ color: "red" }` and the inline arrow function on every row, defeating `memo`'s shallow comparison for every single row on every keystroke — the exact "Why did this render?" → "Props changed (style, onClassify)" signature the Profiler would show, even though neither prop's actual content changed.

**Fixed** — hoist the literal that never varies out of the render body entirely, and stabilize the one that depends on `asset` with `useCallback`:

```tsx
const ROW_STYLE = { color: "red" };            // hoisted once, module scope — same reference forever

function AssetList({ assets }: { assets: DataAsset[] }) {
  const [query, setQuery] = useState("");
  const handleClassify = useCallback(
    (id: string) => classify.mutate({ id }),
    [classify],
  );                                            // stable across re-renders of AssetList
  return (
    <>
      <input value={query} onChange={(e) => setQuery(e.target.value)} />
      {assets.map((asset) => (
        <DataAssetRow key={asset.id} asset={asset} style={ROW_STYLE} onClassify={handleClassify} />
      ))}
    </>
  );
}
```

Now `DataAssetRow`'s props are referentially stable across a keystroke that only changes `query` — `memo`'s shallow comparison passes, and the Profiler's "Why did this render?" panel reports nothing for the row components on that interaction. When the literal genuinely varies per row (a computed style depending on `asset`), hoisting isn't available — memoize it at the source instead: `const style = useMemo(() => computeStyle(asset), [asset])` inside the parent, still cheaper than the row re-rendering.

The general rule: `memo` on a child is only as strong as the referential stability of every prop the parent hands it. Fix the parent's props before concluding `memo` "doesn't work."
