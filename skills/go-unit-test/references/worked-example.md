# Worked Example: A Complete Table-Driven Test

A full illustration of the Table-Driven Test pattern (`go-unit-test`'s "Table-Driven Tests" section): one test function, a table of named cases, a loop, each case run as its own parallel subtest.

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

**Running a single case:**

```bash
go test -run 'TestSensitivityLevel_IsHigherThan/equal_is_not_higher'
```

Spaces in subtest names become underscores in the `-run` regex target.
