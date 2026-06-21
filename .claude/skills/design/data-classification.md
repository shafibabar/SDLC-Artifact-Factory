# Skill: design/data-classification

## Purpose
Produce the Data Classification Framework — a taxonomy for all data the system processes, stores, or transmits. Drives encryption requirements, access controls, retention policies, and audit requirements. Classification decisions feed directly into the security architecture and compliance design.

## Inputs
- `sdlc-config.json` (compliance_frameworks, sensitive_data_types)
- `artifacts/ideate/requirements/functional.md`
- `artifacts/design/domain/events.md`

## Output
**File:** `artifacts/design/data/data-classification.md`
**Registers in manifest:** yes

## Classification Tiers (standard — adjust if product-specific taxonomy required)

| Tier | Name | Definition | Examples |
|------|------|-----------|---------|
| C1 | Public | Safe to disclose; no restrictions | Marketing content, public documentation |
| C2 | Internal | Internal use only; not for public disclosure | Product feature lists, internal metrics |
| C3 | Confidential | Sensitive business or customer operational data | Customer configuration, scan schedules, finding summaries |
| C4 | Restricted | PII, financial data, health data, regulated data | Names, emails, SSNs, credit card numbers, health records |

## Artifact Template

```markdown
# Data Classification Framework

**Product:** {product_name}
**Phase:** Design
**Artifact:** Data Classification Framework
**Version:** 1.0
**Date:** {date}
**Compliance frameworks:** {from sdlc-config}
**Status:** Draft

---

## Classification Tiers

| Tier | Name | Handling | Encryption at rest | Encryption in transit | Access |
|------|------|---------|-------------------|--------------------|--------|
| C1 | Public | No restriction | Optional | TLS (standard) | Any authenticated user |
| C2 | Internal | Internal use | AES-256 | TLS 1.3 | Authenticated users with valid role |
| C3 | Confidential | Business sensitive | AES-256 | TLS 1.3 | Role-based; logged |
| C4 | Restricted | Regulated / PII | AES-256 + field-level encryption | TLS 1.3 | Need-to-know; logged + audited |

---

## Data Inventory by Classification

### C4 — Restricted

| Data element | Where stored | Classification reason | Compliance tag | Field-level encryption? |
|-------------|-------------|----------------------|---------------|------------------------|
| Person names extracted from customer files | Entity Domain DB (`entities` table, `value` column) | PII — direct identifier | GDPR Art.4, HIPAA PHI | Yes |
| Email addresses extracted | Entity Domain DB | PII — direct identifier | GDPR Art.4 | Yes |
| Social Security Numbers / National IDs | Entity Domain DB | PII — highly sensitive identifier | GDPR, HIPAA, SOC2 | Yes |
| Credit card / financial account numbers | Entity Domain DB | PCI-DSS CHD | PCI-DSS | Yes — tokenised |
| Health / medical information | Entity Domain DB | PHI | HIPAA | Yes |
| Storage platform credentials (references) | Secrets Manager (customer-operated) | Authentication secret | SOC2 CC6 | N/A — stored in secrets manager, never in product DB |

### C3 — Confidential

| Data element | Where stored | Classification reason |
|-------------|-------------|----------------------|
| Compliance findings with entity references | Compliance Domain DB | Business-sensitive; links to C4 by reference |
| Scan configuration | File Domain DB | Reveals customer data estate structure |
| Storage location paths | File Domain DB | Reveals customer infrastructure topology |
| User profiles (name, email) | Identity Domain DB | Internal customer user data |
| Audit trail entries | Audit Domain DB | Contains references to C4 data; legally sensitive |

### C2 — Internal

| Data element | Where stored |
|-------------|-------------|
| Compliance rule definitions | Compliance Domain DB |
| Alert channel configurations | Alert Domain DB |
| Product usage metrics and telemetry | Elasticsearch |
| System performance logs | Elasticsearch |

### C1 — Public
- Product API documentation
- Generic error messages (no internal state)
- Public compliance framework definitions (GDPR article text, etc.)

---

## Field-Level Encryption (C4 Data)

C4 data elements stored in the Entity Domain database are encrypted at the field level before database write:

- **Algorithm:** AES-256-GCM
- **Key management:** Per-tenant encryption key stored in customer-operated Secrets Manager
- **Key rotation:** Supported; rotation does not require re-scanning files
- **Searchability:** Encrypted fields support equality search only (via deterministic encryption variant for indexed fields). Full-text search of C4 values is not supported.

---

## Data That NEVER Transits Product Infrastructure

| Data category | Reason |
|--------------|--------|
| Raw file content | WorkerNodes execute in customer environment; text is extracted and stored locally |
| Unredacted entity values in API responses | API returns entity type + count + location reference; never the raw extracted value in transit |
| Customer storage credentials | Only credential references (secrets manager keys) are stored; the actual credential never leaves the customer's secrets manager |
```

## Quality Checks
- [ ] Every sensitive_data_type from sdlc-config.json is classified
- [ ] C4 data has field-level encryption specified
- [ ] "Data that never transits product infrastructure" section is populated
- [ ] Compliance framework tags are applied to each C4 element
- [ ] Storage location for each classified element is specified
