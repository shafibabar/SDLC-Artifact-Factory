---
name: ui-component-spec
description: >
  Teaches how to write UI component specifications — the design contracts between
  the ux-architect and the frontend-engineer. Covers component anatomy, prop
  specifications, state variants, interaction behaviour, accessibility requirements,
  and the connection between UI components and the domain's Read Models and Commands.
  Component specs are the primary input to the frontend-engineer's React+TypeScript
  implementation. Produced by the ux-architect agent during the Design phase.
version: 1.0.0
phase: design
owner: ux-architect
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

| Requirement | Implementation |
|---|---|
| Keyboard navigation | Tab order follows visual order; all actions reachable by keyboard |
| Screen reader | Table has `aria-label`; column headers use `<th scope="col">`; sort state announced via `aria-sort` |
| Focus management | After modal opens, focus moves to first interactive element; after modal closes, focus returns to trigger |
| Colour contrast | All text meets 4.5:1 contrast ratio; status badges meet 3:1 for large text |
| Loading state | `aria-busy="true"` on table during loading; screen reader hears "Loading data assets" |
| Error state | Error message has `role="alert"` so screen readers announce it immediately |

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

---

## Output Format

```markdown
---
artifact: ui-component-spec
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
| Requirement | Implementation |
|---|---|
```
