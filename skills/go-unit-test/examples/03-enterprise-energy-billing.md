# Enterprise: Multi-tenant Energy Billing

Self-contained input and output. All code compiled and run on Go 1.27.4; gate output is copied from the runs (gobco 1.3.4). Module `example.test/voltbill`.

## Input

> "Unit test billing: meter lines from suppliers, per-tenant rates priced concurrently, a time limit on the rate service, and an export file name. The cloud build has an extra file behind the `cloudexport` tag. Give me the coverage figure."

## Output

| Package | Kind | Cases derived from |
|---|---|---|
| `reading` | Parser of untrusted input | Classes and boundaries, plus fuzzing |
| `tariff` | Domain logic, concurrent | Two tenants and an unknown one; empty and large inputs; `-race` |
| `fetch` | Time limit | Either side of the limit, with a fake clock. Parent cancellation not tried |
| `export` | Trivial | Empty and named tenant |

```go
// file: internal/reading/reading.go
package reading

import (
	"errors"
	"fmt"
	"strconv"
	"strings"
)

var ErrMalformed = errors.New("reading: malformed line")

type Reading struct {
	Meter string
	KWh   int
}

func (r Reading) String() string { return r.Meter + "," + strconv.Itoa(r.KWh) }

// Parse reads "<13 digit meter>,<whole kWh, 0 or more>".
func Parse(line string) (Reading, error) {
	meter, amount, found := strings.Cut(line, ",")
	if !found || len(meter) != 13 || strings.Trim(meter, "0123456789") != "" {
		return Reading{}, fmt.Errorf("%w: meter", ErrMalformed)
	}
	kwh, err := strconv.Atoi(amount)
	if err != nil || kwh < 0 {
		return Reading{}, fmt.Errorf("%w: amount", ErrMalformed)
	}
	return Reading{Meter: meter, KWh: kwh}, nil
}
```

```go
// file: internal/reading/reading_test.go
package reading

import (
	"errors"
	"testing"
)

func TestParse(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name    string
		line    string
		want    Reading
		wantErr error
	}{
		{"zero is valid", "1200012345678,0", Reading{"1200012345678", 0}, nil},
		{"no comma", "1200012345678", Reading{}, ErrMalformed},
		{"meter one digit short", "120001234567,5", Reading{}, ErrMalformed},
		{"meter one digit long", "12000123456789,5", Reading{}, ErrMalformed},
		{"meter with a letter", "120001234567x,5", Reading{}, ErrMalformed},
		{"negative amount", "1200012345678,-1", Reading{}, ErrMalformed},
		{"amount not a number", "1200012345678,five", Reading{}, ErrMalformed},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			got, err := Parse(tt.line)
			if !errors.Is(err, tt.wantErr) || got != tt.want {
				t.Errorf("Parse(%q) = %+v, %v, want %+v, %v", tt.line, got, err, tt.want, tt.wantErr)
			}
		})
	}
}
```

```go
// file: internal/reading/reading_fuzz_test.go
package reading

import (
	"errors"
	"testing"
)

func FuzzParse(f *testing.F) {
	f.Add("1200012345678,42")
	f.Add("")
	f.Add("1200012345678,-1")
	f.Fuzz(func(t *testing.T, line string) {
		got, err := Parse(line)
		if err != nil {
			if !errors.Is(err, ErrMalformed) || got != (Reading{}) {
				t.Errorf("Parse(%q) = %+v, %v, want the zero value and ErrMalformed", line, got, err)
			}
			return
		}
		if got.KWh < 0 || len(got.Meter) != 13 {
			t.Errorf("Parse(%q) accepted %+v", line, got)
		}
		again, err := Parse(got.String())
		if err != nil || again != got {
			t.Errorf("Parse(%q) = %+v, %v, want %+v", got.String(), again, err, got)
		}
	})
}
```

CI step (the command ran for 20 seconds without a failure; the duration is for the test strategy to set):

```bash
go test -run='^$' -fuzz='^FuzzParse$' -fuzztime=20s ./internal/reading
```

```go
// file: internal/tariff/book.go
package tariff

import (
	"errors"
	"sync"
)

var ErrUnknownTenant = errors.New("tariff: no rate for this tenant")

// Book holds pence per kWh for each tenant. It is read-only after NewBook.
type Book struct{ rates map[string]int }

func NewBook(rates map[string]int) Book {
	own := make(map[string]int, len(rates))
	for tenant, rate := range rates {
		own[tenant] = rate
	}
	return Book{rates: own}
}

// Total prices every amount at the tenant's rate, one goroutine per amount.
func (b Book) Total(tenant string, kwh []int) (int, error) {
	rate, ok := b.rates[tenant]
	if !ok {
		return 0, ErrUnknownTenant
	}
	var (
		wg    sync.WaitGroup
		mu    sync.Mutex
		total int
	)
	for _, amount := range kwh {
		wg.Go(func() {
			mu.Lock()
			defer mu.Unlock()
			total += amount * rate
		})
	}
	wg.Wait()
	return total, nil
}
```

```go
// file: internal/tariff/book_test.go
package tariff

import (
	"errors"
	"testing"
)

func TestBook_Total(t *testing.T) {
	t.Parallel()
	rates := map[string]int{"north": 20, "south": 30}
	book := NewBook(rates)
	rates["north"] = 999 // the book keeps its own copy

	many := make([]int, 1000)
	for i := range many {
		many[i] = 1
	}
	tests := []struct {
		name    string
		tenant  string
		kwh     []int
		want    int
		wantErr error
	}{
		{"north uses the north rate", "north", []int{1, 2}, 60, nil},
		{"south uses the south rate", "south", []int{1, 2}, 90, nil},
		{"no amounts", "north", nil, 0, nil},
		{"many amounts at once", "north", many, 20000, nil},
		{"unknown tenant gets nobody's rate", "east", []int{1}, 0, ErrUnknownTenant},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			got, err := book.Total(tt.tenant, tt.kwh)
			if !errors.Is(err, tt.wantErr) || got != tt.want {
				t.Errorf("Total(%q, %d amounts) = %d, %v, want %d, %v",
					tt.tenant, len(tt.kwh), got, err, tt.want, tt.wantErr)
			}
		})
	}
}
```

```go
// file: internal/fetch/within.go
package fetch

import (
	"context"
	"time"
)

// Within returns get's answer, or the context's error after limit.
func Within(ctx context.Context, limit time.Duration, get func(context.Context) (int, error)) (int, error) {
	ctx, cancel := context.WithTimeout(ctx, limit)
	defer cancel()
	type answer struct {
		value int
		err   error
	}
	done := make(chan answer, 1) // buffered: a late get never blocks
	go func() {
		v, err := get(ctx)
		done <- answer{v, err}
	}()
	select {
	case a := <-done:
		return a.value, a.err
	case <-ctx.Done():
		return 0, ctx.Err()
	}
}
```

```go
// file: internal/fetch/within_test.go
package fetch

import (
	"context"
	"errors"
	"testing"
	"testing/synctest"
	"time"
)

// answersAfter ignores cancellation, as a slow dependency would.
func answersAfter(d time.Duration) func(context.Context) (int, error) {
	return func(context.Context) (int, error) {
		<-time.After(d)
		return 7, nil
	}
}

func TestWithin(t *testing.T) {
	t.Parallel()
	const limit = 5 * time.Second
	tests := []struct {
		name    string
		delay   time.Duration
		want    int
		wantErr error
	}{
		{"answer just inside the limit", limit - time.Nanosecond, 7, nil},
		{"answer just after the limit", limit + time.Nanosecond, 0, context.DeadlineExceeded},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			synctest.Test(t, func(t *testing.T) { // fake clock: no real waiting
				got, err := Within(t.Context(), limit, answersAfter(tt.delay))
				if !errors.Is(err, tt.wantErr) || got != tt.want {
					t.Errorf("Within = %d, %v, want %d, %v", got, err, tt.want, tt.wantErr)
				}
				synctest.Sleep(tt.delay) // let get's goroutine finish: a leftover one panics
			})
		})
	}
}
```

Without the final `synctest.Sleep`, the slow case panicked: `deadlock: main bubble goroutine has exited but blocked goroutines remain`.

```go
// file: internal/export/name.go
package export

// Name is the file name of one tenant's export.
func Name(tenant string) string {
	if tenant == "" {
		return "export.csv"
	}
	return tenant + ".csv"
}
```

```go
// file: internal/export/name_test.go
package export

import "testing"

func TestName(t *testing.T) {
	t.Parallel()
	for tenant, want := range map[string]string{"": "export.csv", "north": "north.csv"} {
		if got := Name(tenant); got != want {
			t.Errorf("Name(%q) = %q, want %q", tenant, got, want)
		}
	}
}
```

```go
// file: internal/export/bucket.go
//go:build cloudexport

package export

// Key is the object key used by the cloud build.
func Key(tenant string) string {
	if tenant == "" {
		return "shared/export.csv"
	}
	return "tenants/" + tenant + "/export.csv"
}
```

```go
// file: internal/export/bucket_test.go
//go:build cloudexport

package export

import "testing"

func TestKey(t *testing.T) {
	t.Parallel()
	for tenant, want := range map[string]string{"": "shared/export.csv", "north": "tenants/north/export.csv"} {
		if got := Key(tenant); got != want {
			t.Errorf("Key(%q) = %q, want %q", tenant, got, want)
		}
	}
}
```

## Gate output

Without the tag, both gates refuse a result because `bucket.go` is outside the build. With `--tags cloudexport`:

```text
Statement coverage: 39/39 statements, 0 block(s) not run
PASS: every measured statement block ran (statement blocks only; branches are a separate gate)
Branch coverage (gobco 1.3.4): 8/8 outcomes
NO RESULT internal/export/bucket.go: has conditions but gobco measured none (a custom build tag does this)
NO RESULT: this blocks the build and there is nothing to waive. Change the code so it can be measured, or list an exception for the product owner's approval. Never report statement coverage only.
```

## What the answer says

- "The build is blocked. There is no branch figure for this module. Statement blocks are 39/39. 8/8 leaves out `bucket.go`, so it is not the result and is not reported as one." No waiver is possible.
- Remedies: move the logic of `bucket.go` into an untagged file so both gates measure it (first choice, a code change); or list the file as an exception with its reason, pending until the product owner approves, with the build blocked meanwhile. An approved exception is printed as not measured, never as passing.
- `fetch` has no condition gobco counts: its `select` is seen only by the statement gate. Also unmeasured: `range` and zero-iteration loops; booleans outside conditions; functions without conditions.
- `tariff` proves one tenant cannot be priced at another's rate in memory only. Isolation in storage is an integration test, keyed by the product's tenancy design.
- `-race` checks only the interleavings that happened. The gate run excluded nothing.
