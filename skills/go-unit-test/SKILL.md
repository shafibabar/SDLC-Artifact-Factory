---
name: go-unit-test
description: >
  This plugin's foundational unit-testing standard for Go — the one every other
  Go test skill (go-integration-test, go-contract-test, go-mutation-test,
  go-e2e-test) assumes as baseline. Covers: Table-Driven Test structure (the
  exact struct-shape convention, subtest naming via t.Run, t.Parallel()
  safe-vs-unsafe rules — references/worked-example.md); the code-complexity
  quadrant heuristic (domain complexity × collaborator count) deciding what
  earns a unit test versus an integration test versus no test at all;
  Khorikov's four pillars of a good unit test (protection against regressions,
  resistance to refactoring, fast feedback, maintainability) held as
  multiplicative not additive; this repo's mocking philosophy — classical
  (Detroit) school chosen over London (mockist), mock only unmanaged
  dependencies, cross-referencing mock-generation for the actual tooling
  (references/mocking-philosophy.md); numeric coverage-expectation targets by
  quadrant, honestly caveated against Khorikov's coverage-is-gameable warning
  (references/coverage-by-quadrant.md); the assertion-style standard — a
  layered stdlib-vs-testify convention and what a good expected/got failure
  message looks like — plus the unit-layer test-data/fixture standard and the
  flakiness-prevention standard (no time.Sleep, no real network/filesystem,
  seeded deterministic randomness — references/assertion-and-fixture-
  standard.md). Authored by the test-strategist as the canonical pattern;
  applied test-first (TDD) by the backend-engineer for every unit in
  go-domain-model and go-service-layer. The base of the pyramid. Used during
  Implement.
version: 3.0.0
phase: implement
owner: test-strategist
created: 2026-06-25
tags: [implement, go, unit-test, table-driven, tdd, fuzzing, mocking-philosophy, coverage, assertions, fixtures, flakiness, four-pillars, complexity-quadrants]
related: [mock-generation, go-domain-model, go-repository-pattern, go-integration-test, test-fixture-design, go-mutation-test]
---

# Go Unit Test

## Purpose

Unit tests are the foundation of the pyramid: fast, deterministic, isolated checks that a function or Aggregate behaves correctly. They run in milliseconds, so there can be thousands of them, and they pinpoint a failure to one unit. This skill is authored by the test-strategist as the canonical pattern; the backend-engineer applies it **test-first** (TDD) for `go-domain-model` and `go-service-layer`. Every other Go test skill in this roster treats this one's standards — table shape, mocking philosophy, assertion style — as baseline, not as something to restate.

---

## What Deserves a Unit Test: The Complexity Quadrants

Before writing a test, classify the code on two axes — **domain complexity** and **number of collaborators** — and let the quadrant decide the strategy:

| Quadrant | Domain complexity | Collaborators | Verdict |
|---|---|---|---|
| 1 — Domain logic | High | Few | Best return on unit-test investment — thorough table-driven tests belong here (`go-domain-model` Aggregates, value objects, pure calculations) |
| 2 — Overcomplicated | High | Many | The danger zone: decompose first, pulling complex logic into quadrant 1, then unit-test the extracted logic *and* integration-test (`go-integration-test`) the wiring left behind |
| 3 — Controllers | Low | Many | A thin chi handler that deserializes and delegates — apply Humble Object (`go-chi-handler`) and verify with integration/e2e tests instead of forcing unit coverage |
| 4 — Trivial | Low | Few | A getter, a simple mapper — often needs no dedicated test at all |

Numeric coverage guidance per quadrant, and the honest caveat about coverage as a metric: `references/coverage-by-quadrant.md`. Quadrant 3 is the common trap: table-driven unit tests over a handler with no logic of its own really test wiring, not behaviour — `go-chi-handler`'s handler → service → encode split is this fix in practice.

---

## Isolation — No Real World

A unit test touches no file system, no network, no database, no clock it doesn't control — dependencies are replaced with test doubles (`mocking-philosophy` below), and time/IDs are injected (`go-domain-model`'s `now time.Time` parameter). If a "unit" test needs a real database, it is an integration test — move it (`go-integration-test`). Full flakiness-prevention rules (no `time.Sleep`, no real network/FS, seeded randomness): `references/assertion-and-fixture-standard.md`.

---

## Table-Driven Test: Struct Shape and Parallel Safety

The canonical shape — one test function, a table of named cases, a loop, each case a named subtest:

```go
tests := []struct {
    name    string
    // ...inputs...
    want    T
    wantErr bool // or a typed/sentinel error field per go-domain-model's axes
}{ /* cases */ }
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) { /* Act + assert */ })
}
```

`name` is always first and always drives `t.Run(tt.name, ...)` so a failure names the exact case. Since Go 1.22, loop variables are per-iteration — `tt := tt` re-declaration is dead weight and must not appear in new code. Full worked example (`TestSensitivityLevel_IsHigherThan`) and the single-case `-run` invocation: `references/worked-example.md`.

**`t.Parallel()` is safe** when a subtest owns its data and doubles exclusively and its outcome does not depend on execution order — the default for table-driven cases. It is **unsafe** when subtests share a package-level `var`, a fixed clock/random source with no per-test isolation, or any other mutable state outside the case's own scope; `go test -race` and `-shuffle=on` both exist to catch exactly this. One structural pitfall worked in `references/worked-example.md`: a parent test that spawns parallel subtests *returns* before they run, so a parent `defer` fires before its subtests execute — use `t.Cleanup` for shared teardown instead.

---

## The TDD Loop (Red-Green-Refactor)

The test is written **before** the production code, and drives its design: **Red** — write a failing test that specifies the next behaviour, confirm it fails for the right reason; **Green** — write the *minimal* code to pass, no more than the test demands; **Refactor** — improve names, structure, and efficiency with the test green as the safety net. The `tdd-gate` hook verifies the test file is not newer than the implementation file — TDD is enforced, not trusted.

---

## Mocking Philosophy

This repo follows Khorikov's **classical (Detroit/Chicago) school**, not the London (mockist) school: isolate the *test case* from other test cases (no shared mutable state), not the *class under test* from every collaborator. A unit of test is a unit of observable behaviour, which may legitimately span several collaborating types with only true external dependencies replaced. The precise rule for what earns a mock at all — managed vs. unmanaged dependencies, stub-vs-mock, and why a repository (Humble Object, `go-repository-pattern`) gets a fake or an integration test rather than a call-count mock — is `references/mocking-philosophy.md`. `mock-generation` owns the actual Go tooling (`moq`/`mockgen`/`counterfeiter`) this philosophy is applied through; this skill owns only *when to mock at all*.

---

## Assertion-Style Standard

A failing test must state exactly what went wrong — the operation, the input, the got value, and the want value — without a debugger. This repo's convention is layered, not one blanket rule: hand-written stdlib `t.Errorf`/`t.Fatalf` for quadrant-1 domain-model table-driven tests (each row already supplies the exact input/want, so a case-specific message beats any generic library one), `testify/require` at the application/integration layer where boilerplate reduction matters more than per-case customization. Never a boolean-collapsing assertion (`assert.True(t, got == want)`) — it discards both values from the failure output. Full standard and worked bad/good pairs: `references/assertion-and-fixture-standard.md`.

---

## Test-Data and Fixture Standard (Unit Layer)

Unit-test fixtures are small, inline, readable struct literals — one per table row — never a large opaque golden file; golden files belong to `test-fixture-design`'s toolkit for complex output at the integration/e2e layer, not here. `test-fixture-design` owns the builder pattern and hermetic setup/teardown this skill's fixtures follow; full unit-layer specifics: `references/assertion-and-fixture-standard.md`.

---

## Flakiness Prevention

- **No `time.Sleep`** — inject a fake clock or a `now time.Time` parameter; a unit test never waits for something to happen, it calls a function and asserts.
- **No real network or filesystem calls** — that dependency belongs to `go-integration-test`; a "unit" test touching either is mislabeled or not actually isolated.
- **Deterministic randomness** — never call unseeded top-level `math/rand` inside code under unit test; inject a seeded `*rand.Rand` or stub randomness as a collaborator.
- **Order-independence** — `go test -shuffle=on` must stay green; any shared mutable package-level state between test functions violates this immediately.

Full standard and rationale: `references/assertion-and-fixture-standard.md`.

---

## Native Fuzzing for Input Mutation

Go's built-in fuzzer (`testing.F`) generates mutated inputs to find cases hand-written tables miss — malformed input, panics, invariant violations. Use it on parsers, validators, and anything taking untrusted input:

```go
func FuzzParseSensitivity(f *testing.F) {
    f.Add("Confidential") // seed corpus
    f.Fuzz(func(t *testing.T, s string) {
        level := domain.SensitivityLevel(s)
        if level.IsValid() && level.rank() == 0 {
            t.Errorf("valid level %q has rank 0", s)
        }
    })
}
```

Fuzz tests run briefly in CI and longer on a schedule; a discovered crasher is added to the seed corpus as a permanent regression case.

---

## Decoupled from Implementation — The Four Pillars

Khorikov's **four pillars** — Protection Against Regressions, Resistance to Refactoring, Fast Feedback, Maintainability — are the "why" behind every rule above. They are **multiplicative, not additive**: a missing pillar zeroes out the value of the others rather than just discounting it. Asserting a private call count *looks* like more protection, but it destroys resistance to refactoring — any internal restructuring that preserves behaviour still breaks the test, training the team to distrust red tests. Tests assert **behaviour through the public surface** (`asset.Sensitivity()`), never private fields or internal call counts. A well-decoupled test stays green through any refactor that preserves behaviour and fails only when external behaviour changes.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Isolated | No real FS/network/DB/clock | A "unit" test hitting a database |
| Right-sized | Quadrant classified before testing | Exhaustive unit tests forced onto controller/glue code |
| Table-driven | Named struct shape; subtests via `t.Run` | Copy-pasted near-identical test funcs |
| Parallel-safe | `t.Parallel()`; no shared state; race-clean | Order-dependent, shared-state tests |
| Test-first | Test precedes code (`tdd-gate`) | Tests written after, to fit the code |
| Mocking philosophy applied | Classical school; only unmanaged deps mocked | Every collaborator mocked (London-style) |
| Assertions actionable | Expected-vs-got with context, layered convention followed | Bare `t.Fail()`; boolean-collapsing assertions |
| Fixtures unit-appropriate | Small inline literals per case | Opaque golden file for a unit test |
| Flakiness-free | No sleep/network/FS/unseeded rand | Any of the above present |
| Fuzzed where apt | Parsers/validators have fuzz tests | Untrusted-input code unfuzzed |
| Behaviour-coupled | Asserts public behaviour | Asserts private state / call counts |

---

## Anti-Patterns

- **`tt := tt` loop-variable capture** — unnecessary since Go 1.22; a stale idiom cargo-culted forward.
- **`defer` for teardown shared with parallel subtests** — fires before the subtests run; use `t.Cleanup`.
- **`time.Sleep` in a unit test** — a unit test controls its clock by injection; sleeping means it's nondeterministic or secretly an integration test.
- **Mocking managed dependencies** (your own repository/DB) — Khorikov's classical-school violation; a managed dependency gets a fake or an integration test, never interaction verification.
- **Asserting on a stub** — verifying calls that were only there to supply data couples the test to an implementation detail with zero behavioural payoff.
- **Asserting error message strings** — assert with `errors.Is`/`errors.As` against sentinel errors or types; message text is not a contract.
- **Boolean-collapsing assertions** — `assert.True(t, got == want)` discards both values from the failure output.
- **One giant test function** — a failure in case 3 hides cases 4–20; table-driven subtests report every case independently.
- **Test names that describe mechanics, not behaviour** — `TestClassify2` says nothing; `"equal is not higher"` reads as a specification.

---

## Output Format

Produces Go test files (written before the code they cover):

```
internal/domain/*_test.go              (table-driven invariant tests)
internal/application/**/*_test.go       (handler tests with mocked ports)
internal/**/fuzz_test.go                (fuzz targets for parsers/validators)
```
