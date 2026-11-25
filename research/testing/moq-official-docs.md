# moq Official Documentation
**Authors:** Mat Ryer and contributors (matryer/moq)
**Domain:** Testing (Go test doubles)

Accessed 2026-11-25. Latest release v0.8.1, 2026-10-14 (https://api.github.com/repos/matryer/moq/releases/latest). MIT; Go 1.18+ to build from source (https://github.com/matryer/moq).

## Core Concepts

- Generates a struct per interface, normally via `go:generate`: `//go:generate moq -out x_moq_test.go . MyInterface`. Usage `moq [flags] source-dir interface [interface2 ...]`; the source is a directory; `Name:Alias` renames the mock. (README)
- Flags: `-out`, `-pkg`, `-rm`, `-fmt` (gofmt, goimports, noop), `-skip-ensure`, `-stub`, `-with-resets`, `-version`. (README)
- Each method has a `<Method>Func` field and a `<Method>Calls()` record. A nil func panics unless `-stub`, which returns zero values. (README)
- Call recording is guarded by a per-method lock (https://raw.githubusercontent.com/matryer/moq/v0.8.1/internal/template/template.go).

## Actionable Techniques

- Pin the version in `go:generate` tooling and check in CI that regeneration produces no diff (design inference).
- Avoid `-stub` where an unexpected call should fail the test.
- Generated mocks are machine-generated code for coverage exclusion only if they carry the Go marker ([unverified] header text not checked).

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| mock-generation, go-unit-test | W3B-33 | Flags, panic behaviour, call records |

## Candidate New Skills/Agents

None.

## Key Terminology

Mock, Stub mode, Call record.

## Caveats

- [unverified] Whether call assertions are safe while the function field is being reassigned concurrently.

## Answers to audit questions

Batch B raises no moq-specific [GK] claim.
