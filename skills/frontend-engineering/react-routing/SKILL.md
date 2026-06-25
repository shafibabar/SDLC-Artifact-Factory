---
name: react-routing
description: >
  Teaches how to implement routing from the ux-architect's information architecture
  — the route tree mirroring the IA and URL structure, route-level code-splitting
  with lazy + Suspense, URL as the source of truth for filters/sort/pagination,
  typed route params, protected routes gated on auth/permissions, data loading
  patterns, and not-found/error route handling. Implements the IA's URL structure
  from Chunk 10. Used by the frontend-engineer during Implement.
version: 1.0.0
phase: implement
owner: frontend-engineer
tags: [implement, frontend, react, routing, code-splitting, url-state, protected-routes]
---

# React Routing

## Purpose

Routing turns the ux-architect's information architecture into navigable URLs. The route tree mirrors the IA hierarchy (Chunk 10), and the URL structure follows the IA's defined patterns exactly — so a URL is meaningful, shareable, and bookmarkable. Routing is also the natural seam for code-splitting: each route loads only the code it needs.

This skill implements the IA's URL structure; the default router is React Router (declarative, mature). The IA is the contract — routes are not invented here.

---

## Route Tree Mirrors the IA

The IA hierarchy maps one-to-one to the route tree, using the IA's URL patterns.

```tsx
// src/app/router.tsx — mirrors the information-architecture from Chunk 10
const router = createBrowserRouter([
  {
    path: "/",
    element: <AppLayout />,                 // persistent sidebar nav (IA navigation model)
    errorElement: <RouteError />,           // route-level error boundary (see react-observability)
    children: [
      { index: true, element: <DashboardPage /> },              // /
      {
        path: "data-assets",
        children: [
          { index: true, element: <DataAssetListPage /> },      // /data-assets
          { path: ":id", element: <DataAssetDetailPage /> },    // /data-assets/:id
        ],
      },
      { path: "data-sources", children: [ /* … */ ] },          // /data-sources
      { path: "compliance",   children: [ /* … */ ] },          // /compliance
      { path: "reports",      children: [ /* … */ ] },          // /reports
      { path: "*", element: <NotFoundPage /> },                 // catch-all 404
    ],
  },
]);
```

URL segments use the Ubiquitous Language plural nouns from the IA (`data-assets`, not `files`). The label/URL inventory in the IA is the source.

---

## Route-Level Code-Splitting

Each page is lazy-loaded so the initial bundle contains only the shell and the landing route — everything else loads on navigation. This is the highest-leverage code-splitting boundary (detail in `react-performance-optimization`).

```tsx
const DataAssetListPage = lazy(() => import("@/features/data-assets/DataAssetListPage"));

// Wrap routed content in Suspense with a sensible fallback:
<Suspense fallback={<PageSkeleton />}>
  <Outlet />
</Suspense>
```

Heavy, rarely-first-seen features — notably the **estate graph** (a large WebGL dependency, see `react-graph-visualization`) — are always their own chunk, so the graph library never bloats the initial load of users who go straight to a dashboard.

---

## URL as the Source of Truth

Filters, sort, pagination, and the active selection live in the URL (search params), not component state — so a filtered view is shareable and survives refresh (the decision recorded in `react-state-management`). The IA defines these query params (`?sensitivity=Confidential&sort=name`).

```tsx
function DataAssetListPage() {
  const [params, setParams] = useSearchParams();
  const filter: AssetFilter = {
    sensitivity: params.get("sensitivity") as SensitivityLevel | null,
    sort: params.get("sort") ?? "name",
    page: Number(params.get("page") ?? "1"),
  };
  const { data, isLoading, error } = useDataAssets(filter); // URL → query key → fetch
  // changing a filter updates the URL, which re-derives the query:
  const onFilter = (s: SensitivityLevel) => setParams((p) => { p.set("sensitivity", s); return p; });
  // …
}
```

The URL flows into the TanStack Query key, so navigation and data stay in sync automatically.

---

## Typed Route Params

Route params are strings and must be parsed/validated, not trusted. Centralise typed accessors so pages don't sprinkle `as` casts.

```tsx
function useDataAssetId(): string {
  const { id } = useParams();
  if (!id || !isUuid(id)) throw new Response("Not Found", { status: 404 }); // → nearest errorElement
  return id;
}
```

Invalid params route to the not-found/error UI rather than crashing or fetching garbage.

---

## Protected Routes

Routes that require authentication or a specific permission are gated by a wrapper that checks the auth state (and the typed `Permission` from `typescript-types`). Unauthenticated users are redirected to login with a return path; authenticated-but-unauthorised users see a forbidden view.

```tsx
function RequirePermission({ perm, children }: { perm: Permission; children: ReactNode }) {
  const { isAuthenticated, hasPermission } = useAuth();
  const location = useLocation();
  if (!isAuthenticated) return <Navigate to="/login" state={{ from: location }} replace />;
  if (!hasPermission(perm)) return <ForbiddenPage />;       // mirrors backend ABAC (never reveals why)
  return <>{children}</>;
}
```

This is a **UX** gate, not a security control — the backend's ABAC is the real enforcement (`access-control-model`). The frontend hides what the user can't do; the server guarantees it.

---

## Not-Found and Error Handling

- A catch-all `path: "*"` renders a friendly 404 (with navigation back into the IA).
- Each route subtree has an `errorElement` so a thrown render error degrades that region, not the whole app (route-level error boundaries — see `react-observability`).
- A 404 from the API (resource doesn't exist) renders the same not-found UI as an unknown route, for consistency.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Mirrors the IA | Route tree + URLs match the IA structure/labels | Routes/URLs invented outside the IA |
| Route code-splitting | Pages lazy-loaded; heavy features isolated chunks | Everything in one initial bundle |
| URL as state | Filters/sort/pagination/selection in the URL | Shareable view state in component state |
| Typed params | Params parsed/validated; invalid → 404 | Unvalidated `as` casts on params |
| Protected routes | Auth + permission gates with redirect/forbidden | Sensitive routes reachable unauthenticated |
| Graceful 404/errors | Catch-all 404; per-subtree errorElement | Blank screen / full-app crash on bad route |

---

## Output Format

Produces the router, route guards, and routing tests:

```
src/app/router.tsx                 (route tree mirroring the IA)
src/app/AppLayout.tsx               (persistent navigation)
src/shared/auth/RequirePermission.tsx
src/app/router.test.tsx             (navigation + guard tests; written first)
```
