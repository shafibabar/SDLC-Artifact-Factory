# Go Unit Test Skeletons

Copy only what is needed; replace the package, type and rule names. Each block compiled and passed on Go 1.27.4 with the small stand-in types in the first block. Name each file `<implementation>_test.go` or `<implementation>_<variant>_test.go` (for example `_fuzz_test.go`), the shapes `scripts/tdd-gate.sh` accepts.

## Stand-in code under test

```go
// file: ticket/ticket.go
package ticket

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"
)

var (
	ErrClosed  = errors.New("ticket: already closed")
	ErrBadCode = errors.New("ticket: bad code")
)

type Ticket struct{ closedAt time.Time }

func (t *Ticket) ClosedAt() time.Time { return t.closedAt }

func (t *Ticket) Close(now time.Time) error {
	if !t.closedAt.IsZero() {
		return ErrClosed
	}
	t.closedAt = now
	return nil
}

// ParseCode reads "T-<number>".
func ParseCode(s string) (int, error) {
	digits, ok := strings.CutPrefix(s, "T-")
	if !ok {
		return 0, ErrBadCode
	}
	n, err := strconv.Atoi(digits)
	if err != nil {
		return 0, ErrBadCode
	}
	return n, nil
}

func CodeHandler(w http.ResponseWriter, r *http.Request) {
	n, err := ParseCode(r.URL.Query().Get("code"))
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]int{"number": n})
}

// Remind calls send after delay unless ctx ends first.
func Remind(ctx context.Context, delay time.Duration, send func()) {
	select {
	case <-time.After(delay):
		send()
	case <-ctx.Done():
	}
}
```

## Table-driven test with a rejected path

Assert the error by identity, and that a refused call changed nothing.

```go
// file: ticket/ticket_test.go
package ticket

import (
	"errors"
	"testing"
	"time"
)

func TestTicket_Close(t *testing.T) {
	t.Parallel()
	first := time.Date(2026, 1, 15, 12, 0, 0, 0, time.UTC)
	second := first.Add(time.Hour)
	tests := []struct {
		name         string
		closedBefore bool
		wantErr      error
		wantClosedAt time.Time
	}{
		{name: "open ticket closes", wantClosedAt: second},
		{name: "closed ticket is refused and unchanged", closedBefore: true, wantErr: ErrClosed, wantClosedAt: first},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			ticket := &Ticket{}
			if tt.closedBefore {
				if err := ticket.Close(first); err != nil {
					t.Fatalf("arrange: Close(%v) = %v", first, err)
				}
			}
			if err := ticket.Close(second); !errors.Is(err, tt.wantErr) {
				t.Fatalf("Close(%v) = %v, want %v", second, err, tt.wantErr)
			}
			if got := ticket.ClosedAt(); !got.Equal(tt.wantClosedAt) {
				t.Errorf("ClosedAt() = %v, want %v", got, tt.wantClosedAt)
			}
		})
	}
}
```

Arrange and assert through exported behaviour, never by setting or reading a field. For a typed error use `errors.As` and assert its fields.

## HTTP handler with httptest

No socket is opened.

```go
// file: ticket/ticket_internal_test.go
package ticket

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCodeHandler(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name       string
		target     string
		wantStatus int
		wantBody   string
	}{
		{"valid code", "/?code=T-7", http.StatusOK, "{\"number\":7}\n"},
		{"missing prefix", "/?code=7", http.StatusBadRequest, ""},
		{"not a number", "/?code=T-x", http.StatusBadRequest, ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			rec := httptest.NewRecorder()
			CodeHandler(rec, httptest.NewRequest(http.MethodGet, tt.target, nil))
			if rec.Code != tt.wantStatus || rec.Body.String() != tt.wantBody {
				t.Errorf("GET %s = %d %q, want %d %q",
					tt.target, rec.Code, rec.Body.String(), tt.wantStatus, tt.wantBody)
			}
		})
	}
}
```

## Fuzz test

State properties that hold for every input.

```go
// file: ticket/ticket_fuzz_test.go
package ticket

import (
	"errors"
	"testing"
)

func FuzzParseCode(f *testing.F) {
	f.Add("T-1")
	f.Add("")
	f.Fuzz(func(t *testing.T, s string) {
		n, err := ParseCode(s)
		if err != nil && (!errors.Is(err, ErrBadCode) || n != 0) {
			t.Errorf("ParseCode(%q) = %d, %v, want 0 and ErrBadCode", s, n, err)
		}
	})
}
```

## Timers with testing/synctest (Go 1.25 and later; synctest.Sleep from 1.27)

```go
// file: ticket/ticket_race_test.go
package ticket

import (
	"context"
	"testing"
	"testing/synctest"
	"time"
)

func TestRemind(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name   string
		cancel bool
		want   int
	}{
		{"sends once after the delay", false, 1},
		{"cancelled sends nothing", true, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			synctest.Test(t, func(t *testing.T) {
				ctx, cancel := context.WithCancel(t.Context())
				defer cancel()
				sent := 0
				go Remind(ctx, time.Hour, func() { sent++ })
				if tt.cancel {
					cancel()
				}
				synctest.Sleep(2 * time.Hour) // fake time; returns once the goroutine has settled
				if sent != tt.want {
					t.Errorf("sends = %d, want %d", sent, tt.want)
				}
			})
		})
	}
}
```
