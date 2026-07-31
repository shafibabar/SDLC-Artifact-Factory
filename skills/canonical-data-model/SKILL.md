---
name: canonical-data-model
description: >
  Design a Canonical Data Model and master-data golden records — the canonical
  entity format that reconciles differing source representations of the same
  real-world entity, entity ownership and authority (system of record vs system
  of entry), match/merge record-linkage rules, and survivorship rules that
  produce the golden record. Covers identity resolution (deterministic vs
  probabilistic matching), the anti-corruption relationship between the
  canonical model and each source model, and multi-domain / stewardship
  governance. Grounded in Loshin and Cervo & Allen MDM. Used during Design when
  multiple sources describe the same real-world entity — e.g. the same file seen
  via Google Drive and S3, or a Person named in both an extracted PDF and the
  identity provider.
version: 2.0.0
phase: design
owner: data-architect
created: 2026-06-25
tags: [design, data-architecture, mdm, canonical-model, golden-record, survivorship, match-merge]
related: [context-map-patterns, integration-design, data-lineage-design, event-schema-design, data-classification, data-model-design, multi-tenancy-design]
---

# Canonical Data Model

## Purpose

When multiple Bounded Contexts and external systems describe the same real-world thing in different ways, integration becomes a translation problem. A "person" in an extracted PDF, a "user" in the identity system, and an "owner" in a data source each describe overlapping reality with different shapes. The **Canonical Data Model (CDM)** is the single, agreed representation that these are translated *to* and *from* at integration points.

The canonical model is **not** a universal schema that every context must adopt — that would couple every context to one shape and recreate the monolith. It is an integration contract used only at boundaries. Inside its own boundary, each context keeps its own model and its own Ubiquitous Language.

This skill is knowledge — selection criteria, use-when tables, and the shape of the artifact. The `data-architect` applies it to a specific system.

---

## Where the Canonical Model Lives (and Doesn't)

| Layer | Model used |
|---|---|
| Inside a Bounded Context | The context's own domain model — its Aggregates, its Ubiquitous Language |
| At an integration boundary (event published, API consumed) | Translation to/from the canonical model |
| In an Anti-Corruption Layer | The canonical model is the translation target that protects the context from the foreign model |

The critical discipline: the canonical model is a **boundary artifact**. A context's internal code never depends on it directly; the Anti-Corruption Layer (designed by the enterprise-architect in `integration-design`, using patterns from `context-map-patterns`) translates between the foreign/canonical shape and the local model. Solving byte-level exchange without agreeing meaning produces "successfully transmitted nonsense" — the canonical model is the *semantic* contract that prevents it.

Full CDM entity format, source-to-canonical field mapping, ownership assignment (system of record vs system of entry), the four MDM architectural styles, and the ACL/Published Language relationship: **`references/cdm-format-and-ownership.md`**.

---

## Master Data and the Golden Record

Master data is the set of core entities referenced across many contexts — for the first product: `Person`, `DataSource`, `Organisation`. These need a single authoritative version despite being described by many systems.

The **Golden Record** is the reconciled, deduplicated, authoritative version of a master entity, assembled from multiple sources by survivorship rules. It is produced by a two-step mechanism:

1. **Match** (identity resolution) — decide that two source records describe the *same* real-world entity.
2. **Merge** (survivorship) — for each attribute, decide which contributing source's value survives into the golden record.

These are deliberately separate steps: a match decision can be retracted without re-deriving survivorship, which is what makes a bad merge reversible.

### Entity ownership and authority

Every canonical attribute has an authority. Distinguish two senses (Loshin), because this repo overloads the phrase "system of record":

- **System of Entry** — any system where the attribute can be created or edited (there may be several).
- **System of Record** — the one source whose value is authoritative when systems disagree, *determined by the survivorship rule*, not by which store happens to hold the golden record.

Assigning ownership per attribute (not per entity) is the decision that makes survivorship trustworthy. Full guidance in `references/cdm-format-and-ownership.md`.

### Matching (identity resolution) — the shape of the decision

| Strategy | Use when |
|---|---|
| Deterministic (exact key match) | A shared strong identifier exists (verified email, government ID) |
| Probabilistic (weighted similarity) | No shared strong key; match on similarity of name + attributes |

Probabilistic matching is not a single threshold — it partitions candidate pairs into bands (confident match, human-review, confident non-match) and needs a pre-filtering step to stay tractable at estate scale (every document across every customer's Google Drive/S3/PDF estate). The band model, the pre-filtering step, similarity-function choices per attribute type, and match precision/recall as an MDM-specific quality axis are in **`references/match-merge-survivorship.md`**.

**Matching is tenant-scoped.** Identity resolution never compares records across tenants — the product uses per-tenant physical isolation. Two tenants may each hold records describing the same real-world person; they still get two separate Golden Records. Cross-tenant matching would leak to one tenant that another holds data about the same person.

### Survivorship — the shape of the rule

When two matched sources disagree about an attribute, a survivorship rule picks the winner:

| Rule type | Example |
|---|---|
| Source priority | The identity provider's email beats an email extracted from a document |
| Recency | The most recently updated value wins |
| Completeness | A non-null value beats a null |
| Confidence | The value with the higher extraction confidence wins |

Two invariants make survivorship trustworthy:

- **Deterministic termination.** Every rule chain ends in a deterministic tie-breaker (e.g. lowest source record id). Re-running assembly over the same source records always produces the same Golden Record — otherwise it cannot serve as compliance evidence.
- **Reversibility.** Because match decisions are recorded, an incorrect merge is reversible: retract the match decision and replay assembly without it.

Worked golden-record assembly, the full `match_decisions` schema, per-(source, attribute) trust scores, merge strategy, and the sensitivity-survivorship exception (highest-sensitivity-wins, never recency) are in **`references/match-merge-survivorship.md`**.

The Golden Record is a **deterministic Read Model** over source records plus the *active* (non-retracted) match decisions, stored in PostgreSQL and rebuildable at any time. It is never hand-edited: a correction is a change to a source record, a retraction of a match decision, or a new survivorship rule — followed by replay.

---

## Canonical Model vs Event Schema

Related but distinct (owned by the same agent — keep aligned, not merged):

| Artifact | Purpose |
|---|---|
| Canonical data model (this skill) | The *semantic* integration contract — what a Person means across contexts |
| Event schema (`event-schema-design`) | The *serialization* contract — the wire format and registry for events carrying canonical entities |

When a Domain Event crosses a context boundary carrying master data, its payload uses the canonical representation. Because event payloads carry canonical shapes, changing the canonical model changes wire contracts: adding an *optional* attribute is additive and survives `BACKWARD` compatibility; adding a *required* attribute, renaming one, or changing a type is a breaking change to every event schema that carries the entity and must follow `event-schema-design`'s breaking-change procedure — never an in-place edit. Plan canonical attributes as optional-with-default wherever possible.

---

## Multi-Domain and Governance

Three master entities sharing one `match_decisions` mechanism and one survivorship section is, in substance, a **multi-domain MDM** design (Cervo & Allen). Whether that shared hub is deliberate infrastructure or an accident of file layout is a decision to record — and before adding a fourth master entity, decide explicitly whether it reuses the shared mechanism or defines its own. The `Tenant` (from `multi-tenancy-design`) vs `Organisation` question — same real-world thing, or a distinct fourth domain — must be resolved in writing, not left implicit.

Governance splits the single "Data Steward" into accountable roles (Data Domain Owner per entity; Business vs Technical Steward; a Governance Council — at this repo's solo-operator scale, Shafi — for cross-domain conflicts) and defines the golden-record lifecycle including un-merge/split. Full treatment: **`references/mdm-governance.md`**.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Boundary-only scope | Canonical model used at integration points; contexts keep internal models | Canonical model imposed as every context's internal schema |
| Golden Record defined | Each master entity has matching + survivorship rules | "Single version of truth" asserted with no reconciliation rules |
| Matching strategy explicit | Deterministic vs probabilistic stated, with thresholds/bands | Matching left implicit |
| Ownership assigned | Each attribute has a system of record per survivorship rule | Authority ambiguous or "whichever write was last" |
| Mappings complete | Every source has a field-level mapping to canonical; gaps documented | Sources feeding canonical with no documented mapping |
| Lineage preserved | Every Golden Record traces to contributing source records | Reconciled records with no provenance |
| Aligned with ACL | Canonical model is the named translation target in `integration-design` | Canonical model disconnected from the ACL design |
| Survivorship deterministic | Every rule chain ends in a deterministic tie-breaker; assembly reproducible | Two runs over the same sources yield different Golden Records |
| Matching tenant-scoped | Identity resolution never crosses tenants | Cross-tenant matching leaking entity existence between tenants |
| Golden Record is a Read Model | Rebuildable from source records + active match decisions | Hand-edited canonical records that replay would overwrite |

---

## Anti-Patterns

- **The enterprise canonical schema.** Forcing every Bounded Context to adopt the canonical model internally — recreates the shared-database monolith and destroys each context's Ubiquitous Language. The canonical model lives only at boundaries.
- **Golden Record without survivorship rules.** Declaring a "single source of truth" while sources still disagree — the "truth" becomes whichever write happened last.
- **Merge without provenance.** Reconciling records and discarding contributing sources or match decisions — the Golden Record can no longer be traced, disputed, or reversed.
- **Confidence stored as fact.** Promoting a confidence-weighted value into the canonical model without keeping the confidence as survivorship input — a 0.51-confidence email should be beatable by a better source later.
- **Canonical model edited in place.** Adding a required attribute or renaming one directly, silently breaking every event schema and ACL mapping — canonical changes follow event-schema evolution discipline.
- **Sensitivity survivorship by recency.** Letting the most recent source set `classification` — sensitivity always survives by highest-sensitivity-wins; a newer, lower-sensitivity source must never downgrade protection.
- **Implicit multi-domain hub.** Adding a fourth master entity to the shared mechanism without deciding whether it should share it — the decision stops being free once a fourth domain exists.

---

## Output Format

```markdown
---
name: canonical-data-model
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: data-architect
---

# Canonical Data Model

## Master Entities
| Entity | System of record | Consumers | MDM style |
|---|---|---|---|

## Canonical Entity Definitions
[YAML per canonical entity: attributes, survivorship, provenance]

## Identity Resolution
| Entity | Matching strategy | Key / threshold / bands |
|---|---|---|

## Survivorship Rules
| Entity | Attribute | Rule |
|---|---|---|

## Source-to-Canonical Mappings
| Source | Source field | Canonical field | Transformation |
|---|---|---|---|
```
