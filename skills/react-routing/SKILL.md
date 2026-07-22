---
name: react-routing
description: >
  Teaches how to implement routing across this plugin's shell + remotes
  microfrontend layout — the shell's top-level path-to-fragment mapping
  via lazy Module Federation remote loading, each fragment's own internal
  nested route tree mirroring its slice of the ux-architect's information
  architecture, URL as the source of truth for filters/sort/pagination,
  typed route params, protected routes gated on the shared shell context,
  remote-load-failure handling (distinct from an ordinary route render
  error), and navigation accessibility (focus/scroll) across both a
  fragment's own routes and the shell→remote transition. Used by the
  frontend-engineer during Implement.
version: 2.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, routing, code-splitting, url-state, protected-routes, microfrontend]
---

# React Routing

## Purpose

Routing turns the ux-architect's information architecture into navigable
URLs, split across two owners: the **shell** owns the top-level
path-to-fragment mapping (`microfrontend-architecture`,
`react-project-structure`), and each **fragment** owns a complete, ordinary
nested route tree within its mount point. The route tree mirrors the IA
hierarchy at both levels, and the URL structure follows the IA's defined
patterns exactly — so a URL is meaningful, shareable, and bookmarkable
regardless of which app owns that segment.

The default router is React Router (declarative, mature). The IA is the
contract — routes are not invented here, at either level. Full host↔remote
composition code, the routing-pattern rationale, and remote-load-failure
handling: `references/cross-remote-composition.md`.

---

## Shell + Remote Split, at a Glance

The shell's router declares each fragment's mount path and lazily loads
its Module Federation exposed module — the same lazy-loading mechanism a
single-app router already uses for heavy in-app features, just resolving
a federated remote instead of a same-build chunk. Within its mount point,
a fragment owns an ordinary nested route tree, no different from a
single-app router. Full code for both sides, and why this repo defaults
to shell-owned client-side composition over hyperlink handoff:
`references/cross-remote-composition.md`.

URL segments use the Ubiquitous Language plural nouns from the IA
(`data-assets`, not `files`) regardless of which app owns that segment —
the IA remains the single source for URL structure.

---

## URL State and Typed Params

Filters, sort, pagination, and the active selection live in the URL, not
component state — validated on parse, never trusted via an `as` cast, at
both the route-param and search-param level. This is unchanged from the
single-app model — nothing about URL-as-state differs inside a fragment.
Full code (validated parse/serialise round-trip, typed param accessors):
`references/url-state-and-params.md`.

---

## Protected Routes, via the Shell Context

Routes that require authentication or a specific permission are gated by
a wrapper that checks auth state and the typed `Permission` from
`typescript-types`. Auth/tenant/permission state comes from the shell
context (`microfrontend-architecture`'s narrow, versioned, read-mostly
shared context) — **a fragment never maintains its own independent auth
state**; it reads the shell's.

```tsx
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
user can't do; the server guarantees it. This is unchanged from the
single-app model — only the source of the auth state moved, from a local
hook to the shell context.

---

## Focus and Scroll on Navigation

An SPA route change reloads nothing, so the browser gives no cue that the
page changed — a screen-reader user hears silence and keyboard focus is
stranded on the old page's DOM. On navigation, at every level (shell,
and within each fragment):

- **Move focus** to the new page's `<h1 tabIndex={-1}>` (or announce the
  new title via a live region) — see `react-accessibility`.
- **Update `document.title`** to the new page's title.
- **Restore scroll** with the data router's `<ScrollRestoration />`.

These rules apply unchanged across a shell→remote transition and within a
fragment's own internal navigation — see
`references/cross-remote-composition.md` for why a fragment must uphold
this contract independently, not rely on the shell to do it once.

---

## Not-Found and Error Handling

- A catch-all `path: "*"` renders a friendly 404 (shell-owned, with
  navigation back into the IA).
- Each route subtree has an `errorElement` so a thrown render error
  degrades that region, not the whole app (see `react-observability`).
- **Remote-load failure is a distinct failure mode from a route render
  error** — a fragment whose code never arrived (network failure, bad
  deploy, version conflict) needs a shell-owned fallback, not the failed
  fragment's own UI. Every fragment's mount point needs its own
  `errorElement` for exactly this reason. Full pattern:
  `references/cross-remote-composition.md`.
- A 404 from the API (resource doesn't exist) renders the same not-found
  UI as an unknown route, for consistency.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Mirrors the IA | Route tree + URLs match the IA structure/labels, at both shell and fragment level | Routes/URLs invented outside the IA |
| Shell/fragment split | Shell owns mount-path mapping only; fragment owns everything past it | Shell reaching into a fragment's internal routes |
| Route code-splitting | Fragments lazy-loaded via Module Federation; heavy in-fragment features their own chunk | Everything in one initial bundle |
| URL as state | Filters/sort/pagination/selection in the URL | Shareable view state in component state |
| Typed params | Params parsed/validated; invalid → 404 | Unvalidated `as` casts on params |
| Protected routes | Auth/permission gates read the shell context | A fragment maintaining its own independent auth state |
| Remote-load failure handled | Every fragment mount point has its own `errorElement` for load failure | A broken remote crashes the whole shell |
| Navigation a11y | Focus moved + title updated at both shell and fragment level | Silent SPA navigation; focus stranded |

---

## Anti-Patterns

| Anti-pattern | Instead |
|---|---|
| Inventing routes/URLs not in the IA | The IA is the contract — change the IA first |
| A fragment maintaining its own auth/permission state independently | Read from the shell context — one source of truth |
| `as SensitivityLevel` casts on params/search params | Validated parse with a safe default |
| Duplicating URL state into component state ("hydrate on mount") | Read the URL directly; it *is* the state |
| Auth gate in the frontend treated as security | It's UX only — the backend's ABAC enforces |
| One error boundary for the whole shell, none per fragment mount point | `errorElement` per fragment mount, distinct from per-route errors |
| Treating a remote-load failure the same as a route render error | Shell-owned fallback UI — the failed fragment's own UI never arrived |
| `useEffect` + `navigate()` for redirects reachable in render | `<Navigate replace />` during render |
| Deep-linking breaks (blank page on refresh of a nested fragment route) | Test every route, including inside fragments, by direct URL entry |

---

## Output Format

Produces the shell router, each fragment's internal router, guards, and
routing tests:

```
apps/shell/src/app/router.tsx           (top-level path-to-fragment mapping, lazy remote loading)
apps/shell/src/app/AppLayout.tsx        (persistent navigation)
apps/shell/src/shell-context/           (auth/tenant/permission state fragments read from)
apps/<fragment>/src/features/<name>/<Name>App.tsx   (fragment's own nested route tree)
apps/shell/src/app/router.test.tsx      (navigation + guard tests; written first)
```
