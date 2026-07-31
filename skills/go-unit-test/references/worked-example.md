# Worked Example: A Complete Table-Driven Test, and the Parallel-Safety Pitfall

Illustrates two things from `go-unit-test`'s "Table-Driven Test: Struct Shape and Parallel Safety" section: (1) a complete, correctly-shaped table-driven test, and (2) the specific pitfall of mixing `defer` with parallel subtests.

---

## 1. The Complete Table-Driven Test

```go
func TestSensitivityLevel_IsHigherThan(t *testing.T) {
    t.Parallel()
    tests := []struct {
        name string
        a, b domain.SensitivityLevel
        want bool
    }{
        {"restricted over public", domain.SensitivityRestricted, domain.SensitivityPublic, true},
        {"public not over restricted", domain.SensitivityPublic, domain.SensitivityRestricted, false},
        {"equal is not higher", domain.SensitivityConfidential, domain.SensitivityConfidential, false},
        {"unclassified is lowest", domain.SensitivityUnclassified, domain.SensitivityPublic, false},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            if got := tt.a.IsHigherThan(tt.b); got != tt.want {
                t.Errorf("IsHigherThan(%q,%q) = %v, want %v", tt.a, tt.b, got, tt.want)
            }
        })
    }
}
```

**What to notice:**

- **The table** (`tests := []struct{...}{...}`) is the whole spec — every case's name, inputs, and expectation is a single scannable line. Adding a case is a one-line diff.
- **`t.Run(tt.name, ...)`** turns each row into its own named subtest, so a failure names the exact case (`TestSensitivityLevel_IsHigherThan/equal_is_not_higher`), not just the parent function.
- **`t.Parallel()`** at both the parent and each subtest lets all cases run concurrently — cheap because each case is fully isolated (no shared state between rows).
- **No `tt := tt` re-declaration.** Since Go 1.22, `for` loop variables are per-iteration; capturing `tt` into a new variable before the closure is dead weight from the pre-1.22 idiom and must not appear in new code.
- **Case names read as specifications** — `"equal is not higher"` states a behaviour, not a mechanism. A name like `TestClassify2` gives a debugger nothing to go on.
- **The failure message** (`t.Errorf("IsHigherThan(%q,%q) = %v, want %v", ...)`) names the operation, both inputs, the got value, and the want value — this is the assertion-style standard's minimum bar (`references/assertion-and-fixture-standard.md`), satisfiable with plain stdlib and no library.

**Running a single case:**

```bash
go test -run 'TestSensitivityLevel_IsHigherThan/equal_is_not_higher'
```

Spaces in subtest names become underscores in the `-run` regex target.

---

## 2. The Parallel-Safety Pitfall: `defer` vs. `t.Cleanup`

When a parent test spawns parallel subtests, the parent function body finishes executing and *returns* before those subtests actually run — Go parks them until the parent yields control back to the test runner. A `defer` registered in the parent therefore fires immediately when the parent returns, **before** any parallel subtest body has executed — tearing down shared fixtures the subtests still need.

```go
// WRONG: sharedDB is closed before any parallel subtest runs.
func TestRepo_Queries(t *testing.T) {
    sharedDB := setupInMemoryFixture(t)
    defer sharedDB.Close() // fires when TestRepo_Queries returns — the subtests haven't run yet

    for _, tt := range cases {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            row := sharedDB.Query(tt.id) // sharedDB may already be closed here
            // ...
        })
    }
}
```

```go
// RIGHT: t.Cleanup runs only after every subtest (parallel or not) has completed.
func TestRepo_Queries(t *testing.T) {
    sharedDB := setupInMemoryFixture(t)
    t.Cleanup(func() { sharedDB.Close() })

    for _, tt := range cases {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            row := sharedDB.Query(tt.id) // sharedDB is guaranteed open here
            // ...
        })
    }
}
```

The fix is mechanical: any teardown that must outlive the parent function's own return — which is every teardown shared by parallel subtests — is registered with `t.Cleanup`, never `defer`.

---

## 3. Unsafe `t.Parallel()`: Shared Package-Level State

`t.Parallel()` is unsafe the moment two subtests can observe or mutate the same state outside their own case:

```go
// WRONG: package-level var mutated by every subtest — a data race under -race,
// and an order-dependent result even without one.
var callCount int

func TestHandler_RecordsCall(t *testing.T) {
    for _, tt := range cases {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            callCount++ // shared mutable state across parallel subtests
            // ...
        })
    }
}
```

The fix is the same isolation rule every table-driven case already follows: each subtest owns its counters, doubles, and clocks locally (a fake constructed inside the closure, not hoisted to package scope). If a value genuinely must be shared read-only (a fixed corpus of valid inputs, for example), it must never be written to by any subtest.
