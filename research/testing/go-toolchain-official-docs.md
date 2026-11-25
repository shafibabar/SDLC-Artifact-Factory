# Go Toolchain Official Documentation: Build Tags, Fuzzing, Testing Behaviour
**Authors:** The Go project (go.dev, pkg.go.dev, golang/go repository)
**Domain:** Testing (Go)

Accessed 2026-11-25. Current release: go1.27.4 (https://go.dev/VERSION?m=text). Coverage has its own note (`go-coverage-official-docs.md`).

## Core Concepts

- **Build constraints:** a `//go:build` line before the package clause decides whether a file is in the package; expressions use `||`, `&&`, `!`; more than one line per file is an error. `-tags` lists *additional* tags to treat as satisfied. (https://pkg.go.dev/cmd/go, go1.27.4)
- **Consequence (inference from the same page):** untagged files always compile, so `-tags smoke` adds files and removes none; an untagged file that uses a symbol defined only in a tagged file fails to build without that tag.
- **Implicit tags and suffixes:** GOOS, GOARCH, `unix`, compiler, `cgo`, Go release tags; `_GOOS`/`_GOARCH` file-name suffixes. `//go:build ignore` excludes a file. (https://pkg.go.dev/cmd/go)
- **Test selection:** `-run` is split at unbracketed `/` into one expression per subtest level, and parents of matches run too. `-skip` excludes matches. `-short` asks long tests to shorten. `-count=1` is the idiomatic cache bypass. (https://pkg.go.dev/cmd/go; source https://raw.githubusercontent.com/golang/go/master/src/cmd/go/internal/test/test.go)
- **Fuzz tests:** `FuzzXxx(*testing.F)` in `_test.go`, one `f.Fuzz` target; arguments limited to string, []byte, integer, unsigned, float and bool types. (https://go.dev/doc/security/fuzz/)
- **Plain `go test` runs only the seed corpus** (`f.Add` plus `testdata/fuzz/<Name>/`). Fuzzing needs `-fuzz`, which must match exactly one fuzz test in exactly one package; it runs without limit unless `-fuzztime` is set. (https://go.dev/doc/security/fuzz/, https://pkg.go.dev/cmd/go)
- **Failures** are minimised and written to `testdata/fuzz/<Name>/<hash>`, then act as regression tests. A single execution over 1 second counts as a failure. Targets should be fast, deterministic and stateless. Coverage-guided growth needs AMD64 or ARM64. (https://go.dev/doc/security/fuzz/)
- **`t.Setenv` with `t.Parallel`** (test or any ancestor) panics. (https://pkg.go.dev/testing; panic in https://raw.githubusercontent.com/golang/go/master/src/testing/testing.go, master branch)
- **Loop variables:** per iteration from Go 1.22, for modules declaring that version. **`math/rand/v2`** global generator is always randomly seeded. (https://go.dev/doc/go1.22)
- **`testing/synctest`:** `Test` added in Go 1.25, `Sleep` in 1.27; fake clock inside a "bubble". Mutex waits, I/O and system calls do not count as durably blocked. `T.Run`, `T.Parallel`, `T.Deadline` must not be called inside. (https://pkg.go.dev/testing/synctest, go1.27.4)
- **Benchmarks:** `b.Loop()` (Go 1.24) is preferred over `b.N`; setup and cleanup outside it are untimed and the body is not optimised away. `b.ReportMetric` adds custom units. (https://pkg.go.dev/testing, https://go.dev/doc/go1.24)

## Actionable Techniques

- Separate suites with constraints and mark destructive files `//go:build e2e && !smoke` (design inference), or use a separate directory.
- In CI run `go test` for regressions, then a bounded step per fuzz target: `go test -run='^$' -fuzz='^FuzzX$' -fuzztime=30s ./pkg` (the `-run='^$'` is this note's choice). Commit failing inputs.
- Skip long tests per test with `t.Skip` under `testing.Short()` (https://pkg.go.dev/testing), not by exiting `TestMain`.

## Applies To

| Skill/Agent | Gap (Wave 3 audit) | What the docs add |
|---|---|---|
| go-unit-test | W3B-31 and section gaps | Fuzz CI step, Setenv, synctest, loop semantics |
| go-e2e-test, go-chaos-test, go-makefile | W3B-2, 5, 46, 51 | Tag and `-run` semantics |
| go-performance-test | W3B-16 | `b.Loop`, `ReportMetric` |

## Candidate New Skills/Agents

None.

## Key Terminology

Build Constraint, Seed Corpus, Generated Corpus, Fuzz Target, Bubble, Durably Blocked.

## Caveats

- Source links on `master` move.
- [unverified] That OS or arch behaviour of custom tags matches every third-party tool (see gobco in the coverage note).

## Answers to audit questions

| Question (batch ID) | Answer | Status |
|---|---|---|
| W3B-2: are build tags additive? | Yes | Confirmed (inference for untagged files) |
| W3B-31: does CI need `-fuzz` with `-fuzztime`, one target per run? | Yes; otherwise seeds only | Confirmed |
| W3B-5: do subtest slashes affect a `-run` pattern? | Yes, split per level | Confirmed |
| W3B-46: does an untagged test calling a tag-only symbol fail to compile? | Follows from constraints | Confirmed by inference; not compiled |
| go-unit-test: `t.Parallel` with `t.Setenv` panics | Yes | Confirmed |
| go-unit-test: `testing/synctest` in recent Go | Yes, 1.25 on | Confirmed |
| go-unit-test: `math/rand/v2` auto-seeded; loop semantics depend on `go.mod` version | Yes | Confirmed |
| go-performance-test: Go 1.24 `b.Loop` | Exists | Confirmed |
| W3B-23: release `published` timing | Not a Go question; see GitHub Actions note | Unverified |
