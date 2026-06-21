# Skill: design/privacy-design

## Purpose
Produce the Privacy Design document — embedding privacy controls into the product architecture (Privacy by Design, GDPR Art.25). Covers data minimisation, purpose limitation, consent and rights handling, and privacy impact assessment.

## Inputs
- `sdlc-config.json` (compliance_frameworks, sensitive_data_types)
- `artifacts/design/data/data-classification.md`
- `artifacts/design/data/data-retention-policy.md`
- `artifacts/design/security/security-architecture.md`

## Output
**File:** `artifacts/design/security/privacy-design.md`
**Registers in manifest:** yes

## Artifact Template

```markdown
# Privacy Design

**Product:** {product_name}
**Phase:** Design
**Artifact:** Privacy Design
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Privacy by Design Principles Applied

| Principle | Implementation |
|-----------|---------------|
| **Proactive, not reactive** | Privacy controls are architectural, not retrofitted. Zero-copy architecture prevents data transit. |
| **Privacy as default** | All features default to maximum privacy. Opt-in for any additional data sharing. |
| **Privacy embedded in design** | Field-level encryption, tenant isolation, and data minimisation are built in — not added later. |
| **Full functionality** | Privacy controls do not reduce product utility — the product delivers compliance insights WITHOUT holding sensitive values at rest in plaintext. |
| **End-to-end security** | mTLS, TLS 1.3, AES-256-GCM at every layer. |
| **Visibility and transparency** | Customers can query what data the product holds about their data subjects via the Data Subject Access API. |
| **Respect for user privacy** | Product team has no access to customer data. Physical tenant isolation prevents accidental exposure. |

---

## Data Minimisation

The product collects the minimum data required to deliver its function:

| What we collect | Why it's needed | What we don't collect (and why) |
|----------------|-----------------|--------------------------------|
| File metadata (path, MIME type, size, checksum) | Needed to identify files and detect changes | File content — never stored on product infrastructure |
| Entity TYPE and COUNT (per file) | Needed to evaluate compliance rules | Entity VALUES (names, emails, SSNs) — stored encrypted in customer-controlled infrastructure; never transmitted to product-operated systems |
| Compliance finding metadata | Needed to deliver the product's value | Raw entity values in findings — findings reference entity by ID; the value is looked up at review time in the customer's infrastructure |
| User identity (from IdP JWT claims) | Needed for access control and audit | Passwords — never stored (delegated to customer's IdP) |

---

## Data Subject Rights Implementation

| Right | GDPR Article | Implementation | SLA |
|-------|-------------|---------------|-----|
| Right of access | Art.15 | `GET /privacy/data-subject/{id}/report` — returns all data held about the subject | 30 days |
| Right to rectification | Art.16 | `PUT /privacy/data-subject/{id}/correction` — flags entity record for human review | 30 days |
| Right to erasure | Art.17 | `POST /privacy/data-subject/{id}/erasure` — initiates the erasure workflow | 30 days |
| Right to restriction | Art.18 | `POST /privacy/data-subject/{id}/restriction` — marks entity records as restricted from processing | 30 days |
| Right to portability | Art.20 | `GET /privacy/data-subject/{id}/export` — structured JSON export | 30 days |
| Right to object | Art.21 | `POST /privacy/data-subject/{id}/objection` — stops further processing | Immediate |

All rights requests are logged in the immutable audit trail.

---

## Zero-Copy Architecture

The product's primary privacy control is its zero-copy architecture:

```
Customer Files ─── [Worker Node: runs in customer infra] ─── Entity extraction
                          │
                          │  Only transmitted to product:
                          │    - File metadata (path, MIME type, size)
                          │    - Entity TYPE and COUNT (not values)
                          │    - Compliance rule evaluation results
                          │
                          ▼
                    Product Control Plane
                    (never sees file content or entity values)
```

This means: even if the product control plane is breached, customer PII is not exposed.

---

## Privacy Impact Assessment (PIA)

| Data flow | Risk | Mitigation | Residual risk |
|-----------|------|-----------|--------------|
| Entity type detection (on-premise) | Low — processing happens in customer infrastructure | Zero-copy architecture | Negligible |
| Entity metadata (type + count) in transit to product | Medium — could reveal compliance posture | Encrypted in transit (mTLS) | Low |
| Compliance findings stored in product DB | Medium — references entity types and locations | Tenant-isolated DB; field encryption; ABAC access controls | Low |
| Audit trail entries | Low-medium — contains user actions referencing entity IDs | Immutable, append-only; ABAC read restricted | Low |
| User identity (JWT claims) | Low — name and email from customer's IdP | Not stored beyond JWT lifetime; not persisted | Negligible |

---

## Product Team Access to Customer Data

**Product team members have ZERO access to customer data by default.**

| Access type | Permitted? | Mechanism |
|------------|-----------|---------|
| Customer database (any) | No | Physical isolation; product team has no cluster credentials |
| Customer audit trail | No | Audit Domain read restricted to `auditor` role within the tenant |
| Support access (break-glass) | Only with customer written consent + 4-eye review | Break-glass access logged in customer-visible audit trail; time-limited (4 hours) |

Break-glass procedure:
1. Customer explicitly grants support access in writing
2. Two engineers approve the access request (4-eye)
3. Time-limited credential issued (4-hour expiry)
4. All actions taken are logged to the customer's audit trail
5. Access log is emailed to the customer after the session
```

## Quality Checks
- [ ] All seven Privacy by Design principles are mapped to concrete implementations
- [ ] Data minimisation table explicitly states what is NOT collected and why
- [ ] All GDPR data subject rights have API endpoints and SLA defined (if GDPR is in compliance_frameworks)
- [ ] Zero-copy architecture diagram shows what does and does not transit product infrastructure
- [ ] Product team access policy is explicit (default: zero access)
- [ ] Break-glass procedure is documented
