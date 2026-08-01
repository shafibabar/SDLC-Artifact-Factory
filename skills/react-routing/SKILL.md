---
name: react-routing
description: >
  Teaches routing across this plugin's shell + remotes microfrontend
  layout as four standards: route-tree ownership (exactly which routes
  the shell owns — top-level layout, auth guard, 404 — versus the
  complete nested route subtree each remote owns beneath its
  shell-defined mount path); lazy-loading/code-splitting, placing
  React.lazy/Suspense boundaries within one remote's own bundle and
  distinguishing that precisely from Module Federation's own,
  coarser-grained remoteEntry.js async-chunk boundary that resolves
  before any React.lazy inside that remote even runs; remote-load
  failure — retry-with-backoff at the Module Federation loading layer
  plus a shell-owned fallback UI, distinct from an ordinary React
  render-error boundary because a load failure means the remote's code
  never executed at all; and URL state — the exact test for whether a
  value belongs in a route param, a search param, or component state,
  with deep-linking/shareable-URL correctness as the pass/fail check.
  Used by the frontend-engineer during Implement.
version: 3.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, routing, code-splitting, url-state, protected-routes, microfrontend, remote-load-failure, retry]
produces: react-router-configuration
domain: frontend
status: stable
related: [react-project-structure, microfrontend-architecture, react-state-management, react-accessibility, react-api-client, access-control-model]
---

# React Routing

## Purpose

Routing turns the ux-architect's information architecture into navigable
URLs, split across two owners: the **shell** owns the top-level
path-to-fragment mapping; each **fragment** owns a complete, ordinary
nested route tree within its mount point. The IA is the contract — routes
are not invented at either level. Default router: React Router (data-
router APIs). This body states four standards; each has a full worked
reference: route-tree ownership and the protected-route guard —
`references/cross-remote-composition.md`; remote-load-failure retry and
fallback UI — `references/remote-load-failure-handling.md`; URL state —
`references/url-state-and-params.md`.

---

## Standard 1 — Route-Tree Ownership

| Owns | Shell | Remote |
|---|---|---|
| Top-level layout (persistent nav) | Yes | No — renders inside it |
| Mount-path-to-fragment mapping | Yes, the only place it's declared | No |
| Auth/permission guards | Yes — reads its own shell context; a remote never keeps independent auth state | Composes the shell's guard; never re-implements the check |
| 404 (unknown top-level path) | Yes, one catch-all | May add its own not-found for a bad nested segment |
| Everything past its mount path (`fragment/*`) | No — the `/*` wildcard is deliberate | Yes — a complete nested route tree, no different from a single-app router |

A fragment reads auth/tenant/permission state from the shell context
(`microfrontend-architecture`'s narrow, read-mostly shared context) — a
UX gate only; the backend's ABAC is the real enforcement
(`access-control-model`). Full host↔remote code and the guard component:
`references/cross-remote-composition.md`.

---

## Standard 2 — Lazy-Loading and Code-Splitting

Two distinct, non-competing async boundaries exist, and conflating them
is this layout's most common routing mistake. **Module Federation's own
async-chunk boundary** resolves first: a remote's `exposes` entry is
already its own async chunk by construction, fetched when the shell's
`lazy: async () => import("remote/App")` runs, *before* any code inside
that remote executes — `react-project-structure`'s own stated
clarification (`references/typescript-and-tree-shaking.md`: "A federation
`exposes` entry becomes its own async chunk regardless of `sideEffects`
settings — the exposed module boundary is already a code-split point by
construction"); this skill cross-references that fact rather than
restating it as new. **`React.lazy`/`Suspense` inside one remote's own
bundle** is a separate, finer-grained, later-resolving split — for a
heavy in-fragment route or component that remote doesn't always render.

**Never wrap a whole federated remote import in a second `React.lazy()`**
— the `exposes` entry is already the async boundary; a second wrapper
adds no split, only redundant `Suspense` nesting. Component-level
splitting for anything heavy and not always visible is
`react-performance-optimization`'s territory.

---

## Standard 3 — Remote-Load Failure Is Not a Render Error

A remote-load failure — a dynamic `import()` of a `remoteEntry.js` that
never arrives (network failure, a remote mid-deploy briefly 404ing, a
`strictVersion` negotiation conflict) — is a **distinct failure category**
from an ordinary route render error thrown by code that loaded and ran.
The fallback must be entirely **shell-owned**: the failed remote's own UI
never arrived, so nothing of the remote's own can render it.

**Transient causes** (network blip, a remote briefly 404ing mid-deploy)
get an automatic retry with exponential backoff and jitter at the Module
Federation loading layer, mirroring `react-api-client`'s own backoff
shape. **Deterministic causes** (a `strictVersion` conflict per
`microfrontend-architecture`) are never retried — retrying reproduces the
identical failure — and go straight to the fallback. Every fragment's
mount point needs its own `errorElement` for exactly this reason, even
one that "never fails in testing": this is a production deploy/network
condition, not a logic bug a test suite reaches. Full retry/backoff
function and fallback component: `references/remote-load-failure-
handling.md`.

---

## Standard 4 — URL State

**The test:** does the value identify *which* resource this route is
about (route param); does it describe *a view* over that resource a
colleague pasting this URL should see reproduced exactly (search param);
or does it have no meaning beyond this one render (component state)?

| Value | Lives in |
|---|---|
| The resource being viewed (`:id`) | Route param |
| Filter, sort, pagination, active tab, selection | Search param |
| Live keystroke value before submit, hover, transient animation | Component state |

**Deep-linking correctness is the pass/fail check**: paste the URL in a
fresh tab — if the visible state doesn't reproduce exactly, something
that should be a route/search param is trapped in memory. Both param
kinds are untrusted input requiring a validated parse with a safe
default, never an `as` cast — matching `react-state-management`'s "URL as
State" section exactly. Full round-trip parse/serialise and typed
accessors: `references/url-state-and-params.md`.

---

## Focus and Scroll on Navigation

An SPA route change gives no native cue the page changed.
`react-accessibility` owns the general focus-management standard and
states that SPA routing breaks the native focus reset — this skill
implements that at **every** transition, shell→remote and a fragment's
own internal navigation alike: move focus to the new page's
`<h1 tabIndex={-1}>` (or a live-region announcement), update
`document.title`, restore scroll via `<ScrollRestoration />`. A fragment
must uphold this independently on its own internal route changes — the
shell doing it once on the outer transition doesn't cover them.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Mirrors the IA | Route tree + URLs match the IA at both levels | Routes/URLs invented outside the IA |
| Route-tree ownership | Shell owns layout/mapping/guards/404 only; remote owns everything past its mount path | Shell reaching into a remote's routes, or a remote re-declaring its mount path |
| Protected routes | Guard reads the shell context; no fragment-local auth state | A fragment maintaining independent auth/permission state |
| MF boundary vs. `React.lazy` | Distinct, non-redundant boundaries | A federated remote import double-wrapped in `React.lazy()` |
| Remote-load failure handled | Every mount point has its own `errorElement`; transient retried with backoff, deterministic fails fast; shell-owned fallback | Whole shell crashes; indefinite retry; failed fragment's own (never-arrived) UI shown |
| URL state placement | Route/search/component-state choice matches the test | Shareable view state trapped in component state |
| Deep-linking correctness | Pasting the URL in a fresh tab reproduces the exact state | Blank page or lost filters on refresh/direct entry |
| Typed, validated params | Both param kinds parsed/validated; invalid → 404 | Unvalidated `as` casts |
| Navigation a11y | Focus + title updated at every transition, shell and fragment alike | Silent navigation; focus stranded |

---

## Anti-Patterns

| Anti-pattern | Instead |
|---|---|
| Inventing routes/URLs not in the IA | The IA is the contract — change it first |
| A fragment maintaining its own auth/permission state | Read from the shell context — one source of truth |
| A federated remote import wrapped in a second `React.lazy()` | `exposes` is already the async boundary; use `React.lazy` only within the remote |
| Treating a remote-load failure like a route render error | Distinct `errorElement`; shell-owned fallback |
| Retrying a deterministic `strictVersion` failure | Fail fast — retrying reproduces the identical failure |
| Retrying a remote load with no backoff, or indefinitely | Exponential backoff + jitter, capped attempts |
| Filters/sort/selection kept in component state | The URL — shareable, bookmarkable, refresh-survivable |
| `as SensitivityLevel` casts on route/search params | Validated parse with a safe default |
| Auth gate in the frontend treated as security | UX only — the backend's ABAC enforces |
| `useEffect` + `navigate()` for redirects reachable in render | `<Navigate replace />` during render |
| Deep-linking breaks on refresh of a nested fragment route | Test every route, including inside fragments, by direct URL entry |

---

## Output Format

```
apps/shell/src/app/router.tsx              (top-level path-to-fragment mapping, lazy remote loading, retry wrapper)
apps/shell/src/app/AppLayout.tsx           (persistent navigation, shell-owned 404/RemoteLoadError)
apps/shell/src/shell-context/              (auth/tenant/permission state fragments read from)
apps/<fragment>/src/features/<name>/<Name>App.tsx   (fragment's own nested route tree)
apps/shell/src/app/router.test.tsx         (navigation + guard + remote-load-failure tests; written first)
```
