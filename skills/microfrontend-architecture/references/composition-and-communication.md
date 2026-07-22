# Composition Pattern Rationale and Cross-Fragment Communication

Why Module Federation over the alternatives, and how fragments talk to
each other without re-coupling. Per Rappl (`art-of-micro-frontends-rappl.md`),
Geers (`micro-frontends-in-action-geers.md`), and Mezzalira
(`building-micro-frontends-mezzalira.md`) in `research/micro-frontends/`.
Self-contained — loadable without reading `SKILL.md` first.

---

## Why Not the Alternatives

| Pattern | Trade-off | Why not chosen here |
|---|---|---|
| **iframe** | Strongest isolation (separate DOM/JS realm/CSS cascade); no style bleed, a crash can't take down the shell | Right tool for genuinely untrusted/third-party content, not cooperating internal fragments. Costs: no shared routing/history without extra plumbing, awkward responsive sizing, degraded accessibility (focus/screen-reader traversal across frame boundaries), communication reduced to `postMessage` only |
| **Web Components / Shadow DOM** | Same-JS-realm, direct DOM interop, native style encapsulation | React doesn't map cleanly onto the Custom Elements lifecycle (props vs. attributes, event dispatching, re-render timing all need a wrapper layer) — a real integration tax for an all-React product with no framework-agnostic requirement |
| **Edge-side composition** | Best first-paint, composition off the client entirely | New infrastructure layer to own; poor fit for pages needing heavy client-side interactivity after composition |
| **Server-side composition** | Best first-paint/SEO, closest to classic SSR | Requires every fragment to expose a server-renderable version — raises the bar for what every team's stack must support |
| **Build-time composition** | Simplest to reason about | Explicitly "a trade-off of last resort" (Mezzalira) — reintroduces a shared build and release train across teams, the exact coupling micro-frontends exist to remove |
| **Module Federation (chosen)** | Runtime JS composition, normal SPA ergonomics, independent deploys | Central hazard is shared-singleton negotiation (see `references/module-federation-config.md`) — a real but well-understood and mitigable cost |

Plain **hyperlink handoff between separately deployed pages** (Geers) is a
legitimate zeroth option worth checking before reaching for any of the
above — no shared router, no shared shell state, zero cross-fragment
coupling, a genuine full-page navigation. Use it for boundaries that don't
need to feel unified to the end user (e.g. a marketing site handing off to
an authenticated app) before reaching for shell-owned client-side
composition. This repo's default is still Module Federation for fragments
within one product experience that *do* need to feel unified — hyperlink
handoff is the right call only where that unification isn't actually
needed.

## Independent Deployability Is the Litmus Test, Not the Composition Pattern

Whichever pattern is used, a fragment that cannot build, test, and deploy
on its own — without coordinating a release with any other team — hasn't
achieved the goal. This is the test to apply when a boundary is proposed,
before checking anything about composition mechanics.

## Cross-Fragment Communication, in Order of Preference

1. **Custom DOM events** (`CustomEvent` + `dispatchEvent`/`addEventListener`)
   — lowest coupling: a fragment announces something happened without
   knowing who's listening.
2. **A shell-provided event bus / pub-sub layer** — one step more
   structured than raw DOM events, still no shared mutable store.
3. **Props/attributes at mount time** — one-directional shell → fragment
   configuration (tenant id, locale, feature flags) — the simplest and
   most common channel.
4. **A deliberately shared, minimal, versioned "shell context"** (current
   user, current tenant, auth token) exposed through a documented,
   read-mostly API — the *only* form of shared state permitted, and only
   when narrow and explicit. This is Rappl's allowance, distinct from and
   narrower than a general-purpose store.

**Never**: a shared client-side state store spanning fragment boundaries.
This re-creates the tight coupling (a shared mutable dependency every team
must coordinate around) vertical decomposition exists to eliminate — see
`react-state-management` for what server/client state architecture looks
like *within* one fragment, which is unaffected by any of this.

## Versioning and Contract Discipline

- Version the shell↔fragment contract (exposed props, events, exposed
  module shape) with semantic versioning — a breaking change is a breaking
  API change: coordinated, documented, never silent.
- Build shell↔fragment contract tests (mount the fragment against the
  shell's actual exposed context/props shape) as a required CI gate for
  each fragment's independent deploy — this is not full e2e; it's the
  mechanical safety net for the one thing unit tests inside one fragment's
  repo structurally cannot catch: another team's independent deploy
  breaking the contract.
- Canary/feature-flag a fragment's new version behind the existing shell
  before full rollout, so an independent deploy has a rollback path that
  touches nothing else.

## Production Costs to Expect, Not Hope Away

Per Geers's case-study grounding, these are observed costs, not
theoretical risk:

- **Framework-duplication page weight** — even with singleton discipline,
  independently-built fragments can still ship overlapping non-shared
  dependencies; measure real bundle weight across a user session, don't
  assume a shared build step dedupes it automatically (there is no shared
  build step by design).
- **Design/branding drift** — fragments visibly diverge over time without
  active enforcement. The shared, independently-versioned design-system
  package (see `css-styling-strategy`) is the practical countermeasure,
  not a one-time setup step — treat drift as a certainty to actively
  counter, not an edge case that might not happen.

## Self-Contained Systems: A Larger Boundary, Not Adopted Here

Geers's book also covers **Self-Contained Systems (SCS)** — a more radical
sibling concept where one team owns UI *and* backend logic *and* datastore
end-to-end, communicating with sibling systems mostly via hyperlinks
rather than inline composition. This is a materially larger, whole-system
decomposition decision than a frontend-only micro-frontend split — it
would need evaluation against this repo's backend architecture (Go
services, PostgreSQL, `enterprise-architect`'s `openapi.yaml` contract
ownership) as much as against the frontend. **Not adopted as part of this
decision** — recorded here as a further-future option if a fragment's
boundary ever needs to extend past the frontend.
