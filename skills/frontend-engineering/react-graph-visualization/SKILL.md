---
name: react-graph-visualization
description: >
  Teaches how to build the data-estate relationship graph view in React — choosing
  a WebGL renderer (Sigma.js) for large graphs, mapping the backend's Apache AGE
  graph to nodes and edges, progressive/lazy loading and neighbourhood expansion,
  force-directed layout off the main thread, interaction (zoom/pan/select/filter),
  performance at thousands of nodes, accessibility fallbacks, and keeping the heavy
  graph bundle code-split. Visualizes the data-architect's graph model. Used by the
  frontend-engineer during Implement.
version: 1.0.0
phase: implement
owner: frontend-engineer
tags: [implement, frontend, react, graph, sigma, webgl, visualization, apache-age]
---

# React Graph Visualization

## Purpose

The estate graph is the product's signature view — an Obsidian-style map of how data assets, entities, sources, and people connect across the estate. It must stay fluid at thousands of nodes, which rules out naive SVG/DOM rendering. This skill covers rendering the graph with a WebGL engine, sourcing it from the backend's Apache AGE graph, and keeping it performant, interactive, and accessible.

This is the highest-performance-risk view in the product; it is treated as a first-class performance problem from the start (see `react-performance-optimization`).

---

## Renderer Choice

| Option | Rendering | Scales to | Use |
|---|---|---|---|
| **Sigma.js** | WebGL | tens of thousands of nodes | **Default** — the main estate graph |
| Cytoscape.js | Canvas/SVG | hundreds–low thousands | Richer interaction on small subgraphs |
| D3-force | SVG | low hundreds | Bespoke small diagrams only |

**Default: Sigma.js (WebGL).** The estate graph can be large; WebGL keeps frame rates smooth where Canvas/SVG would stall. Pair it with `graphology` for the in-memory graph model and layout algorithms. The renderer choice is recorded as an **ADR** (the enterprise-architect owns ADRs; the frontend-engineer supplies the rationale).

The graph library is **always code-split** (`lazy()` — see `react-routing`/`react-performance-optimization`) so its weight never lands in the initial bundle for users who don't open the graph.

---

## Sourcing from the Apache AGE Graph

The backend stores the graph in Apache AGE and exposes it through an API endpoint (the graph is a projection — see `data-model-design`). The frontend never talks to AGE directly; it fetches graph data through the typed API client (`react-api-client`), tenant-scoped by the backend.

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

The API returns nodes and edges in a shape mapped from the AGE vertices/edges (`DataAsset`, `Entity`, `DataSource`, `Person` vertices; `CONTAINS`, `REFERENCES`, `OWNED_BY` edges — the Ubiquitous Language from `data-model-design`).

---

## Progressive Loading — Never Load the Whole Estate

A full estate graph may have millions of nodes — loading it all is neither possible nor useful. Load a **bounded neighbourhood** and expand on demand:

1. Start from a focus node (or a small seed set) at depth 1–2.
2. On node click/expand, fetch that node's neighbourhood and merge it into the in-memory `graphology` graph.
3. Cap the visible node count; beyond it, cluster or require filtering.

```ts
const graph = useMemo(() => new Graph(), []);       // graphology model, stable across renders
function expand(nodeId: string) {
  api.getGraphNeighbourhood(nodeId, 1).then((nbhd) => mergeIntoGraph(graph, nbhd));
}
```

This keeps both the network payload and the GPU load bounded regardless of estate size.

---

## Layout Off the Main Thread

Force-directed layout is CPU-heavy; running it on the main thread causes long tasks (the INP killer — see `react-observability`). Run layout in a **Web Worker** so the UI stays responsive.

```ts
// graphology-layout-forceatlas2 in a worker; post positions back to the main thread
const worker = new Worker(new URL("./layout.worker.ts", import.meta.url), { type: "module" });
worker.postMessage({ nodes, edges });
worker.onmessage = (e) => applyPositions(graph, e.data.positions);
```

Pre-compute layout where possible (or persist positions) so reopening the graph is instant.

---

## Interaction

Implement the interactions from the `ui-component-spec`:

| Interaction | Behaviour |
|---|---|
| Zoom / pan | Camera controls; smooth at the target frame rate |
| Select node | Highlight node + its edges; open a detail panel (the `DataAsset` detail read model) |
| Expand | Fetch + merge the node's neighbourhood |
| Filter | By node type or sensitivity; dim/hide non-matching (e.g., show only `Restricted` assets) |
| Search | Locate and centre a node by name |

Selection and filter state live in the URL where it makes the view shareable (see `react-routing`).

---

## Performance Guardrails

- **WebGL renderer** (Sigma) — never thousands of SVG/DOM nodes.
- **Bounded visible set** — progressive loading + clustering; a hard cap with a "refine your filter" prompt beyond it.
- **Layout in a worker** — no main-thread blocking; watch Long Tasks in RUM.
- **Code-split** the graph bundle.
- **Clean up** the Sigma instance, the worker, and event listeners on unmount (the leak rule from `react-performance-optimization`) — a retained WebGL context is a serious leak.

```tsx
useEffect(() => {
  const renderer = new Sigma(graph, containerRef.current!);
  return () => { renderer.kill(); worker.terminate(); }; // release GPU context + worker
}, [graph]);
```

---

## Accessibility Fallback

A WebGL canvas is opaque to screen readers. Accessibility is provided by an **equivalent accessible representation**, not abandoned (see `react-accessibility`):

- A parallel, navigable **list/tree view** of the same nodes and relationships, fully keyboard- and screen-reader-accessible.
- Keyboard interaction for the graph itself (focus a node, expand, select) where feasible.
- The canvas has an `aria-label` and a described-by summary ("Estate graph: 142 assets, 38 entities…").

The graph is a visual enhancement; the underlying data is always reachable without it.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| WebGL for scale | Sigma/WebGL for the estate graph | Thousands of SVG/DOM nodes stalling the UI |
| Progressive loading | Bounded neighbourhood + expand-on-demand | Attempting to load the whole estate |
| Off-main-thread layout | Force layout in a Web Worker | Layout blocking the main thread (long tasks) |
| Tenant-scoped via API | Graph fetched through the typed client | Direct DB access / cross-tenant data |
| Code-split | Graph bundle lazy-loaded | Graph library in the initial bundle |
| Cleanup | Sigma instance + worker + listeners released | Retained WebGL context / worker leak |
| Accessible fallback | Equivalent list/tree representation | Inaccessible canvas with no alternative |

---

## Output Format

Produces the graph feature (React + worker) and its tests:

```
src/features/estate-graph/EstateGraph.tsx        (lazy-loaded Sigma renderer)
src/features/estate-graph/layout.worker.ts        (force layout off main thread)
src/features/estate-graph/useEstateGraph.ts        (data hook)
src/features/estate-graph/GraphListView.tsx        (accessible fallback)
src/features/estate-graph/*.test.tsx               (interaction + a11y; written first)
```
