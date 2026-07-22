---
name: css-styling-strategy
description: >
  Teaches the CSS isolation mechanism for this plugin's micro-frontends —
  CSS Modules as the chosen strategy (build-time scoped class names,
  matching the same-framework Module Federation composition pattern from
  microfrontend-architecture), shared design-token/theming distribution
  across independently-deployed fragments, local naming conventions, and
  CI enforcement so isolation isn't left to convention. Used by
  frontend-engineer during Implement, for every fragment's styling.
version: 1.0.0
phase: implement
owner: frontend-engineer
created: 2026-07-22
tags: [implement, frontend, css, styling, microfrontend, isolation, design-tokens]
---

# CSS Styling Strategy

## Purpose

Once fragments are independently built and composed at runtime via Module
Federation (`microfrontend-architecture`), they share one page and one CSS
cascade — uncontrolled CSS collides between fragments without a
deliberate, enforced strategy. This is an architectural correctness
concern, not component polish: an unscoped style from one fragment
silently overriding another team's fragment is exactly the kind of
coupling independent deployability is supposed to prevent. Source:
`research/micro-frontends/art-of-micro-frontends-rappl.md`.

## The Isolation Mechanism: CSS Modules

Of the isolation options (Shadow DOM, CSS Modules/scoped class names,
naming-convention discipline like BEM, CSS-in-JS), this plugin uses **CSS
Modules** (build-time class-name hashing, e.g. `.button_a3f2b1`) — per
Rappl's own guidance: *"CSS Modules (or equivalent build-time scoping) as
the default for a same-framework Module Federation setup; Shadow DOM only
if using Web Components."* This repo's composition pattern is Module
Federation with all-React fragments (`microfrontend-architecture`), not
Web Components — Shadow DOM's native encapsulation solves a problem this
repo doesn't have, at a real cost (theming across a shadow boundary needs
deliberate piercing via `::part()` or CSS custom properties).

CSS Modules works with Vite natively (`*.module.css` imports, no extra
plugin), has zero runtime cost, and needs no framework-agnostic
integration tax. **Its guarantee is only as strong as the build pipeline
enforcing it** — a fragment that ships a raw global `@import` or an
un-scoped third-party stylesheet still leaks. Enforcement below is not
optional.

## Shared Design Tokens: Deliberately Global, by Contract

CSS Modules scopes *component* styles per fragment — it must **not** scope
design tokens (color, spacing, typography primitives), which need to cross
fragment boundaries by design so visual consistency survives independent
deployability (`microfrontend-architecture`'s shared design-system
package point). Tokens are **CSS custom properties** (`--color-primary`,
`--space-md`), distributed via the shared, independently-versioned
design-system package every fragment consumes — never redeclared
per-fragment.

Version the token contract with the same discipline as the shell↔fragment
contract (`microfrontend-architecture`): semver, documented, a breaking
token rename or removal is a breaking change, coordinated across every
consuming fragment before it ships — never silent. A fragment overriding
a token locally "just this once" is exactly the visual drift Geers's
research names as a certainty to actively counter.

## Local Naming Conventions

CSS Modules' build-time hashing already solves the collision problem BEM
was invented to solve manually — full BEM verbosity (`block__element--modifier`)
is not required for local class names inside a module. Use clear,
self-documenting local names (`.card`, `.cardHeader`, `.cardHeader--active`)
— readable for the humans maintaining the fragment, since the hash
(not the convention) is what actually prevents cross-fragment collision.

## Enforcement in CI

Isolation is enforced by tooling, not convention, matching this repo's
existing module-boundary enforcement (`react-project-structure`'s ESLint
boundary rules):

- A lint rule (or a `stylelint` config) fails the build if a component
  file imports a plain `.css` file instead of a `.module.css` file, except
  for the design-token stylesheet itself and any explicitly allow-listed
  third-party stylesheet.
- Any raw `@import` of an external stylesheet inside a fragment's own
  component code fails CI — third-party CSS is either wrapped through the
  Modules pipeline or explicitly declared as a shared, versioned
  dependency (same singleton discipline as a shared JS package, per
  `microfrontend-architecture`'s `references/module-federation-config.md`).
- The design-token stylesheet is the **only** allowed global CSS file per
  fragment, and it must only declare custom properties — no selectors that
  could style another fragment's markup.

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Isolation mechanism | CSS Modules used for all component styling | Plain global CSS files per component |
| Design tokens | CSS custom properties from the shared, versioned design-system package | Tokens redeclared or hardcoded per-fragment |
| Token contract | Versioned, breaking changes coordinated across fragments | A token renamed/removed with no coordination |
| Enforcement | CI fails on raw global CSS import or un-wrapped third-party stylesheet | Isolation left to convention/code review only |
| Local naming | Clear, self-documenting names — hashing does the collision-prevention work | Full defensive BEM verbosity compensating for missing build-time scoping |

## Anti-Patterns

| Anti-pattern | Instead |
|---|---|
| A fragment importing a raw, un-scoped `.css` file for component styles | `.module.css` — CI-enforced |
| Redeclaring a color/spacing value instead of using the shared token | Import the token from the shared design-system package |
| Overriding a shared token locally "just for this fragment" | Coordinate the token change across every consuming fragment, versioned |
| Adopting Shadow DOM for style isolation in an all-React Module Federation setup | CSS Modules — Shadow DOM solves a Web Components problem this repo doesn't have |
| Defensive full BEM naming to manually avoid collisions | Clear local names — CSS Modules' hash already prevents collision |
| Treating isolation as a code-review convention | CI-enforced lint/build rule — the same discipline as `react-project-structure`'s ESLint boundaries |

## Output Format

Produces the styling configuration and token contract:

```
<fragment>/src/**/*.module.css          (component styles, build-time scoped)
<fragment>/src/styles/tokens.css        (design-token custom properties — the one allowed global file)
stylelint.config.js or eslint rule      (CI enforcement of the Modules-only import rule)
```
