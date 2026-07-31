---
name: test-fixture-design
description: >
  Used by the test-strategist during Implement to design hermetic test fixtures
  and test data for Go services. Covers the Test Data Builder pattern (fluent
  builder with sensible defaults, override only what the test cares about — the
  foundation go-unit-test and go-integration-test assume when they mention
  fixtures), the Object Mother pattern (named pre-configured objects for
  recurring test scenarios, distinct from the fluent builder), the hermetic
  fixture principle (each test creates, owns, and cleans exactly its data),
  t.Cleanup for guaranteed teardown regardless of pass or fail, deterministic
  data (fixed clock, explicit IDs, seeded randomness), golden files for complex
  outputs, parallel-safe isolation via unique tenant IDs or transaction rollback
  (cross-references go-integration-test's test-isolation-standard.md for the
  rollback-vs-tenant tradeoff), and the unit-vs-integration fixture strategy
  (inline struct literals for unit-layer tests, builders and t.Cleanup helpers
  for integration and e2e layers). Full Go code examples and the Object Mother
  pattern catalogue: references/fixture-patterns-catalogue.md.
version: 2.0.0
phase: implement
owner: test-strategist
created: 2026-06-25
tags: [implement, go, fixtures, test-data, hermetic, builder, object-mother, test-data-builder, seeding, cleanup, testcontainers]
related: [go-unit-test, go-integration-test, go-e2e-test, mock-generation]
---

# Test Fixture Design

## Purpose

Most test flakiness traces back to data: a test that depends on data another
test created, state left behind from a previous run, or non-deterministic
values. Hermetic fixtures eliminate this — every test sets up exactly the data
it needs, owns it exclusively, and cleans up after itself, so tests are
independent, repeatable, and safe to run in parallel and in any order.

This skill underpins `go-unit-test` (inline fixtures), `go-integration-test`
(real-data seeding with Testcontainers), and `go-e2e-test` (ephemeral
environment seeding). Reliable higher-layer tests are impossible without
disciplined fixtures.

---

## Hermetic Principle

A hermetic test:
1. **Creates** the state it needs — no reliance on pre-existing or ambient data.
2. **Owns** that state exclusively — no sharing with other tests.
3. **Cleans up** afterward — no residue for the next test or the next run.

The order-independence litmus test: `go test -shuffle=on` must stay green.
A test that passes in isolation but fails in sequence has a hermetic violation.

---

## Unit vs. Integration Fixture Strategy

The right fixture shape depends on the test layer:

| Layer | Fixture shape | Pattern |
|---|---|---|
| Unit (`go-unit-test`) | Inline struct literals, one per table row | No builders needed — small, readable, zero shared state |
| Integration/E2E (`go-integration-test`, `go-e2e-test`) | Builders + `t.Cleanup` helpers | Test Data Builder or Object Mother + `freshTenant` for parallel safety |

Unit fixtures are deliberately small and inline — see `go-unit-test`'s
assertion-and-fixture-standard for the unit-layer rule. Builders and `t.Cleanup`
helpers belong to the integration and e2e layers, where setting up a real
database record (Testcontainers) requires more structure.

---

## Test Data Builder

The builder pattern makes test data readable by expressing only what the test
cares about. A builder provides sensible defaults for every field so a test
that only cares about one field only has to state that one field. All other
fields absorb into the builder's defaults, invisible to the reader.

**Use when:** the same type is constructed across many tests with different
fields overridden each time, or when a type has many fields and you want tests
to state only what matters to them.

**Maintainability rationale** (from Khorikov's four pillars): when a new field
is added to a domain type, it breaks exactly one place — the builder's default
— rather than every test that constructs that type inline. This is the
maintainability pillar applied to test data.

Full Go implementation: `references/fixture-patterns-catalogue.md#test-data-builder`.

---

## Object Mother

The Object Mother pattern creates named, pre-configured complete objects for
recurring test scenarios. Where a builder provides a fluent API for targeted
overrides, an Object Mother provides factory functions that return a complete,
named fixture without requiring the caller to specify any fields.

**Use when:** the same complete configuration recurs across many tests
(for example, `MakeClassifiedAsset()` or `MakeArchivedAsset()`) and
the specifics of that configuration are not the subject of any individual test.

**Object Mother vs. builder:** builders are for one-off tests that need a
specific field override; Object Mothers are for recurring configurations that
multiple tests share. A codebase may use both — builders for fine-grained
control, Object Mothers for named, stable reference configurations.

Full Go implementation: `references/fixture-patterns-catalogue.md#object-mother`.

---

## Deterministic Data

Tests must be reproducible, so randomness and time are controlled:

- **Inject time** — never `time.Now()` in the code under test; accept a
  `now time.Time` parameter. Fixtures use a fixed `testTime`.
- **Generate IDs explicitly** — a builder assigns a known UUID, or a fixed
  one when the test asserts on it.
- **Seed PRNGs** with a fixed value if randomness is required at all.

Full Go examples for fixed clock and explicit ID usage:
`references/fixture-patterns-catalogue.md#deterministic-data`.

---

## Setup and Teardown with t.Cleanup

`t.Cleanup` registers teardown next to setup, runs in reverse order, and fires
even if the test fails — the cleanest way to guarantee no residue.

Prefer `t.Cleanup` over `defer` in helpers: `defer` in a helper fires when the
*helper* returns (while the test still needs the resource), not when the test
ends. Prefer `t.Cleanup` over `TestMain` teardown (too coarse).

Full Go code for `setupTestDB` and `freshTenant` with `t.Cleanup`:
`references/fixture-patterns-catalogue.md#tcleanup-teardown`.

---

## Parallel-Safe Isolation

For integration tests sharing a real database, isolate each test by scoping it
to a unique `tenant_id` (the `freshTenant` helper). Each test creates its own
tenant, so its data never intersects another test's.

Where stronger isolation is needed (for example, testing commit behavior itself
where a wrapping transaction would hide the effect), use transaction rollback
per test instead. See `go-integration-test`'s `test-isolation-standard.md` for
the rollback-vs-tenant tradeoff and when each applies.

Full Go code for `freshTenant` and parallel-safety:
`references/fixture-patterns-catalogue.md#parallel-safe-isolation`.

---

## Golden Files for Complex Output

When asserting on a large, stable output (a generated report, a serialized
event, an API response body), compare against a **golden file** rather than a
giant inline expected literal. An `-update` flag regenerates them on intentional
change.

Two disciplines keep golden files honest: **normalize before comparing** — strip
non-deterministic fields (timestamps, generated IDs) before writing or asserting;
and **never run `-update` to silence a failure you don't understand** — updating
a golden file is approving a behavior change, and the diff must be read.

Full Go code for `assertGolden` and the `testdata/` convention:
`references/fixture-patterns-catalogue.md#golden-files`.

---

## DRY Without Coupling

Share the *means* of creating data (builders, Object Mothers, helpers) — never
a live data object two tests both touch. A shared builder is good (reuse of
construction); a shared mutable fixture instance across tests is bad (couples
their outcomes).

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Hermetic | Each test creates, owns, and cleans its data | Tests depending on shared or leftover data |
| Order-independent | `go test -shuffle=on` stays green | Failures when test order changes |
| Layer-appropriate fixture | Inline literals for unit; builders + t.Cleanup for integration/e2e | Builder pattern forced onto unit-layer table-driven tests |
| Builders | Readable builders with defaults + targeted overrides | Giant inline literals; brittle fixtures |
| Object Mother where appropriate | Named pre-configured objects for recurring configurations | Builder called with 20 identical arguments across many tests |
| Deterministic | Fixed clock, explicit IDs, seeded PRNG | Wall-clock or random values in assertions |
| Cleanup guaranteed | `t.Cleanup` fires on success and failure | Leaked data; teardown skipped on failure |
| Parallel-safe | Per-test tenant or transaction-rollback isolation | Parallel tests colliding on shared rows |
| Golden for big output | `testdata/*.golden` + `-update` | Massive inline expected blobs |

---

## Anti-Patterns

- **Shared seed data all tests rely on** — "the test database has tenant 1 with
  5 assets" couples every test to ambient state; one mutation breaks three others
  mysteriously.
- **A mutable fixture object passed between tests** — share builders (construction),
  never live instances (state).
- **`time.Now()` or unseeded randomness in assertions** — flaky by construction;
  fix the clock and the IDs.
- **`defer` inside a helper** — fires when the helper returns, while the test
  still needs the resource; `t.Cleanup` scopes teardown to the test.
- **Cleanup only on the happy path** — teardown guarded by "if the test passed"
  leaks residue exactly when you are debugging; `t.Cleanup` runs regardless.
- **Golden files updated reflexively** — `-update` as a "make CI green" button
  converts a behavior gate into a rubber stamp.
- **Builder that mirrors every production field** — a 20-argument builder call
  is an inline literal wearing a costume; a builder's value is that tests state
  only what they care about.
- **Unit-layer test using a builder when an inline literal suffices** — adds
  indirection to a small, self-contained table-driven test that doesn't need it.

---

## Output Format

Produces fixtures, builders, and test data:

```
internal/test/builders/*.go            (Test Data Builder implementations)
internal/test/mothers/*.go             (Object Mother factory functions)
internal/test/fixtures.go              (setup/cleanup helpers: setupTestDB, freshTenant)
**/testdata/*.golden                    (golden files for complex outputs)
```

Full Go code examples for every pattern above:
`references/fixture-patterns-catalogue.md`
