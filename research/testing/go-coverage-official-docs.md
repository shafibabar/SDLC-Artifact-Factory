# Go Code Coverage and Branch Coverage Tools
**Authors:** The Go project; third-party tool maintainers (official repositories and pkg.go.dev)
**Domain:** Testing (Go); decision D048 follow-up A (100% line and branch)

Accessed 2026-11-25. Go release go1.27.4 (https://go.dev/VERSION?m=text). Nothing was installed or run.

## Core Concepts

### What `go test -cover` measures
- **Statements, by source block.** Reports are "percent of statements" (https://go.dev/doc/build-cover; https://go.dev/blog/cover, 2013, Go 1.2). The tool approximates basic blocks from source and does not probe inside `&&` and `||` (https://raw.githubusercontent.com/golang/go/master/src/cmd/cover/doc.go, cover.go).
- **No branch coverage.** The request to add it was closed in 2018; Rob Pike said its absence follows from the design and favoured keeping it simple (https://github.com/golang/go/issues/28888). A newer proposal, opened 2024-11-12, is open with no Go team decision shown (https://github.com/golang/go/issues/70306).
- Case and comm clause bodies each get a counter; an `if` without `else` has no counter for the false path (inference from https://raw.githubusercontent.com/golang/go/master/src/cmd/cover/cover.go).
- **Modes:** `set` (default), `count`, `atomic` (default with `-race`). Without `-coverpkg`, each package's tests count only that package. (https://pkg.go.dev/cmd/go)
- Since Go 1.22, packages without tests report 0.0% instead of being silent (https://go.dev/doc/go1.22).
- The printed percentage has one decimal (`%.1f`) in `go tool cover -func` (https://raw.githubusercontent.com/golang/go/master/src/cmd/cover/func.go), so a tiny gap can print as 100.0% (inference).
- **Generated files are not excluded.** The proposal to exclude them was closed as not planned on 2026-01-25; filtering belongs at the reporting layer (https://github.com/golang/go/issues/77306). Marker: `^// Code generated .* DO NOT EDIT\.$` (https://pkg.go.dev/cmd/go).
- **Binaries:** `go build -cover`, `GOCOVERDIR`, `go tool covdata percent|textfmt|merge`; data is lost on panic or fatal signal. (https://go.dev/doc/build-cover)

### Branch tools

| Tool | Method | Last release | Licence | Limits |
|---|---|---|---|---|
| gobco (`rillig/gobco`) | Own source instrumentation; condition mode, or `-branch` | v1.3.4, 2024-03-08 (https://pkg.go.dev/github.com/rillig/gobco?tab=versions); last commit seen 2026-05-03, not archived (https://api.github.com/repos/rillig/gobco) | BSD-2-Clause | See below |
| go-bcov (`alx99/go-bcov`) | Derived from the Go profile plus AST; `if` and `switch` | v1.0.4, 2024-09-18 (https://pkg.go.dev/github.com/alx99/go-bcov) | BSD-3-Clause | Repository URL returned 404 |
| gocoverageplus (`Fabianexe/gocoverageplus`) | Profile plus AST; method and file level | v1.2.0, 2026-03-22 (https://pkg.go.dev/github.com/Fabianexe/gocoverageplus?tab=versions) | [unverified] Apache-2.0 per a search summary | A multi-condition `if` is one branch (https://raw.githubusercontent.com/Fabianexe/gocoverageplus/main/README.md) |

### gobco detail
- `-branch` instruments whole `if` and `for` conditions; `switch` and type-switch cases are instrumented in both modes. `select` is not covered; unused functions without conditions are not seen. `range` loops have no instrumentation. Boolean expressions outside controlling positions are skipped in `-branch` mode. (https://raw.githubusercontent.com/rillig/gobco/v1.3.4/README.md, .../v1.3.4/instrumenter.go, .../master/instrumenter.go)
- Output `Branch coverage: x/y` plus each unmet condition; `-stats file` saves JSON. Flags include `-test` (pass options to `go test`), `-list-all`, `-cover-test`. (https://raw.githubusercontent.com/rillig/gobco/v1.3.4/main.go, .../master/main.go)
- **No threshold; incomplete coverage does not fail the exit status.** **One package per run.** (https://raw.githubusercontent.com/rillig/gobco/master/main.go)
- No exclusion flag appears in the flag list (same file).
- File selection uses only GOOS and GOARCH, so custom build tags are not honoured: tag-only files can report `0/0`; platform-split files can panic "redeclared" (open issue, 2026-09-28: https://github.com/rillig/gobco/issues/40).
- Other open issues: black-box test using `export_test.go` panics (#42, 2026-10-08); Kubernetes integration `TestMain` panic (#38); nested packages (#12) (https://github.com/rillig/gobco/issues).
- `TestMain` must call `os.Exit` explicitly (or the Etcd form) (https://raw.githubusercontent.com/rillig/gobco/master/instrumenter.go).
- Declares `go 1.16` minimum (https://raw.githubusercontent.com/rillig/gobco/master/go.mod). The README warns older syntactic-only analysis: write `cond == true` for bare booleans (v1.3.4 README; may be out of date).

## Actionable Techniques (recommendation; design is this note's)

1. **Line gate:** `go test -covermode=atomic -coverpkg=./... -coverprofile=...`; a script drops files with the generated marker and approved exclusions, then fails on **any block with a zero count**. Never compare the printed percentage. Report it as statement coverage by line range.
2. **Branch gate:** gobco pinned at v1.3.4, `-branch`, once per package. A tested wrapper requires `x == y`, fails on tool error or panic, treats `0/0` as a failure unless the package truly has no conditions, and filters generated or approved files.
3. Define "branch" to the product owner: both outcomes of `if`/`for` conditions and switch cases (gobco), `select` clauses via the statement gate. Zero-iteration `range` is measured by neither.
4. Before committing, run a spike in the throwaway environment on go1.27.4 with generics, build tags, `TestMain` and external test packages. If it fails, take the gap to the product owner; do not silently drop the branch gate.

## Applies To

| Skill/Agent | Gap | What this adds |
|---|---|---|
| go-unit-test (coverage-by-quadrant), go-makefile, ci-pipeline, test-pyramid | D048 A | Two gates, both needing wrapper scripts |

## Candidate New Skills/Agents

None. The two gate scripts need one owning skill.

## Key Terminology

Statement Coverage, Basic Block, Branch Coverage, Condition Coverage.

## Caveats

- [unverified] gobco on go1.27.4, with generics, or with newer syntax; no run was made.
- [unverified] How `-test=-tags=...` behaves given issue #40.
- [unverified] Statements after a runtime panic inside one block may show as covered (inference from block counters).
- [unverified] Whether any other maintained tool exists; searches found only forks and the tools above. `srvgit/gocove` returned 404; `gocover-cobertura` is reported (search summary, https://pkg.go.dev/github.com/boumenot/gocover-cobertura) to write branch rate 0.
- gobco has one maintainer account and no release since 2024.

## Answers to audit questions

| Question | Answer | Status |
|---|---|---|
| D048 A: does Go measure branch coverage? | No | Confirmed |
| Is an extra tool needed? | Yes; gobco is the closest fit, with limits above | Confirmed need; fitness unverified |
| D048 A: does Go exclude generated code from coverage? | No | Confirmed |
