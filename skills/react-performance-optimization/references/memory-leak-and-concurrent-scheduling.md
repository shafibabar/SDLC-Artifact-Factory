# Memory-Leak Cleanup and Concurrent Scheduling — Worked Examples

Self-contained reference for `react-performance-optimization`. Covers the full cleanup-effect pattern behind the memory-leak-prevention standard, and the full worked example behind the concurrent-scheduling standard (`useDeferredValue`/`useTransition`). Read this when writing an effect that subscribes to something external, or when deciding whether a slow render needs deferred/transitional scheduling on top of (never instead of) memoization and virtualization.

---

## Memory-Leak Prevention: The Cleanup Contract, Worked

A long-lived SPA never fully unmounts — screens mount and unmount repeatedly as the user navigates, so any effect that subscribes to something external and doesn't clean up leaks one more listener/timer/in-flight-request per mount, compounding silently over a session.

```tsx
useEffect(() => {
  const ctrl = new AbortController();
  window.addEventListener("resize", onResize, { signal: ctrl.signal });
  const id = setInterval(poll, 30_000);
  fetch("/api/estate-overview", { signal: ctrl.signal }).then(handleOverview);

  return () => {
    ctrl.abort();          // aborts the fetch AND removes the listener (signal-scoped)
    clearInterval(id);
  };
}, [onResize]);
```

**The rule, exhaustively:** every `addEventListener`, `setInterval`/`setTimeout`, subscription (WebSocket, observable), or in-flight `fetch` started inside an effect has a matching teardown in that effect's cleanup function. A single `AbortController` can cover both an event listener (via the `signal` option) and a fetch (forwarded to the API client — see `react-api-client`) in one cleanup call.

**Verification, not assumption:** open a heap snapshot, mount and unmount the screen under test repeatedly (10+ cycles), and take a second snapshot. Live node count and listener count must return to the same baseline each cycle — a monotonically growing count across cycles is a leak, found before it ships rather than after a support ticket about a browser tab that slows down over a workday.

---

## Concurrent Scheduling: `useDeferredValue` and `useTransition`, Worked

Some renders are expensive even after profiling-justified memoization and virtualization — re-filtering thousands of rows on every keystroke is real work that has to happen somewhere. React's concurrent scheduling APIs don't reduce that work; they let an urgent update (the keystroke landing in the input) interrupt a non-urgent one (the filtered list re-rendering), so the input never feels janky even while the list is still catching up.

```tsx
function AssetSearch({ assets }: { assets: ReadonlyArray<DataAsset> }) {
  const [query, setQuery] = useState("");
  const deferredQuery = useDeferredValue(query);   // lags behind during heavy renders
  const filtered = useMemo(
    () => assets.filter((a) => a.name.includes(deferredQuery)),
    [assets, deferredQuery],
  );
  return (
    <>
      <input value={query} onChange={(e) => setQuery(e.target.value)} /> {/* always instant */}
      <AssetTable rows={filtered} />                                      {/* renders at lower priority */}
    </>
  );
}
```

- **`useDeferredValue`** defers a **value** that drives an expensive render — the input's displayed `query` stays instant while `deferredQuery` (and everything derived from it) lags a beat behind under load.
- **`startTransition` / `useTransition`** mark a **state update** itself as non-urgent (a tab switch that renders a heavy panel) rather than deferring a value; `isPending` from `useTransition` drives a subtle busy indicator so the delay reads as intentional, not broken.

**Decision criteria:** reach for these only after profiling shows a specific interaction (typing, a tab switch) is blocked by an unavoidably expensive render that virtualization and memoization have already reduced as far as they can — not as a first response to any slow list. These APIs change **when** work happens (scheduling), not **how much** work happens; they complement virtualization and memoization, they never substitute for them. A virtualizable list that's still slow because it isn't virtualized is a virtualization bug, not a scheduling one.
