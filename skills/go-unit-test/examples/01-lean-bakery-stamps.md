# Lean: Bakery Stamp Card (one Go package)

Self-contained input and output. All code compiled and run on Go 1.27.4; gate output is copied from the runs (gobco 1.3.4). Module `example.test/crumbcard`.

## Input

> "Add stamps: one per full £5, double on Tuesdays, at most 10 per purchase. It's a tiny app, a couple of tests is plenty."

## Output

**Kind of code:** domain logic, so a table-driven unit test. **Derivation:** boundary value analysis on spend (-1, 0, 499, 500, 4999, 5000, 5500) and two day classes (Tuesday, not Tuesday). Not tried: very large spends; other days beyond the one representative.

```go
// file: internal/loyalty/stamps.go
package loyalty

import (
	"errors"
	"time"
)

const (
	PencePerStamp = 500
	MaxStamps     = 10
)

var ErrNegativeSpend = errors.New("loyalty: spend must not be negative")

// Stamps returns the stamps one purchase earns. Tuesdays count double.
func Stamps(spendPence int, at time.Time) (int, error) {
	if spendPence < 0 {
		return 0, ErrNegativeSpend
	}
	n := spendPence / PencePerStamp
	if at.Weekday() == time.Tuesday {
		n *= 2
	}
	if n > MaxStamps {
		n = MaxStamps
	}
	return n, nil
}
```

## First draft: two rows

A negative spend, and a large Tuesday spend. Result:

```text
Statement coverage: 8/8 statements, 0 block(s) not run
PASS: every measured statement block ran (statement blocks only; branches are a separate gate)
  internal/loyalty/stamps.go:21:5: 'at.Weekday() == time.Tuesday' never false
  internal/loyalty/stamps.go:24:5: 'n > MaxStamps' never false
Branch coverage (gobco 1.3.4): 4/6 outcomes
FAIL: the gate is 100% of measured branches. 90% or below: no waiver.
```

Every statement ran, yet no test showed an ordinary day or a purchase under the cap.

## The derived table

```go
// file: internal/loyalty/stamps_test.go
package loyalty

import (
	"errors"
	"testing"
	"time"
)

func TestStamps(t *testing.T) {
	t.Parallel()
	tuesday := time.Date(2026, 3, 3, 9, 0, 0, 0, time.UTC)
	wednesday := tuesday.AddDate(0, 0, 1)
	tests := []struct {
		name    string
		spend   int
		at      time.Time
		want    int
		wantErr error
	}{
		{name: "negative spend is rejected", spend: -1, at: wednesday, wantErr: ErrNegativeSpend},
		{name: "nothing spent earns nothing", spend: 0, at: wednesday, want: 0},
		{name: "one penny short earns nothing", spend: 499, at: wednesday, want: 0},
		{name: "exactly one stamp", spend: 500, at: wednesday, want: 1},
		{name: "one below the cap", spend: 4999, at: wednesday, want: 9},
		{name: "exactly the cap", spend: 5000, at: wednesday, want: 10},
		{name: "above the cap stays at the cap", spend: 5500, at: wednesday, want: 10},
		{name: "tuesday doubles", spend: 500, at: tuesday, want: 2},
		{name: "tuesday doubling is capped", spend: 3000, at: tuesday, want: 10},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			got, err := Stamps(tt.spend, tt.at)
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("Stamps(%d, %s) error = %v, want %v", tt.spend, tt.at.Weekday(), err, tt.wantErr)
			}
			if got != tt.want {
				t.Errorf("Stamps(%d, %s) = %d, want %d", tt.spend, tt.at.Weekday(), got, tt.want)
			}
		})
	}
}
```

```text
Statement coverage: 8/8 statements, 0 block(s) not run
Branch coverage (gobco 1.3.4): 6/6 outcomes
PASS: every measured outcome was seen
```

## What the answer says

- "A couple of tests" is replaced by the nine derived rows. Small size means one package and one table; the gates stay at 100%.
- The day is passed in as `at`; the test never reads the clock. Every subtest owns its data, so all run in parallel.
- Unmeasured: `select`; `range` and zero-iteration loops; booleans outside conditions; functions without conditions. This code has no `select` or loop.
- Nothing excluded; no waiver. Coverage shows the paths ran; the assertions are what check the values.
- Run: `go test`, both gates. The red step was not re-enacted for this write-up.
