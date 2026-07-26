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

### Why Each Flag Matters More in a Federation-Composed App

A monolithic single-app codebase gets one `tsc` (or one bundler
typecheck) pass across the whole tree — a looseness in one file is at
least visible to whichever program-wide check runs over everything. A
shell and its remotes are never checked by one program-wide pass: each
app compiles independently, and the only thing that crosses the boundary
at build time is a generated `.d.ts` (see Federation Boundary Typing
below). That changes what each flag is actually defending against —
per-flag reasoning, not just what each does in general:

| Flag | What it catches, generally | Why it matters specifically at a federation seam |
|---|---|---|
| `isolatedModules` | Rejects any TypeScript construct that cannot be compiled file-by-file without whole-program type information (e.g. re-exporting a `const enum`'s type incorrectly) | Vite/esbuild transpile **one file at a time**, and a remote's build has zero visibility into the shell's program (and vice versa) — a construct that only "works" with whole-program knowledge silently breaks the moment the two apps are compiled as the separate programs they actually are, which is every build, not a hypothetical one |
| `verbatimModuleSyntax` | Forces every type-only import to be written `import type { X }`, never a plain `import { X }` for a type | Without this, a bundler doing per-file, no-whole-program-visibility transpilation (exactly what `isolatedModules` requires) cannot always tell whether an import is a value it must keep or a type it may safely elide — at the federation boundary specifically, an ambiguous import inside an `exposes` entry risks either a runtime import of something that doesn't exist as a value, or a type silently failing to elide, bloating the shipped chunk |
| `noUncheckedIndexedAccess` | Types `arr[i]` as `T \| undefined`, not `T`, forcing an explicit check | A remote's public API surface (its exposed component's props, a shared collection from `packages/api-client`) is consumed by a shell team member who did not write the remote — the array-bounds assumption that "feels safe" to the author who wrote the data source is invisible to the consumer on the other side of the boundary; the compiler must catch what code review across two independently-owned apps cannot |
| `exactOptionalPropertyTypes` | Distinguishes `prop?: string` (property may be absent) from `prop: string \| undefined` (property present, value may be `undefined`) — an unannotated optional otherwise silently accepts both | A remote's exposed component's prop types are published once, as a generated `.d.ts`, and consumed by a shell that never sees the remote's source — if "omitted" and "explicitly `undefined`" collapse into one meaning at that boundary, a real product distinction (a dashboard widget's "field not loaded yet" vs. "field explicitly cleared by the user") silently disappears at exactly the one seam where nobody can spot the loss in a single code review, since the two sides are reviewed by different PRs entirely |
| `noImplicitOverride` | Requires an explicit `override` keyword when a subclass method overrides a base class method | Applies narrowly (this repo is function-component-first), but matters at the one class-component-mandatory surface every fragment shares — the error boundary (`react-observability`) — where `packages/design-system` may supply a base implementation a fragment extends; an accidental non-override method-name collision between a shared base and a fragment's subclass is exactly the kind of drift two independently-compiled apps won't surface to each other without the compiler flagging it explicitly |
| `noFallthroughCasesInSwitch` | Rejects a `switch` case that falls through to the next case without an explicit `break`/`return` | Not federation-specific — a general correctness guard kept on for the same reason `strict` is: consistency across every app so no app is quietly held to a looser bar than its siblings |
| `moduleResolution: "bundler"` | Matches TypeScript's module resolution to how Vite (not Node, not classic CommonJS) actually resolves imports | Vite is the build tool for every app (shell and every remote alike) — a resolution mode mismatched to the actual bundler produces type-checks that pass locally but don't reflect what the bundler will actually do, which is worse than no check at all because it's false confidence |
| `target: "ES2022"` | Sets the JS output level | Required alongside `build.target: "esnext"` in every app's `vite.config.ts` (see `references/vite-module-federation-config.md`) — `@module-federation/vite` relies on native dynamic `import()` semantics; a mismatched target between an app's TS output and its Vite build target is a drift class this repo's config already warns about for `target`/`sourcemap` generally |

`any` is banned by lint rule, not just discouraged (see `typescript-types`).
This ban extends across the federation boundary too: a remote's exposed
modules must publish generated `.d.ts` types the shell's build consumes
(see `microfrontend-architecture`'s `references/module-federation-config.md`)
— a federated import that silently degrades to `any` is a lint failure,
not an accepted gap. Generate and publish each remote's declaration file
as a build artifact the shell's typecheck step consumes; never let the
absence of build-time visibility into a remote's source become an excuse
to skip typing the boundary.

### The Federation Boundary Is a Contract Between Two Compiler Runs, Not One

Every flag above is enforced the same way in the shell's `tsconfig.json`
and every remote's `tsconfig.json` — but "the same config in two files"
is not the same guarantee as "one compiler checking both sides together."
The shell's `tsc`/typecheck step never parses a remote's source; it only
ever sees the remote's generated `.d.ts`. Two consequences follow directly:

1. **A remote can pass its own strict typecheck while still exporting a
   type that misrepresents its actual runtime shape** — nothing forces
   the generated `.d.ts` to be regenerated the moment the remote's
   exposed module changes; a stale declaration file typechecks the shell
   against a contract the remote no longer honors. Treat `.d.ts`
   generation as part of the remote's build step that runs on every
   change, never a manually-triggered, easy-to-forget side task.
2. **Strictness on both sides is necessary but not sufficient** — it
   guarantees each app is internally sound, not that the two apps agree
   with each other. The generated `.d.ts` is the only artifact doing that
   job; keeping every flag above identical in both `tsconfig.json` files
   is what keeps "internally sound" meaning the same thing on both sides
   of a boundary neither compiler run can see across.

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
