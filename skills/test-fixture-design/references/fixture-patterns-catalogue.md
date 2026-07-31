# Fixture Patterns Catalogue

Reference for `skills/test-fixture-design`. Self-contained: every section can
be loaded independently without the parent `SKILL.md` body in context. Covers
all Go code examples for the patterns the SKILL.md body describes conceptually.

---

## Test Data Builder

The Test Data Builder applies the builder pattern to test data construction. It
provides a struct with sensible defaults for every field and a fluent API that
lets each test override only the fields relevant to that test's specific
scenario. The result: tests express intent rather than noise.

**Maintainability rationale:** when a domain type gains a new field, the change
breaks exactly one place — the builder's default — rather than every test that
previously constructed the type inline. This is Khorikov's maintainability
pillar applied to test data: a builder concentrates construction knowledge so
test failures are test-intent failures, not "I forgot to update the constructor
call in 40 files."

```go
// internal/test/builders/dataasset.go

package builders

import (
    "github.com/google/uuid"
    "acme/internal/domain"
)

type dataAssetFields struct {
    id          uuid.UUID
    tenantID    uuid.UUID
    sourceID    string
    sensitivity domain.SensitivityLevel
    version     int
}

// DataAssetBuilder creates domain.DataAsset values for tests.
// Call NewDataAsset() for an asset with sensible defaults, then
// chain With* methods to override only what the test cares about.
type DataAssetBuilder struct {
    fields dataAssetFields
}

func NewDataAsset() *DataAssetBuilder {
    return &DataAssetBuilder{fields: dataAssetFields{
        id:          uuid.New(),
        tenantID:    uuid.New(),
        sourceID:    "source-default",
        sensitivity: domain.SensitivityUnclassified,
        version:     1,
    }}
}

func (b *DataAssetBuilder) WithID(id uuid.UUID) *DataAssetBuilder {
    b.fields.id = id
    return b
}

func (b *DataAssetBuilder) WithTenant(id uuid.UUID) *DataAssetBuilder {
    b.fields.tenantID = id
    return b
}

func (b *DataAssetBuilder) WithSource(sourceID string) *DataAssetBuilder {
    b.fields.sourceID = sourceID
    return b
}

func (b *DataAssetBuilder) Classified(l domain.SensitivityLevel) *DataAssetBuilder {
    b.fields.sensitivity = l
    return b
}

func (b *DataAssetBuilder) AtVersion(v int) *DataAssetBuilder {
    b.fields.version = v
    return b
}

func (b *DataAssetBuilder) Build() *domain.DataAsset {
    return domain.Reconstitute(
        b.fields.id,
        b.fields.tenantID,
        b.fields.sourceID,
        b.fields.sensitivity,
        b.fields.version,
    )
}
```

**Test usage — only the relevant detail is stated:**

```go
func TestClassifyDataAsset(t *testing.T) {
    tenantID := uuid.New()

    // Test only cares about the tenant and the starting sensitivity:
    asset := builders.NewDataAsset().
        WithTenant(tenantID).
        Classified(domain.SensitivityUnclassified).
        Build()

    // Act and assert against the domain behavior, not the construction.
}
```

---

## Object Mother

The Object Mother pattern creates named factory functions that return complete,
pre-configured objects for recurring test scenarios. Where a builder provides a
fluent API for targeted overrides, an Object Mother provides a single call that
returns a specific, named fixture — no fields to specify, no chain to write.

**When to prefer Object Mother over builder:**
- The same configuration recurs across many tests and its details are not the
  subject of any individual test.
- You want to give a canonical name to a configuration that represents a
  meaningful business scenario ("a restricted asset," "an active tenant").

**When to prefer builder over Object Mother:**
- A single test needs to override one specific field to exercise a boundary.
- Tests differ in which fields matter — a builder's targeted-override idiom
  expresses each test's specific concern more clearly.

A codebase may use both: builders for fine-grained per-test variation, Object
Mothers for stable reference configurations shared across the suite.

```go
// internal/test/mothers/assets.go

package mothers

import (
    "github.com/google/uuid"
    "acme/internal/domain"
    "acme/internal/test/builders"
)

// MakeUnclassifiedAsset returns a data asset with default sensitivity.
// Use this when the test cares about something other than sensitivity level.
func MakeUnclassifiedAsset(tenantID uuid.UUID) *domain.DataAsset {
    return builders.NewDataAsset().
        WithTenant(tenantID).
        Classified(domain.SensitivityUnclassified).
        Build()
}

// MakeClassifiedAsset returns a data asset already classified as Restricted.
// Use this when the test is about behavior that applies to classified assets.
func MakeClassifiedAsset(tenantID uuid.UUID) *domain.DataAsset {
    return builders.NewDataAsset().
        WithTenant(tenantID).
        Classified(domain.SensitivityRestricted).
        Build()
}

// MakeArchivedAsset returns a data asset in the Archived lifecycle state.
// Use this when the test is about post-archive behavior (e.g., access denial).
func MakeArchivedAsset(tenantID uuid.UUID) *domain.DataAsset {
    return builders.NewDataAsset().
        WithTenant(tenantID).
        Classified(domain.SensitivityRestricted).
        AtVersion(5). // archived assets accumulate versions
        Build()
}
```

**Test usage — named scenario, no field noise:**

```go
func TestAccessDenied_WhenAssetIsArchived(t *testing.T) {
    tenantID := uuid.New()
    asset := mothers.MakeArchivedAsset(tenantID)
    // The test is about archived-asset access policy, not asset construction.
}
```

Object Mothers can span multiple domain types. A tenant-level mother creates a
fully-configured tenant record in the repository — useful when the test is about
tenant-scoped behavior, not about the asset inside it:

```go
// internal/test/mothers/tenants.go

package mothers

import (
    "context"
    "testing"
    "github.com/google/uuid"
    "github.com/jackc/pgx/v5/pgxpool"
    "acme/internal/domain"
    "acme/internal/infrastructure/postgres"
)

// SeedActiveTenant inserts a fully-configured, active tenant into the database
// and registers cleanup. Use when the test is about behavior that applies to
// any active tenant (not about the tenant's specific configuration).
// Returns the tenant ID for use in further fixture setup.
func SeedActiveTenant(t *testing.T, pool *pgxpool.Pool) uuid.UUID {
    t.Helper()
    id := uuid.New()
    repo := postgres.NewTenantRepository(pool)
    err := repo.Save(context.Background(), domain.NewTenant(id, "test-tenant", domain.TenantStatusActive))
    if err != nil {
        t.Fatalf("SeedActiveTenant: %v", err)
    }
    t.Cleanup(func() {
        _, _ = pool.Exec(context.Background(), "DELETE FROM tenants WHERE id = $1", id)
    })
    return id
}
```

---

## t.Cleanup Teardown

`t.Cleanup` registers a teardown function that runs when the test finishes —
whether the test passes, fails, or panics. Registrations run in reverse order
(LIFO), so a dependency set up first is torn down last. This is the correct
place for all test teardown.

**Why not `defer` in a helper?**

`defer` in a helper function fires when the *helper* returns, not when the test
ends. If a helper sets up a database connection and defers its close, the
connection closes before the test body even starts. `t.Cleanup` scopes teardown
to the test, not the helper.

```go
// internal/test/fixtures.go

package test

import (
    "context"
    "testing"
    "github.com/jackc/pgx/v5/pgxpool"
)

// SetupTestDB opens a connection pool, runs migrations, and registers cleanup.
// Call at the start of any integration test that needs a real database.
// The pool is valid for the lifetime of the calling test.
func SetupTestDB(t *testing.T) *pgxpool.Pool {
    t.Helper()
    pool := connectTestPool(t)       // opens the pool from the container URL
    runMigrations(t, pool)           // applies real migration chain
    t.Cleanup(func() {
        truncateAll(pool)            // wipes data in reverse migration order
        pool.Close()                 // returns the connection to the pool
    })
    return pool
}

// FreshTenant creates a unique tenant ID for one test and registers cleanup
// that deletes all rows owned by that tenant. Gives each test its own data
// namespace so parallel tests never collide.
func FreshTenant(t *testing.T, pool *pgxpool.Pool) uuid.UUID {
    t.Helper()
    id := uuid.New()
    t.Cleanup(func() {
        _, _ = pool.Exec(context.Background(),
            "DELETE FROM data_assets WHERE tenant_id = $1", id)
    })
    return id
}
```

**Why not `TestMain` teardown?**

`TestMain` teardown is too coarse: it fires after the entire package finishes,
not after each test. A test that leaks data will affect subsequent tests in the
package before `TestMain` ever runs. `t.Cleanup` gives per-test scope.

---

## Deterministic Data

A test that sometimes fails because of a non-deterministic value (the wall
clock, an unseeded random) is flaky by construction. Fix the sources of
non-determinism before writing the test, not after.

**Fixed clock:**

```go
// testTime is a fixed timestamp shared across fixture helpers in this package.
// Use it wherever the code under test accepts a time.Time parameter.
var testTime = time.Date(2026, 1, 15, 12, 0, 0, 0, time.UTC)

// In the test:
asset, err := svc.Classify(ctx, assetID, domain.SensitivityRestricted, testTime)
require.NoError(t, err)
assert.Equal(t, testTime, asset.ClassifiedAt()) // deterministic assertion
```

**Explicit IDs when the test asserts on them:**

```go
// When the test asserts on an ID, use a fixed one so the assertion is stable.
var knownID = uuid.MustParse("12345678-1234-1234-1234-123456789012")

asset := builders.NewDataAsset().WithID(knownID).Build()
// Now: assert.Equal(t, knownID, asset.ID()) — not "assert something is a UUID."
```

**Seeded randomness:**

```go
// If the code under test uses a PRNG, inject a seeded one so the sequence is
// reproducible. Never call top-level math/rand without seeding in test context.
rng := rand.New(rand.NewSource(42)) // fixed seed, fixed sequence
result := myFunc(rng)
```

---

## Golden Files

A golden file stores the expected output for a test as a file in `testdata/`.
The test reads the golden file and compares the actual output to it. A
`-update` flag regenerates golden files when the expected output changes
intentionally.

**When to use golden files:**
- The expected output is large (a full JSON response, a rendered report, a
  serialized event payload).
- Embedding the expected output inline would make the test unreadable.
- The output is stable across runs (after normalization — see below).

```go
// internal/test/golden.go

package test

import (
    "flag"
    "os"
    "path/filepath"
    "testing"

    "github.com/stretchr/testify/require"
)

var updateGolden = flag.Bool("update", false, "rewrite golden files on test run")

// AssertGolden compares got against the golden file at testdata/<name>.golden.
// Run with -update to rewrite the golden file when the output changes
// intentionally: go test ./... -update
// Never run -update to silence a failure you don't understand — updating a
// golden file is approving a behavior change; the diff must be reviewed.
func AssertGolden(t *testing.T, name string, got []byte) {
    t.Helper()
    path := filepath.Join("testdata", name+".golden")
    if *updateGolden {
        require.NoError(t, os.MkdirAll("testdata", 0o755))
        require.NoError(t, os.WriteFile(path, got, 0o644))
        t.Logf("updated golden file: %s", path)
        return
    }
    want, err := os.ReadFile(path)
    require.NoError(t, err, "missing golden file — run: go test ./... -update")
    require.Equal(t, string(want), string(got),
        "output differs from golden file %s — if intentional, run: go test ./... -update", name)
}
```

**Normalize before comparing:**

Strip non-deterministic fields (timestamps, generated IDs, request trace IDs)
before writing to or asserting against a golden file. Otherwise the file will
change on every run and `-update` becomes the only way to stay green.

```go
type apiResponse struct {
    ID        string `json:"id"`
    CreatedAt string `json:"created_at"` // non-deterministic
    Data      string `json:"data"`
}

func normalizeForGolden(r apiResponse) apiResponse {
    r.ID = "{{id}}"          // replace with stable placeholder
    r.CreatedAt = "{{ts}}"   // replace with stable placeholder
    return r
}

// In the test:
got, _ := json.Marshal(normalizeForGolden(response))
test.AssertGolden(t, "classify-response", got)
```

Golden files live in `testdata/` (the Go toolchain ignores this directory).
They are committed to source control and reviewed in pull requests — a diff in
a golden file is a visible, reviewable behavior change.

---

## Parallel-Safe Isolation

When integration tests share one Testcontainers database (the `TestMain`
per-package shared container from `go-integration-test`), parallel tests must
not collide on the same rows. Two strategies:

### Tenant-scoped isolation (default for this repo)

Each test creates a unique `tenant_id` via `FreshTenant`. Because the product's
physical multi-tenancy model scopes every row to a tenant, each test's data is
automatically invisible to every other test's queries.

```go
func TestRepository_ListAssets_FiltersByTenant(t *testing.T) {
    t.Parallel()
    pool := test.SharedPool(t)             // package-level shared container
    tenantID := test.FreshTenant(t, pool)  // unique per test; cleanup registered

    // All data written here is scoped to tenantID.
    // Another parallel test's FreshTenant gives a different UUID.
    // The two tests are fully isolated without transactions.
}
```

### Transaction rollback (for tests that need real commits)

Some tests cannot use the uncommitted-wrapper default because their subject
*is* commit behavior (outbox atomicity, real concurrent-update conflict). These
tests use real commits scoped to a `FreshTenant` and rely on `t.Cleanup` to
delete only that tenant's data afterward.

The detailed tradeoff between transaction rollback and tenant-scoped commits,
including the specific exception cases for outbox and concurrent-CAS tests, is
in `go-integration-test`'s `references/test-isolation-standard.md`.

---

## Unit-Layer vs. Integration-Layer Fixtures

The correct fixture shape depends on the test layer. Using a builder where an
inline literal suffices adds indirection; using an inline literal where a
builder is needed creates brittle, coupled tests.

| Criterion | Unit layer (`go-unit-test`) | Integration/E2E layer |
|---|---|---|
| **Shape** | Inline struct literal, one per table row | Builder or Object Mother + t.Cleanup helper |
| **Rationale** | Test is small, self-contained; inline literal is readable with full context visible | Real database setup requires more structure; builder isolates test from construction detail |
| **State sharing** | Each table row owns its own literal; no shared state | `FreshTenant` or transaction-rollback gives per-test isolation |
| **Cleanup** | None needed — unit tests have no side effects | `t.Cleanup` always registered at fixture creation |
| **Example** | `input: domain.DataAsset{Sensitivity: domain.SensitivityRestricted}` | `asset := builders.NewDataAsset().Classified(Restricted).Build()` + `FreshTenant` |

**Decision rule:** if the test touches a real database (Testcontainers, via
`go-integration-test`), use builders and `t.Cleanup` helpers. If the test is a
pure Go function call with no real I/O, use inline struct literals and skip the
builder entirely.
