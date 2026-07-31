---
name: document-data-modeling
description: >
  Teaches the data-architect to design a document data model for MongoDB — the
  embedding-vs-referencing decision, denormalization tradeoffs, schema design and
  versioning in a schemaless store (schemaVersion + handle-on-read migration),
  index strategy (compound/ESR, multikey, text, TTL), aggregation-pipeline-shaped
  data, and the document-vs-relational selection (when a document store earns its
  place over the repo default PostgreSQL). Used during Design when a bounded context
  needs flexible, hierarchical, aggregate-shaped documents read and written together
  rather than join-heavy relational tables — for the data-estate/compliance product,
  a DataAsset with variable per-connector metadata and nested classification results.
version: 1.0.0
phase: design
owner: data-architect
created: 2026-07-31
tags: [design, data-architecture, document-model, mongodb, schema-design, embedding, nosql]
related: [data-model-design, data-classification, go-mongodb-repository, canonical-data-model]
---

# Document Data Modeling

## Purpose

The repo default is PostgreSQL + pgx, and `data-model-design` covers the normalized
3NF (OLTP) and dimensional (OLAP) shapes over it. This skill adds the third physical
shape: the **aggregate-oriented document model** for MongoDB. It teaches the
data-architect to decide *whether* a bounded context earns a document store against
the Postgres default, and *how* to model it if so — the embed-vs-reference decision,
denormalization as an owned tradeoff, schema versioning without DDL, and index
strategy. It is knowledge (selection criteria, rules of thumb, decision tables); the
`go-mongodb-repository` skill owns the Go `mongo-go-driver` persistence code, and
`data-classification` owns what the classification payloads mean.

A MongoDB document is a BSON object — a typed superset of JSON (`ObjectId`, dates,
decimals, binary), capped at **16MB** — and one document should hold the data read and
written *together*. This maps almost exactly onto the DDD **Aggregate** boundary: a
single-document write is atomic, so an Aggregate root and everything inside its
consistency boundary is the natural document. Model from the queries you run, not from
normalization purity.

---

## First Decision: Document Store or Postgres?

Do not reach for MongoDB by omission, and do not reach for it by novelty. The repo
biases toward Postgres for frugality and stack-default reasons; a document store must
be *justified*, and the justification recorded in the data model artifact like an ER
choice. Use this table to rule it in or out per bounded context.

| Signal | Lean document (MongoDB) | Stay relational (PostgreSQL) |
|---|---|---|
| Shape | Aggregate-shaped, read/written as one unit | Many entities joined at read time |
| Nesting | Deep or variable hierarchy per instance | Flat, uniform rows |
| Schema | Evolving / per-connector variance | Stable, shared across all rows |
| Relationships | Mostly containment (one owner) | Rich many-to-many, referential |
| Transactions | Single-aggregate writes suffice | Frequent multi-entity ACID transactions |
| Analytics | Pipeline reshaping within a collection | Ad-hoc joins across many tables |

Three-plus signals on one side decides it. A document store is the right call for the
data-estate product's `DataAsset` when each connector (Google Drive, S3, PDF/DOCX/XLSX)
contributes different metadata fields and nested classification results read together —
variance and containment. It is the *wrong* call for a strongly-relational
tenant/user/role/permission web with multi-entity transactions — that stays in Postgres.
Full decision guide with worked cases: `references/document-modeling-patterns.md`.

---

## The Core Modeling Decision: Embed vs. Reference

This is the one decision that matters most. Validate every parent-child relationship
against **three tests**:

1. **Bounded?** Will the child set stay well under the 16MB document cap?
2. **Read together?** Is the child read with the parent every time?
3. **Owned by one?** Is the child owned by exactly one parent (contained lifecycle)?

**Three yeses → embed** (nested sub-document). **Any no → reference** (store an
`ObjectId`/key, read separately). The rule of thumb by cardinality:

| Relationship | Default | Why |
|---|---|---|
| One-to-few | Embed | Bounded, contained (a DataAsset's handful of classification tags) |
| One-to-many | Reference, or embed a bounded subset | Growth risk; embed only if capped |
| One-to-squillions | **Always reference** — put the key on the *child* | Unbounded; embedding would breach 16MB (audit events per DataAsset) |

The one-to-squillions threshold, worked DataAsset examples, and the parent-key-on-child
inversion are in `references/document-modeling-patterns.md`.

**Denormalization is a deliberate, owned tradeoff.** With no joins on the write path,
you duplicate data on purpose — copying `tenantName` into each `DataAsset` so a listing
is one query, not a lookup. This trades a write-time consistency obligation (update
every copy, or accept staleness) for read locality. Make the choice with eyes open and
name who owns the update fan-out.

---

## Schemaless Still Needs a Schema — and a Version

MongoDB does not enforce structure, but a collection still has an implicit
application-level schema, and letting it drift silently is the failure mode. There is no
`ALTER TABLE` — evolution is code, not DDL.

- Put a **`schemaVersion`** field on every document from day one.
- Write the load path as a small **handle-on-read** upgrade (read a v1 document → return
  a v2 shape in memory), so schema evolution never needs a migration window. A background
  migrator can lazily rewrite at rest.
- Once the shape stabilizes, attach a **`$jsonSchema`** collection validator to make the
  contract server-enforceable.

Versioned-document pattern, migration-on-read code, and bucketing/outlier patterns:
`references/document-modeling-patterns.md`.

---

## Index Strategy Overview

An uncovered query is a design defect, not a tuning afterthought — indexing is the
difference between a working system and a collection scan. The governing rule is
**index-supports-the-query**: every hot query must be served by an index, verified with
`explain()`.

| Index type | Use when |
|---|---|
| Single-field | One equality/sort predicate |
| **Compound** | Multi-predicate query — order by the **ESR rule**: Equality, then Sort, then Range |
| **Multikey** | Predicate over an array field (automatic; indexes each element) |
| **Text** | Full-text search over string content |
| **TTL** | Anything ephemeral — auto-expire scan results, cached extractions, audit windows |
| Partial / Unique | Index a subset / enforce uniqueness (e.g. `tenantId` + natural key) |

**Tenant scoping is mandatory:** `tenantId` leads every compound index and appears in
every filter as application-layer defense-in-depth, even under per-tenant physical
isolation — a second independent layer, consistent with the Postgres tenant check.
`tenantId` is also the conceptual shard key. ESR worked examples, aggregation-pipeline
stages, and index anti-patterns: `references/aggregation-and-indexing.md`.

---

## Aggregation-Shaped Data

The **aggregation pipeline** is the document store's analytical query language: an
ordered list of stages (`$match`, `$group`, `$lookup`, `$project`, `$sort`, `$unwind`,
`$facet`) each transforming the stream. Design collections so `$match` filters early on
an indexed field. `$lookup` (left-outer join into another collection) is the deliberate
*exception* — heavy join-shaped work is the signal you may want Postgres, not Mongo.
Multi-document ACID transactions exist (snapshot isolation, 60s default limit) but
needing them frequently means the documents are drawn wrong. Full stage catalog with
worked queries: `references/aggregation-and-indexing.md`.

---

## Quality Criteria

A document data model produced under this skill is complete only when it:

- Records the **document-vs-relational** decision with the signals that drove it.
- States the **embed-vs-reference** call for every relationship against the three tests.
- Names every **denormalized** field and who owns its update fan-out.
- Carries a **`schemaVersion`** on every document and a handle-on-read upgrade plan.
- Lists **indexes** covering every hot query (ESR-ordered), with `tenantId` leading.
- Keeps every document within the **16MB** cap by construction (no unbounded embed).

## Anti-Patterns

- Choosing MongoDB by default or by novelty — it must beat Postgres on the signal table.
- Unbounded embedding (one-to-squillions in an array) — breaches 16MB.
- Denormalizing without naming the consistency obligation.
- No `schemaVersion` — silent schema drift with no upgrade path.
- Leaning on `$lookup` / multi-document transactions as the norm — re-examine the
  document boundaries instead.
- Omitting `tenantId` from a filter or from the lead of a compound index.
