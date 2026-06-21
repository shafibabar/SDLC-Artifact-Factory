# Skill: implement/tdd-spec

## Purpose
Produce a TDD Specification for a feature or user story — the failing test cases that define the expected behaviour BEFORE any implementation code is written. This is the Red phase of Red-Green-Refactor. The spec becomes the test file; the developer writes only enough code to make it pass.

## Inputs
- `artifacts/ideate/backlog/stories/{story-id}.md` (the target story)
- `artifacts/ideate/backlog/examples/{story-id}.md` (example mapping output — required)
- `artifacts/design/domain/aggregates/` (relevant aggregate definitions)
- `artifacts/design/domain/commands.md`
- `artifacts/design/domain/events.md`
- `artifacts/implement/standards/coding-standards.md`
- **Argument required:** story ID (e.g. `US-004`)

## Output
**File:** `artifacts/implement/specs/{story-id}-tdd-spec.md`
**Registers in manifest:** yes

## TDD Rules (enforced)
- Tests are written before implementation. If implementation exists, this skill warns.
- Every acceptance criterion from the user story becomes at least one test case.
- Every error scenario from example mapping becomes a test case.
- Unit tests cover the domain model in isolation (no infrastructure).
- Integration test cases are identified but flagged separately — they need real infrastructure.
- Test names follow: `Test{Type}_{Method}_{Scenario}` — e.g. `TestStorageLocation_InitiateScan_RejectsScanInProgress`

## Artifact Template

```markdown
# TDD Specification: {story-id} — {Story Title}

**Product:** {product_name}
**Phase:** Implement
**Artifact:** TDD Specification
**Story:** {story-id}
**Feature:** {feature area}
**Date:** {date}
**Status:** Red (tests written; implementation pending)

---

## Story Context

**As a** {persona}
**I want** {capability}
**So that** {outcome}

**Acceptance criteria (from story):**
1. {AC-1}
2. {AC-2}
3. {AC-3}

---

## Test Cases

### Layer: Domain (unit tests — no infrastructure)

**File:** `internal/domain/aggregates/storage_location_test.go`
**Package:** `aggregates_test`
**Dependencies:** None (pure Go)

---

#### TestStorageLocation_InitiateScan_SucceedsFromActiveState

**Maps to:** AC-1 — active locations can initiate a scan

```go
func TestStorageLocation_InitiateScan_SucceedsFromActiveState(t *testing.T) {
    t.Parallel()
    // GIVEN a storage location in Active state
    loc := domain.NewStorageLocation(
        uuid.New(),
        uuid.New(), // tenant_id
        "gs://my-bucket",
        domain.StoragePlatformGoogleDrive,
        domain.Credentials{CredentialRef: "vault://creds/tenant-a/gd-cred"},
        domain.ScanConfiguration{ResourceCapPercent: 20},
    )
    loc.ApplyEvent(domain.CredentialsValidated{...}) // transition to Active

    // WHEN InitiateScan is called
    events, err := loc.InitiateScan()

    // THEN no error is returned
    require.NoError(t, err)
    // AND a ScanInitiated event is emitted
    require.Len(t, events, 1)
    scanEvent, ok := events[0].(domain.ScanInitiated)
    require.True(t, ok)
    assert.Equal(t, loc.ID(), scanEvent.StorageLocationID)
    assert.Equal(t, domain.ScanTypeInitial, scanEvent.ScanType)
}
```

**Status:** 🔴 RED — not yet implemented

---

#### TestStorageLocation_InitiateScan_RejectsScanAlreadyInProgress

**Maps to:** AC-2 — scanning locations reject a second scan

```go
func TestStorageLocation_InitiateScan_RejectsScanAlreadyInProgress(t *testing.T) {
    t.Parallel()
    // GIVEN a storage location in Scanning state
    loc := domain.NewStorageLocation(...)
    loc.ApplyEvent(domain.CredentialsValidated{...})
    loc.ApplyEvent(domain.ScanInitiated{...}) // → Scanning state

    // WHEN InitiateScan is called again
    _, err := loc.InitiateScan()

    // THEN ErrScanInProgress is returned
    require.ErrorIs(t, err, domain.ErrScanInProgress)
}
```

**Status:** 🔴 RED — not yet implemented

---

#### TestStorageLocation_InitiateScan_RejectsPendingLocation

**Maps to:** Error scenario — pending locations cannot scan (no validated credentials yet)

```go
func TestStorageLocation_InitiateScan_RejectsPendingLocation(t *testing.T) {
    t.Parallel()
    // GIVEN a storage location in Pending state (just registered)
    loc := domain.NewStorageLocation(...)
    // no credential validation event applied → stays Pending

    // WHEN InitiateScan is called
    _, err := loc.InitiateScan()

    // THEN error is returned (not ErrScanInProgress — different condition)
    require.ErrorIs(t, err, domain.ErrCredentialsNotValidated)
}
```

**Status:** 🔴 RED — not yet implemented

---

#### TestStorageLocation_InitiateScan_RejectsDeregisteredLocation

**Maps to:** Error scenario — deregistered locations cannot scan

```go
func TestStorageLocation_InitiateScan_RejectsDeregisteredLocation(t *testing.T) {
    t.Parallel()
    loc := domain.NewStorageLocation(...)
    loc.ApplyEvent(domain.CredentialsValidated{...})
    loc.ApplyEvent(domain.StorageLocationDeregistered{...}) // → Deregistered

    _, err := loc.InitiateScan()

    require.ErrorIs(t, err, domain.ErrLocationDeregistered)
}
```

**Status:** 🔴 RED — not yet implemented

---

### Layer: Application (unit tests — mock infrastructure dependencies)

**File:** `internal/application/commands/initiate_scan_test.go`

#### TestInitiateScanHandler_Handle_LoadsAndSavesAggregate

```go
func TestInitiateScanHandler_Handle_LoadsAndSavesAggregate(t *testing.T) {
    t.Parallel()
    // GIVEN a mock repository that returns an Active storage location
    mockRepo := &MockStorageLocationRepository{}
    mockOutbox := &MockOutboxRepository{}
    handler := commands.NewInitiateScanHandler(mockRepo, mockOutbox)

    locationID := uuid.New()
    tenantID := uuid.New()
    mockRepo.On("Load", mock.Anything, locationID).Return(activeLocation(locationID, tenantID), nil)
    mockRepo.On("Save", mock.Anything, mock.AnythingOfType("*domain.StorageLocation")).Return(nil)
    mockOutbox.On("Write", mock.Anything, mock.AnythingOfType("[]domain.Event")).Return(nil)

    // WHEN the handler is called
    err := handler.Handle(context.Background(), commands.InitiateScanCommand{
        StorageLocationID: locationID,
        TenantID:          tenantID,
    })

    // THEN no error
    require.NoError(t, err)
    // AND the repository was called with the correct ID
    mockRepo.AssertCalled(t, "Load", mock.Anything, locationID)
    // AND the aggregate was saved
    mockRepo.AssertCalled(t, "Save", mock.Anything, mock.Anything)
    // AND the outbox was written
    mockOutbox.AssertCalled(t, "Write", mock.Anything, mock.Anything)
}
```

**Status:** 🔴 RED — not yet implemented

---

### Layer: Integration (requires real PostgreSQL via testcontainers-go)

**File:** `internal/infrastructure/persistence/storage_location_repo_integration_test.go`
**Build tag:** `//go:build integration`
**Run with:** `make test-integration`

#### TestStorageLocationRepository_SaveAndLoad_RoundTrip

**Maps to:** Infrastructure layer — verifies aggregate survives a round-trip through the real database

```go
//go:build integration

func TestStorageLocationRepository_SaveAndLoad_RoundTrip(t *testing.T) {
    // Uses testcontainers-go to spin up real PostgreSQL
    db := testhelper.StartPostgres(t)
    repo := persistence.NewStorageLocationRepository(db)

    // GIVEN a new storage location
    loc := domain.NewStorageLocation(uuid.New(), uuid.New(), "s3://bucket", ...)

    // WHEN saved
    err := repo.Save(context.Background(), loc)
    require.NoError(t, err)

    // AND loaded back
    loaded, err := repo.Load(context.Background(), loc.ID())
    require.NoError(t, err)

    // THEN state matches
    assert.Equal(t, loc.Status(), loaded.Status())
    assert.Equal(t, loc.TenantID(), loaded.TenantID())
}
```

**Status:** 🔴 RED — not yet implemented

---

## Test Coverage Map

| Acceptance criterion | Test case(s) | Layer |
|---------------------|-------------|-------|
| AC-1: Active locations can initiate scan | `TestStorageLocation_InitiateScan_SucceedsFromActiveState` | Domain |
| AC-2: Scanning locations reject duplicate scan | `TestStorageLocation_InitiateScan_RejectsScanAlreadyInProgress` | Domain |
| AC-3: Events are persisted atomically with aggregate | `TestInitiateScanHandler_Handle_LoadsAndSavesAggregate` | Application (mock) + Integration |
| Error: Pending location cannot scan | `TestStorageLocation_InitiateScan_RejectsPendingLocation` | Domain |
| Error: Deregistered location cannot scan | `TestStorageLocation_InitiateScan_RejectsDeregisteredLocation` | Domain |

---

## Implementation Notes for Developer

When making these tests pass, implement in this order:
1. `domain.StorageLocation.InitiateScan()` method
2. Sentinel errors: `ErrScanInProgress`, `ErrCredentialsNotValidated`, `ErrLocationDeregistered`
3. `domain.ScanInitiated` event type
4. `commands.InitiateScanHandler`
5. `persistence.StorageLocationRepository` (integration test last)
```

## Quality Checks
- [ ] Every acceptance criterion from the story has at least one test case
- [ ] Every error/edge-case scenario from example mapping has a test case
- [ ] Domain layer tests have zero infrastructure dependencies
- [ ] Integration tests are tagged with `//go:build integration`
- [ ] All tests are marked 🔴 RED — no implementation code present yet
- [ ] Test names follow `Test{Type}_{Method}_{Scenario}` convention
