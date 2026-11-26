# Go Fixture Skeletons

Copy only what the test needs into the paths shown; replace `<module>`, `Booking` and table names with the product's. Unverified: these have not been compiled. Shared helpers live under `internal/test/`.

`testPool` is the shared `*pgxpool.Pool` that `go-integration-test`'s `TestMain` opens against the container it started. Never build it from `DATABASE_URL`.

## internal/test/db/tx.go (default: roll back each test)

```go
package db

import (
	"context"
	"errors"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// WithTx returns a transaction that is always rolled back.
func WithTx(t *testing.T, pool *pgxpool.Pool) pgx.Tx {
	t.Helper()
	tx, err := pool.Begin(context.Background())
	if err != nil {
		t.Fatalf("begin: %v", err)
	}
	t.Cleanup(func() {
		// context.Background: t.Context() is already cancelled during cleanup.
		err := tx.Rollback(context.Background())
		if err != nil && !errors.Is(err, pgx.ErrTxClosed) {
			t.Errorf("rollback: %v", err)
		}
	})
	return tx
}
```

## internal/test/db/scope.go (only when a real commit is needed)

```go
package db

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

var testNamespace = uuid.MustParse("6f9c1b4e-0000-4000-8000-000000000001")

// ID is unique per test and label, and identical on every run.
func ID(t *testing.T, label string) uuid.UUID {
	return uuid.NewSHA1(testNamespace, []byte(t.Name()+"/"+label))
}

// Scoped registers removal of every row owned by key. Call it BEFORE seeding.
// deletes: one statement per owned table, children first, each filtered by $1.
func Scoped(t *testing.T, pool *pgxpool.Pool, key uuid.UUID, deletes ...string) {
	t.Helper()
	if len(deletes) == 0 {
		t.Fatal("Scoped: list every table this test writes")
	}
	t.Cleanup(func() {
		for _, q := range deletes {
			if _, err := pool.Exec(context.Background(), q, key); err != nil {
				t.Errorf("cleanup %q: %v", q, err)
			}
		}
	})
}
```

Usage, with the reason stated:

```go
// Real commit needed: the subject is that the booking and its outbox row commit together.
bookingID := db.ID(t, "booking")
db.Scoped(t, testPool, bookingID,
	`DELETE FROM outbox WHERE aggregate_id = $1`,
	`DELETE FROM bookings WHERE id = $1`,
)
```

## internal/test/builders/booking.go

```go
package builders

import (
	"testing"
	"time"

	"github.com/google/uuid"

	"<module>/internal/domain"
)

var FixedNow = time.Date(2026, 1, 15, 12, 0, 0, 0, time.UTC)

type BookingBuilder struct {
	id    uuid.UUID
	seats int
}

func NewBooking() *BookingBuilder {
	return &BookingBuilder{
		id:    uuid.MustParse("00000000-0000-4000-8000-000000000101"),
		seats: 1,
	}
}

func (b *BookingBuilder) WithID(id uuid.UUID) *BookingBuilder { b.id = id; return b }
func (b *BookingBuilder) WithSeats(n int) *BookingBuilder    { b.seats = n; return b }

// Build uses the domain's own constructor so the object is valid.
func (b *BookingBuilder) Build(t *testing.T) *domain.Booking {
	t.Helper()
	booking, err := domain.NewBooking(b.id, b.seats, FixedNow)
	if err != nil {
		t.Fatalf("build booking: %v", err)
	}
	return booking
}
```

## internal/test/mothers/booking.go

```go
package mothers

import (
	"testing"

	"<module>/internal/domain"
	"<module>/internal/test/builders"
)

// CancelledBooking reaches the state through the domain's own behaviour.
func CancelledBooking(t *testing.T) *domain.Booking {
	t.Helper()
	b := builders.NewBooking().Build(t)
	if err := b.Cancel(builders.FixedNow); err != nil {
		t.Fatalf("cancel booking: %v", err)
	}
	return b
}
```

## internal/test/golden/golden.go

```go
package golden

import (
	"bytes"
	"flag"
	"os"
	"path/filepath"
	"testing"
)

var update = flag.Bool("update", false, "rewrite golden files; read the diff before committing")

// Assert compares got with testdata/<name>.golden in the test's package.
func Assert(t *testing.T, name string, got []byte) {
	t.Helper()
	path := filepath.Join("testdata", name+".golden")
	if *update {
		if err := os.MkdirAll("testdata", 0o755); err != nil {
			t.Fatalf("mkdir testdata: %v", err)
		}
		if err := os.WriteFile(path, got, 0o644); err != nil {
			t.Fatalf("write %s: %v", path, err)
		}
		t.Logf("rewrote %s", path)
		return
	}
	want, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read golden file %s: %v", path, err)
	}
	if !bytes.Equal(want, got) {
		t.Errorf("%s differs\n--- want\n%s\n--- got\n%s", path, want, got)
	}
}
```
