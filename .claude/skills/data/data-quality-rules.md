# Skill: data/data-quality-rules

## Purpose
Produce the Data Quality Rules — the explicit, automated rules that enforce data integrity beyond database constraints. Defines what "good data" looks like for each entity, how violations are detected, and what actions are taken. Data quality rules are the foundation of trust in the compliance assessments.

## Inputs
- `artifacts/data/models/` (all entity data models)
- `artifacts/design/data/data-classification.md`
- `artifacts/design/data/canonical-data-model.md`
- `sdlc-config.json` (compliance_frameworks)

## Output
**File:** `artifacts/data/data-quality-rules.md`
**Registers in manifest:** yes

## Quality Rule Categories

| Category | Examples |
|----------|---------|
| **Completeness** | Required fields must be non-null; collections must have at least one member |
| **Validity** | Values must be in allowed enum sets; UUIDs must be valid; timestamps must be in range |
| **Consistency** | `status = SCANNING` implies `last_scan_initiated_at IS NOT NULL`; foreign key references must resolve |
| **Uniqueness** | No duplicate entity extractions from the same file position; no duplicate Golden Records for the same identity |
| **Timeliness** | Findings must be evaluated within SLA window after entity extraction; stale data is flagged |
| **Accuracy** | Entity extraction confidence must meet minimum threshold; low-confidence entities are flagged for review |

## Artifact Template

```markdown
# Data Quality Rules

**Product:** {product_name}
**Phase:** Data
**Artifact:** Data Quality Rules
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Rule Registry

### File Domain

#### DQ-FILE-001: StorageLocation status consistency
| Attribute | Value |
|-----------|-------|
| **Category** | Consistency |
| **Entity** | StorageLocation |
| **Rule** | `status = 'SCANNING'` implies `last_scan_initiated_at IS NOT NULL` |
| **Severity** | ERROR |
| **Detection** | Nightly data quality job |
| **Action on violation** | Alert + log; do not auto-correct (risk of masking scan state bugs) |
| **SQL check** | `SELECT id FROM storage_locations WHERE status = 'SCANNING' AND last_scan_initiated_at IS NULL AND deleted_at IS NULL` |

---

#### DQ-FILE-002: Credential reference format
| Attribute | Value |
|-----------|-------|
| **Category** | Validity |
| **Entity** | StorageLocation |
| **Rule** | `credential_ref` must not be empty and must match the pattern `^(vault|aws-sm|gcp-sm)://` |
| **Severity** | ERROR |
| **Detection** | On write (application validation) + nightly job |
| **Action** | On write: reject with INVALID_CREDENTIAL_REF; in batch: flag and alert |

---

### Entity Domain

#### DQ-ENTITY-001: Extraction confidence threshold
| Attribute | Value |
|-----------|-------|
| **Category** | Accuracy |
| **Entity** | ExtractedEntity |
| **Rule** | Entities with `confidence_score < 0.50` must have `review_status = 'REQUIRES_REVIEW'` |
| **Severity** | WARNING |
| **Detection** | On write (application logic) |
| **Action** | Set `review_status = 'REQUIRES_REVIEW'`; include in low-confidence review queue |

---

#### DQ-ENTITY-002: Golden Record deduplication coverage
| Attribute | Value |
|-----------|-------|
| **Category** | Uniqueness |
| **Entity** | GoldenRecord |
| **Rule** | No two GoldenRecords of the same `entity_type` and `tenant_id` should share a `canonical_identifier` |
| **Severity** | ERROR |
| **Detection** | Post-deduplication job; nightly consistency check |
| **Action** | Flag for manual review; merge candidate surfaced in UI |
| **SQL check** | `SELECT canonical_identifier, COUNT(*) FROM golden_records WHERE tenant_id = $1 GROUP BY entity_type, canonical_identifier HAVING COUNT(*) > 1` |

---

### Compliance Domain

#### DQ-COMP-001: Finding must reference valid rule
| Attribute | Value |
|-----------|-------|
| **Category** | Consistency |
| **Entity** | Finding |
| **Rule** | Every finding must reference an active compliance rule (`rule_id` FK must resolve to a non-deleted rule) |
| **Severity** | ERROR |
| **Detection** | On write (FK constraint) + nightly orphan scan |
| **Action** | On orphan detection: alert; do not auto-delete (finding is evidence) |

---

#### DQ-COMP-002: Exception requires justification
| Attribute | Value |
|-----------|-------|
| **Category** | Completeness |
| **Entity** | Exception |
| **Rule** | `justification` must be non-null and have length > 20 characters |
| **Severity** | ERROR |
| **Detection** | On write (application validation) |
| **Action** | Reject with MISSING_JUSTIFICATION |

---

#### DQ-COMP-003: Finding age timeliness
| Attribute | Value |
|-----------|-------|
| **Category** | Timeliness |
| **Entity** | Finding |
| **Rule** | Findings created > 30 days ago with `status = 'OPEN'` are classified as OVERDUE |
| **Severity** | WARNING (business concern, not data error) |
| **Detection** | Computed at query time; `overdue = (created_at < NOW() - INTERVAL '30 days' AND status = 'OPEN')` |
| **Action** | Surface in UI with overdue badge; include in overdue count metric |

---

## Data Quality Job

The nightly data quality job runs all `Detection: nightly` rules and writes results to:

```sql
CREATE TABLE data_quality_violations (
    id              UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id       UUID        NOT NULL,
    rule_id         TEXT        NOT NULL,   -- e.g. 'DQ-FILE-001'
    entity_table    TEXT        NOT NULL,
    entity_id       UUID        NOT NULL,
    severity        TEXT        NOT NULL,   -- ERROR | WARNING
    violation_desc  TEXT        NOT NULL,
    detected_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);
```

Violations of severity ERROR trigger an alert. Violations of severity WARNING are surfaced in the admin dashboard under "Data Quality".

---

## Data Quality Score

A per-tenant data quality score is computed nightly:

```
dq_score = (total_checks_passed / total_checks_run) * 100
```

Displayed in the administrator dashboard as a health indicator. Below 95% triggers an advisory notification to the tenant admin.
```

## Quality Checks
- [ ] Rules cover all six quality categories (completeness, validity, consistency, uniqueness, timeliness, accuracy)
- [ ] Every rule has detection mechanism, severity, and action specified
- [ ] SQL checks are included for rules detected via database query
- [ ] Data quality violations table is defined
- [ ] Nightly job scope is defined
- [ ] Data quality score computation is documented
