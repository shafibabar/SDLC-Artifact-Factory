# Testing Error Paths

Full worked material for `SKILL.md`'s "Testing Error Paths" section.
Self-contained — reads without the parent body already in context.

---

## 1. Error-Path Coverage Expectation

Every function whose signature includes a non-nil `error` return gets at least
one test case that actually drives it down an error-returning path — not merely
a happy-path test that incidentally never exercises `if err != nil`. This is a
coverage expectation, not a coverage-percentage target: a function with three
distinct ways to fail (three different validation rules, two different sentinel
returns) gets a test case per distinct failure, not one generic "some error
happens" case.

The table-driven structure `go-unit-test` establishes as this repo's default
test shape (`references/` there; also Donovan & Kernighan ch. 11, the pattern's
original popularisation in Go) is the natural fit: a `wantErr` field per case
turns "add a new failure mode" into "add a table row," not a new test function.

```go
tests := []struct {
    name    string
    input   string
    wantErr error // nil means success expected
}{
    {name: "valid input succeeds", input: "ok", wantErr: nil},
    {name: "empty input rejected", input: "", wantErr: ErrInvalidInput},
}
```

## 2. Asserting on Wrapped Errors — Correctly

The assertion must match the taxonomy (`references/error-taxonomy-and-wrapping.md`
§1) the function under test actually uses:

- **Sentinel error** → `errors.Is(err, target)`.
- **Typed error** → `errors.As(err, &target)`, then assert on the extracted
  struct's fields, not just that the extraction succeeded.

```go
// Sentinel:
if !errors.Is(err, domain.ErrNotFound) {
    t.Fatalf("got %v, want %v", err, domain.ErrNotFound)
}

// Typed — extract AND check the fields, since a wrong-but-right-shaped
// value would otherwise pass:
var dg *domain.ErrSensitivityDowngrade
if !errors.As(err, &dg) {
    t.Fatalf("got %v, want *ErrSensitivityDowngrade", err)
}
if dg.From != tt.wantFrom || dg.To != tt.wantTo {
    t.Fatalf("got downgrade %s→%s, want %s→%s", dg.From, dg.To, tt.wantFrom, tt.wantTo)
}
```

`go-domain-model`'s `references/aggregate-invariant-enforcement.md` has the full
worked table-driven test for `Classify` built on exactly this pattern, extended
with the two additional axes a domain-model test must also prove (state
unchanged on rejection, correct event count both ways) — that file is the
canonical worked instance; this file states the general rule those additional
axes sit on top of.

## 3. What Fails to Prove Anything

| Anti-pattern | Why it's worthless |
|---|---|
| `if err == nil { t.Fatal(...) }` and nothing else | Passes for **any** error — a `nil`-pointer panic converted to an error, a completely wrong sentinel, a typo'd message. Proves only that the function failed somehow, never that it failed for the *right* reason. |
| `strings.Contains(err.Error(), "not found")` | Breaks the moment a message is reworded (`references/error-message-standards.md`) or a wrap layer is added/removed — the message text is not a stable contract, `errors.Is`/`errors.As` against the underlying value is. |
| `err.Error() == "exact expected string"` | Same fragility as above, worse — any wrap-chain change at any layer breaks every test asserting the literal string, even ones testing unrelated behaviour. |
| Testing only the happy path "because the error path is obvious" | The error path is exactly the code most likely to regress silently — a refactor that changes which sentinel a branch returns compiles cleanly and passes every happy-path test. |

## 4. Testing the Nil-Interface Footgun Itself

`references/worked-example.md`'s compiled, verified example is also the test
pattern for catching this specific class of regression: on every declared
no-error path, assert `err == nil` is literally `true` — a bare `error`-typed
interface comparison. This is the one place in this file's standard where plain
`==` identity, not `errors.Is`, is the right tool: there is no wrap chain
involved, and the whole point of the assertion is verifying the interface
value itself (type word and value word both zero), not locating a sentinel
somewhere inside a chain.
