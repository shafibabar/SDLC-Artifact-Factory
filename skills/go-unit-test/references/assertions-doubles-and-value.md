# Assertions, Doubles and What a Test Is Worth

Self-contained. Use when deciding what to assert, what to replace, or how to judge a test.

## Failure messages

A failure names the call, the inputs, the got value and the want value.

```go
// a, b and want come from the table row.
if got := a.IsHigherThan(b); got != want {
	t.Errorf("IsHigherThan(%q, %q) = %v, want %v", a, b, got, want)
}
```

- Domain tables: standard library `t.Errorf` and `t.Fatalf`; the row supplies the exact message.
- Application and integration layers, where the same checks repeat: `testify/require` is accepted (`require` stops the test; `assert` continues).
- Never collapse a comparison into a boolean (`assert.True(t, got == want)`): both values vanish. Use `Equal`.
- Never `t.Fail()` with no message.

## Errors

Assert identity: `errors.Is(err, ErrX)`, or `errors.As` and then the typed error's fields. Message text is not a contract. `if err == nil { t.Fatal() }` alone passes for any error.

On a success path assert `err == nil`: a function returning a nil typed pointer as `error` yields a non-nil error (seen).

## HTTP handlers

`httptest.NewRequest` and `httptest.NewRecorder` call a handler without a socket; assert status, headers that matter and body. Keep handlers thin (Humble Object): decisions move into plain types that are tested directly.

## Doubles: `mock-generation` owns the rules

School: Khorikov's classical one. Isolate each test from other tests; run the real domain code; replace only what lies outside the application.

| Dependency | In a unit test |
|---|---|
| Own database, repository or in-process service (managed) | Fake, or the real thing in an integration test; assert state, never its calls |
| Publish, email, third-party API (unmanaged) | moq mock; assert the call, its arguments and count |
| A call that only feeds data in (stub) | Never assert on it |

Double only a port the consumer defines. Load `mock-generation` before writing one.

## Four pillars

Judge a test on protection against regressions, resistance to refactoring, fast feedback and maintainability. They multiply: a zero on one makes the test poor however well it does on the others (Khorikov).

Assert behaviour through the public surface, not internal state: no asserting a private field or internal call count. A test that breaks on a refactor that preserved behaviour is a false alarm and teaches the team to ignore red. A private function that seems to need its own test is a type waiting to be extracted.

## Which code, which tests

| Quadrant | Domain complexity | Collaborators | Where its behaviour is proven |
|---|---|---|---|
| 1 Domain logic | High | Few | Thorough table-driven unit tests: most of the effort |
| 2 Overcomplicated | High | Many | Split first: logic to quadrant 1, wiring to quadrant 3 |
| 3 Controllers | Low | Many | A few integration tests, plus `httptest` for a handler's own paths; not a web of mocks |
| 4 Trivial | Low | Few | Exercised through the behaviour that uses it |

The quadrant decides which test covers the code, never whether it is covered: the product's gate is 100% of lines and branches. Code no behaviour test reaches gets its own small test, or is listed as an exclusion for the product owner. See `./coverage-gates.md` for why the branch gate needs those tests in the same package.
