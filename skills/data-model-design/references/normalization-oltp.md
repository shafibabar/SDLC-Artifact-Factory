# Normalization and the Logical Model for OLTP (Hoberman)

Reference for the transactional (OLTP) model: the conceptual→logical passes that precede
DDL, normalization through BCNF worked on a repo table, keys and referential integrity, when
to denormalize, and the PostgreSQL/pgx constraint patterns that encode all of it. This is the
*normalized* shape — the system-of-record schema for Aggregate state. For the *dimensional*
(OLAP) shape see `dimensional-oltp-olap.md`; for full physical DDL see `physical-ddl-patterns.md`.

---

## 1. The Conceptual and Logical Passes Before DDL

Hoberman's discipline: build the model in three passes, each reviewable by a different
audience, and never skip to physical DDL before the concepts and relationships are agreed.

### Conceptual Data Model (CDM)

ER-Entity names plus relationship verb phrases only — no keys, no data types. Small enough
for Shafi (a non-programmer PM) to approve in one sitting. For the data-estate product:

```
DataSource ──(supplies)──▶ DataAsset ──(contains)──▶ ExtractedEntity
                                             │
                                    (classified as)
                                             ▼
                                     SensitivityLevel
```

### Relationship sentences (the validation ritual)

Every relationship is read aloud as **two** plain-English sentences the business owner
confirms in both directions. The words carry the two properties that must be explicit:

| Word | Property | Meaning |
|---|---|---|
| may / must | optionality (modality) | is the relationship optional or mandatory on this side |
| one / one-or-more | cardinality | how many instances participate |

- *"Each DataSource **may** supply **one or more** DataAssets."* (optional, 1-to-many)
- *"Each DataAsset **must** be supplied by **exactly one** DataSource."* (mandatory, many-to-1)
- *"Each DataAsset **may** contain **one or more** ExtractedEntities."*
- *"Each ExtractedEntity **must** belong to **exactly one** DataAsset."*

A relationship that cannot be read as a valid sentence in both directions has been *drawn*,
not *validated*. Unresolved cardinality/optionality disagreements found in the walkthrough
are blocking, not advisory.

### Definitions as testable artifacts

Every ER-Entity and every non-obvious attribute carries a real one-line definition — what
qualifies as an instance, what is explicitly excluded, one concrete example. "DataAsset: a
data asset" is not a definition. Example: *"sensitivity_level: the highest classification the
asset's contents warrant; NULL means not yet classified (distinct from Public, which is a
deliberate determination that the asset carries nothing sensitive)."* That null-vs-value
distinction is exactly the kind of business rule a definition must pin down.

### Logical Data Model (LDM)

The LDM adds full rigor — every attribute, each relationship's cardinality/optionality,
primary/alternate/foreign keys, and a completed normalization pass — while staying
technology-independent (no PostgreSQL types yet).

### Subtype / Supertype (generalization)

When several ER-Entities share attributes and relationships but also diverge, model a
**supertype** holding the shared attributes and **subtypes** holding what is distinct, with a
documented **subtype discriminator rule** (exclusive vs. inclusive, complete vs. incomplete).
Classic case here: `Person` and `Organisation` both plausibly share a `Party` supertype
(shared identifiers, contact attributes) rather than duplicating those attributes across two
sibling entities. The subtype rule ("a Party is exactly one of Person or Organisation" =
exclusive, complete) is documented, not left implicit.

> **The DDD/ER "Entity" collision.** Hoberman's ER "Entity" = any business noun. This repo's
> DDD `Entity` = an object with identity and lifecycle inside an Aggregate. They are not the
> same. In conceptual/logical work always write **ER-Entity** or **conceptual entity**.
> Critically: an ER relationship between two Aggregates is a *business* rule with
> cardinality/optionality — it does **not** license a foreign key across the Aggregate
> boundary. The Aggregate rule wins; cross-Aggregate references stay plain UUID columns.

---

## 2. Normalization Through BCNF — Worked on a Repo Table

Normalization eliminates redundancy and the update/insert/delete **anomalies** redundancy
causes: each fact stored in exactly one place, keyed by *the whole key and nothing but the
key*. Work a deliberately-bad denormalized table toward BCNF.

### The starting mess (unnormalized)

Imagine a single flat table someone proposed for tracking classification scans:

```
scan_log(
  asset_id, source_name, source_kind,
  entity_types_found,                 -- "PERSON, EMAIL, SSN"  (a repeating group!)
  scanned_by, scanner_email,
  sensitivity_level, sensitivity_rank -- rank derived from level
)
```

### 1NF — atomic values, no repeating groups

`entity_types_found = "PERSON, EMAIL, SSN"` packs many values into one cell. 1NF requires
atomic columns: the repeating group becomes its own child table, one row per value.

```
scan(asset_id, source_name, source_kind, scanned_by, scanner_email,
     sensitivity_level, sensitivity_rank)
scan_entity_type(asset_id, entity_type)      -- one row per found type
```

**Anomaly removed:** you can now query/index/constrain individual entity types (impossible
when they were a comma string). This is exactly why `extracted_entities` is a child table,
not a column on `data_assets`.

### 2NF — no partial dependency on part of a composite key

`scan_entity_type` has composite key `(asset_id, entity_type)`. If we had added
`asset_file_path` to it, that column depends only on `asset_id` (part of the key), not the
whole key — a partial dependency. 2NF moves `asset_file_path` back to a table keyed by
`asset_id` alone. (Tables with a single-column key are automatically in 2NF.)

**Anomaly removed:** the file path is stored once per asset, not repeated on every
entity-type row — so it cannot disagree with itself.

### 3NF — no transitive dependency (non-key → non-key)

In `scan`, `sensitivity_rank` is functionally determined by `sensitivity_level`
(Restricted→4, Confidential→3, …), which is a non-key attribute. `sensitivity_rank` depends
on the key only *transitively* through `sensitivity_level`. That is a 3NF violation.

**Fix:** `sensitivity_rank` does not belong here. Either drop it (derive rank in a query /
view) or put the level→rank mapping in its own tiny reference table keyed by
`sensitivity_level`.

**Anomaly removed (the update anomaly):** with rank stored redundantly on every scan row,
changing Confidential's rank means updating thousands of rows and risking some rows
disagreeing. In 3NF the mapping lives in one place.

### BCNF — every determinant is a candidate key

BCNF is a stricter 3NF: for every functional dependency X→Y, X must be a candidate key.
Violations arise with overlapping candidate keys. If, say, `scanner_email` uniquely
identified `scanned_by` and vice versa (two candidate keys), a dependency where the
determinant is not the chosen primary key breaks BCNF; split so each determinant is a key of
its own table. In practice the operational model reaches BCNF once every non-key fact is
attributed to the single Aggregate it belongs to.

### Summary table

| Normal form | Rule (informal) | Violation in `scan_log` | Fix |
|---|---|---|---|
| 1NF | Atomic columns, no repeating groups | `entity_types_found` comma-list | child table `scan_entity_type` |
| 2NF | No non-key attribute depends on part of a composite key | `asset_file_path` on `(asset_id, entity_type)` | move to `asset_id`-keyed table |
| 3NF | No transitive dependency (non-key → non-key) | `sensitivity_rank` derived from `sensitivity_level` | drop / reference table |
| BCNF | Every determinant is a candidate key | overlapping candidate keys | split per determinant |

---

## 3. Keys and Referential Integrity

- **Primary key** — uniquely identifies a row. In this repo, an application-assigned `UUID`
  (the Aggregate Root's identity), not a database serial, so identity exists before the row
  is persisted and is stable across stores.
- **Alternate (candidate) key** — another attribute set that could identify the row but was
  not chosen (e.g. a source's natural `(source_kind, external_id)`); enforced with a `UNIQUE`
  constraint so the business rule still holds.
- **Foreign key** — a primary key value copied into a child row to implement a relationship,
  enforced with `REFERENCES ... ON DELETE CASCADE` **within an Aggregate**. Across Aggregate
  boundaries the reference is a plain `UUID` column with **no** FK — integrity is the domain's
  responsibility, not the database's (the one-database-per-service rule depends on this).

---

## 4. When to Denormalize (the physical-only exception)

Denormalize only *after* the logical model is fully normalized, only at the physical layer,
and only for a named, measured performance reason. Every denormalization is a documented
exception, never a default. Legitimate cases in this repo:

- A **read-side projection / Read Model** deliberately flattened for query speed — but that
  is a projection rebuildable from the normalized source, not the system of record.
- A **dimensional mart** whose dimension tables are intentionally denormalized (see
  `dimensional-oltp-olap.md`) — a different layer, denormalized on purpose for BI.
- A cached derived column guarded by a trigger or recomputed by a Projector, where the join
  cost is proven prohibitive.

If a denormalized value can drift from its source, a mechanism (Projector, trigger,
scheduled recompute) must keep it correct, and that mechanism is part of the design.

---

## 5. Encoding It All in PostgreSQL Constraints (pgx)

The logical model's invariants become physical constraints — enforced by the database, not
merely by application code:

```sql
CREATE TABLE data_assets (
    id                 UUID PRIMARY KEY,
    tenant_id          UUID NOT NULL,
    source_id          UUID NOT NULL,                 -- cross-Aggregate ref: ID only, no FK
    file_path          TEXT NOT NULL,
    sensitivity_level  TEXT,                          -- NULL = not yet classified (see definition)
    version            BIGINT NOT NULL DEFAULT 1,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT sensitivity_valid CHECK (
        sensitivity_level IS NULL OR
        sensitivity_level IN ('Public','Internal','Confidential','Restricted')
    ),
    CONSTRAINT data_assets_source_natural_uq UNIQUE (tenant_id, source_id, file_path)  -- alternate key
);

-- Child table (same Aggregate): FK + cascade express the 1NF/2NF decomposition
CREATE TABLE extracted_entities (
    id             UUID PRIMARY KEY,
    data_asset_id  UUID NOT NULL REFERENCES data_assets(id) ON DELETE CASCADE,
    tenant_id      UUID NOT NULL,
    entity_type    TEXT NOT NULL,
    confidence     NUMERIC(4,3) NOT NULL CHECK (confidence >= 0 AND confidence <= 1)
);
```

Reading these queries with pgx, the constraints are the contract: a `CHECK` violation or FK
violation surfaces as a `*pgconn.PgError` with a `Code` (e.g. `23514` check, `23503` FK,
`23505` unique) the command handler maps to a domain error rather than a 500. Constraints
that encode invariants are not optional hardening — an invariant enforced *only* in Go is one
a bad migration or a second writer can violate.

---

## Checklist

- [ ] A CDM exists and every relationship was read as two confirmed sentences before DDL.
- [ ] Every ER-Entity and non-obvious attribute has a real definition (qualifies / excluded / example).
- [ ] The model reaches 3NF (BCNF where candidate keys overlap); each denormalization is a documented physical-only exception.
- [ ] Keys chosen deliberately: UUID PK, UNIQUE for alternate keys, FK+cascade only inside an Aggregate.
- [ ] Cross-Aggregate references are plain UUID columns with no FK.
- [ ] Every logical invariant is a PostgreSQL CHECK/UNIQUE/FK constraint, not Go-only.
