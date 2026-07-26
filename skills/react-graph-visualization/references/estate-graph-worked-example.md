# Estate Graph Worked Example

Self-contained reference implementation for the estate graph feature described
in `react-graph-visualization`'s `SKILL.md`. Shows the complete lifecycle end
to end: the tenant-scoped data hook, the lazily-initialized `graphology` graph
instance, the layout worker, and the Sigma WebGL renderer — created and torn
down together in one mount effect. Read this file on its own; it does not
assume the parent `SKILL.md` body is also in context.

This example previously shipped as three independent snippets that did not
actually compose into a working implementation — two real bugs were caught by
independent verification and fixed here. Both fixes are preserved verbatim
below; do not revert either.

---

## 1. Data Hook — Tenant-Scoped, Neighbourhood-Bounded

The frontend never talks to Apache AGE directly. It fetches graph data through
the typed API client (`react-api-client`), tenant-scoped by the backend, and
bounded to a neighbourhood rather than the whole estate (see `SKILL.md`'s
Progressive Loading standard):

```ts
// graph data hook — tenant-scoped, neighbourhood-bounded
function useEstateGraph(rootId: string, depth: number) {
  return useQuery({
    queryKey: ["estate-graph", rootId, depth],
    queryFn: ({ signal }) => api.getGraphNeighbourhood(rootId, depth, signal),
    staleTime: 60_000,
  });
}
```

The API returns nodes and edges in a shape mapped from the AGE vertices/edges
(`DataAsset`, `Entity`, `DataSource`, `Person` vertices; `CONTAINS`,
`REFERENCES`, `OWNED_BY` edges — the Ubiquitous Language from
`data-model-design`).

---

## 2. Progressive Expansion — `useRef`, Not `useMemo`, for the Graph Instance

**Bug fix #1, preserved exactly.** A full estate graph may have millions of
nodes — loading it all is neither possible nor useful. The pattern is a
bounded neighbourhood, expanded on demand: start from a focus node at depth
1–2, and on click, fetch that node's neighbourhood and merge it into the
in-memory `graphology` graph.

The graph instance itself must be a `useRef`, not a `useMemo`:

```ts
// graphRef, not useMemo -- the graph is imperatively mutated on every expand() call
// (mergeIntoGraph adds nodes/edges in place), and useMemo is a discardable React
// performance hint, not a lifetime guarantee: React is allowed to drop and recompute
// it, silently losing every merged node. A ref survives for the component's full
// lifetime by construction, which is what a mutable model that outlives any single
// render actually needs.
const graphRef = useRef<Graph | null>(null);
if (graphRef.current === null) graphRef.current = new Graph(); // lazy init, once

function expand(nodeId: string) {
  api.getGraphNeighbourhood(nodeId, 1).then((nbhd) => mergeIntoGraph(graphRef.current!, nbhd));
}
```

`useMemo` is documented by React itself as a performance hint, not a lifetime
guarantee — React is explicitly permitted to discard a memoized value and
recompute it, which is safe for a pure derived value but wrong for a value
that owns external, non-recreatable state being mutated node-by-node across
the component's full lifetime. This keeps both the network payload and the
GPU load bounded regardless of estate size.

---

## 3. The Full Component — Graph Ref, Worker Ref, and Sigma Renderer in One Mount Effect

**Bug fix #2, preserved exactly.** Force-directed layout is CPU-heavy and runs
in a Web Worker so the UI stays responsive. The worker must be created in the
*same* mount effect that creates the Sigma renderer, and torn down in that
same effect's cleanup — a cleanup that references a variable declared in a
disconnected snippet elsewhere in the component is not in scope and not in
the effect's dependency array, and the two never actually compose into a
correct implementation. The fix consolidates the graph ref, the worker ref,
and the Sigma renderer into one component, all created and torn down
together:

```tsx
function EstateGraph() {
  const containerRef = useRef<HTMLDivElement>(null);
  const graphRef = useRef<Graph | null>(null);
  if (graphRef.current === null) graphRef.current = new Graph();
  const workerRef = useRef<Worker | null>(null);

  useEffect(() => {
    const graph = graphRef.current!;
    const renderer = new Sigma(graph, containerRef.current!);

    const worker = new Worker(new URL("./layout.worker.ts", import.meta.url), { type: "module" });
    worker.onmessage = (e) => applyPositions(graph, e.data.positions);
    workerRef.current = worker;
    worker.postMessage({ nodes: graph.nodes(), edges: graph.edges() });

    // Both refs and the renderer are created and torn down in the SAME effect —
    // no cross-snippet reference to a variable declared somewhere else in the
    // component. []: the graph and worker are refs precisely so this effect
    // runs once per mount, not once per graph mutation.
    return () => { renderer.kill(); worker.terminate(); };
  }, []);

  return <div ref={containerRef} />;
}
```

Pre-compute layout where possible (or persist positions) so reopening the
graph is instant. The full worker-lifecycle checklist this example satisfies
is in `worker-lifecycle-and-interaction-state.md`.

---

## Why Both Fixes Matter Together

Neither fix is sufficient alone. A `useRef`-based graph with a disconnected
worker snippet still leaks a worker on unmount. A correctly-scoped worker
effect built on a `useMemo`-based graph still silently drops merged nodes the
first time React discards the memo. The correct implementation requires both:
a stable, imperatively-mutated graph instance (`useRef`), and a single mount
effect that owns the full lifecycle of everything created alongside it (the
renderer and the worker, together, with one matching cleanup).
