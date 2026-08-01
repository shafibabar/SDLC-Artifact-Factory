---
name: data-model-design
description: >
  Teaches the data-architect to design a data model — the conceptual/logical/physical
  progression (Hoberman), normalization to 3NF for transactional (OLTP) models,
  dimensional star/snowflake modeling for analytical (OLAP) models (Kimball), the
  OLTP-vs-OLAP model-shape decision, and PostgreSQL physical DDL patterns with pgx.
  Used during Design whenever a service needs a persistent schema or an analytical mart.
version: 2.0.0
phase: design
owner: data-architect
created: 2026-06-25
tags: [design, data-architecture, data-modeling, normalization, dimensional-modeling, postgresql, er-diagram]
produces: data-model
domain: data
status: stable
related: [bounded-context-mapping, read-model-design, data-pipeline-design, multi-tenancy-design, dashboard-specification, canonical-data-model, glossary-management]
---

# Data Model Design

## Purpose

The data model design turns the conceptual domain model — Aggregates, Entities, Value
Objects, Read Models produced by the domain-modeler — into concrete, deployable schemas.
The domain-modeler decides *what* concepts exist; the data-architect decides *how* they
are stored, keyed, constrained, indexed, and partitioned. The output is the authoritative
schema the backend-engineer turns into migrations. A schema is a contract: changing it
later means a migration, a backfill, and a coordinated deployment.

Two model *shapes* are produced by this skill, for two different jobs, and they must never
be confused: a **normalized (OLTP) model** for transactional Aggregate state, and a
**dimensional (OLAP) model** for analytical marts that back dashboards and reports.

---

## The Conceptual → Logical → Physical Progression (Hoberman)

A model is built in three deliberate passes, each for a different audience. Skipping to
physical DDL before the concepts and relationships are agreed is the central failure mode.

| Pass | Answers | Contains | Reviewer |
|---|---|---|---|
| **Conceptual (CDM)** | What the business talks about | ER-Entity names + relationship verb phrases; no keys, no types | Shafi (PM), in one sitting |
| **Logical (LDM)** | The full rigorous structure | Every attribute, cardinality/optionality, primary/alternate/foreign keys, normalization | Technical, tech-independent |
| **Physical (PDM)** | How this database stores it | PostgreSQL tables, types, indexes, deliberate denormalization | data-architect + backend-engineer |

**Before any `CREATE TABLE`,** produce a short CDM and read every relationship aloud as a
sentence a non-technical reviewer can confirm in both directions: *"Each DataAsset may
contain one or more Entities. Each Entity must belong to exactly one DataAsset."* The words
*may/must* carry optionality; *one/one-or-more* carry cardinality. A relationship that
cannot be read this way has been drawn, not validated. Give every ER-Entity and non-obvious
attribute a real one-line definition (what qualifies, what is excluded) — not the name
restated. Full CDM/LDM technique, the definition bar, and subtype/supertype modeling:
`references/normalization-oltp.md`.

> **Terminology collision — "Entity".** Hoberman's ER "Entity" (any business noun) is *not*
> this repo's DDD `Entity` (identity + lifecycle inside an Aggregate). In conceptual/logical
> work always say **ER-Entity** or **conceptual entity**, never bare "Entity". An ER
> relationship between two Aggregates documents a business rule — it never licenses a foreign
> key across an Aggregate boundary. The Aggregate rule below always wins over what a pure ER
> model would draw.

---

## The Primary Decision: Normalize for OLTP, Dimensionalize for OLAP

This is the first choice the skill forces, because the two shapes optimize for opposite things.

| | Transactional model (OLTP) | Analytical model (OLAP / mart) |
|---|---|---|
| **Job** | Record and mutate Aggregate state correctly | Aggregate history for a dashboard/report |
| **Shape** | Normalized to 3NF; one root table per Aggregate | Dimensional star: narrow fact + wide dimensions |
| **Optimizes** | Write integrity, no update anomalies | Read comprehensibility + query speed |
| **Redundancy** | Eliminated (each fact stored once) | Deliberately controlled (denormalized dimensions) |
| **Authority** | System of record | Projection — rebuildable from events + OLTP |
| **In this repo** | Every service's Aggregate schema | A Read Model backing `dashboard-specification` / `reporting-spec` |

Default to the normalized OLTP model — it is what the vast majority of services need.
Reach for a dimensional mart *only* when a Read Model exists specifically to be aggregated
for analytics, and even then it stays a plain PostgreSQL table (this repo has no separate
warehouse). Never apply dimensional modeling to operational Aggregate state; never leave a
mart un-normalized "because it's easier". Decision detail, and when a mart is warranted
versus a simple Read Model: `references/dimensional-oltp-olap.md`.

---

## Normalization in Brief (the OLTP shape)

Normalize the transactional model to **3NF** before any denormalization decision:

- **1NF** — atomic column values, no repeating groups; a repeating group becomes a child table.
- **2NF** — 3NF prerequisite: no non-key attribute depends on only part of a composite key.
- **3NF** — every non-key attribute depends on *the key, the whole key, and nothing but the
  key*; no transitive dependency (a non-key attribute determined by another non-key attribute).

Denormalization is a conscious, physical-layer-only, performance-justified exception — made
*after* the logical model is fully normalized, never as a substitute for normalizing.
Worked 1NF→BCNF walkthrough on a repo table, the anomalies each form removes, keys and
referential integrity, and when denormalizing is justified: `references/normalization-oltp.md`.

### The Aggregate-to-Schema Rule (this repo's OLTP mapping)

Normalization is filtered through the DDD Aggregate boundary:

1. **One Aggregate Root → one primary table**; the root's identity is the primary key.
2. **Child Entities → child tables** with an FK to the root and `ON DELETE CASCADE`.
3. **Value Objects are embedded** — columns, or a `jsonb` column when composite and never
   queried by its parts.
4. **Cross-Aggregate references are ID only** — a plain UUID, never an FK across the boundary.
5. **One database per service** — tables of different Bounded Contexts never share a schema.

Every Aggregate Root carries a `version` column for optimistic concurrency (compare-and-swap
in the `WHERE`), and every tenant-scoped table carries an explicit `tenant_id`. Full DDL for
these — the DataAsset worked schema, composite-FK tenant hardening, and the concurrency UPDATE
— is in `references/physical-ddl-patterns.md`.

---

## Star Schema in Brief (the OLAP shape, Kimball)

When a mart is warranted, build a **star schema** with the four-step process, in order:
(1) pick the business process, (2) declare the **grain** as one literal sentence, (3) choose
dimensions, (4) choose facts. The grain ("one row per data asset per sensitivity scan") is
the first modeling step — every dimension and fact must fit that one sentence.

- **Fact table** — narrow; foreign keys to dimensions plus numeric measures.
- **Dimension tables** — wide, denormalized, flat (a *star*, not a snowflake); each uses a
  **surrogate key**, not the source's natural key.
- Classify every fact as **additive / semi-additive / non-additive** — a point-in-time count
  sums across tenants but not across time.

Fact-table types (transaction / periodic-snapshot / accumulating-snapshot), **Slowly Changing
Dimension** Types 0–3, conformed dimensions and the bus matrix, and when this repo needs a
mart versus a plain Read Model: `references/dimensional-oltp-olap.md`.

---

## Multi-Tenancy, Graph, and Polyglot (physical layer)

The first product uses **physical multi-tenancy**, yet every tenant-scoped table still carries
`tenant_id` and every index leads with it (defence in depth — see `multi-tenancy-design`). The
estate relationship graph lives in **Apache AGE** (a PostgreSQL extension, not a separate
Neo4j) as a *projection* rebuilt from Domain Events; the relational store is the system of
record. Add a non-PostgreSQL store (Elasticsearch for full-text, MongoDB for variable-schema
extraction output) only as a rebuildable projection with an ADR — never as a second system of
record. PostgreSQL types, indexing strategy, partitioning for large tables, JSONB usage, the
graph model, and polyglot selection: `references/physical-ddl-patterns.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Progression followed | CDM relationship sentences confirmed before DDL | Straight to `CREATE TABLE` |
| Correct shape chosen | OLTP normalized to 3NF; marts dimensional | A mart left un-normalized, or a dimensional operational schema |
| Aggregate boundary preserved | One root table per Aggregate; cross-Aggregate refs by ID | FKs spanning Aggregate boundaries |
| Grain declared for marts | Every fact table has a one-sentence grain | A fact table with no stated grain |
| SCD type chosen | Each changeable dimension attribute has a documented SCD type | "Overwrite" the silent default where history is required |
| Tenant column present | Every tenant-scoped table has `tenant_id`; indexes lead with it | Reliance on physical isolation alone |
| Projections rebuildable | Graph/search/mart rebuildable from PostgreSQL + events | A projection holding authoritative state |

---

## Anti-Patterns

- **Skipping the conceptual pass.** Choosing column types and indexes before the business
  relationships are agreed — the failure mode both Hoberman and Kimball name.
- **Dimensional modeling on operational state.** A star schema where an Aggregate belongs —
  destroys write integrity for a read optimization the OLTP path never needs.
- **The un-normalized "mart".** A denormalized table with no grain, no fact-type, no
  surrogate keys — a wide dump nobody can reconcile across reports.
- **The generic entity (EAV) table.** Trading every CHECK constraint, index, and type for a
  schema nobody can query. Migrations are the cost of a real model — pay it.
- **`jsonb` as schema escape hatch.** Indexing into `->>` in hot queries. If a value's parts
  are queried or joined, they are columns; `jsonb` is for whole-consumed Value Objects.
- **The decorative `version` column.** Present but absent from the update `WHERE` — a row
  counter, not optimistic concurrency.
- **A projection promoted to system of record.** The AGE graph, Elasticsearch index, or a
  mart becoming the only place a fact lives — if a rebuild would lose data, it is already broken.

## Output Format

See `references/physical-ddl-patterns.md` for the full artifact template (Aggregate→Table
mapping, relational schemas, dimensional marts with grain, graph model, polyglot decisions,
and indexing plan).
