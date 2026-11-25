# Coverage and Mutation Gates per Stack

Self-contained. Use when writing or judging a coverage or mutation gate. Facts come from the tools' official documentation (accessed 2026-11-25); nothing here has been run, so a build proves each gate in its own environment first.

## Contents
The rules; coverage: Go, Python, TypeScript; exclusion register; mutation: Gremlins, mutmut, StrykerJS; mutant register.

## The rules

- Coverage: 100% of lines and branches. Only machine-generated code is excluded; every other exclusion is listed with a reason for the product owner's approval.
- Mutation: every planted mutant is caught by a test, or recorded with the reason it cannot be (behaviour unchanged). A timeout or a type-checker rejection counts as caught only after each one is individually checked and recorded with a one-line reason; never automatically.
- The full gate runs all suites in scope. A partial run reports no coverage verdict, so keep thresholds out of shared configuration that partial runs read.
- A missing, stale or empty report is a failure. So is a run that selected zero tests.

## Coverage: Go

- `go test -cover` counts statements by source block. It has no branch coverage and does not look inside `&&` or `||`. It does not exclude generated files.
- Line gate: run with `-covermode=atomic -coverpkg=./... -coverprofile=...`; a script drops files carrying the marker `^// Code generated .* DO NOT EDIT\.$` and approved exclusions, then fails on any block with a zero count. Never compare the printed percentage: one decimal can show a gap as 100.0%.
- Branch gate: `gobco` (trial first, version pinned) with `-branch`, once per package. It has no threshold and exits successfully when coverage is incomplete, so a script requires covered equal to total and fails on a tool error, a panic, or `0/0` in a package that has conditions.
- Not measured, stated in every report: `select` (gobco; clause bodies are seen only by the statement gate), `range` loops and zero-iteration loops, boolean expressions outside `if`/`for` conditions and switch cases, functions without conditions in the branch figure.
- Trial before relying on it: generics, build tags (gobco ignores custom tags), `TestMain`, external test packages. If the trial fails, return to the product owner.

## Coverage: Python

- Set branch measurement on (`--cov-branch` or `branch = true`) and `source` naming the product packages, so unexecuted files appear.
- Gate on the full run with `--cov-fail-under=100` (exact: 99.99 fails). Keep `fail_under` and `--cov*` flags out of shared configuration: subset runs would fail, and mutation runs would be disturbed.
- A script also requires: branch data present, more than zero statements, no missing lines, missing branches or partial branches.
- Built-in default exclusions (`# pragma: no cover`, `...` bodies, `if TYPE_CHECKING:`, some always-true loops) are exclusions too: list them for approval, with every `omit`, `exclude_*`, `partial_*` setting and `no branch` pragma.

## Coverage: TypeScript (Vitest)

- `coverage.include` is mandatory, or untested files vanish and 100% is hollow.
- Thresholds for lines and branches at 100, per file; `autoUpdate` off; no negative or glob thresholds that relax the gate.
- Every `exclude` entry, ignore comment (`v8 ignore`, `istanbul ignore`) and `ignoreClassMethods` goes in the register. Playwright runs do not feed these numbers.

## Exclusion register

| Field | Content |
|---|---|
| Path or pattern | The file, block or setting |
| Kind | generated, or other |
| Reason | Why a test cannot or should not reach it |
| Approval | The product owner's approval date, or pending |

It lives in the strategy. Adding an entry edits an approved artifact, which sends it back to the product owner. A pending entry is not yet excluded. A package left out of mutation is an exclusion too.

## Mutation: Go (Gremlins)

- Enable all eleven operators (six are off by default). It lists no statement-removal operator.
- Do not use its thresholds: a threshold of 100 fails even a perfect run. A script reads the JSON from `--output`.
- Fail on a missing report, or any lived or not-covered mutant without a record. Timed-out mutants are left out of its ratios: read each mutation's status. Not-viable (did not compile) and skipped mutants are checked one by one. With no mutants it succeeds and writes nothing.

## Mutation: Python (mutmut 3)

- Surviving mutants do not make `run` exit non-zero. Delete `mutants/` first, run, then parse `mutmut results --all`; the summary export omits type-check rejections and unchecked mutants.
- Fix, never record: not checked, suspicious, segfault, interrupted. Record after checking: survived (behaviour unchanged), timeout, caught by type check. No tests: write the test.
- Module-level code, most decorated functions and some other constructs are never mutated: state this limit.

## Mutation: TypeScript (StrykerJS)

- Set `break` to 100 but also read the JSON report: fail on survived, no coverage, pending, runtime error, empty report or zero mutants.
- It counts timeouts as detected and leaves compile errors out of the score: check and record each. Disabled mutants (`// Stryker disable next-line <Mutator>: reason`) need a record; reject `all`, blocks and empty reasons. List `mutate` negations, excluded mutations, ignorers and `ignoreStatic` in the exclusion register. No incremental mode on the gate.

## Mutant register

One row per mutant not caught by a failing assertion, kept in the mutation report: file and location, mutant type, a fingerprint of the change (lines move), status (equivalent, timeout, type-check rejection), a one-line reason, and who checked it on which date. A hard-to-test mutant is not equivalent: if any input makes the behaviour differ, write the test. Re-check a record when its code changes. A tool proves nothing about faults it never plants.
