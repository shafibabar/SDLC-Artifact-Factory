# Lean: Rowing Boat Hire (the lab that was run)

Self-contained. Read for the whole flow on a small product: the first release run, each kind of mutant, the record, a waiver, and the scheduled run. Every file below was extracted from this page into a fresh module and run with Go 1.27.4 and Gremlins v0.6.0 (macOS arm64, 2026-11-28); the outputs are copied from those runs, trimmed only where marked.

## Input

A lean product: one Go module for a lake's rowing-boat hire desk. Lean changes the number of packages, never the rule: the release run covers all product code and every mutant is killed or recorded.

### `go.mod`

```text
module example.com/boathire

go 1.27
```

### `internal/domain/listing/listing.go`

```go
// Package listing pages the boat list shown at the desk.
package listing

// IsLastPage reports whether page (0-indexed) is the final page of a
// collection of totalItems items at pageSize items per page.
func IsLastPage(page, pageSize, totalItems int) bool {
	return (page+1)*pageSize >= totalItems
}

// Shard spreads booking ids over seven partitions.
func Shard(id int) int {
	id %= 7
	return id
}
```

### `internal/domain/listing/listing_test.go`

```go
package listing

import "testing"

func TestIsLastPage(t *testing.T) {
	tests := []struct {
		name                       string
		page, pageSize, totalItems int
		want                       bool
	}{
		{"early page is not last", 0, 10, 100, false},
		{"page well past the end is last", 15, 10, 100, true},
		{"page exactly at the boundary is last", 9, 10, 100, true}, // (9+1)*10 == 100
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsLastPage(tt.page, tt.pageSize, tt.totalItems); got != tt.want {
				t.Errorf("IsLastPage(%d,%d,%d) = %v, want %v", tt.page, tt.pageSize, tt.totalItems, got, tt.want)
			}
		})
	}
}

func TestShard(t *testing.T) {
	if got := Shard(23); got != 2 {
		t.Fatalf("Shard(23) = %d, want 2", got)
	}
}
```

### `internal/domain/seats/seats.go`

```go
// Package seats limits a party to the boat's seats.
package seats

// Seats returns requested, limited to capacity.
func Seats(requested, capacity int) int {
	if requested > capacity {
		return capacity
	}
	return requested
}
```

### `internal/domain/seats/seats_test.go`

```go
package seats

import "testing"

func TestSeats(t *testing.T) {
	tests := []struct {
		name                string
		requested, capacity int
		want                int
	}{
		{"under capacity", 3, 4, 3},
		{"at capacity", 4, 4, 4},
		{"over capacity", 6, 4, 4},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Seats(tt.requested, tt.capacity); got != tt.want {
				t.Errorf("Seats(%d,%d) = %d, want %d", tt.requested, tt.capacity, got, tt.want)
			}
		})
	}
}
```

### `internal/domain/receipt/receipt.go`

```go
// Package receipt prices and labels a hire receipt.
package receipt

import "strconv"

// Total sums the hire fees, in pence.
func Total(fees []int) int {
	sum := 0
	for i := 0; i < len(fees); i++ {
		sum += fees[i]
	}
	return sum
}

// Label names a hire slot on the receipt header.
func Label(lake string, slot int) string {
	return lake + "-" + strconv.Itoa(slot)
}

// Repeat returns the fee for a book of count hires.
func Repeat(fee, count int) int {
	total := 0
	for i := 0; i < count; i++ {
		total += fee
	}
	return total
}
```

### `internal/domain/receipt/receipt_test.go`

```go
package receipt

import (
	"testing"

	"example.com/boathire/internal/test/fees"
)

func TestTotal(t *testing.T) {
	if got := Total([]int{1200, 800, 450}); got != 2450 {
		t.Fatalf("Total = %d, want 2450", got)
	}
	if got := Total(nil); got != 0 {
		t.Fatalf("Total(nil) = %d, want 0", got)
	}
	if got := Total(fees.Flat(3)); got != 1500 {
		t.Fatalf("Total(three flat fees) = %d, want 1500", got)
	}
}

func TestLabel(t *testing.T) {
	if got := Label("MERE", 7); got != "MERE-7" {
		t.Fatalf("Label = %q, want MERE-7", got)
	}
}

func TestRepeat(t *testing.T) {
	if got := Repeat(250, 4); got != 1000 {
		t.Fatalf("Repeat = %d, want 1000", got)
	}
}
```

### `internal/application/quote/quote.go`

```go
// Package quote prices a hire request.
package quote

// Price returns the fee for adults and children, children at half fee.
func Price(adults, children, fee int) int {
	return adults*fee + children*fee/2
}
```

### `internal/application/quote/quote_test.go`

```go
package quote

import "testing"

func TestPrice(t *testing.T) {
	tests := []struct {
		name                  string
		adults, children, fee int
		want                  int
	}{
		{"adults only", 2, 0, 1000, 2000},
		{"children at half fee", 0, 2, 1000, 1000},
		{"mixed party", 2, 1, 1000, 2500},
		{"odd fee rounds a child down", 0, 1, 1001, 500},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Price(tt.adults, tt.children, tt.fee); got != tt.want {
				t.Errorf("Price(%d,%d,%d) = %d, want %d", tt.adults, tt.children, tt.fee, got, tt.want)
			}
		})
	}
}
```

### `internal/gen/models.go`

```go
// Code generated by sqlc. DO NOT EDIT.

package gen

// Seats is a generated row helper.
func Seats(a, b int) int {
	return a + b
}
```

### `internal/test/fees/fees.go`

```go
// Package fees builds hire fees for tests.
package fees

// Flat returns n fees of 500 pence.
func Flat(n int) []int {
	out := make([]int, 0, n)
	for i := 0; i < n; i++ {
		out = append(out, 500)
	}
	return out
}
```

Plus, unchanged: `.gremlins.yaml` (`../templates/gremlins-config.md`), the `Makefile` lines (`../templates/make-targets.md`), both workflows (`../templates/workflows.md`), `mutation/exclusions.txt` with its header only, `scripts/run-go-mutation.sh` and `scripts/check-go-mutation.sh`, and `.gitignore` holding `mutation-out/`.

## Output

### Run 1: the first release candidate (`make mutation`, the boundary row not yet written)

```text
Planted: 24
Killed by a test: 17
Not caught: 7
  internal/domain/listing/listing.go:7:14 ARITHMETIC_BASE: LIVED; write the test that kills it; ...
  internal/domain/listing/listing.go:7:27 CONDITIONALS_BOUNDARY: LIVED; write the test that kills it; ...
  internal/domain/listing/listing.go:12:5 INVERT_ASSIGNMENTS: LIVED; ...
  internal/domain/receipt/receipt.go:17:14 ARITHMETIC_BASE: KILLED, does not compile (... operator - not defined on lake (variable of type string)); ...
  internal/domain/receipt/receipt.go:17:20 ARITHMETIC_BASE: KILLED, does not compile (...); ...
  internal/domain/receipt/receipt.go:23:26 INCREMENT_DECREMENT: TIMED OUT, timed out again on recheck; ...
  internal/domain/seats/seats.go:6:15 CONDITIONALS_BOUNDARY: LIVED; ...
Generated code (left out): internal/gen/models.go
Result: 17/24 caught (killed 17 + recorded 0)
90% or below: no waiver is possible.
Verdict: FAIL
make: *** [mutation] Error 1
```

Gremlins' own summary for the same run said `Killed: 19, Lived: 4` and `Test efficacy: 82.61%`: it counted the two string mutants that cannot compile as killed and left the timed-out one out. Neither number is used.

What each survivor needed (the triage in `../references/triage-method.md`):

| Mutant | Finding | Action |
|---|---|---|
| `listing.go:7:27` `>=` to `>`, and `7:14` `page+1` to `page-1` | Real gaps: no row puts `(page+1)*pageSize` exactly on `totalItems` | Add `{"page exactly at the boundary is last", 9, 10, 100, true}`: both killed |
| `seats.go:6:15` `>` to `>=` | Equivalent: at `requested == capacity` both return the same number | Record |
| `receipt.go:17:14` and `17:20` `+` to `-` on strings | Not viable: the compiler rejects them; Gremlins called them KILLED | Record |
| `receipt.go:23:26` `i++` to `i--` | Never ends; the recheck timed out again | Record |
| `listing.go:12:5` `%=` under INVERT_ASSIGNMENTS | Gremlins maps `%=` to `%=`: nothing changed | Record |

### Run 2 and 3: the boundary row, then three records

With the row added: `Result: 19/24`, FAIL. With three record lines (the two strings and the seat clamp):

```text
Recorded: 3 (equivalent 1, timeout 0, not-viable 2)
Not caught: 2
  internal/domain/listing/listing.go:12:5 INVERT_ASSIGNMENTS: LIVED; ...
  internal/domain/receipt/receipt.go:23:26 INCREMENT_DECREMENT: TIMED OUT, timed out again on recheck; ...
Result: 22/24 caught (killed 19 + recorded 3)
More than 90%: the product owner may waive the remaining 2 after reviewing them; add the row | mutation | go | source eefd19a06f0146f0 | 22/24 | <comments> | <YYYY-MM-DD> | ...
Verdict: WAIVER-NEEDED
make: *** [mutation] Error 3
```

### Run 4: the product owner's waiver

The product owner reviewed both and their row went into `artifacts/boathire/quality/test-reports/go-mutation-report.md` (filled from `../templates/mutation-report.md`; it passed the plugin's artifact frontmatter check):

```text
| mutation | go | source eefd19a06f0146f0 (commit c677f00adde6) | 22/24 | Reviewed both: the no-op %= and the endless loop cannot be killed; record them before the next release | 2026-11-28 |
```

That commit changed only the report, so the source id stayed `eefd19a06f0146f0` and the re-run matched the row:

```text
Test support under internal/test/ (approved class, left out): internal/test/fees/fees.go
Result: 22/24 caught (killed 19 + recorded 3)
Verdict: PASS (waived by the product owner on 2026-11-28)
```

### Run 5: every mutant killed or recorded

### `mutation/mutant-record.txt`

```text
# Mutant record (go-mutation-test): one line per planted mutant that no test can kill.
# <file>:<line>:<col> | <TYPE> | equivalent|timeout|not-viable | <fingerprint> | <reason> | <who> <YYYY-MM-DD>
# Copy the line check-go-mutation.sh prints for the mutant, check it, then write the reason.
internal/domain/receipt/receipt.go:17:14 | ARITHMETIC_BASE | not-viable | 509aefa3ac64 | lake - "-": Go has no minus on strings, so the compiler rejects it before any test runs | test-strategist 2026-11-28
internal/domain/receipt/receipt.go:17:20 | ARITHMETIC_BASE | not-viable | 509aefa3ac64 | (lake + "-") - strconv.Itoa(slot): no minus on strings; rejected by the compiler | test-strategist 2026-11-28
internal/domain/seats/seats.go:6:15 | CONDITIONALS_BOUNDARY | equivalent | dfaa2de1dc31 | at requested == capacity both versions return the same number, so > and >= agree for every input | test-strategist 2026-11-28
internal/domain/listing/listing.go:12:5 | INVERT_ASSIGNMENTS | equivalent | 7094cbc8ffd5 | Gremlins maps %= to %= for this type, so the planted code is identical to the original | test-strategist 2026-11-28
internal/domain/receipt/receipt.go:23:26 | INCREMENT_DECREMENT | timeout | a93166abe748 | i-- never reaches count, so the loop never ends; the recheck stopped it after 120 s | test-strategist 2026-11-28
```

```text
Planted: 24
Killed by a test: 19
Recorded: 5 (equivalent 2, timeout 1, not-viable 2)
Not caught: 0
Result: 24/24 caught (killed 19 + recorded 5)
Verdict: PASS
```

Tagged `v1.0.0`. Gremlins printed `Test efficacy: 91.30%` for this same run.

### Run 6: scheduled, after a change (`make mutation-changed`)

A later commit added `Deposit(party int) int` (2000 when `party > 4`) to `quote.go`, tested with parties of 6 and 2. The monthly run covered only the changed lines:

```text
Report only: blocks nothing. Changed code since v1.0.0; 25 mutants outside it were not planted.
Planted: 2
Killed by a test: 1
Not caught: 1
  internal/application/quote/quote.go:11:11 CONDITIONALS_BOUNDARY: LIVED; write the test that kills it; ...
Result: 1/2 caught (killed 1 + recorded 0)
Verdict: FAIL
```

`make` exited 0: nothing is blocked. The finding is a real gap (no test for a party of exactly 4), and the next release run will fail on it unless the row is added.

## What this shows

- Gremlins' percentages were 82.61% and 91.30% while the D048 result was 17/24 and 24/24; only per-mutant statuses, rechecked, give the verdict.
- An equivalent, a timed-out and a non-compiling mutant each counted only once recorded, one line each.
- The waiver applied above 90% only after the product owner's row named this run; at 17/24 and 19/24 no waiver was possible.
- Lean planted 24 mutants and ran the same gate as any size.
