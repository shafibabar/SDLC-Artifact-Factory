---
name: canonical-data-model
description: >
  Teaches how to design a canonical data model — the shared, normalised
  representation used to integrate data across Bounded Contexts and external
  sources. Covers Master Data Management, the Golden Record pattern, how
  heterogeneous source formats are normalised to a canonical entity, and how the
  canonical model relates to (and must not violate) each context's own model.
  The canonical model is the translation target for Anti-Corruption Layers.
  Produced by the data-architect during the Design phase.
version: 1.1.0
phase: design
owner: data-architect
created: 2026-06-25
tags: [design, data-architecture, canonical-model, mdm, golden-record, integration, acl]
---

# Canonical Data Model

## Purpose

When multiple Bounded Contexts and external systems describe the same real-world thing in different ways, integration becomes a translation problem. A "person" in an extracted PDF, a "user" in the identity system, and an "owner" in a data source each describe overlapping reality with different shapes. The canonical data model is the single, agreed representation that these are translated *to* and *from* at integration points.

The canonical model is **not** a universal schema that all contexts must adopt — that would couple every context to one shape and recreate the monolith. It is an integration contract used only at boundaries. Inside its own boundary, each context keeps its own model and its own Ubiquitous Language.

---

## Where the Canonical Model Lives (and Doesn't)

| Layer | Model used |
|---|---|
| Inside a Bounded Context | The context's own domain model — its Aggregates, its Ubiquitous Language |
| At an integration boundary (event published, API consumed) | Translation to/from the canonical model |
| In an Anti-Corruption Layer | The canonical model is the translation target that protects the context from the foreign model |

This is the critical discipline: the canonical model is a **boundary artifact**. A context's internal code never depends on it directly; the ACL (designed by the enterprise-architect in `integration-design`) translates between the foreign/canonical shape and the local model.

---

## Master Data Management and the Golden Record

Master data is the set of core entities referenced across many contexts — for the first product: `Person`, `DataSource`, `Organisation`. These need a single authoritative version despite being described by many systems.

**The Golden Record** is the reconciled, deduplicated, authoritative version of a master entity, assembled from multiple sources by survivorship rules.

### Survivorship rules

When two sources disagree about an attribute, a survivorship rule decides which value wins:

| Rule type | Example |
|---|---|
| Source priority | The identity provider's email beats an email extracted from a document |
| Recency | The most recently updated value wins |
| Completeness | A non-null value beats a null |
| Confidence | The value with the higher extraction confidence wins |

Two rules make survivorship trustworthy:

- **Deterministic termination.** Every survivorship chain must end in a deterministic tie-breaker (e.g., lowest source record id). Re-running assembly over the same source records must always produce the same Golden Record — otherwise the Golden Record is not reproducible and cannot serve as evidence.
- **Reversibility.** Because match decisions are recorded (below), an incorrect merge is reversible: retract the match decision and replay assembly without it. A Golden Record that cannot be un-merged forces manual data surgery when identity resolution gets it wrong.

```
Golden Record assembly for Person:
  email        ← source priority: IdP > extracted   (IdP value survives)
  display_name ← completeness then recency
  identifiers  ← union of all source identifiers (kept for matching/lineage)
```

### Identity resolution (matching)

Before survivorship, records must be matched — deciding that two source records describe the *same* real entity. Document the matching strategy:

| Strategy | When |
|---|---|
| Deterministic (exact key match) | A shared strong identifier exists (verified email, government ID) |
| Probabilistic (fuzzy) | No shared strong key; match on weighted similarity of name + attributes above a threshold |

Every match decision is recorded for lineage (see `data-lineage-design`) — so a Golden Record can always be traced back to its contributing source records. The record of decisions is what makes reversibility real:

```sql
CREATE TABLE match_decisions (
    id                UUID PRIMARY KEY,
    tenant_id         UUID NOT NULL,
    canonical_id      UUID NOT NULL,           -- the canonical Person this source record was matched into
    source_system     TEXT NOT NULL,
    source_record_id  TEXT NOT NULL,
    method            TEXT NOT NULL CHECK (method IN ('deterministic','probabilistic','manual')),
    score             NUMERIC(4,3) CHECK (score IS NULL OR (score >= 0 AND score <= 1)),
    decided_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    retracted_at      TIMESTAMPTZ,             -- un-merge = set this, never DELETE — retraction is auditable
    UNIQUE (tenant_id, source_system, source_record_id, canonical_id)
);
```

The Golden Record itself is a deterministic Read Model over the source records plus the *active* (non-retracted) match decisions, stored in PostgreSQL and rebuildable at any time. It is never hand-edited: a correction is either a change to a source record, a retraction of a match decision, or a new survivorship rule — followed by replay of assembly.

**Matching is tenant-scoped.** Identity resolution never compares records across tenants. Two tenants may each hold records describing the same real-world person; they still get two separate Golden Records, one per tenant. Cross-tenant matching would be a data leak — it reveals to one tenant that another tenant holds data about the same person.

---

## Designing a Canonical Entity

For each master entity, define the canonical shape: the union of attributes needed by *consumers* at the boundary, named in neutral, source-independent terms.

```yaml
# Canonical entity: Person
canonical_entity: Person
identifier: person_id            # canonical UUID assigned at first match
attributes:
  - name: primary_email
    type: string
    source_of_truth: identity-provider
  - name: display_name
    type: string
    survivorship: completeness-then-recency
  - name: source_identifiers     # all known keys, for matching + lineage
    type: array<SourceIdentifier>
  - name: classification         # highest sensitivity of any contributing record
    type: SensitivityLevel
    survivorship: highest-sensitivity-wins
provenance:
  contributing_sources: [identity-provider, entity-extraction, data-source-crawl]
  lineage_required: true
```

**Naming:** canonical attribute names use neutral integration vocabulary, documented in the glossary. Where a canonical term maps to a different context-local term, the mapping is recorded so traceability holds.

---

## Source-to-Canonical Mapping

For every source feeding the canonical model, document the field-level mapping. This mapping is the specification the ACL implements.

| Source | Source field | Canonical field | Transformation |
|---|---|---|---|
| Entity extraction | `entity.value` (type=EMAIL) | `Person.primary_email` | lowercase, trim, validate format |
| Identity provider | `user.mail` | `Person.primary_email` | direct (authoritative) |
| Data source crawl | `owner.name` | `Person.display_name` | direct |
| Entity extraction | `entity.confidence` | (survivorship input) | used to weight, not stored as canonical attribute |

A mapping with an unmapped required canonical field is a gap — either the source cannot populate it (acceptable, documented) or the mapping is incomplete (a defect).

---

## Canonical Model vs Event Schema

These are related but distinct (and owned by the same agent — keep them aligned, not merged):

| Artifact | Purpose |
|---|---|
| Canonical data model (this skill) | The *semantic* integration contract — what a Person means across contexts |
| Event schema (`event-schema-design`) | The *serialization* contract — the wire format and registry for events that may carry canonical entities |

When a Domain Event crosses a context boundary carrying master data, its payload uses the canonical representation, and its schema is governed by `event-schema-design`.

**Evolution interplay:** because event payloads carry canonical shapes, changing the canonical model changes wire contracts. Adding an *optional* canonical attribute is additive and survives the registry's `BACKWARD` compatibility check. Adding a *required* canonical attribute, renaming one, or changing its type is a breaking change to **every** event schema that carries the entity — it must follow the breaking-change versioning procedure in `event-schema-design` (new version, parallel publication), not be edited in place. Plan canonical attributes as optional-with-default wherever possible.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Boundary-only scope | Canonical model used at integration points; contexts keep their own internal models | Canonical model imposed as every context's internal schema |
| Golden Record defined | Each master entity has matching + survivorship rules | "Single version of truth" asserted with no reconciliation rules |
| Matching strategy explicit | Deterministic vs probabilistic stated, with thresholds | Matching left implicit |
| Mappings complete | Every source has a field-level mapping to canonical; gaps documented | Sources feeding canonical with no documented mapping |
| Lineage preserved | Every Golden Record traces to contributing source records | Reconciled records with no provenance |
| Aligned with ACL | Canonical model is the named translation target in integration-design | Canonical model disconnected from the ACL design |
| Survivorship deterministic | Every rule chain ends in a deterministic tie-breaker; assembly is reproducible | Two runs over the same sources can yield different Golden Records |
| Matching tenant-scoped | Identity resolution never crosses tenants | Cross-tenant matching leaking entity existence between tenants |
| Golden Record is a Read Model | Rebuildable from source records + active match decisions | Hand-edited canonical records that replay would overwrite |

---

## Anti-Patterns

- **The enterprise canonical schema.** Forcing every Bounded Context to adopt the canonical model as its internal schema. This recreates the shared-database monolith: every context is coupled to one shape, and no context's Ubiquitous Language survives. The canonical model lives only at boundaries.
- **Golden Record without survivorship rules.** Declaring a "single source of truth" while sources still disagree. Without documented matching and survivorship, the "truth" is whichever write happened last.
- **Merge without provenance.** Reconciling records and discarding the contributing source records or match decisions. The Golden Record can no longer be traced, disputed values cannot be arbitrated, and a bad merge cannot be reversed.
- **Confidence stored as fact.** Promoting an extraction-confidence-weighted value into the canonical model without keeping the confidence as survivorship input. A 0.51-confidence email should be beatable by a better source later.
- **Canonical model edited in place.** Adding a required attribute or renaming an attribute directly, silently breaking every event schema and ACL mapping that carries the entity. Canonical changes follow the same evolution discipline as event schemas.
- **Sensitivity survivorship by recency.** Letting the most recent source set `classification`. Sensitivity always survives by highest-sensitivity-wins (the max rule from `data-classification`) — a newer, lower-sensitivity source must never downgrade a Golden Record's protection.

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
| Entity | System of truth | Consumers |
|---|---|---|

## Canonical Entity Definitions
[YAML per canonical entity: attributes, survivorship, provenance]

## Identity Resolution
| Entity | Matching strategy | Key / threshold |
|---|---|---|

## Survivorship Rules
| Entity | Attribute | Rule |
|---|---|---|

## Source-to-Canonical Mappings
| Source | Source field | Canonical field | Transformation |
|---|---|---|---|
```
