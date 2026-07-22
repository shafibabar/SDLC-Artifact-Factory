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
