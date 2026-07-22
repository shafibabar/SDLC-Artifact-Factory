# Cross-Fragment State

The real answer for state that spans independently-built, independently-
deployed fragments — the question the single-app version of this skill
was silent on. Self-contained — loadable without reading `SKILL.md`
first, though it assumes `microfrontend-architecture`'s decomposition and
cross-fragment-communication rules.

---

## Server State: Per-Fragment, Never Shared

Each fragment owns its own `QueryClient` instance — there is no shared,
cross-fragment TanStack Query cache, even though the cache is
"server state" rather than client UI state. This follows the same logic
`microfrontend-architecture` applies to a shared client-side store: a
cache shared across fragment boundaries is a shared mutable dependency
every fragment would need to coordinate around, which recreates the exact
coupling independent deployability exists to remove — a fragment's
`QueryClient` instantiation, cache config, and invalidation rules
shouldn't need to agree with another fragment's.

**The accepted cost**: if two fragments both need overlapping server data
(e.g. a dashboard widget in one fragment and a detail page in another both
need `data-assets`), each fetches and caches it independently — a
duplicated network request, not a shared cache hit. Per Geers's research,
this is a real, accepted cost of the architecture (like framework
duplication page weight), not a bug to engineer around by sharing a
`QueryClient` — sharing it would be a build-time coupling smuggled back in
through a technical shortcut. If the duplication becomes a genuine
performance problem for a specific pair of fragments, that's a signal to
re-examine whether they should be one fragment (re-check the Bounded
Context boundary via `microfrontend-architecture`'s
`assets/fragment-ownership-canvas.md`), not a signal to share a cache
across a boundary that's supposed to stay independent.

## Client State: Fragment-Local, Never Cross-Fragment

Zustand/Jotai stores (this skill's escalation path from co-location) are
scoped to **one fragment** — the same "co-locate first, escalate only
when justified" discipline applies, but the ceiling is the fragment
boundary, not the whole product. **A store spanning fragment
boundaries is exactly the shared-mutable-store anti-pattern
`microfrontend-architecture` bans outright** — it doesn't matter whether
it's Zustand, Context, or Redux; sharing a client-side store across
fragments recreates monolith-style coupling regardless of which state
library implements it.

## What Actually Crosses a Fragment Boundary

Per `microfrontend-architecture`'s Cross-Fragment Communication rules, in
order of preference — this skill doesn't redefine these, it shows what
consuming them looks like from fragment-local code:

```ts
// Reading the shell context — narrow, versioned, read-mostly (never a general store)
function useCurrentTenant(): TenantId {
  const { tenantId } = useShellContext();     // provided by the shell, not fragment-local state
  return tenantId;
}

// Listening for a cross-fragment notification — a fragment doesn't know or care who emitted it
useEffect(() => {
  const onClassificationChanged = (e: CustomEvent<{ assetId: string }>) => {
    qc.invalidateQueries({ queryKey: ["data-assets", e.detail.assetId] }); // react locally, own cache only
  };
  window.addEventListener("classification-changed", onClassificationChanged as EventListener);
  return () => window.removeEventListener("classification-changed", onClassificationChanged as EventListener);
}, [qc]);
```

Notice the event handler still only touches **this fragment's own**
`QueryClient` — the event crosses the boundary, the cache invalidation it
triggers does not. This is the pattern for the rare case two fragments'
server-state caches need to react to the same underlying change without
sharing a cache: each fragment listens independently and invalidates its
own copy.

## Quality Criteria (Cross-Fragment Additions)

| Criterion | Pass | Fail |
|---|---|---|
| Query cache scope | Each fragment owns its own `QueryClient` | A `QueryClient` instance shared/imported across fragment boundaries |
| Client-state store scope | Zustand/Jotai stores never leave their fragment | A store imported into a different fragment |
| Cross-fragment reads | Shell context only, narrow and read-mostly | A fragment reading another fragment's store/cache directly |
| Cross-fragment reactions | Custom events, each fragment invalidates its own cache | A shared invalidation mechanism spanning fragments |

## Anti-Patterns (Cross-Fragment Additions)

| Anti-pattern | Instead |
|---|---|
| Sharing a `QueryClient` instance across fragments to "avoid duplicate fetches" | Each fragment owns its cache; accept the duplication as the cost of independence |
| A Zustand/Context store imported by more than one fragment | Fragment-local only; use the shell context or events for the rare cross-fragment need |
| A custom event handler invalidating another fragment's cache directly | Each fragment listens and invalidates only its own cache |
| Treating cache/state duplication across fragments as a bug to eliminate | It's an accepted cost — eliminating it by sharing recreates the coupling decomposition removed |
