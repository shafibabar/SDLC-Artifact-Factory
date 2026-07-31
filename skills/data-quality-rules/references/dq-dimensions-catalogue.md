# DQ Dimensions Catalogue — the six DAMA dimensions on this repo's schema

Reference for `data-quality-rules`. Each of the six DAMA-DMBOK Data Quality dimensions is expanded here with its definition, concrete rules on the compliance product's schema (`data_assets`, `extracted_entities`, `lineage_edges`), thresholds, and where the rule is implemented (PostgreSQL constraint vs. pipeline-stage check). Self-contained.

## Schema recap (the tables rules run against)

```sql
-- One row per discovered file/object in a customer estate. Physically per-tenant.
CREATE TABLE data_assets (
  id                UUID PRIMARY KEY,
  tenant_id         UUID NOT NULL,
  source_id         UUID NOT NULL,          -- Google Drive / S3 connector instance
  source_uri        TEXT NOT NULL,          -- gdrive://... or s3://...
  content_hash      BYTEA,                  -- sha256 of decoded content
  file_type         TEXT,                   -- pdf | docx | xlsx
  sensitivity_level TEXT,                   -- Public|Internal|Confidential|Restricted
  last_scanned_at   TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One row per entity the extraction stage detected inside an asset.
CREATE TABLE extracted_entities (
  id               UUID PRIMARY KEY,
  tenant_id        UUID NOT NULL,
  data_asset_id    UUID NOT NULL REFERENCES data_assets(id),
  entity_type      TEXT NOT NULL,           -- EMAIL|PHONE|PERSON_NAME|SSN|...
  raw_value        TEXT NOT NULL,
  normalized_value TEXT NOT NULL,           -- canonical form for dedupe/compare
  confidence       NUMERIC(4,3) NOT NULL,   -- 0.000..1.000
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

DAMA-DMBOK's Data Quality Management Knowledge Area names six dimensions. `Fundamentals of Data Engineering` uses a lighter three (accuracy, completeness, timeliness); we keep all six because consistency, validity, and uniqueness catch failure modes a compliance finding cannot tolerate.

---

## 1. Completeness — is all required data present?

**DAMA definition:** the proportion of stored data against the potential of "100% complete." At the record level: are the fields that MUST be present, present.

A `data_asset` is worthless to compliance if it cannot be traced to a source or a tenant. Required fields differ by lifecycle stage — a freshly-discovered asset may not yet have a `content_hash`, but one that has passed the extraction stage must.

**Rules on this schema:**

| Rule | Dimension test | Where implemented |
|---|---|---|
| Every asset traces to a source and tenant | `source_id IS NOT NULL AND tenant_id IS NOT NULL` | `NOT NULL` column constraint (absolute) |
| A post-extraction asset has a content hash | `content_hash IS NOT NULL` once `last_scanned_at IS NOT NULL` | pipeline-stage check at extraction output (conditional on stage) |
| Every extracted entity carries a confidence | `confidence IS NOT NULL` | `NOT NULL` column constraint |
| A Restricted asset has at least one contributing entity | `EXISTS (SELECT 1 FROM extracted_entities e WHERE e.data_asset_id = a.id)` when `sensitivity_level='Restricted'` | pipeline-stage check (spans a join) |

```sql
-- Completeness: hard required fields as column constraints
ALTER TABLE data_assets
  ALTER COLUMN source_id SET NOT NULL,
  ALTER COLUMN tenant_id SET NOT NULL;
```

**Completeness score** = (rows passing all completeness rules) / (rows evaluated) in the window.

---

## 2. Accuracy — does the data correctly represent reality?

**DAMA definition:** the degree to which data correctly describes the real-world object or event. Accuracy is the hardest dimension to check automatically because it needs ground truth. For automated extraction, the practical proxy is the **confidence score** the model emits — a below-threshold score means "we are not accurate enough to be trusted unreviewed."

Thresholds are **per entity-type risk**, not one blanket number, because the cost of being wrong differs. They live in configuration (a lookup table), not code, so they are tuned as models improve without a redeploy.

| Entity type / signal | Confidence threshold | Rationale |
|---|---|---|
| `EMAIL`, `PHONE`, `PERSON_NAME` (general PII) | ≥ 0.85 | Moderate cost either way |
| `SSN`, `NATIONAL_ID`, `PASSPORT` (strong identifiers) | ≥ 0.90 | A false negative is a compliance miss; a false positive costs review load |
| `HEALTH_TERM`, `DIAGNOSIS` (special category) | ≥ 0.90 | Special-category data under GDPR Art. 9 |
| Document-level classification | inherits the lowest confidence of any entity that drove the level | The aggregate is only as accurate as its weakest driver |

```sql
CREATE TABLE dq_confidence_thresholds (   -- configuration, not code
  entity_type    TEXT PRIMARY KEY,
  min_confidence NUMERIC(4,3) NOT NULL,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO dq_confidence_thresholds VALUES
  ('EMAIL', 0.850, now()), ('PHONE', 0.850, now()),
  ('PERSON_NAME', 0.850, now()), ('SSN', 0.900, now()),
  ('NATIONAL_ID', 0.900, now()), ('HEALTH_TERM', 0.900, now());
```

A below-threshold entity does **not** fail the record; it selects the **quarantine** remediation path (see `remediation-and-go.md`) for steward review. The accuracy dimension's per-record verdict is `confidence >= threshold(entity_type)`.

**Accuracy score** = (entities at or above their type threshold) / (entities evaluated).

---

## 3. Consistency — does the data agree with itself and related data?

**DAMA definition:** the absence of difference when comparing two or more representations of a thing, within a dataset or across datasets. Consistency rules are cross-field or cross-table invariants.

The load-bearing consistency rule in this product comes from `data-classification`'s propagation model: **an asset's stored `sensitivity_level` is never lower than the maximum level implied by its contained (confirmed) entities.** A Confidential asset that contains a confirmed SSN (a Restricted-grade identifier) is inconsistent.

Because this spans a join and depends on which entities are *confirmed* (not merely detected), it is enforced in application logic at write time, not as a `CHECK` constraint.

| Rule | Invariant | Where implemented |
|---|---|---|
| Level ≥ max contained entity level | `asset.level >= MAX(level_of(entity_type))` over confirmed entities | application logic at reclassification write |
| Tenant agreement | `entity.tenant_id = asset.tenant_id` for every child entity | `CHECK` via composite FK + trigger |
| Normalized ↔ raw agreement | `normalized_value = canonicalize(raw_value)` | pipeline-stage check at extraction output |

```sql
-- Consistency: child entity can never belong to a different tenant than its asset
ALTER TABLE extracted_entities
  ADD CONSTRAINT entity_asset_same_tenant
  FOREIGN KEY (data_asset_id, tenant_id)
  REFERENCES data_assets (id, tenant_id);   -- requires composite UNIQUE on parent
```

A consistency violation is usually a **reject** (a hard invariant broken → the write should never have happened) rather than a quarantine, except the level-propagation case, which quarantines for steward adjudication.

---

## 4. Timeliness — is the data current enough to be useful?

**DAMA definition:** the degree to which data represents reality at the required point in time; freshness relative to when it is needed. A stale sensitivity level is a live compliance risk: a document reclassified as Restricted in the source but still scanned as Internal is a wrong finding.

Timeliness is an **age/staleness threshold** measured against the source's configured scan interval. It is not "is this old" in the abstract — it is "is this older than the freshness this decision requires."

| Rule | Test | Where implemented |
|---|---|---|
| Asset scanned within its source's interval | `now() - last_scanned_at <= source.scan_interval` | pipeline-stage / scheduled check |
| No asset with a NULL scan timestamp older than N days | `last_scanned_at IS NOT NULL OR created_at > now() - interval '7 days'` | scheduled profiling query |

```sql
-- Timeliness: flag assets past their source's scan interval as stale
SELECT a.id, a.source_uri, a.last_scanned_at
FROM data_assets a
JOIN sources s ON s.id = a.source_id
WHERE a.last_scanned_at < now() - s.scan_interval;
```

A stale asset does not reject — it is flagged and re-queued for scan; timeliness is the one dimension whose remediation is usually "re-ingest," not quarantine or reject. Timeliness is also a **pipeline-level observability** signal (freshness of the backlog), per `Fundamentals of Data Engineering`'s data-observability pillars.

**Timeliness score** = (assets within their freshness window) / (assets evaluated).

---

## 5. Validity — does the data conform to its expected format/domain?

**DAMA definition:** data conforms to the syntax (format, type, range, domain) of its definition. This is the most mechanizable dimension — most validity rules are `CHECK` constraints or enum/regex checks, evaluated at write time, absolute.

| Rule | Constraint | Where implemented |
|---|---|---|
| Sensitivity level in its controlled vocabulary | `sensitivity_level IN ('Public','Internal','Confidential','Restricted')` | `CHECK` constraint (absolute) |
| Entity type in the known code list | `entity_type IN (SELECT entity_type FROM dq_confidence_thresholds)` | FK to reference-data table |
| File type in supported formats | `file_type IN ('pdf','docx','xlsx')` | `CHECK` constraint |
| Confidence in range | `confidence >= 0 AND confidence <= 1` | `CHECK` constraint |
| A detected `EMAIL` value matches RFC 5322 shape before being trusted | regex on `normalized_value` | pipeline-stage check |

```sql
-- Validity: the sensitivity level domain (a controlled vocabulary / reference data)
ALTER TABLE data_assets
  ADD CONSTRAINT valid_sensitivity_level
  CHECK (sensitivity_level IN ('Public','Internal','Confidential','Restricted'));

ALTER TABLE extracted_entities
  ADD CONSTRAINT valid_confidence_range
  CHECK (confidence >= 0 AND confidence <= 1);
```

A validity failure at the constraint layer is a **reject** — malformed input the database refuses. A validity failure that is deterministically fixable (e.g. an email with surrounding whitespace, a mixed-case value) is an **auto-correct** candidate before rejection.

**Validity score** = (rows conforming to all validity rules) / (rows evaluated).

---

## 6. Uniqueness — is the same real-world thing represented once?

**DAMA definition:** no entity instance is recorded more than once. Duplicates inflate compliance findings — the same SSN counted three times reads as three exposures.

The uniqueness key here is the natural key `(data_asset_id, entity_type, normalized_value)`: the same normalized value of the same type inside the same asset is one real-world entity. This mirrors `lineage_edges`' natural-key pattern in `data-lineage-design`.

| Rule | Key | Where implemented |
|---|---|---|
| One entity per (asset, type, normalized value) | `UNIQUE (data_asset_id, entity_type, normalized_value)` | `UNIQUE` constraint (absolute) |
| One asset per (tenant, content hash) — same file discovered twice | `UNIQUE (tenant_id, content_hash)` | `UNIQUE` constraint |

```sql
-- Uniqueness: one entity per (asset, type, normalized value)
ALTER TABLE extracted_entities
  ADD CONSTRAINT uniq_entity_per_asset
  UNIQUE (data_asset_id, entity_type, normalized_value);

-- Uniqueness: the same file content discovered twice in one tenant is one asset
ALTER TABLE data_assets
  ADD CONSTRAINT uniq_asset_content
  UNIQUE (tenant_id, content_hash);
```

A uniqueness collision is normally an **auto-correct** (dedupe: keep the highest-confidence row, drop the duplicate) rather than a reject — a duplicate is not malformed, it is redundant. Deduplication on the natural key is the canonical deterministic, lossless auto-correct rule (see `remediation-and-go.md`).

**Uniqueness score** = 1 − (duplicate rows detected) / (rows evaluated).

---

## Dimension → default remediation-path quick map

| Dimension | Typical failure | Default path |
|---|---|---|
| Completeness | required field missing | reject (hard) or quarantine (upstream-dependent) |
| Accuracy | confidence below type threshold | quarantine (steward review) |
| Consistency | level below contained-entity max | quarantine (adjudicate); tenant mismatch → reject |
| Timeliness | past freshness window | re-ingest / re-scan |
| Validity | out of domain/format | auto-correct if fixable, else reject |
| Uniqueness | duplicate on natural key | auto-correct (dedupe, keep highest confidence) |

These are defaults, not laws — the gate applies the selection principle in `remediation-and-go.md`.

## DAMA grounding

DAMA-DMBOK frames data quality as a **continuous management cycle** — profile, define rules, measure, root-cause, trend a scorecard — not a one-time gate design. This catalogue defines the rules and their per-dimension scores; `dq-metrics-and-scorecard.md` closes the loop with trending and root-cause; `remediation-and-go.md` implements the correction step. Together they are the full DMBOK Data Quality operating cycle for this product.
