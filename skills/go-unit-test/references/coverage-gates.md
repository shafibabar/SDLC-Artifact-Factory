# Go Coverage Gates

Self-contained. Use when running, reading or reporting Go coverage. The policy belongs to `test-pyramid`; this file says how Go meets it. Tool behaviour marked below was run on Go 1.27.4 with gobco 1.3.4 (2026-11-26).

## The policy

- 100% of lines and branches. Go's own tool counts statement blocks and has no branch coverage, so: 100% of statement blocks as a hard gate, plus `gobco` branch coverage after a trial, with the unmeasured cases stated in each report. A failed trial returns to the product owner; never drop to statements only.
- Only machine-generated code is excluded automatically. Every other exclusion is listed with a reason for the product owner's approval.
- Statement and branch results are judged separately. Above 90% and under 100% fails unless the product owner reviews the gap and waives it with recorded comments; 90% or below has no waiver; no result means nothing to waive. A waiver covers one run. Testing layers are never waived.
- Compute from counts, never a rounded figure: waivable only if `covered x 10 > total x 9` and `covered < total`.
- The verdict comes from the full run of all suites in scope. A unit-only or filtered run gives no verdict.

## The two commands

```bash
check-go-line-coverage.sh [--tags t] [--exclusions file] [--profile file | --out file] [module-dir]
check-go-branch-coverage.sh [--tags t] [--exclusions file] [module-dir]
```

Copy `../scripts/check-go-line-coverage.sh` and `../scripts/check-go-branch-coverage.sh` into the product's `scripts/`. Install the pinned tool: `go install github.com/rillig/gobco@v1.3.4`. Both need Python 3; the line gate runs `-race`, which needs cgo (a C compiler). Exit 0 pass, 1 gap, 2 no result.

| | Line gate | Branch gate |
|---|---|---|
| Runs | `go test -count=1 -race -covermode=atomic -coverpkg=./...` | `gobco -branch` once per package, fresh statistics file |
| Counts | Blocks from any package's tests | **Only the package's own tests** |
| Passes when | No block has a zero count | Every measured condition was true and false |
| Leaves out | `_moq.go` by name, generated marker, approved entries | The same |
| Refuses a result when | Tests fail; build constraints leave a production file out | Also: gobco fails; a file with conditions is measured as none |

Why not the printed figure: with 1 of 2503 statements not run, `go test -cover` and `go tool cover -func` both printed `100.0%`.

Exclusion file, one line each, approved entries only (pending is refused): `internal/x/y.go | approved YYYY-MM-DD | reason`. It mirrors the strategy's exclusion register. `cmd/**` composition roots are counted (packages without tests appear at 0%): test them or list them.

Because the branch gate counts only own-package tests, every package with conditions needs tests of its own, including hand-written fakes under `internal/test/`.

## Not measured, stated in every report

| Case | Statement gate | Branch gate |
|---|---|---|
| `select` | Sees whether each clause body ran | Nothing |
| `range` loop, including zero iterations | Sees only whether the body ran | Nothing |
| `ok := a \|\| b`, a returned comparison | Line ran | Nothing |
| Each operand of `a && b` in an `if` | No | Whole condition only |
| Function without conditions | Counted | Absent |

## The gobco trial (D048 requires one)

**Verdict: not a clean pass.** Generics and multi-package modules work through the script; custom build tags fail.

| Construct | Result |
|---|---|
| Generic types and constraints, Go 1.27 generic methods, type switches, range-over-func, named bool types | Measured |
| Several packages | One package per run: naming two panics; `./...` prints "nothing to instrument" and **exits 0** |
| Production file behind a custom build tag, even with `-test=-tags=` | **Silently unmeasured**, reported complete |
| The same function in two tagged files, or `_linux`/`_windows` pairs | Panic, "redeclared" |
| `export_test.go` used by an external test package | Panic |
| External test package importing the package under an alias, or where folder and package names differ | Setup fails |
| `TestMain` without an explicit `os.Exit` | Panic |
| `break` to a label on a `switch` | Build fails |
| A `//go:build ignore` file with package `main` beside the package | Setup fails |
| `-test=-race` with parallel tests | Data race in gobco's counters |
| A reused statistics file | Old counts are added |
| moq mocks | Their conditions are counted; the script removes them by file name |

Not tried: `go.work`, nested modules, `replace` directives to outside the module, cgo, operating systems other than Linux on amd64, very large modules. One package with two third-party dependencies took about 10 seconds on its first run.

For a "no result": say which package, quote the message, and put it to the product owner. Offering a change to the code or tests that makes it measurable (rename an import, give `TestMain` an `os.Exit`, remove the label) is fine. Excluding the file, or reporting statements alone, is their decision to refuse, not a workaround to take.
