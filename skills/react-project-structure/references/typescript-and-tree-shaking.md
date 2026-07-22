# Strict TypeScript Configuration and Tree-Shaking

Full TypeScript strictness config and tree-shaking discipline, applied
identically across the shell and every remote. Self-contained — loadable
without reading `SKILL.md` first.

---

## Strict TypeScript Configuration

Strictness is non-negotiable (see `typescript-types`) and applies
identically in the shell and every remote. Each app's `tsconfig.json`
turns on the full strict family:

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
This ban extends across the federation boundary too: a remote's exposed
modules must publish generated `.d.ts` types the shell's build consumes
(see `microfrontend-architecture`'s `references/module-federation-config.md`)
— a federated import that silently degrades to `any` is a lint failure,
not an accepted gap. Generate and publish each remote's declaration file
as a build artifact the shell's typecheck step consumes; never let the
absence of build-time visibility into a remote's source become an excuse
to skip typing the boundary.

## Side-Effect-Free Modules (Tree-Shaking)

For the bundler to drop unused code, modules must be side-effect-free:
importing a module must not *do* anything except define exports. Rules,
unchanged per app:

- No top-level code that runs on import (no `console.log`, no mutation, no
  network call at module scope).
- Mark the package side-effect-free where true: `"sideEffects": false` in
  `package.json` (with explicit exceptions for CSS).
- Prefer named exports; avoid barrel files that re-export everything
  eagerly (they defeat tree-shaking and slow the dev server).

A federation `exposes` entry becomes its own async chunk regardless of
`sideEffects` settings — the exposed module boundary is already a
code-split point by construction, but the modules behind it still need
the same tree-shaking discipline for everything not exposed. Exposing a
fragment's entire `src/` tree instead of its deliberate public surface
defeats this doubly: it both violates the module boundary rules
(`references/directory-layout.md`) and ships dead code across the
federation boundary that tree-shaking can no longer reach, since the
shell's bundler never sees the remote's source to shake it.
