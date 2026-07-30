# Worker Lifecycle Checklist and Interaction-State Ownership

Self-contained reference for two related standards `react-graph-visualization`'s
`SKILL.md` points to: the worker-lifecycle teardown checklist, and where
zoom/pan/selection state should live. Read this file on its own; it does not
assume the parent body is also in context. The full component these standards
govern is `estate-graph-worked-example.md`.

---

## Worker-Lifecycle Checklist

The graph ref, the worker ref, and the Sigma renderer must share one
lifecycle — created together, torn down together — or one outlives the
other and leaks a WebGL context, a worker thread, or both. Verify every one
of these against `estate-graph-worked-example.md`'s `EstateGraph` component:

1. **The `graphology` graph is created lazily on first render, via `useRef`,
   never `useMemo`.** `if (graphRef.current === null) graphRef.current = new
   Graph();` — a lazy-init ref, not a memoized value. (`useMemo` is a
   discardable performance hint; a value mutated node-by-node across the
   component's full lifetime needs a genuine lifetime guarantee.)
2. **The worker is created inside the same mount effect that creates the
   Sigma renderer** — not in a separate effect, and not inline in the
   component body. Two effects with two independent lifecycles is exactly
   the shape that produced the original bug: a cleanup in one effect
   referencing a variable that effect never created.
3. **The worker reference is stored in a `ref`, assigned inside that same
   effect**, so the cleanup closure and any other code that needs to reach
   the worker (posting new layout requests, for instance) can find the exact
   instance the effect created — never a variable from a disconnected
   snippet or an outer scope the effect doesn't own.
4. **The mount effect's cleanup tears down both the renderer and the worker
   in the same function**: `return () => { renderer.kill();
   worker.terminate(); };`. One cleanup, two teardowns — not two separate
   cleanups from two separate effects that could theoretically run out of
   order or independently fail.
5. **The effect's dependency array is `[]`.** The graph and worker are refs
   specifically so this effect runs once per mount, not once per graph
   mutation — an `expand()` call mutates `graphRef.current` in place and
   must never re-trigger this effect, re-creating the renderer and worker
   over live data.
6. **Never let one half of the pair outlive the other.** A renderer without
   a live worker draws a graph that never re-lays-out; a worker without a
   live renderer posts positions into a canvas that no longer exists. Both
   are the direct product of drawing the mount effect boundary in the wrong
   place — the fix in `estate-graph-worked-example.md` is exactly to draw it
   around both at once.

A code review that finds a worker or a Sigma instance created outside a
`useEffect`, or a cleanup that references anything not created inside that
same effect, has found a leak — treat it with the same severity as
`react-performance-optimization`'s cleanup rule for listeners and timers.

---

## Interaction State: Camera and Selection Ownership

Zoom, pan, and (in most cases) selection are **not** React state. They live
in the graph library's own state — Sigma's `Camera` for zoom/pan, and either
Sigma's own node-state API or a lightweight non-React store for selection —
and React reads from it only when it needs to render something derived from
it (a detail panel, a URL parameter), never as the value driving the
graph's own rendering.

### Why: A Pan Gesture Is Many Frames, Not One Event

A pan or zoom gesture fires camera-update events on every animation frame
while the gesture is active — tens of updates per second. Mirroring that into
`useState` (`const [camera, setCamera] = useState(initialCamera)`) would
re-render the entire React tree on every one of those frames purely so
Sigma's own canvas — which already redraws itself from its own camera state
on every frame regardless of React — can be told to do what it was already
doing. This is the same class of cost `react-state-management`'s
Context-performance-cost model describes for an unnecessary re-render, at a
frequency (per-animation-frame) far higher than any typical Context update:

```ts
// Correct: read Sigma's camera state imperatively when something outside
// the canvas needs it (a "reset view" button's disabled state, for
// instance) — not mirrored into a React state variable that re-renders on
// every pan/zoom frame.
function resetView(renderer: Sigma) {
  renderer.getCamera().animate({ x: 0.5, y: 0.5, ratio: 1 });
}
```

### What Legitimately Crosses Into React State

Selection and filter state that must be **shareable** (reflected in the URL,
read by a detail panel, survive a refresh) does cross into React — but as a
discrete, low-frequency event ("user clicked node X"), not a continuous
stream ("camera is currently at ratio 1.34"):

```ts
// A node click is a discrete event, not a per-frame stream — this is the
// right shape for React state (and, per react-routing, the URL).
renderer.on("clickNode", ({ node }) => setSelectedNodeId(node));
```

Selected-node ID and active filters belong in the URL, exactly as
`react-state-management`'s URL-as-state standard already requires for any
shareable view state — the graph is not a special case there. What stays out
of React state, always: raw camera position/zoom ratio, and any per-frame
hover/highlight state during an active gesture.

| State | Owner | Why |
|---|---|---|
| Camera position/zoom ratio | Sigma's `Camera` | Updates per animation frame; mirroring re-renders React tens of times/second for no visual benefit Sigma doesn't already provide |
| In-gesture hover/highlight | Sigma's node/edge reducers | Same frequency argument; Sigma re-styles the canvas directly without a React round-trip |
| Selected node ID | React state, promoted to the URL | Discrete event; shareable/bookmarkable view state (`react-state-management`, `react-routing`) |
| Active filters | React state, promoted to the URL | Same — discrete, shareable |
| The `graphology` graph itself | `useRef` (see `estate-graph-worked-example.md`) | Imperatively mutated, must outlive any single render |
