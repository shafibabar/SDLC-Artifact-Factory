# Skill: design/data-retention-policy

## Purpose
Produce the Data Retention Policy — specifying how long each category of data is retained, when it is deleted or anonymised, and the legal basis for each retention period. This is a compliance requirement for GDPR, HIPAA, SOC2, and most other frameworks.

## Inputs
- `artifacts/design/data/data-classification.md`
- `sdlc-config.json` (compliance_frameworks)
- `artifacts/ideate/requirements/functional.md`

## Output
**File:** `artifacts/design/data/data-retention-policy.md`
**Registers in manifest:** yes

## Retention Rules (enforced)
- Every data category has an explicit retention period — "indefinite" is not acceptable without legal basis.
- Deletion must be verifiable — the system must be able to produce evidence that a data element was deleted.
- Right to erasure (GDPR Art.17) must be implemented as a concrete workflow if GDPR is in compliance_frameworks.
- Audit trail entries are exempt from standard deletion schedules (legal hold), but must have their own retention period.
- Retention periods are measured from the event that starts the clock (e.g. "from date of customer tenant deactivation", not "from creation date").

## Artifact Template

```markdown
# Data Retention Policy

**Product:** {product_name}
**Phase:** Design
**Artifact:** Data Retention Policy
**Version:** 1.0
**Date:** {date}
**Compliance frameworks:** {from sdlc-config}
**Status:** Draft

---

## Retention Schedule

| Data category | Classification | Retention period | Clock starts | Legal basis | Deletion method |
|--------------|---------------|-----------------|-------------|-------------|----------------|
| Extracted entity records (PII) | C4 | Duration of customer contract + 90 days | Contract end | Legitimate interest; GDPR Art.6(1)(b) | Hard delete + field-level key destruction |
| Compliance findings | C3 | 3 years | Finding resolution date | Legal obligation (audit evidence) | Hard delete |
| File metadata (scan results) | C3 | Duration of contract + 90 days | Contract end | Legitimate interest | Hard delete |
| Audit trail entries | C2-C3 | 7 years | Entry creation date | Legal obligation; regulatory | Archive to cold storage; not deleted |
| User session tokens | C3 | 24 hours | Token issuance | Legitimate interest | Expiry (automatic) |
| User account data | C3 | Duration of contract + 30 days | Account deactivation | Legitimate interest | Hard delete |
| Application logs (non-PII) | C2 | 90 days | Log creation | Legitimate interest | Automated purge |
| Application logs (with PII references) | C3 | 30 days | Log creation | Legitimate interest | Automated purge with field scrubbing |
| Scan configuration | C3 | Duration of contract + 30 days | Contract end | Legitimate interest | Hard delete |
| Backup data | Mirrors primary | Primary period + 30 days | Backup creation | Mirrors primary | Automated backup expiry |

---

## Right to Erasure Workflow (GDPR Art.17)

Applicable when: `GDPR` is in compliance_frameworks and a data subject submits an erasure request.

**Workflow:**
1. Customer submits erasure request for a specific data subject (person)
2. Compliance officer initiates `DataSubjectErasureRequested` command
3. System identifies all entity records linked to the data subject across all bounded contexts
4. Entity Domain hard-deletes entity records + destroys field-level encryption key for those records
5. Compliance Domain redacts finding descriptions that reference the data subject
6. Audit Domain records the erasure event (audit entry: "Erasure executed for data subject {anonymised_id} on {date}")
7. Erasure completion certificate is generated and stored

**Erasure is NOT possible for:**
- Audit trail entries recording that the data subject existed — the fact of the erasure is itself an audit entry (GDPR Recital 65)
- Anonymised / aggregated data where re-identification is impossible

---

## Data Deletion Implementation

| Method | When used | Mechanism |
|--------|----------|-----------|
| Hard delete | PII (C4), user data, configuration | `DELETE FROM` with verification query; Elasticsearch document delete |
| Field-level key destruction | Encrypted PII fields | Destroy the per-tenant/per-subject encryption key; data becomes permanently unreadable |
| Archival | Audit trail after primary retention | Move to cold storage (object store, compressed); access restricted to compliance officers |
| Automated purge | Short-lived data (logs, tokens) | Scheduled job; PostgreSQL partitioning by date for efficient bulk delete |
| Anonymisation | Analytics data to be retained | Replace PII with anonymised token; retain aggregate statistics |

---

## Retention Enforcement

| Mechanism | Scope | Frequency |
|-----------|-------|-----------|
| PostgreSQL table partitioning by date | Log tables, session tokens | Daily partition drop |
| Scheduled retention job | Entity records, findings, configuration | Nightly batch check; delete records past retention + N days |
| Elasticsearch ILM policy | Log and audit indices | Automated index rollover and deletion |
| Manual archive job | Audit trail (cold archival) | Monthly |

---

## Retention Exceptions

| Exception | Condition | Approval required |
|-----------|-----------|-----------------|
| Legal hold | Active litigation or regulatory investigation | Legal team + Compliance Officer |
| Extended audit retention | Customer contract requires longer audit trail | Customer approval in contract |
| Research retention | Anonymised data for model improvement | Ethics review + explicit customer consent |
```

## Quality Checks
- [ ] Every data category from data-classification.md has a retention period
- [ ] "Indefinite" retention is not present without documented legal basis
- [ ] Right to erasure workflow is present if GDPR is in compliance_frameworks
- [ ] Deletion method is specified (hard delete vs key destruction vs anonymisation)
- [ ] Audit trail has its own separate retention rule
- [ ] Automated enforcement mechanism is named for each retention category
