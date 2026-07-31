# Lineage Uses — Reference

Depth behind `SKILL.md`'s Decision 3: the concrete uses a lineage design must serve, the
traversals each requires, and a full worked example. A lineage design is *validated* by
these uses — if a required question cannot be answered from the captured edges, the
capture is incomplete regardless of how elegant the schema is. Grounded in DAMA-DMBOK's
"lineage is evidence" framing and this repo's compliance/data-estate product.

The three dominant uses each map to a traversal direction over `lineage_edges`
(schema and indexes in `granularity-and-capture.md`):

- **Impact analysis** → forward (input → outputs)
- **Root-cause** → backward (output → inputs)
- **Compliance / provenance evidence** → backward, tenant-scoped, tag-aware

---

## 1. Impact analysis — "what breaks if this changes?"

**Direction: forward.** Given an input that is about to change — a re-scanned source, a
renamed column, a re-classified asset — find everything downstream that must be
re-evaluated or invalidated.

```sql
-- Everything directly produced from data_asset A1 (one hop, forward).
SELECT DISTINCT output_dataset, output_ref
FROM   lineage_edges
WHERE  tenant_id = $tenant
  AND  input_dataset = 'data_assets'
  AND  input_ref     = $asset_id;
```

For **transitive** impact ("every report, graph node, and finding transitively downstream
of A1"), project into the Apache AGE graph and traverse `DERIVED_FROM*` (see
`granularity-and-capture.md` §3d). Typical impact questions in this product:

| Trigger | Impact question | Consumer |
|---|---|---|
| Source X re-scanned | Which reports/Read Models are now stale and must be recomputed? | Operations, cache invalidation |
| A column is renamed/dropped in a schema change | Which downstream outputs reference it and will break? | Schema migration review |
| An asset is re-classified (e.g. Internal → Restricted) | Which derivatives must inherit the stricter classification? | `data-classification` propagation |

**Column-level sharpens impact.** Dataset-level impact says "these four reports touch
source X." Column-level impact says "only the reports using X's `email` column break if
`email` changes" — narrower, fewer false invalidations. This is one of the few places
column-level lineage earns its cost outside survivorship, *if* schema-change impact
precision is a stated requirement.

---

## 2. Root-cause — "where did this wrong value come from?"

**Direction: backward.** A data-quality (DQ) incident surfaces a suspect output — a finding
that looks wrong, an entity with an implausible type. Root-cause walks the edges backward
to the run and source that produced it.

```sql
-- What produced compliance_finding F9? (one hop, backward)
SELECT DISTINCT input_dataset, input_ref, job_name, run_id, occurred_at
FROM   lineage_edges
WHERE  tenant_id = $tenant
  AND  output_dataset = 'compliance_findings'
  AND  output_ref     = $finding_id;
```

Root-cause for a DQ incident chains backward until it reaches an originating asset or a
run whose facet explains the defect:

```
compliance_finding F9
  ← (rule-engine run R7)  compliance_rule_eval
      ← (classification run R5)  classification_result
          ← (extraction run R3, confidence=0.42 facet)  extracted_entity E2   ◄─ low-confidence root cause
              ← (discovery run R1)  data_asset A1  (file: contract-scan-2026-03.pdf)
```

The **confidence facet** captured at extraction time (`granularity-and-capture.md`) is what
lets root-cause distinguish "the rule is wrong" from "the input was a low-confidence
extraction." Without captured lineage, root-cause degrades to log archaeology — a
hypothesis, not a finding. DAMA-DMBOK's point stands: lineage inferred after the fact from
timestamps is not evidence.

DQ root-cause connects to the observability pillars (freshness, volume, distribution,
schema, **lineage**) that a stage worker exposes in production — lineage is the pillar that
turns "this metric looks off" into "here is the exact run and source that caused it."

---

## 3. Compliance / provenance evidence

**Direction: backward, tenant-scoped, tag-aware.** This is the use the product exists for.
When the system reports a SOC 2 gap, an auditor asks "based on what?" — and lineage is the
answer. Provenance evidence has three properties beyond a plain backward walk.

### 3a. The evidence chain

```sql
-- Full provenance of a finding: finding → rule run → entities → asset → source.
SELECT * FROM cypher('lineage_graph', $$
    MATCH (f {ref: $finding_id})-[:DERIVED_FROM*1..]->(n)
    RETURN n
$$) AS (n agtype);
```

The chain must terminate at a concrete, auditable origin: a named file at a named source
(Google Drive / S3), at a recorded time. This is what `compliance-verification` cites as
evidence — the lineage chain *is* the "based on what."

### 3b. Classification tag propagation

Lineage edges are the rails along which `data-classification` tags flow. When a source is
Restricted, every artifact `DERIVED_FROM` it inherits at least that sensitivity — the tag
propagates **forward along the same edges** impact analysis uses:

```
data_asset A1  [Restricted]
   └─DERIVED_FROM─◄  extracted_entity E2   → inherits Restricted
        └─DERIVED_FROM─◄  compliance_finding F9  → inherits Restricted
```

This is why lineage records **derivation references, not raw values**: the edge proves E2
came from a Restricted source and must be handled as Restricted, without ever copying the
Restricted content into the edge (which would make `lineage_edges` itself another store to
protect and crypto-shred).

### 3c. Right-to-erasure

**Direction: forward from a person's contributing records.** To honor an erasure request,
find every derived artifact originating from that person's data, then purge/crypto-shred
per `data-retention-policy`:

```sql
-- Everything transitively derived from any record contributed by person P.
SELECT * FROM cypher('lineage_graph', $$
    MATCH (out)-[:DERIVED_FROM*1..]->(src)
    WHERE src.person_id = $person_id
    RETURN DISTINCT out
$$) AS (out agtype);
```

Erasure is the strongest argument for **complete** lineage: a single un-captured edge is a
derived artifact that survives an erasure it should not — a compliance failure. Lineage
must therefore be retained **as long as the longest-retained artifact it describes** and
purged with it, never on an independent schedule (`data-retention-policy`).

---

## 4. The five canonical lineage questions

A lineage design is validated by answering all five. If one cannot be answered from the
captured edges, capture is incomplete.

| # | Question | Direction | Grain needed | Used by |
|---|---|---|---|---|
| 1 | "What is this compliance finding based on?" | Backward: finding → rule run → entities → asset → source | Dataset | Audit, customer report |
| 2 | "If we re-scan source X, what reports become stale?" | Forward: source → all downstream outputs | Dataset (column sharpens) | Operations, cache invalidation |
| 3 | "Where did this person's data end up?" | Forward: person's records → all derived artifacts | Dataset | Right-to-erasure |
| 4 | "Which surviving attribute came from which source?" | Backward, field-level on a Golden Record | **Column** | MDM trust, dispute resolution |
| 5 | "Was this value derived from a low-confidence extraction?" | Backward to the extraction run's confidence facet | Dataset + facet | Data quality / root-cause |

Question 4 is the *only* one that forces column-level capture — every other is answered at
dataset-level (see the worth-it test in `granularity-and-capture.md`).

---

## 5. Worked example — the DataAsset → finding flow

One file flows through the pipeline; watch the edges accumulate and each use light up.

```
DISCOVERY   run R1:  data_asset A1  (gdrive://acme/contracts/msa-2026.pdf, tenant T1)
                     └─ edge: (T1, R1, source_scan → data_assets, A1)

EXTRACTION  run R3:  extracted_entity E2 {type: SSN, confidence: 0.42}
                     └─ edge: (T1, R3, data_assets/A1 → extracted_entities/E2)
                              facet: confidence=0.42

CLASSIFY    run R5:  classification_result C4 {level: Restricted}
                     └─ edge: (T1, R5, extracted_entities/E2 → classification_results/C4)

RULE ENGINE run R7:  compliance_finding F9 {control: SOC2-CC6.1, status: gap}
                     └─ edge: (T1, R7, classification_results/C4 → compliance_findings/F9)

REPORT      run R9:  compliance_report RPT {sources: [A1, ...]}
                     └─ edge: (T1, R9, compliance_findings/F9 → compliance_reports/RPT)
```

Each use, answered from these edges:

- **Provenance (Q1):** backward from F9 → C4 → E2 → A1 → `msa-2026.pdf`. The auditor's
  "based on what?" is answered with a named file at a named source and time.
- **Root-cause (Q5):** backward from F9 reaches E2's `confidence=0.42` facet — the finding
  rests on a low-confidence extraction; the DQ incident is in extraction, not the rule.
- **Impact (Q2):** forward from A1 → E2 → C4 → F9 → RPT. Re-scanning `msa-2026.pdf`
  invalidates report RPT; recompute it.
- **Tag propagation (3b):** A1's later re-classification to Restricted flows forward along
  the same edges — E2, C4, F9, RPT all inherit Restricted.
- **Erasure (Q3):** if `msa-2026.pdf` belongs to a person exercising erasure, forward
  traversal finds E2, C4, F9, RPT — every derivative to purge, with none missed.

All five answered from **dataset-level** edges plus one confidence facet — no column-level
capture needed for this flow, which is why the pipeline stays dataset-level and reserves
column-level for the separate Golden Record survivorship path.

---

## 6. Checklist

- [ ] All five canonical questions answerable from the captured edges.
- [ ] Forward index supports impact analysis and erasure; backward index supports provenance and root-cause.
- [ ] Root-cause reaches quality facets (e.g. extraction confidence), not just structural edges.
- [ ] Classification tags propagate forward along edges; edges hold references, never raw Restricted values.
- [ ] Provenance chains terminate at a concrete, auditable source (named file, source, time).
- [ ] Lineage retention aligned to the longest-retained artifact it is evidence for.
