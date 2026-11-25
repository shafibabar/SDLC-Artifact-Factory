# godog Official Documentation
**Authors:** Cucumber project (cucumber/godog)
**Domain:** Testing (behaviour-driven, Go)

Accessed 2026-11-25. Latest release v0.16.0, 2026-07-31 (https://api.github.com/repos/cucumber/godog/releases/latest), MIT (https://pkg.go.dev/github.com/cucumber/godog). Gherkin syntax is in `gherkin-official-reference.md`.

## Core Concepts

- The README warns the API may change before 1.0.0; the `godog` CLI is deprecated in favour of `go test` (https://github.com/cucumber/godog).
- A `TestSuite` with `ScenarioInitializer` and `Options{Format, Paths, TestingT}` is run from a Go test; with `TestingT`, each scenario is a subtest (README; https://raw.githubusercontent.com/cucumber/godog/v0.16.0/suite.go).
- Steps register through `Step`, `Given`, `When`, `Then` with a regexp, string or []byte; all are regular expressions (https://raw.githubusercontent.com/cucumber/godog/v0.16.0/test_context.go).
- State passes through `context.Context`; hooks exist at suite, scenario and step level (README).
- `Options`: `Strict` (fail on pending, undefined or ambiguous steps), `Tags`, `Concurrency`, `Randomize` (0 off, -1 random seed), `StopOnFailure`, `Paths`, `FS`, `FeatureContents` (https://raw.githubusercontent.com/cucumber/godog/main/internal/flags/options.go).
- **Without `Strict`, undefined and pending steps do not fail the suite** (`shouldFail` in v0.16.0 suite.go above).
- With no paths and no `features` directory, nothing runs and the exit is success; `Run` returns 0, 1 or 2; the `events` format returns 0 even on failure (https://raw.githubusercontent.com/cucumber/godog/v0.16.0/run.go).
- Tag expressions: `@a`, `~@a`, `&&`, `,` for OR (README); the OR operator was fixed in v0.16.0 (https://github.com/cucumber/godog/releases).

## Actionable Techniques

- Always set `Strict: true`.
- Fail the test when `suite.Run() != 0`, and assert that features were found (`RetrieveFeatures`) so an empty or mistyped path cannot pass (design inference from run.go).
- Isolate scenario state through context; use `Randomize: -1` to expose leaks.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| bdd-feature-file, go-e2e-test, go-integration-test | D048 methodology; step runner behaviour | Strict, empty-suite pass, regex steps |

## Candidate New Skills/Agents

None.

## Key Terminology

Test Suite, Scenario Initializer, Step Definition, Strict, Pickle.

## Caveats

- [unverified] Cucumber Expressions support elsewhere in the library; none seen in registration.
- [unverified] Supported Gherkin version and keywords such as `Rule`.
- [unverified] Behaviour when a tag filter selects zero scenarios was not run.

## Answers to audit questions

Batch B raises no godog-specific [GK] claim. Added for the rebuild: non-strict runs pass with undefined steps (confirmed from source).
