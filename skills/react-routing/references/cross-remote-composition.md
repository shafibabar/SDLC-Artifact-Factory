# Cross-Remote Route Composition and Route-Tree Ownership

Full host↔remote routing code, the route-tree ownership standard, the
protected-route guard, and the routing-pattern rationale. Self-contained
— loadable without reading `SKILL.md` first, though it assumes
`microfrontend-architecture`'s decomposition/composition decisions and
`react-project-structure`'s shell+remotes layout. Remote-load-failure
retry/backoff and the fallback UI are covered in full in the sibling file
`references/remote-load-failure-handling.md` — this file states the
distinction where it's first relevant (the fragment mount point) and
points there for the full standard, rather than duplicating it.

---

## Why Shell-Owned Client-Side Composition (Not Hyperlink Handoff)

Geers's research (`research/micro-frontends/micro-frontends-in-action-geers.md`)
presents a routing spectrum from plain hyperlink handoff between
separately-deployed pages (zero coupling, a genuine full-page navigation)
up to a shared client-side shell that owns the URL-to-fragment mapping.
This plugin defaults to **shell-owned client-side composition** because
it matches the chosen Module Federation composition pattern
(`microfrontend-architecture`) — fragments already resolve into one SPA
session, so routing between them should feel unified, not force a full
page reload between two fragments in the same product experience.

**Hyperlink handoff remains the right choice for boundaries that genuinely
don't need to feel unified** — e.g. a marketing site handing off to the
authenticated app — per Geers's point that this is a legitimate first
rung, not a compromise. Default to shell-owned composition within one
product's fragments; use hyperlink handoff only where the UX genuinely
doesn't require a seamless transition.

## The Route-Tree Ownership Standard

Two scales, two owners, and neither reaches into the other's territory:

| What | Owner | Why |
|---|---|---|
| Persistent top-level layout (nav shell, header) | Shell | It's the one visual frame every fragment renders inside |
| Path-to-fragment mount mapping (`data-assets/*` → the `dataAssets` remote) | Shell, the only place this is declared | A fragment doesn't know, and shouldn't need to know, its own mount path — see Remote's Own Route Tree below |
| Auth/permission guards | Shell — reads its own shell context, exposes a guard component fragments compose | A fragment maintaining independent auth state would drift from the shell's actual session state (`react-state-management`'s Cross-Fragment State rule) |
| Top-level 404 (an unknown path entirely) | Shell, one catch-all | Consistent not-found UX regardless of which app owns the nearest matched segment |
| Everything past a fragment's mount path (`fragment/*`) | The fragment, completely | From the fragment's own perspective it *is* a single app — it can run standalone for local dev (`react-project-structure`'s standalone-entry note) |
| A not-found for a bad **nested** segment inside a fragment's own subtree | The fragment, optionally | Distinct from the shell's top-level 404 — this is "you're in the right app, wrong sub-path," not "unknown route entirely" |

The test for whether something belongs at the shell or in a fragment: is
this true regardless of which fragment is mounted (shell), or is this
specific to what one fragment's own routes mean (fragment)? A shell
reaching past its mount-path declaration into a fragment's internal
routes, or a fragment trying to declare its own mount path, both violate
this split.

## Host Route Tree — Lazy Remote Loading

The shell owns the top-level path-to-fragment mapping. Each fragment's
route subtree loads via its Module Federation `exposes` entry, lazily,
the same way a heavy in-app feature would lazy-load in a single-app
router — the mechanism is identical; only the module's origin (a
same-build chunk vs. a federated remote) differs. See `SKILL.md`'s
Standard 2 for why this is a distinct, coarser-grained boundary from
`React.lazy`/`Suspense` used *inside* a remote.

```tsx
// apps/shell/src/app/router.tsx
const router = createBrowserRouter([
  {
    path: "/",
    element: <AppLayout />,                 // persistent sidebar nav (IA navigation model)
    errorElement: <RouteError />,           // route-level error boundary (see react-observability)
    children: [
      { index: true, element: <DashboardPage /> },              // owned directly by the shell
      {
        path: "data-assets/*",
        lazy: async () => {
          // retryRemoteImport wraps this in retry-with-backoff for a
          // transient load failure — full standard: references/remote-load-failure-handling.md
          const { DataAssetsApp } = await retryRemoteImport(
            () => import("dataAssets/DataAssetsApp"),
          );
          return { Component: DataAssetsApp };
        },
        errorElement: <RemoteLoadError fragment="data-assets" />,   // distinct from RouteError above
      },
      { path: "compliance/*", lazy: async () => { /* same pattern */ } },
      { path: "*", element: <NotFoundPage /> },                     // catch-all 404, shell-owned
    ],
  },
]);
```

The `/*` wildcard on each fragment's mount path is deliberate: the shell
only owns *where* a fragment mounts, not what happens inside it.

## Protected Routes, via the Shell Context

Routes that require authentication or a specific permission are gated by
a shell-owned wrapper that checks auth state and the typed `Permission`
from `typescript-types`. Auth/tenant/permission state comes from the
shell context (`microfrontend-architecture`'s narrow, versioned,
read-mostly shared context) — **a fragment never maintains its own
independent auth state**; it composes the shell's guard.

```tsx
// apps/shell/src/app/RequirePermission.tsx
function RequirePermission({ perm, children }: { perm: Permission; children: ReactNode }) {
  const { isAuthenticated, hasPermission } = useShellContext();   // from the shell, not fragment-local
  const location = useLocation();
  if (!isAuthenticated) return <Navigate to="/login" state={{ from: location }} replace />;
  if (!hasPermission(perm)) return <ForbiddenPage />;       // mirrors backend ABAC (never reveals why)
  return <>{children}</>;
}
```

This is a **UX** gate, not a security control — the backend's ABAC is the
real enforcement (`access-control-model`). The frontend hides what the
user can't do; the server guarantees it.

## Remote's Own Route Tree

Within its mount point, a fragment owns a complete, ordinary nested route
tree — no different from a single-app router, because from the
fragment's own perspective, it *is* a single app (it can run standalone
for local dev, per `react-project-structure`'s "standalone entry" note).

```tsx
// apps/data-assets/src/features/data-assets/DataAssetsApp.tsx — exposed as "./DataAssetsApp"
export function DataAssetsApp() {
  return (
    <Routes>                                          {/* nested under the shell's "data-assets/*" */}
      <Route index element={<DataAssetListPage />} />           {/* /data-assets */}
      <Route path=":id" element={<DataAssetDetailPage />} />    {/* /data-assets/:id */}
    </Routes>
  );
}
```

URL segments still use the Ubiquitous Language plural nouns from the IA
(`data-assets`, not `files`) — the IA remains the single source for URL
structure regardless of which app owns a given segment.

## Remote-Load Failure: Where the Distinction First Applies

A broken remote (network failure, a bad deploy, a `strictVersion`
negotiation conflict per `microfrontend-architecture`) is a **partial or
full runtime failure**, per Mezzalira's caveat about client-side
composition — the shell must degrade gracefully at exactly the mount
point shown above, not crash the whole app because one fragment's
`remoteEntry.js` failed to load. This is why every fragment's mount point
in the host route tree above carries its own `errorElement`
(`<RemoteLoadError>`), separate from the ordinary `<RouteError>` at the
layout level — a remote-load failure means the fragment's code never
arrived at all, so its fallback must be entirely shell-owned content, not
anything from the failed fragment. The retry-with-backoff policy and the
fallback component's full implementation: `references/remote-load-
failure-handling.md`.

## Focus and Scroll Across a Shell→Remote Transition

The existing single-app focus/scroll rules (move focus to the new page's
heading, update `document.title`, restore scroll via
`<ScrollRestoration />`) apply **unchanged** across a shell→remote
transition — from the user's perspective, navigating into a fragment is
still just a route change, not a distinct event requiring special
handling. The one thing to verify explicitly: a fragment's own internal
`<h1>`/title-update logic must fire on its *own* internal route changes
too (e.g. moving from the list page to a detail page within
`DataAssetsApp`), not just on the shell-level transition into the
fragment — a fragment is a full app internally and must uphold the same
navigation-accessibility contract the shell does.
