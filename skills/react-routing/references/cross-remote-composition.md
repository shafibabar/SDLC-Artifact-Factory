# Cross-Remote Route Composition

Full host↔remote routing code, the routing-pattern choice, and
remote-load-failure handling. Self-contained — loadable without reading
`SKILL.md` first, though it assumes `microfrontend-architecture`'s
decomposition/composition decisions and `react-project-structure`'s
shell+remotes layout.

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

## Host Route Tree — Lazy Remote Loading

The shell owns the top-level path-to-fragment mapping. Each fragment's
route subtree loads via its Module Federation `exposes` entry, lazily,
the same way a heavy in-app feature would lazy-load in a single-app
router — the mechanism is identical; only the module's origin (a
same-build chunk vs. a federated remote) differs.

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
          // dynamic import of a Module Federation remote — see microfrontend-architecture's
          // references/module-federation-config.md for the underlying resolution mechanics
          const { DataAssetsApp } = await import("dataAssets/DataAssetsApp");
          return { Component: DataAssetsApp };
        },
        errorElement: <RemoteLoadError fragment="data-assets" />,   // see Remote-Load Failure below
      },
      { path: "compliance/*", lazy: async () => { /* same pattern */ } },
      { path: "*", element: <NotFoundPage /> },                     // catch-all 404, shell-owned
    ],
  },
]);
```

The `/*` wildcard on each fragment's mount path is deliberate: the shell
only owns *where* a fragment mounts, not what happens inside it — the
fragment owns everything past that point (see Remote's Own Route Tree
below).

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

## Remote-Load Failure Is a Distinct Failure Mode

A broken remote (network failure, a bad deploy, a version-negotiation
conflict per `microfrontend-architecture`) is a **partial or full runtime
failure**, per Mezzalira's caveat about client-side composition — the
shell must degrade gracefully, not crash the whole app because one
fragment's `remoteEntry.js` failed to load:

```tsx
function RemoteLoadError({ fragment }: { fragment: string }) {
  return (
    <ErrorRegion>
      <p>The {fragment} section is temporarily unavailable.</p>
      <RetryButton onRetry={() => window.location.reload()} />
    </ErrorRegion>
  );
}
```

This is a **different failure category** from an ordinary route-level
render error (`errorElement` on a locally-owned route) — a remote load
failure means the fragment's code never arrived at all, so the fallback
must be entirely shell-owned content, not anything from the failed
fragment. Treat every fragment's mount point as needing its own
`errorElement` for exactly this reason, even ones that "never fail in
testing" — the failure mode is a production deploy/network condition, not
a logic bug a test suite would catch.

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
