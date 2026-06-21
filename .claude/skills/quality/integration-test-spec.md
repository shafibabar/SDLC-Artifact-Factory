# Skill: quality/integration-test-spec

## Purpose
Produce an Integration Test Specification for one domain boundary — the tests that verify a service's infrastructure adapters (repositories, event publishers, event consumers) work correctly with real infrastructure. Real PostgreSQL (testcontainers-go), real Redpanda, real Elasticsearch. No mocks at integration boundaries.

## Inputs
- `artifacts/data/models/{entity}.md`
- `artifacts/design/architecture/integration-design.md`
- `artifacts/quality/test-plan.md`
- **Arguments required:** boundary name (e.g. `file-domain-postgres`, `entity-domain-redpanda`)

## Output
**File:** `artifacts/quality/integration/{boundary}.md`
**Registers in manifest:** yes

## Integration Test Rules (enforced)
- Build tag `//go:build integration` on all integration test files.
- `testcontainers-go` starts real infrastructure before the test suite and tears it down after.
- Tests run migrations before the first test in the suite.
- Each test function is responsible for its own data setup and teardown (no shared state between tests).
- Idempotency is tested explicitly: run the same operation twice, assert the same outcome.

## Artifact Template

```markdown
# Integration Test Specification: {boundary}

**Product:** {product_name}
**Phase:** Quality
**Artifact:** Integration Test Specification
**Boundary:** {boundary name}
**Service:** {service name}
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Boundary Under Test

**Adapter:** `internal/infrastructure/persistence/postgres_storage_location_repository.go`
**Interface:** `domain.StorageLocationRepository`
**Infrastructure:** PostgreSQL (real, via testcontainers-go)

---

## Test Suite Structure

```go
//go:build integration

package persistence_test

import (
    "context"
    "testing"

    "github.com/stretchr/testify/suite"
    "github.com/testcontainers/testcontainers-go/modules/postgres"
)

type StorageLocationRepositoryIntegrationSuite struct {
    suite.Suite
    pgContainer *postgres.PostgresContainer
    repo        domain.StorageLocationRepository
    db          *pgxpool.Pool
}

func TestStorageLocationRepositoryIntegration(t *testing.T) {
    suite.Run(t, new(StorageLocationRepositoryIntegrationSuite))
}

func (s *StorageLocationRepositoryIntegrationSuite) SetupSuite() {
    ctx := context.Background()

    // Start real PostgreSQL
    pgContainer, err := postgres.RunContainer(ctx,
        testcontainers.WithImage("postgres:16-alpine"),
        postgres.WithDatabase("file_domain_test"),
        postgres.WithUsername("test"),
        postgres.WithPassword("test"),
        testcontainers.WithWaitStrategy(
            wait.ForLog("database system is ready to accept connections"),
        ),
    )
    s.Require().NoError(err)
    s.pgContainer = pgContainer

    connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
    s.Require().NoError(err)

    // Apply migrations
    m, err := migrate.New("file://../../migrations", connStr)
    s.Require().NoError(err)
    s.Require().NoError(m.Up())

    // Build repo
    pool, err := pgxpool.New(ctx, connStr)
    s.Require().NoError(err)
    s.db = pool
    s.repo = persistence.NewPostgresStorageLocationRepository(pool)
}

func (s *StorageLocationRepositoryIntegrationSuite) TearDownSuite() {
    s.db.Close()
    s.Require().NoError(s.pgContainer.Terminate(context.Background()))
}

func (s *StorageLocationRepositoryIntegrationSuite) SetupTest() {
    // Clean tenant data before each test
    _, err := s.db.Exec(context.Background(),
        "DELETE FROM storage_locations WHERE tenant_id = $1", testTenantID)
    s.Require().NoError(err)
}
```

---

## Test Cases

### Save and FindByID (Round-Trip)

```
Test: Repository_SaveAndFindByID_RoundTrip
Given: A new StorageLocation aggregate
When: Save is called, then FindByID with the same ID
Then: The returned aggregate matches the saved aggregate (all fields)
```

**Assertions:**
- `sl.ID()` matches
- `sl.Platform()` matches
- `sl.StoragePath()` matches
- `sl.Status()` is PENDING (initial state)
- `sl.TenantID()` matches
- `sl.CreatedAt()` is non-zero

---

### Tenant Isolation

```
Test: Repository_FindByID_ReturnsNotFoundForOtherTenant
Given: A StorageLocation saved under tenant_id = T1
When: FindByID called with the correct ID but tenant_id = T2
Then: Returns ErrNotFound (not the record)
```

This test verifies that the repository enforces tenant scope. A cross-tenant read returning data is a security defect — this test must be present.

---

### Idempotency — Outbox

```
Test: Repository_SaveWithOutbox_Idempotent
Given: A StorageLocation with an outbox event (idempotency_key = "key-001")
When: Save is called twice with the same idempotency_key
Then: The second save does not create a duplicate outbox entry (ON CONFLICT DO NOTHING)
And: No error is returned
```

---

### Soft Delete

```
Test: Repository_Delete_SetsDeletedAt
Given: A saved StorageLocation
When: Delete(id) is called
Then: deleted_at IS NOT NULL in the database
And: FindByID returns ErrNotFound (deleted records excluded from queries)
And: The record is still visible to forensic queries (raw SELECT without filter)
```

---

### List with Pagination

```
Test: Repository_List_ReturnsCursorPagedResults
Given: 30 StorageLocations saved for tenant T1
When: List called with cursor=nil, pageSize=10
Then: Returns 10 records and a non-nil next cursor
When: List called with the returned cursor, pageSize=10
Then: Returns the next 10 records (no duplicates, no gaps)
```

---

## Event Consumer Integration Test

**Adapter:** `internal/infrastructure/messaging/file_event_consumer.go`
**Infrastructure:** Redpanda (real, via testcontainers-go)

```
Test: Consumer_FileProcessed_EnqueuesCommand
Given: Redpanda topic "file-domain.file-processed" contains a FileProcessed event
When: The consumer processes the message
Then: An InitiateScan command is enqueued for the referenced aggregate
And: The event is marked as processed in file_processed_events table
And: A duplicate message is discarded (idempotency check)
```
```

## Quality Checks
- [ ] `//go:build integration` build tag on all test files
- [ ] testcontainers-go starts real PostgreSQL (not SQLite, not in-memory)
- [ ] Migrations run via golang-migrate before tests
- [ ] SetupTest cleans data between tests — no shared state
- [ ] Tenant isolation test is present (cross-tenant read must return not-found)
- [ ] Idempotency is explicitly tested (duplicate save / duplicate event)
- [ ] Soft delete test verifies record still exists in raw DB (for audit)
- [ ] Pagination cursor test covers multi-page traversal
