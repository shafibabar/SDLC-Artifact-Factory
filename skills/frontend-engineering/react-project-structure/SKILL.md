---
name: react-project-structure
description: >
  Teaches the canonical React + TypeScript project layout for this plugin —
  feature-based (not type-based) folder structure, the Vite build, strict
  TypeScript and ESLint configuration, the module boundary rules (features don't
  import each other's internals), side-effect-free ES modules for tree-shaking,
  and where shared UI, hooks, and the generated API client live. This is the
  skeleton every frontend is generated into. Used by the frontend-engineer during
  Implement.
version: 1.1.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, typescript, vite, project-structure, tree-shaking]
---

# React Project Structure

## Purpose

Every frontend in this plugin uses the same feature-based layout so any screen is navigable by anyone who has seen one. Code is organised by **feature** (the thing a user does), not by **type** (all components here, all hooks there) — because features are how the product grows and how work is split, and a feature-based layout keeps everything for one capability in one place.

This skill produces the directory skeleton, the Vite + TypeScript + ESLint configuration, and the module-boundary rules. It implements the ux-architect's information architecture as a code structure.

---

## Feature-Based Layout

```
estate-ui/
├── src/
│   ├── app/                      # app shell: providers, router, global layout
│   │   ├── App.tsx
│   │   ├── providers.tsx         # QueryClientProvider, ErrorBoundary, OTel, theme
│   │   └── router.tsx            # route tree (see react-routing)
│   ├── features/                 # one folder per feature — the unit of growth
│   │   ├── data-assets/
│   │   │   ├── components/       # feature-private components
│   │   │   ├── hooks/            # feature-private hooks (useClassifyDataAsset…)
│   │   │   ├── api.ts            # feature's data-fetching hooks (TanStack Query)
│   │   │   ├── types.ts          # feature-local types (derived from generated API types)
│   │   │   └── index.ts          # PUBLIC surface — the only thing other code imports
│   │   ├── compliance/
│   │   ├── data-sources/
│   │   └── estate-graph/
│   ├── shared/                   # cross-feature, app-agnostic building blocks
│   │   ├── ui/                   # design-system atoms/molecules (Button, Badge…)
│   │   ├── hooks/                # generic hooks (useDebounce, useMediaQuery)
│   │   └── lib/                  # pure utilities (formatting, guards)
│   ├── api/
│   │   ├── generated.ts          # GENERATED from openapi.yaml — never edited
│   │   └── client.ts             # typed fetch client (see react-api-client)
│   ├── telemetry/                # OTel Web, Web Vitals, error sinks (see react-observability)
│   └── main.tsx                  # entry point
├── tests/                        # e2e (Playwright); unit tests live beside source
├── index.html
├── vite.config.ts
├── tsconfig.json
├── eslint.config.js              # ESLint flat config (typescript-eslint + boundaries)
├── Dockerfile
└── package.json
```

Unit tests live **beside** the file they test (`Button.tsx` + `Button.test.tsx`); end-to-end specs live in `tests/`.

---

## Module Boundary Rules

The feature layout only pays off if boundaries are enforced:

1. **A feature's public surface is its `index.ts`.** Other code imports `features/data-assets`, never `features/data-assets/components/Internal`.
2. **Features do not import each other's internals.** If two features need the same thing, it moves to `shared/`.
3. **`shared/` never imports from `features/`.** Dependencies point inward: `features → shared → lib`. (The frontend analogue of the backend's dependency rule.)
4. **The generated API client is the only source of server types** (see `react-api-client`). Features derive their types from it; they never redeclare server shapes.

These rules are enforced by ESLint (`eslint-plugin-boundaries` / `import/no-restricted-paths`), not by convention — a violating import fails `npm run lint`.

---

## Strict TypeScript Configuration

Strictness is non-negotiable (see `typescript-types`). The `tsconfig.json` turns on the full strict family:

```jsonc
{
  "compilerOptions": {
    "strict": true,                          // the whole strict family
    "noUncheckedIndexedAccess": true,        // arr[i] is T | undefined — forces the check
    "exactOptionalPropertyTypes": true,      // optional ≠ "| undefined" sloppiness
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "verbatimModuleSyntax": true,            // explicit type-only imports → better tree-shaking
    "isolatedModules": true,
    "moduleResolution": "bundler",
    "target": "ES2022",
    "jsx": "react-jsx"
  }
}
```

`any` is banned by lint rule, not just discouraged (see `typescript-types`).

---

## Vite Build

Vite is the default (fast dev server, native ES modules, excellent tree-shaking, frugal). Configuration enables code-splitting and bundle visibility from day one:

```ts
// vite.config.ts
/// <reference types="vitest/config" />   // types the `test` block below
export default defineConfig({
  plugins: [react()],
  build: {
    sourcemap: true,                 // for production stack traces (see react-observability)
    rollupOptions: {
      output: { manualChunks: { /* split heavy deps like the graph lib */ } },
    },
  },
  test: { environment: "jsdom", setupFiles: "./src/test/setup.ts" }, // Vitest
});
```

Route-level and component-level code-splitting are detailed in `react-performance-optimization`; the structure here makes them natural.

---

## Side-Effect-Free Modules (Tree-Shaking)

For the bundler to drop unused code, modules must be side-effect-free: importing a module must not *do* anything except define exports. Rules:

- No top-level code that runs on import (no `console.log`, no mutation, no network call at module scope).
- Mark the package side-effect-free where true: `"sideEffects": false` in `package.json` (with explicit exceptions for CSS).
- Prefer named exports; avoid barrel files that re-export everything eagerly (they defeat tree-shaking and slow the dev server).

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Feature-based | Code grouped by feature with a public `index.ts` | Type-based `components/`, `hooks/` dumping grounds |
| Boundaries enforced | ESLint blocks cross-feature internal imports | Features reaching into each other's internals |
| Inward dependencies | `features → shared → lib`; shared never imports features | `shared/` importing a feature |
| Strict TS | Full strict family on; `any` lint-banned | Loose `tsconfig`; `any` allowed |
| Generated types only | Server types come from the generated client | Hand-redeclared server shapes |
| Tree-shakeable | Side-effect-free modules; `sideEffects: false` | Side effects on import; eager barrels |

---

## Anti-Patterns

| Anti-pattern | Instead |
|---|---|
| Type-based top-level folders (`components/`, `hooks/`, `utils/` as dumping grounds) | Feature folders; type folders only *inside* a feature |
| Importing `features/x/components/Internal` from another feature | Import the feature's `index.ts` public surface only |
| A `shared/` module importing from `features/` | Dependencies point inward — promote or invert |
| Hand-writing types that mirror server responses | Derive from the generated API client |
| A barrel `index.ts` re-exporting the entire app | Barrels only at feature boundaries, exporting the deliberate public surface |
| Loosening `tsconfig` to silence errors ("temporarily") | Fix the type; strictness is the point |
| Editing `src/api/generated.ts` by hand | Regenerate from `openapi.yaml`; the file is build output |

---

## Output Format

Produces the project skeleton and configuration:

```
vite.config.ts, tsconfig.json, eslint.config.js, package.json
src/app/{App.tsx,providers.tsx,router.tsx}
src/{features,shared,api,telemetry}/   (with index.ts public surfaces)
src/main.tsx
```
