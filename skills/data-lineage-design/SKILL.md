---
name: data-lineage-design
description: >
  Teaches the data-architect to design data lineage — the lineage granularity
  decision (dataset vs table vs column/field level), the capture mechanism (static
  SQL parsing vs runtime emission vs OpenLineage events from pipelines), and lineage
  uses (impact analysis for a schema change, root-cause for a data-quality incident,
  and compliance/audit evidence of data provenance). Grounded in DAMA-DMBOK. Used
  during Design so every dataset can trace where its data came from and what depends
  on it.
version: 2.0.0
phase: design
owner: data-architect
created: 2026-06-25
related: [data-pipeline-design, data-pipeline-implementation, canonical-data-model, data-classification, privacy-design, compliance-verification, data-retention-policy, glossary-management]
tags: [design, data-governance, lineage, openlineage, impact-analysis, provenance, compliance]
produces: data-lineage-design
domain: data
status: stable
---

# Data Lineage Design

## Purpose

Data lineage is the recorded answer to: *where did this data come from, what was done to it, and where did it go?* DAMA-DMBOK classes lineage as **technical metadata** — the structural record of what produced what — governed as an asset in its own right. In a compliance product it is not a nice-to-have but the **evidence**: when the system reports "this data source has a SOC 2 gap," lineage is the traceable chain back to the specific file, the extracted entity, and the rule evaluation that produced the finding.

A lineage design makes three decisions, in order:

1. **Granularity** — dataset, table, or column/field level, chosen per flow against cost.
2. **Capture mechanism** — how the edge is recorded: static SQL parse, runtime emission, or OpenLineage events.
3. **Uses it must serve** — impact analysis, root-cause, and compliance provenance. If a use can't be answered, capture is incomplete.

---

## Decision 1 — Granularity

Lineage granularity is a cost/value tradeoff, not a "more is better" axis. Finer lineage answers finer questions but multiplies both capture and storage cost. Pick the *coarsest* level that answers the questions a given flow must serve.

| Level | Tracks | Answers | Cost |
|---|---|---|---|
| **Dataset** | Which asset/dataset produced which asset/dataset | "This report was built from these 4 sources" | Low — one edge per run |
| **Table** | Which relation fed which relation | "`extracted_entities` feeds `estate_graph`" | Low–moderate |
| **Column / field** | Which input field produced which output field/value | "This `Person.primary_email` came from the identity provider, not the document" | High — edges multiply by column count |

The first product needs **both ends**: dataset-level for the pipeline and reports (cheap, sufficient), and column/field-level *only* on the canonical model's Golden Record survivorship path, where every surviving attribute must trace to its contributing source field (see `canonical-data-model`). Column-level everywhere is the classic over-capture anti-pattern. The cost math, the "worth it / not worth it" test per level, and the field-level survivorship case: **`references/granularity-and-capture.md`**.

---

## Decision 2 — Capture Mechanism

There are three ways to record a lineage edge. They differ in *when* the edge is known and how trustworthy it is as evidence.

| Mechanism | When derived | Trust | Fits |
|---|---|---|---|
| **Static SQL parsing** | Before/without running — parse the transform's SQL for source→target columns | Design-time hypothesis; misses runtime branches | dbt-style declarative SQL models; documentation |
| **Runtime emission** | As the stage executes — the code that writes the output writes the edge | High — records what actually happened | This repo's choreographed stage workers |
| **OpenLineage events** | Standardized run events (job/run/dataset) emitted by the pipeline | High + portable | Interop with external lineage/catalog tools |

This repo captures lineage by **runtime emission**, written in the **same PostgreSQL transaction** as the state change it describes and the Transactional Outbox row that announces it — so lineage can never disagree with committed reality (see `data-pipeline-implementation`). An OpenLineage-format export is a *projection from* the stored edges, never the primary capture path. The full OpenLineage run/job/dataset event model (including the dataset facet that carries field-level mappings), the transactional capture SQL, idempotent at-least-once handling, and the Apache AGE graph projection: **`references/granularity-and-capture.md`**.

Do **not** emit lineage asynchronously to a separate collector outside the stage's transaction — any gap between "output committed" and "lineage recorded" is a window where derived data exists with no provenance, and collector downtime makes that window hours wide.

---

## Decision 3 — The Uses It Must Serve

A lineage design is validated against the real questions the business will ask. Three uses dominate; each is a traversal direction over the lineage graph.

| Use | Direction | Question |
|---|---|---|
| **Impact analysis** | Forward (input → outputs) | "If we re-scan source X / change this column, what downstream reports go stale?" |
| **Root-cause** | Backward (output → inputs) | "This finding looks wrong — what run and what source produced it?" |
| **Compliance / provenance evidence** | Backward + tenant scope | "What is this SOC 2 finding based on?" / "Where did this person's data end up?" (right-to-erasure) |

Lineage must therefore be indexed for **both** directions — provenance (backward) and impact (forward). Compliance provenance also carries `data-classification` tags along the edges (so a Restricted source's derivatives stay Restricted) and feeds the evidence chain in `compliance-verification`. The five canonical lineage questions, the erasure/impact traversals, tag propagation, and a full worked example over the DataAsset → entity → finding flow: **`references/lineage-uses.md`**.

---

## Key Principles

Lineage records are compliance evidence, so they are held to evidence-grade rules:

- **Captured, not reconstructed.** Lineage inferred after the fact from logs and timestamps is a hypothesis, not evidence. Emit it at derivation time.
- **Append-only.** Lineage is historical record; a wrong derivation is superseded by a new run's edges, never rewritten. Otherwise a past point-in-time state is unreconstructable.
- **Tenant-scoped.** Lineage never crosses tenants (per-tenant physical isolation).
- **Idempotent.** The pipeline is at-least-once; edge inserts dedupe on a natural key so redelivery mints no duplicate edges.
- **Privacy-respecting.** Records *derivation references*, not the raw sensitive content that was derived — the input file's content is transient (`privacy-design`, `data-classification`).
- **Retention-aligned.** Lineage lives exactly as long as the longest-retained artifact it describes, and is purged with it (`data-retention-policy`).

---

## Anti-Patterns

- **Archaeology lineage.** Reconstructing provenance after the fact from logs and guesswork — a hypothesis an auditor will treat as such.
- **The async collector.** Emitting lineage outside the stage's transaction; the gap is a no-provenance window.
- **Raw values in the edge.** Copying the derived sensitive content ("for context") turns `lineage_edges` into another Restricted store to protect and crypto-shred.
- **Field-level everywhere.** Column-level lineage captured for every stage because it's "more complete" — expensive; reserve it for where a question (Golden Record survivorship) demands it.
- **Mutable lineage.** Updating edges in place instead of superseding them with a new run's edges.
- **Orphaned retention.** Purging lineage on its own schedule, detached from the artifacts it is evidence for.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Right granularity per flow | Dataset for pipeline; column-level only on Golden Record | Column-level everywhere, or too coarse where field-level is needed |
| Captured transactionally | Lineage written with the output it describes | Reconstructed / async-collected after the fact |
| Bidirectional | Indexed for both provenance and impact | Queryable one direction only |
| Answers the key questions | All five canonical questions answerable | A required question cannot be answered |
| Privacy-respecting | Derivation references, not raw content | Raw Restricted values copied in |
| Append-only & tenant-scoped | Immutable, tenant-isolated, time-stamped | Mutable or cross-tenant |
| Idempotent capture | Edge inserts dedupe on the natural key | Redelivery duplicates edges |
| Retention-aligned | Retained as long as the artifact it describes | Purged early or orphaned |

---

## Output Format

```markdown
---
name: data-lineage-design
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

## Capture Points
| Pipeline stage | Input dataset(s) | Output dataset(s) | Mechanism | Field-level? |
|---|---|---|---|---|

## Storage Model
[lineage_edges schema + indexes; AGE projection if used]

## Lineage Questions Coverage
| Question | Direction | Covered? |
|---|---|---|
```

---

## References

- **`references/granularity-and-capture.md`** — dataset vs table vs column-level (cost math and the worth-it test per level); the three capture mechanisms in depth (static SQL parse-time, runtime emission tied to the stage transaction, the OpenLineage run/job/dataset event model and its field-level facet); the `lineage_edges` schema, idempotent at-least-once capture, and the replayable Apache AGE graph projection.
- **`references/lineage-uses.md`** — impact analysis, root-cause for a data-quality incident, and compliance/audit provenance (the five canonical lineage questions, right-to-erasure traversal, `data-classification` tag propagation along edges, and a full worked example over the DataAsset → entity → finding flow).
