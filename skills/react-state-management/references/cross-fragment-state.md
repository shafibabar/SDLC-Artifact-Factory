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

### Worked Failure Mode: What Sharing a `QueryClient` Actually Breaks

The temptation is concrete, so the failure should be too. Say a shell
developer, trying to avoid the duplicated `data-assets` fetch above,
hoists one `QueryClient` instance into the shell and passes it down to
every remote via the shell context, instead of each remote instantiating
its own:

```ts
// DON'T: one QueryClient, shared across the fragment boundary
// apps/shell/src/shell-context/query-client.ts
export const sharedQueryClient = new QueryClient({ /* one config for every fragment */ });
```

This looks like it removes the duplication cheaply. What it actually does:

- **Cache shape becomes a cross-fragment contract.** The `data-assets`
  fragment can no longer change its own query-key structure, its
  `select` transform, or its `staleTime`/`gcTime` tuning
  (`references/tanstack-query-patterns.md`) without checking every other
  fragment reading the same keys from the same cache — exactly the
  build-time coordination independent deployability exists to remove.
- **A TanStack Query version bump in one fragment is now a version bump
  for all of them.** Each fragment is independently built and deployed;
  if the shared instance is version-pinned in the shell, no remote can
  adopt a new TanStack Query major version on its own schedule. If it
  isn't pinned, two remotes built against different TanStack Query
  versions may not even agree on the shared instance's method signatures.
- **A cache bug in one fragment corrupts state for fragments that never
  touched it.** `qc.setQueryData` or `qc.clear()` called anywhere in the
  shared instance's lifetime affects every fragment holding a reference
  to it — a bug in fragment A's cleanup code can silently blank data
  fragment B is currently rendering, with no import or call site in B's
  own source pointing to the cause.

Each fragment instantiating its own `QueryClient` — accepting the
duplicated fetch — avoids all three. This is the same trade the
accepted-cost framing above names in the abstract; this is what it looks
like concretely when someone tries to skip it.

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

| Criterion | Pass | Fail | How a reviewer verifies |
|---|---|---|---|
| Query cache scope | Each fragment owns its own `QueryClient` | A `QueryClient` instance shared/imported across fragment boundaries | Grep every `apps/*/src` for `new QueryClient(` — exactly one per fragment, none imported from `apps/shell` |
| Client-state store scope | Zustand/Jotai stores never leave their fragment | A store imported into a different fragment | `eslint-plugin-boundaries` (`react-project-structure`) fails a cross-fragment import at CI; confirm zero suppressions on a store file |
| Cross-fragment reads | Shell context only, narrow and read-mostly | A fragment reading another fragment's store/cache directly | Every non-`shell-context` cross-fragment import in a fragment's `package.json` is `packages/design-system` or `packages/api-client` only |
| Cross-fragment reactions | Custom events, each fragment invalidates its own cache | A shared invalidation mechanism spanning fragments | Each `window.addEventListener` handler's `invalidateQueries` call uses that fragment's own `qc`, never one threaded in from elsewhere |

## Anti-Patterns (Cross-Fragment Additions)

| Anti-pattern | Instead |
|---|---|
| Sharing a `QueryClient` instance across fragments to "avoid duplicate fetches" | Each fragment owns its cache; accept the duplication as the cost of independence |
| A Zustand/Context store imported by more than one fragment | Fragment-local only; use the shell context or events for the rare cross-fragment need |
| A custom event handler invalidating another fragment's cache directly | Each fragment listens and invalidates only its own cache |
| Treating cache/state duplication across fragments as a bug to eliminate | It's an accepted cost — eliminating it by sharing recreates the coupling decomposition removed |
