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

## The Shared-Dependency Version-Skew Standard

Every app's `shared: { react: {...} }` block is copied from the same
source when a new remote is scaffolded — but nothing at the source level
keeps it identical afterward. Each app has its own `package.json`; each
gets its dependencies bumped on its own release cadence, by whichever
agent or engineer touches that app that week. Version skew is not an edge
case this standard defends against hypothetically — it is the default
outcome of independent deployability unless the convention below is
followed deliberately every time.

**The convention:** every app's `shared.react` entry declares the
**identical** `requiredVersion` range, and always pairs `singleton: true`
with `strictVersion: true`. Never widen, narrow, or drop the range in one
app "just for this release" — the range is a cross-app contract, bumped
in lockstep, not a per-app implementation detail.

**Concrete failure scenario — the shell pins `^18.2.0`, a remote ships
`18.3.0`:** the shell's `vite.config.ts` declares
`react: { singleton: true, requiredVersion: "^18.2.0", strictVersion: true }`.
A remote is later rebuilt and independently deployed against React
`18.3.0` in its own `package.json` — but its federation config's
`requiredVersion` is left unchanged, or a contributor "fixes" it to
`^18.3.0` without updating the shell to match. Per the singleton
negotiation mechanics `microfrontend-architecture`'s
`references/module-federation-config.md` documents in full, two distinct
outcomes follow depending on what actually diverged:

1. **The ranges still overlap** (`^18.2.0` is satisfied by `18.3.0`) —
   negotiation succeeds silently, and one copy wins (the version that
   satisfies every consumer's range). This is the **safe** case, and it
   is exactly why `requiredVersion` should be a real semver range, not a
   pinned exact version — a remote shipping a compatible patch/minor bump
   ahead of the shell should not break anything.
2. **The ranges genuinely conflict** (the shell requires `^18.2.0`, a
   remote requires `^19.0.0`) — with `strictVersion: true` on both sides,
   Module Federation **fails loudly at runtime**, refusing to load rather
   than guessing. This is the fix working as intended: a loud failure in
   staging is strictly preferable to what happens without
   `strictVersion` — the **first-loaded-wins hazard**, where negotiation
   non-deterministically picks whichever copy's manifest resolves first
   (a function of network timing, not intent), and every other app
   silently runs against a React copy it was never tested with. That
   silent case is what surfaces in production as an "Invalid hook call"
   error — two React copies, or one component calling into another
   copy's dispatcher — which is precisely the failure `singleton: true`
   exists to prevent, and only actually prevents when paired with a
   range strict enough to fail instead of guess.

**Detecting drift before it reaches runtime:** nothing at the source
level forces every app's `shared.react` block to stay identical — this is
a review-time and CI-time check, not a compiler guarantee. Confirm, on
every PR that touches any app's `vite.config.ts` or bumps `react`/
`react-dom` in any `package.json`: every app's `requiredVersion` string is
identical, `singleton: true` and `strictVersion: true` are both present
in every app (not just the shell), and the actual installed `react`
version in every app's lockfile satisfies that one shared range. Treat a
`vite.config.ts` diff that changes only one app's `shared.react` block
without a corresponding, deliberate change everywhere else as a rejected
PR, the same way a config-drift diff on `sourcemap`/`target` above is.

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
