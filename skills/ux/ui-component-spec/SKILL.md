---
name: ui-component-spec
description: >
  Teaches how to write UI component specifications — the design contracts between
  the ux-architect and the frontend-engineer. Covers component anatomy, prop
  specifications, state variants, interaction behaviour, accessibility requirements,
  and the connection between UI components and the domain's Read Models and Commands.
  Component specs are the primary input to the frontend-engineer's React+TypeScript
  implementation. Produced by the ux-architect agent during the Design phase.
version: 1.1.0
phase: design
owner: ux-architect
created: 2026-06-25
tags: [design, ux, ui-components, react, typescript, accessibility, component-spec]
---

# UI Component Specification

## Purpose

A UI component specification is the contract between the UX design and the frontend implementation. It defines exactly what a component does, what data it displays, how it behaves in every state, and what accessibility requirements it must meet — before a single line of React code is written.

Component specs prevent the "lost in translation" failure where a developer interprets design intent differently than it was meant. They make every component a clearly scoped unit of work with defined inputs, outputs, and behaviour.

---

## Component Taxonomy

Organise components using Atomic Design principles:

| Level | Name | Description | Examples |
|---|---|---|---|
| 1 | **Atom** | Smallest indivisible UI element | Button, Badge, Input, Icon, Tooltip |
| 2 | **Molecule** | Atoms combined into a functional unit | SearchBar (Input + Button), FormField (Label + Input + Error) |
| 3 | **Organism** | Molecules combined into a distinct section | DataAssetTable (table + pagination + filters), ClassificationModal |
| 4 | **Template** | Page-level layout structure | DashboardLayout, DetailPageLayout |
| 5 | **Page** | Template + data — the full screen | DataAssetListPage, DataAssetDetailPage |

The frontend-engineer implements atoms and molecules as shared components. Organisms map to features. Templates define layout. Pages connect data (Read Models) to templates.

---

## Component Spec Format

Every component gets a specification with these sections:

### Header

```
Component: [ComponentName]
Level: [Atom | Molecule | Organism | Template | Page]
Domain mapping: [Read Model or Command this component represents]
Owned by: frontend-engineer
```

### Props

Define every prop the component accepts. Props are typed — use TypeScript types directly.

| Prop | Type | Required | Default | Description |
|---|---|---|---|---|
| `assets` | `DataAsset[]` | Yes | — | List of data assets to display |
| `onClassify` | `(id: string) => void` | Yes | — | Called when user clicks Classify on a row |
| `isLoading` | `boolean` | No | `false` | Shows skeleton loader when true |
| `emptyState` | `ReactNode` | No | Default empty state | Override for the empty state content |

### State Variants

Every component has visual and behavioural states. All states must be specified.

| State | Trigger | Visual treatment | Behaviour |
|---|---|---|---|
| **Loading** | `isLoading={true}` | Skeleton rows replace data | No interactions; rows are non-clickable |
| **Empty** | `assets.length === 0` | Empty state illustration + CTA | "Connect a source" CTA is clickable |
| **Populated** | `assets.length > 0` | Full table with data | All interactions enabled |
| **Error** | `error !== null` | Error banner at top of table | "Retry" button reloads data |
| **Selected** | One or more rows checked | Bulk action toolbar appears | Bulk classify becomes enabled |

### Interaction Behaviour

Document every user interaction and its response:

| Interaction | User action | System response |
|---|---|---|
| Row click | Click anywhere on a data asset row | Navigate to `/data-assets/[id]` |
| Classify click | Click "Classify" button on a row | Open `ClassificationModal` with `assetId` |
| Sort | Click column header | Toggle sort asc/desc; update URL query param `?sort=[col]` |
| Filter | Select sensitivity level filter | Filter list; update URL query param `?sensitivity=[level]` |
| Bulk select | Click row checkbox | Add to selection; show bulk toolbar |
| Bulk classify | Click "Classify Selected" in toolbar | Open `BulkClassificationModal` with selected IDs |

### Accessibility Requirements

Every component must meet WCAG 2.1 AA. Document component-specific requirements:

| Requirement | WCAG 2.1 AA criterion | Implementation |
|---|---|---|
| Keyboard navigation | 2.1.1 Keyboard, 2.1.2 No Keyboard Trap | Tab order follows visual order; all actions reachable by keyboard; focus can always leave the component |
| Visible focus | 2.4.7 Focus Visible | Every interactive element has a visible focus indicator — never `outline: none` without a replacement |
| Screen reader | 1.3.1 Info and Relationships, 4.1.2 Name Role Value | Table has `aria-label`; column headers use `<th scope="col">`; sort state announced via `aria-sort` |
| Focus management | 2.4.3 Focus Order | After modal opens, focus moves to first interactive element; after modal closes, focus returns to trigger |
| Colour contrast | 1.4.3 Contrast (Minimum), 1.4.11 Non-text Contrast | Normal text ≥ 4.5:1; large text (≥ 24px, or ≥ 18.66px bold) ≥ 3:1; non-text UI parts (badge boundaries, icons, focus indicators, input borders) ≥ 3:1 |
| Colour independence | 1.4.1 Use of Color | Sensitivity levels are never conveyed by colour alone — the badge always carries the level text (Public / Internal / Confidential / Restricted) |
| Loading state | 4.1.3 Status Messages | `aria-busy="true"` on table during loading; a polite live region announces "Loading data assets" |
| Error state | 4.1.3 Status Messages, 3.3.1 Error Identification | Error message has `role="alert"` so screen readers announce it immediately; the field in error is identified in text |
| Reflow | 1.4.10 Reflow | Component remains usable at 320px width / 400% zoom without two-dimensional scrolling (data tables may scroll horizontally as an allowed exception) |

---

## Domain-Mapped Components

For each Read Model and Command in the domain, there is a corresponding component:

### Read Model → Component Mapping

| Read Model | Component | Level |
|---|---|---|
| `DataAssetListView` | `DataAssetTable` | Organism |
| `DataAssetDetailView` | `DataAssetDetailCard` | Organism |
| `ComplianceGapReportView` | `ComplianceGapReport` | Organism |
| `DataSourceListView` | `DataSourceTable` | Organism |
| `EstateOverviewView` | `EstateSummaryDashboard` | Organism |

### Command → Component Mapping

| Command | Component | Level |
|---|---|---|
| `ClassifyDataAsset` | `ClassificationModal` | Organism |
| `ConnectDataSource` | `ConnectSourceWizard` | Organism |
| `GenerateComplianceReport` | `GenerateReportForm` | Organism |
| `BulkClassifyDataAssets` | `BulkClassificationModal` | Organism |

---

## Component Spec Example: ClassificationModal

```
Component: ClassificationModal
Level: Organism
Domain mapping: ClassifyDataAsset command
Owned by: frontend-engineer
```

**Props:**

| Prop | Type | Required | Default | Description |
|---|---|---|---|---|
| `assetId` | `string` | Yes | — | UUID of the asset to classify |
| `assetName` | `string` | Yes | — | Display name shown in modal title |
| `currentLevel` | `SensitivityLevel \| null` | No | `null` | Pre-selects current classification |
| `onSuccess` | `(level: SensitivityLevel) => void` | Yes | — | Called after successful classification |
| `onClose` | `() => void` | Yes | — | Called when modal is dismissed |

**State variants:**

| State | Visual | Behaviour |
|---|---|---|
| Open (no selection) | Sensitivity options shown; Save disabled | User must select a level before saving |
| Open (selection made) | Chosen option highlighted; Save enabled | User can save |
| Saving | Save button shows spinner; form fields disabled | API call in progress |
| Success | Modal closes; parent list updates | `onSuccess` callback fires |
| Error (API) | Error banner below form; form re-enabled | User can retry |
| Error (validation) | Inline error under sensitivity selector | Shown before API call if level missing |

**Interactions:**

| Interaction | Response |
|---|---|
| Select sensitivity level | Radio button selected; Save button enabled |
| Click Save | POST to API; show saving state |
| Click Cancel | `onClose()` called; no API call |
| Press Escape | `onClose()` called |
| Click overlay | `onClose()` called |

**Accessibility:**

- `role="dialog"` with `aria-modal="true"` and `aria-labelledby` pointing to modal title
- Focus trapped within modal while open
- Focus moves to first radio button when modal opens
- Focus returns to "Classify" trigger button when modal closes

---

## Component Inventory

Before implementation begins, produce the complete component inventory. This is the frontend-engineer's work breakdown.

| Component | Level | Priority | Domain mapping | Dependencies |
|---|---|---|---|---|
| `SensitivityBadge` | Atom | P1 | SensitivityLevel value | None |
| `DataAssetTable` | Organism | P1 | DataAssetListView | `SensitivityBadge`, `Button` |
| `ClassificationModal` | Organism | P1 | ClassifyDataAsset | `SensitivityBadge`, `Modal` |
| `ComplianceGapReport` | Organism | P2 | ComplianceGapReportView | `StatusBadge`, `Chart` |
| `ConnectSourceWizard` | Organism | P2 | ConnectDataSource | `Step`, `Form` |

Priority 1 components are needed for the MVP slice. Priority 2 for the full feature set.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| All Read Models mapped | Every Read Model has a component spec | Read Models with no UI representation |
| All Commands mapped | Every Command has a component spec | Commands with no entry point component |
| All states specified | Every component has all states documented | Components with only "happy state" |
| Accessibility documented | Every component has WCAG 2.1 AA requirements | Components with no accessibility spec |
| TypeScript types | All props have TypeScript types | Props with `any` or no type |
| Domain language | Component props and labels use Ubiquitous Language | Props named with technical or informal terms |
| WCAG criteria cited | Accessibility rows reference the specific WCAG 2.1 AA success criterion | "Must be accessible" with no testable criterion |

---

## Anti-Patterns

- **Happy-state specs.** Specifying only the populated state and leaving loading, empty, error, and permission-denied states to the implementer's imagination. The states table is where most rework hides — five states specified is the floor, not thoroughness.
- **Screenshot-as-spec.** Handing over a mockup image with no props, states, or interaction table. A picture specifies one state at one viewport with one dataset; the frontend-engineer needs the contract.
- **`data: any`.** Props typed as `any`, `object`, or `unknown` defer the type decision to implementation time, where it will be made inconsistently. Prop types come from the Read Model's TypeScript definitions.
- **Business logic in the component spec.** A spec that says "disable Save if the user lacks data-assets:write and the asset is Restricted" is embedding policy in the UI. The API decides authorisation; the component renders the decision (e.g. a `canClassify` prop) — never re-derives it.
- **Accessibility as a footer note.** "Component must be WCAG compliant" with no criterion, no implementation note, no testable statement. Every accessibility row cites its success criterion and how the component meets it.
- **Colour-only status.** A red/amber/green badge with no text. Fails 1.4.1 and fails every colour-blind Compliance Officer reading a gap report.
- **Modal spawn without focus contract.** Specifying that a modal opens but not where focus goes, whether it is trapped, or where it returns. Unspecified focus behaviour is how keyboard users get lost.
- **Duplicating domain state client-side.** A spec that has the component compute derived compliance status from raw fields, when `ComplianceGapReportView` already provides it. Components display Read Models; they do not re-implement them.

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
| Component | Level | Priority | Domain mapping |
|---|---|---|---|

## Component: [Name]

**Level:** [Atom/Molecule/Organism/Template/Page]
**Domain mapping:** [Read Model or Command]

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
