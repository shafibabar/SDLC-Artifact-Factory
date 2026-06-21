# Skill: design/compliance-design

## Purpose
Produce the Compliance Design document — mapping each applicable compliance framework's requirements to specific system controls. Demonstrates how the product satisfies each framework's requirements and identifies gaps requiring remediation before launch.

## Inputs
- `sdlc-config.json` (compliance_frameworks)
- `artifacts/design/security/security-architecture.md`
- `artifacts/design/data/data-classification.md`
- `artifacts/design/data/data-retention-policy.md`
- `artifacts/ideate/requirements/nfrs.md`

## Output
**File:** `artifacts/design/security/compliance-design.md`
**Registers in manifest:** yes

## Compliance Mapping Rules (enforced)
- Every requirement of each active compliance framework is addressed — not just the easy ones.
- "We will do this later" is tracked as a gap with a target date, not silently omitted.
- Controls map to specific system components (not vague statements like "we use encryption").
- Shared Responsibility Model is explicitly stated — what the product provides vs. what the customer is responsible for.

## Artifact Template

```markdown
# Compliance Design

**Product:** {product_name}
**Phase:** Design
**Artifact:** Compliance Design
**Version:** 1.0
**Date:** {date}
**Active frameworks:** {from sdlc-config.compliance_frameworks}
**Status:** Draft

---

## Framework: GDPR (General Data Protection Regulation)

### Shared Responsibility Model
| Responsibility | Product | Customer |
|---------------|---------|---------|
| Data classification and mapping | Automated (product provides tooling) | Final sign-off and gap remediation |
| Consent management | Not in scope (product scans existing data) | Customer owns consent for their data subjects |
| Data subject rights (erasure, access) | Product provides API to execute | Customer owns process for receiving and validating requests |
| Data transfer agreements | N/A (data stays in customer infrastructure) | Customer responsible for SCCs with their own cloud providers |
| DPA (Data Processing Agreement) | Product provides template DPA | Customer signs and countersigns |

### GDPR Requirement → Control Mapping

| Article | Requirement | Control | Component | Status |
|---------|-------------|---------|-----------|--------|
| Art.5 | Lawfulness, fairness, transparency | ABAC access log; audit trail | Identity Domain, Audit Domain | Implemented |
| Art.5(1)(b) | Purpose limitation | Data classification; field-level encryption prevents cross-purpose access | Data Classification Framework | Implemented |
| Art.5(1)(e) | Storage limitation | Data Retention Policy with automated purge | Data Retention Policy, scheduled jobs | Implemented |
| Art.17 | Right to erasure | `DataSubjectErasureRequested` command + key destruction workflow | Entity Domain, Compliance Domain | Implemented |
| Art.20 | Data portability | Structured export API (`GET /data-export/{subject_id}`) | Compliance Domain API | Planned (Phase 2) |
| Art.25 | Data protection by design | Field-level encryption; zero-copy architecture (files stay on-premise) | Security Architecture | Implemented |
| Art.30 | Records of processing activities | Data inventory in Data Architecture doc; auto-maintained entity registry | Data Architecture | Implemented |
| Art.32 | Security of processing | AES-256 at rest; TLS 1.3 in transit; mTLS internal; ABAC | Security Architecture | Implemented |
| Art.33 | Breach notification capability | Security monitoring + alert pipeline; incident response runbook | Alert Domain, Observability Design | Implemented |

**GDPR Gaps:**
| Gap | Risk | Target resolution |
|-----|------|-----------------|
| Art.20 data portability export API | Medium — may be required by enterprise customers | Phase 2 (Implement) |

---

## Framework: SOC 2 Type II

### Trust Service Criteria → Control Mapping

| TSC | Criteria | Control | Component | Evidence type |
|-----|---------|---------|-----------|--------------|
| CC6.1 | Logical access controls | ABAC; JWT authentication; role definitions | Identity Domain | ABAC policy config; access log |
| CC6.2 | Access provisioning | Tenant admin manages user access; no standing access for product team | Identity Domain | Audit trail of access changes |
| CC6.3 | Access revocation | User deactivation propagates within 1 minute | Identity Domain | Access log |
| CC6.7 | Transmission encryption | TLS 1.3 external; mTLS internal | Security Architecture | Certificate config; Linkerd metrics |
| CC7.1 | Vulnerability detection | Dependency scanning (Snyk/govulncheck); SAST (Semgrep) in CI | CI/CD pipeline | CI scan reports |
| CC7.2 | Anomaly detection | Elasticsearch ML + Prometheus alerts | Observability Design | Alert config; incident log |
| CC8.1 | Change management | GitHub PRs with required reviews; CI gate; signed commits | CI/CD | PR audit log; deployment log |
| A1.1 | Availability commitments | 99.5% uptime SLA; Kubernetes HA; health checks | Deployment Architecture | Uptime monitoring |
| C1.1 | Confidentiality classification | Data Classification Framework | Data Classification | Classification docs |

---

## Framework: HIPAA (if applicable)

Only applicable if `HIPAA` in `sdlc-config.compliance_frameworks`.

### HIPAA Safeguards → Control Mapping

| Safeguard | Rule | Control | Status |
|-----------|------|---------|--------|
| Administrative | §164.308 — Access management | ABAC; access review quarterly | Implemented |
| Physical | §164.310 — Workstation security | Deployment in customer-controlled infra; not product responsibility | Customer responsibility |
| Technical | §164.312(a) — Unique user ID | JWT per user; no shared credentials | Implemented |
| Technical | §164.312(b) — Audit controls | Immutable audit trail | Implemented |
| Technical | §164.312(c) — Integrity | Audit chain hash; field encryption | Implemented |
| Technical | §164.312(e) — Transmission security | TLS 1.3 + mTLS | Implemented |

---

## Compliance Readiness Assessment

| Framework | Requirements met | Requirements planned | Gaps (unplanned) | Launch readiness |
|-----------|----------------|--------------------|-----------------|----|
| GDPR | 8/9 | 1/9 | 0/9 | Ready (1 planned item for Phase 2) |
| SOC2 Type II | 9/9 | 0 | 0 | Ready |
| HIPAA | 7/7 | 0 | 0 | Ready (if applicable) |

---

## Compliance Automation

| Control | Manual or automated | Frequency |
|---------|-------------------|-----------|
| Access review | Semi-automated (report generated; human review required) | Quarterly |
| Data retention enforcement | Automated (scheduled job) | Nightly |
| Vulnerability scanning | Automated (CI gate) | Every PR |
| Penetration testing | Manual (external vendor) | Annually |
| SOC2 evidence collection | Semi-automated (audit log exports) | Continuous |
```

## Quality Checks
- [ ] Every framework in sdlc-config.compliance_frameworks has a mapping section
- [ ] Shared Responsibility Model is defined for each framework
- [ ] Gaps are tracked — not silently omitted
- [ ] Controls reference specific system components, not vague statements
- [ ] Compliance readiness assessment table is populated
- [ ] Automated vs manual controls are distinguished
