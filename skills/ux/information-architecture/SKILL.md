---
name: information-architecture
description: >
  Teaches how to design the information architecture (IA) of a product — the
  structure, organisation, and navigation of content and functionality. Covers
  navigation models, content hierarchy, labelling systems, URL structure, and
  the connection between the IA and the domain model's Bounded Contexts and
  Read Models. A well-designed IA makes the Ubiquitous Language visible in the
  product's navigation and reduces cognitive load for users. Produced by the
  ux-architect agent during the Design phase.
version: 1.0.0
phase: design
owner: ux-architect
tags: [design, ux, information-architecture, navigation, content-hierarchy, ia]
---

# Information Architecture

## Purpose

Information architecture (IA) defines how content and functionality are organised, labelled, and navigated. It answers: what sections exist, what lives in each section, what are they called, and how does a user move between them.

The IA is the skeleton of the product. All screen designs, navigation components, and URL structures are derived from it. A weak IA forces users to hunt for features; a strong IA makes the next action obvious.

---

## IA and the Domain Model

The IA must be grounded in the domain model. Navigation labels come from the Ubiquitous Language. Sections align with Bounded Contexts. Read Models define what data each section displays.

| Domain concept | IA implication |
|---|---|
| Bounded Context | A top-level navigation section or a distinct application area |
| Ubiquitous Language term | Navigation label, page title, column header — use the exact term, not a synonym |
| Read Model (List type) | A list/index view in the IA |
| Read Model (Detail type) | A detail/record view in the IA |
| Read Model (Aggregate type) | A dashboard or summary view in the IA |
| Domain Command | An action available in the relevant section |

---

## Navigation Models

Choose the navigation model based on the number of top-level sections and user task patterns:

| Model | When to use | Structure |
|---|---|---|
| **Top navigation bar** | 3–7 top-level sections; horizontal space available; desktop primary | Horizontal tabs or links; secondary nav as dropdown or sidebar |
| **Sidebar navigation** | Data-heavy applications; many sections; need persistent context | Left sidebar; hierarchical — section → subsection |
| **Flat navigation** | Simple products with fewer than 5 sections; mobile-first | Bottom tab bar (mobile) or minimal top nav (desktop) |
| **Hub and spoke** | Task-focused products; users complete tasks and return to a home hub | Central dashboard → task flows → return to dashboard |

For the data estate management platform:
- Primary model: **Sidebar navigation** — data-heavy, many entity types, desktop-first
- Mobile: **Flat navigation** with bottom tab bar for the 3–4 most critical sections

---

## IA Structure Notation

The IA is documented as an indented hierarchy. Each level is a navigation node.

```
Level 0 (App root)
├── Level 1: Top-level section (maps to a Bounded Context or major feature area)
│   ├── Level 2: Subsection or entity type (maps to a Read Model)
│   │   ├── Level 3: Record view (Detail Read Model)
│   │   └── Level 3: Action view (Command-driven screen)
│   └── Level 2: Dashboard (Aggregate Read Model)
└── Level 1: Settings (cross-cutting concerns)
```

### Example IA for Data Estate Management

```
[App Root]
├── Dashboard
│   └── Estate Overview (Aggregate Read Model: cross-source summary)
├── Data Sources
│   ├── All Sources (List Read Model)
│   ├── [Source Name] (Detail Read Model)
│   │   ├── Assets (List Read Model: assets in this source)
│   │   └── Scan History (List Read Model: scan runs)
│   └── Connect Source (Command: ConnectDataSource)
├── Data Assets
│   ├── All Assets (List Read Model: filterable, sortable)
│   ├── [Asset Name] (Detail Read Model)
│   │   ├── Classification (Command: ClassifyDataAsset)
│   │   ├── Lineage (Read Model: upstream/downstream)
│   │   └── Audit History (List Read Model: changes)
│   └── Bulk Classify (Command: BulkClassifyDataAssets)
├── Compliance
│   ├── Gap Report (Aggregate Read Model: gaps by framework)
│   ├── Controls (List Read Model: control status)
│   └── [Control Name] (Detail Read Model)
├── Reports
│   ├── All Reports (List Read Model)
│   ├── [Report Name] (Detail Read Model)
│   └── Generate Report (Command: GenerateComplianceReport)
└── Settings
    ├── Team (List Read Model: users)
    ├── Integrations (List Read Model: connected systems)
    └── Security (audit log, MFA settings)
```

---

## Labelling System

Labels are the names given to navigation items, page headings, buttons, and sections. Label rules:

1. **Use Ubiquitous Language terms.** If the domain model calls it a "Data Asset," the navigation label is "Data Assets" — not "Files," "Items," or "Resources."
2. **Use nouns for sections.** Section labels are nouns: "Data Assets," "Reports," "Settings."
3. **Use verb phrases for actions.** Command entry points are verb phrases: "Connect Source," "Classify Asset," "Generate Report."
4. **No jargon the user does not know.** Technical implementation terms (Aggregate, Bounded Context, Projector) do not appear in the UI.
5. **Consistent pluralisation.** List views are plural ("Data Assets"); detail views are the item name ("Invoice #1234").

### Label Inventory

Document all navigation labels and their domain mapping:

| UI label | Domain term | Type |
|---|---|---|
| Data Sources | DataSource | Bounded Context section |
| Data Assets | DataAsset | Entity / Aggregate |
| Classify Asset | ClassifyDataAsset | Command |
| Gap Report | ComplianceGapReport | Aggregate Read Model |
| Connect Source | ConnectDataSource | Command |
| Scan History | ScanRun | List Read Model |

---

## URL Structure

URLs follow the IA hierarchy. Every section in the IA maps to a URL segment. URLs use kebab-case. URL segments use the Ubiquitous Language term in its plural noun form.

| IA level | URL pattern | Example |
|---|---|---|
| Root | `/` | Dashboard |
| Top-level section | `/[section]` | `/data-assets` |
| List view | `/[section]` | `/data-assets` |
| Detail view | `/[section]/[id]` | `/data-assets/a1b2c3` |
| Action | `/[section]/[id]/[action]` | `/data-assets/a1b2c3/classify` |
| Create | `/[section]/new` | `/data-sources/new` |
| Sub-section | `/[section]/[id]/[subsection]` | `/data-sources/s1/assets` |

Rules:
- UUIDs in URLs are acceptable — no sequential integer IDs in the UI
- Query parameters for filters and sort: `/data-assets?sensitivity=Confidential&sort=name`
- No verbs in resource URLs; verbs appear in action sub-paths only (`/classify`, `/generate`)

---

## Search and Findability

For products with more than three sections or more than a handful of entity types, define the findability model:

| Mechanism | When to include | Implementation |
|---|---|---|
| Global search | When users need to find any entity from any screen | Search bar in top navigation; searches across Data Assets, Sources, Reports |
| Section filter | When a list has more than one meaningful filter attribute | Filter panel on list views |
| Sort controls | When list order affects usability | Sort dropdown or column header click |
| Breadcrumbs | When navigating three or more levels deep | Breadcrumb trail on detail and action screens |
| Recent items | For returning to recently visited records | "Recent" section on dashboard or navigation hover |

---

## IA Review Checklist

Before handoff to the frontend-engineer:

- [ ] Every Bounded Context has a corresponding top-level section (or a justified exception)
- [ ] Every Read Model (List/Detail/Aggregate) has a corresponding IA node
- [ ] Every Command has an accessible entry point in the IA
- [ ] All labels use Ubiquitous Language terms — no synonyms
- [ ] URL structure is consistent and follows the pattern
- [ ] Empty states are identified for every list view
- [ ] The IA has been verified against the flow inventory — every user flow has a valid starting point in the IA

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Domain grounding | Every top-level section maps to a BC or Read Model | Sections invented without domain basis |
| Ubiquitous Language | All labels use canonical glossary terms | Labels that are synonyms or informal equivalents |
| URL consistency | All URLs follow the defined pattern | Inconsistent URL schemes across sections |
| Command accessibility | Every Command has a reachable entry point | Commands with no navigation path |
| Empty states identified | All list views have empty state noted | List views with no empty state consideration |

---

## Output Format

```markdown
---
artifact: information-architecture
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: ux-architect
---

# Information Architecture

## Navigation Model
[Model chosen and rationale]

## IA Hierarchy
[Full indented hierarchy with domain mapping notes]

## Label Inventory
| UI label | Domain term | Type |
|---|---|---|

## URL Structure
| Section | URL pattern | Example |
|---|---|---|

## Findability Model
[Search, filter, sort, breadcrumb decisions]
```
