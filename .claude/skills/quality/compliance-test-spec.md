# Skill: quality/compliance-test-spec

## Purpose
Produce a Compliance Test Specification for one compliance framework — the programmatic, automated tests that verify the product's compliance controls are implemented and behaving correctly. Compliance as Code: every control has a test; tests run in CI; a failing compliance test blocks merge.

## Inputs
- `artifacts/design/security/compliance-design.md`
- `artifacts/design/security/access-control-model.md`
- `artifacts/design/data/data-retention-policy.md`
- `artifacts/quality/test-plan.md`
- **Argument required:** framework slug (e.g. `gdpr`, `soc2`, `hipaa`)

## Output
**File:** `artifacts/quality/compliance/{framework}.md`
**Registers in manifest:** yes

## Compliance Test Rules (enforced)
- Every control from the compliance design maps to at least one automated test.
- Tests are categorised: automated (CI), scheduled (weekly/monthly), manual (annual).
- Automated tests use Open Policy Agent (OPA) for policy assertions or standard Go tests.
- Test results contribute to the compliance posture score for internal tracking.
- A control marked "manual" must have documented evidence requirements.

## Artifact Template

```markdown
# Compliance Test Specification: {framework}

**Product:** {product_name}
**Phase:** Quality
**Artifact:** Compliance Test Specification
**Framework:** {framework name and version}
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Framework: GDPR (General Data Protection Regulation)

---

## Control Coverage

| Control | GDPR Article | Test ID | Automation | Status |
|---------|-------------|---------|-----------|--------|
| Data minimisation | Art. 5(1)(c) | CT-GDPR-01 | Automated (CI) | Defined |
| Purpose limitation | Art. 5(1)(b) | CT-GDPR-02 | Automated (CI) | Defined |
| Storage limitation | Art. 5(1)(e) | CT-GDPR-03 | Automated (scheduled) | Defined |
| Right to Access | Art. 15 | CT-GDPR-04 | Automated (integration) | Defined |
| Right to Erasure | Art. 17 | CT-GDPR-05 | Automated (integration) | Defined |
| Data Portability | Art. 20 | CT-GDPR-06 | Automated (integration) | Defined |
| Encryption at rest | Art. 32 | CT-GDPR-07 | Automated (CI + scan) | Defined |
| Breach notification (72h) | Art. 33 | CT-GDPR-08 | Manual (runbook audit) | Defined |
| DPA (Data Processing Agreement) | Art. 28 | CT-GDPR-09 | Manual (legal review) | Defined |
| Privacy by Design | Art. 25 | CT-GDPR-10 | Automated (CI policy) | Defined |

---

## Automated Test Specifications

### CT-GDPR-01: Data Minimisation

**Control:** The system must not collect data beyond what is strictly necessary for its stated purpose.
**Test approach:** OPA policy asserts that no API response or database schema contains fields categorised as "not collected" in `data-classification.md`.

```rego
# policies/gdpr/data_minimisation.rego
package gdpr.data_minimisation

deny[msg] {
    # entity extraction results must not include raw PII values in event payloads
    input.event_type == "EntitiesExtracted"
    input.payload.entities[_].value != ""  # value field must be empty — entity_id only
    msg := "GDPR violation: entity value must not transit in event payload"
}

deny[msg] {
    # API responses must not return credential values
    input.response.body.credential_ref
    startswith(input.response.body.credential_ref, "vault://") == false
    startswith(input.response.body.credential_ref, "aws-sm://") == false
    msg := "GDPR violation: credential value exposed in API response"
}
```

---

### CT-GDPR-03: Storage Limitation

**Control:** Personal data must not be retained beyond the stated retention period.
**Test approach:** Scheduled nightly job checks for records past their retention deadline.

```go
func TestGDPR_StorageLimitation_NoPIIBeyondRetentionDate(t *testing.T) {
    // Integration test — runs against real PostgreSQL (testcontainers or staging)
    // Inserts a golden_record with created_at 8 years ago (beyond 7-year retention)
    // Runs the retention policy enforcer
    // Asserts the record is hard-deleted

    ctx := context.Background()
    pastDate := time.Now().AddDate(-8, 0, 0)

    _, err := db.Exec(ctx, `
        INSERT INTO golden_records (id, tenant_id, entity_type, created_at, deleted_at)
        VALUES (gen_random_uuid(), $1, 'PII_EMAIL', $2, $2)
    `, testTenantID, pastDate)
    require.NoError(t, err)

    // Run retention enforcer
    enforcer := retention.NewEnforcer(db)
    err = enforcer.Enforce(ctx, testTenantID)
    require.NoError(t, err)

    // Verify hard delete
    var count int
    err = db.QueryRow(ctx,
        "SELECT COUNT(*) FROM golden_records WHERE tenant_id = $1 AND created_at = $2",
        testTenantID, pastDate,
    ).Scan(&count)
    require.NoError(t, err)
    assert.Equal(t, 0, count, "record beyond retention period must be hard-deleted")
}
```

---

### CT-GDPR-04: Right to Access

**Control:** Data subjects can request all personal data held about them.
**Test approach:** Integration test verifying the data subject access request API returns all data in the correct format.

```
Test: GDPR_RightToAccess_ReturnsAllSubjectData
Given: A tenant with 3 golden records matching email "john.doe@acme.com"
When: GET /api/v1/data-subjects/requests?identifier=john.doe%40acme.com&type=email
Then: Response 200 with all 3 records listed
And: Each record contains: entity_type, location, first_seen_at, last_seen_at
And: Each record does NOT contain the raw value field (entity_id reference only)
And: Request is logged in the audit trail
```

---

### CT-GDPR-05: Right to Erasure

**Control:** Data subjects can request deletion of their personal data.
**Test approach:** Integration test verifying the erasure workflow.

```
Test: GDPR_RightToErasure_DeletesAllMatchingRecords
Given: A tenant with 3 golden records matching email "john.doe@acme.com"
When: POST /api/v1/data-subjects/erasure-requests {identifier: "john.doe@acme.com", type: "email"}
Then: Response 202 Accepted
And: Within 30 seconds, all 3 golden records have deleted_at set
And: An ErasureRequestReceived event is on the "audit-domain.events" topic
And: The erasure is listed in the audit trail

Test: GDPR_RightToErasure_RejectsIfActiveComplianceFinding
Given: A golden record with an open CRITICAL compliance finding
When: Erasure request submitted for that record
Then: Response 409 Conflict with code "ERASURE_BLOCKED_BY_OPEN_FINDING"
```

---

### CT-GDPR-07: Encryption at Rest

**Control:** All personal data must be encrypted at rest.
**Test approach:** Automated scan of database schema; C4 field inspection.

```go
func TestGDPR_EncryptionAtRest_C4FieldsAreEncrypted(t *testing.T) {
    // Connect to test PostgreSQL
    // For each C4 classified field, verify raw value is not readable as plaintext
    // The `value_encrypted` column should contain base64-encoded ciphertext, not human-readable text
    
    var rawValue string
    err := db.QueryRow(ctx,
        "SELECT value_encrypted FROM extracted_entities WHERE tenant_id = $1 LIMIT 1",
        testTenantID,
    ).Scan(&rawValue)
    require.NoError(t, err)
    
    // A base64-encoded AES-GCM ciphertext should not decode to valid UTF-8 plaintext
    // and must not contain common PII patterns
    assert.NotRegexp(t, `\d{3}-\d{2}-\d{4}`, rawValue, "SSN pattern found in encrypted field")
    assert.NotRegexp(t, `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}`, rawValue, "email pattern found")
}
```

---

## Manual Test Specifications

### CT-GDPR-08: Breach Notification Capability

**Control:** The organisation must be able to notify the supervisory authority within 72 hours of becoming aware of a breach.

**Evidence required:**
- Documented incident response runbook with 72-hour notification procedure
- Named DPO (Data Protection Officer) or responsible party
- Contact details for supervisory authority stored and accessible
- Annual tabletop exercise completed and documented

**Review frequency:** Annual (prior to SOC 2 / compliance audit)

---

## Compliance Test Report

After each CI run and weekly scheduled run, compliance test results are written to:
`artifacts/quality/reports/{run-id}.md` using the `quality/test-execution-report` skill.

Results feed the internal compliance posture dashboard (separate from the customer-facing posture score — this is the product's own GDPR posture, not the customer's data estate posture).
```

## Quality Checks
- [ ] Every compliance control has a test ID and automation status
- [ ] OPA policy tests cover data minimisation (no raw PII in events)
- [ ] Right to Erasure test includes the blocking condition (open finding)
- [ ] Encryption at rest test asserts raw DB value is not plaintext PII
- [ ] Manual tests have documented evidence requirements
- [ ] Results feed the compliance posture dashboard (internal product posture)
