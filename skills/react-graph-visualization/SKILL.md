---
name: react-graph-visualization
description: >
  Teaches how to build the data-estate relationship graph view in React —
  renderer choice (Sigma.js/WebGL by default) and the concrete node/edge-count
  threshold where SVG/Canvas rendering stops being viable, level-of-detail and
  viewport culling for very large estates, sourcing the graph from the
  backend's Apache AGE projection through the typed API client, progressive/
  lazy neighbourhood loading, the worker-lifecycle standard for running
  force-directed layout off the main thread (graph ref, worker ref, and Sigma
  renderer created and torn down together in one mount effect), interaction-
  state ownership (zoom/pan/selection living in the graph library's own camera
  state, not mirrored into React state, and why), and the accessibility-
  fallback standard for an opaque WebGL canvas. Used by the frontend-engineer
  during Implement.
version: 2.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, graph, sigma, webgl, visualization, apache-age, performance, accessibility]
produces: react-graph-feature
domain: frontend
status: stable
related: [react-accessibility, react-performance-optimization, react-state-management, data-model-design]
---

# React Graph Visualization

## Purpose

The estate graph is the product's signature view — an Obsidian-style map of
how data assets, entities, sources, and people connect. It must stay fluid
at thousands of nodes, ruling out naive SVG/DOM rendering, and is treated as
a first-class performance problem from the start
(`react-performance-optimization`). This skill states the renderer,
performance, lifecycle, interaction-state, and accessibility standards; the
full worked implementation is in `references/`.

---

## Renderer Choice

| Option | Rendering | Scales to | Use |
|---|---|---|---|
| **Sigma.js** | WebGL | tens of thousands of nodes | **Default** — the main estate graph |
| Cytoscape.js | Canvas/SVG | hundreds–low thousands | A small, bounded subgraph only (a "related assets" popover) |
| D3-force | SVG | low hundreds | Bespoke small diagrams only |

**Default: Sigma.js (WebGL)**, paired with `graphology` for the in-memory
graph model and layout algorithms. The exact SVG/DOM ceiling and why WebGL
changes it: `references/rendering-performance-and-lod.md`. Renderer choice is
recorded as an **ADR** (enterprise-architect owns ADRs; frontend-engineer
supplies the rationale). The graph library is **always code-split** (`lazy()`
— see `react-routing`/`react-performance-optimization`) so its weight never
lands in the initial bundle for users who don't open the graph.

---

## Sourcing from the Apache AGE Graph

The backend stores the graph in Apache AGE and exposes it as a projection
(`data-model-design`) through the typed API client (`react-api-client`),
tenant-scoped by the backend — the frontend never talks to AGE directly.
Nodes/edges map from AGE vertices/edges using the Ubiquitous Language
(`DataAsset`, `Entity`, `DataSource`, `Person` vertices; `CONTAINS`,
`REFERENCES`, `OWNED_BY` edges). Full data-hook code:
`references/estate-graph-worked-example.md`.

---

## Progressive Loading — Never Load the Whole Estate

A full estate graph may have millions of nodes. Load a **bounded
neighbourhood** (depth 1–2 from a focus node) and expand on demand: on
click, fetch that node's neighbourhood and merge it into the in-memory
`graphology` graph, capping the visible count and requiring filtering or
clustering beyond it. The graph instance is a lazily-initialized `useRef`,
never a `useMemo` — it is mutated in place on every expansion, and `useMemo`
is a discardable performance hint, not a lifetime guarantee. Full code and
the bug this fixes: `references/estate-graph-worked-example.md`.

---

## Rendering Performance: Thresholds and Level of Detail

SVG-viability ceiling (~200 nodes comfortable, 1,000+ unacceptable), why
WebGL changes it, and the two LOD techniques for very large estates —
viewport/label culling at the renderer level (`hideLabelsOnMove`, a
rendered-size threshold) and collapsing dense neighbourhoods into a single
aggregate node below a zoom threshold, applied at the render layer only,
never mutating the model. These numbers are reasoned engineering estimates
for this stack, not a research citation — validate against real profiling.
Full standard: `references/rendering-performance-and-lod.md`.

---

## Worker Lifecycle Standard

Layout runs in a Web Worker so ForceAtlas2 iterations never block the main
thread (the Long Task / INP risk — `react-observability`). The worker shares
one lifecycle with the graph ref and the Sigma renderer: created together in
a single mount effect, torn down together in that effect's one cleanup, `[]`
dependency array. The full six-point checklist, and why a cleanup
referencing a variable from a different effect is a leak:
`references/worker-lifecycle-and-interaction-state.md`.

---

## Interaction-State Standard

Zoom, pan, and in-gesture hover/highlight are **not** React state — they
live in Sigma's own `Camera` and node-state reducers, read imperatively when
something outside the canvas needs them. Mirroring per-animation-frame
camera updates into `useState` re-renders the whole tree tens of times a
second for something the canvas already redraws on its own. Selection and
active filters (the `ui-component-spec` interactions) *do* cross into React
— as a discrete click event, not a continuous stream — and are promoted to
the URL exactly as `react-state-management`'s URL-as-state standard already
requires; the detail panel a selection opens reads the `DataAsset` Read
Model. Full ownership table and the frequency argument:
`references/worker-lifecycle-and-interaction-state.md`.

---

## Accessibility Fallback

A WebGL canvas is opaque to screen readers. `react-accessibility` owns the
general WCAG standard (semantic HTML, keyboard operability, focus
management, live regions) this section does not restate — what's specific
to the graph is the **exact fallback content**:

- A parallel, navigable **list/tree view** (`GraphListView`) of the same
  nodes and edges — every `DataAsset`/`Entity`/`DataSource`/`Person` node as
  a list item, relationships as nested/linked entries — built from semantic
  HTML (`react-accessibility`'s semantic-first rule), not a re-implementation
  of the canvas's interaction model.
- Keyboard interaction for the graph itself where feasible (focus, expand,
  select a node) — additive, not a substitute for the list/tree view.
- The canvas carries an `aria-label` + described-by summary ("Estate graph:
  142 assets, 38 entities…") per `react-accessibility`'s accessible-names rule.

The list/tree view is the accessible product, reachable without the canvas
— never an afterthought bolted on last.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| WebGL for scale | Sigma/WebGL above the SVG ceiling (`references/rendering-performance-and-lod.md`) | Thousands of SVG/DOM nodes stalling the UI |
| Progressive loading | Bounded neighbourhood + expand-on-demand | Attempting to load the whole estate |
| Graph instance lifetime | `useRef`, lazily initialized once | `useMemo` for an imperatively-mutated graph |
| Level of detail at scale | Viewport/label culling + cluster-collapse below a zoom threshold, applied at the render layer | Rendering every node at every zoom; or mutating the model to hide unseen nodes |
| Worker lifecycle | Graph ref, worker ref, renderer created + torn down together in one effect; layout off the main thread | Worker/renderer created outside an effect or torn down in a mismatched cleanup; layout blocking the main thread |
| Interaction-state ownership | Camera/hover in Sigma's own state; selection/filters in React, promoted to the URL | Camera mirrored into `useState`; shareable selection trapped in component state |
| Tenant-scoped via API | Graph fetched through the typed client | Direct DB access / cross-tenant data |
| Code-split | Graph bundle lazy-loaded | Graph library in the initial bundle |
| Cleanup | Sigma instance + worker + listeners released | Retained WebGL context / worker leak |
| Accessible fallback | Navigable list/tree with the exact same nodes/edges | Inaccessible canvas with no alternative, or a token `aria-label` alone |

---

## Anti-Patterns

- **SVG/DOM nodes at scale** — a `<circle>` per DataAsset works in the demo and dies at the first real estate. Renderer choice is made for the worst case, not the fixture.
- **"Load the whole graph, then filter"** — fetching millions of vertices to show forty is unbounded in payload, memory, and GPU. The bound is server-side (neighbourhood queries), not client-side.
- **`useMemo` for the graph instance** — silently drops merged nodes the first time React discards the memo. `useRef`, lazily initialized.
- **Layout on the main thread, or a worker/renderer created outside a mount effect (or torn down by a cleanup that doesn't share that effect)** — ForceAtlas2 freezing input for seconds is the classic Long Task; a mismatched worker/renderer lifecycle is the exact shape that produced this skill's original bug — see the six-point checklist.
- **Mirroring camera state, or any node/edge data, into `useState`** — re-renders the whole tree on every pan/zoom animation frame, or on changes only the WebGL layer cares about; the `graphology` instance and Sigma's `Camera` are the model.
- **The graph library in the initial bundle** — lazy route + `lazy()` import, verified in the bundle-size CI check.
- **Canvas-only accessibility** — an `aria-label` on an opaque canvas is a caption on a locked door; the list/tree fallback is the accessible product, not a nice-to-have.

---

## Output Format

Produces the graph feature (React + worker) and its tests, per the standards
in `references/estate-graph-worked-example.md`,
`references/rendering-performance-and-lod.md`, and
`references/worker-lifecycle-and-interaction-state.md`:

```
src/features/estate-graph/EstateGraph.tsx        (lazy-loaded Sigma renderer; ref/worker/renderer lifecycle)
src/features/estate-graph/layout.worker.ts        (force layout off main thread)
src/features/estate-graph/useEstateGraph.ts        (tenant-scoped data hook)
src/features/estate-graph/GraphListView.tsx        (accessible list/tree fallback)
src/features/estate-graph/*.test.tsx               (interaction + a11y; written first)
```
