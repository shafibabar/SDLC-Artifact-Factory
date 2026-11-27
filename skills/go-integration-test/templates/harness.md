# Integration Harness (PostgreSQL)

Copy both files into `internal/test/` unchanged except for the values named below: they import nothing of the product. Compiled and run on Go 1.27.4 with testcontainers-go v0.45.0, pgx v5.13.0 and goose v3.30.2.

```bash
go get github.com/testcontainers/testcontainers-go@v0.45.0 \
  github.com/testcontainers/testcontainers-go/modules/postgres@v0.45.0 \
  github.com/jackc/pgx/v5@v5.13.0 github.com/pressly/goose/v3@v3.30.2
go mod tidy
```

Change only: the image tag (match production), the pool size, and the start limits. `StartPostgres` takes the migrations as an `fs.FS`; the product exports them, for example `//go:embed *.sql` as `var FS embed.FS` in a `migrations` package.

Test data helpers (`internal/test/db/tx.go`, `internal/test/db/scope.go`: `WithTx`, `ID`, `Scoped`) come from the Go fixture template of `test-fixture-design`; do not rewrite them here.

The coverage gates measure these files (see the skill's coverage rule).

### `internal/test/containers.go`

```go
// Package test is the integration test harness: throwaway containers started by
// the test run itself, the real migrations, and a leftover check.
package test

import (
	"context"
	"database/sql"
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"log"
	"maps"
	"net/netip"
	"slices"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/moby/moby/api/types/container"
	"github.com/moby/moby/api/types/network"
	"github.com/pressly/goose/v3"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
)

// Pin the tag to the version production runs.
const PostgresImage = "postgres:17.12-alpine"

// Start limits. Chosen values, not measurements: raise them if a cold image pull needs it.
const (
	startAttempts = 3
	startTimeout  = 2 * time.Minute
	startBackoff  = time.Second
)

// Integration skips the calling test under -short. Every integration test calls it first.
func Integration(t testing.TB) {
	t.Helper()
	if testing.Short() {
		t.Skip("integration test: skipped by -short")
	}
}

// StartWithRetry retries a container START only, never a test. Each attempt has
// its own deadline; a container left by a failed attempt is terminated.
func StartWithRetry[C testcontainers.Container](ctx context.Context, name string,
	start func(context.Context) (C, error)) (C, error) {
	var zero C
	var failures []error
	for attempt := 1; attempt <= startAttempts; attempt++ {
		attemptCtx, cancel := context.WithTimeout(ctx, startTimeout)
		ctr, err := start(attemptCtx)
		cancel()
		if err == nil {
			return ctr, nil
		}
		err = errors.Join(err, testcontainers.TerminateContainer(ctr))
		log.Printf("start %s: attempt %d of %d failed: %v", name, attempt, startAttempts, err)
		failures = append(failures, err)
		if attempt == startAttempts {
			break
		}
		select {
		case <-ctx.Done():
			return zero, fmt.Errorf("start %s: %w", name, errors.Join(append(failures, ctx.Err())...))
		case <-time.After(time.Duration(attempt) * startBackoff):
		}
	}
	return zero, fmt.Errorf("start %s: %w", name, errors.Join(failures...))
}

// loopback publishes the ports on 127.0.0.1 only, on random host ports.
func loopback(ports ...string) testcontainers.CustomizeRequestOption {
	return testcontainers.WithHostConfigModifier(func(hc *container.HostConfig) {
		if hc.PortBindings == nil {
			hc.PortBindings = network.PortMap{}
		}
		for _, p := range ports {
			hc.PortBindings[network.MustParsePort(p)] = []network.PortBinding{
				{HostIP: netip.MustParseAddr("127.0.0.1")},
			}
		}
	})
}

// Postgres is one throwaway server with the migrations applied to its database.
type Postgres struct {
	Pool       *pgxpool.Pool
	ctr        *postgres.PostgresContainer
	migrations fs.FS
	databases  atomic.Int64
}

// StartPostgres starts the container and applies every migration. The address
// comes only from this container: DATABASE_URL is never read. The caller calls Close.
func StartPostgres(ctx context.Context, migrations fs.FS) (*Postgres, error) {
	ctr, err := StartWithRetry(ctx, PostgresImage, func(ctx context.Context) (*postgres.PostgresContainer, error) {
		return postgres.Run(ctx, PostgresImage,
			postgres.WithDatabase("app_test"),
			postgres.WithUsername("test"),
			postgres.WithPassword("test"),
			postgres.BasicWaitStrategies(), // a port check alone passes during initdb's first start
			loopback("5432/tcp"),
		)
	})
	if err != nil {
		return nil, err
	}
	p := &Postgres{ctr: ctr, migrations: migrations}
	p.Pool, err = p.open(ctx, "app_test")
	if err != nil {
		return nil, errors.Join(err, testcontainers.TerminateContainer(ctr))
	}
	return p, nil
}

// DSN returns the connection string of one database in this container.
func (p *Postgres) DSN(ctx context.Context, database string) (string, error) {
	dsn, err := p.ctr.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		return "", fmt.Errorf("connection string: %w", err)
	}
	return strings.Replace(dsn, "/app_test?", "/"+database+"?", 1), nil
}

func (p *Postgres) open(ctx context.Context, database string) (*pgxpool.Pool, error) {
	dsn, err := p.DSN(ctx, database)
	if err != nil {
		return nil, err
	}
	if err := Migrate(ctx, dsn, p.migrations); err != nil {
		return nil, err
	}
	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse pool config: %w", err)
	}
	// Every rollback test holds one connection until it ends. Keep this above
	// go test's -parallel (default GOMAXPROCS) or tests queue for a connection.
	cfg.MaxConns = 40
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("open pool: %w", err)
	}
	return pool, nil
}

// Migrate applies every migration with goose, as a deployment does.
func Migrate(ctx context.Context, dsn string, migrations fs.FS) (err error) {
	provider, closeDB, err := MigrationProvider(dsn, migrations)
	if err != nil {
		return err
	}
	defer func() { err = errors.Join(err, closeDB()) }()
	if _, err := provider.Up(ctx); err != nil {
		return fmt.Errorf("migrate up: %w", err)
	}
	return nil
}

// MigrationProvider gives a migration test control of single steps.
func MigrationProvider(dsn string, migrations fs.FS) (*goose.Provider, func() error, error) {
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return nil, nil, fmt.Errorf("open for migration: %w", err)
	}
	provider, err := goose.NewProvider(goose.DialectPostgres, db, migrations)
	if err != nil {
		return nil, nil, errors.Join(fmt.Errorf("goose provider: %w", err), db.Close())
	}
	return provider, db.Close, nil
}

// NewDatabase gives one test its own migrated database, dropped when it ends.
// For code that reads every row (a relay, a scheduler) and migration tests.
func (p *Postgres) NewDatabase(t testing.TB) (*pgxpool.Pool, string) {
	t.Helper()
	name := fmt.Sprintf("it_%d", p.databases.Add(1))
	ident := pgx.Identifier{name}.Sanitize()
	if _, err := p.Pool.Exec(context.Background(), "CREATE DATABASE "+ident); err != nil {
		t.Fatalf("create database %s: %v", name, err)
	}
	t.Cleanup(func() {
		if _, err := p.Pool.Exec(context.Background(), "DROP DATABASE "+ident+" WITH (FORCE)"); err != nil {
			t.Errorf("drop database %s: %v", name, err)
		}
	})
	pool, err := p.open(context.Background(), name)
	if err != nil {
		t.Fatalf("open database %s: %v", name, err)
	}
	t.Cleanup(pool.Close) // registered last, so it runs before the drop
	dsn, err := p.DSN(context.Background(), name)
	if err != nil {
		t.Fatalf("dsn %s: %v", name, err)
	}
	return pool, dsn
}

// RowCounts counts the rows of every table in the shared database. TestMain
// compares the counts before and after the package: a difference is a leak.
func (p *Postgres) RowCounts(ctx context.Context) (map[string]int64, error) {
	rows, err := p.Pool.Query(ctx, `
		SELECT table_schema, table_name FROM information_schema.tables
		 WHERE table_type = 'BASE TABLE' AND table_schema NOT IN ('pg_catalog', 'information_schema')`)
	if err != nil {
		return nil, fmt.Errorf("list tables: %w", err)
	}
	tables, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (pgx.Identifier, error) {
		var schema, name string
		err := row.Scan(&schema, &name)
		return pgx.Identifier{schema, name}, err
	})
	if err != nil {
		return nil, fmt.Errorf("list tables: %w", err)
	}
	counts := make(map[string]int64, len(tables))
	for _, table := range tables {
		var n int64
		if err := p.Pool.QueryRow(ctx, "SELECT count(*) FROM "+table.Sanitize()).Scan(&n); err != nil {
			return nil, fmt.Errorf("count %s: %w", table.Sanitize(), err)
		}
		counts[table.Sanitize()] = n
	}
	return counts, nil
}

// Differences lists the tables whose row count changed.
func Differences(before, after map[string]int64) []string {
	var out []string
	all := maps.Clone(before)
	maps.Copy(all, after)
	for _, table := range slices.Sorted(maps.Keys(all)) {
		if before[table] != after[table] {
			out = append(out, fmt.Sprintf("%s: %d rows before, %d after", table, before[table], after[table]))
		}
	}
	return out
}

// Close closes the pool and removes the container.
func (p *Postgres) Close() error {
	p.Pool.Close()
	return testcontainers.TerminateContainer(p.ctr)
}

// RunPostgres is the body of TestMain for a package that needs PostgreSQL only.
// Under -short it starts nothing. It returns a non-zero code when a container
// cannot start or stop, or when the tests left rows in the shared database.
func RunPostgres(m *testing.M, migrations fs.FS, use func(*Postgres)) (code int) {
	if Short() {
		return m.Run()
	}
	ctx := context.Background()
	pg, err := StartPostgres(ctx, migrations)
	if err != nil {
		log.Printf("integration harness: %v", err)
		return 1
	}
	defer func() {
		if err := pg.Close(); err != nil {
			log.Printf("integration harness: stop postgres: %v", err)
			code = 1
		}
	}()
	before, err := pg.RowCounts(ctx)
	if err != nil {
		log.Printf("integration harness: %v", err)
		return 1
	}
	use(pg)
	code = m.Run()
	after, err := pg.RowCounts(ctx)
	if err != nil {
		log.Printf("integration harness: %v", err)
		return 1
	}
	if leaks := Differences(before, after); len(leaks) > 0 {
		log.Printf("integration harness: tests changed the shared database:\n  %s", strings.Join(leaks, "\n  "))
		return 1
	}
	return code
}

// Short parses the flags (TestMain runs before they are parsed) and reports -short.
func Short() bool {
	if !flag.Parsed() {
		flag.Parse()
	}
	return testing.Short()
}
```

### `internal/test/await.go`

```go
package test

import (
	"context"
	"testing"
	"time"
)

// Await polls check until it reports true, and fails the test at the deadline
// with the last error. Call it from the test's own goroutine.
func Await(t testing.TB, timeout time.Duration, what string, check func(context.Context) (bool, error)) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	tick := time.NewTicker(20 * time.Millisecond)
	defer tick.Stop()
	var last error
	for {
		done, err := check(ctx)
		if done && err == nil {
			return
		}
		if err != nil && ctx.Err() == nil {
			last = err
		}
		select {
		case <-ctx.Done():
			t.Fatalf("%s: not observed within %s (last error: %v)", what, timeout, last)
		case <-tick.C:
		}
	}
}
```
