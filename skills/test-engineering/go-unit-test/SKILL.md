---
name: go-unit-test
description: >
  Teaches how to write fast, deterministic, isolated Go unit tests — table-driven
  structure, boundary/nil/edge analysis, the Red-Green-Refactor TDD loop, strict
  actionable assertions (expected/got), native fuzzing for input mutation, parallel
  safety with t.Parallel, and decoupling tests from implementation details so they
  survive refactors. This is the base of the pyramid; authored by the test-strategist
  and applied by the backend-engineer test-first. Used during Implement.
version: 1.0.0
phase: implement
owner: test-strategist
tags: [implement, go, unit-test, table-driven, tdd, fuzzing, boundary, assertions]
---

# Go Unit Test

## Purpose

Unit tests are the foundation of the pyramid: fast, deterministic, isolated checks that a function or Aggregate behaves correctly. They run in milliseconds, so there can be thousands of them, and they pinpoint a failure to one unit. They are the cheapest place to catch a bug and the safety net that makes refactoring fearless.

This skill is authored by the test-strategist as the canonical pattern; the backend-engineer applies it **test-first** (TDD) for the code it writes (`go-domain-model`, `go-service-layer`). The patterns here are the standard both follow.

---

## Isolation — No Real World

A unit test touches no file system, no network, no database, no clock it doesn't control. Dependencies are replaced with test doubles (see `mock-generation`); time and IDs are injected (the domain takes `now time.Time` — see `go-domain-model`). This is what makes unit tests fast and deterministic.

```go
// The handler's dependencies are interfaces → replaced with fakes/mocks in the test.
h := commands.NewClassifyDataAssetHandler(fakeRepo, stubPolicy, fakeIdem)
```

If a "unit" test needs a real database, it is an integration test — move it (see `go-integration-test`).

---

## Table-Driven Tests

The idiomatic Go pattern: one test function, a table of cases, a loop. Adding a case is one line; the structure makes the inputs and expectations explicit and scannable.

```go
func TestSensitivityLevel_IsHigherThan(t *testing.T) {
    t.Parallel()
    tests := []struct {
        name string
        a, b domain.SensitivityLevel
        want bool
    }{
        {"restricted over public", domain.SensitivityRestricted, domain.SensitivityPublic, true},
        {"public not over restricted", domain.SensitivityPublic, domain.SensitivityRestricted, false},
        {"equal is not higher", domain.SensitivityConfidential, domain.SensitivityConfidential, false},
        {"unclassified is lowest", domain.SensitivityUnclassified, domain.SensitivityPublic, false},
    }
    for _, tt := range tests {
        tt := tt
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            if got := tt.a.IsHigherThan(tt.b); got != tt.want {
                t.Errorf("IsHigherThan(%q,%q) = %v, want %v", tt.a, tt.b, got, tt.want)
            }
        })
    }
}
```

Each case is a subtest (`t.Run`) so failures name the exact case, and cases run in parallel.

---

## Boundary, Nil, and Edge Analysis

Most bugs hide at the edges. Every unit test deliberately probes them:

| Probe | Examples |
|---|---|
| Boundaries | min/max, empty/full, first/last, off-by-one |
| Zero values | nil pointer, empty string, zero time, empty slice |
| Invalid input | wrong type, malformed UUID, out-of-range enum |
| State edges | already-classified, already-deleted, concurrent version |

```go
{"empty sensitivity is invalid", "", false},
{"unknown level is invalid", "Secret", false},   // not one of the four canonical levels
```

The happy path is the *least* interesting case — the negative and edge cases are where the value is.

---

## The TDD Loop (Red-Green-Refactor)

The test is written **before** the production code, and drives its design:

1. **Red** — write a failing test that specifies the next behaviour. Run it; confirm it fails for the right reason.
2. **Green** — write the *minimal* production code to pass. No more than the test demands.
3. **Refactor** — improve names, structure, and efficiency with the test green as the safety net.

The `tdd-gate` hook (Chunk 20) verifies the test file is not newer than the implementation file — TDD is enforced, not trusted.

---

## Strict, Actionable Assertions

A failing test must say exactly what went wrong, so a failure is diagnosable without a debugger.

```go
// Good: states expected vs actual with context
if got != want {
    t.Errorf("Classify(%q): sensitivity = %q, want %q", input, got, want)
}
```

Use stdlib `t.Errorf` for full control, or `testify/require` for concise assertions with good messages (`require.Equal(t, want, got)`). `require` stops the test on failure (use when continuing is pointless); `assert` continues (use to collect multiple checks). Prefer `require` for preconditions, `assert`/`Errorf` for the actual checks.

Never a bare `t.Fail()` with no message — "expected X, got Y" is the minimum.

---

## Native Fuzzing for Input Mutation

Go's built-in fuzzer (`testing.F`) generates mutated inputs to find cases hand-written tables miss — malformed input, panics, invariant violations. Use it on parsers, validators, and anything taking untrusted input (a cheap, Go-native form of the blueprint's "input mutation").

```go
func FuzzParseSensitivity(f *testing.F) {
    f.Add("Confidential")                    // seed corpus
    f.Fuzz(func(t *testing.T, s string) {
        level := domain.SensitivityLevel(s)
        // Property: IsValid never panics, and a valid level round-trips.
        if level.IsValid() && level.rank() == 0 {
            t.Errorf("valid level %q has rank 0", s)
        }
    })
}
```

Fuzz tests run briefly in CI and longer on a schedule; a discovered crasher is added to the seed corpus as a permanent regression case.

---

## Parallel Safety

Unit tests run in parallel (`t.Parallel()`) to keep the suite fast. This requires **no shared mutable state** between tests — each test owns its data and doubles. Shared state causes order-dependence and flakiness (see `test-fixture-design`). The race detector (`go test -race`, always on — see `go-makefile`) catches accidental sharing.

---

## Decoupled from Implementation

Tests assert **behaviour through the public surface**, not internal state. A test that reaches into private fields or asserts how many times an internal method was called breaks on every refactor and proves nothing the caller cares about.

```go
// ✅ behaviour: classify, then observe the public outcome
err := asset.Classify(domain.SensitivityConfidential, by, now)
require.NoError(t, err)
require.Equal(t, domain.SensitivityConfidential, asset.Sensitivity())

// ❌ implementation: asserting a private field or internal call count
```

A well-decoupled test stays green through any refactor that preserves behaviour, and fails only when external behaviour changes — exactly when it should.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Isolated | No real FS/network/DB/clock | A "unit" test hitting a database |
| Table-driven | Cases in a table; subtests named | Copy-pasted near-identical test funcs |
| Edge coverage | Boundary/nil/invalid/state-edge probed | Happy-path-only assertions |
| Test-first | Test precedes code (tdd-gate) | Tests written after, to fit the code |
| Actionable assertions | Expected-vs-got with context | Bare `t.Fail()`; opaque failures |
| Fuzzed where apt | Parsers/validators have fuzz tests | Untrusted-input code unfuzzed |
| Parallel-safe | `t.Parallel()`; no shared state; race-clean | Order-dependent, shared-state tests |
| Behaviour-coupled | Asserts public behaviour | Asserts private state / call counts |

---

## Output Format

Produces Go test files (written before the code they cover):

```
internal/domain/*_test.go              (table-driven invariant tests)
internal/application/**/*_test.go       (handler tests with mocked ports)
internal/**/fuzz_test.go                (fuzz targets for parsers/validators)
```
