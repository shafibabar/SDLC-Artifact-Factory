# IA Systems, Taxonomy, and Labeling — Reference

Comprehensive treatment of the four Rosenfeld/Morville IA systems, the taxonomy and
controlled-vocabulary design method, URL structure, and a worked site-map for the
data-estate/compliance platform spanning its microfrontend fragments. The SKILL.md body
names each system in one line; this file is the depth behind those pointers.

Personas assumed throughout: **Data Steward** (governs and classifies data assets day to
day) and **Compliance Officer** (proves the estate meets a framework such as SOC 2). The
frontend is a **microfrontend** — a shell composing independently-deployable remotes
("fragments"); IA responsibility is split shell-vs-fragment and that split is called out
explicitly below.

---

## 1. The Organization System

The organization system is how content is grouped. Two decisions define it: which
**organization scheme** groups the content, and which **organization structure** arranges
the groups.

### Organization schemes — exact vs. ambiguous

Rosenfeld/Morville split schemes into two families:

**Exact schemes** partition content into mutually exclusive, unambiguous cells. Membership
is objective — there is exactly one correct home for each item, and no judgement is
involved. Sub-types:

| Exact scheme | Groups by | Example in this product |
|---|---|---|
| Alphabetical | First letter | A–Z index of all data sources |
| Chronological | Date/time | Scan history, audit log by timestamp |
| Geographical | Location/region | Data residency by region (EU, US) |

Exact schemes are easy to build and maintain but only useful when the user already knows
the exact item they want (they know the source name, the date). They do not help a user who
is browsing to *learn* what exists.

**Ambiguous schemes** (also called topical or subjective schemes) group by meaning, task,
or audience — where membership requires human judgement and an item could plausibly sit in
more than one group. They are harder to design (and the reason card sorting exists) but far
more useful for discovery. Sub-types:

| Ambiguous scheme | Groups by | Example in this product |
|---|---|---|
| Topical | Subject matter | "Compliance", "Data Sources", "Data Assets" |
| Task-oriented | What the user is doing | "Classify", "Generate Report", "Connect Source" |
| Audience-oriented | Who the user is | A Data Steward workspace vs. a Compliance Officer workspace |
| Metaphor-driven | A familiar real-world model | Rarely appropriate for a compliance tool; avoid |

Most real products use a **hybrid**: an ambiguous topical top level (the sections a user
browses) with exact schemes *inside* a section (assets sorted alphabetically, scans listed
chronologically). The top-level scheme is the one that most needs validation, because it is
subjective — it is a hypothesis about the user's mental model, not a fact.

### Organization structures

- **Hierarchy (taxonomy)** — a top-down tree of parent/child categories. The dominant
  structure for navigation. Keep it broad-and-shallow rather than narrow-and-deep: users
  find items faster in a wide, shallow tree than a deep one (this is the empirical basis for
  the ≤ 3-click depth budget in the body's Quality Criteria).
- **Facets** — multiple independent classification axes applied to the same items, combined
  by filtering (a Data Asset has *sensitivity*, *source*, *classification status*, *owner* —
  each an independent facet). Prefer facets over deep hierarchy whenever items have several
  orthogonal attributes; a filterable flat list of assets beats a five-level drill-down.
- **Hypertext** — associative, non-hierarchical links between related items (contextual "see
  also", lineage links from an asset to its upstream source). Complements hierarchy; never
  replaces it as the primary structure.

---

## 2. The Labeling System

Labels are the words that represent the structure — navigation items, headings, section
names, action buttons, field labels. A label is a stand-in for a larger chunk of
information; if it is wrong, the whole group behind it becomes invisible.

### Labeling rules (the body lists these; here is the design method)

1. **One concept, one label, everywhere.** Build a **label inventory** (below) and treat it
   as normative. The same concept must not be "Data Asset" in the sidebar, "Item" on the
   page, and "Record" on the button.
2. **Use the user's language and the Ubiquitous Language.** Source every label from
   `glossary-management`. If the glossary says `DataAsset`, the label is "Data Assets" — not
   "Files", "Objects", or "Resources".
3. **No implementation jargon.** "Aggregate", "Projection", "Read Model", "Bounded Context"
   are internal modelling terms. They map *to* IA nodes; they never appear as labels.
4. **Nouns for sections, verb phrases for actions.** "Reports" (section), "Generate Report"
   (action). Consistent grammatical form is itself a findability aid.
5. **Consistent granularity and pluralization.** Sibling labels should sit at the same level
   of specificity; list views are plural ("Data Assets"), a detail view is the item's name
   ("Invoice #1234").

### The label inventory

Document every navigation label, its domain term, its type, and — because this is a
microfrontend — the fragment that owns the screen the label leads to:

| UI label | Domain term (Ubiquitous Language) | Type | Owning fragment |
|---|---|---|---|
| Data Sources | DataSource | BC section | sources-remote |
| Data Assets | DataAsset | Entity / Aggregate | assets-remote |
| Classify Asset | ClassifyDataAsset | Command | assets-remote |
| Gap Report | ComplianceGapReport | Aggregate Read Model | compliance-remote |
| Controls | Control | List Read Model | compliance-remote |
| Connect Source | ConnectDataSource | Command | sources-remote |
| Scan History | ScanRun | List Read Model | sources-remote |
| Generate Report | GenerateComplianceReport | Command | reports-remote |

The inventory is the single artifact that keeps labels consistent across independently
deployed fragments — see §6.

---

## 3. The Navigation System

Navigation is how a user moves through the organization structure. Rosenfeld/Morville split
it into three embedded types, all three of which a mature IA designs deliberately:

- **Global (site-wide) navigation** — present on every screen; the top-level sections. In
  this product it is the persistent left sidebar. **Owned by the shell.**
- **Local navigation** — navigation *within* a section (sub-tabs on a Data Source: Assets,
  Scan History, Settings). **Owned by the fragment** that renders the section.
- **Contextual navigation** — inline, content-embedded links to related items (from a Data
  Asset to its upstream source via lineage, from a gap to the control that closes it).
  Associative; owned by whichever fragment renders the content.

Supplementary navigation aids that sit outside the main systems: **breadcrumbs** (show the
user's position in the hierarchy on any view ≥ 3 levels deep), **sitemaps/indexes** (a flat
directory of everything), and **guides/wizards** (linear task flows — hand off to
`ux-flow-design`).

### URL structure (the navigation system made addressable)

URLs are part of the navigation system: they encode position in the hierarchy and must be
consistent. In a microfrontend the shell owns the root scheme and routes each top-level
segment to a fragment.

| IA level | URL pattern | Example | Routes to |
|---|---|---|---|
| Root | `/` | Dashboard | shell |
| Top-level section | `/[section]` | `/data-assets` | assets-remote |
| List view | `/[section]` | `/data-assets` | assets-remote |
| Detail view | `/[section]/[id]` | `/data-assets/a1b2c3` | assets-remote |
| Action | `/[section]/[id]/[action]` | `/data-assets/a1b2c3/classify` | assets-remote |
| Create | `/[section]/new` | `/data-sources/new` | sources-remote |
| Sub-section | `/[section]/[id]/[subsection]` | `/data-sources/s1/assets` | sources-remote |

Rules: kebab-case; plural Ubiquitous-Language noun for section segments; UUIDs (never
sequential integer IDs) for record identifiers; query parameters for facet filters and sort
(`/data-assets?sensitivity=Confidential&sort=name`); verbs only in action sub-paths
(`/classify`, `/generate`), never in resource paths. The shell's route table is the
authority; a fragment cannot invent a new top-level segment without a shell change.

---

## 4. The Search System

For any product beyond a handful of sections, browsing is not enough — users need to find
content directly. The search system spans:

| Mechanism | Include when | Notes |
|---|---|---|
| Global search | Users need any entity from any screen | Search box in the shell top bar; indexes across fragments (Data Assets, Sources, Reports). **Owned by the shell** — cross-fragment search cannot live in one remote |
| Faceted filters | A list has ≥ 1 meaningful filter attribute | Filter panel on list views; each facet is an organization-system axis (see §1) |
| Sort controls | List order affects usability | Column-header or dropdown sort |
| Recent / saved | Users return to the same records | "Recent" on the dashboard; saved searches for the Compliance Officer's recurring queries |

Search results are themselves an IA surface: they need consistent labels (same term as the
browse hierarchy), a clear result type indicator, and a path back into the hierarchy
(breadcrumb or section link). Search and browse must agree — an item found by search must be
reachable by browsing to the same label.

---

## 5. Taxonomy and Controlled Vocabulary

A **taxonomy** is the organization scheme realized as a named, structured set of categories.
A **controlled vocabulary** is the governed list of allowed terms — the enforced answer to
"what do we call this?" It is what makes the label inventory normative rather than aspirational.

Design method:

1. **Harvest terms** from the domain model (Bounded Contexts, Aggregates, Read Models,
   Commands) and from user research (interview transcripts, support tickets, the words users
   actually say).
2. **Reconcile synonyms** — for each concept, pick the single preferred term (the Ubiquitous
   Language term) and record variants as *non-preferred* (so search can map "file" → "Data
   Asset" without the label ever showing "file").
3. **Define the hierarchy** — arrange preferred terms into the broad-and-shallow taxonomy.
4. **Add relationships** where useful — broader/narrower (Data Source → Data Asset) and
   related (Gap ↔ Control) — these power contextual navigation and faceted filters.
5. **Validate** — card-sort the categories, tree-test the hierarchy (see the companion
   reference `ia-validation-methods.md`); feed results back and revise.
6. **Govern** — the vocabulary is owned in `glossary-management`; changes are versioned, and
   every fragment consumes it rather than defining its own terms.

A controlled vocabulary is the discipline that prevents synonym drift — the single most
common IA failure in a multi-team microfrontend, where nothing at build time stops two
fragments naming the same concept differently.

---

## 6. Worked Site-Map Across Microfrontend Fragments

Full IA for the platform, annotated with the fragment that owns each subtree. The shell owns
the global navigation (the top-level sections and their order) and global search; each
fragment owns its own local IA beneath its section root.

```
[App Root]  ── shell: global sidebar, global search, root routing
│
├── Dashboard                                    (shell / dashboard-remote)
│   └── Estate Overview        Aggregate Read Model: cross-source summary
│
├── Data Sources                                 (sources-remote — local IA below)
│   ├── All Sources            List Read Model
│   ├── [Source Name]          Detail Read Model
│   │   ├── Assets             List Read Model (assets in this source)
│   │   └── Scan History       List Read Model (scan runs, chronological)
│   └── Connect Source         Command: ConnectDataSource
│
├── Data Assets                                  (assets-remote — local IA below)
│   ├── All Assets             List Read Model (faceted: sensitivity, source, status)
│   ├── [Asset Name]           Detail Read Model
│   │   ├── Classification     Command: ClassifyDataAsset
│   │   ├── Lineage            Read Model (upstream/downstream — contextual nav)
│   │   └── Audit History      List Read Model (chronological)
│   └── Bulk Classify          Command: BulkClassifyDataAssets
│
├── Compliance                                   (compliance-remote — local IA below)
│   ├── Gap Report             Aggregate Read Model (gaps by framework)
│   ├── Controls               List Read Model (control status)
│   └── [Control Name]         Detail Read Model
│
├── Reports                                       (reports-remote — local IA below)
│   ├── All Reports            List Read Model
│   ├── [Report Name]          Detail Read Model
│   └── Generate Report        Command: GenerateComplianceReport
│
└── Settings                                      (shell / settings-remote)
    ├── Team                   List Read Model (users)
    ├── Integrations          List Read Model (connected systems)
    └── Security              Audit log, MFA settings
```

### Ownership contract

- **Shell owns:** the six top-level labels and their order, the sidebar, global search, the
  root URL scheme, and the shared label inventory / controlled vocabulary.
- **Each fragment owns:** everything below its section root — its local nav, list/detail
  structure, contextual links, and section-scoped facets — deployable without a shell release.
- **Consistency rule:** a fragment may *not* rename a shared concept, invent a new top-level
  section, or use a term absent from the controlled vocabulary. The label inventory (§2) is
  the contract; a shared design-token/config package distributes it so that "Data Asset"
  renders identically in the shell nav, in assets-remote, and in any other fragment that
  references an asset. Because fragments deploy independently there is no compile-time check —
  the vocabulary governance in `glossary-management` is the only guard.

A backstage-only Bounded Context (e.g. the classification engine that computes labels) has
**no node in this map** — correctly. IA is front-stage; if a reviewer asks "where is the
classification engine in the IA?", the answer is "nowhere, by design — it has no
customer-navigable surface."
