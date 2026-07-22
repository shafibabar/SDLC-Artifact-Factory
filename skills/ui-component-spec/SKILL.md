---
name: ui-component-spec
description: >
  Teaches how to write UI component specifications — the design contracts
  between the ux-architect and the frontend-engineer. Covers component
  anatomy, prop specifications, state variants, interaction behaviour,
  accessibility requirements, the connection between UI components and the
  domain's Read Models and Commands, and — given this plugin's shell +
  remotes microfrontend layout — which components are Shared (federated,
  living in packages/design-system, consumed by every fragment) versus
  Local (fragment-specific, mapped to that fragment's own Read
  Models/Commands), with the additional contract-versioning and styling
  discipline a Shared component's spec needs. Component specs are the
  primary input to the frontend-engineer's React+TypeScript implementation.
  Produced by the ux-architect agent during the Design phase.
version: 2.0.0
phase: design
owner: ux-architect
created: 2026-06-25
tags: [design, ux, ui-components, react, typescript, accessibility, component-spec, microfrontend]
---

# UI Component Specification

## Purpose

A UI component specification is the contract between the UX design and
the frontend implementation. It defines exactly what a component does,
what data it displays, how it behaves in every state, what accessibility
requirements it must meet, and — in this plugin's shell + remotes
layout — **whether it's Shared or Local**, before a single line of React
code is written.

Component specs prevent the "lost in translation" failure where a
developer interprets design intent differently than it was meant. They
make every component a clearly scoped unit of work with defined inputs,
outputs, behaviour, and — for Shared components — a versioned contract
every consuming fragment can rely on.

---

## Component Taxonomy

Organise components using Atomic Design principles:

| Level | Name | Description | Examples | Typical scope |
|---|---|---|---|---|
| 1 | **Atom** | Smallest indivisible UI element | Button, Badge, Input, Icon, Tooltip | Usually **Shared** |
| 2 | **Molecule** | Atoms combined into a functional unit | SearchBar (Input + Button), FormField (Label + Input + Error) | Usually **Shared** |
| 3 | **Organism** | Molecules combined into a distinct section | DataAssetTable (table + pagination + filters), ClassificationModal | Usually **Local** |
| 4 | **Template** | Page-level layout structure | DashboardLayout, DetailPageLayout | Usually **Local**, or shell-owned if it's the app shell itself |
| 5 | **Page** | Template + data — the full screen | DataAssetListPage, DataAssetDetailPage | Always **Local** |

Atoms and Molecules are domain-agnostic by nature — good default Shared
candidates. Organisms, Templates, and Pages map directly to one
fragment's Read Models and Commands, which are themselves
Bounded-Context-specific — so they're almost always Local. See Shared vs
Local Components below for the actual promotion decision, not just the
typical-by-level default.

---

## Component Spec Format

Every component gets a specification with these sections. Full worked
example (a Local Organism, `ClassificationModal`, demonstrating every
section): `references/component-spec-worked-example.md`. Full worked
example of a Shared component's spec, with its additional fields:
`references/shared-component-contract.md`.

### Header

```
Component: [ComponentName]
Level: [Atom | Molecule | Organism | Template | Page]
Scope: [Shared (packages/design-system) | Local (apps/<fragment>)]
Contract version: [semver — Shared components only]
Domain mapping: [Read Model or Command this component represents — Local components only]
Owned by: frontend-engineer
```

### Props, State Variants, Interaction Behaviour

Define every prop (typed — TypeScript types directly, never `any`), every
visual/behavioural state (loading, empty, populated, error, and any
domain-specific states — five is the floor, not thoroughness), and every
user interaction with its system response. See the worked examples for
the full table formats in practice.

### Accessibility Requirements

Every component must meet WCAG 2.1 AA. Document component-specific
requirements — each row cites its specific success criterion, never
"must be accessible" with no testable statement. Full baseline table
(the applicable-rows-vary-by-component checklist every spec draws from):
`references/accessibility-requirements-baseline.md`.

---

## Shared vs Local Components

**Default every new component to Local.** Promote to **Shared**
(`packages/design-system`, per `microfrontend-architecture`) only when a
component is domain-agnostic, needed identically (not just similarly) by
more than one fragment, and stable — not "might reuse it someday." A
component still co-evolving with one fragment's domain model is premature
to promote. If only two specific fragments seem to need something, check
whether they should be one fragment before reaching for a shared package
(`microfrontend-architecture`'s ad-hoc-sharing-signals-a-boundary-problem
rule).

A **Shared** component's spec needs two things a Local component's
doesn't:

- **A versioned contract** (semver in the header) — a breaking prop change
  is coordinated across every consuming fragment before it ships, exactly
  like any other cross-fragment contract.
- **An explicit styling contract** — which design tokens it consumes (from
  `packages/design-system/tokens.css`, per `css-styling-strategy`), and
  whether it accepts any fragment-supplied style override (default: no,
  beyond an explicitly-scoped layout-only escape hatch).

Full promotion criteria, the versioning discipline, the styling contract,
and a complete worked example (`SensitivityBadge`):
`references/shared-component-contract.md`.

---

## Domain-Mapped Components (Local)

For each Read Model and Command in **one fragment's** domain, there is a
corresponding Local component in that fragment:

| Read Model | Component | Level |
|---|---|---|
| `DataAssetListView` | `DataAssetTable` | Organism |
| `ComplianceGapReportView` | `ComplianceGapReport` | Organism |

| Command | Component | Level |
|---|---|---|
| `ClassifyDataAsset` | `ClassificationModal` | Organism |
| `ConnectDataSource` | `ConnectSourceWizard` | Organism |

A Local Organism may still depend on Shared Atoms/Molecules for its
visual building blocks (see the `ClassificationModal` worked example's
use of the Shared `SensitivityBadge`) — Local vs. Shared is about where a
component's *domain logic* lives, not whether it can consume shared UI
primitives.

---

## Component Inventory

Before implementation begins, produce the complete component inventory —
the frontend-engineer's work breakdown, with Scope now a required column:

| Component | Level | Scope | Priority | Domain mapping | Dependencies |
|---|---|---|---|---|---|
| `SensitivityBadge` | Atom | Shared | P1 | SensitivityLevel value | None |
| `DataAssetTable` | Organism | Local (data-assets) | P1 | DataAssetListView | `SensitivityBadge`, `Button` |
| `ClassificationModal` | Organism | Local (data-assets) | P1 | ClassifyDataAsset | `SensitivityBadge`, `Modal` |
| `ComplianceGapReport` | Organism | Local (compliance) | P2 | ComplianceGapReportView | `StatusBadge`, `Chart` |

Priority 1 components are needed for the MVP slice. Priority 2 for the
full feature set. A Shared component's Priority reflects the earliest
consuming fragment's need — it's built once, ahead of whichever fragment
needs it first.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| All Read Models mapped | Every Read Model has a Local component spec in its owning fragment | Read Models with no UI representation |
| All Commands mapped | Every Command has a Local entry-point component spec | Commands with no entry point component |
| Scope declared | Every component's header states Shared or Local | Scope left implicit or unstated |
| Shared components justified | Promoted only when domain-agnostic, needed identically by 2+ fragments, stable | A component promoted "just in case" |
| Shared contract versioned | Semver in the header; breaking changes coordinated | Shared prop shape changed with no version bump |
| All states specified | Every component has all states documented | Components with only "happy state" |
| Accessibility documented | Every component has WCAG 2.1 AA requirements, criterion cited | Components with no accessibility spec, or "must be accessible" with no criterion |
| TypeScript types | All props have TypeScript types | Props with `any` or no type |
| Domain language | Component props and labels use Ubiquitous Language | Props named with technical or informal terms |

---

## Anti-Patterns

- **Happy-state specs.** Specifying only the populated state and leaving loading, empty, error, and permission-denied states to the implementer's imagination. Five states specified is the floor, not thoroughness.
- **Screenshot-as-spec.** Handing over a mockup image with no props, states, or interaction table. A picture specifies one state at one viewport with one dataset; the frontend-engineer needs the contract.
- **`data: any`.** Props typed as `any`, `object`, or `unknown` defer the type decision to implementation time. Prop types come from the Read Model's TypeScript definitions.
- **Business logic in the component spec.** A spec that says "disable Save if the user lacks data-assets:write" is embedding policy in the UI. The API decides authorisation; the component renders the decision (e.g. a `canClassify` prop) — never re-derives it.
- **Accessibility as a footer note.** "Component must be WCAG compliant" with no criterion, no implementation note. Every accessibility row cites its success criterion and how the component meets it.
- **Colour-only status.** A badge with no text. Fails 1.4.1 and fails every colour-blind user.
- **Modal spawn without focus contract.** Specifying that a modal opens but not where focus goes, whether it is trapped, or where it returns.
- **Duplicating domain state client-side.** A spec that has the component compute derived data a Read Model already provides. Components display Read Models; they do not re-implement them.
- **Scope left undeclared.** No component spec is complete without stating Shared or Local — it determines whether a change needs cross-fragment coordination.
- **Promoting a component to Shared "just in case."** Wait for a genuine second consumer with an identical need — see `references/shared-component-contract.md`.

---

## Output Format

```markdown
---
name: ui-component-spec
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: ux-architect
---

# UI Component Specifications

## Component Inventory
| Component | Level | Scope | Priority | Domain mapping |
|---|---|---|---|---|

## Component: [Name]

**Level:** [Atom/Molecule/Organism/Template/Page]
**Scope:** [Shared (packages/design-system) | Local (apps/<fragment>)]
**Contract version:** [semver — Shared only]
**Domain mapping:** [Read Model or Command — Local only]

### Props
| Prop | Type | Required | Default | Description |
|---|---|---|---|---|

### State Variants
| State | Trigger | Visual | Behaviour |
|---|---|---|---|

### Interaction Behaviour
| Interaction | User action | System response |
|---|---|---|

### Accessibility
| Requirement | WCAG 2.1 AA criterion | Implementation |
|---|---|---|
```
