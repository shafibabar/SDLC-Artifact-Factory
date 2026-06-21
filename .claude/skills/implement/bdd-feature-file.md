# Skill: implement/bdd-feature-file

## Purpose
Produce a BDD Feature File in Gherkin (Given/When/Then) for a user story. The feature file is the shared specification between product, QA, and engineering — the source of truth for what "done" means. Scenarios become acceptance tests that run in CI.

## Inputs
- `artifacts/ideate/backlog/stories/{story-id}.md`
- `artifacts/ideate/backlog/examples/{story-id}.md` (example mapping — required; provides the scenarios)
- `artifacts/design/language/{bc-name}.md` (ubiquitous language for this bounded context)
- **Argument required:** story ID

## Output
**File:** `artifacts/implement/features/{story-id}.feature`
**Registers in manifest:** yes

## BDD Rules (enforced)
- Scenarios describe WHAT the system does, not HOW it does it. No implementation details in Gherkin.
- Every `When` step describes one action. If you find yourself writing "and when", split the scenario.
- `Given` sets up state. `When` is the action. `Then` is the observable outcome.
- Scenarios are independent — each can run in isolation without relying on state from another scenario.
- Ubiquitous language is used exactly — terms from `artifacts/design/language/{bc-name}.md`.
- Background steps are used only for universal setup (e.g. tenant exists, user is authenticated).
- At least one negative/error scenario per feature.

## Artifact Template

```gherkin
# Feature file: artifacts/implement/features/{story-id}.feature
# Story: {story-id} — {Story Title}
# BDD framework: godog (Go) — https://github.com/cucumber/godog

Feature: {Feature Name}
  As a {specific persona}
  I want {capability}
  So that {outcome}

  Background:
    Given a tenant "{tenant_name}" exists and is active
    And I am authenticated as an Administrator in tenant "{tenant_name}"

  # ── Happy Path ──────────────────────────────────────────────────────────

  Scenario: Successfully register a Google Drive storage location
    Given I have a valid read-only Google Drive credential reference "vault://creds/tenant-a/gd-cred"
    When I register a storage location with:
      | field              | value                         |
      | storage_path       | gs://my-company-drive         |
      | platform           | GOOGLE_DRIVE                  |
      | credential_ref     | vault://creds/tenant-a/gd-cred|
      | resource_cap_pct   | 20                            |
    Then the storage location is created with status "PENDING"
    And a "StorageLocationRegistered" event is published
    And the audit trail records the registration action

  Scenario: Storage location transitions to Active after credential validation
    Given a storage location "gs://my-company-drive" exists with status "PENDING"
    When credential validation completes successfully
    Then the storage location status becomes "ACTIVE"
    And a "CredentialsValidated" event is published

  Scenario: A scan is initiated on an Active storage location
    Given a storage location "gs://my-company-drive" exists with status "ACTIVE"
    When I initiate a scan
    Then the storage location status becomes "SCANNING"
    And a "ScanInitiated" event is published

  # ── Error Scenarios ─────────────────────────────────────────────────────

  Scenario: Registering a duplicate storage location is rejected
    Given a storage location "gs://my-company-drive" already exists for tenant "acme"
    When I register a storage location with path "gs://my-company-drive"
    Then I receive error code "ALREADY_EXISTS"
    And no storage location is created
    And no event is published

  Scenario: Credential with write access is rejected
    Given I have a Google Drive credential reference with write scope "vault://creds/bad-cred"
    When I register a storage location with credential "vault://creds/bad-cred"
    Then I receive error code "WRITE_SCOPE_REJECTED"
    And no storage location is created

  Scenario: Initiating a scan on a Scanning location is rejected
    Given a storage location "gs://my-company-drive" exists with status "SCANNING"
    When I initiate a scan
    Then I receive error code "SCAN_IN_PROGRESS"
    And the storage location status remains "SCANNING"
    And no new "ScanInitiated" event is published

  Scenario: Initiating a scan on a Pending location is rejected
    Given a storage location "gs://my-company-drive" exists with status "PENDING"
    When I initiate a scan
    Then I receive error code "CREDENTIALS_NOT_VALIDATED"
    And no "ScanInitiated" event is published

  # ── Scenario Outline (data-driven) ──────────────────────────────────────

  Scenario Outline: Storage locations of all supported platforms can be registered
    When I register a storage location with platform "<platform>" and a valid credential reference
    Then the storage location is created with status "PENDING"

    Examples:
      | platform    |
      | GOOGLE_DRIVE|
      | AWS_S3      |
      | SHAREPOINT  |
      | DROPBOX     |
```

## Step Definition Notes (for developer)

Step definitions live in the service repository:
`internal/testing/bdd/steps/{feature_area}_steps_test.go`

Key patterns for Go/godog:

```go
// steps file
func InitializeScenario(ctx *godog.ScenarioContext) {
    ctx.Step(`^a tenant "([^"]*)" exists and is active$`, aTenantExistsAndIsActive)
    ctx.Step(`^I register a storage location with:$`, iRegisterAStorageLocationWith)
    ctx.Step(`^the storage location is created with status "([^"]*)"$`, theStorageLocationIsCreatedWithStatus)
    // ...
}

// Integration: steps use a real test server + real PostgreSQL (testcontainers)
// NOT mocks — BDD acceptance tests are integration-level
```

## Quality Checks
- [ ] Feature file uses `Given/When/Then` — no `And` as the first step of a block
- [ ] Background contains only universal pre-conditions (authentication, tenant setup)
- [ ] Every acceptance criterion from the story has a corresponding scenario
- [ ] At least one negative scenario per feature (error conditions)
- [ ] Gherkin uses only terms from `artifacts/design/language/{bc-name}.md`
- [ ] Scenario Outline used for data-driven cases (multiple platforms, multiple states, etc.)
- [ ] Scenarios are independent (no shared mutable state between them)
