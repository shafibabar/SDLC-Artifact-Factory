# Skill: quality/e2e-test-spec

## Purpose
Produce an End-to-End Test Specification for one critical user journey — the tests that verify the complete system path from user action through all services to final observable state. Uses godog (BDD) with a real staging environment. No mocks anywhere in the E2E test stack.

## Inputs
- `artifacts/implement/features/{story-id}.feature`
- `artifacts/design/ux/flows/`
- `artifacts/quality/test-plan.md`
- **Argument required:** scenario name (e.g. `register-and-scan-storage-location`, `compliance-posture-visible`)

## Output
**File:** `artifacts/quality/e2e/{scenario}.md`
**Registers in manifest:** yes

## E2E Test Rules (enforced)
- E2E tests run against the staging environment — never against production.
- All infrastructure is real: real PostgreSQL, real Redpanda, real Elasticsearch, real Worker Node.
- Test setup creates a dedicated test tenant and tears it down after.
- Assertions are on externally observable outcomes: API response codes, database state, event presence in topic.
- No assertions on internal service state, goroutine count, or memory.
- E2E tests are the slowest layer — every scenario must justify its existence (covers a critical user journey).

## Artifact Template

```markdown
# E2E Test Specification: {scenario}

**Product:** {product_name}
**Phase:** Quality
**Artifact:** E2E Test Specification
**Scenario:** {scenario display name}
**Critical user journey:** {the JTBD this journey covers}
**Environment:** Staging (k3s cluster with all services deployed)
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Journey: Register and Scan a Storage Location

**User:** Tenant Administrator (role: `tenant_admin`)
**JTBD:** "When I connect a new Google Drive to the system, I want to know its compliance posture within 24 hours so I can prioritise remediation before our next audit."

---

## Preconditions

- Staging environment is healthy (all services ready, Worker Node connected)
- Test tenant provisioned with id: `e2e-tenant-{run-id}`
- Test user created with role: `tenant_admin`
- JWT issued for test user (valid for test run duration)
- Google Drive test fixture available (read-only access to a seeded test folder with 5 files of known types)

---

## godog Feature File

```gherkin
Feature: Storage Location Registration and Scan
  As a Tenant Administrator
  I want to register a Google Drive storage location and initiate a scan
  So that I can see the compliance posture of that storage location

  Background:
    Given I am authenticated as a tenant administrator
    And the staging environment has a connected Worker Node

  Scenario: Successfully register and scan a storage location
    When I register a Google Drive storage location with path "drive://e2e-test-hr-documents"
    Then the registration should succeed with status 201
    And the storage location should have status "PENDING"
    When I activate the storage location
    Then the storage location should have status "ACTIVE"
    When I initiate a scan of the storage location
    Then the scan should start within 5 seconds
    And the storage location should have status "SCANNING"
    When I wait for the scan to complete (up to 60 seconds)
    Then the storage location should have status "ACTIVE"
    And at least 1 entity extraction job should have completed
    And the compliance posture should be visible on the dashboard

  Scenario: Registration rejected for duplicate storage path
    Given a storage location with path "drive://e2e-test-hr-documents" already exists
    When I register a storage location with the same path "drive://e2e-test-hr-documents"
    Then the registration should fail with status 409
    And the error code should be "DUPLICATE_STORAGE_PATH"
```

---

## Step Definitions

```go
// internal/testing/e2e/steps/storage_location_steps.go

func (s *E2ETestSuite) iRegisterAStorageLocation(path string) error {
    payload := map[string]any{
        "platform":       "GOOGLE_DRIVE",
        "storage_path":   path,
        "credential_ref": s.cfg.TestGDriveCredRef,
    }
    resp, err := s.apiClient.Post("/api/v1/storage-locations", payload)
    if err != nil {
        return err
    }
    s.lastResponse = resp
    return nil
}

func (s *E2ETestSuite) theRegistrationShouldSucceedWithStatus(code int) error {
    assert.Equal(s.t, code, s.lastResponse.StatusCode)
    var body map[string]any
    if err := json.NewDecoder(s.lastResponse.Body).Decode(&body); err != nil {
        return err
    }
    s.lastStorageLocationID = body["id"].(string)
    return nil
}

func (s *E2ETestSuite) waitForScanToComplete(timeoutSecs int) error {
    deadline := time.Now().Add(time.Duration(timeoutSecs) * time.Second)
    for time.Now().Before(deadline) {
        status, err := s.getStorageLocationStatus(s.lastStorageLocationID)
        if err != nil {
            return err
        }
        if status == "ACTIVE" {
            return nil
        }
        time.Sleep(2 * time.Second)
    }
    return fmt.Errorf("scan did not complete within %d seconds", timeoutSecs)
}
```

---

## Assertions

### API Assertions
- `POST /api/v1/storage-locations` → 201 with `id` in response body
- `GET /api/v1/storage-locations/{id}` → 200 with `status: SCANNING` within 5 seconds of initiate
- `GET /api/v1/storage-locations/{id}` → 200 with `status: ACTIVE` after scan completes

### Database Assertions (direct PostgreSQL query on test tenant schema)
```sql
SELECT COUNT(*) FROM storage_locations
WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL;
-- Expected: 1

SELECT COUNT(*) FROM extraction_jobs
WHERE storage_location_id = $1 AND status = 'COMPLETED';
-- Expected: >= 1 (at least one file extracted)
```

### Event Assertions (Redpanda consumer assertion)
```
Topic: file-domain.scan-completed
Expected: event with payload.storage_location_id = $id within 60 seconds
```

---

## Teardown

After every E2E test run:
1. Call `DELETE /api/v1/tenants/{e2e-tenant-id}` (admin endpoint — requires platform_admin role)
2. Verify all tenant data purged from PostgreSQL within 30 seconds
3. Verify Redpanda test topics drained

If teardown fails, alert staging environment owner — test data leaks between runs.
```

## Quality Checks
- [ ] Preconditions include dedicated test tenant creation and teardown
- [ ] godog Gherkin scenario covers the full user journey (not just one step)
- [ ] Step definitions make real HTTP calls (no fakes)
- [ ] Assertions include API, database, AND event layer
- [ ] Wait loops have timeout bounds (no infinite waits)
- [ ] Teardown procedure is specified
- [ ] Scenario is justified as covering a critical user journey
