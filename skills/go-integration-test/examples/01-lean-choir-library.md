# Lean: a Choir's Sheet-Music Library

One Go service, one PostgreSQL database, one organisation (no tenant column), no broker. Lean means these few tests and one container, with every fixed rule kept.

Run on 2026-11-27: Go 1.27.4, testcontainers-go v0.45.0, pgx v5.13.0, goose v3.30.2, `postgres:17.12-alpine`.

## Plan

| Behaviour | Isolation |
|---|---|
| Lend, read, return, return twice | Rollback |
| Second open loan refused by the index | Rollback, refusal inside a savepoint |
| Database failure reaches the caller | Rollback (aborted transaction) |
| Migration up, down, up | Own database |

No relay, consumer or API promise exists, so none is tested, and no Redpanda harness is copied. When the service gains an HTTP contract, its documented errors are tested here too.

## Files

Harness (`containers.go`, `await.go`) and `internal/test/db/` copied unchanged; `migrations/embed.go` exports `FS`.

### `migrations/00001_create_loans.sql`

```sql
-- +goose Up
CREATE TABLE loans (
    id       uuid PRIMARY KEY,
    score    text NOT NULL,
    singer   text NOT NULL,
    returned boolean NOT NULL DEFAULT false
);
CREATE UNIQUE INDEX loans_one_open_per_score ON loans (score) WHERE NOT returned;

-- +goose Down
DROP TABLE loans;
```

### `internal/loans/store.go`

```go
// Package loans records which singer has which score.
package loans

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrOnLoan  = errors.New("score is already on loan")
	ErrNotOpen = errors.New("no open loan with this id")
)

type querier interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

type Store struct{ q querier }

func NewStore(pool *pgxpool.Pool) *Store { return &Store{q: pool} }
func (s *Store) WithTx(tx pgx.Tx) *Store { return &Store{q: tx} }

func (s *Store) Lend(ctx context.Context, id uuid.UUID, score, singer string) error {
	_, err := s.q.Exec(ctx, `INSERT INTO loans (id, score, singer) VALUES ($1, $2, $3)`, id, score, singer)
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.ConstraintName == "loans_one_open_per_score" {
		return ErrOnLoan
	}
	if err != nil {
		return fmt.Errorf("lend: %w", err)
	}
	return nil
}

func (s *Store) Return(ctx context.Context, id uuid.UUID) error {
	tag, err := s.q.Exec(ctx, `UPDATE loans SET returned = true WHERE id = $1 AND NOT returned`, id)
	if err != nil {
		return fmt.Errorf("return: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotOpen
	}
	return nil
}

// Holder reports who has the score now; empty when nobody does.
func (s *Store) Holder(ctx context.Context, score string) (string, error) {
	var singer string
	err := s.q.QueryRow(ctx, `SELECT singer FROM loans WHERE score = $1 AND NOT returned`, score).Scan(&singer)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil
	}
	if err != nil {
		return "", fmt.Errorf("holder: %w", err)
	}
	return singer, nil
}
```

### `internal/loans/store_integration_test.go`

```go
package loans_test

import (
	"context"
	"errors"
	"os"
	"testing"

	"github.com/jackc/pgx/v5"

	"example.com/choir/internal/loans"
	"example.com/choir/internal/test"
	testdb "example.com/choir/internal/test/db"
	"example.com/choir/migrations"
)

// pg is set by TestMain; it stays nil under -short, where every test skips.
var pg *test.Postgres

func TestMain(m *testing.M) {
	os.Exit(test.RunPostgres(m, migrations.FS, func(p *test.Postgres) { pg = p }))
}

func TestLendThenReturnFreesTheScore(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx := context.Background()
	store := loans.NewStore(pg.Pool).WithTx(testdb.WithTx(t, pg.Pool))
	id := testdb.ID(t, "loan")
	holder := func(want string) {
		t.Helper()
		if got, err := store.Holder(ctx, "Fauré Requiem"); err != nil || got != want {
			t.Errorf("Holder = %q, %v; want %q", got, err, want)
		}
	}

	if err := store.Lend(ctx, id, "Fauré Requiem", "Ines"); err != nil {
		t.Fatalf("Lend: %v", err)
	}
	holder("Ines")
	if err := store.Return(ctx, id); err != nil {
		t.Fatalf("Return: %v", err)
	}
	holder("")
	if err := store.Return(ctx, id); !errors.Is(err, loans.ErrNotOpen) {
		t.Errorf("second Return = %v, want ErrNotOpen", err)
	}
}

func TestLendRefusesAScoreAlreadyOut(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx := context.Background()
	tx := testdb.WithTx(t, pg.Pool)
	store := loans.NewStore(pg.Pool).WithTx(tx)
	if err := store.Lend(ctx, testdb.ID(t, "first"), "Messiah", "Ines"); err != nil {
		t.Fatalf("Lend: %v", err)
	}
	// A savepoint: the expected constraint error must not abort the test's transaction.
	sp, err := tx.Begin(ctx)
	if err != nil {
		t.Fatalf("savepoint: %v", err)
	}
	if err := store.WithTx(sp).Lend(ctx, testdb.ID(t, "second"), "Messiah", "Oto"); !errors.Is(err, loans.ErrOnLoan) {
		t.Errorf("second Lend = %v, want ErrOnLoan", err)
	}
	if err := sp.Rollback(ctx); err != nil && !errors.Is(err, pgx.ErrTxClosed) {
		t.Fatalf("rollback savepoint: %v", err)
	}
	if got, err := store.Holder(ctx, "Messiah"); err != nil || got != "Ines" {
		t.Errorf("Holder = %q, %v; want Ines", got, err)
	}
}

// Every documented error path through the real database, including its failure.
func TestStoreReportsADatabaseFailure(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx := context.Background()
	tx := testdb.WithTx(t, pg.Pool)
	if _, err := tx.Exec(ctx, `SELECT 1/0`); err == nil {
		t.Fatal("arrange: the transaction should now be aborted")
	}
	store := loans.NewStore(pg.Pool).WithTx(tx)
	id := testdb.ID(t, "loan")
	if err := store.Lend(ctx, id, "Elijah", "Ines"); err == nil || errors.Is(err, loans.ErrOnLoan) {
		t.Errorf("Lend = %v, want a database error", err)
	}
	if err := store.Return(ctx, id); err == nil || errors.Is(err, loans.ErrNotOpen) {
		t.Errorf("Return = %v, want a database error", err)
	}
	if _, err := store.Holder(ctx, "Elijah"); err == nil {
		t.Error("Holder = nil error, want a database error")
	}
}

func TestMigrationsGoDownAndUpAgain(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx := context.Background()
	pool, dsn := pg.NewDatabase(t) // already migrated up
	provider, closeDB, err := test.MigrationProvider(dsn, migrations.FS)
	if err != nil {
		t.Fatalf("provider: %v", err)
	}
	t.Cleanup(func() {
		if err := closeDB(); err != nil {
			t.Errorf("close: %v", err)
		}
	})
	exists := func() (found bool) {
		t.Helper()
		if err := pool.QueryRow(ctx, `SELECT to_regclass('loans') IS NOT NULL`).Scan(&found); err != nil {
			t.Fatalf("look up loans: %v", err)
		}
		return found
	}
	if _, err := provider.DownTo(ctx, 0); err != nil {
		t.Fatalf("down: %v", err)
	}
	if exists() {
		t.Error("loans still exists after down")
	}
	if _, err := provider.Up(ctx); err != nil {
		t.Fatalf("up again: %v", err)
	}
	if !exists() {
		t.Error("loans missing after up again")
	}
}
```

## Output

```text
$ go test -race -shuffle=on -count=1 -v ./...
--- PASS: TestStoreReportsADatabaseFailure
--- PASS: TestLendRefusesAScoreAlreadyOut
--- PASS: TestLendThenReturnFreesTheScore
--- PASS: TestMigrationsGoDownAndUpAgain
ok      example.com/choir/internal/loans
```

## Coverage, as measured

| Gate | Result | Where the gaps are |
|---|---|---|
| Statement blocks | 114/187, **FAIL** | All 55 blocks in `internal/test/`; none in `internal/loans` |
| Branches (gobco 1.3.4) | 12/86, **FAIL** | None in `internal/loans` |

The repository is fully covered with a real database; the build is still blocked by the harness. **Decision for the product owner:** approve each harness file as a listed exclusion, with its reason ("test harness; error paths need container faults"), or have tests written for it. Until then the exclusions are pending and neither gate passes.

Not run: Ryuk (disabled in this run), any CI runner.
