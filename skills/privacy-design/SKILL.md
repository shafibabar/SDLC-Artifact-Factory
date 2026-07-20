---
name: privacy-design
description: >
  Teaches how to apply Privacy by Design principles to a product that processes
  personal data — covering data minimisation, purpose limitation, right to
  erasure implementation, consent design, the personal data inventory, GDPR
  Article 30 data processing register requirements, and Data Protection Impact
  Assessment (DPIA) triggers. Used by the security-architect agent during the
  Design phase for products that process personally identifiable information.
version: 1.1.0
phase: design
owner: security-architect
created: 2026-06-25
tags: [design, security, privacy, gdpr, pii, data-minimisation, dpia, privacy-by-design]
---

# Privacy Design

## Purpose

Privacy by Design (Ann Cavoukian) means privacy protections are built into the architecture from the start — not bolted on as a compliance checkbox at the end. For a product that processes personal data (names, email addresses, file contents containing personal information, extracted PII from documents), privacy design determines what data is collected, why, for how long, and how individuals can exercise their rights.

---

## The Seven Privacy by Design Principles

| Principle | Applied meaning in this product |
|---|---|
| **1. Proactive, not reactive** | Privacy risks are identified in threat modeling before any code is written |
| **2. Privacy as default** | The strictest privacy setting is the default; users opt into lower privacy, not out of it |
| **3. Privacy embedded** | Privacy controls are in the domain model and infrastructure — not a separate "privacy module" |
| **4. Full functionality** | Privacy is not traded against functionality — the product must achieve both |
| **5. End-to-end security** | Personal data is protected from collection through deletion (encryption, access control, audit) |
| **6. Visibility and transparency** | Processing activities are documented, auditable, and disclosed to data subjects |
| **7. Respect for user privacy** | Individuals can access, correct, and delete their personal data |

---

## Personal Data Inventory

The first step in privacy design is identifying every category of personal data the system processes:

| Data category | Examples | Collected from | Purpose | Retention | Basis (GDPR Art 6) |
|---|---|---|---|---|---|
| User identity | Name, email, role | User onboarding | Authentication and authorisation | Account lifetime + 90 days | Contract performance (Art 6(1)(b)) |
| File metadata | File path, file name, file type, size | Storage source scan | Data estate mapping | 90 days (configurable) | Legitimate interest |
| Extracted PII entities | Person names, email addresses, ID numbers found in files | Entity extraction | Compliance detection | Same as file metadata | Legitimate interest |
| Access logs | User ID, action, timestamp, IP address | All API requests | Security audit, Non-Repudiation | 7 years (compliance requirement) | Legal obligation |
| File contents | The actual content of scanned files | Never — file contents are never stored | n/a | n/a | n/a |

**Critical design constraint for the first product:** File contents are never stored. Only metadata and extracted entities (types and counts, not raw extracted text) are stored. This is the primary privacy architecture decision.

---

## Data Minimisation

Collect only the data necessary for the stated purpose. For each data element, the design must answer: "What happens if we don't collect this?"

| Data element | Is it necessary? | If we don't collect it |
|---|---|---|
| File path | Yes — identifies the asset | Cannot locate the file for remediation |
| File content | No — entity extraction result is sufficient | Cannot reconstruct content from our data |
| Extracted entity raw text (e.g., "John Smith") | No — entity type and count is sufficient for compliance | Cannot identify specific individuals, but can still detect "contains PII" |
| User email | Yes — for authentication and notifications | Cannot notify user of scan completion |
| User IP address in logs | Yes — for security audit | Cannot investigate security incidents |

---

## Purpose Limitation

Data collected for one purpose must not be used for another without a new legal basis. Define the purpose for each data element at the point of collection, and enforce it at the data access layer.

| Data | Collected purpose | Prohibited uses |
|---|---|---|
| Extracted entity types | Compliance classification | Cannot be used for profiling individual data subjects |
| Access logs | Security audit | Cannot be used for user behaviour analytics or marketing |
| File metadata | Data estate mapping | Cannot be shared with third parties |

---

## Right to Erasure (Article 17 GDPR)

A data subject can request deletion of their personal data. For a B2B compliance product, the data subject whose data is processed (people named in documents) is different from the customer (the company that uses the product).

**Erasure scope for this product:**
- **User account data** (employees of the customer company): delete on account termination + grace period
- **Extracted entity data** (people mentioned in discovered files): the product processes this for compliance detection; erasure is governed by the customer's data retention policy, not by individual data subject requests (the customer holds this legal relationship)
- **Access logs**: access logs have a mandatory retention period for legal/compliance reasons; erasure requests for access log entries are declined with reference to the legal retention obligation

**Erasure implementation:**
```sql
-- Soft delete: mark as deleted, anonymise PII fields
UPDATE users
SET email = 'deleted-' || id || '@deleted.invalid',
    deleted_at = now()
WHERE id = $1 AND tenant_id = $2;

-- Hard delete after retention period expires
DELETE FROM users WHERE deleted_at < now() - interval '90 days';
```

---

## GDPR Article 30 Data Processing Register

Article 30 requires a record of processing activities. For a software product, this means documenting what personal data is processed, on whose behalf, for what purpose, and with what safeguards.

Required fields per processing activity:

```
Activity name:          [Name]
Controller:             [The customer company — data controller]
Processor:              [Our company — data processor, if applicable]
Purpose:                [The specific purpose]
Data categories:        [Types of personal data]
Data subjects:          [Who the data is about]
Recipients:             [Who the data is shared with — "no third parties" is a valid answer]
Retention period:       [How long the data is kept]
Safeguards:             [Encryption, access controls, transfer mechanisms]
Legal basis (Art 6):    [Consent / Contract / Legal obligation / Legitimate interest]
Transfer (Art 44-49):   [Whether data is transferred outside the EU/EEA and the mechanism]
```

---

## Data Protection Impact Assessment (DPIA) Triggers

A DPIA is required (GDPR Article 35) when processing is "likely to result in a high risk to the rights and freedoms of natural persons." Triggers that apply to this product:

| Trigger | Applies? | Reason |
|---|---|---|
| Systematic processing of sensitive data | Yes | Health, financial, or HR data may be in scanned files |
| Large-scale processing | Potentially | Depends on customer file volume |
| Processing that affects individuals' legal or similar significant effects | No | The product detects, not decides |
| New technologies | Yes | Entity extraction using ML models |

**Recommendation:** Conduct a DPIA for the first product. Document it as part of the security and compliance design.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Personal data inventory complete | All categories of personal data documented | Any processed personal data not in the inventory |
| Data minimisation applied | Every data element justified; no "nice to have" data collected | Data collected speculatively |
| Purpose defined per element | Every data element has a documented, specific purpose | Generic purposes ("operational purposes") |
| Erasure path defined | Erasure procedure documented per data category | No erasure path for user account data |
| Art 30 register exists | Processing activities documented | No processing register |
| DPIA conducted if triggered | DPIA on file if any trigger applies | DPIA triggers present but no DPIA conducted |
| Correct legal basis | Each basis matches an Art 6(1) ground precisely (contract ≠ legitimate interest) | Bases conflated or listed as "GDPR" |

---

## Anti-Patterns

- **Storing what you promised not to.** The architecture says "file contents are never stored" — then a debug log, a cache, or an error message captures raw extracted text ("found entity: John Smith, SSN 078-05-1120"). Store entity **types and counts** only, and treat any raw-text capture as a privacy defect, not a logging bug.
- **Privacy as a module.** A `privacy-service` bolted beside the domain instead of privacy constraints embedded in the domain model (retention on the `DataAsset` aggregate, purpose tags at the data access layer). Principle 3 is architectural, not organisational.
- **"Operational purposes."** Purposes so generic they permit anything. A purpose that cannot generate a prohibited-uses list is not a purpose.
- **Conflating legal bases.** Citing "legitimate interest" for processing that is actually necessary for contract performance (Art 6(1)(b)), or claiming consent from users who cannot meaningfully refuse (employees of the customer). Each basis has distinct obligations — legitimate interest requires a documented balancing test.
- **Hard-deleting audit history to satisfy erasure.** Erasure requests never justify destroying access logs under legal retention. Decline with the legal reference; anonymise the user record instead.
- **Confusing controller and processor obligations.** For extracted entities, the customer is the controller and holds the relationship with data subjects. Routing individual erasure requests for in-document PII to the processor short-circuits the legal chain — direct them to the controller.
- **DPIA after go-live.** A DPIA conducted once the system is built can only document risk, not design it out. DPIA triggers are evaluated in the Design phase, before architecture is fixed.
- **Retention as a config nobody enforces.** A documented 90-day retention with no scheduled deletion job. Retention is only real when a mechanism (cron job, partition drop, TTL) provably deletes on schedule and the deletion is itself audited.

---

## Output Format

```markdown
---
name: privacy-design
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: security-architect
gdpr-applicable: [yes / no]
dpia-required: [yes / no]
---

# Privacy Design

## Personal Data Inventory
| Category | Examples | Source | Purpose | Retention | Legal basis |
|---|---|---|---|---|---|

## Data Minimisation Decisions
[Per data element: necessity justification or decision not to collect]

## Purpose Limitation Controls
[Per data element: permitted and prohibited uses]

## Data Subject Rights Implementation
| Right | Scope | Implementation | Limitations |
|---|---|---|---|

## Article 30 Processing Register
[Processing activity entries]

## DPIA Summary
[DPIA findings and mitigations if DPIA was required]
```
