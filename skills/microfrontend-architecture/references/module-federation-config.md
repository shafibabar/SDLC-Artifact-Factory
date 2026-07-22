# Module Federation Configuration

Deep mechanics for `exposes`/`remotes`/`shared`, per Jackson & Herrington's
*Practical Module Federation* (`research/micro-frontends/practical-module-federation-jackson-herrington.md`).
Self-contained — loadable without reading `SKILL.md` first. Concepts here
are the underlying Module Federation protocol; exact config syntax must be
verified against this repo's actual tooling (`@module-federation/vite`),
since the book's own examples are Webpack-specific.

---

## The Three Primitives

- **`exposes`** — maps a public name to a local module path in an app
  acting as a **remote** (the app being consumed by others). Each exposed
  entry becomes its own async chunk, loaded on demand — never bundled into
  the remote's own initial load unless the remote's own app also imports
  it directly.
- **`remotes`** — maps a name to a **container location** (a URL to the
  remote's `remoteEntry.js` manifest) in an app acting as a **host**. The
  host's bundler does not need the remote's source at build time —
  resolution happens in the browser at runtime.
- **`shared`** — the dependency-negotiation layer. For each listed package
  (`react`, `react-dom`, a design-system package), Module Federation
  decides at runtime whether the host's copy or a remote's copy satisfies
  everyone's semver range, loading only the copies that don't overlap.
  This is the single most consequential config surface — get it wrong and
  the failure mode is silent and non-deterministic, not a build error.

## Runtime Federation vs. Build-Time Integration

Unlike a monorepo or an npm-published component library (resolved by the
bundler at **build time**), Module Federation resolves which code loads at
**runtime**, in the browser, after host and remote are already
independently deployed. This is what makes independent deployability
real — a remote ships a new version and every host picks it up on next
page load, no host rebuild. The cost: integration bugs a build-time system
catches at compile time (a removed export, an incompatible prop shape)
surface at runtime instead, in production, for a real user. This trade —
deploy-time independence purchased with weaker static guarantees — is the
central cost/benefit ledger of adopting this at all.

## Singleton Discipline (the Most Common Failure Mode)

```
shared: {
  react: { singleton: true, requiredVersion: '^18.0.0', strictVersion: true, eager: false }
}
```

- **`singleton: true`** — exactly one instance of this module loads across
  host and every remote, no matter how many separately-built bundles
  request it. **Mandatory for `react`/`react-dom` specifically** — multiple
  React copies break the Hooks dispatcher (a component from one copy
  calling into another copy's runtime is undefined behavior, not just
  wasted bytes).
- **Version negotiation without `singleton`** — a deliberate escape hatch
  for packages where "ban duplicates" doesn't apply (e.g. a chart library
  two remotes each use independently, not as a shared runtime object).
  Each remote gets the version it was built against.
- **The first-loaded-wins hazard** — without a careful `requiredVersion`
  range, negotiation can non-deterministically select whichever copy of a
  singleton happens to load first (a function of network-timing load
  order). Treat this as a real production failure mode: always pair
  `singleton: true` with an explicit `requiredVersion` **and**
  `strictVersion: true` (fail loudly rather than silently pick an
  incompatible version) — never mark singleton and assume it's solved.
- **`eager` vs. lazy** — eager bundles the dependency into the initial
  chunk (needed when the host must render before any remote's federation
  call resolves, since negotiation itself needs something loaded to
  compare candidate versions against); lazy (the default) defers loading
  until first actually needed — right for most remotes, wrong for the
  host's own first-render dependency.

## Dynamic Remote Loading

Beyond a fixed `remotes` map declared at build time, a remote's URL can be
resolved **at runtime** — fetching a manifest that lists which remote URL
to use per environment or tenant, letting a host discover and mount a
remote it didn't know about at its own build time. This is directly
relevant to this repo's **physical multi-tenancy default**: one shell
image could serve different per-tenant remote bundles resolved from a
runtime manifest — the same "build once, inject config at runtime"
principle `react-dockerfile` already applies to `window.__APP_CONFIG__`,
extended to remote resolution. Use this instead of baking tenant URLs into
the host's build.

## Bidirectional / Omnidirectional Federation

Nothing restricts an app to being purely a shell or purely a remote — an
app can declare both a `remotes` map (consuming others) and an `exposes`
map (being consumed by others) in the same config. **Omnidirectional
federation** (every app both host and remote to every other) contrasts
with the simpler **unidirectional** shell→remotes topology this skill
defaults to. Decide deliberately: default to unidirectional (one shell,
many remotes) unless a real mesh requirement exists — e.g. the narrower
"share a component library between two otherwise-independent products"
use case is exactly the bidirectional shape, not hub-and-spoke.

## Type Safety Across the Federation Boundary

Since a host's bundler never sees a remote's source at build time,
TypeScript cannot type-check a dynamically federated import by default —
directly relevant given `typescript-types` bans `any` outright. Generate
and publish a remote's `.d.ts` types as a separate build artifact (a small
companion package, or a federation-aware plugin that fetches types at dev
time), so the host gets real type-checking against a remote it doesn't
build. Never let a federated import silently degrade to `any` — that
defeats the lint ban in a way ordinary code can't.

## Vite-Specific Note

This repo uses Vite (`react-project-structure`), not Webpack. Use Module
Federation 2.0's bundler-agnostic tooling (`@module-federation/vite`) or
`@originjs/vite-plugin-federation`. The protocol concepts above transfer
directly; exact config option names and maturity/edge cases differ from
Webpack's `ModuleFederationPlugin` and must be verified against the
Vite-side tooling's own docs before implementation.
