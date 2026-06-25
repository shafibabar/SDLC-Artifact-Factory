---
name: data-lineage-design
description: >
  Teaches how to design data lineage — the recorded provenance of every piece of
  derived data, tracing it backward to its sources and forward to its consumers.
  Covers dataset-level and field-level lineage, the OpenLineage model (run / job /
  dataset), how lineage is captured at each pipeline stage, and how lineage answers
  compliance, audit, and right-to-erasure questions. Lineage is what lets the system
  prove where a compliance finding came from. Produced by the data-architect during
  the Design phase.
version: 1.0.0
phase: design
owner: data-architect
tags: [design, data-architecture, lineage, provenance, openlineage, audit, compliance]
---

# Data Lineage Design

## Purpose

Data lineage is the recorded answer to: *where did this data come from, what was done to it, and where did it go?* In a compliance product, lineage is not a nice-to-have — it is the evidence. When the system reports "this data source has a SOC 2 gap," an auditor will ask "based on what?" Lineage is the traceable chain back to the specific file, the specific extracted entity, and the specific rule evaluation that produced the finding.

Lineage also makes two hard compliance operations possible: **right-to-erasure** (find every derived artifact originating from a person's data) and **impact analysis** (if a source was misclassified, find everything downstream that must be re-evaluated).

---

## Two Granularities

| Granularity | Tracks | Answers |
|---|---|---|
| **Dataset-level** | Which dataset/asset produced which dataset/asset | "This compliance report was built from these 4 data sources" |
| **Field-level** | Which input field produced which output field/value | "This `Person.primary_email` came from the identity provider, not the extracted document" |

The first product needs **both**: dataset-level for the pipeline and reports, field-level for the canonical model's Golden Record survivorship (every surviving attribute traces to the contributing source field — see `canonical-data-model`).

---

## The OpenLineage Model

Use the OpenLineage standard (open spec, vendor-neutral, frugal — no proprietary lineage product). It models lineage with three core concepts:

| Concept | Meaning | First-product example |
|---|---|---|
| **Dataset** | A named set of data | `data_assets`, `extracted_entities`, the `estate_graph`, a `compliance_report` |
| **Job** | A process that reads datasets and writes datasets | The Entity Extraction stage, the Compliance Rule Engine |
| **Run** | A single execution of a job, with inputs, outputs, and status | One extraction run over one file |

A Run emits lineage events: it declares its input datasets, its output datasets, and (for field-level) the column mapping between them. Stitched together, runs form the lineage graph.

```
Run(job=EntityExtraction, run_id=R1)
  inputs:  [Dataset(data_assets, asset=A1)]
  outputs: [Dataset(extracted_entities, produced=[E1,E2,E3])]
  facets:  columnLineage { E*.entity_type ← derived_from A1.file_content (transient) }
```

Note the input file content is **transient** — lineage records that an entity was *derived from* file A1, without storing A1's content (privacy constraint from `data-classification` / `privacy-design`).

---

## Capturing Lineage at Each Stage

Lineage is emitted by the pipeline, not reconstructed after the fact. Each stage (from `data-pipeline-design`) emits a lineage record as part of its work — in the same transaction as its output, so lineage can never disagree with reality.

```sql
CREATE TABLE lineage_edges (
    id              UUID PRIMARY KEY,
    tenant_id       UUID NOT NULL,
    job_name        TEXT NOT NULL,          -- e.g. 'entity-extraction'
    run_id          UUID NOT NULL,
    input_dataset   TEXT NOT NULL,          -- e.g. 'data_assets'
    input_ref       UUID NOT NULL,          -- e.g. the data_asset id
    output_dataset  TEXT NOT NULL,          -- e.g. 'extracted_entities'
    output_ref      UUID NOT NULL,          -- e.g. the entity id
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_lineage_output ON lineage_edges (tenant_id, output_dataset, output_ref);
CREATE INDEX idx_lineage_input  ON lineage_edges (tenant_id, input_dataset, input_ref);
```

Two indexes because lineage is traversed in both directions:
- **Backward (provenance):** given an output, find its inputs → "what produced this finding?"
- **Forward (impact):** given an input, find its outputs → "what is affected if this source changes?"

The lineage graph can also be projected into Apache AGE (`DERIVED_FROM` edges) when multi-hop traversal queries are common.

---

## The Lineage Questions It Must Answer

A lineage design is validated against the real questions the business will ask:

| Question | Traversal | Used by |
|---|---|---|
| "What is this compliance finding based on?" | Backward from finding → rule run → entities → asset → source | Audit, the customer-facing report |
| "If we re-scan source X, what reports become stale?" | Forward from source → all downstream outputs | Operations, cache invalidation |
| "Where did this person's data end up?" | Forward from a Person's contributing records → all derived artifacts | Right-to-erasure (`data-retention-policy`) |
| "Which surviving attribute came from which source?" | Field-level backward on a Golden Record | MDM trust, dispute resolution |
| "Was this value derived from a low-confidence extraction?" | Backward to the extraction run's confidence facet | Data quality |

If the design cannot answer one of these, the lineage capture is incomplete.

---

## Lineage and Compliance Evidence

Lineage records are part of the compliance evidence chain (see security `compliance-verification`). They are:
- **Tenant-scoped** — lineage never crosses tenants.
- **Append-only** — lineage is a historical record; it is never updated or deleted (except by the retention purge, which is itself audited).
- **Time-stamped** — every edge records when the derivation happened, so the state of the world at evidence time is reconstructable.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Both granularities where needed | Dataset-level for pipeline; field-level for Golden Record | Only coarse lineage where field-level is required |
| Captured transactionally | Lineage written with the output it describes | Lineage reconstructed/guessed after the fact |
| Bidirectional traversal | Indexed for both provenance and impact queries | Lineage queryable only one direction |
| Answers the key questions | All standard lineage questions are answerable | A required question cannot be answered |
| Privacy-respecting | Records derivation references, not raw sensitive content | Raw sensitive values copied into lineage |
| Append-only & tenant-scoped | Immutable, tenant-isolated, time-stamped | Mutable or cross-tenant lineage |

---

## Output Format

```markdown
---
artifact: data-lineage-design
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: data-architect
---

# Data Lineage Design

## Datasets & Jobs (OpenLineage)
| Dataset | Produced by job | Granularity |
|---|---|---|

## Lineage Capture Points
| Pipeline stage | Input dataset(s) | Output dataset(s) | Field-level? |
|---|---|---|---|

## Storage Model
[lineage_edges schema + indexes; AGE projection if used]

## Lineage Questions Coverage
| Question | Traversal | Covered? |
|---|---|---|
```
