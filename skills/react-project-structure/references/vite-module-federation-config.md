# Vite Build + Module Federation Configuration

The project-structure-level Vite/Module Federation surface — host config
and remote config, side by side. Self-contained — loadable without
reading `SKILL.md` first. For the underlying negotiation semantics
(singleton discipline, dynamic remotes, bidirectional federation, type
safety across the boundary), see `microfrontend-architecture`'s
`references/module-federation-config.md` — this file only covers where
that config actually lives in each app's project structure.

---

## Vite Is the Default, Everywhere

Vite (fast dev server, native ES modules, excellent tree-shaking, frugal)
is the build tool for every app — the shell and every remote alike. Each
app's config additionally carries its Module Federation role via
`@module-federation/vite` (not Webpack's `ModuleFederationPlugin` — this
repo's build tool is Vite; see `microfrontend-architecture`'s
Vite-specific note for why Webpack tooling doesn't apply directly).

## Host Config (the Shell)

```ts
// apps/shell/vite.config.ts — HOST
export default defineConfig({
  plugins: [
    react(),
    federation({
      name: "shell",
      remotes: {
        dataAssets: "https://.../data-assets/remoteEntry.js",
        compliance: "https://.../compliance/remoteEntry.js",
      },
      shared: { react: { singleton: true, requiredVersion: "^18.0.0", strictVersion: true } },
    }),
  ],
  build: { sourcemap: true, target: "esnext" },   // esnext required for federation's native ESM
});
```

The shell's `remotes` map is the one place every fragment the shell
composes is declared. For per-tenant remote resolution (this repo's
physical multi-tenancy default), resolve these URLs from a runtime
manifest instead of hardcoding them here — see
`microfrontend-architecture`'s dynamic remote loading section.

## Remote Config (Each Fragment)

```ts
// apps/data-assets/vite.config.ts — REMOTE
export default defineConfig({
  plugins: [
    react(),
    federation({
      name: "dataAssets",
      filename: "remoteEntry.js",
      exposes: { "./DataAssetsApp": "./src/features/data-assets" },
      shared: { react: { singleton: true, requiredVersion: "^18.0.0", strictVersion: true } },
    }),
  ],
  build: { sourcemap: true, target: "esnext" },
});
```

Expose only the fragment's deliberate public surface (its top-level
feature's `index.ts`), never the whole `src/` tree — the same
no-eager-barrel discipline this skill already applies within a fragment
extends to what a fragment federates out.

## Shared Configuration Notes

- `sourcemap: true` on every app, for production stack traces (see
  `react-observability`) — this doesn't change with federation, but it's
  easy to drop when copying config between apps; keep it on both host and
  every remote.
- `target: "esnext"` is required wherever `@module-federation/vite` is
  used — the plugin relies on native dynamic `import()` semantics Vite's
  default target doesn't guarantee.
- The `shared: { react: {...} }` block must be **identical** (same
  `requiredVersion`, same `strictVersion: true`) in the shell's config and
  every remote's config — a mismatched range across apps is exactly the
  first-loaded-wins hazard `microfrontend-architecture` warns about,
  reintroduced by config drift rather than a genuine version conflict.

## What This File Doesn't Cover

Singleton negotiation failure modes, dynamic remote resolution mechanics,
bidirectional/omnidirectional federation, and the cross-boundary
TypeScript `.d.ts` problem all live in
`microfrontend-architecture`'s `references/module-federation-config.md` —
this file is the project-structure surface (where the config lives, what
a minimal correct example looks like), not the protocol semantics
underneath it.

Route-level and component-level code-splitting within one fragment are
detailed in `react-performance-optimization`; the multi-app structure here
makes them natural — a fragment's own routes still lazy-load exactly as
they would in a single-app project.
