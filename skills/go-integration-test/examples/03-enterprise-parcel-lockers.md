# Enterprise: Parcel Lockers Shared by Several Carriers

The product's tenancy design (assumed here, and only here): carriers share one table, isolated by PostgreSQL row-level security; the service connects as a role subject to it. Couriers claim compartments concurrently. A new column ships while the previous release is running.

Run on 2026-11-27: Go 1.27.4, testcontainers-go v0.45.0, pgx v5.13.0, goose v3.30.2, `postgres:17.12-alpine`.

## Plan

| Behaviour | Isolation and reason |
|---|---|
| A carrier cannot read, change or forge another's parcel; no setting sees nothing | Rollback, as `parcel_app` |
| Superuser bypasses the policy (guard) | Rollback |
| Two claims on one compartment | Real commit, own database: two connections, lock view |
| Previous release works on the new schema | Own database |

## Production code

### `migrations/00001_create_parcels.sql`

```sql
-- +goose Up
CREATE TABLE parcels (
    id          uuid PRIMARY KEY,
    carrier_id  uuid NOT NULL,
    compartment text NOT NULL,
    state       text NOT NULL
);
CREATE UNIQUE INDEX parcels_one_waiting_per_compartment ON parcels (compartment) WHERE state = 'waiting';

-- +goose Down
DROP TABLE parcels;
```

### `migrations/00002_isolate_carriers.sql`

```sql
-- +goose Up
-- Roles belong to the server, not to one database: create only if missing, and
-- tolerate another database's migration creating it at the same moment.
-- +goose StatementBegin
DO $$
BEGIN
    CREATE ROLE parcel_app NOLOGIN;
EXCEPTION WHEN duplicate_object OR unique_violation THEN NULL;
END
$$;
-- +goose StatementEnd
GRANT SELECT, INSERT, UPDATE ON parcels TO parcel_app;
ALTER TABLE parcels ENABLE ROW LEVEL SECURITY;
ALTER TABLE parcels FORCE ROW LEVEL SECURITY;
CREATE POLICY own_carrier ON parcels
    USING (carrier_id = NULLIF(current_setting('app.carrier', true), '')::uuid)
    WITH CHECK (carrier_id = NULLIF(current_setting('app.carrier', true), '')::uuid);

-- +goose Down
DROP POLICY own_carrier ON parcels;
ALTER TABLE parcels NO FORCE ROW LEVEL SECURITY;
ALTER TABLE parcels DISABLE ROW LEVEL SECURITY;
REVOKE SELECT, INSERT, UPDATE ON parcels FROM parcel_app;
```

### `migrations/00003_add_size_code.sql`

```sql
-- +goose Up
-- Expand step: nullable, so the release already running can still insert.
ALTER TABLE parcels ADD COLUMN size_code text;

-- +goose Down
ALTER TABLE parcels DROP COLUMN size_code;
```

### `internal/parcels/store.go`

```go
// Package parcels places parcels in lockers for several carriers in one pool.
package parcels

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

var (
	ErrNotFound = errors.New("parcel not found")
	ErrOccupied = errors.New("compartment already holds a waiting parcel")
)

// Beginner is satisfied by *pgxpool.Pool and pgx.Tx.
type Beginner interface {
	Begin(ctx context.Context) (pgx.Tx, error)
}

type Parcel struct {
	ID          uuid.UUID
	Compartment string
	Size        string // empty for rows written before size codes existed
}

// asCarrier runs fn in a transaction whose row-level security shows one carrier.
// The connection's role must be subject to row-level security (parcel_app).
func asCarrier(ctx context.Context, db Beginner, carrier uuid.UUID, fn func(pgx.Tx) error) (err error) {
	tx, err := db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin: %w", err)
	}
	defer func() {
		if rb := tx.Rollback(ctx); rb != nil && !errors.Is(rb, pgx.ErrTxClosed) {
			err = errors.Join(err, fmt.Errorf("rollback: %w", rb))
		}
	}()
	if _, err := tx.Exec(ctx, `SELECT set_config('app.carrier', $1, true)`, carrier.String()); err != nil {
		return fmt.Errorf("set carrier: %w", err)
	}
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func Place(ctx context.Context, db Beginner, carrier uuid.UUID, p Parcel) error {
	return asCarrier(ctx, db, carrier, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `INSERT INTO parcels (id, carrier_id, compartment, state, size_code)
			 VALUES ($1, $2, $3, 'waiting', NULLIF($4, ''))`, p.ID, carrier, p.Compartment, p.Size)
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.ConstraintName == "parcels_one_waiting_per_compartment" {
			return ErrOccupied
		}
		if err != nil {
			return fmt.Errorf("place: %w", err)
		}
		return nil
	})
}

// Find has no carrier filter on purpose in this example: the policy is under test.
func Find(ctx context.Context, db Beginner, carrier, id uuid.UUID) (Parcel, error) {
	p := Parcel{ID: id}
	err := asCarrier(ctx, db, carrier, func(tx pgx.Tx) error {
		err := tx.QueryRow(ctx, `SELECT compartment, coalesce(size_code, '') FROM parcels WHERE id = $1`, id).
			Scan(&p.Compartment, &p.Size)
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		return err
	})
	return p, err
}

// Collect marks a waiting parcel collected.
func Collect(ctx context.Context, db Beginner, carrier, id uuid.UUID) error {
	return asCarrier(ctx, db, carrier, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `UPDATE parcels SET state = 'collected' WHERE id = $1 AND state = 'waiting'`, id)
		if err != nil {
			return fmt.Errorf("collect: %w", err)
		}
		if tag.RowsAffected() == 0 {
			return ErrNotFound
		}
		return nil
	})
}
```

## Tests

### `internal/parcels/main_test.go`

```go
package parcels_test

import (
	"os"
	"testing"

	"example.com/lockers/internal/test"
	"example.com/lockers/migrations"
)

// pg is set by TestMain; it stays nil under -short, where every test skips.
var pg *test.Postgres

func TestMain(m *testing.M) {
	os.Exit(test.RunPostgres(m, migrations.FS, func(p *test.Postgres) { pg = p }))
}
```

### `internal/parcels/isolation_integration_test.go`

```go
package parcels_test

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"example.com/lockers/internal/parcels"
	"example.com/lockers/internal/test"
	testdb "example.com/lockers/internal/test/db"
)

type seeded struct{ carrier, parcel uuid.UUID }

func exec(t *testing.T, tx pgx.Tx, sql string, args ...any) {
	t.Helper()
	if _, err := tx.Exec(context.Background(), sql, args...); err != nil {
		t.Fatalf("%s: %v", sql, err)
	}
}

// twoCarriers seeds one parcel for carrier A and one for B as the superuser,
// then, unless asSuperuser, switches the test's transaction to the application role.
func twoCarriers(t *testing.T, asSuperuser bool) (pgx.Tx, [2]seeded) {
	t.Helper()
	tx := testdb.WithTx(t, pg.Pool)
	var out [2]seeded
	for i, name := range []string{"a", "b"} {
		s := seeded{carrier: testdb.ID(t, "carrier-"+name), parcel: testdb.ID(t, "parcel-"+name)}
		exec(t, tx, `INSERT INTO parcels (id, carrier_id, compartment, state) VALUES ($1, $2, $3, 'waiting')`,
			s.parcel, s.carrier, t.Name()+name)
		out[i] = s
	}
	if !asSuperuser {
		exec(t, tx, `SET LOCAL ROLE parcel_app`)
	}
	return tx, out
}

func TestCarrierCannotReadOrChangeAnothersParcel(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx := context.Background()
	tx, s := twoCarriers(t, false)
	a, b := s[0], s[1]

	if _, err := parcels.Find(ctx, tx, a.carrier, a.parcel); err != nil {
		t.Fatalf("A cannot read its own parcel: %v", err) // otherwise the denials prove nothing
	}
	if _, err := parcels.Find(ctx, tx, a.carrier, b.parcel); !errors.Is(err, parcels.ErrNotFound) {
		t.Errorf("A reads B: %v, want ErrNotFound", err)
	}
	if err := parcels.Collect(ctx, tx, a.carrier, b.parcel); !errors.Is(err, parcels.ErrNotFound) {
		t.Errorf("A collects B: %v, want ErrNotFound", err)
	}
	if _, err := parcels.Find(ctx, tx, b.carrier, b.parcel); err != nil {
		t.Errorf("B cannot read its own parcel: %v", err)
	}
	if err := parcels.Collect(ctx, tx, b.carrier, b.parcel); err != nil {
		t.Errorf("B collects its parcel: %v", err)
	}
}

func TestCarrierCannotWriteAParcelForAnother(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	tx, s := twoCarriers(t, false)
	sp, err := tx.Begin(context.Background())
	if err != nil {
		t.Fatalf("savepoint: %v", err)
	}
	exec(t, sp, `SELECT set_config('app.carrier', $1, true)`, s[0].carrier.String())
	_, err = sp.Exec(context.Background(), `INSERT INTO parcels (id, carrier_id, compartment, state)
		VALUES ($1, $2, 'z', 'waiting')`, testdb.ID(t, "forged"), s[1].carrier)
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) || pgErr.Code != "42501" {
		t.Errorf("insert for B as A = %v, want insufficient_privilege (42501)", err)
	}
	if err := sp.Rollback(context.Background()); err != nil {
		t.Errorf("rollback savepoint: %v", err)
	}
}

func TestNoCarrierSettingSeesNothing(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	tx, _ := twoCarriers(t, false)
	var n int
	if err := tx.QueryRow(context.Background(), `SELECT count(*) FROM parcels`).Scan(&n); err != nil || n != 0 {
		t.Errorf("rows visible with no carrier set: %d, %v; want 0", n, err)
	}
}

// Guard test: the container's user is a superuser, and a superuser bypasses
// row-level security. An isolation test that skips SET ROLE proves nothing.
func TestSuperuserBypassesRowLevelSecurity(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	tx, s := twoCarriers(t, true)
	if _, err := parcels.Find(context.Background(), tx, s[0].carrier, s[1].parcel); err != nil {
		t.Errorf("superuser reading another carrier's parcel: %v, want it to succeed", err)
	}
}
```

### `internal/parcels/claim_integration_test.go`

```go
package parcels_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"example.com/lockers/internal/parcels"
	"example.com/lockers/internal/test"
	testdb "example.com/lockers/internal/test/db"
	"example.com/lockers/migrations"
)

// Real commit needed: two couriers on two connections claim one compartment.
// The second is held until the first commits; no sleep decides the order.
func TestTwoCouriersClaimOneCompartment(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	t.Cleanup(cancel)
	pool, _ := pg.NewDatabase(t) // own database: pg_stat_activity is filtered to it
	carrier := testdb.ID(t, "carrier")

	first, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin: %v", err)
	}
	t.Cleanup(func() { rollback(t, first.Rollback) })
	// Inside first's open transaction, so Place uses a savepoint and first holds the claim.
	if err := parcels.Place(ctx, first, carrier, parcels.Parcel{ID: testdb.ID(t, "one"), Compartment: "c7"}); err != nil {
		t.Fatalf("first Place: %v", err)
	}

	second := make(chan error, 1)
	go func() {
		second <- parcels.Place(ctx, pool, carrier, parcels.Parcel{ID: testdb.ID(t, "two"), Compartment: "c7"})
	}()
	test.Await(t, 10*time.Second, "the second claim waiting on a lock", func(ctx context.Context) (bool, error) {
		return waitingOnLock(ctx, pool)
	})
	if err := first.Commit(ctx); err != nil {
		t.Fatalf("commit: %v", err)
	}

	select {
	case err := <-second:
		if !errors.Is(err, parcels.ErrOccupied) {
			t.Errorf("second Place = %v, want ErrOccupied", err)
		}
	case <-ctx.Done():
		t.Fatal("second Place did not return")
	}
}

func waitingOnLock(ctx context.Context, pool *pgxpool.Pool) (found bool, err error) {
	err = pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM pg_stat_activity
		WHERE datname = current_database() AND wait_event_type = 'Lock')`).Scan(&found)
	return found, err
}

func rollback(t *testing.T, fn func(context.Context) error) {
	t.Helper()
	if err := fn(context.Background()); err != nil && !errors.Is(err, pgx.ErrTxClosed) {
		t.Errorf("rollback: %v", err)
	}
}

// Expand step: the previous release's statements and the new code must both work
// on the new schema, because migration and rollout do not happen at one instant.
func TestSizeCodeMigrationKeepsThePreviousReleaseWorking(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx := context.Background()
	pool, dsn := pg.NewDatabase(t)
	provider, closeDB, err := test.MigrationProvider(dsn, migrations.FS)
	if err != nil {
		t.Fatalf("provider: %v", err)
	}
	t.Cleanup(func() {
		if err := closeDB(); err != nil {
			t.Errorf("close: %v", err)
		}
	})
	if _, err := provider.DownTo(ctx, 2); err != nil {
		t.Fatalf("down to the previous schema: %v", err)
	}
	carrier := testdb.ID(t, "carrier")
	// Copied from the release now in production; do not update it with the code.
	const previousInsert = `INSERT INTO parcels (id, carrier_id, compartment, state) VALUES ($1, $2, $3, 'waiting')`
	const previousRead = `SELECT compartment, state FROM parcels WHERE id = $1`
	previous := func(id, compartment string) {
		t.Helper()
		parcel := testdb.ID(t, id)
		if _, err := pool.Exec(ctx, previousInsert, parcel, carrier, compartment); err != nil {
			t.Fatalf("previous release insert: %v", err)
		}
		var got, state string
		if err := pool.QueryRow(ctx, previousRead, parcel).Scan(&got, &state); err != nil || got != compartment {
			t.Fatalf("previous release read: %q, %v", got, err)
		}
	}
	previous("before", "c1")

	if _, err := provider.UpByOne(ctx); err != nil {
		t.Fatalf("apply the new migration: %v", err)
	}
	previous("after", "c2")
	old, err := parcels.Find(ctx, pool, carrier, testdb.ID(t, "before"))
	if err != nil || old.Size != "" || old.Compartment != "c1" {
		t.Errorf("new code reads old row: %+v, %v", old, err)
	}
	sized := parcels.Parcel{ID: testdb.ID(t, "sized"), Compartment: "c3", Size: "M"}
	if err := parcels.Place(ctx, pool, carrier, sized); err != nil {
		t.Fatalf("new code writes: %v", err)
	}
	if got, err := parcels.Find(ctx, pool, carrier, sized.ID); err != nil || got != sized {
		t.Errorf("new code reads %+v, %v; want %+v", got, err, sized)
	}
}
```

## Output and broken on purpose

`go test -race -shuffle=on -count=3 ./...` passed.

| Broken (in a copy, then reverted) | Observed |
|---|---|
| Policy changed to `USING (true) WITH CHECK (true)` | `A reads B`, `A collects B`, `insert for B as A = <nil>`, `rows visible with no carrier set: 2` |
| New column `NOT NULL` with no default | `previous release insert: null value in column "size_code" ... (SQLSTATE 23502)` |

The guard test shows why the role switch matters: as the container's superuser, carrier A reads carrier B's parcel.

## Coverage and open points

| Gate | Result | Where the gaps are |
|---|---|---|
| Statement blocks | 28/33, **FAIL** | 5 blocks in `store.go` |
| Branches (gobco 1.3.4) | 13/18, **FAIL** | 5 error branches in `store.go` |

Left out as the approved test-support class, listed by both gates and in the report:

```text
excluded internal/test/await.go: test support (class approved by the product owner)
excluded internal/test/containers.go: test support (class approved by the product owner)
excluded internal/test/db/scope.go: test support (class approved by the product owner)
excluded internal/test/db/tx.go: test support (class approved by the product owner)
```

**Next:** fault cases for the five `store.go` branches. **For the product owner:** confirmation of the tenancy design and of who may bypass row-level security (support, reporting, migrations); the release that makes `size_code` required.

Unproven here: the production login's actual role membership (check it against the deployed environment), lock time of the migration on a large table, several regions, parallel CI shards. A sharded run gives no coverage verdict; the gates run the full suite.
