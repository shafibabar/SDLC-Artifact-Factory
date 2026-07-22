# Shared Component Contract

What changes in a component spec when a component is **Shared** (lives in
`packages/design-system`, consumed by every fragment) rather than
**Local** (lives inside one fragment, per that fragment's Bounded
Context). Self-contained — loadable without reading `SKILL.md` first,
though it assumes `microfrontend-architecture`'s fragment model and
`css-styling-strategy`'s isolation mechanism.

---

## Promotion Criteria: When a Component Becomes Shared

Default every new component to **Local** — promote to Shared only when
more than one fragment genuinely needs the identical component, not
"might reuse it someday." Per `microfrontend-architecture`'s rule that
ad-hoc sharing between just two specific fragments is a Bounded Context
signal, not a packaging decision: if only two fragments need something,
check whether they should be one fragment before reaching for
`packages/design-system`.

A component is a legitimate Shared candidate when it is:

- **Domain-agnostic** — `SensitivityBadge`, `Button`, `Modal` (Atoms and
  Molecules, per the Component Taxonomy) have no Bounded-Context-specific
  behaviour baked in.
- **Needed identically by more than one fragment** — not "similar," the
  same component with the same contract.
- **Stable** — a component still actively co-evolving with one fragment's
  domain model is premature to promote; promotion adds versioning
  overhead that only pays off once the component has settled.

Organisms, Templates, and Pages (per the Component Taxonomy) are almost
always Local — they're the components that directly map to one
fragment's Read Models and Commands, which are themselves
Bounded-Context-specific.

## The Contract Is Versioned, Like Any Cross-Fragment Contract

A Shared component's prop contract is exactly the kind of shell↔fragment
(here, design-system↔fragment) contract `microfrontend-architecture`
requires be versioned: semver, documented, a breaking prop change
coordinated across every consuming fragment before it ships — never
silent. Add a **Contract Version** field to a Shared component's header:

```
Component: SensitivityBadge
Level: Atom
Scope: Shared (packages/design-system)
Contract version: 1.2.0
Owned by: frontend-engineer
```

A prop being added is a minor version bump; a prop being removed, renamed,
or having its meaning changed is a major version bump requiring every
consuming fragment to be updated in lockstep with the release — the same
discipline as any other federated contract.

## The Styling Contract

Per `css-styling-strategy`, every fragment scopes its own styles with CSS
Modules — a Shared component ships its styles the same way, scoped within
`packages/design-system`'s own build, **not** inside any consuming
fragment's CSS Modules scope. What a Shared component's spec must state
explicitly that a Local component's spec doesn't need to:

- **Which design tokens it consumes** (from `packages/design-system`'s
  `tokens.css`) — a Shared component's visual appearance is defined
  entirely in tokens, never a hardcoded value, since it renders inside
  fragments it wasn't built by and can't assume anything about their local
  styles.
- **That it accepts no fragment-supplied className/style override** unless
  the spec explicitly defines an escape hatch (e.g. a `className` prop for
  layout-only concerns like margin) — an unconstrained style override prop
  defeats the whole isolation guarantee `css-styling-strategy` provides,
  since a consuming fragment could then inject arbitrary CSS into a
  component every other fragment also renders.

## Worked Example: SensitivityBadge (Shared)

```
Component: SensitivityBadge
Level: Atom
Scope: Shared (packages/design-system)
Contract version: 1.0.0
Domain mapping: SensitivityLevel value (not tied to one fragment's Read Model)
Owned by: frontend-engineer
```

**Props:**

| Prop | Type | Required | Default | Description |
|---|---|---|---|---|
| `level` | `SensitivityLevel` | Yes | — | `Public \| Internal \| Confidential \| Restricted` |
| `className` | `string` | No | — | Layout-only escape hatch (margin/positioning); never used to override the badge's own visual treatment |

**Design tokens consumed:** `--color-sensitivity-public`,
`--color-sensitivity-internal`, `--color-sensitivity-confidential`,
`--color-sensitivity-restricted`, `--radius-badge` (all from
`packages/design-system/src/tokens.css`) — no hardcoded colors.

**State variants:** one per `SensitivityLevel` value — no loading/error
states (this is a presentational atom with no data fetching of its own).

**Accessibility:** colour independence (1.4.1) — the level's text label is
always rendered, never colour alone (this rule is inherited by every
fragment using this component, satisfied once here rather than
re-specified per fragment).

This is the component every fragment's own Organism-level specs (e.g. the
`DataAssetTable` example in `SKILL.md`) reference as a dependency, rather
than each fragment defining its own badge.

## Quality Criteria (Shared-Component Additions)

| Criterion | Pass | Fail |
|---|---|---|
| Promotion justified | Shared only when domain-agnostic, needed identically by 2+ fragments, and stable | A component promoted "just in case" or still co-evolving with one fragment's domain |
| Contract versioned | Semver on the header; breaking changes coordinated across every consuming fragment | Prop shape changed with no version bump or coordination |
| Tokens only, no hardcoding | Every visual value traces to a `packages/design-system` token | A hardcoded colour/spacing value in a Shared component |
| No style-override escape hatch (unless explicit) | `className` scoped to layout-only, explicitly documented | An unconstrained style override prop defeating isolation |

## Anti-Patterns (Shared-Component Additions)

| Anti-pattern | Instead |
|---|---|
| Promoting a component to Shared after only one fragment uses it, anticipating future reuse | Wait for a second fragment to genuinely need it identically |
| A Shared component with one fragment's Bounded-Context-specific logic baked in | Keep Bounded-Context logic in that fragment's own Local Organism; the Shared Atom/Molecule stays domain-agnostic |
| Bumping a Shared component's prop shape without coordinating every consuming fragment | Semver the contract; treat it like any other cross-fragment contract change |
| An unconstrained `style`/`className` prop that lets a consuming fragment override the component's own visual treatment | A layout-only escape hatch, explicitly scoped and documented |
