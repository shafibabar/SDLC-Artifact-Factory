# Shell + Remotes Directory Layout

Full multi-app skeleton and the complete module boundary rules, at both
scales (within a fragment, across fragments). Self-contained — loadable
without reading `SKILL.md` first, though it assumes
`microfrontend-architecture`'s decomposition/composition decisions.

---

## Full Layout

```
apps/
├── shell/                          # HOST — global nav, shared shell context, remote loading
│   ├── src/
│   │   ├── app/
│   │   │   ├── App.tsx
│   │   │   ├── providers.tsx       # QueryClientProvider, ErrorBoundary, OTel, theme
│   │   │   └── router.tsx          # host-level route tree, composes remotes (see react-routing)
│   │   ├── shell-context/          # the narrow, versioned, read-mostly shared context —
│   │   │                           # current user, tenant, feature flags (microfrontend-architecture)
│   │   └── main.tsx
│   ├── vite.config.ts              # Module Federation HOST config — remotes: {...}, shared: {...}
│   ├── tsconfig.json
│   ├── eslint.config.js
│   ├── Dockerfile
│   └── package.json
│
├── data-assets/                    # REMOTE — one app per Bounded-Context-aligned fragment
│   ├── src/
│   │   ├── features/               # SAME feature-based discipline as before, scoped to this
│   │   │   └── data-assets/        # fragment's Bounded Context — usually one feature, sometimes a few
│   │   │       ├── components/
│   │   │       ├── hooks/
│   │   │       ├── api.ts          # TanStack Query hooks, using the shared generated API client
│   │   │       ├── types.ts
│   │   │       └── index.ts        # PUBLIC surface within this fragment
│   │   ├── shared/                 # FRAGMENT-LOCAL shared code only — not cross-fragment
│   │   │   ├── hooks/
│   │   │   └── lib/
│   │   └── main.tsx                # standalone entry (local dev) + the module federation exposes entry
│   ├── vite.config.ts              # Module Federation REMOTE config — exposes: {...}, shared: {...}
│   ├── tsconfig.json
│   ├── eslint.config.js
│   ├── Dockerfile
│   └── package.json
│
├── compliance/                     # another fragment, same internal shape
├── data-sources/
└── estate-graph/
│
packages/
├── design-system/                  # shared, independently-versioned — every fragment + shell consume it
│   ├── src/
│   │   ├── ui/                     # atoms/molecules (Button, Badge…) — federated or npm-published
│   │   ├── tokens.css              # design tokens as CSS custom properties (see css-styling-strategy)
│   │   └── hooks/                  # truly generic hooks (useDebounce, useMediaQuery)
│   └── package.json
└── api-client/                     # shared generated API client — one per product, not per fragment
    ├── src/
    │   ├── generated.ts            # GENERATED from openapi.yaml — never edited
    │   └── client.ts                # typed fetch client (see react-api-client)
    └── package.json

tests/                              # cross-fragment e2e (Playwright); unit tests live beside source per app
```

Unit tests live **beside** the file they test (`Button.tsx` +
`Button.test.tsx`) within each app; end-to-end specs spanning multiple
fragments live in the top-level `tests/`.

**One fragment, one feature (usually).** Most Bounded-Context-aligned
fragments own exactly one `features/` folder — the old single-app
layout's `features/data-assets`, `features/compliance`, etc. each become
their own `apps/<fragment>/` today. A fragment growing a second, distinct
feature is a signal to re-check its Bounded Context boundary
(`microfrontend-architecture`'s `assets/fragment-ownership-canvas.md`),
not to assume the fragment naturally absorbs it.

---

## What Belongs Where, and Why

Every directory in the tree above exists because of a specific property
Jackson & Herrington's *Practical Module Federation*
(`research/micro-frontends/practical-module-federation-jackson-herrington.md`)
and `microfrontend-architecture` establish about how a shell and a remote
actually compose — this section states the rule *and* the reason, per
location, so a reviewer can tell a misplaced file from a correctly placed
one without re-deriving the reasoning from scratch.

### The Shell (`apps/shell/`)

| Path | Owns | Why it lives here, not in a remote |
|---|---|---|
| `src/app/App.tsx`, `providers.tsx` | The one process-wide provider tree (`QueryClientProvider`, `ErrorBoundary`, OTel, theme) | These wrap every remote's mount point; instantiating them per-remote would mean N query caches, N error boundary trees, and N OTel initializations for one page — the opposite of the shared-runtime property `shared: { react: {...} }` exists to provide |
| `src/app/router.tsx` | The host-level route tree that composes remotes via `lazy: async () => import("dataAssets/DataAssetsApp")` | The host is the only app that knows about every fragment's existence at once — a remote importing another remote's route directly would be the cross-fragment violation the Module Boundary Rules below forbid |
| `src/shell-context/` | The narrow, versioned, read-mostly shared context — current user, tenant, feature flags (`microfrontend-architecture`) | This is the *only* sanctioned channel besides `packages/` for something every fragment needs; it stays intentionally narrow because every field added here is a field every remote's build now implicitly depends on |
| `vite.config.ts` | The Module Federation **host** config: `remotes: {...}` | The shell is the one place every fragment the product composes is declared — see `references/vite-module-federation-config.md` |
| `main.tsx` | Process bootstrap only — no feature code | A shell that accumulates feature logic under time pressure ("it's just one banner, put it in the shell") is the same drift `microfrontend-architecture` warns a fragment's scope-creep about, one level up: the shell's job is composition, not features |

**What must never appear in the shell:** a `features/` directory, a
fragment-specific `api.ts`, or any import of a specific fragment's
internal types. The shell composes remotes by name through `remotes:` and
the shell context — it does not know what is inside any of them beyond
their exposed entry point's public type.

### A Remote (`apps/<fragment>/`)

| Path | Owns | Why it lives here, not the shell or `packages/` |
|---|---|---|
| `src/features/<fragment>/` | The fragment's actual capability: components, hooks, `api.ts`, `types.ts`, a public `index.ts` | This is the fragment's Bounded Context made concrete as code — everything a user does inside this fragment lives in exactly one place, per the feature-based (not type-based) discipline |
| `src/features/<fragment>/api.ts` | TanStack Query hooks built on the shared generated API client | Data-fetching logic belongs beside the feature that uses it, not centralized in a type-based `hooks/` or `services/` folder a type-based layout would create |
| `src/shared/` | Code reused by **more than one feature inside this fragment only** | Promoting fragment-local reuse straight to `packages/` before a second fragment actually needs it manufactures a false cross-product dependency; `shared/` is the fragment's own junk-drawer safety valve, scoped to stay junk-drawer-small |
| `src/main.tsx` | Two roles in one file: a standalone dev entry (so the fragment runs alone, without the shell, for fast local iteration) and the Module Federation `exposes` entry the shell actually loads | A remote that can *only* run federated inside the shell is much slower to iterate on — this repo requires both entry points to coexist, never just the federated one |
| `vite.config.ts` | The Module Federation **remote** config: `exposes: {...}` | Exposes only the fragment's deliberate public surface (its top-level feature's `index.ts`) — see `references/vite-module-federation-config.md` and the no-eager-barrel rule this skill already applies within a fragment |

**What must never appear in a remote:** an import of another fragment's
`src/` (rule 4 below), a hand-rolled copy of a server type the generated
API client already provides (rule 6 below), or a second, unrelated
feature folder without first re-checking the Bounded Context boundary.

### `packages/design-system` and `packages/api-client`

| Path | Owns | Why it lives in `packages/`, not a fragment's `shared/` |
|---|---|---|
| `packages/design-system/src/ui/` | Presentational atoms/molecules (`Button`, `Badge`, …) with no fragment-specific business logic | Every fragment and the shell consume the identical component — putting it in any one fragment's `shared/` would make every other fragment reach across a boundary that Module Boundary Rule 4 forbids |
| `packages/design-system/src/tokens.css` | Design tokens as CSS custom properties (`css-styling-strategy`) | Visual consistency across independently-deployed fragments requires one shared source of truth, not N fragments each owning a copy that can drift |
| `packages/design-system/src/hooks/` | Truly generic, business-logic-free hooks (`useDebounce`, `useMediaQuery`) | These have no Bounded Context — they're reusable exactly the way a stdlib helper is, which is the bar for anything living outside a fragment's own `shared/` |
| `packages/api-client/src/generated.ts` | Generated from `openapi.yaml` — never hand-edited | One product has one server contract; regenerating this per fragment would let each fragment's copy of "what the server returns" drift independently, defeating the entire point of a generated client |
| `packages/api-client/src/client.ts` | The typed fetch client every fragment's `api.ts` wraps with TanStack Query (`react-api-client`) | Centralizes auth headers, tenant resolution, and error mapping once, instead of once per fragment |

**The test for whether something belongs in `packages/`, a fragment's
`shared/`, or nowhere shared at all:** would a *second* fragment need this
today, not hypothetically? If yes and it's truly generic, `packages/`. If
it's reused only within one fragment, that fragment's `shared/`. If it
would only ever serve two specific fragments and no others, that is a
Bounded Context boundary question (`microfrontend-architecture`'s
`assets/fragment-ownership-canvas.md`), not a packaging question — creating
a package for exactly two consumers is the ad-hoc-shared-package
anti-pattern this skill's Anti-Patterns table already names.

---

## Module Boundary Rules, Full Detail

Two scales, both enforced — within a fragment, and across fragments:

### Within a fragment (unchanged from the single-app model)

1. **A feature's public surface is its `index.ts`.** Other code in the
   same fragment imports `features/data-assets`, never
   `features/data-assets/components/Internal`.
2. **Features within one fragment do not import each other's internals.**
   If two features in the same fragment need the same thing, it moves to
   that fragment's local `shared/`.
3. **A fragment's local `shared/` never imports from its own `features/`.**
   Dependencies point inward: `features → shared → lib`.

### Across fragments (new — per `microfrontend-architecture`)

4. **Fragments never import each other's source directly** — not even
   through a workspace path. The only cross-fragment channels are the
   shell context, custom events, and the shared `packages/` (design
   system, API client) — never a direct import from
   `apps/compliance/src/...` inside `apps/data-assets`.
5. **`packages/design-system` and `packages/api-client` are the only
   shared code every fragment may import.** Anything that feels like it
   should be shared *between two specific fragments* (not universally) is
   a sign the Bounded Context boundary needs re-examining, not a signal to
   create an ad-hoc shared package between just those two.
6. **The generated API client (`packages/api-client`) is the only source
   of server types**, consumed by every fragment identically (see
   `react-api-client`). Fragments derive their types from it; they never
   redeclare server shapes locally.

These rules are enforced by ESLint (`eslint-plugin-boundaries` /
`import/no-restricted-paths`) for the within-fragment rules, and by
**physical repository/package separation** for the cross-fragment
rules — a fragment cannot accidentally deep-import another fragment's
source because it isn't in the same npm workspace dependency graph at
all, not merely lint-discouraged.
