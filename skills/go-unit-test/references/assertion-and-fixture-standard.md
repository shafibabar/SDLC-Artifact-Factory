# Assertion, Fixture, and Flakiness-Prevention Standard

Full grounding for `go-unit-test`'s "Assertion-Style Standard," "Test-Data and Fixture Standard," and "Flakiness Prevention" sections. Self-contained.

---

## Assertion Style: A Layered Convention, Stated Precisely

This repo does not pick one assertion library for every Go test — it applies a convention by layer, and the reasoning for each layer is different:

**Quadrant-1 domain-model table-driven tests: plain stdlib `t.Errorf`/`t.Fatalf`.** Every row of a table-driven case already carries the exact input and the exact want value; a hand-written format string can therefore produce the single most specific failure message possible for that row, naming the operation, the input, the got value, and the want value in one line. No generic library assertion beats a message written for the exact case it's reporting on. This is the pattern `go-domain-model`'s `references/aggregate-invariant-enforcement.md` uses throughout — `t.Fatalf("got %d events, want exactly 1", len(events))`, `t.Fatalf("sensitivity mutated on rejected call: got %v, want unchanged %v", ...)` — and it is the standard this skill's own worked example (`references/worked-example.md`) follows too.

**Application/integration-layer tests: `testify/require`.** At this layer, tests are less exhaustively table-shaped and more about wiring correctness — does the handler call the right port, does the repository round-trip through real SQL — where the same handful of checks (`require.NoError`, `require.Equal`, `require.ErrorIs`, `require.Len`) repeat across many tests. Boilerplate reduction matters more here than per-case message customization, and `require`'s default messages are legible enough for a non-exhaustive check. This is the established pattern already in `go-repository-pattern`, `go-integration-test`, and `mock-generation`'s own worked examples.

**`require` vs. `assert` where testify is in play:** `require` stops the test on failure (use for preconditions — if the setup call failed, continuing produces confusing downstream failures); `assert` continues (use to collect multiple independent checks in one test so a run reports every failing check, not just the first).

### The Failure-Message Template

Every assertion, in either layer, states four things: the operation, the input(s), the got value, and the want value.

```go
// Good — stdlib, quadrant 1: operation, input, got, want, all in one line.
if got := tt.a.IsHigherThan(tt.b); got != tt.want {
    t.Errorf("IsHigherThan(%q,%q) = %v, want %v", tt.a, tt.b, got, tt.want)
}

// Good — testify, application layer: two-value equality preserves both sides.
require.Equal(t, want, got, "Classify(%q)", input)
```

### The One Forbidden Shape: Boolean-Collapsing Assertions

```go
// WRONG — collapses got and want into a single boolean before asserting; the
// failure message can say only "expected true, got false," naming neither value.
assert.True(t, got == want)

// RIGHT — the two-value form keeps both sides in the failure output.
assert.Equal(t, want, got)
```

`assert.True`/`require.True` are reserved for genuine boolean predicates with no natural "expected vs. actual" pair (`assert.True(t, asset.IsClassified())`) — never as a substitute for an equality check that has two concrete values worth reporting.

A bare `t.Fail()` with no message is never acceptable in either layer — "expected X, got Y" is the floor, not a nicety.

---

## Test-Data and Fixture Standard (Unit Layer)

Unit-test fixtures are **small, inline, readable struct literals** — the table itself, or a handful of local variables built directly in the test function. This is deliberately different from `test-fixture-design`'s guidance for the integration/e2e layer, which owns the **builder pattern** (sensible defaults, per-test overrides) for constructing larger, more realistic seed data, and **golden files** for asserting complex output. At the unit layer:

- A fixture that needs more than a few fields to express is a signal the test is exercising more than one behaviour — split it, don't reach for a builder to hide the complexity.
- A golden file at the unit layer defeats the purpose of a table-driven case: the point of the table is that every input/want pair is visible in the test file itself, scannable without opening a second file. Golden files earn their keep only where the expected output is genuinely large and unwieldy to inline (a full JSON payload, a rendered template) — that is an integration/e2e-layer concern, not a unit-layer one.
- Fixtures are constructed **inside** the test or subtest closure, never hoisted to package scope — package-level fixture state is exactly the shared-mutable-state hazard `t.Parallel()`'s safety rule warns against.

```go
// Right — inline, local, visible in the table itself.
tests := []struct {
    name  string
    asset domain.DataAsset
    want  bool
}{
    {"classified asset satisfies the check", mustBuildClassifiedAsset(t), true},
}
```

---

## Flakiness-Prevention Standard

A flaky unit test — one that passes and fails nondeterministically with no code change — destroys trust in the whole suite faster than an outright broken one, because a team trains itself to re-run instead of investigate. Four disciplines eliminate the common causes at the unit layer:

**No `time.Sleep`.** A unit test that sleeps to "wait for" something is either racing a nondeterministic outcome (flaky by construction) or is secretly testing an asynchronous, real-dependency path (an integration test wearing a unit test's clothes — move it to `go-integration-test`, which polls with a deadline instead of sleeping, for exactly this reason). The fix inside a true unit test: inject the clock. `go-domain-model`'s Aggregates already take `now time.Time` as a parameter rather than calling `time.Now()` internally — a unit test supplies a fixed `time.Date(...)` value and asserts against it directly, no waiting involved.

**No real network or filesystem calls.** A unit test that opens a socket, calls a real HTTP endpoint, or reads/writes a real file is not isolated, full stop — regardless of intent, this is `go-integration-test`'s territory. `go-unit-test`'s own "Isolation" rule (no real FS/network/DB/clock) exists precisely to keep this boundary bright-line rather than a judgment call per test.

**Deterministic randomness.** Code under unit test must never call an unseeded top-level `math/rand` function (`rand.Intn`, `rand.Float64`) and expect a deterministic assertion to hold — the test's pass/fail becomes a function of which random value happened to come out. Two correct patterns: inject a seeded `*rand.Rand` (`rand.New(rand.NewSource(fixedSeed))`) so the sequence is reproducible across runs, or — where the actual value doesn't matter, only that *some* value was produced — treat randomness as a collaborator and stub it to a fixed return in the test, the same way a clock is injected.

**Order-independence.** `go test -shuffle=on` must stay green for every package. A fixture standard that leaves any shared mutable package-level state between test functions (a `var` incremented by one test and read by another, a shared fake left populated from a prior test) violates this immediately and is caught the same way `t.Parallel()` unsafety is caught — by running the suite shuffled and looking for a test that only fails in some orderings.
