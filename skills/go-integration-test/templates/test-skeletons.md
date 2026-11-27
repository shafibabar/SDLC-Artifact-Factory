# Test File Skeletons

Copy what the test needs; replace `example.com/product`, the `things` table and `newRouter`. Compiled and run against the harness with a one-table migration and a stand-in `newRouter` (a handler that answers 404). Broker tests (duplicate delivery, dead letters, relay) are copied from example 02.

## One `main_test.go` per package: PostgreSQL

### `internal/things/main_test.go`

```go
package things_test

import (
	"os"
	"testing"

	"example.com/product/internal/test"
	"example.com/product/migrations"
)

// pg is set by TestMain; it stays nil under -short, where every test skips.
var pg *test.Postgres

func TestMain(m *testing.M) {
	os.Exit(test.RunPostgres(m, migrations.FS, func(p *test.Postgres) { pg = p }))
}
```

## One `main_test.go` per package: PostgreSQL and Redpanda

### `internal/thingevents/main_test.go`

```go
package thingevents_test

import (
	"os"
	"testing"

	"example.com/product/internal/test"
	"example.com/product/migrations"
)

var (
	pg     *test.Postgres
	broker *test.Redpanda
)

func TestMain(m *testing.M) {
	os.Exit(test.RunPostgresAndRedpanda(m, migrations.FS,
		func(p *test.Postgres, r *test.Redpanda) { pg, broker = p, r }))
}
```

## Tests: rollback (default), real commit, API behaviour

### `internal/things/things_integration_test.go`

```go
package things_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"example.com/product/internal/test"
	testdb "example.com/product/internal/test/db"
)

// Default: roll back. Replace the SQL with calls to the repository under test,
// bound to tx.
func TestThingIsStored(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx := context.Background()
	tx := testdb.WithTx(t, pg.Pool)
	id := testdb.ID(t, "thing")

	if _, err := tx.Exec(ctx, `INSERT INTO things (id, name) VALUES ($1, $2)`, id, t.Name()); err != nil {
		t.Fatalf("insert: %v", err)
	}

	var name string
	if err := tx.QueryRow(ctx, `SELECT name FROM things WHERE id = $1`, id).Scan(&name); err != nil || name != t.Name() {
		t.Errorf("name = %q, %v; want %q", name, err, t.Name())
	}
}

// Real commit needed: <name the reason>. Scoped is registered before any write
// and lists every table the test or the code under test writes, children first.
func TestThingIsVisibleToAnotherConnection(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx := context.Background()
	id := testdb.ID(t, "thing")
	testdb.Scoped(t, pg.Pool, id, `DELETE FROM things WHERE id = $1`)

	if _, err := pg.Pool.Exec(ctx, `INSERT INTO things (id, name) VALUES ($1, $2)`, id, t.Name()); err != nil {
		t.Fatalf("insert: %v", err)
	}

	other, err := pg.Pool.Acquire(ctx)
	if err != nil {
		t.Fatalf("acquire: %v", err)
	}
	t.Cleanup(other.Release)
	var n int
	if err := other.QueryRow(ctx, `SELECT count(*) FROM things WHERE id = $1`, id).Scan(&n); err != nil || n != 1 {
		t.Errorf("rows seen = %d, %v; want 1", n, err)
	}
}

// API behaviour through the real router, in this goroutine, so a router built on
// the test's transaction stays inside it. Replace newRouter with the service's own.
func TestUnknownThingIs404(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	router := newRouter(testdb.WithTx(t, pg.Pool))
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/things/unknown", nil))
	if rec.Code != http.StatusNotFound {
		t.Errorf("status = %d, body %s; want 404", rec.Code, rec.Body)
	}
}
```
