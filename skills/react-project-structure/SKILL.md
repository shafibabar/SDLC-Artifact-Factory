---
name: react-project-structure
description: >
  Teaches the canonical React + TypeScript project layout for this plugin —
  a shell (host) plus one independently-built remote app per Bounded-
  Context-aligned fragment (see microfrontend-architecture), each remote
  internally organised by feature-based (not type-based) folders, the Vite
  + Module Federation build, strict TypeScript and ESLint configuration,
  module boundary rules (both within a fragment and across fragments),
  side-effect-free ES modules for tree-shaking, and the shared
  design-system/API-client packages every fragment consumes. This is the
  skeleton every frontend is generated into. Used by the frontend-engineer
  during Implement.
version: 2.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, typescript, vite, project-structure, tree-shaking, microfrontend]
---

# React Project Structure

## Purpose

This plugin's frontend is a **shell plus independently-built remote
apps**, one remote per Bounded-Context-aligned fragment
(`microfrontend-architecture`) — not one monolithic app. Within each
remote, code is still organised by **feature** (the thing a user does),
not by **type** (all components here, all hooks there): features are how
one fragment grows, and a feature-based layout keeps everything for one
capability in one place. The shell/remotes split and the feature-based
internal layout are two different concerns, at two different scales —
this skill covers both; full depth on each lives in `references/`.

This skill produces the multi-app skeleton, the Vite + Module Federation +
TypeScript + ESLint configuration, and the module-boundary rules. It
implements the ux-architect's information architecture as a code
structure, sliced along `microfrontend-architecture`'s fragment
boundaries.

---

## Shell + Remotes, at a Glance

```
apps/shell/           # HOST — global nav, shared shell context, remote loading
apps/<fragment>/      # REMOTE — one per Bounded-Context-aligned fragment,
                      # internally feature-based (usually one feature per fragment)
packages/design-system/   # shared, independently-versioned UI + tokens — every app consumes it
packages/api-client/      # shared generated API client — one per product, not per fragment
```

Full annotated tree, plus the complete module boundary rules at both
scales (within a fragment, and across fragments): `references/directory-layout.md`.

**One fragment, one feature (usually).** A fragment growing a second,
distinct feature is a signal to re-check its Bounded Context boundary
(`microfrontend-architecture`'s `assets/fragment-ownership-canvas.md`),
not to assume the fragment naturally absorbs it.

---

## Module Boundary Rules — Summary

Two scales, both enforced:

**Within a fragment**: a feature's public surface is its `index.ts`;
features don't import each other's internals; the fragment's local
`shared/` never imports from its own `features/`.

**Across fragments**: fragments never import each other's source
directly — only the shell context, custom events, and
`packages/design-system`/`packages/api-client` cross a fragment boundary.
Anything that feels like it should be shared between just two specific
fragments is a Bounded Context boundary problem, not a shared-package
problem.

Within-fragment rules are ESLint-enforced; cross-fragment rules are
enforced by **physical package separation** — a fragment cannot
accidentally deep-import another fragment's source because it isn't in
the same workspace dependency graph at all. Full detail:
`references/directory-layout.md`.

---

## Vite Build + Module Federation

Vite is the default for every app — shell and every remote alike. Host
config declares `remotes`; each remote's config declares `exposes`; both
share an identical `shared: { react: {...} }` block. Minimal working
examples for both roles, plus the config-drift hazard to watch for:
`references/vite-module-federation-config.md`. Underlying negotiation
semantics (singleton discipline, dynamic remotes, the cross-boundary
TypeScript problem): `microfrontend-architecture`'s
`references/module-federation-config.md`.

---

## Strict TypeScript and Tree-Shaking

Full strict family on, `any` lint-banned, extended across the federation
boundary via generated `.d.ts` per remote; side-effect-free modules with
`sideEffects: false` and no eager barrels. Full configuration and
rationale: `references/typescript-and-tree-shaking.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Fragment boundary source | Each `apps/*` maps to a Bounded Context (`microfrontend-architecture`) | Fragments split by arbitrary page/component grouping |
| Feature-based within a fragment | Code grouped by feature with a public `index.ts` | Type-based `components/`, `hooks/` dumping grounds |
| Cross-fragment boundaries enforced | No fragment imports another fragment's source; only `packages/` + shell context + events | A fragment deep-importing another fragment's `src/` |
| Shared code correctly scoped | Universal sharing in `packages/`; fragment-local sharing in that fragment's `shared/` | Ad-hoc shared code between two specific fragments only |
| Strict TS across the boundary | Full strict family on; `any` lint-banned; federated imports typed via generated `.d.ts` | Loose `tsconfig`; federated import degrades to `any` |
| Tree-shakeable | Side-effect-free modules; `sideEffects: false` | Side effects on import; eager barrels |

---

## Anti-Patterns

| Anti-pattern | Instead |
|---|---|
| A fragment deep-importing another fragment's `src/` directly | Shell context, custom events, or `packages/` only |
| Creating an ad-hoc shared package between just two fragments | Universal sharing goes in `packages/`; a two-fragment-only need signals a boundary problem |
| Type-based top-level folders inside a fragment | Feature folders; type folders only *inside* a feature |
| A fragment's local `shared/` importing from its own `features/` | Dependencies point inward — promote or invert |
| Hand-writing types that mirror server responses | Derive from `packages/api-client`'s generated client |
| Adopting Webpack purely to get Module Federation | `@module-federation/vite` — this repo's build tool is Vite |
| A new feature added to an existing fragment without checking its Bounded Context still fits | Check `microfrontend-architecture`'s `assets/fragment-ownership-canvas.md` before growing a fragment's scope |

---

## Output Format

Produces the multi-app skeleton and configuration:

```
apps/shell/{vite.config.ts,tsconfig.json,eslint.config.js,package.json,Dockerfile}
apps/shell/src/{app,shell-context}/  + main.tsx
apps/<fragment>/{vite.config.ts,tsconfig.json,eslint.config.js,package.json,Dockerfile}   (one per fragment)
apps/<fragment>/src/{features,shared}/  + main.tsx
packages/design-system/src/{ui,hooks}/  + tokens.css
packages/api-client/src/{generated.ts,client.ts}
```
