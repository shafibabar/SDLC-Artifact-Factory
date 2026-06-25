---
name: test-fixture-design
description: >
  Teaches how to design hermetic test fixtures and data — the builder pattern for
  readable test data, deterministic seeding, per-test setup and teardown that
  prevents test pollution, golden files for complex outputs, the t.Cleanup pattern,
  parallel-safe data isolation (unique tenants/ids per test), and keeping fixtures
  DRY without coupling tests. Hermetic fixtures are what make integration and e2e
  tests reliable. Used by the test-strategist during Implement.
version: 1.0.0
phase: implement
owner: test-strategist
tags: [implement, go, fixtures, test-data, hermetic, builder, seeding, cleanup]
---

# Test Fixture Design

## Purpose

Most test flakiness traces back to data: a test that depends on data another test created, state left behind from a previous run, or non-deterministic values. Hermetic fixtures eliminate this — every test sets up exactly the data it needs, owns it exclusively, and cleans up after itself, so tests are independent, repeatable, and safe to run in parallel and in any order.

This skill underpins `go-unit-test` (in-memory fixtures), `go-integration-test`, and `go-e2e-test` (real-data seeding). Reliable higher-layer tests are impossible without disciplined fixtures.

---

## Hermetic Principle

A hermetic test:
1. **Creates** the state it needs (no reliance on pre-existing data).
2. **Owns** that state exclusively (no sharing with other tests).
3. **Cleans up** afterward (no residue for the next test).

The result: the test passes or fails based only on the code under test — never on execution order, leftover data, or a neighbour's side effects. Order-independence is the litmus test: `go test -shuffle=on` must stay green.

---

## The Builder Pattern for Test Data

Test data should be readable and express only what matters to the test. The builder pattern provides sensible defaults and lets each test override just the relevant field — so the test's intent is obvious and a new field doesn't break every fixture.

```go
// internal/test/builders/dataasset.go
type DataAssetBuilder struct{ a assetFields }

func NewDataAsset() *DataAssetBuilder {
    return &DataAssetBuilder{a: assetFields{           // sensible defaults
        id: uuid.New(), tenantID: uuid.New(),
        sensitivity: domain.SensitivityUnclassified, version: 1,
    }}
}
func (b *DataAssetBuilder) WithTenant(id uuid.UUID) *DataAssetBuilder { b.a.tenantID = id; return b }
func (b *DataAssetBuilder) Classified(l domain.SensitivityLevel) *DataAssetBuilder { b.a.sensitivity = l; return b }
func (b *DataAssetBuilder) Build() *domain.DataAsset { return domain.Reconstitute(b.a.id, b.a.tenantID, b.a.sourceID, b.a.sensitivity, b.a.version) }

// In a test — only the relevant detail is stated:
asset := NewDataAsset().WithTenant(tenantID).Classified(domain.SensitivityRestricted).Build()
```

Defaults absorb irrelevant detail; overrides spotlight what the test is actually about.

---

## Deterministic Data

Tests must be reproducible, so randomness is controlled:

- **Seed PRNGs** with a fixed value when randomness is needed, or use fixed values.
- **Inject time** — never `time.Now()` in the code under test; pass a fixed clock (the domain takes `now time.Time`). Fixtures use a fixed `testTime`.
- **Generate ids explicitly** — a builder assigns a known UUID, or a fixed one when the test asserts on it.

```go
var testTime = time.Date(2026, 1, 15, 12, 0, 0, 0, time.UTC) // fixed clock for assertions
```

A test that sometimes fails because of a random value or the wall clock is a flaky test by construction.

---

## Setup and Teardown with t.Cleanup

`t.Cleanup` registers teardown next to setup, runs in reverse order, and fires even if the test fails — the cleanest way to guarantee no residue.

```go
func setupTestDB(t *testing.T) *pgxpool.Pool {
    t.Helper()
    pool := connectTestPool(t)
    t.Cleanup(func() { truncateAll(pool); pool.Close() }) // always runs, even on failure
    return pool
}
```

Prefer `t.Cleanup` over `defer` in helpers (defer in a helper fires when the *helper* returns, not the test) and over `TestMain` teardown (too coarse). Setup and its matching cleanup live together, so neither is forgotten.

---

## Parallel-Safe Isolation

Parallel tests sharing a database must not collide. Isolate by **scoping each test to a unique tenant** (the physical multi-tenancy model makes this natural) — each test creates its own `tenant_id`, so its data never intersects another's.

```go
func freshTenant(t *testing.T) uuid.UUID {
    id := uuid.New()                              // unique per test
    t.Cleanup(func() { deleteTenantData(id) })     // scoped cleanup
    return id
}
```

This lets integration tests run in parallel against one shared database without a transaction-per-test or order dependence. (Where stronger isolation is needed, run each test in a transaction rolled back at cleanup.)

---

## Golden Files for Complex Output

When asserting on a large, stable output (a generated report, a serialized event, an API response body), compare against a **golden file** rather than a giant inline literal. An `-update` flag regenerates them on intentional change.

```go
func assertGolden(t *testing.T, name string, got []byte) {
    t.Helper()
    path := filepath.Join("testdata", name+".golden")
    if *update { os.WriteFile(path, got, 0o644); return } // go test -update on intended changes
    want, _ := os.ReadFile(path)
    require.Equal(t, string(want), string(got))
}
```

Golden files live in `testdata/` (ignored by the Go toolchain) and are reviewed in PRs — a diff in a golden file is a visible, reviewable behaviour change.

---

## DRY Without Coupling

Fixtures are shared (builders, helpers) but tests stay independent: a shared *builder* is good (reuse construction); a shared *mutable fixture instance* across tests is bad (couples them). Share the means of creating data, never a live data object two tests both touch.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Hermetic | Each test creates/owns/cleans its data | Tests depending on shared/leftover data |
| Order-independent | `go test -shuffle=on` stays green | Failures when test order changes |
| Builders | Readable builders with defaults + overrides | Giant inline literals; brittle fixtures |
| Deterministic | Fixed clock/ids/seed | Wall-clock or random values in assertions |
| Cleanup guaranteed | `t.Cleanup` fires on success and failure | Leaked data; teardown skipped on failure |
| Parallel-safe | Per-test tenant/tx isolation | Parallel tests colliding on shared rows |
| Golden for big output | `testdata/*.golden` + `-update` | Massive inline expected blobs |

---

## Output Format

Produces fixtures, builders, and test data:

```
internal/test/builders/*.go            (data builders)
internal/test/fixtures.go               (setup/cleanup helpers: setupTestDB, freshTenant)
**/testdata/*.golden                    (golden files for complex outputs)
```
