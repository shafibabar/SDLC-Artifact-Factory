# PostgreSQL Physical DDL Patterns

Reference for the **physical** pass: PostgreSQL data-type choices, the tenant/isolation
columns, optimistic-concurrency DDL, indexing strategy, partitioning for large tables, JSONB
usage, the Apache AGE graph model, polyglot store selection, and the full Output Format
template. Grounded in this repo's stack: Go + chi + pgx + PostgreSQL, per-tenant **physical**
isolation, Apache AGE, Elasticsearch, Redpanda. For the logical model see
`normalization-oltp.md`; for the dimensional shape see `dimensional-oltp-olap.md`.

---

## 1. PostgreSQL Type Selection

| Domain concept | PostgreSQL type | Why |
|---|---|---|
| Identity (Aggregate Root, child) | `UUID` | Application-assigned; stable across stores; no serial leakage |
| Timestamps | `TIMESTAMPTZ` | Always timezone-aware; store UTC, never naive `TIMESTAMP` |
| Money / exact decimals | `NUMERIC(p,s)` | Never `float` — exact arithmetic |
| Bounded scores | `NUMERIC(4,3)` with `CHECK` | e.g. confidence `0.000`–`1.000` |
| Enum-like value | `TEXT` + `CHECK ... IN (...)` | Cheaper to evolve than a native `ENUM` type (adding a value to an `ENUM` needs `ALTER TYPE`) |
| Composite Value Object queried whole | `JSONB` | See §5 — only when never queried by its parts |
| Optimistic-concurrency counter | `BIGINT` | The `version` column |
| Free text needing search | `TEXT` (+ project to Elasticsearch) | Not PG FTS for the primary search surface |

Prefer `TEXT`+`CHECK` over native `ENUM` for enum-like columns: the classification set
(`Public/Internal/Confidential/Restricted`) evolves via a cheap constraint change rather than
a type migration.

---

## 2. The Tenant / Isolation Columns

The first product uses **physical multi-tenancy** (separate namespace/deployment per tenant —
see `multi-tenancy-design`). Even so, every tenant-scoped table carries an explicit
`tenant_id` — defence in depth:

- Physical isolation prevents cross-tenant routing at the infrastructure layer.
- The `tenant_id` column + parameterised query filter is the application-layer backstop (see
  security `access-control-model`) — applied uniformly to **every** tenant-scoped statement,
  including ones where `id` alone is globally unique.
- Every index on a tenant-scoped table **leads with `tenant_id`**.

### Composite-FK tenant hardening

A single-column FK cannot stop a child row pointing at a parent in *another* tenant if
application code passes a wrong id. A composite FK makes that state unrepresentable:

```sql
ALTER TABLE data_assets ADD CONSTRAINT data_assets_id_tenant_uq UNIQUE (id, tenant_id);

-- child then declares, in place of the single-column FK:
--   FOREIGN KEY (data_asset_id, tenant_id)
--     REFERENCES data_assets (id, tenant_id) ON DELETE CASCADE
```

---

## 3. Optimistic Concurrency DDL

Every Aggregate Root carries a `version` column, and writes use a compare-and-swap in the
`WHERE` — the one-writer-per-Aggregate rule without pessimistic locks:

```sql
UPDATE data_assets
   SET sensitivity_level = $1, version = version + 1, updated_at = now()
 WHERE id = $2 AND tenant_id = $3 AND version = $4
   AND deleted_at IS NULL;
-- 0 rows affected → concurrent modification OR soft-deleted → conflict → retry/fail
```

Two details make it trustworthy:

- **`tenant_id` stays in the `WHERE`** even though `id` is unique — the uniform tenant
  backstop, not an optimisation.
- **`AND deleted_at IS NULL`** prevents resurrection: a command racing a soft delete cannot
  mutate a "deleted" Aggregate. Zero rows affected is a single conflict signal the handler
  treats uniformly whatever the cause.

A `version` column that is *not* in the update `WHERE` is a decorative row counter, not
concurrency control.

---

## 4. Indexing Strategy

| Index need | Approach |
|---|---|
| Tenant-scoped lookups | Composite index **leading with `tenant_id`** |
| Active-record queries | **Partial** index `WHERE deleted_at IS NULL` |
| FK joins within an Aggregate | Index the child table's FK column (also serves `ON DELETE CASCADE`) |
| Time-range queries (audit, scans) | B-tree on `(tenant_id, occurred_at)`; **BRIN** for append-only large tables |
| Composite VO queried whole | GIN on the `jsonb` column **only if** whole-document containment queries exist |
| Full text | Do **not** use PostgreSQL FTS for the primary surface — project to Elasticsearch |

```sql
CREATE INDEX idx_data_assets_tenant_source ON data_assets (tenant_id, source_id);
CREATE INDEX idx_data_assets_tenant_sensitivity ON data_assets (tenant_id, sensitivity_level)
    WHERE deleted_at IS NULL;                       -- partial: active assets only
CREATE INDEX idx_extracted_entities_asset ON extracted_entities (data_asset_id);
```

Every index must justify its existence by naming the Read Model or Command it speeds.
Speculative indexes are removed — each taxes every write and every vacuum. **BRIN** (Block
Range INdex) is the frugal choice for large append-only, naturally time-ordered tables (audit
log, scan events): a fraction of a B-tree's size, ideal when rows are physically clustered by
insertion time.

---

## 5. JSONB Usage — the Discipline

`JSONB` is for a **composite Value Object consumed whole** — like `location` (page + offset)
that is read back as a unit and never filtered by its parts:

```sql
location JSONB NOT NULL   -- {"page": 3, "offset": 512}; read whole, never `WHERE location->>'page'`
```

Rules:

- If a value's parts are **queried, constrained, joined, or ordered on**, they are
  **columns**, not JSONB keys. Reaching into `->>` in hot queries is the anti-pattern.
- JSONB is **not** an EAV / schema escape hatch. A generic `(entity, attribute, value)` table
  trades every CHECK, index, and type guarantee for a schema nobody can query — migrations are
  the cost of a real model; pay it.
- Index JSONB with GIN only for genuine whole-document containment (`@>`) needs.

---

## 6. Partitioning for Large Tables

When a table grows unbounded and append-only — the audit log, scan-event history, extracted
entities across the whole estate — use **declarative range partitioning**, typically by time,
so old partitions can be dropped cheaply (also serving `data-retention-policy` purges) and
queries prune to the relevant partition:

```sql
CREATE TABLE audit_log (
    id          UUID NOT NULL,
    tenant_id   UUID NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    action      TEXT NOT NULL,
    PRIMARY KEY (id, occurred_at)                    -- partition key must be in the PK
) PARTITION BY RANGE (occurred_at);

CREATE TABLE audit_log_2026_q3 PARTITION OF audit_log
    FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
```

Note the partition key (`occurred_at`) must be part of the primary key. Pair partitioning with
a BRIN index per §4. Do not partition small tables — the planning overhead outweighs the gain.

---

## 7. The Apache AGE Graph Model

The estate relationship graph lives in **Apache AGE**, a PostgreSQL extension providing
openCypher queries — one fewer system to operate than a separate Neo4j (frugal by default).

| Element | Rule |
|---|---|
| Vertex (node) | One label per concept that participates in relationships: `DataAsset`, `Entity`, `DataSource`, `Person` |
| Edge (relationship) | Named with a Ubiquitous-Language verb: `CONTAINS`, `REFERENCES`, `OWNED_BY`, `DERIVED_FROM` |
| Vertex properties | Minimal — an `id` referencing the relational row, plus `tenant_id`. Graph holds structure; relational store holds detail. |
| Tenant isolation | Every vertex carries `tenant_id`; every query filters by it. Paths never cross tenants. |

```cypher
SELECT * FROM cypher('estate_graph', $$
    MATCH (a:DataAsset {tenant_id: $tenant})-[:CONTAINS]->(e:Entity)-[:REFERENCES]->(p:Person)
    WHERE a.id = $asset_id
    RETURN p.id, count(e) AS mentions
$$) AS (person_id agtype, mentions agtype);
```

The relational store is the **system of record**; the graph is a **projection** kept current
by a Projector consuming Domain Events (`EntityExtracted`, `AssetClassified`) and replayable
from the event log — see `read-model-design` and `data-pipeline-design`.

---

## 8. Polyglot Persistence — When to Use What

Default to PostgreSQL. Add a second store only when PostgreSQL is the wrong tool *and* the
operating cost is justified — and document it as an ADR.

| Store | Use when | Do not use when | First-product use |
|---|---|---|---|
| **PostgreSQL + pgx** | Transactional Aggregates, outbox, audit, config — anything needing ACID | (the default) | All Aggregate state, outbox, audit |
| **Apache AGE** (in PG) | Relationship traversal (paths, neighbourhoods) | Simple FK lookups | The estate relationship graph |
| **MongoDB** | Highly variable schema unknown ahead of time | Anything transactional/relational | Raw extraction output / crawl metadata — optional, behind a config flag |
| **Elasticsearch** | Full-text search, ranking, flexible alert querying | As a system of record | Document full-text index, compliance alert search |

**Rule:** a non-PostgreSQL store is **never** a system of record for an Aggregate — always a
projection or derived index, rebuildable from PostgreSQL + the event log. If a rebuild would
lose data, the invariant is already broken. (Kleppmann's "unbundling": specialized stores each
kept in sync as derived data from one source of truth.)

---

## 9. Output Format (the artifact template)

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

## Conceptual Model (CDM)
[ER-Entity names + relationship sentences, cardinality/optionality, definitions]

## Aggregate → Table Mapping
| Aggregate | Root table | Child tables | Store |
|---|---|---|---|

## Relational Schemas (OLTP, normalized)
[CREATE TABLE per Aggregate, with constraints and indexes]

## Dimensional Marts (OLAP, where warranted)
| Mart | Grain (one sentence) | Fact type | Conformed dimensions | SCD types |
|---|---|---|---|---|

## Graph Model (Apache AGE)
| Vertex label | Properties | Source of truth |
| Edge label | From → To | Meaning |

## Polyglot Persistence Decisions
| Store | Data | Justification (ADR ref) |
|---|---|---|

## Indexing Plan
| Table | Index | Query it serves |
|---|---|---|
```

---

## Checklist

- [ ] Types chosen deliberately (UUID / TIMESTAMPTZ / NUMERIC / TEXT+CHECK); no `float` for exact values.
- [ ] Every tenant-scoped table has `tenant_id`; every index leads with it; composite-FK hardening where a child crosses tenants.
- [ ] Every Aggregate Root has a `version` column used in the update `WHERE`, with `deleted_at IS NULL`.
- [ ] Each index names the Read Model/Command it serves; BRIN for large append-only tables.
- [ ] JSONB only for whole-consumed Value Objects; no EAV, no `->>` in hot queries.
- [ ] Large append-only tables range-partitioned by time; small tables not partitioned.
- [ ] Graph and any non-PostgreSQL store are projections with an ADR — never a system of record.
