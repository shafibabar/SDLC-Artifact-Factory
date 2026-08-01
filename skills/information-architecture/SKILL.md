---
name: information-architecture
description: >
  Teaches the ux-architect to design a product Information Architecture — the
  four IA systems (organization, labeling, navigation, search), the taxonomy and
  labeling rules, navigation patterns, and the validation methods card sorting
  (open vs closed) and tree testing. Grounded in Rosenfeld/Morville IA
  fundamentals. Used during Design to structure content and navigation coherently,
  including across the microfrontend fragment boundaries so the shell navigation
  stays consistent.
version: 2.0.0
phase: design
owner: ux-architect
created: 2026-06-25
tags: [design, ux, information-architecture, card-sorting, tree-testing, taxonomy, navigation, labeling]
produces: information-architecture
domain: ux
status: stable
related: [user-journey-mapping, ux-flow-design, event-storming-facilitation, glossary-management, jtbd-analysis]
---

# Information Architecture

## Purpose

Information architecture (IA) defines how content and functionality are organized, labeled, navigated, and searched. It answers four questions: what sections exist, what lives in each, what they are called, and how a user moves between and finds them.

The IA is the skeleton of the product — every screen, navigation component, and URL is derived from it. A weak IA forces users to hunt; a strong IA makes the next action obvious. IA is front-stage by design: it structures only what the customer navigates. Backstage-only Bounded Contexts (e.g. a classification engine with no UI) correctly have no IA node.

---

## The Four IA Systems (Rosenfeld / Morville)

Rosenfeld & Morville decompose IA into four interlocking systems. Design all four — an IA that only draws a nav tree has skipped three of them.

- **Organization system** — how content is grouped and structured (the categories and their scheme: exact vs. ambiguous/topical, and the hierarchy/facets that arrange them).
- **Labeling system** — what each group, page, and action is *called*; the words that represent the structure to the user.
- **Navigation system** — how the user moves through the structure: global (site-wide), local (within a section), and contextual (inline, related-item) navigation.
- **Search system** — how the user finds content directly rather than by browsing: query, filters, sort, and results.

Full treatment of each system, organization-scheme types, controlled vocabulary, URL structure, and a worked site-map: `references/ia-systems-and-labeling.md`.

---

## IA Grounds the UX Layer on Real Structure

In Olsen's Product-Market Fit Pyramid the UX layer sits atop Feature Set → Value Proposition → Underserved Needs. The IA is the load-bearing structure directly beneath the UX: it is where the feature set becomes navigable. A section that traces to no underserved need or Read Model is structural waste, however well-styled. Every top-level section should answer a real user job (for the Data Steward: govern assets; for the Compliance Officer: prove compliance), not mirror an org chart or a database schema.

### IA and the Domain Model

The IA is grounded in the domain model — labels come from the Ubiquitous Language, sections align with Bounded Contexts, Read Models define what each view displays.

| Domain concept | IA implication |
|---|---|
| Bounded Context | A top-level navigation section or a distinct application area |
| Ubiquitous Language term | Navigation label, page title, column header — the exact term, not a synonym |
| Read Model (List) | A list/index view |
| Read Model (Detail) | A detail/record view |
| Read Model (Aggregate) | A dashboard or summary view |
| Domain Command | An action entry point in the relevant section |

---

## Taxonomy and Labeling Rules

The taxonomy is the organization scheme made concrete: the named categories and how they nest. Key rules (worked design method in the reference):

1. **Consistent** — one label per concept, used identically everywhere (sidebar, page title, breadcrumb, button). Synonym drift is a defect.
2. **User language, not internal jargon** — labels use the user's and the Ubiquitous Language's terms. Implementation terms (Aggregate, Projection, Read Model) map *to* the IA; they never appear *in* it.
3. **Mutually exclusive categories where possible** — an item has one obvious home. When categories genuinely overlap, prefer facets/filters over forcing a single parent.
4. **Nouns for sections, verb phrases for actions** — "Data Assets" (section), "Classify Asset" (action).
5. **No junk-drawer** — no "Tools/More/Other" catch-all. A homeless item means a missing category, not a drawer.

---

## Navigation-Pattern Selection

Choose the navigation model from the number of top-level sections and the task pattern:

| Model | When to use |
|---|---|
| **Top navigation bar** | 3–7 top-level sections; desktop-primary; horizontal space available |
| **Sidebar navigation** | Data-heavy apps; many sections; persistent context needed |
| **Flat navigation** | Fewer than 5 sections; mobile-first (bottom tab bar) |
| **Hub and spoke** | Task-focused; users complete a task and return to a home hub |

For the data-estate/compliance platform: **sidebar** primary (data-heavy, many entity types, desktop-first); **flat** bottom-tab on mobile for the 3–4 critical sections.

---

## Validating the IA: Card Sorting and Tree Testing

An IA is a hypothesis about how users expect content to be grouped and found. Validate it with two complementary methods before the frontend-engineer builds UI — do not ship an unvalidated taxonomy.

- **Card sorting** validates the **organization and labeling** systems — how users would group and name content. Run it *open* (users create their own groups) to discover categories, or *closed* (users sort into your categories) to test a proposed taxonomy.
- **Tree testing** validates the **navigation** system — whether users can *find* a given item in a proposed hierarchy, tested on the bare label tree before any UI, styling, or search exists.

How to run each, open-vs-closed selection, participant counts, metrics, and how results feed back into the taxonomy: `references/ia-validation-methods.md`.

---

## Microfrontend IA (Shell + Remotes)

This product's frontend is a microfrontend: a shell composing independently-deployable remotes (fragments). IA responsibility splits across the fragment boundary, and the split is itself an IA decision:

- **The shell owns the global navigation system** — the top-level sections, the primary sidebar/top bar, global search, and the URL-root scheme. It is the single source of truth for cross-product structure.
- **Each fragment owns its local IA** — the sub-navigation, list/detail structure, and contextual navigation *within* its section, deployable without touching the shell.
- **Labels must stay consistent across fragments** — a term (e.g. "Data Asset") must read identically in the shell nav, in every fragment that shows it, and in the glossary. Because fragments deploy independently, label consistency has no compile-time guard; it is enforced by a shared label inventory sourced from `glossary-management`, not by hoping teams agree.

Fragment-boundary site-map and the shell-vs-fragment ownership worked example: `references/ia-systems-and-labeling.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Four systems addressed | Organization, labeling, navigation, search each designed | Only a nav tree drawn |
| Domain grounding | Every top-level section maps to a BC / Read Model / user job | Sections invented without a domain or need basis |
| Ubiquitous Language | All labels use canonical glossary terms | Synonyms or informal equivalents |
| Validated | Taxonomy card-sorted, hierarchy tree-tested before build | Structure shipped on the designer's intuition alone |
| Cross-fragment consistency | Labels identical shell↔fragments; shell owns global nav | Each fragment names the same concept differently |
| Depth budget | Any record reachable in ≤ 3 clicks from root | Content buried four or more levels deep |

---

## Anti-Patterns

- **Org-chart navigation** — sections named for internal teams or services ("Ingestion", "Pipeline", "Admin Tools") instead of user tasks. The Compliance Officer looks for "Compliance", not the service that computes it.
- **Synonym drift** — domain says DataAsset, sidebar says "Files", title says "Items", button says "Records". One term everywhere. Across microfrontends this is the default failure mode, not the exception.
- **Implementation jargon in labels** — "Projections", "Aggregates", "Read Models" surfacing in the UI. The IA maps to these; it never displays them.
- **Mirroring the database** — one nav section per table, including join/lookup tables. IA reflects Read Models and user jobs, not the schema.
- **Deep nesting as organization** — five levels where facets/filters would serve. If users must drill Source → Folder → Subfolder → Type → Asset, a filterable flat list is the better IA.
- **Unvalidated taxonomy** — shipping category names and hierarchy without a card sort or tree test, then discovering post-launch that users cannot find anything.
- **Fragment-local labeling** — letting each remote name shared concepts on its own; the shell must own the global vocabulary.

---

## Output Format

```markdown
---
name: information-architecture
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: ux-architect
---

# Information Architecture

## Organization & Navigation Model
[Model chosen and rationale; shell-vs-fragment ownership split]

## IA Hierarchy
[Indented hierarchy with domain mapping and fragment ownership notes]

## Label Inventory
| UI label | Domain term | Type | Owning fragment |
|---|---|---|---|

## Search & Findability Model
[Global search, filters, sort, breadcrumbs]

## Validation Plan
[Card sort (open/closed) and tree test: what each validates, sample size]
```
