# Seeding Straight Into the Database

Self-contained. Use only when a journey needs a state that the product offers **no public way** to create (a row written by a nightly job, a record imported long ago). Everything else is created through the public API (`./go-suite.md`, `seed_test.go`): a journey that writes tables by hand stops proving that the product can reach that state.

Run on Go 1.27.4 with pgx v5.13.0 against PostgreSQL 17.12 in the throwaway cluster.

Rules, each enforced by the code below:

- The address comes from the run marker (an endpoint named `db` in `E2E_ENDPOINTS`) and passes `env.RequireThrowaway`. No address is typed, read from the environment or taken from a flag. Seen: `db.staging.example:5432`, `10.0.0.7:5432`, `127.0.0.1:5432` and `localhost:5432` are all refused.
- The credentials are the test-only values of the end-to-end values file. No real credential exists in the suite.
- A plain `INSERT`, never an upsert (`ON CONFLICT ... DO UPDATE`, `MERGE`, `REPLACE`): if the row is already there the test fails instead of overwriting it. Seen: the second `INSERT` of the same row fails.
- Removal of exactly that row is registered at once and reports its own failure. No `TRUNCATE`, no unfiltered `DELETE` (`test-fixture-design`).
- This file is tagged `e2e && !smoke`: the smoke build cannot compile it.

The database is published on a loopback port only for this: add `db|<nodePort>` to `E2E_ENDPOINTS` and set the database chart's Service to that NodePort in its end-to-end values file.

### `tests/e2e/seed_db_test.go`

```go
//go:build e2e && !smoke

package e2e

import (
	"context"
	"database/sql"
	"fmt"
	"testing"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
)

// openThrowawayDB connects straight to the database of this run's cluster. Use
// it only for data the product offers no public way to create. The address
// comes from the run marker and passes RequireThrowaway; the credentials are the
// test-only values of tests/e2e/values/postgres.yaml.
func openThrowawayDB(t *testing.T) *sql.DB {
	t.Helper()
	addr, err := env.Addr("db")
	if err != nil {
		t.Fatal(err)
	}
	if err := env.RequireThrowaway(addr); err != nil {
		t.Fatal(err)
	}
	db, err := sql.Open("pgx", fmt.Sprintf("postgres://app:e2e-only-not-a-secret@%s/app", addr))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := db.Close(); err != nil {
			t.Errorf("close database: %v", err)
		}
	})
	return db
}

// insertBookingRow writes one row with a plain INSERT, never an upsert: if the
// row already exists the test fails instead of overwriting it. Removal of
// exactly this row is registered at once.
func insertBookingRow(t *testing.T, ctx context.Context, db *sql.DB, id, status string) {
	t.Helper()
	if _, err := db.ExecContext(ctx,
		`INSERT INTO bookings (id, tenant, status, body) VALUES ($1, '', $2, '{}')`, id, status); err != nil {
		t.Fatalf("seed booking %s: %v", id, err)
	}
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if _, err := db.ExecContext(ctx, `DELETE FROM bookings WHERE id = $1`, id); err != nil {
			t.Errorf("cleanup of booking row %s: %v", id, err)
		}
	})
}
```

### `tests/e2e/journey_archive_test.go`

```go
//go:build e2e && !smoke

package e2e

import (
	"net/http"
	"testing"
)

// TestJourney_ArchivedBookingStillReadable proves AC-US-6.2: a booking archived
// by the nightly job (no public API creates that state) can still be read.
func TestJourney_ArchivedBookingStillReadable(t *testing.T) {
	ctx, _ := startJourney(t)
	api, err := env.Client("api")
	if err != nil {
		t.Fatal(err)
	}
	db := openThrowawayDB(t)
	id := ref(t)
	insertBookingRow(t, ctx, db, id, "archived")

	var got booking
	status, err := api.Do(ctx, http.MethodGet, "/bookings/"+id, nil, &got)
	if err != nil || status != http.StatusOK || got.Status != "archived" {
		t.Fatalf("read archived booking: status %d, booking status %q, err %v", status, got.Status, err)
	}

	// A second seed of the same row must fail loudly, not overwrite.
	if _, err := db.ExecContext(ctx, `INSERT INTO bookings (id, tenant, status, body) VALUES ($1, '', 'pending', '{}')`, id); err == nil {
		t.Fatal("a second INSERT of the same row succeeded")
	}
}
```
