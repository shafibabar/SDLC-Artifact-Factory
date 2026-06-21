# Skill: design/data-architecture

## Purpose
Produce the Data Architecture document — the master design for how data is stored, partitioned, accessed, and governed across all bounded contexts. Establishes storage technology assignments, data ownership, and cross-cutting data concerns.

## Inputs
- `artifacts/design/bounded-contexts.md`
- `artifacts/design/domain/aggregates/` (all)
- `artifacts/design/domain/read-models/` (all)
- `sdlc-config.json`

## Output
**File:** `artifacts/design/data/data-architecture.md`
**Registers in manifest:** yes

## Data Architecture Rules (enforced)
- Each bounded context owns its own database schema. No cross-BC joins.
- Aggregates live in the write-side (PostgreSQL). Read models may use a different store.
- Apache AGE (graph extension) lives within the PostgreSQL instance for the Entity/Graph Domain — not a separate server in the default config.
- The Audit Domain uses append-only PostgreSQL tables — updates and deletes are prohibited at the application layer (enforced via row-level policy if available).
- Elasticsearch is the secondary read store for full-text search and analytics — it is never the source of truth.
- MongoDB is not enabled unless `mongodb_hybrid: true` in sdlc-config.json — in which case it is assigned to document-heavy read models only.

## Artifact Template

```markdown
# Data Architecture

**Product:** {product_name}
**Phase:** Design
**Artifact:** Data Architecture
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Storage Technology Assignments

| Bounded Context | Write-side store | Read-side store | Graph store | Notes |
|----------------|-----------------|----------------|------------|-------|
| File Domain | PostgreSQL (`file_schema`) | PostgreSQL (read models) + Elasticsearch (search) | — | |
| Entity Domain | PostgreSQL (`entity_schema`) | PostgreSQL (read models) | Apache AGE (`entity_graph`) | AGE is a PostgreSQL extension — same cluster |
| Compliance Domain | PostgreSQL (`compliance_schema`) | PostgreSQL (read models) + Elasticsearch (findings search) | — | |
| Graph Domain | Apache AGE (`graph_schema`) | PostgreSQL (read models) | Apache AGE | Lineage graph; traversal queries via AGE/Cypher |
| Identity Domain | PostgreSQL (`identity_schema`) | PostgreSQL | — | |
| Alert Domain | PostgreSQL (`alert_schema`) | PostgreSQL | — | |
| Audit Domain | PostgreSQL (`audit_schema`) | Elasticsearch (audit log search) | — | Append-only; no UPDATE/DELETE |

---

## Database Instance Strategy

### Physical Multi-Tenancy (default)
Each tenant gets a dedicated PostgreSQL cluster. No shared database between tenants.

```
Tenant A: postgres-a.{product}.internal
Tenant B: postgres-b.{product}.internal
```

Each PostgreSQL cluster hosts all bounded context schemas for that tenant:
```
postgres-{tenant}/
├── file_schema
├── entity_schema
├── compliance_schema
├── graph_schema       # Apache AGE
├── identity_schema
├── alert_schema
└── audit_schema
```

### Apache AGE
Enabled as a PostgreSQL extension on the same cluster. No separate graph database process.
- If `graph_database: neo4j` is selected in sdlc-config.json: Neo4j Community Edition is deployed as a separate container; same data residency rules apply.

---

## Schema Ownership and Migration

- Each bounded context service owns its own schema migrations.
- Migration tool: `golang-migrate/migrate` (file-based, numbered migrations).
- Migration files live in the service repository: `{service-repo}/migrations/`
- Migrations run at service startup (or via CI pre-deploy job — configurable).
- Cross-schema foreign keys are **prohibited** — referential integrity is enforced at the application layer via domain events.

---

## Data Isolation Guarantees

| Isolation layer | Mechanism |
|----------------|-----------|
| Tenant-level | Dedicated PostgreSQL cluster per tenant |
| BC-level | Separate schema per bounded context |
| Row-level | `tenant_id` column on all tables + PostgreSQL RLS (defence in depth) |
| Application-level | All queries include `WHERE tenant_id = $1` enforced by repository layer |

---

## Backup and Recovery Strategy

| Tier | RPO | RTO | Mechanism |
|------|-----|-----|-----------|
| PostgreSQL (all BCs) | 1 hour | 4 hours | Continuous WAL archiving to customer-controlled object store |
| Elasticsearch | 24 hours | 8 hours | Snapshot to customer-controlled object store |
| Redpanda | 7 days retention | N/A (replay) | Topic retention; no separate backup required |
| Apache AGE | 1 hour | 4 hours | Included in PostgreSQL WAL backup |

---

## Elasticsearch Index Strategy

| Index | Source BC | Purpose | Refresh interval |
|-------|----------|---------|-----------------|
| `files-{tenant}` | File Domain | File metadata full-text search | 1s |
| `findings-{tenant}` | Compliance Domain | Finding search and analytics | 1s |
| `audit-{tenant}` | Audit Domain | Audit log search | 5s |
| `entities-{tenant}` | Entity Domain | Entity search (name, type, location) | 1s |

Index names are tenant-scoped: no cross-tenant index queries.
```

## Quality Checks
- [ ] Every bounded context has a designated write-side and read-side store
- [ ] No cross-BC database joins are present
- [ ] Audit domain tables are marked append-only
- [ ] Physical multi-tenancy isolation strategy is documented
- [ ] Migration ownership is assigned per bounded context
- [ ] RPO/RTO targets are defined and connected to NFR requirements
