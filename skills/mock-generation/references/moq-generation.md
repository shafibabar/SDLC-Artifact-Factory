# Generating Mocks with moq

Self-contained. Use when adding, regenerating, migrating or excluding a generated Go mock. Tool facts come from moq's README and template at v0.8.1 (accessed 2026-11-25). Nothing here has been run.

## Directive

Put it beside the port, in the hand-written file that declares the interface:

```go
//go:generate go run github.com/matryer/moq@v0.8.1 -out welcome_sender_moq.go . WelcomeSender
type WelcomeSender interface {
	SendWelcome(ctx context.Context, email string) error
}
```

- Usage is `moq [flags] source-dir interface [interface ...]`. The source is a directory. `Name:Alias` renames the generated type.
- Output name: `<port>_moq.go`, in the consuming package (`go-project-structure`). For another package use `-pkg`.
- Pin the version. Never `@latest`.
- The plugin's TDD hook refuses a new hand-written `.go` file with no matching test, including a file that holds only an interface or only directives. Write the matching test first.
- The generated file is written by `go generate`, not by an editor. Never edit it: regeneration overwrites it.

## Flags

| Flag | Effect | Use here |
|---|---|---|
| `-out` | Output file | Always |
| `-pkg` | Package name of the output | When it differs from the source |
| `-fmt` | `gofmt`, `goimports` or `noop` | Optional |
| `-rm` | Listed in the README's flags; check `moq -help` for its effect | Optional |
| `-stub` | A method with a nil func returns zero values instead of panicking | Avoid where an unexpected call should fail the test |
| `-skip-ensure` | Skips the "ensure" step; from its name, the compile-time interface check | Do not pass it |
| `-with-resets` | Listed in the README; from its name, adds reset methods | Not needed: build a new mock per test |
| `-version` | Prints the version | Diagnosis |

## What the generated type does

- One struct per interface, a `<Method>Func` field and a `<Method>Calls()` record per method.
- Calling a method whose func is nil **panics**, so the test run fails. Set exactly the funcs the scenario expects.
- It records calls and **verifies nothing**. The test asserts `len(x.MethodCalls())` and the recorded arguments, or the mock is only a stub.
- Call recording is guarded by a per-method lock. Whether it is safe to reassign a func field while goroutines call it is unverified: set funcs before starting them.
- The type name (`WelcomeSenderMock`) and the record field names (parameter names, capitalised) in these examples are unverified: read them from the generated file.

## Freshness in CI

Regenerate, then require a clean tree, untracked files included:

```makefile
.PHONY: generate-check
generate-check:
	go generate ./...
	@test -z "$$(git status --porcelain)" || { git status --porcelain; echo "generated code is stale or not committed"; exit 1; }
```

It belongs in the `ci` target that `go-makefile` owns, on a clean checkout. `git diff --exit-code` alone misses a newly generated, uncommitted file. A `_moq.go` file with no directive is never regenerated, so this check stays green while it ages; `validate-test-doubles.sh` (this skill's script) reports it.

## Coverage and mutation

- Go does not exclude generated files from coverage. The gate script drops files carrying the marker line matching `^// Code generated .* DO NOT EDIT\.$`, and the branch tool's wrapper filters them too.
- That moq v0.8.1 writes exactly such a line is unverified. Look at the first lines of the generated file; the script fails a `_moq.go` without it. If it is absent, the file is not automatically excluded: report it.
- A filter keyed on names must match `_moq.go`. One that matches only `_mock.go` counts the mock.
- Record each generated mock in the strategy's exclusion register: path or pattern (`**/*_moq.go`), kind `generated`, reason, approval. Adding an entry edits an approved artifact, which returns it to the product owner.
- Mutation: the exclusion setting (Gremlins `unleash.exclude-files`) covers generated files and approved exclusions only.
- Hand-written fakes, port suites and helpers under `internal/test/` are counted. Cover them or list them for approval.

## Replacing mockery, gomock or testify mocks

Plan first, then change:

1. List every double: port, tool, tests using it, managed or unmanaged.
2. For each: managed becomes a fake (or the test moves to integration) with state assertions; unmanaged becomes a moq mock with `Calls()` assertions; a query becomes a stub with no assertion.
3. Check expectations the old tool enforced on its own (call counts, "never called") and write each one that matters as an explicit assertion. moq enforces none, so a dropped assertion fails silently.
4. Check the list against the rules, then change one port at a time.
5. Remove the old directives, generator configuration (such as `.mockery.yaml`), generated files and module dependency; run the freshness check and the validator.
