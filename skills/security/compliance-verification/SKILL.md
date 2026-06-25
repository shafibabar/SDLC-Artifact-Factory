---
name: compliance-verification
description: >
  Teaches how to verify that implemented security controls meet the compliance
  requirements defined in compliance-design — covering automated compliance test
  execution, evidence collection, the compliance test report format, penetration
  test integration, vulnerability scan interpretation, and how to produce a
  compliance evidence package for SOC 2, GDPR, and ISO 27001 audits. Used by
  the security-engineer agent during the Quality phase.
version: 1.0.0
phase: quality
owner: security-engineer
tags: [quality, security, compliance-verification, soc2, gdpr, penetration-testing, evidence]
---

# Compliance Verification

## Purpose

Compliance verification confirms that the implemented system meets the compliance requirements designed in `compliance-design`. It produces the evidence that auditors, customers, and regulators can inspect to verify compliance posture.

Compliance verification is not a one-time activity — it runs continuously in CI/CD and produces timestamped, signed evidence on every deployment.

---

## Verification Modes

### Mode 1: Automated Compliance Tests (continuous — every CI run)

Go integration tests that verify security controls are correctly implemented. These run on every pull request and deployment.

```
tests/compliance/
├── auth_compliance_test.go          ← all endpoints require auth
├── abac_compliance_test.go          ← all resources check tenant isolation
├── audit_log_compliance_test.go     ← all write operations produce audit entries
├── encryption_compliance_test.go    ← IaC check: all stores encrypted
├── rate_limit_compliance_test.go    ← rate limiting active on write endpoints
└── data_retention_compliance_test.go ← data not retained beyond policy period
```

### Mode 2: Infrastructure Compliance Scan (on every deployment)

OpenTofu plan output verified against compliance rules using policy-as-code (OPA or similar):

```
# Check: no PostgreSQL instance deployed without encryption
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    not resource.change.after.storage_encrypted
    msg := sprintf("PostgreSQL instance %v must have storage_encrypted = true", [resource.address])
}
```

### Mode 3: Vulnerability Scan (weekly + on dependency update)

```bash
# Go vulnerability scan
govulncheck ./...

# Container image scan
trivy image [image-name]:[tag] --exit-code 1 --severity HIGH,CRITICAL

# Dependency audit
go list -m -json all | nancy sleuth
```

### Mode 4: Penetration Test (annually + after major changes)

Third-party penetration test against a staging environment. Scope: external API surface, authentication bypass, privilege escalation, cross-tenant data access.

---

## Compliance Test Implementation Patterns

### SOC 2 CC6.1 — All Endpoints Require Authentication

```go
func TestCC61_AllEndpointsRequireAuth(t *testing.T) {
    endpoints := loadEndpointRegistry() // reads openapi.yaml and excludes /healthz, /readyz

    for _, ep := range endpoints {
        t.Run(ep.Method+" "+ep.Path, func(t *testing.T) {
            req := buildRequest(ep.Method, ep.Path, nil)
            // No Authorization header
            resp := executeRequest(t, req)

            assert.Equal(t, http.StatusUnauthorized, resp.StatusCode,
                "endpoint %s %s must return 401 when no token provided", ep.Method, ep.Path)

            // Record evidence
            evidence.Record(t, "CC6.1", ep.Method+" "+ep.Path, "PASS", resp.StatusCode)
        })
    }
}
```

### SOC 2 CC6.3 — Tenant Isolation

```go
func TestCC63_CrossTenantAccessDenied(t *testing.T) {
    // Create a resource in Tenant A
    assetID := createDataAsset(t, tenantA)

    // Attempt to access it with Tenant B's credentials
    req := buildRequest("GET", "/v1/data-assets/"+assetID.String(), nil)
    req.Header.Set("Authorization", "Bearer "+tenantBToken)
    resp := executeRequest(t, req)

    // Must be 404 (not 403 — we don't confirm the resource exists to the wrong tenant)
    assert.Equal(t, http.StatusNotFound, resp.StatusCode,
        "tenant B must not be able to access tenant A's resources")

    evidence.Record(t, "CC6.3", "cross-tenant-access", "PASS", resp.StatusCode)
}
```

### GDPR Article 30 — Audit Log Completeness

```go
func TestGDPRArt30_AllWriteOperationsAudited(t *testing.T) {
    writeOperations := []func(){
        func() { classifyDataAsset(t) },
        func() { connectStorageSource(t) },
        func() { generateReport(t) },
    }

    for _, op := range writeOperations {
        auditCountBefore := countAuditEntries(t)
        op()
        auditCountAfter := countAuditEntries(t)

        assert.Greater(t, auditCountAfter, auditCountBefore,
            "write operation must create at least one audit log entry")
    }
}
```

---

## Evidence Collection

Every compliance test produces a signed evidence record:

```go
type EvidenceRecord struct {
    ControlID   string    `json:"controlId"`
    Framework   string    `json:"framework"`
    TestName    string    `json:"testName"`
    Result      string    `json:"result"`   // PASS / FAIL
    Details     string    `json:"details"`
    TestedAt    time.Time `json:"testedAt"`
    BuildID     string    `json:"buildId"`
    CommitSHA   string    `json:"commitSha"`
    Environment string    `json:"environment"`
}

// Evidence records are written to an append-only S3 bucket with object lock
// Signed with Cosign using the CI/CD pipeline's signing key
```

---

## Compliance Evidence Package

For an audit, the following package is assembled from the evidence store:

```
compliance-evidence-[date]/
├── automated-tests/
│   ├── cc6.1-auth-test-results.json   (signed)
│   ├── cc6.3-isolation-test-results.json (signed)
│   ├── gdpr-art30-audit-test-results.json (signed)
│   └── ...
├── infrastructure/
│   ├── tofu-plan-encryption-check.json (signed)
│   ├── linkerd-mtls-edge-report.json
│   └── ...
├── vulnerability-scans/
│   ├── govulncheck-report-[date].json
│   ├── trivy-scan-report-[date].json
│   └── ...
├── penetration-test/
│   └── pentest-report-[date].pdf (third-party)
└── README.md  (index of evidence with control mapping)
```

---

## Penetration Test Scope

Annual penetration test scope (minimum):

| Test area | What is tested |
|---|---|
| Authentication bypass | Can an attacker access APIs without a valid JWT? |
| JWT attacks | Algorithm confusion, signature bypass, expired token reuse |
| Privilege escalation | Can a low-privilege user access admin endpoints? |
| Cross-tenant access | Can a tenant-A user access tenant-B data? |
| Input validation | SQL injection, command injection, path traversal |
| Dependency vulnerabilities | Known CVEs in direct and transitive dependencies |
| Infrastructure exposure | Unintended external exposure of internal services |

Penetration test findings are classified by severity (Critical, High, Medium, Low) with SLA for remediation:
- Critical: 48 hours
- High: 30 days
- Medium: 90 days
- Low: next planned release

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Control coverage | Every compliance control from `compliance-design` has a test | Controls verified only by documentation |
| Signed evidence | All test outputs signed with Cosign and stored in append-only evidence store | Evidence stored in mutable storage |
| CI gate | Compliance test suite is a required CI gate for deployment | Compliance tests run manually only |
| Pentest completed | Annual penetration test completed; findings remediated per SLA | No penetration test on record |
| Vulnerability scan clean | No HIGH or CRITICAL CVEs in production images or dependencies | Known CVEs in production |
| Evidence package assembling | Evidence package can be assembled for an audit in < 1 day | Evidence assembly requires weeks of manual collection |

---

## Output Format

```markdown
---
artifact: compliance-verification-report
product: [product name]
period: [audit period]
frameworks: [SOC 2, GDPR, ISO 27001]
version: 1.0.0
phase: quality
created: [date]
owner: security-engineer
---

# Compliance Verification Report

## Executive Summary
[Overall compliance posture — pass/fail per framework]

## Control Coverage
| Control ID | Framework | Test | Result | Evidence location |
|---|---|---|---|---|

## Exceptions and Accepted Risks
| Control ID | Exception | Risk acceptance | Review date |
|---|---|---|---|

## Penetration Test Summary
[Date, scope, critical/high findings, remediation status]

## Vulnerability Scan Summary
[Date, total CVEs, HIGH/CRITICAL count, remediation status]

## Evidence Package Location
[Path to the signed evidence archive]
```
