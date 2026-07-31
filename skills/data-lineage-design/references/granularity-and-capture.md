# Granularity & Capture — Reference

Depth behind the two headline decisions in `SKILL.md`: **how fine** to record lineage
(dataset / table / column-level, against cost) and **how** the edge is recorded (static
SQL parsing / runtime emission / OpenLineage events), plus how it is stored. Grounded in
DAMA-DMBOK's technical-metadata framing and this repo's Go + `pgx` + PostgreSQL +
Redpanda + Apache AGE stack.

---

## 1. Granularity — the cost/value tradeoff

Lineage granularity is an economic decision. Each level answers a strictly finer class
of question than the one above it, and each costs strictly more to capture, store, and
query. The rule is: **choose the coarsest level that answers the questions the flow must
serve**, and let finer levels be the exception you justify per flow.

### The three levels

| Level | Grain of an edge | Question it uniquely answers | Where it belongs in this product |
|---|---|---|---|
| **Dataset** | asset/dataset → asset/dataset | "This compliance report was built from these four sources" | The whole pipeline; every report |
| **Table** | relation → relation | "`extracted_entities` feeds `estate_graph` and `classification_results`" | Coarse schema-dependency maps between Read Models |
| **Column / field** | source field → output field/value | "This surviving `Person.primary_email` came from the identity provider, not the parsed document" | Golden Record survivorship only |

### The cost math

The number of edges a level produces per run is the multiplier that matters:

- **Dataset-level:** ~1 edge per (input dataset × output dataset) per run. A stage reading
  one dataset and writing one dataset writes **one** edge per run. Cheap, bounded, and
  usually enough.
- **Table-level:** similar order to dataset-level in this product, because most datasets
  map to a small fixed set of tables. Slightly more edges, still bounded by schema size,
  not by data volume.
- **Column-level:** edges multiply by the **fan-in of columns**. A survivorship decision
  over a Golden Record with *N* attributes, each fed by up to *S* candidate source
  records, can produce up to *N × S* edges per record resolved — and it grows with data
  volume, not just schema size. This is why column-level lineage "for completeness"
  everywhere is a real cost, not a rounding error.

### The worth-it test (apply per flow)

Column/field-level lineage is worth its cost only when **all** of the following hold:

1. A required lineage question is genuinely field-specific (it names a *column*, not a
   dataset) — e.g. "which source did this surviving attribute come from?"
2. No coarser level can answer it (dataset-level "the Golden Record came from these three
   sources" does **not** tell you which source won a specific attribute).
3. The flow's fan-in is bounded enough that the edge multiplication is affordable.

In the first product exactly one flow passes this test: **MDM Golden Record
survivorship** (`canonical-data-model`). Every other flow — file discovery, entity
extraction, classification, compliance evaluation, report assembly — is answered at
**dataset-level**. Table-level sits in between as an optional coarse dependency map when
you want "which Read Models depend on which" without per-record edges.

### Worked contrast

Same event, three grains:

```
Dataset-level:   compliance_report R42  DERIVED_FROM  data_asset A1, A2, A3, A4
Table-level:     compliance_reports     DERIVED_FROM  compliance_findings, data_assets
Column-level:    golden_person.primary_email  DERIVED_FROM  idp_record.email   (survived)
                 golden_person.primary_email  NOT_FROM      doc_entity.email   (lost survivorship)
```

Only the third grain can settle an MDM dispute about a single attribute; only the first is
cheap enough to run for every report. Both are correct choices — for different flows.

---

## 2. Capture mechanism — how the edge is recorded

An edge can be derived three ways. The distinction that matters for a *compliance* product
is **evidence trust**: does the edge record what the design *intended* to happen, or what
*actually* happened?

### 2a. Static SQL parsing (parse-time)

Parse a transform's SQL (or a dbt-style model graph) and extract source→target column
references **without executing the pipeline**. Tools in the modern data stack derive
lineage this way from declarative SQL models.

- **Strength:** available before a single row moves; great for documentation and for
  declarative ELT/dbt-style transforms where the SQL *is* the transformation.
- **Weakness:** it is a **design-time hypothesis**. It cannot see runtime-conditional
  branches (a `CASE` that only fires on some rows, a dynamically built query, a code path
  taken only when confidence < threshold). What the parser says *would* happen is not
  proof of what *did* happen — so it is weak as audit evidence.
- **Fit here:** this repo's pipeline is **event-choreographed streaming transformation in
  Go**, not declarative SQL models, so static SQL parsing has little to parse. It is a
  documentation aid at best, never the system of record.

### 2b. Runtime emission (this repo's default)

The stage code that writes the output **also writes the lineage edge, in the same
transaction**. The edge records what the run actually did.

- **Strength:** highest evidence trust — the edge is a fact about a real execution, not a
  prediction. It captures runtime branches, confidence facets, and skipped paths exactly
  as they occurred.
- **Requirement:** it must be **transactional** with the output and the Transactional
  Outbox row (see below), or it isn't trustworthy.
- **Fit here:** matches the choreographed stage workers (`data-pipeline-implementation`)
  one-to-one — every stage already writes its output and its outbox row in one Postgres
  transaction; the lineage edge joins that same transaction.

### 2c. OpenLineage events (the portable standard)

[OpenLineage](https://openlineage.io) is an open, vendor-neutral spec (frugal — no
proprietary lineage product) that models lineage as **run events**. It is orthogonal to
2a/2b: you can *emit* OpenLineage events from a runtime-emission capture. Its value here is
**interoperability** — a standard shape an external catalog or lineage tool can consume.

The model has three core entities:

| Entity | Meaning | First-product example |
|---|---|---|
| **Dataset** | A named set of data | `data_assets`, `extracted_entities`, `estate_graph`, a `compliance_report` |
| **Job** | A process that reads datasets and writes datasets | The Entity Extraction stage; the Compliance Rule Engine |
| **Run** | A single execution of a Job, with inputs, outputs, status | One extraction run over one file |

A **Run** progresses through lifecycle events — `START`, then `RUNNING`, then a terminal
`COMPLETE`, `ABORT`, or `FAIL` — and each event declares the Run's input Datasets, output
Datasets, and optional **facets** (typed metadata attachments). Field-level lineage rides
on a dataset facet named **`columnLineage`**: for each output field it lists the input
fields it was derived from and the transformation type. A minimal shape:

```json
{
  "eventType": "COMPLETE",
  "job":  { "namespace": "estate", "name": "entity-extraction" },
  "run":  { "runId": "R1" },
  "inputs":  [ { "namespace": "estate", "name": "data_assets" } ],
  "outputs": [ {
    "namespace": "estate", "name": "extracted_entities",
    "facets": {
      "columnLineage": {
        "fields": {
          "entity_type": {
            "inputFields": [
              { "namespace": "estate", "name": "data_assets", "field": "file_content" }
            ],
            "transformationType": "INDIRECT",
            "transformationDescription": "derived; source content transient (not stored)"
          }
        }
      }
    }
  } ]
}
```

Note the source `file_content` is **transient** — the `columnLineage` facet records that
`entity_type` was *derived from* it, without the edge ever storing the file content itself
(privacy constraint from `data-classification` / `privacy-design`).

> **In this repo, OpenLineage is a projection, not the capture path.** Edges are captured
> by runtime emission into PostgreSQL first; an OpenLineage-format export is generated
> *from* the stored `lineage_edges` for external tools. Emitting OpenLineage events to a
> remote HTTP collector as the *primary* record is exactly the async-collector trap: when
> the collector is down for an hour, an hour of outputs exist with no provenance.

---

## 3. Storing the lineage graph

### 3a. System of record — relational `lineage_edges` in PostgreSQL

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
    input_field     TEXT,                   -- NULL for dataset/table-level; set for column-level
    output_field    TEXT,                   -- NULL for dataset/table-level; set for column-level
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT lineage_edge_natural_key UNIQUE
        (tenant_id, run_id, input_dataset, input_ref, output_dataset, output_ref,
         input_field, output_field)
);

-- Traversed in both directions, so index both:
CREATE INDEX idx_lineage_output ON lineage_edges (tenant_id, output_dataset, output_ref);
CREATE INDEX idx_lineage_input  ON lineage_edges (tenant_id, input_dataset,  input_ref);
```

- **Column-level is the same table**, with `input_field` / `output_field` populated. They
  are `NULL` for dataset- and table-level edges — one schema serves all three grains.
- **Two indexes**, because lineage is traversed both ways: backward (given an output, find
  inputs → *provenance*) and forward (given an input, find outputs → *impact*).

### 3b. Transactional capture (why it's trustworthy)

The edge is written in the **same transaction** as the output row it describes and the
Transactional Outbox row that announces the output:

```go
func (s *ExtractionStage) persist(ctx context.Context, tx pgx.Tx, out Entity, in AssetRef) error {
    if err := insertEntity(ctx, tx, out); err != nil {
        return err
    }
    // Lineage edge — same tx as the output and the outbox row.
    _, err := tx.Exec(ctx, `
        INSERT INTO lineage_edges
            (id, tenant_id, job_name, run_id, input_dataset, input_ref, output_dataset, output_ref, occurred_at)
        VALUES ($1,$2,'entity-extraction',$3,'data_assets',$4,'extracted_entities',$5, now())
        ON CONFLICT ON CONSTRAINT lineage_edge_natural_key DO NOTHING`,
        uuid.New(), out.TenantID, out.RunID, in.AssetID, out.ID)
    if err != nil {
        return err
    }
    return insertOutbox(ctx, tx, out) // same tx — lineage can never disagree with committed reality
}
```

### 3c. Idempotent at-least-once capture

The pipeline is **at-least-once**: on Redpanda redelivery a stage may re-execute. Lineage
capture must be exactly as idempotent as the stage — the natural-key `UNIQUE` constraint
plus `ON CONFLICT ... DO NOTHING` means a redelivered run re-inserts the identical edge as
a no-op. Without it, every redelivery mints a duplicate edge and lineage counts stop being
evidence.

### 3d. Apache AGE projection (for multi-hop traversal)

Backward/forward single-hop queries are cheap in SQL. **Multi-hop** questions ("everything
transitively downstream of source X", "the full derivation chain behind finding F") are
graph traversals, and Apache AGE (the PostgreSQL graph extension in this repo's stack) is
the right shape for them:

```sql
-- Project relational edges into an AGE 'DERIVED_FROM' graph, then traverse transitively.
SELECT * FROM cypher('lineage_graph', $$
    MATCH (out)-[:DERIVED_FROM*1..]->(src {ref: $asset_id})
    RETURN out
$$) AS (out agtype);
```

The standing rule from this repo's data skills applies to lineage too: **a non-relational
store is never a system of record**. The relational `lineage_edges` table is the source of
truth; the AGE projection is **replayable and disposable** — rebuilt from `lineage_edges`
whenever needed, never the primary write target.

---

## 4. Checklist

- [ ] Each flow assigned the **coarsest** granularity that answers its required questions.
- [ ] Column-level reserved for flows that pass the worth-it test (here: Golden Record only).
- [ ] Capture is **runtime emission**, in the stage's transaction — not static-parse guess, not async collector.
- [ ] OpenLineage export (if any) is a projection *from* stored edges, never the primary capture.
- [ ] `lineage_edges` indexed for both directions; natural-key `UNIQUE` for idempotency.
- [ ] AGE projection, if used, is replayable from the relational system of record.
