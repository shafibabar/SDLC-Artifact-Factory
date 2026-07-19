---
name: compliance-design
description: >
  Teaches how to design Compliance as Code — translating regulatory and
  framework controls (SOC 2, GDPR, ISO 27001) into automated, verifiable tests
  that run in CI/CD. Covers control-to-code mapping, automated compliance checks,
  the compliance evidence pipeline, and how compliance design connects to the
  NFR specification's compliance requirements and the Quality phase's compliance
  test suite. Used by the security-architect agent during the Design phase.
version: 1.1.0
phase: design
owner: security-architect
created: 2026-06-25
tags: [design, security, compliance, soc2, gdpr, iso27001, compliance-as-code]
---

# Compliance Design

## Purpose

Compliance design translates regulatory requirements — SOC 2 controls, GDPR obligations, ISO 27001 clauses — into specific, verifiable system behaviours. The goal is Compliance as Code: every compliance requirement has an automated check that can be run in CI/CD, producing evidence that the requirement is met.

Manual compliance audits are expensive, infrequent, and snapshot-based. Automated compliance checks are cheap, continuous, and produce real-time evidence.

---

## Compliance Frameworks (First Product)

The first product targets three frameworks in the MVP:

| Framework | Scope | Key controls |
|---|---|---|
| **SOC 2 Type II** | Security, Availability, Confidentiality trust service criteria | CC6 (Logical and Physical Access), CC7 (System Operations), A1 (Availability) |
| **GDPR** | Processing of EU personal data | Article 5 (principles), Article 25 (privacy by design), Article 32 (security), Article 30 (processing register) |
| **ISO 27001** | Information security management system | A.9 (Access control), A.10 (Cryptography), A.12 (Operations security), A.16 (Incident management) |

---

## Control Decomposition

Each compliance control is decomposed into verifiable system behaviours:

### SOC 2 CC6.1 — Logical Access Security

**Control text:** The entity implements logical access security software, infrastructure, and architectures over protected information assets to protect them from security events to meet the entity's objectives.

**Decomposition:**

| Behaviour | Automated check | Evidence |
|---|---|---|
| All API endpoints require authentication | Security test: call endpoint without JWT → expect 401 | Test suite output |
| Authentication tokens expire within 1 hour | JWT inspection test: verify `exp - iat ≤ 3600` | JWT audit log sample |
| All service-to-service calls use mTLS | Linkerd edge report shows no plain-text connections | Linkerd CLI output |
| Access control policy evaluated on every request | Integration test: call with insufficient permissions → expect 403 | Test suite output |

### SOC 2 CC6.3 — Access Removal

**Control text:** The entity removes access to information assets when individuals no longer require access.

**Decomposition:**

| Behaviour | Automated check | Evidence |
|---|---|---|
| User account termination revokes all active sessions | Integration test: terminate account; use previous JWT → expect 401 | Test suite output |
| Offboarded users have no database access | Database query: no active credentials for terminated users | Database audit query |

### GDPR Article 32 — Security of Processing

**Control text:** Implement appropriate technical measures to ensure a level of security appropriate to the risk.

**Decomposition:**

| Behaviour | Automated check | Evidence |
|---|---|---|
| Data encrypted at rest | IaC check: encryption enabled on all PostgreSQL instances | OpenTofu plan output |
| Data encrypted in transit | TLS certificate validity check; mTLS verification | Certificate audit |
| Access logs retained for 7 years | Database query: oldest audit log entry ≥ 7 years ago | Audit retention query |

---

## Compliance as Code Implementation

### Pattern: Infrastructure Compliance Tests (Terratest / OpenTofu)

```go
// Test that all PostgreSQL instances have encryption enabled
func TestPostgresEncryptionAtRest(t *testing.T) {
    // Load the OpenTofu plan
    plan := terraform.InitAndPlan(t, &terraform.Options{
        TerraformDir: "../infrastructure/terraform/tenant",
    })

    // Assert encryption is enabled on the RDS/Cloud SQL instance
    resourceChanges := plan.ResourceChangesMap
    for name, change := range resourceChanges {
        if strings.Contains(name, "aws_db_instance") {
            storageEncrypted := change.Change.After["storage_encrypted"]
            assert.True(t, storageEncrypted.(bool),
                "PostgreSQL instance %s must have storage_encrypted = true", name)
        }
    }
}
```

### Pattern: API Security Compliance Tests (Go integration tests)

```go
// Test: all write endpoints require authentication
func TestAllWriteEndpointsRequireAuth(t *testing.T) {
    endpoints := []struct {
        method string
        path   string
    }{
        {"PATCH", "/v1/data-assets/test-id/classification"},
        {"POST", "/v1/storage-sources"},
        {"DELETE", "/v1/storage-sources/test-id"},
    }

    for _, ep := range endpoints {
        t.Run(ep.method+" "+ep.path, func(t *testing.T) {
            req := httptest.NewRequest(ep.method, ep.path, nil)
            // No Authorization header
            rr := httptest.NewRecorder()
            handler.ServeHTTP(rr, req)
            assert.Equal(t, http.StatusUnauthorized, rr.Code)
        })
    }
}
```

### Pattern: Audit Log Compliance Tests

```go
// Test: every classification action is recorded in the audit log
func TestClassificationCreatesAuditEntry(t *testing.T) {
    // Arrange: classify a data asset
    cmd := ClassifyDataAsset{DataAssetID: testAssetID, Level: Restricted}
    err := handler.Handle(ctx, cmd)
    require.NoError(t, err)

    // Assert: audit log entry exists with correct fields
    entry, err := auditRepo.FindByAggregate(ctx, testAssetID)
    require.NoError(t, err)
    assert.Equal(t, "DataAssetClassified", entry.EventType)
    assert.Equal(t, testUserID, entry.ActorID)
    assert.WithinDuration(t, time.Now(), entry.OccurredAt, 5*time.Second)
    assert.NotEmpty(t, entry.NonRepudiationHash)
}
```

---

## Compliance Evidence Pipeline

Compliance evidence must be collected automatically and stored in a tamper-evident audit store:

```
CI/CD Pipeline
     │
     ├── Run compliance test suite
     │         │
     │         ▼
     │   Test output (JSON) → signed with Cosign → stored in evidence store
     │
     ├── Linkerd mTLS edge report → stored in evidence store
     │
     ├── Container image scan report → stored in evidence store
     │
     └── IaC compliance check output → stored in evidence store

Evidence Store: append-only S3 bucket with object lock
(Cannot be deleted or modified after upload)
```

At audit time, the compliance team presents the evidence store contents — automated tests, signed artefacts, and infrastructure audit reports — as the compliance evidence package.

---

## Compliance Control Coverage Matrix

| Control ID | Framework | Behaviour | Test | Evidence | Status |
|---|---|---|---|---|---|
| CC6.1 | SOC 2 | All endpoints authenticated | `TestAllEndpointsRequireAuth` | Test output | Designed |
| CC6.3 | SOC 2 | Access revoked on termination | `TestAccountTerminationRevokesAccess` | Test output | Designed |
| Art 32 | GDPR | Encryption at rest | `TestPostgresEncryptionAtRest` | IaC plan | Designed |
| A.9.4.1 | ISO 27001 | Information access restriction | `TestABACEnforcementOnAllResources` | Test output | Designed |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Control decomposition | Every in-scope control decomposed into verifiable behaviours | Controls accepted on faith with no verification |
| Automated checks | Every behaviour has an automated test or IaC check | Manual-only verification |
| Evidence pipeline | Compliance evidence collected and stored automatically | Evidence collected manually before each audit |
| Coverage matrix | All in-scope controls appear in the matrix | Controls not in the matrix |
| Tamper-evident evidence | Evidence store uses append-only storage with object lock | Evidence stored in mutable storage |
| Continuous verification | Compliance checks run on every pipeline execution | Checks run once, shortly before the audit window |

---

## Anti-Patterns

- **Checkbox compliance.** Declaring a control "met" because a policy document exists, with no system behaviour that enforces it. Every control must decompose into behaviours a test can exercise.
- **Screenshot evidence.** Collecting evidence by hand (console screenshots, exported spreadsheets) days before the audit. Screenshots are snapshot-based, unverifiable, and trivially staged. Evidence must be pipeline-generated and signed.
- **Audit-week testing.** Running the compliance suite only when an audit approaches. SOC 2 Type II assesses operating effectiveness over the whole period — evidence must exist continuously, which means the suite runs on every pipeline execution.
- **Mutable evidence store.** Storing evidence where it can be edited or deleted. Without object lock, the evidence proves nothing — an auditor must be able to trust that it was not altered after collection.
- **Conflating compliance with security.** A passing compliance suite means the controls in scope are verified — not that the system is secure. Threat modeling and security testing remain separate obligations; compliance is the floor, not the ceiling.
- **Orphan controls.** In-scope controls that never appear in the coverage matrix, discovered missing during the audit. The matrix is the completeness check: every in-scope control gets a row, even if its status is "Not yet designed".
- **Testing the mock.** Compliance tests that assert against stubbed infrastructure (an in-memory database "encrypted at rest") prove nothing. Infrastructure controls must be checked against the real IaC plan or the running environment.

---

## Output Format

```markdown
---
name: compliance-design
product: [product name]
frameworks: [SOC 2, GDPR, ISO 27001]
version: 1.0.0
phase: design
created: [date]
owner: security-architect
---

# Compliance Design

## In-Scope Controls
[One section per framework with control list]

## Control Decomposition
[Per control: behaviours, automated checks, evidence]

## Compliance Control Coverage Matrix
| Control ID | Framework | Behaviour | Test | Evidence location | Status |
|---|---|---|---|---|---|

## Evidence Pipeline Design
[Architecture of the evidence collection and storage pipeline]

## Compliance Test Suite Location
`tests/compliance/` — [description of test organisation]
```
