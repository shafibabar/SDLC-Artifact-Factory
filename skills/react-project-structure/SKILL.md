---
name: react-project-structure
description: >
  Teaches the canonical React + TypeScript project layout for this plugin —
  a shell (host) plus one independently-built remote app per Bounded-
  Context-aligned fragment (see microfrontend-architecture), each remote
  internally organised by feature-based (not type-based) folders, the Vite
  + Module Federation build including the shared-dependency version-skew
  standard and singleton enforcement, strict TypeScript configuration
  applied identically across a federation boundary no single compiler run
  ever sees both sides of, the Rules of Hooks mechanically enforced via
  eslint-plugin-react-hooks, module boundary rules (both within a fragment
  and across fragments), side-effect-free ES modules for tree-shaking, and
  the shared design-system/API-client packages every fragment consumes.
  This is the skeleton every frontend is generated into. Used by the
  frontend-engineer during Implement.
version: 2.2.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, typescript, vite, project-structure, tree-shaking, microfrontend]
produces: react-app-skeleton
domain: frontend
status: stable
related: [microfrontend-architecture, typescript-types, react-component-design, react-component-testing, react-observability]
---

# React Project Structure

## Purpose

This plugin's frontend is a **shell plus independently-built remote
apps**, one remote per Bounded-Context-aligned fragment
(`microfrontend-architecture`) — not one monolithic app. Within each
remote, code is organised by **feature** (the thing a user does), not by
**type** (all components here, all hooks there). The shell/remotes split
and the feature-based internal layout are two different concerns at two
different scales — this skill covers both; full depth on each lives in
`references/`.

This skill produces the multi-app skeleton, the Vite + Module Federation +
TypeScript + ESLint configuration, and the module-boundary rules — the
standard every generated file must meet, not just where it goes —
implementing the ux-architect's information architecture as a code
structure sliced along `microfrontend-architecture`'s fragment boundaries.

---

## Shell + Remotes, at a Glance

```
apps/shell/           # HOST — global nav, shared shell context, remote loading
apps/<fragment>/      # REMOTE — one per Bounded-Context-aligned fragment,
                      # internally feature-based (usually one feature per fragment)
packages/design-system/   # shared, independently-versioned UI + tokens — every app consumes it
packages/api-client/      # shared generated API client — one per product, not per fragment
```

The exact per-directory standard — what belongs in the shell vs. a remote
vs. `packages/`, and *why*, file by file — is `references/directory-layout.md`.
**One fragment, one feature (usually).** A fragment growing a second,
distinct feature is a signal to re-check its Bounded Context boundary
(`microfrontend-architecture`'s `assets/fragment-ownership-canvas.md`),
not to assume the fragment naturally absorbs it.

---

## Module Boundary Rules — Summary

Two scales, both enforced: **within a fragment**, a feature's public
surface is its `index.ts`; features don't import each other's internals;
the local `shared/` never imports from `features/`. **Across fragments**,
apps never import each other's source directly — only the shell context,
custom events, and `packages/design-system`/`packages/api-client` cross a
boundary; anything that feels like it should be shared between just two
specific fragments is a Bounded Context problem, not a shared-package one.

Within-fragment rules are ESLint-enforced; cross-fragment rules are
enforced by **physical package separation** — a fragment cannot
accidentally deep-import another's source because it isn't in the same
workspace dependency graph at all. Full detail, plus the per-location
"what belongs where and why" standard: `references/directory-layout.md`.

---

## Vite Build, Module Federation, and Shared-Dependency Version Skew

Vite is the default for every app — shell and every remote alike. Host
config declares `remotes`; each remote's config declares `exposes`; both
share an identical `shared: { react: {...} }` block. Minimal working
examples, the config-drift hazard, and the **shared-dependency
version-skew standard** — what happens when the shell and a remote
disagree on a `shared` package's version, and why `singleton: true` alone
does not prevent it without a matching `requiredVersion` and
`strictVersion: true` — are in `references/vite-module-federation-config.md`.
Underlying negotiation semantics (dynamic remotes, the cross-boundary
TypeScript problem): `microfrontend-architecture`'s
`references/module-federation-config.md`.

**The rule in one sentence:** every app's `shared.react` entry carries the
identical `requiredVersion` and `strictVersion: true` — a diff that
changes this block in only one app, without an identical change
everywhere else, is a rejected PR, not a judgment call.

---

## Strict TypeScript Across a Boundary No Compiler Run Spans

Full strict family on (`strict`, `noUncheckedIndexedAccess`,
`exactOptionalPropertyTypes`, `noImplicitOverride`,
`noFallthroughCasesInSwitch`, `verbatimModuleSyntax`, `isolatedModules`),
`any` lint-banned, extended across the federation boundary via generated
`.d.ts` per remote. Each flag matters *more* here than in a single-program
codebase: the shell's typecheck never parses a remote's source, only its
generated declaration file — a looseness invisible to one app's own
strict config is invisible to the other app's reviewer too, since the two
sides are never checked, or reviewed, together. Per-flag rationale and the
federation-boundary-as-a-contract argument: `references/typescript-and-tree-shaking.md`.

## Side-Effect-Free Modules for Tree-Shaking

No top-level code that runs on import; `sideEffects: false` in
`package.json`; named exports over eager barrels. A federation `exposes`
entry is already its own async chunk by construction — exposing a whole
`src/` tree instead of the deliberate public surface both violates the
module boundary rules above and ships dead code the shell's bundler can
never see to shake. Same file: `references/typescript-and-tree-shaking.md`.

---

## Rules of Hooks — Mechanically Enforced, Not Prose-Only

`react-component-design` states the Rules of Hooks (call only at the top
level; call only from a component or a custom hook) and exhaustive-
dependency discipline as prose conventions — a convention nobody's
tooling checks erodes the first time someone is under deadline pressure.
`eslint-plugin-react-hooks` is in every fragment's `eslint.config.js`:
`rules-of-hooks` at `error` (a hook called conditionally, in a loop, after
an early return, or from a plain function fails the build — structural,
call-order verification, the same mechanism `any` is lint-banned by, not
merely discouraged); `exhaustive-deps` at `warn` (flags a dependency array
missing a value the effect body reads — `warn` because the rule cannot
distinguish a genuinely unsafe omission from a React-guaranteed-stable one
like a `dispatch` function).

**What neither rule catches:** a hook called with perfectly correct shape
— top level, unconditional, complete dependency array — whose body
computes the wrong thing or subscribes to the wrong event. That class of
bug is a behavior-level testing question (`react-component-testing`), not
a lint question — the two layers are complementary, never substitutes for
each other. Exact rule configuration, worked catch/no-catch examples, and
the reviewer verification checklist: `references/hooks-lint-enforcement.md`.

---

## Quality Criteria

| Criterion | Pass | Fail | How a reviewer verifies |
|---|---|---|---|
| Fragment boundary source | Each `apps/*` maps to a Bounded Context | Split by arbitrary page/component grouping | Cross-check against `assets/fragment-ownership-canvas.md` |
| Feature-based within a fragment | Grouped by feature, public `index.ts` | Type-based `components/`/`hooks/` dumping grounds | Top-level folders in `src/` name features, not JS/TS constructs |
| Directory-boundary correctness | Every file matches its location's standard | Feature code in the shell; two-fragment code in `packages/` | Walk the "What Belongs Where" tables (`references/directory-layout.md`) per PR |
| Cross-fragment boundaries enforced | Only `packages/` + shell context + events cross | A fragment deep-importing another's `src/` | `eslint-plugin-boundaries` CI gate — zero violations |
| Strict TS across the boundary | Full strict family in every app; `any` banned; `.d.ts` typed | Loose `tsconfig`; federated import degrades to `any` | Diff every `tsconfig.json` against the canonical flags; confirm `.d.ts` regenerates every change |
| Tree-shakeable | Side-effect-free; `sideEffects: false`; no eager barrels | Side effects on import; whole-`src/` `exposes` | Bundle visualizer: each `exposes` entry is its own chunk |
| Hooks enforcement completeness | `rules-of-hooks` at `error`, zero violations; every `exhaustive-deps` suppression commented | Prose-only Rules of Hooks; bare `eslint-disable-next-line` | `npm run lint` zero `rules-of-hooks` errors; grep `eslint-disable` near `exhaustive-deps` for a rationale |
| Shared-dependency version skew | Identical `requiredVersion`; `singleton`+`strictVersion` true everywhere | One app's range diverges; `strictVersion` missing anywhere | Grep every `vite.config.ts`'s `shared.react` block; strings match verbatim |

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
| Silencing `exhaustive-deps` with a bare `// eslint-disable-next-line` | A one-line comment naming *why* the omitted dependency is safe — a silent suppression hides the next, genuinely unsafe omission |
| Bumping one app's `shared.react` `requiredVersion` without the rest, or assuming `singleton: true` alone prevents a version conflict | Bump the range in lockstep across every app in the same PR; pair `singleton: true` with `requiredVersion` **and** `strictVersion: true`, or negotiation can silently pick an incompatible copy |

---

## Output Format

Produces the multi-app skeleton — every `vite.config.ts` governed by
`references/directory-layout.md` + `references/vite-module-federation-config.md`,
every `tsconfig.json` by `references/typescript-and-tree-shaking.md`,
every `eslint.config.js` by the boundaries rules above plus
`references/hooks-lint-enforcement.md` — identically for the shell and
every fragment:

```
apps/shell/{vite.config.ts,tsconfig.json,eslint.config.js,package.json,Dockerfile}
apps/shell/src/{app,shell-context}/  + main.tsx
apps/<fragment>/{vite.config.ts,tsconfig.json,eslint.config.js,package.json,Dockerfile}  (one per fragment)
apps/<fragment>/src/{features,shared}/  + main.tsx
packages/design-system/src/{ui,hooks}/  + tokens.css
packages/api-client/src/{generated.ts,client.ts}
```
