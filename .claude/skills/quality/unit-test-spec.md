# Skill: quality/unit-test-spec

## Purpose
Produce a Unit Test Specification for one module within a service — the complete set of unit tests that must be written before implementation code is generated. This is the TDD Red phase document for a specific package. Developers write these tests first, watch them fail, then write the implementation.

## Inputs
- `artifacts/implement/specs/{story-id}-tdd-spec.md` (if story-scoped)
- `artifacts/design/domain/aggregates/{name}.md`
- `artifacts/design/domain/events.md`
- `artifacts/quality/test-plan.md`
- **Arguments required:** service name, module path (e.g. `file-domain`, `internal/domain/aggregates/storage_location`)

## Output
**File:** `artifacts/quality/unit/{service}/{module}.md`
**Registers in manifest:** yes

## Unit Test Rules (enforced)
- Zero I/O: no database, no network, no filesystem. If a test touches I/O, it is not a unit test.
- Table-driven tests (`testify/suite` or `go test` table pattern) for all multi-scenario cases.
- `t.Parallel()` is called in every test function and every subtest.
- Test names: `Test{Type}_{Method}_{StateUnderTest}` pattern (from TDD spec skill).
- Aggregate tests: domain methods must be testable by inspecting returned `[]DomainEvent` — never by inspecting internal state directly.

## Artifact Template

```markdown
# Unit Test Specification: {Service} / {Module}

**Product:** {product_name}
**Phase:** Quality
**Artifact:** Unit Test Specification
**Service:** {service name}
**Module:** `{go package path}`
**Version:** 1.0
**Date:** {date}
**Status:** Approved
**Coverage target:** 90% (domain/aggregates) | 80% (application/commands) | 75% (api/handlers)

---

## Module Under Test

**Package:** `internal/domain/aggregates`
**Type:** `StorageLocation`
**Responsibility:** Enforce StorageLocation lifecycle invariants. Emit domain events on state transitions.

---

## Test Suite: StorageLocation Aggregate

### TestStorageLocation_Register

| Test case | Initial state | Input | Expected domain events | Expected error |
|-----------|--------------|-------|----------------------|----------------|
| `Succeeds_WithValidPlatformAndPath` | n/a (constructor) | platform=GOOGLE_DRIVE, path="drive://HR", credRef="vault://..." | `[StorageLocationRegistered]` | nil |
| `RejectsEmptyPath` | n/a | path="" | `[]` | `ErrInvalidStoragePath` |
| `RejectsUnknownPlatform` | n/a | platform="DROPBOX_V2" | `[]` | `ErrUnsupportedPlatform` |
| `RejectsInvalidCredentialRef` | n/a | credRef="MY_KEY" (no scheme) | `[]` | `ErrInvalidCredentialRef` |

```go
func TestStorageLocation_Register(t *testing.T) {
    t.Parallel()

    cases := []struct {
        name           string
        platform       string
        storagePath    string
        credRef        string
        wantEventType  string
        wantErr        error
    }{
        {
            name:          "Succeeds_WithValidPlatformAndPath",
            platform:      "GOOGLE_DRIVE",
            storagePath:   "drive://hr-documents",
            credRef:       "vault://tenants/acme/google-drive-credentials",
            wantEventType: "StorageLocationRegistered",
            wantErr:       nil,
        },
        {
            name:        "RejectsEmptyPath",
            platform:    "GOOGLE_DRIVE",
            storagePath: "",
            credRef:     "vault://tenants/acme/creds",
            wantErr:     ErrInvalidStoragePath,
        },
        {
            name:        "RejectsUnknownPlatform",
            platform:    "DROPBOX_V2",
            storagePath: "path",
            credRef:     "vault://tenants/acme/creds",
            wantErr:     ErrUnsupportedPlatform,
        },
        {
            name:        "RejectsInvalidCredentialRef",
            platform:    "GOOGLE_DRIVE",
            storagePath: "path",
            credRef:     "MY_KEY",
            wantErr:     ErrInvalidCredentialRef,
        },
    }

    for _, tc := range cases {
        tc := tc
        t.Run(tc.name, func(t *testing.T) {
            t.Parallel()

            sl, events, err := NewStorageLocation(tc.platform, tc.storagePath, tc.credRef)

            if tc.wantErr != nil {
                require.ErrorIs(t, err, tc.wantErr)
                assert.Nil(t, sl)
                assert.Empty(t, events)
                return
            }

            require.NoError(t, err)
            require.Len(t, events, 1)
            assert.Equal(t, tc.wantEventType, events[0].EventType())
        })
    }
}
```

---

### TestStorageLocation_InitiateScan

| Test case | Initial state | Expected events | Expected error |
|-----------|--------------|-----------------|----------------|
| `Succeeds_FromActiveState` | ACTIVE | `[ScanInitiated]` | nil |
| `RejectsScanAlreadyInProgress` | SCANNING | `[]` | `ErrScanAlreadyInProgress` |
| `RejectsPendingLocation` | PENDING | `[]` | `ErrLocationNotActive` |
| `RejectsDeregisteredLocation` | DEREGISTERED | `[]` | `ErrLocationDeregistered` |

```go
func TestStorageLocation_InitiateScan(t *testing.T) {
    t.Parallel()

    cases := []struct {
        name       string
        setupState func() *StorageLocation
        wantEvents int
        wantErr    error
    }{
        {
            name:       "Succeeds_FromActiveState",
            setupState: func() *StorageLocation { return activeStorageLocation(t) },
            wantEvents: 1,
            wantErr:    nil,
        },
        {
            name:       "RejectsScanAlreadyInProgress",
            setupState: func() *StorageLocation { return scanningStorageLocation(t) },
            wantErr:    ErrScanAlreadyInProgress,
        },
        // ... etc
    }

    for _, tc := range cases {
        tc := tc
        t.Run(tc.name, func(t *testing.T) {
            t.Parallel()
            sl := tc.setupState()
            events, err := sl.InitiateScan()
            if tc.wantErr != nil {
                require.ErrorIs(t, err, tc.wantErr)
                assert.Empty(t, events)
                return
            }
            require.NoError(t, err)
            require.Len(t, events, tc.wantEvents)
            assert.Equal(t, "ScanInitiated", events[0].EventType())
        })
    }
}
```

---

### TestStorageLocation_Deregister

| Test case | Initial state | Expected events | Expected error |
|-----------|--------------|-----------------|----------------|
| `Succeeds_FromActiveState` | ACTIVE | `[StorageLocationDeregistered]` | nil |
| `Succeeds_FromScanErrorState` | SCAN_ERROR | `[StorageLocationDeregistered]` | nil |
| `RejectsAlreadyDeregistered` | DEREGISTERED | `[]` | `ErrAlreadyDeregistered` |
| `RejectsWhileScanning` | SCANNING | `[]` | `ErrScanInProgress` |

---

## Test Helpers

```go
// test helpers live in package aggregates_test

func activeStorageLocation(t *testing.T) *StorageLocation {
    t.Helper()
    sl, _, err := NewStorageLocation("GOOGLE_DRIVE", "drive://hr", "vault://creds")
    require.NoError(t, err)
    _, err = sl.Activate()
    require.NoError(t, err)
    return sl
}

func scanningStorageLocation(t *testing.T) *StorageLocation {
    t.Helper()
    sl := activeStorageLocation(t)
    _, err := sl.InitiateScan()
    require.NoError(t, err)
    return sl
}
```

---

## Forbidden Patterns

The following patterns are defects in unit tests for this module:

- Calling any function that opens a database connection
- Using `time.Sleep` — use deterministic time injection
- Inspecting `sl.status` directly — only inspect returned events
- Using `mock.Anything` for domain argument checks — assert exact values
```

## Quality Checks
- [ ] Zero I/O — no db, no network, no filesystem access in any test case
- [ ] `t.Parallel()` appears in every test function
- [ ] Table-driven pattern used for all multi-scenario cases
- [ ] Test naming follows `Test{Type}_{Method}_{StateUnderTest}`
- [ ] Tests assert on returned events, not on aggregate internal state
- [ ] Test helpers are defined for common state setup
- [ ] Forbidden patterns section is present
