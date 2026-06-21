# Skill: design/canonical-data-model

## Purpose
Produce the Canonical Data Model — the authoritative type definitions shared across bounded context integration boundaries. Not a shared database schema, but a shared vocabulary for integration events and ACL translation. Defines what a concept looks like "on the wire" between contexts.

## Inputs
- `artifacts/design/contracts/event-schemas.md`
- `artifacts/design/bounded-contexts.md`
- `artifacts/design/domain/events.md`
- `sdlc-config.json` (compliance_frameworks — affects canonical entity type taxonomy)

## Output
**File:** `artifacts/design/data/canonical-data-model.md`
**Registers in manifest:** yes

## Canonical Model Rules (enforced)
- The canonical model is NOT a shared database schema — it exists only on the wire (in events and APIs).
- Every bounded context translates to/from the canonical model at its ACL boundary.
- Canonical types are additive — new fields can be added without breaking existing consumers.
- Canonical entity type taxonomy is compliance-framework-aware (GDPR PII categories, HIPAA PHI, PCI-DSS CHD).

## Artifact Template

```markdown
# Canonical Data Model

**Product:** {product_name}
**Phase:** Design
**Artifact:** Canonical Data Model
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Purpose and Scope

The Canonical Data Model defines shared type definitions used in **integration events and cross-context API responses only**. Each bounded context maintains its own internal model and translates at the ACL boundary.

---

## Entity Type Taxonomy

The canonical entity type list — used consistently in event payloads and API responses across all contexts:

### PII — Direct Identifiers
| Type code | Description | GDPR | HIPAA | PCI-DSS |
|-----------|-------------|------|-------|---------|
| `PII_FULL_NAME` | Full person name | Art.4 | — | — |
| `PII_EMAIL_ADDRESS` | Email address | Art.4 | — | — |
| `PII_PHONE_NUMBER` | Phone number | Art.4 | — | — |
| `PII_NATIONAL_ID` | National identification number (SSN, NIN, etc.) | Art.9 | PHI | — |
| `PII_PASSPORT_NUMBER` | Passport or government ID number | Art.9 | — | — |
| `PII_DATE_OF_BIRTH` | Date of birth | Art.4 | PHI | — |
| `PII_HOME_ADDRESS` | Residential address | Art.4 | PHI | — |

### Financial Data (PCI-DSS)
| Type code | Description | PCI-DSS category |
|-----------|-------------|-----------------|
| `FINANCIAL_CREDIT_CARD_NUMBER` | Primary Account Number (PAN) | CHD |
| `FINANCIAL_CARD_EXPIRY` | Card expiry date | CHD |
| `FINANCIAL_CVV` | Card verification value | SAD |
| `FINANCIAL_BANK_ACCOUNT_NUMBER` | Bank account number | SFD |
| `FINANCIAL_IBAN` | International bank account number | SFD |

### Health Data (HIPAA PHI)
| Type code | Description |
|-----------|-------------|
| `HEALTH_DIAGNOSIS_CODE` | ICD-10 or SNOMED diagnosis code |
| `HEALTH_MEDICATION` | Medication name or prescription |
| `HEALTH_PROVIDER_ID` | Healthcare provider identifier (NPI) |
| `HEALTH_INSURANCE_ID` | Health insurance member ID |

### Credentials and Tokens
| Type code | Description |
|-----------|-------------|
| `CREDENTIAL_PASSWORD` | Plaintext or weakly encoded password |
| `CREDENTIAL_API_KEY` | API key or access token |
| `CREDENTIAL_SSH_PRIVATE_KEY` | SSH private key material |
| `CREDENTIAL_CERTIFICATE` | TLS or code signing certificate private key |

---

## Canonical Event Envelope (reference)

All integration events conform to this envelope (from event-schemas.md):

```json
{
  "event_id": "uuid",
  "event_type": "string (PascalCase)",
  "event_version": "integer",
  "schema_version": "string (v1, v2...)",
  "occurred_at": "ISO8601",
  "idempotency_key": "string",
  "tenant_id": "uuid",
  "correlation_id": "uuid",
  "causation_id": "uuid",
  "payload": {}
}
```

---

## Canonical Entity Summary (used in cross-context events)

When cross-context events reference entity type distributions (e.g. `EntitiesExtracted`), they use this canonical structure:

```json
{
  "entity_type_summary": [
    {
      "entity_type": "PII_FULL_NAME",
      "count": 14,
      "confidence_bucket": "HIGH | MEDIUM | LOW"
    }
  ]
}
```

**`confidence_bucket` thresholds:**
- HIGH: confidence ≥ 0.85
- MEDIUM: confidence ≥ 0.65
- LOW: confidence < 0.65

---

## Canonical Finding Severity

All compliance findings use this severity scale:

| Level | Numeric | Definition |
|-------|---------|-----------|
| CRITICAL | 4 | Data subject rights violation or regulatory breach requiring immediate action |
| HIGH | 3 | Significant compliance risk; remediation required within 30 days |
| MEDIUM | 2 | Compliance gap; remediation required within 90 days |
| LOW | 1 | Minor risk or advisory; track for review |
| INFORMATIONAL | 0 | Observation only; no remediation required |

---

## Canonical Compliance Framework Codes

Used in finding events and API responses:

| Code | Framework |
|------|-----------|
| `GDPR` | General Data Protection Regulation |
| `SOC2` | SOC 2 Type II |
| `HIPAA` | Health Insurance Portability and Accountability Act |
| `ISO27001` | ISO/IEC 27001:2022 |
| `PCIDSS` | PCI Data Security Standard v4.0 |
```

## Quality Checks
- [ ] Entity type taxonomy covers all compliance frameworks in sdlc-config.json
- [ ] Canonical model is explicitly NOT a shared database schema
- [ ] Canonical event envelope matches event-schemas.md
- [ ] Severity scale is unambiguous with time-bound remediation guidance
- [ ] Confidence bucketing thresholds are defined numerically
