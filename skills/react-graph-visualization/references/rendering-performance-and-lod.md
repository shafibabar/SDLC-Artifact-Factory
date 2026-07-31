# Rendering Performance: WebGL vs SVG, and Level-of-Detail/Culling

Self-contained reference for the render-budget and level-of-detail (LOD)
standard `react-graph-visualization`'s `SKILL.md` points to. Read this file on
its own; it does not assume the parent body is also in context.

**Grounding note:** the exact node/edge-count thresholds below are stated as
reasoned engineering estimates specific to browser rendering behaviour and the
Sigma.js/graphology stack this plugin defaults to — they are not sourced from
a research citation in this repo's `research/` corpus (neither research book
consulted for this skill's rebuild, *Learning React* or *React Design
Patterns*, covers WebGL/Canvas/graph-rendering performance; both are
general-purpose React fundamentals texts). Treat the numbers as defaults to
validate against this product's actual profiling data, not as a fixed law.

---

## The SVG/DOM Ceiling

Every SVG node is a live DOM element: a `<circle>` or `<g>` that the browser
must lay out, style, and hit-test independently. Every edge is a `<path>`.
Rendering and reconciling this tree is where SVG/DOM graph rendering breaks
down at scale:

| Approximate node count | SVG/DOM viability |
|---|---|
| < 200 | Fine — full interactivity, no perceptible cost |
| 200–1,000 | Degraded — pan/zoom starts to stutter; acceptable only for a fixed, non-panning diagram |
| > 1,000 | Unacceptable — layout thrash and dropped frames on interaction; this is the point WebGL becomes mandatory, not optional |

The estate graph routinely exceeds the top band even at a single bounded
neighbourhood (see `SKILL.md`'s Progressive Loading standard) — WebGL (Sigma)
is the default renderer for exactly this reason, not a premature optimisation.
Cytoscape.js (Canvas/SVG) remains the right tool only for small, bounded
subgraphs shown outside the main estate view (a "show related assets" popover
capped at a few dozen nodes), never for the estate view itself.

## Why WebGL Changes the Ceiling

A WebGL renderer (Sigma) draws nodes and edges as GPU primitives in a single
canvas element, not as individual DOM nodes — the DOM footprint is one
`<canvas>` regardless of graph size, and the GPU is well-suited to drawing
tens of thousands of simple shapes per frame. The bottleneck shifts from DOM
layout/reconciliation to GPU draw calls and CPU-side layout computation — the
latter is why force-directed layout runs in a Web Worker (`SKILL.md`'s Worker
Lifecycle standard) rather than on the render thread.

| Approximate node count (WebGL) | Guidance |
|---|---|
| Up to ~5,000 | Smooth at 60fps with no special handling beyond the worker-based layout |
| ~5,000–20,000 | Smooth with level-of-detail (below) applied at low zoom |
| > 20,000 visible simultaneously | Apply clustering (below) — rendering every individual node stops being useful to a human regardless of frame rate |

---

## Level of Detail (LOD): Viewport Culling

At any given zoom level, only render nodes/edges within the current viewport
plus a small margin — nodes far outside the visible camera frustum cost draw
calls for no visual benefit. Sigma's own camera and quadtree-based spatial
index make this the renderer's job, not application code's:

```ts
// Sigma computes the visible viewport from its own camera state; application
// code does not maintain a separate "which nodes are visible" list — that
// would duplicate state the renderer already owns and get out of sync with
// the camera on every pan/zoom frame.
renderer.setSetting("hideLabelsOnMove", true);   // skip label draw cost during pan/zoom gestures
renderer.setSetting("labelRenderedSizeThreshold", 8); // don't render labels below this on-screen node size
```

`hideLabelsOnMove` and a rendered-size threshold are the two cheapest LOD
levers: labels are text-measurement-heavy and the first thing to skip during
an active gesture or at a zoom level where the label would be illegible
anyway.

## Level of Detail: Clustering Below a Zoom Threshold

Below a chosen zoom threshold, collapse dense clusters of nodes into a single
visual "cluster node" sized by member count, rather than rendering every
individual node at a scale where they'd overlap into unreadable noise:

```ts
// Below zoomThreshold, replace a dense neighbourhood with one aggregate node.
// This is a rendering-layer decision, computed from the current camera
// state, not a mutation of the underlying graphology model — expanding the
// cluster (zooming in) must reveal the same underlying nodes, unchanged.
function getRenderNodes(graph: Graph, camera: CameraState, zoomThreshold: number) {
  if (camera.ratio > zoomThreshold) return computeClusters(graph); // zoomed out: aggregate
  return graph.nodes(); // zoomed in: render individually
}
```

The clustering threshold is a per-product tuning value, set from profiling
against this product's actual estate sizes — the number above is a starting
point, not a fixed constant. What must hold regardless of the exact threshold:
clustering is applied at the rendering layer only; the underlying
`graphology` model (and the merge/expand logic in
`estate-graph-worked-example.md`) is never mutated to remove nodes the user
merely can't currently see.

---

## Measuring, Not Guessing

Apply `react-performance-optimization`'s measure-first discipline here too:
profile with production-scale synthetic data (a neighbourhood at the largest
realistic depth/fan-out) before deciding whether LOD or clustering is
actually needed for this product's estates, and re-measure after applying
either. The thresholds above are where to start looking, not a substitute for
a flame graph.
