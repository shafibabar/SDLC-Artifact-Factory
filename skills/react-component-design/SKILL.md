---
name: react-component-design
description: >
  Teaches how to design and author React + TypeScript components from the
  ux-architect's ui-component-spec — the prop-interface design standard
  (discriminated unions for variant props so invalid combinations are
  unrepresentable, required-vs-optional prop rules), the composition-
  pattern selection standard (custom hooks vs render props vs compound
  components vs legacy HOCs, with precise decision criteria), single-
  responsibility components, the Atomic Design taxonomy, controlled vs
  uncontrolled inputs, and the presentational/container split realized
  through custom hooks. States the minimum every component must satisfy
  for testing hooks, accessibility, and error-boundary placement, cross-
  referencing react-component-testing, react-accessibility, and
  react-observability for the full standard rather than duplicating it.
  Used by the frontend-engineer during Implement.
version: 2.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, components, composition, custom-hooks, atomic-design, prop-design, discriminated-unions]
related: [react-component-testing, react-accessibility, react-observability, react-state-management, react-project-structure]
---

# React Component Design

## Purpose

A component is a single, well-named visual responsibility — small,
composable, testable by behavior, so the UI grows by combining pieces
rather than inflating God-components with ever more props. This skill
turns the ux-architect's `ui-component-spec` into React + TypeScript
components matching its props, states, and interactions exactly, and sets
the standard for prop typing and composition-tool selection. The spec is
the contract; an ambiguous one is raised to the ux-architect and updated
there — never guessed.

---

## Implement to the Spec, and the Atomic Design Taxonomy

Every state variant (loading, error, empty, populated) maps to a render
path; every interaction maps to a handler; every a11y requirement is
realized, not deferred. A stable `key` from the data — never the array
index — identifies each rendered list item. Worked `DataAssetTable`
example + the reconciliation rationale for that `key` rule: `references/worked-examples.md` §1.

Mirror the spec's taxonomy so code structure matches the design language;
atoms/molecules are app-agnostic and shared, organisms/pages belong to
their feature:

| Level | Lives in | Example |
|---|---|---|
| Atom | `shared/ui/` | `Button`, `SensitivityBadge`, `Input` |
| Molecule | `shared/ui/` or feature | `SearchBar`, `FormField` |
| Organism | feature `components/` | `DataAssetTable`, `ClassificationModal` |
| Template | feature / `app/` | `DetailPageLayout` |
| Page | feature (route element) | `DataAssetListPage` |

---

## Prop and Input Design Standard

Plain typed function + `interface`, never `React.FC` — it obscures the
props type and historically implied an untyped `children`. Props and
prop arrays are `readonly`/`ReadonlyArray<T>`.

**Discriminated unions for variant props.** If two or more optional props
can co-occur, or both be absent, in a combination meaningless for the
component (`variant: "link"` with an `onClick` and no `href`), the props
aren't independent — key a union on a literal `variant`/`kind` field so
the invalid combination fails to compile instead of surfacing as a
runtime bug. Worked example + the exact "does this need a union" test:
`references/prop-interface-and-composition-standard.md` §1.2.

**Required-vs-optional rule.** A prop is optional only with a genuinely
sensible default for its absence — never "optional because most callers
happen not to pass it." An optional prop with no decided default, or a
required prop given a fake default in destructuring, are both defects
(§1.3). Pair with `react-project-structure`'s `exactOptionalPropertyTypes`
so "omitted" and "explicit `undefined`" stay distinct contracts.

**Boolean props** are named as a predicate (`isLoading`, `hasError`) and
never accumulate past two independent flags — three or more is boolean-
prop proliferation (Anti-Patterns).

**Controlled vs uncontrolled inputs** follow the same "decide the default
deliberately" discipline: **controlled** (value + `onChange`) for a live
value — validation, dependent fields, the default for forms tied to app
state; **uncontrolled** (refs / `defaultValue`) for simple, write-once
inputs — fewer re-renders. Complex forms default to a library (React Hook
Form) that stays uncontrolled internally behind a controlled-feeling API;
reserve fully controlled fields for what genuinely needs live validation.

---

## Composition-Pattern Selection Standard

Start from **custom hooks as the default** — they compose more freely
(call several side by side), add no wrapper depth, and read as ordinary
function calls. Move down this table only when its specific condition
holds, never because a pattern looks more sophisticated:

| Pattern | Choose when | Avoid when |
|---|---|---|
| **Custom hook** | Default: fetching, derived state, effects — no rendering opinion | Reusable part must decide *what renders*, not just what value it returns |
| **Render prop** | Caller must control rendering of something the part measures/manages (a virtualizer) | No caller-side rendering variance — that's a hook |
| **Compound components** | Sub-components share implicit state + a fixed structural relationship (`Tabs`/`Tabs.List`/`Tabs.Panel`) | No genuine structural relationship — forcing unrelated pieces together is Context misuse |
| **HOC** | Legacy only — reading old code, unreachable class-only integration | Any new code — superseded by hooks (Roldán; Banks & Porcello) |

Full decision criteria + cost per pattern: `references/prop-interface-
and-composition-standard.md` Part 2. Code per row, including the
preserved `VirtualizedList` render-props example and the `Tabs` Compound
Component: `references/worked-examples.md` §§2–4.

**Context is not a state manager.** It fits a compound component's
low-frequency, narrowly-scoped shared state; every consumer re-renders on
any Provider-value change with no slice-selection — see
`react-state-management` for the Context/store boundary.

**Presentational vs container.** Presentational components take data +
callbacks via props, hold no server state (most `shared/ui`
atoms/molecules); container logic — wiring `react-api-client`/`react-
state-management` to presentational children — lives in a custom hook
today, not a wrapper component, the same separation of concerns without
the extra layer (Roldán; Banks & Porcello). A presentational component
never calls the network.

---

## Minimum Bar: Testing, Accessibility, Error Boundaries

This skill states only the minimum a component produced here must
satisfy; each cited skill owns the full standard, not duplicated here.

| Standard | Minimum this skill requires | Full standard owned by |
|---|---|---|
| Testing hook | Test-first against the spec's state/interaction table; queried by role/label, never internal state | `react-component-testing` (stack, TDD flow, MSW isolation) |
| Accessibility baseline | Semantic HTML first, ARIA only for gaps; every control keyboard-reachable and named; focus managed at modal/route/error transitions | `react-accessibility` (full WCAG 2.1 AA standard, testing layers) |
| Error-boundary placement | An organism that can fail independently (modal, widget, the graph) sits behind its own boundary, never one top-level boundary | `react-observability` (mechanics, granular placement, log enrichment) |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Implements the spec | Every spec state/interaction/a11y realized | Only the happy path built |
| Single responsibility | Small, well-named components | God-components with dozens of props |
| Prop interface typed | Discriminated unions for variants; readonly; predicate booleans | Flat optional-everything interfaces; mutable prop arrays |
| Required/optional correct | Optional only with a decided default | Undecided-default optional props; fake defaults on required ones |
| Composition over prop-drilling | children/slots/compound/hooks over threading | Props threaded through many layers |
| Right composition tool chosen | Hook by default; render prop/compound/HOC only per their row | Render prop or compound component for a plain reuse problem a hook solves |
| Logic in hooks | Non-trivial logic extracted to `useX` | Fetching/effects tangled in markup |
| Presentational/container split | Presentational components network-free | Atoms calling the API |
| Context not abused | Context for low-frequency, narrowly-scoped values only | Context as a state manager (re-render storms) |
| Stable list keys | `key` from data identity | `key={index}` on a reorderable/filterable list |
| Testing/a11y/error-boundary minimums met | Test-first + role/label queried; semantic + keyboard/focus managed; independent-failure organisms boundaried (`react-component-testing`/`react-accessibility`/`react-observability`) | Any one skipped, deferred, or retrofitted |

---

## Anti-Patterns

- **The God-component** — fetch, transform, filter state, modal state,
  three render modes behind boolean props. Split by responsibility.
- **Boolean-prop proliferation / flat optional-everything interfaces** —
  `<Table compact bordered selectable withActions>`, or every prop `?:`
  "to be safe." A discriminated `variant` union (or a compound component,
  if the flags are really structural slots) makes the invalid combination
  fail to compile instead of quietly working at runtime.
- **Prop-drilling past two layers** — a prop only forwarded is a
  composition failure; pass rendered children, not raw data.
- **`React.FC`** — obscures the props type, historically implied
  `children`, adds nothing over a plain typed function.
- **Logic in markup** — `useEffect` chains/fetch orchestration inline in
  the component body. Extract to a named `useX` hook.
- **Render prop, compound component, or HOC as the default** — a hook
  solves the same reuse problem with less indirection, no wrapper depth,
  and (for HOCs) no legacy baggage (Composition-Pattern Selection Standard).
- **`key={index}`** on a list that can reorder/filter/insert anywhere but
  the end — mismatches state to the wrong row across renders.
- **Guessing at ambiguous specs** — inventing a state the spec doesn't
  define. The spec is updated first, then implemented.

---

## Output Format

Produces React + TypeScript components and their behavior tests (written
first, per `react-component-testing`):

```
src/shared/ui/*.tsx                       (atoms/molecules)
src/features/<feature>/components/*.tsx    (organisms)
src/features/<feature>/hooks/use*.ts       (custom hooks)
*.test.tsx                                 (React Testing Library; written first)
```
