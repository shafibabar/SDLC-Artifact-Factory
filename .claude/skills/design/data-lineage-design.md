# Skill: design/data-lineage-design

## Purpose
Produce the Data Lineage Design — how the product tracks and represents the provenance of every entity extracted from customer files. Shows the chain: source storage location → file → extracted entity → golden record → compliance finding. This is the graph that powers the lineage visualisation and compliance evidence.

## Inputs
- `artifacts/design/domain/events.md`
- `artifacts/design/bounded-contexts.md`
- `artifacts/design/data/data-architecture.md`
- `sdlc-config.json` (graph_database)

## Output
**File:** `artifacts/design/data/data-lineage-design.md`
**Registers in manifest:** yes

## Lineage Rules (enforced)
- Every entity extraction event must record its provenance (source file → source location).
- Lineage is immutable — it records what happened, not what the current state is. Past lineage is never modified.
- The lineage graph is queryable via graph traversal (Cypher via Apache AGE or Neo4j).
- Lineage is stored in the same tenant-isolated infrastructure as other data.
- Lineage chain must be reconstructable from domain events alone (event sourcing enables this).

## Artifact Template

```markdown
# Data Lineage Design

**Product:** {product_name}
**Phase:** Design
**Artifact:** Data Lineage Design
**Version:** 1.0
**Date:** {date}
**Graph database:** {from sdlc-config: apache-age | neo4j}
**Status:** Draft

---

## Lineage Chain

```
StorageLocation
      │ (contains)
      ▼
 DiscoveredFile
      │ (processed by)
      ▼
FileProcessingJob ──── (extracted from) ────► ExtractedEntity
                                                     │ (resolved to)
                                                     ▼
                                               GoldenRecord
                                                     │ (evaluated by)
                                                     ▼
                                               ComplianceFinding
                                                     │ (generates)
                                                     ▼
                                               AuditEntry
```

---

## Graph Model (Apache AGE / Neo4j)

### Nodes

| Node label | Properties | Description |
|-----------|-----------|-------------|
| `StorageLocation` | `location_id`, `tenant_id`, `platform`, `path` | Registered storage source |
| `File` | `file_id`, `tenant_id`, `path`, `checksum`, `mime_type`, `discovered_at` | File detected at a location |
| `ExtractionJob` | `job_id`, `tenant_id`, `model_version`, `processed_at` | Processing run |
| `Entity` | `entity_id`, `tenant_id`, `entity_type`, `confidence_score` | Extracted entity instance (value stored in encrypted PostgreSQL; not in graph) |
| `GoldenRecord` | `golden_id`, `tenant_id`, `entity_type`, `instance_count` | Deduplicated master record |
| `ComplianceFinding` | `finding_id`, `tenant_id`, `severity`, `framework`, `rule_id`, `status` | Compliance violation |

### Edges

| Edge label | From → To | Properties |
|-----------|-----------|-----------|
| `LOCATED_AT` | `File → StorageLocation` | `detected_at` |
| `EXTRACTED_FROM` | `Entity → File` | `extracted_at`, `position` (page/char offset) |
| `EXTRACTED_BY` | `Entity → ExtractionJob` | |
| `RESOLVED_TO` | `Entity → GoldenRecord` | `resolved_at`, `resolution_method` (auto/manual) |
| `TRIGGERED_FINDING` | `GoldenRecord → ComplianceFinding` | `evaluated_at` |
| `MODIFIES_LOCATION` | `File → StorageLocation` | `modification_type` (created/modified/deleted) |

---

## Cypher Query Examples

### "Where does this entity appear?"
```cypher
MATCH (e:Entity {entity_id: $entity_id})-[:EXTRACTED_FROM]->(f:File)-[:LOCATED_AT]->(l:StorageLocation)
WHERE e.tenant_id = $tenant_id
RETURN l.path, f.path, f.discovered_at
ORDER BY f.discovered_at DESC
```

### "What findings are linked to entities from this file?"
```cypher
MATCH (f:File {file_id: $file_id, tenant_id: $tenant_id})
      <-[:EXTRACTED_FROM]-(e:Entity)
      -[:RESOLVED_TO]->(g:GoldenRecord)
      -[:TRIGGERED_FINDING]->(finding:ComplianceFinding)
WHERE finding.status = 'OPEN'
RETURN finding.finding_id, finding.severity, finding.framework, g.entity_type
```

### "Full provenance for a finding"
```cypher
MATCH path = (l:StorageLocation)<-[:LOCATED_AT]-(f:File)<-[:EXTRACTED_FROM]-(e:Entity)-[:RESOLVED_TO]->(g:GoldenRecord)-[:TRIGGERED_FINDING]->(finding:ComplianceFinding {finding_id: $finding_id, tenant_id: $tenant_id})
RETURN path
```

---

## Lineage Graph Build Process

Lineage nodes and edges are created by consuming domain events:

| Domain event | Lineage action |
|-------------|---------------|
| `FileDiscovered` | Create/update `File` node; create `LOCATED_AT` edge |
| `FileProcessed` | Create `ExtractionJob` node |
| `EntitiesExtracted` | Create `Entity` nodes; create `EXTRACTED_FROM` + `EXTRACTED_BY` edges |
| `GoldenRecordCreated` | Create `GoldenRecord` node; create `RESOLVED_TO` edge |
| `GoldenRecordUpdated` | Update `GoldenRecord` node; add new `RESOLVED_TO` edge for new entity |
| `FindingCreated` | Create `ComplianceFinding` node; create `TRIGGERED_FINDING` edge |

---

## Privacy Considerations for the Lineage Graph

- **Entity values are NOT stored in the graph** — only `entity_id` (UUID) and `entity_type`
- The actual entity value (e.g. a person's name) is stored in the Entity Domain's encrypted PostgreSQL column
- Graph queries return references; callers must separately fetch the value from the Entity API (which checks ABAC and logs the access)
- This separation means a graph database breach does not expose PII values
```

## Quality Checks
- [ ] Full lineage chain is documented (storage → file → entity → golden record → finding)
- [ ] Graph node and edge model is specified
- [ ] Cypher query examples cover the primary use cases (provenance, finding linkage)
- [ ] Entity values are NOT stored in the graph (only references)
- [ ] Lineage build process maps domain events to graph mutations
- [ ] Privacy considerations for the graph are addressed
