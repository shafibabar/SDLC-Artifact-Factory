---
name: go-unit-test
description: >
  Use when backend-engineer, test-strategist, security-engineer or anyone
  writes, reviews or fixes Go unit tests in the Implement phase: test-first
  (TDD), table-driven tests and t.Run, t.Parallel, t.Cleanup and t.Setenv,
  deriving cases (boundaries, equivalence classes, decision tables, state
  transitions), assertions with testing or testify, httptest handler tests,
  fake clocks and testing/synctest, fuzzing in CI, what to unit test, or Go
  coverage: go test -cover, 100% statement and branch gates, gobco, exclusions
  and unmeasured code. Produces go-test-file.
version: 4.0.0
phase: implement
owner: test-strategist
created: 2026-06-25
tags: [implement, go, unit-test, table-driven, tdd, fuzzing, assertions, flakiness, coverage, gobco, synctest]
produces: go-test-file
domain: testing
status: stable
related: [test-pyramid, mock-generation, test-fixture-design, go-integration-test, go-mutation-test, go-domain-model, go-error-handling, go-chi-handler, go-repository-pattern, go-makefile]
sources:
  - research/testing/unit-testing-khorikov.md
  - research/testing/software-testing-craftsman-jorgensen.md
  - research/testing/go-toolchain-official-docs.md
  - research/testing/go-coverage-official-docs.md
  - research/testing/moq-official-docs.md
  - research/software-architecture/100-go-mistakes-harsanyi.md
  - research/software-architecture/the-go-programming-language-donovan-kernighan.md
---

# Go Unit Test

## Purpose

This skill owns how Go unit tests are derived, written and measured; the other Go test skills take it as the baseline. `test-strategist` authors the standard; `backend-engineer` applies it. `test-pyramid` owns layers and gates, `mock-generation` doubles, `test-fixture-design` test data.

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off.

| # | Rule | Reason |
|---|---|---|
| U1 | **Test first:** write a failing test, see it fail for the expected reason, write the least code that passes, refactor | The `tdd-gate` hook checks only that a matching test file exists, never order |
| U2 | **Assert behaviour through the public surface, not internal state**: never a private field or internal call count | Such tests break on refactors that preserve behaviour (Khorikov) |
| U3 | **No real world:** no file system, network, database, clock or randomness the test does not control; no sleeping | Results would vary between runs; a real dependency belongs in `go-integration-test` |
| U4 | **Doubles follow `mock-generation`:** managed dependency verified by state; moq mock only for an unmanaged one; never assert on a stub | One rule across every Go test |
| U5 | **Coverage is 100% of lines and branches:** statement blocks as a hard gate plus `gobco` branches. Only machine-generated code is excluded automatically; other exclusions need the product owner's approval. Never offer or record a lower figure | `test-pyramid` and the product owner's decision |
| U6 | **No result is not a pass:** if either gate cannot measure something, return it to the product owner; never report statements alone | The gobco trial was not a clean pass |
| U7 | **A waiver exists only for a measured result above 90% and under 100%,** after the product owner reviews it and records comments, per measure and per run | None before a result; none at 90% or below |

Every product size follows all seven. **Lean** means fewer cases and packages, never a lower figure, a skipped gate or tests written afterwards.

## What every answer states

Say these in words, beside any code; code that follows a rule silently leaves the reader free to undo it.

1. **What kind of code it is** (quadrant) and which test proves each part. "Trivial" and "controller" code is still covered or listed.
2. **How the cases were derived**, naming the technique, what was collapsed and what was not tried.
3. **What is replaced or refused, by name, with the reason**: "`repo.SaveCalls()` is removed: the repository is ours, so the test reads the saved state". Give the compliant version.
4. **What stays the default when one case differs**: "this test is serial because it uses `t.Setenv`; every other test stays parallel".
5. **What a helper or tool does that the reader cannot see**, whichever applies: plain `go test` runs only fuzz seeds; parallel subtests run after the parent returns; `t.Setenv` panics under `t.Parallel`; a synctest bubble panics on a leftover goroutine; a moq method with no func panics and a mock verifies nothing by itself; `go test -cover` counts statements, rounded; gobco has no threshold, counts only a package's own tests and skips `select` and `range`; what each script excludes and its exit codes.
6. **Sketches:** every variable declared or its origin named; each test asserts what its name claims.
7. **Coverage, whenever it comes up:** both measures as counts; the unmeasured cases (`select`; `range` and zero-iteration loops; booleans outside `if`/`for` conditions and switch cases; functions without conditions); generated code excluded by name; other exclusions pending or approved; a unit-only run gives no verdict.
8. **At this size:** what lean changes and what it does not.
9. **Decisions for the product owner**: each exclusion, each waiver after a result, each no-result item, any rule the request leaves undefined.
10. **What was run.** Code not executed is called unverified.

## What deserves which test

| Code | Proof |
|---|---|
| Domain logic: complex, few collaborators | Thorough table-driven unit tests |
| Complex and many collaborators | Split first: logic into plain types, a thin wrapper left (Humble Object) |
| Controller or handler: simple, many collaborators | A few integration tests; `httptest` for its own paths |
| Trivial | Through the behaviour that uses it; else its own small test, or listed |

## Procedure

1. Read the code or requirement, acceptance criteria, ports, existing tests, `go.mod`, and the test strategy's exclusion register.
2. Classify the code with the table above.
3. Derive the cases; open `./references/deriving-test-cases.md` for limits, condition combinations or state changes.
4. Copy a skeleton from `./templates/unit-test-skeletons.md` into `<implementation>_test.go` (or `_<variant>_test.go`) with Write, before the implementation.
5. Run it; see it fail for the expected reason. Then write the least code to pass and refactor.
6. For parallelism, teardown, time or randomness read `./references/test-shape-and-isolation.md`; for assertions, handlers, doubles or test value, `./references/assertions-doubles-and-value.md`.
7. For untrusted input add a fuzz target and its bounded CI step: `./references/fuzzing.md`.
8. Run `./scripts/validate-go-unit-tests.sh <paths>`, then `go test -race -shuffle=on ./...`; fix and repeat until clean.
9. Run `./scripts/check-go-line-coverage.sh` and `./scripts/check-go-branch-coverage.sh` on the module; read `./references/coverage-gates.md` first. For each gap add the behaviour case it reveals; rerun until both pass or only product-owner items remain.
10. Copy `./templates/coverage-report.md` to `artifacts/<product>/quality/test-reports/` and fill it from the full run, for the product owner's approval.
11. Tick `./resources/checklist.md` and answer with the statements above.

Worked cases, with real gate output: `./examples/01-lean-bakery-stamps.md` (100% statements, two branches missed), `./examples/02-standard-class-booking.md` (decision table, transitions, fake and mock), `./examples/03-enterprise-energy-billing.md` (tenants, synctest, fuzzing, a branch result gobco cannot give).

## Gotchas

- **"`go test -cover` says 100.0%."** *Reason:* one decimal hides gaps and it counts statements only. *Instead:* run both gates.
- **"Every statement ran, so branches are fine."** *Reason:* an `if` without `else` has no block for the false path. *Instead:* run the branch gate.
- **Running `gobco ./...`.** *Reason:* it prints "nothing to instrument" and exits 0. *Instead:* use the script.
- **A file behind a custom build tag.** *Reason:* gobco measures nothing in it and still reports complete. *Instead:* the script says "no result"; take it to the product owner.
- **"The handler tests already run the fake."** *Reason:* the branch gate counts only a package's own tests. *Instead:* give the fake its own test.
- **"It is only `main`, a getter or glue."** *Reason:* only generated code is excluded automatically. *Instead:* test it, or list it for approval.
- **Adding calls with no assertion to reach 100%.** *Reason:* coverage proves only that code ran. *Instead:* write the behaviour case, or delete dead code.
- **"The fuzz test runs in CI."** *Reason:* plain `go test` runs seeds only. *Instead:* one `-fuzz` step with `-fuzztime` per target.
- **`defer` for teardown above parallel subtests.** *Reason:* it runs before they do. *Instead:* `t.Cleanup`.
- **`time.Sleep`, or a test that reads `time.Now()`.** *Reason:* timing decides the result. *Instead:* pass the time, or use `testing/synctest`.
- **Writing `tt := tt`.** *Reason:* unneeded from Go 1.22. *Instead:* remove it, after checking `go.mod`.

## Output

| File | When to open it |
|---|---|
| `./references/deriving-test-cases.md` | Choosing rows |
| `./references/test-shape-and-isolation.md` | Table shape, parallelism, time, randomness |
| `./references/assertions-doubles-and-value.md` | Assertions, handlers, doubles, quadrants |
| `./references/fuzzing.md` | Untrusted input |
| `./references/coverage-gates.md` | Running or reporting coverage |
| `./templates/unit-test-skeletons.md` | Writing test files |
| `./templates/coverage-report.md` | Reporting a full run |
| `./scripts/validate-go-unit-tests.sh` | Before hand-off, after every edit |
| `./scripts/check-go-line-coverage.sh` | Statement gate |
| `./scripts/check-go-branch-coverage.sh` | Branch gate |
| `./resources/checklist.md` | Before answering |

Test files sit beside the code they test (`internal/domain/*_test.go`, `internal/application/**/*_test.go`), with fakes for managed ports and moq mocks for unmanaged ones.
