---
name: mock-generation
description: >
  Teaches how to create strongly-typed test doubles in Go — the stub/fake/mock
  distinction and when to use each, generating mocks from consumer-defined
  interfaces with native tools (mockgen, moq, counterfeiter) rather than hand-rolled
  string matchers, keeping mocks honest with interface compliance, and preferring
  fakes over mocks for state-based testing. Supports go-unit-test and
  go-integration-test. Used by the test-strategist during Implement.
version: 1.1.0
phase: implement
owner: test-strategist
created: 2026-06-25
tags: [implement, go, mocks, fakes, stubs, test-doubles, mockgen, moq]
---

# Mock Generation

## Purpose

Unit tests isolate the code under test by replacing its dependencies with test doubles. A good double is strongly typed (it implements the real interface, so it can't drift), generated (not hand-maintained), and chosen for the job — a stub for canned answers, a fake for realistic behaviour, a mock for verifying interactions. This skill defines how doubles are created and used so tests stay fast, honest, and maintainable.

The doubles target the **consumer-defined interfaces** from `go-project-structure` (small ports like `DataAssetRepository`) — because those interfaces are small, the doubles are simple.

---

## Stub vs Fake vs Mock

| Double | What it does | Use when | Verifies |
|---|---|---|---|
| **Stub** | Returns canned values | You need the dependency to return something specific | State (the result) |
| **Fake** | A working lightweight implementation (e.g., in-memory repo) | You want realistic behaviour without the real dependency | State (the outcome) |
| **Mock** | Records calls and asserts they happened as expected | The *interaction* is the behaviour under test | Behaviour (the calls) |

**Prefer fakes and stubs (state-based) over mocks (interaction-based) where possible.** Mocks couple a test to *how* the code calls its dependencies; if that's not the behaviour you care about, the test becomes brittle. Reserve mocks for when the interaction itself is the contract (e.g., "the outbox is written exactly once").

```go
// Fake: an in-memory repository — realistic, reusable, asserts on resulting state.
type fakeAssetRepo struct{ store map[uuid.UUID]*domain.DataAsset }
func (f *fakeAssetRepo) FindByID(_ context.Context, id uuid.UUID) (*domain.DataAsset, error) {
    a, ok := f.store[id]
    if !ok { return nil, domain.ErrNotFound }
    return a, nil
}
func (f *fakeAssetRepo) Save(_ context.Context, a *domain.DataAsset) error { f.store[a.ID()] = a; return nil }
```

A small fake like this is often clearer and less brittle than a generated mock — use it for the common case.

---

## Generate, Don't Hand-Roll

When a mock *is* the right tool (interaction verification), generate it from the interface with a native tool — never hand-write string-matched call recorders. Generated mocks are type-safe, refactor-safe (they regenerate when the interface changes), and consistent.

| Tool | Style | Notes |
|---|---|---|
| **`mockgen`** (uber/golang) | Official-lineage, GoMock | Mature; expectation API; `//go:generate` friendly |
| **`moq`** | Simple struct of func fields | Minimal, very readable generated code; great for small interfaces |
| **`counterfeiter`** | Fakes with call recording | Rich introspection (call counts/args) |

Default to **`moq`** for the small consumer-defined ports (its output is simple and easy to read); `mockgen` when you want a richer expectation DSL.

```go
//go:generate moq -out dataasset_repo_moq.go . DataAssetRepository
// Generated mock implements the interface; tests configure its funcs:
repo := &DataAssetRepositoryMock{
    FindByIDFunc: func(_ context.Context, id uuid.UUID) (*domain.DataAsset, error) { return sampleAsset, nil },
    SaveFunc:     func(_ context.Context, a *domain.DataAsset) error { return nil },
}
// After exercising the code, assert the interaction:
require.Len(t, repo.SaveCalls(), 1)
require.Equal(t, sampleAsset.ID(), repo.SaveCalls()[0].A.ID())
```

Generation runs via `go generate` and is checked for freshness in CI (`git diff --exit-code`) — a stale mock (interface changed, mock not regenerated) fails the build.

---

## Compile-Time Interface Compliance

Every hand-written fake asserts at compile time that it satisfies the interface — so it can never silently diverge from the real port:

```go
var _ domain.DataAssetRepository = (*fakeAssetRepo)(nil) // fails to compile if the interface changes
```

This is the cheap guard that keeps doubles honest as the real interface evolves.

---

## Mocking at the Right Boundary

Mock the **consumer-defined port**, not concrete types or third-party libraries:

- ✅ Mock `domain.DataAssetRepository` (your small interface).
- ❌ Don't mock `*pgxpool.Pool` or `*kgo.Client` — those are integration concerns; test them for real with Testcontainers (see `go-integration-test`).

This keeps unit tests about *your* logic and pushes real-dependency verification to the integration layer where it belongs. Over-mocking (mocking everything, including things you don't own) produces tests that pass while the system is broken.

---

## Frontend Parity

The frontend uses the same philosophy with a different tool: **MSW** mocks the network at the boundary (not the hooks), so components run real data-fetching code against controlled responses (see `react-component-testing`). Same principle — mock at the edge, against the real contract — different layer.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Right double | Stub/fake for state, mock for interaction | Mocks everywhere, even for state checks |
| Generated mocks | `moq`/`mockgen` from the interface; CI freshness check | Hand-rolled string-matched mocks |
| Compliance asserted | `var _ Iface = (*fake)(nil)` on fakes | Doubles that can silently diverge |
| Right boundary | Mock your small ports, not pgx/kgo | Mocking third-party concretes in unit tests |
| Not over-mocked | Prefer fakes; mock only what the test is about | Everything mocked; tests pass on broken systems |
| Refactor-safe | Doubles regenerate/compile-check on interface change | Doubles drifting from the real interface |

---

## Anti-Patterns

- **Interaction-verifying everything** — asserting call counts and argument order on every dependency welds the test to the implementation; a pure refactor turns the suite red. Verify state unless the interaction *is* the contract.
- **Mocking types you don't own** — a mocked `*pgxpool.Pool` encodes your guess about pgx's behaviour; when the guess is wrong the test passes and production fails. Wrap it in a port; integration-test the real thing.
- **Hand-rolled mocks with string-based dispatch** — `calls["Save"]++` style recorders are refactor-blind and typo-prone; generation from the interface is free and type-safe.
- **Editing generated mock files** — regeneration erases the edit; behaviour belongs in the test's configured funcs, customization belongs in a hand-written fake.
- **A "god fake" with test-specific branching** — a fake that inspects inputs to decide which test it's serving is hidden coupling; keep fakes generic, configure per-test via the double's funcs/fields.
- **Doubles without compile-time compliance** — a fake that no longer satisfies the port compiles fine until the one test that needs the missing method; `var _ Iface = (*fake)(nil)` catches it at build.

---

## Output Format

Produces generated mocks, hand-written fakes, and the generate directives:

```
internal/**/<iface>_moq.go             (GENERATED test doubles)
internal/test/fakes/*.go                (hand-written fakes for common ports)
//go:generate moq ...                   (directives beside each interface)
```
