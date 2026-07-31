# Verification Report Template, Completeness Checklist, and Worked Example

Reference for `compliance-verification`. Covers the compliance verification report
format, the completeness checklist adapted from threat modeling's fourth question
for *control coverage*, the evidence-package layout, the penetration-test scope, and
a worked end-to-end example of one SOC 2 control (CC6.3 tenant isolation).

Standard names only — SOC 2 Trust Service Criteria are cited by their real CC-series
names, GDPR by real article numbers. No invented control IDs, clauses, CVEs, or
statistics.

---

## The completeness criterion (adapted from Question 4)

Shostack's threat-modeling framework closes with a fourth question — *"did we do a
good job?"* — a validation pass that most lightweight efforts skip. Its three checks
translate directly into a verification completeness criterion. Coverage must be
**demonstrated**, not asserted: without this pass, "every control is tested" is a
claim, not a fact.

| Threat-model check (Question 4) | Verification analog |
|---|---|
| Does the DFD still match the built system? | **Does the control set still match the built system?** Every endpoint, store, data flow, and third-party integration that exists in production maps to a control. A new endpoint with no control is a coverage gap, exactly as a new DFD element with no STRIDE analysis is. |
| Was STRIDE applied to *every* element, not just the interesting ones? | **Does every in-scope control have an automated test and a signed attestation?** No control is verified by documentation alone; none is quietly skipped because it was inconvenient. |
| Does every filled cell have a mitigation or an accepted-risk note? | **Does every control have a PASS attestation, or a signed, dated accepted-risk exception?** No control is left in an ambiguous state. |

A verification report that cannot answer all three "yes" (with the exceptions
enumerated) is a spot check, not a verification.

### Completeness checklist

- [ ] **Coverage inventory reconciled.** The list of production endpoints (from
  `openapi.yaml`), stores (from OpenTofu state), and data flows is reconciled against
  the codified control set. Deltas are either new controls or listed exceptions.
- [ ] **Test per control.** Every control has an executable test (Go integration, OPA
  policy, or Prometheus rule). Count of controls == count of tests + count of exceptions.
- [ ] **Attestation per test.** Every test emits a signed, digest-pinned attestation
  to the immutable ledger. No flat, unsigned JSON.
- [ ] **Gate coverage.** Every `gate`-mode control is in the control gate's required
  set. A `gate` control not consumed by the gate is a silent gap.
- [ ] **Continuous coverage.** Every `gate`/`monitor` control that can drift in
  production has a Prometheus rule (CCM), not only a deploy-time test.
- [ ] **Exceptions signed and dated.** Every FAIL-with-exception has a signed,
  dated accepted-risk record with a named risk owner and a review date.
- [ ] **FAIL history retained.** The ledger retains FAIL → remediation → PASS chains.

---

## Verification report template

```markdown
---
name: compliance-verification-report
product: [product name]
period: [audit period — SOC 2 Type II assesses over a period, e.g. 2026-01-01..2026-06-30]
frameworks: [SOC 2, GDPR, ISO 27001]
version: 1.0.0
phase: quality
created: [date]
owner: security-engineer
---

# Compliance Verification Report

## Executive Summary
[Overall posture per framework. State plainly whether every gate-mode control held
throughout the period — the Type II operating-effectiveness claim — not just at deploy.]

## Completeness Attestation
[The three-part criterion, each answered yes/no with evidence:]
- Control set matches built system: [yes/no; deltas]
- Every control has a test + signed attestation: [yes/no; gaps]
- Every control has PASS or signed exception: [yes/no; exceptions listed below]

## Control Coverage Matrix
| Control ID | Framework | Enforcement mode | Test | Latest result | Attestation (digest) | Ledger location |
|---|---|---|---|---|---|---|
| CC6.1 | SOC 2 | gate | TestCC61_AllEndpointsRequireAuth | PASS | sha256:9f86… | s3://…/CC6.1/ |
| CC6.3 | SOC 2 | gate | TestCC63_CrossTenantAccessDenied | PASS | sha256:9f86… | s3://…/CC6.3/ |
| GDPR-Art30 | GDPR | gate | TestGDPRArt30_AllWriteOperationsAudited | PASS | sha256:9f86… | s3://…/GDPR-Art30/ |
| … | … | monitor | ccm:EncryptionAtRestDrift | PASS (continuous) | rolling | s3://…/CC6.1-ccm/ |

## Continuous Control Monitoring Summary
[For each monitored control: the SLI, the period-coverage %, any drift events with
their drift→recovery attestation pair and remediation time.]

## Exceptions and Accepted Risks
| Control ID | Exception | Risk owner | Risk acceptance (signed) | Review date |
|---|---|---|---|---|

## Penetration Test Summary
[Date, scope, critical/high findings, remediation status against SLA.]

## Vulnerability Scan Summary
[Date, total CVEs, HIGH/CRITICAL count, remediation status.]

## Evidence Ledger Location
[Bucket + query: how an auditor reconstructs the release chain for any digest.]
```

---

## Evidence package layout (assembled by query)

The point is that the ledger *is* the deliverable — assembly is a query by digest and
control, not a manual scramble. A materialized package for a specific audit:

```
compliance-evidence-[period]/
├── completeness-attestation.json     (the three-part criterion, signed)
├── control-chain-by-release/
│   └── sha256-9f86…/                 (one release digest = one composed chain)
│       ├── CC6.1-auth.dsse.json          (signed attestation)
│       ├── CC6.3-tenant-isolation.dsse.json
│       ├── GDPR-Art30-audit.dsse.json
│       ├── encryption-at-rest.dsse.json  (from iac-scan / OPA)
│       ├── sod-author-ne-approver.dsse.json
│       └── gate-verdict.dsse.json        (the gate's own signed decision)
├── continuous-monitoring/
│   └── CC6.1-encryption-ccm-[period].jsonl  (drift+recovery attestation stream)
├── vulnerability-scans/
│   ├── govulncheck-report-[date].json
│   └── trivy-scan-report-[date].json
├── penetration-test/
│   └── pentest-report-[date].pdf         (third-party)
└── README.md                              (control→evidence map + query commands)
```

---

## Penetration test scope

Annual, and after major change, against a staging environment. For a multi-tenant
compliance product, **cross-tenant access is the single most important scope item**.

| Test area | What is tested |
|---|---|
| Authentication bypass | Can an attacker reach APIs without a valid JWT? |
| JWT attacks | `alg:none`, RS256→HS256 downgrade, signature bypass, `kid` injection, expired-token reuse, missing audience/issuer validation |
| Privilege escalation | Can a low-privilege user reach admin endpoints? |
| Cross-tenant access | Can a tenant-A user reach tenant-B data? (top priority) |
| Input validation | SQL injection, command injection, path traversal |
| Dependency vulnerabilities | Known CVEs in direct and transitive dependencies |
| Infrastructure exposure | Unintended external exposure of internal services |

Findings are classified by severity with remediation SLAs: Critical 48h, High 30d,
Medium 90d, Low next planned release. Remediation is itself attested.

---

## Worked example — CC6.3 tenant isolation, end to end

One SOC 2 control walked through all four links of the chain, plus its continuous
extension.

**1. Control (from `compliance-design`).**
SOC 2 CC6.3 — logical/physical access controls restrict access so a tenant can
access only its own data. Enforcement mode: **gate** (a material, cross-tenant
exposure risk in a compliance product). Note: this repo's *physical* per-tenant
isolation already defends this at the infrastructure layer; the control below is
belt-and-suspenders re-verification at the application layer.

**2. Automated test.**
`TestCC63_CrossTenantAccessDenied` creates a `DataAsset` as tenant A, then requests
it with tenant B's token, and asserts the response is **404, not 403** — a 403 would
confirm to tenant B that tenant A's resource exists. Result: PASS.

**3. Attestation.**
The test emits a DSSE-signed attestation:
- `subject.digest.sha256` = the promoted image digest (the pin)
- `predicate.controlId` = "CC6.3", `framework` = "SOC 2", `enforcementMode` = "gate"
- `predicate.result` = "PASS"
- `producer.identity` = the CI OIDC signing identity; `producer.stage` = "compliance-test"
- `timestamp` = the run time
Appended to the append-only S3 ledger under
`attestations/<digest>/CC6.3/<ts>.dsse.json` (object lock, compliance mode).

**4. Control gate.**
The gate stage, given the promoted digest, finds a CC6.3 attestation for that digest,
verifies its signature against the expected CI identity, confirms `result == PASS`,
and permits promotion. Had the attestation been missing, unsigned, or FAIL (without a
signed exception), the gate would block `deploy`. The gate emits its own verdict
attestation pinned to the same digest.

**Continuous extension (CCM).**
`UntenantedQueryDrift` — `rate(db_queries_without_tenant_filter_total[5m]) > 0` — runs
continuously in production. If any query executes without a tenant filter *between
deploys*, it fires a critical alert **and** emits a FAIL drift attestation pinned to
the running digest; on resolution, a PASS recovery attestation. Over the audit
period the ledger therefore shows CC6.3 operated effectively continuously — the
Type II bar — not merely that it passed at one deploy.

This is the difference between "we test tenant isolation" (a claim) and "here is the
signed, continuously-attested chain proving CC6.3 held for every release across the
period" (demonstrated operating effectiveness).
