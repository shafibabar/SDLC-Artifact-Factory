---
name: data-model-design
description: >
  Teaches how to design the physical and logical data models for a system —
  mapping domain Aggregates to PostgreSQL relational schemas (consumed via pgx),
  designing the Apache AGE graph model (vertices and edges) for relationship data,
  deciding when polyglot persistence is justified (MongoDB for variable-schema
  extraction output, Elasticsearch for search), indexing strategy, and how the
  physical model enforces multi-tenancy. Translates the domain-modeler's conceptual
  model into deployable schemas. Produced by the data-architect during the Design phase.
version: 1.1.0
phase: design
owner: data-architect
created: 2026-06-25
tags: [design, data-architecture, postgresql, pgx, apache-age, graph, polyglot, schema]
---

# Data Model Design

## Purpose

The data model design translates the conceptual domain model — Aggregates, Entities, Value Objects, and Read Models produced by the domain-modeler — into concrete, deployable database schemas. The domain-modeler decides *what* concepts exist and how they relate in the business; the data-architect decides *how* they are physically stored, indexed, and partitioned.

This skill produces the authoritative schema definitions that the backend-engineer turns into migrations. A schema designed here is a contract: changing it later means a migration, a data backfill, and coordinated deployment.

---

## The Aggregate-to-Schema Rule

The Aggregate is the unit of consistency. The physical model preserves that boundary:

1. **One Aggregate Root maps to one primary table.** The root's identity is the primary key.
2. **Child Entities within the Aggregate map to child tables** with a foreign key to the root and `ON DELETE CASCADE`. They are never written independently of the root.
3. **Value Objects are embedded** — as columns on the owning table, or as a `jsonb` column when the value object is composite and never queried by its parts.
4. **References between Aggregates are by ID only** — a plain UUID column, never a foreign key across Aggregate boundaries. Cross-aggregate referential integrity is the domain's responsibility, not the database's.
5. **One database per service** (the enterprise-architect's container rule). Tables for different Bounded Contexts never share a schema, and joins never cross a service boundary.

### Example: DataAsset Aggregate → PostgreSQL

```sql
-- Aggregate Root
CREATE TABLE data_assets (
    id                 UUID PRIMARY KEY,
    tenant_id          UUID NOT NULL,
    source_id          UUID NOT NULL,              -- reference to DataSource Aggregate (ID only)
    file_path          TEXT NOT NULL,
    file_format        TEXT NOT NULL,              -- Value Object: enum-like (PDF, DOCX, XLSX)
    sensitivity_level  TEXT,                        -- Value Object: nullable until classified
    classified_by      UUID,
    classified_at      TIMESTAMPTZ,
    version            BIGINT NOT NULL DEFAULT 1,   -- optimistic concurrency for the Aggregate
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at         TIMESTAMPTZ,                 -- soft delete; see data-retention-policy
    CONSTRAINT sensitivity_valid CHECK (
        sensitivity_level IS NULL OR
        sensitivity_level IN ('Public','Internal','Confidential','Restricted')
    )
);

-- Child Entity within the same Aggregate (extracted entities belong to the asset)
CREATE TABLE extracted_entities (
    id             UUID PRIMARY KEY,
    data_asset_id  UUID NOT NULL REFERENCES data_assets(id) ON DELETE CASCADE,
    tenant_id      UUID NOT NULL,
    entity_type    TEXT NOT NULL,                  -- PERSON, EMAIL, SSN, ACCOUNT_NUMBER, ...
    confidence     NUMERIC(4,3) NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
    location       JSONB NOT NULL,                 -- Value Object: page/offset, queried as a whole
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The child FK column is always indexed: it serves ON DELETE CASCADE and intra-Aggregate loads
CREATE INDEX idx_extracted_entities_asset ON extracted_entities (data_asset_id);
```

**Tenant-mismatch hardening (optional but cheap):** a plain single-column FK cannot stop a child row from pointing at a parent in *another* tenant if application code passes the wrong id. Making the FK composite makes that state unrepresentable:

```sql
ALTER TABLE data_assets ADD CONSTRAINT data_assets_id_tenant_uq UNIQUE (id, tenant_id);

-- extracted_entities then declares (in place of the single-column FK):
--   FOREIGN KEY (data_asset_id, tenant_id)
--     REFERENCES data_assets (id, tenant_id) ON DELETE CASCADE
```

**Note:** `extracted_entities` stores entity *type and location metadata only* — never the raw extracted value if it is sensitive PII. This is a privacy constraint from the security `privacy-design` skill: file contents are never persisted.

---

## Optimistic Concurrency

Every Aggregate Root table carries a `version` column. Writes use a compare-and-swap on version to enforce the one-writer-per-aggregate-per-transaction rule without pessimistic locks:

```sql
UPDATE data_assets
   SET sensitivity_level = $1, version = version + 1, updated_at = now()
 WHERE id = $2 AND tenant_id = $3 AND version = $4
   AND deleted_at IS NULL;
-- 0 rows affected → concurrent modification (or soft-deleted row) → retry or fail
```

Two details that make the compare-and-swap trustworthy:

- **`tenant_id` stays in the `WHERE` even though `id` is globally unique.** The tenant filter is applied uniformly to every tenant-scoped statement — it is the application-layer backstop, not an optimisation.
- **`AND deleted_at IS NULL` prevents resurrection.** Without it, a command racing a soft delete can happily mutate a "deleted" Aggregate. Zero rows affected is a single signal the command handler must treat as a conflict, whichever cause.

---

## Multi-Tenancy in the Physical Model

The first product uses **physical multi-tenancy** (separate namespace/deployment per tenant — see `multi-tenancy-design`). Even so, every tenant-scoped table carries an explicit `tenant_id` column. This is defence in depth:

- The physical isolation prevents cross-tenant routing at the infrastructure layer.
- The `tenant_id` column + parameterised query filter is the application-layer backstop (see security `access-control-model`).
- Every index on a tenant-scoped table leads with `tenant_id`.

```sql
CREATE INDEX idx_data_assets_tenant_source ON data_assets (tenant_id, source_id);
CREATE INDEX idx_data_assets_tenant_sensitivity ON data_assets (tenant_id, sensitivity_level)
    WHERE deleted_at IS NULL;   -- partial index: active assets only
```

---

## The Graph Model (Apache AGE)

The relationship graph — how data assets, entities, sources, and people connect across the estate — is stored in Apache AGE, a PostgreSQL extension providing openCypher graph queries. Using AGE (not a separate Neo4j deployment) keeps the graph in the same PostgreSQL instance: one fewer system to operate, frugal by default.

**Graph design principles:**

| Element | Rule |
|---|---|
| Vertex (node) | One vertex label per domain concept that participates in relationships: `DataAsset`, `Entity`, `DataSource`, `Person` |
| Edge (relationship) | Named with a verb in the Ubiquitous Language: `CONTAINS`, `REFERENCES`, `OWNED_BY`, `DERIVED_FROM` |
| Vertex properties | Minimal — an `id` that references the relational row, plus `tenant_id`. The graph holds structure; the relational store holds detail. |
| Tenant isolation | Every vertex carries `tenant_id`; every query filters by it. Graph paths never cross tenants. |

```cypher
-- A data asset contains extracted entities; entities may reference a person
SELECT * FROM cypher('estate_graph', $$
    MATCH (a:DataAsset {tenant_id: $tenant})-[:CONTAINS]->(e:Entity)-[:REFERENCES]->(p:Person)
    WHERE a.id = $asset_id
    RETURN p.id, count(e) AS mentions
$$) AS (person_id agtype, mentions agtype);
```

**Relational ↔ graph consistency:** the relational store is the system of record. The graph is a projection kept current by a Projector that consumes Domain Events (`EntityExtracted`, `AssetClassified`) — see `read-model-design` and `data-pipeline-design`. The graph is replayable from events.

---

## Polyglot Persistence — When to Use What

Default to PostgreSQL. Add another store only when PostgreSQL is the wrong tool and the cost of operating a second store is justified. Document the decision as an ADR.

| Store | Use when | Do not use when | First-product use |
|---|---|---|---|
| **PostgreSQL + pgx** | Transactional Aggregates, the outbox, audit log, config — anything needing ACID | — (this is the default) | All Aggregate state, outbox, audit |
| **Apache AGE** (in PostgreSQL) | Relationship traversal queries (paths, neighbourhoods) | Simple foreign-key lookups | The data estate relationship graph |
| **MongoDB** | High-variability schema where fields differ per document and are not known ahead of time | Anything transactional or relational | Raw entity-extraction output / crawl metadata (variable per file format) — optional, behind a config flag |
| **Elasticsearch** | Full-text search, ranking, alert storage with flexible querying | As a system of record | Document full-text index, compliance alert search |

**Rule:** a non-PostgreSQL store is never a system of record for an Aggregate. It is always a projection or a derived index, rebuildable from PostgreSQL + the event log.

---

## Indexing Strategy

| Index need | Approach |
|---|---|
| Tenant-scoped lookups | Composite index leading with `tenant_id` |
| Active-record queries | Partial index `WHERE deleted_at IS NULL` |
| Foreign-key joins within an Aggregate | Index the child table's FK column |
| Time-range queries (audit, scans) | B-tree on `(tenant_id, occurred_at)`; consider BRIN for append-only large tables |
| Full-text | Do not use PostgreSQL FTS for the primary search surface — project to Elasticsearch |

Every index must justify its existence: it speeds a known query in a Read Model or Command. Speculative indexes are removed — they cost write throughput.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Aggregate boundary preserved | One root table per Aggregate; children cascade; cross-aggregate refs by ID only | Foreign keys spanning Aggregate boundaries |
| Optimistic concurrency | Every Aggregate Root has a `version` column | Aggregates with no concurrency control |
| Tenant column present | Every tenant-scoped table has `tenant_id`; every index leads with it | Tables relying solely on physical isolation |
| Graph is a projection | Graph rebuildable from events; relational store is system of record | Graph holding authoritative state not in PostgreSQL |
| Polyglot justified | Each non-PostgreSQL store has an ADR and is a projection only | A second store used as an Aggregate system of record |
| No raw sensitive content stored | Extracted entity tables store metadata/type, not raw PII values | File contents or raw PII persisted |
| Constraints encode invariants | Enum-like values and ranges guarded by CHECK constraints | Invariants enforced only in application code |

---

## Anti-Patterns

- **Foreign keys across Aggregate boundaries.** An FK from `extracted_entities` to a `DataSource` table couples two consistency units at the database layer and blocks the one-database-per-service rule. Cross-Aggregate references are plain UUID columns; the domain enforces integrity.
- **The generic entity table.** An EAV (`entity`, `attribute`, `value`) schema "so we never need migrations again". It trades every CHECK constraint, index, and type guarantee for a schema nobody can query or validate. Migrations are the cost of a real model — pay it.
- **`jsonb` as schema escape hatch.** Reaching into a `jsonb` column with `->>` in hot queries or indexing its internals. If a value's parts are queried, constrained, or joined on, they are columns. `jsonb` is for composite Value Objects consumed whole (like `location`).
- **A projection promoted to system of record.** The AGE graph, Elasticsearch index, or MongoDB collection quietly becoming the only place some fact lives. Every non-PostgreSQL store must be rebuildable from PostgreSQL plus the event log — if a rebuild would lose data, the invariant is already broken.
- **The decorative version column.** A `version` column that exists but is not in the `WHERE` clause of updates. Optimistic concurrency lives in the compare-and-swap, not the column; without the predicate it is a row counter.
- **Shared schema across Bounded Contexts.** Two services joining each other's tables "because they're in the same PostgreSQL anyway". That is the shared-database monolith with extra steps; contexts integrate through events and APIs, never through each other's tables.
- **Speculative indexing.** Adding indexes for queries nobody has written. Each index taxes every write and vacuums; an index that cannot name the Read Model or Command it serves is removed.

---

## Output Format

```markdown
---
name: data-model-design
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: data-architect
---

# Data Model Design

## Aggregate → Table Mapping
| Aggregate | Root table | Child tables | Store |
|---|---|---|---|

## Relational Schemas
[CREATE TABLE per Aggregate, with constraints and indexes]

## Graph Model (Apache AGE)
| Vertex label | Properties | Source of truth |
|---|---|---|
| Edge label | From → To | Meaning |

## Polyglot Persistence Decisions
| Store | Data | Justification (ADR ref) |
|---|---|---|

## Indexing Plan
| Table | Index | Query it serves |
|---|---|---|
```
