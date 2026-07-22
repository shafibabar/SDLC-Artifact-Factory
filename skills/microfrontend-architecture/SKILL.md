---
name: microfrontend-architecture
description: >
  Teaches how to decompose this plugin's frontend into independently built
  and deployed micro-frontends — decomposition strategy (vertical slices
  aligned to Bounded Context boundaries), composition pattern selection
  (Module Federation via Vite, not Webpack), fragment ownership and
  independent-deployability discipline, and cross-fragment communication
  rules. Adopted as a deliberate, Shafi-approved architecture decision
  (2026-07-22) anticipating multiple future products and teams — the
  organizational precondition every source book gates adoption on. Used by
  frontend-engineer during Implement, and by domain-modeler/enterprise-
  architect when Bounded Context boundaries double as fragment boundaries.
version: 1.0.0
phase: implement
owner: frontend-engineer
created: 2026-07-22
tags: [implement, frontend, microfrontend, module-federation, architecture, vite]
---

# Micro-Frontend Architecture

## Purpose

This plugin decomposes its frontend into independently built, tested, and
deployed micro-frontends rather than one monolithic app. This is a real
architecture decision, not a default — see Why Now below for the
justification, and `research/micro-frontends/` (four books: Mezzalira,
Rappl, Geers, Jackson & Herrington) for the full source material this
skill distills.

## Why Micro-Frontends, Why Now

Every source book gates adoption on one organizational precondition:
multiple teams that need to ship a shared frontend independently, on
their own release cadence, without blocking on each other. Mezzalira is
explicit that team count — not codebase size — is the actual trigger, and
that adopting this pattern without that precondition just adds operational
cost (multiple builds, a composition layer, cross-app contracts) for no
benefit.

This repo anticipates **multiple future products and teams contributing**
— the precondition the books require. This is a deliberate decision Shafi
made explicitly (2026-07-22, `sdlc-context.json` decision log), not an
inferred default from the research alone; the research's own honest
conclusion (see `research/micro-frontends/building-micro-frontends-mezzalira.md`'s
Caveats) was that a solo-operator, single-product context does *not* meet
the bar — that changed once the multi-product/multi-team plan was stated.

## Decomposition: Align to Bounded Contexts

Vertical split, not horizontal — per Mezzalira, one team owns a business
subdomain end-to-end (route, components, state, its own build/deploy),
never "one team owns the header, another the footer." Boundaries come
from **Bounded Context boundaries**, not arbitrary page splits — the same
boundaries `ddd-agent-handoff`'s Agent Boundary Matrix and
`subdomain-distillation`'s classification already establish for backend
decomposition. A frontend fragment and a backend Bounded Context should
line up so one cross-functional team owns a capability top to bottom.

**This repo's actual product doesn't have a finalized Context Map yet** —
no domain modeling has been run for it. This skill teaches the principle;
this product's real fragment boundaries get decided once domain modeling
happens for real, using `bounded-context-mapping` and
`subdomain-distillation` first, *then* drawing fragment lines to match —
never the reverse.

The litmus test for every fragment boundary drawn: **can this deploy on
its own, right now, without a coordinated release?** If no, the boundary
is wrong or a shared dependency needs to move. See
`assets/fragment-ownership-canvas.md`.

## Composition Pattern: Module Federation via Vite

Of the composition patterns the research compares (iframe, Web
Components/Shadow DOM, Module Federation/runtime JS composition,
edge-side, server-side, build-time), this plugin uses **runtime JS
composition via Module Federation** — it preserves normal SPA ergonomics
(no iframe boundary, no Custom-Elements/React interop tax) while still
shipping fragments independently, which build-time composition (the
"trade-off of last resort," per Mezzalira) does not achieve.

**This repo's build tool is Vite, not Webpack** (`react-project-structure`
specifies `vite.config.ts`/Rollup) — Module Federation's originating
implementation (`webpack.ModuleFederationPlugin`, per Jackson &
Herrington) doesn't apply directly. Use **Module Federation 2.0's
bundler-agnostic tooling** (`@module-federation/vite`) or
`@originjs/vite-plugin-federation` — the underlying protocol concepts
(`exposes`/`remotes`/`shared`, singleton negotiation, dynamic remotes,
bidirectional federation) transfer; exact config syntax must be verified
against the Vite-side tooling's own docs, not assumed identical to
Webpack's.

Full configuration mechanics: `references/module-federation-config.md`.
Composition-pattern rationale and cross-fragment communication rules:
`references/composition-and-communication.md`.

## Independent Deployability Is the Only Thing That Validates This

A fragment that cannot be built, tested, and deployed on its own —
without coordinating a release with any other team — hasn't achieved the
goal, regardless of composition pattern. Every fragment:

- Has its own CI/CD pipeline, versioned independently.
- Exposes a versioned shell↔fragment contract (props/events/exposed
  modules) — a breaking change to it is a breaking API change, coordinated
  and documented, never silent.
- Is contract-tested against the shell's actual exposed context shape as
  a required gate — not full e2e as the only safety net.

## Cross-Fragment Communication Stays Shallow

- **Never** a shared client-side state store spanning fragment boundaries
  — it re-creates exactly the coupling vertical decomposition removes (see
  `react-state-management` for the resulting cross-fragment state answer).
- Custom DOM events / a shell-provided pub-sub layer for the common case.
- At most a small, explicit, versioned "shell context" (current user,
  tenant, feature flags) exposed via a documented API — read-mostly, never
  a general read/write store.
- A shared, independently-versioned design-system package consumed by
  every fragment is how visual consistency survives independent
  deployability — see `css-styling-strategy` for the isolation mechanism
  that package's styles need.

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Boundary source | Fragment boundaries match Bounded Context boundaries | Fragments split by arbitrary page/component grouping |
| Independent deployability | Fragment builds/tests/deploys alone, no coordinated release | Any fragment requires another team's release to ship |
| Singleton discipline | `react`/`react-dom`/design-system marked `singleton: true` with `strictVersion: true` | Default negotiation left to "figure it out" |
| Shell↔fragment contract | Versioned, documented, breaking changes coordinated | Silent prop/event shape changes |
| Cross-fragment state | Shallow (events/pub-sub) or narrow read-mostly shell context only | A shared mutable store spanning fragments |
| Type safety across boundary | Remote's `.d.ts` generated/published, host typechecks against it | Federated import silently degrades to `any` |

## Anti-Patterns

| Anti-pattern | Instead |
|---|---|
| Splitting fragments by page/component (horizontal) | Vertical split aligned to Bounded Context |
| Build-time composition (npm-packaged, compiled together) | Runtime Module Federation — build-time reintroduces the shared-release coupling this exists to remove |
| Adopting Webpack just to get Module Federation | Vite-native Module Federation 2.0 tooling (`@module-federation/vite`) |
| A shared client-side store across fragments | Custom events / narrow versioned shell context only |
| Marking a shared dependency singleton and assuming it's solved | Explicit `requiredVersion` + `strictVersion: true` — first-loaded-wins is a real production failure mode |
| Fragment boundaries invented before Bounded Contexts exist | Model Bounded Contexts first (`bounded-context-mapping`, `subdomain-distillation`), draw fragment lines to match |
| A federated import typed as `any` | Generate and publish the remote's `.d.ts`, typecheck against it |

## Output Format

Produces the fragment topology, Module Federation config, and ownership
record:

```
apps/shell/               (host — owns global nav, shared shell context, remote loading)
apps/<fragment-name>/     (one per Bounded-Context-aligned fragment — own build, own pipeline)
  vite.config.ts          (exposes/remotes/shared per references/module-federation-config.md)
assets/fragment-ownership-canvas.md  (filled in per fragment)
```
