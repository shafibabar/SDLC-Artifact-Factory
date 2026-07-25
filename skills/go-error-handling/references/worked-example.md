# Worked Example: The Nil-Interface Footgun

This is the full wrong/right worked example for "The Nil-Interface Footgun" section of `go-error-handling/SKILL.md`. It uses the same `ValidationError` type already introduced in that skill's "Sentinel Errors and Typed Errors" section:

```go
type ValidationError struct {
    Field   string
    Message string
}
func (e ValidationError) Error() string { return e.Field + ": " + e.Message }
```

## The bug

```go
// WRONG: verr is a nil *ValidationError on the happy path, but the function's
// declared return type is the error INTERFACE, not *ValidationError.
func classify(input string) error {
    var verr *ValidationError // nil concrete pointer — type word is *ValidationError
    if input == "" {
        verr = &ValidationError{Field: "input", Message: "required"}
    }
    return verr // BUG: always a non-nil error interface, even when verr was never assigned
}

// At the call site:
err := classify("ok") // input is valid — verr was never assigned inside classify
if err != nil {
    // This branch runs even though nothing went wrong. The interface's type
    // word is *ValidationError; only its value word is nil. Calling err.Error()
    // here would even panic — ValidationError.Error() has a value receiver, so
    // invoking it through a nil *ValidationError dereferences a nil pointer.
    log.Fatal("unreachable, but reached: ", err)
}
```

This was verified directly (not just reasoned about): compiled and run against Go 1.23.4, `classify("ok")` returns an `error` for which `err == nil` is `false`, and calling `err.Error()` on it panics with `runtime error: invalid memory address or nil pointer dereference` — confirming both halves of the footgun (the surprising non-nil check, and the further landmine of calling a value-receiver method through the nil pointer).

## Two correct fixes

```go
// RIGHT (a): no typed nil variable at all — return the untyped nil literal
// directly on the no-error path. Use this whenever the function builds its
// own concrete error value inline.
func classify(input string) error {
    if input == "" {
        return &ValidationError{Field: "input", Message: "required"}
    }
    return nil // untyped nil literal — the error interface itself is nil
}
```

```go
// RIGHT (b): when a helper already hands back a concrete *ValidationError,
// convert explicitly at the boundary — never pass the typed pointer through
// as-is via a bare `return verr`. Use this whenever the error value originates
// from a call to another function that itself returns a concrete pointer type.
func classify(input string) error {
    verr := runValidation(input) // returns *ValidationError, nil on success
    if verr != nil {
        return verr
    }
    return nil // explicit: the boundary returns the bare nil literal, not verr
}

func runValidation(input string) *ValidationError {
    if input == "" {
        return &ValidationError{Field: "input", Message: "required"}
    }
    return nil
}
```

Both fixes were also verified: `classifyRightA("ok")` and `classifyRightB("ok")` both produce `err == nil` as `true`, and both correctly produce a populated, non-nil error on the invalid-input path (`err == nil` is `false`, with the expected message).

## The rule

Never declare a nil-valued, concrete-typed error variable and return it directly through an `error`-typed result. Return the bare `nil` literal for the no-error path — whether directly (a), or via an explicit conditional when converting a helper's typed-pointer result (b).
