# Real-Time Update Standard

Self-contained reference for `react-dashboard-components`. Governs any
widget that subscribes to live data — a WebSocket push or a polling
interval — rather than fetching once per navigation. Most dashboard
widgets in this skill's domain do not subscribe to live data; this
standard applies only to the ones that do (a live ingestion-throughput
chart, a live open-gap counter). The goal is a widget that updates in
place without a full-widget re-render on every tick.

---

## 1. The Subscription Lives in a Custom Hook

A live subscription is exactly the kind of logic `react-component-design`
requires be extracted to a named `useX` hook, never inlined in the widget
body: `useLiveGapCount(tenantId)`, not a `useEffect` block sitting inside
`GapCounterCard` itself. This keeps the widget presentational and the
subscription mechanics (connect, reconnect, cleanup) independently
testable.

## 2. Patch the Changed Entry, Never Replace the Whole Dataset

The core discipline: on each tick, update **only the specific data point
that changed**, not the entire collection. Keep live data keyed (a `Map`
or an object keyed by id), and apply an immutable patch to just the
changed entry so unchanged entries keep the exact same object reference
across renders:

```tsx
function useLiveMetrics(tenantId: string) {
  const [metrics, setMetrics] = useState<Record<string, MetricPoint>>({});

  useEffect(() => {
    const ctrl = new AbortController();
    const socket = openMetricsSocket(tenantId, ctrl.signal);
    socket.onMessage((tick: MetricPoint) => {
      setMetrics((prev) =>
        prev[tick.id]?.value === tick.value
          ? prev                                    // no change — same reference, no render
          : { ...prev, [tick.id]: tick }             // only the changed entry gets a new reference
      );
    });
    return () => { ctrl.abort(); socket.close(); };  // cleanup — react-performance-optimization Part 5
  }, [tenantId]);

  return metrics;
}
```

This matters because it is the precondition for `React.memo` to work at
all: `react-performance-optimization`'s shallow-comparison rule means a
memoized row/series component still re-renders on every tick if its data
prop is a *new* object even when its value is unchanged. Replacing the
whole `metrics` object on every tick (`setMetrics(fullNewPayload)`) gives
every row a new prop reference regardless of whether that row's value
changed, defeating `memo` for the entire widget. The keyed-patch shape
above is what lets only the changed row's memoized component actually
re-render.

## 3. Chart Diffing Follows the Same Rule

A live chart re-renders its whole `<BarChart>`/`<LineChart>` when its
`data` array prop changes reference — Recharts has no way to know only
one point changed unless the array itself proves it. Build the next
`data` array by mapping over the previous one and replacing only the
changed entry, not by constructing a fresh array of new objects every
tick:

```tsx
const nextData = prevData.map((point) =>
  point.id === tick.id ? { ...point, value: tick.value } : point  // unchanged points: same object reference
);
```

Wrap the series/row-level sub-components in `React.memo` so the
unchanged-reference points from this map skip re-render, same as §2.

## 4. Throttle High-Frequency Streams

A fast WebSocket stream can emit far faster than a useful render cadence.
Coalesce ticks so at most one re-render happens per animation frame
(batch incoming ticks in a ref, flush via `requestAnimationFrame`) rather
than calling `setState` once per message — an un-throttled high-frequency
stream can make the tab itself unresponsive well before any chart-specific
optimization matters.

## 5. Reconcile With the Query Cache, Don't Fork State

When a live widget also has a fetched baseline from `react-state-
management`'s TanStack Query pattern (the widget shows the last-fetched
snapshot, then live-patches it), apply the tick as a cache patch via that
query's own `QueryClient` (`react-state-management`: each fragment owns
its own `QueryClient`) rather than maintaining a second, untracked
`useState` that can drift out of sync with the cached baseline on the
next normal refetch.

## 6. Connection Lifecycle Is Its Own Signal

A live widget has a state the four-state standard in `references/widget-
state-standard.md` doesn't cover on its own: connection health. When the
socket drops or polling starts failing, show a distinct "reconnecting" /
"last updated Xs ago" indicator rather than silently continuing to
display stale data as if it were current — a frozen live widget that
still looks live is misleading specifically because live widgets carry an
implicit "this is current" promise the static four states don't.

## 7. Cleanup Is Mandatory

Every live subscription's effect returns a cleanup function that closes
the socket or clears the polling interval (`react-performance-
optimization` Part 5's cleanup rule applies verbatim here) — an
uncleaned subscription both leaks a connection and can call `setState` on
an unmounted component after the widget is removed from a dashboard.
