# Tagging and Propagation — Where the Tag Lives and How It Flows

Reference for `data-classification`. The tag schema (where a classification physically lives in this
stack), the inherit-max propagation rule applied through pipelines and joins, manual-override
storage, the reclassification event, and worked SQL/Go. Grounded in DAMA-DMBOK's Reference Data and
Metadata disciplines and this repo's stack (Postgres + pgx, Redpanda, Apache AGE).

---

## 1. The tag schema — what a classification actually is

A classification is a small tuple of metadata attached to a classified thing:

```
{
  sensitivity_level:     Public | Internal | Confidential | Restricted   -- computed effective level
  manual_override_level: (nullable) same enum                            -- steward decision, if any
  override_reason:       (nullable) text
  override_by:           (nullable) actor id
  override_at:           (nullable) timestamptz
  special_categories:    set of { PII, special-category, PHI, payment }
  classified_at:         timestamptz
}
```

Two invariants make this safe and auditable:

1. **Store the override separately from the effective level.** If only the effective level is stored,
   recomputation cannot tell "a human decided Internal" from "the max rule produced Internal" — it
   will either clobber the human decision or fossilise it forever. `manual_override_level` is its own
   nullable column; the effective level is always re-derivable from inputs.
2. **Keep the per-input evidence.** Persist the source default and the per-entity provisional levels
   (or a reference to them) so the effective level can be recomputed, audited, and explained — never
   just the result.

---

## 2. Where the tag lives in this stack

| Granularity | Storage location | Mechanism |
|---|---|---|
| **Column** | Postgres column comment / a `column_classifications` catalog table | Technical-metadata catalog keyed on `(table, column)` |
| **Table / dataset** | A `dataset_classifications` row, or table comment | One row per governed dataset |
| **`DataAsset`** (a crawled file) | `data_assets.sensitivity_level` + override columns | Per-tenant schema (physical isolation) |
| **`Entity`** (extracted) | `extracted_entities` provisional level | Feeds the asset's inherit-max |
| **In flight** | Redpanda event envelope header/payload | Travels with every domain event |
| **In the graph** | Apache AGE `DataAsset` / `Entity` vertex property `sensitivity_level` | Enables reachability queries |

### Postgres (pgx) — the asset table

```sql
CREATE TYPE sensitivity_level AS ENUM ('Public', 'Internal', 'Confidential', 'Restricted');

CREATE TABLE data_assets (
    id                    uuid PRIMARY KEY,
    tenant_id             uuid NOT NULL,               -- physical isolation: separate schema/db per tenant
    source_default_level  sensitivity_level NOT NULL DEFAULT 'Internal',
    sensitivity_level     sensitivity_level NOT NULL,  -- the computed EFFECTIVE level
    manual_override_level sensitivity_level,           -- nullable; steward decision sits OUTSIDE the max
    override_reason       text,
    override_by           uuid,
    override_at           timestamptz,
    special_categories    text[] NOT NULL DEFAULT '{}',
    classified_at         timestamptz NOT NULL DEFAULT now()
);
```

### In the event envelope

```json
{
  "event": "DataAssetReclassified",
  "asset_id": "…",
  "tenant_id": "…",
  "old_level": "Confidential",
  "new_level": "Restricted",
  "special_categories": ["PII"],
  "reason": "steward-confirmed SSN",
  "actor": "steward:shafi"
}
```

Every downstream stage (graph updater, compliance engine, alerting) keys on this so its projection of
the current level stays consistent — Eventual Consistency across the pipeline.

---

## 3. The inherit-max propagation rule

The effective level is a pure function of its inputs, with the manual override layered on top:

```
effective_level(asset) =
    manual_override_level                         if manual_override_level is set
    else max( over the ordinal taxonomy:
              sensitivity(each contained entity),
              source_default_level )
```

- `max` runs over the ordinal `Public(0) < Internal(1) < Confidential(2) < Restricted(3)`.
- The **manual override is outside the max**, so a steward's decision is authoritative even when it
  *de-escalates* (an automated signal can never out-vote it).
- **Derived datasets inherit the max of their inputs.** This is the rule that makes classification
  flow through transformations:

| Transformation | Result level |
|---|---|
| A document containing an Internal count + a Restricted `SSN` entity | Restricted |
| A `JOIN` of an Internal table with a Confidential table | Confidential |
| A `JOIN` of a Confidential table with a Restricted table | Restricted |
| An aggregate `COUNT(*)` producing only totals (no row-level PII) | Internal (see taxonomy §1 — counts are Internal) |
| A materialized view / OLAP rollup over mixed-sensitivity sources | max of all contributing sources |

> The one deliberate exception: a **pure aggregate that emits only counts/totals** and carries no
> row-level personal data is Internal even when its sources are Restricted, because the output is
> derived metadata, not the underlying data. This must be an explicit, reviewed decision — it is the
> only path by which a Restricted input legitimately yields a non-Restricted output.

### Go — computing the effective level

```go
type Level int

const (
    Public Level = iota
    Internal
    Confidential
    Restricted
)

// EffectiveLevel applies inherit-max, with a steward override layered outside the max.
func EffectiveLevel(override *Level, entityLevels []Level, sourceDefault Level) Level {
    if override != nil {
        return *override // authoritative — wins even when it de-escalates
    }
    m := sourceDefault
    for _, l := range entityLevels {
        if l > m {
            m = l
        }
    }
    return m
}
```

---

## 4. Escalation past a standing override

If recomputation over **new** evidence yields a level *higher* than the standing override — e.g. a
steward marked an asset Internal, and a later crawl finds a fresh `SSN` entity in it — the system must
**not** silently keep the low override and must **not** silently discard the human judgment. It flags
the asset for steward **re-review** and alerts. Both silent outcomes are defects. De-escalation stays
steward-only; escalation past an override becomes a review task, never an automatic overwrite.

---

## 5. Reclassification is an event, not a mutation

Classification is never a one-time stamp. Whenever the effective level changes, emit
`DataAssetReclassified` so projections and access decisions update:

- The AGE graph vertex property is updated so reachability queries ("which Restricted assets can this
  person reach") stay accurate.
- Downstream ABAC decisions immediately consume the new level.
- **De-escalation is always audited** because it reduces protection.

---

## 6. Worked example — classifying a crawled DOCX

`DataAsset`: a DOCX crawled from a Google Drive `StorageSource` whose `source_default_level` is
`Internal`; confidence threshold `0.60`.

```
Extraction run finds:
  3 × EMAIL        (confidence 0.97–0.99)  → PII, provisional Confidential
  1 × PERSON_NAME  (confidence 0.94)        → PII, provisional Confidential
  1 × SSN          (confidence 0.41)        → BELOW 0.60 threshold →
                                              NOT auto-applied; flagged for steward review

Propagation (no manual override yet):
  effective = max(Confidential, Confidential, Confidential, Internal) = Confidential
  special_categories = { PII }

Steward review:
  steward confirms the low-confidence SSN is real
  → manual_override_level = Restricted   (reason recorded, decision audited)
  → DataAssetReclassified { old: "Confidential", new: "Restricted", actor: "steward:shafi" }
  → AGE vertex updated; ABAC now requires Restricted access; retention window tightens
```

What did **not** happen: the 0.41-confidence SSN never silently set a level (below threshold →
review), and the escalation to Restricted came from an audited human decision with the automated
evidence as input — not from the machine overwriting anything.
