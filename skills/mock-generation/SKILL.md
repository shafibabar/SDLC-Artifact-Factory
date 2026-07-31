---
name: mock-generation
description: >
  Used by the test-strategist during Implement to design typed test doubles in
  Go — the complete five-type taxonomy (dummy, stub, spy, mock, fake), the
  managed vs. unmanaged dependency decision (the criterion that determines
  whether a test double should verify an interaction at all), the Classical
  (Detroit/Chicago) school chosen over London (mockist), interface isolation
  (mock only consumer-defined ports, never third-party concretions), and
  generation tooling (mockery, gomock, moq). Full taxonomy with per-type Go
  examples and the managed vs. unmanaged dependency table:
  references/test-double-taxonomy.md. Go generation mechanics (mockery YAML
  config, gomock DSL, moq //go:generate, compile-time compliance, CI freshness
  check): references/go-mock-implementation.md.
version: 2.0.0
phase: implement
owner: test-strategist
created: 2026-06-25
tags: [implement, go, mocks, fakes, stubs, test-doubles, mockery, gomock, moq, interface-isolation, managed-dependency, unmanaged-dependency]
related: [go-unit-test, go-integration-test, go-project-structure, test-fixture-design, react-component-testing]
---

# Mock Generation

## Purpose

Unit tests isolate the code under test by replacing its dependencies with test
doubles. A good double is strongly typed (it implements the real interface so it
cannot drift), generated not hand-maintained, and chosen for the job — not every
dependency needs the same kind of double, and choosing the wrong one produces
a test that either verifies too much (breaking on pure refactors) or too little
(letting the wrong behavior through). This skill defines how doubles are created
and used so tests stay fast, honest, and maintainable.

The doubles target the **consumer-defined interfaces** from `go-project-structure`
(small ports like `DataAssetRepository`) — because those interfaces are small,
the doubles are simple.

---

## The Core Decision: Managed vs. Unmanaged Dependencies

Before choosing a double type, answer one question: **is this dependency managed
or unmanaged?**

| Dependency kind | Definition | Verify with |
|---|---|---|
| **Managed** | Fully owned by your app; the outside world never observes it directly (e.g., your own repository, your own in-process service) | A state-based **fake** or a real instance in an integration test — never a call-count mock |
| **Unmanaged** | Its side effect is observable to something outside your app's control (e.g., the outbox relay publishing to Redpanda, an outbound email/SMTP call, a third-party API) | A **mock** that verifies the call happened with the right arguments — the interaction IS the behaviour |

**Only mock unmanaged dependencies.** A managed dependency — your own repository,
your own internal service — gets a fake or gets tested for real. Asserting
`repo.SaveCalls()` has length 1 tests an implementation detail (how the handler
called the repository) rather than the actual contract (the asset's new state is
retrievable afterward).

Full table with this-repo examples (fakeAssetRepo as managed, outbox publish as
unmanaged) and the rationale: `references/test-double-taxonomy.md`.

---

## Classical School, Not London

This repo follows Khorikov's **Classical (Detroit/Chicago) school**, not the
London (mockist) school. The distinction governs how much to isolate:

- **London school** — isolate the *class under test* from every collaborator;
  every dependency, however internal, becomes a mock; tests verify a web of
  interactions.
- **Classical school** — isolate the *test case* from other test cases (no
  shared mutable state); a "unit" of test is a unit of observable behaviour,
  which may span several collaborating types with only true external (unmanaged)
  dependencies replaced.

The classical school is chosen because London-school over-mocking zeros out the
Resistance to Refactoring pillar: any internal restructuring that preserves
external behaviour still turns the suite red. See `go-unit-test`'s
`references/mocking-philosophy.md` for the full four-pillars rationale.

---

## The Double-Picking Decision

Once you know a dependency is the right thing to double, choose the type by
what the test needs to prove. Full five-type taxonomy with per-type Go examples:
`references/test-double-taxonomy.md`.

| Double | What it does | Use when | Verifies |
|---|---|---|---|
| **Dummy** | Passed but never used | Interface requires an argument the test does not exercise | Nothing — structural placeholder only |
| **Stub** | Returns canned values | Dependency must return a specific value to exercise the path under test | State (the result the SUT produces) |
| **Spy** | Records calls, then forwards or does nothing | You want to observe calls *without* failing the test for violations | State + deferred observation |
| **Mock** | Declares expected calls upfront; fails if violated | The *interaction* is the behaviour under test (an unmanaged dependency) | Behaviour (the calls) |
| **Fake** | A working lightweight implementation (e.g., in-memory repo) | You want realistic state-based behaviour without the real dependency | State (the outcome) |

**Prefer fakes and stubs (state-based) over mocks (interaction-based).** Mocks
couple the test to *how* the code calls its dependencies; if that is not the
behaviour you care about, the test becomes brittle. Reserve mocks for when the
interaction itself is the contract (e.g., the outbox publish is written exactly
once) — and only for unmanaged dependencies where that interaction is the
observable side effect.

---

## Generate, Don't Hand-Roll

When a mock is the right tool, generate it from the interface — never hand-write
string-matched call recorders. Generated mocks are type-safe, refactor-safe
(they regenerate when the interface changes), and consistent.

| Tool | Style | Default |
|---|---|---|
| **mockery** (vektra/mockery) | YAML-configured, generates entire packages at once | Yes — use for most interfaces |
| **gomock** (uber-go/mock; `mockgen`) | GoMock expectation DSL; per-file or reflect mode | Use when richer EXPECT().Return().Times() DSL is needed |
| **moq** (matryer/moq) | Simple struct of func fields; minimal generated code | Use for small, one-off interfaces where reading is key |

Default to **mockery** for this repo's consumer-defined ports; **gomock** when the
test needs a rich expectation DSL. Full generation mechanics, YAML config, and
CI freshness check: `references/go-mock-implementation.md`.

---

## Compile-Time Interface Compliance

Every hand-written fake must assert at compile time that it satisfies the
interface — so it can never silently diverge from the real port as the interface
evolves:

```go
var _ domain.DataAssetRepository = (*fakeAssetRepo)(nil)
```

This is the cheap guard that keeps fakes honest. Full fake implementation
example (with all repository methods): `references/go-mock-implementation.md`.

---

## Mocking at the Right Boundary

Mock the **consumer-defined port**, not concrete types or third-party libraries:

- Mock `domain.DataAssetRepository` (your small interface).
- Do not mock `*pgxpool.Pool` or `*kgo.Client` — those are integration concerns;
  test them for real with Testcontainers (see `go-integration-test`).

This keeps unit tests about *your* logic and pushes real-dependency verification
to the integration layer where it belongs. Over-mocking (mocking everything,
including things you do not own) produces tests that pass while the system is
broken.

---

## Frontend Parity

The frontend applies the same philosophy with a different tool: **MSW** mocks the
network at the boundary (not the hooks), so components run real data-fetching
code against controlled responses (see `react-component-testing`). Same
principle — mock at the edge, against the real contract — different layer.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Right double | Type chosen from 5-type taxonomy by what the test proves | Mock everywhere, even for state checks |
| Managed/unmanaged decision made | Managed dependencies get fakes or integration tests | Call-count mocks on repositories |
| Classical school applied | Only unmanaged dependencies verified via interaction | Every collaborator mocked (London-style) |
| Generated mocks | mockery/gomock/moq from the interface; CI freshness check | Hand-rolled string-matched mocks |
| Compile compliance asserted | `var _ Iface = (*fake)(nil)` on fakes | Doubles that can silently diverge |
| Right boundary | Mock consumer-defined ports, not pgx/kgo | Mocking third-party concretions in unit tests |
| Not over-mocked | Prefer fakes for managed deps; mock only unmanaged | Everything mocked; tests pass on broken systems |

---

## Anti-Patterns

- **Mocking managed dependencies** — asserting `SaveCalls()` on a repository
  tests how the handler happened to call the repo, not the actual contract
  (resulting state); managed dependencies get a fake or an integration test.
- **Interaction-verifying everything** — asserting call counts and argument order
  on every dependency couples the test to the implementation; a pure refactor
  turns the suite red. Verify state unless the interaction IS the contract.
- **Mocking types you do not own** — a mocked `*pgxpool.Pool` encodes your guess
  about pgx's behaviour; when the guess is wrong the test passes and production
  fails. Wrap it in a port; integration-test the real thing.
- **Hand-rolled mocks with string-based dispatch** — `calls["Save"]++` style
  recorders are refactor-blind and typo-prone; generation from the interface is
  free and type-safe.
- **Editing generated mock files** — regeneration erases the edit; behaviour
  belongs in the test's configured funcs, customization belongs in a
  hand-written fake.
- **A "god fake" with test-specific branching** — a fake that inspects inputs to
  decide which test it is serving is hidden coupling; keep fakes generic.
- **Doubles without compile-time compliance** — `var _ Iface = (*fake)(nil)` is
  free and catches interface drift at build time.
- **Asserting on a stub** — if a double's calls are only there to arrange input,
  do not verify them; if you want to verify them, the double is functioning as a
  mock and should only exist for an unmanaged dependency.

---

## Output Format

Produces generated mocks, hand-written fakes, and the generate directives:

```
internal/**/<iface>_mock.go              (GENERATED — mockery/gomock/moq)
internal/test/fakes/*.go                 (hand-written fakes for managed ports)
.mockery.yaml                            (mockery configuration at repo root)
//go:generate ...                        (directives beside each interface)
```

Full Go code for each artifact: `references/go-mock-implementation.md`.
