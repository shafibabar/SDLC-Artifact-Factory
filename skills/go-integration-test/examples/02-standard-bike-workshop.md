# Standard: a Bike Repair Workshop

Booking jobs over HTTP; each booking writes its event to a Transactional Outbox; a relay publishes it; a consumer sends one reminder per event. One organisation, no tenant column.

Run on 2026-11-27: Go 1.27.4, testcontainers-go v0.45.0, pgx v5.13.0, goose v3.30.2, franz-go v1.22.3, chi v5.5.0, `postgres:17.12-alpine`, `redpandadata/redpanda:v26.2.7`.

## Contents
Plan; contract assumed; production code; tests; output; broken on purpose; coverage and open points.

## Plan

| Behaviour | Isolation and reason |
|---|---|
| Stale start refused; second open job refused | Rollback |
| Rollback hides writes from other connections (guard) | Rollback |
| Job and event commit together or not at all | Real commit, own database: the test alters a table |
| Repeat request, key reuse, rate limit, errors, deprecation, workflow | Rollback, real router |
| Eight identical requests at once | Real commit, scoped keys: separate connections |
| Relay publishes once | Real commit, own database: it reads every row |
| Duplicate event, poison record | Real commit, own database and topic |
| Migrations up, down, up | Own database |

## Contract assumed

`POST /v2/jobs` (optional `Idempotency-Key`; same key and body replays the 201; other body 422 `IDEMPOTENCY_KEY_REUSED`), `GET /v2/jobs/{id}`, `POST /v2/jobs/{id}/start` with the version read; per-caller rate limit answering 429 `RATE_LIMITED` with `Retry-After`; `/v1` deprecated with `Deprecation` and `Sunset`. `X-Subject` stands in for the authenticated subject; authentication is not part of this example. Key retention is not modelled.

The consumer is deliberately minimal: no worker pool, no retry with backoff. `go-event-consumer` owns the production shape; its retry paths need their own tests.

## Production code

### `migrations/00001_create_jobs.sql`

```sql
-- +goose Up
CREATE TABLE jobs (
    id       uuid PRIMARY KEY,
    bike_ref text NOT NULL,
    state    text NOT NULL,
    version  int  NOT NULL
);
CREATE UNIQUE INDEX jobs_one_open_per_bike ON jobs (bike_ref) WHERE state <> 'done';
CREATE TABLE outbox (
    id           uuid PRIMARY KEY,
    aggregate_id uuid NOT NULL,
    event_type   text NOT NULL,
    occurred_at  timestamptz NOT NULL DEFAULT now(),
    published_at timestamptz
);
CREATE TABLE idempotency_keys (
    key          text PRIMARY KEY,
    request_hash text  NOT NULL,
    status       int   NOT NULL,
    body         bytea NOT NULL
);

-- +goose Down
DROP TABLE idempotency_keys, outbox, jobs;
```

### `migrations/00002_create_reminders.sql`

```sql
-- +goose Up
CREATE TABLE processed_events (
    consumer_name text NOT NULL,
    event_id      uuid NOT NULL,
    PRIMARY KEY (consumer_name, event_id)
);
CREATE TABLE reminders (
    job_id uuid PRIMARY KEY,
    sent   int NOT NULL
);

-- +goose Down
DROP TABLE reminders, processed_events;
```

### `internal/workshop/store.go`

```go
// Package workshop books bike repair jobs.
package workshop

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
	ErrNotFound = errors.New("job not found")
	ErrConflict = errors.New("job was changed by someone else")
	ErrBikeBusy = errors.New("bike already has an open job")
)

type Job struct {
	ID      uuid.UUID `json:"id"`
	Bike    string    `json:"bike"`
	State   string    `json:"state"`
	Version int       `json:"version"`
}

// Querier is satisfied by *pgxpool.Pool and pgx.Tx (go-repository-pattern).
type Querier interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// DB can also open a transaction. Both *pgxpool.Pool and pgx.Tx can; on a
// pgx.Tx, Begin creates a savepoint.
type DB interface {
	Querier
	Begin(ctx context.Context) (pgx.Tx, error)
}

type Store struct{ q Querier }

func NewStore(pool *pgxpool.Pool) *Store { return &Store{q: pool} }
func (s *Store) WithTx(tx pgx.Tx) *Store { return &Store{q: tx} }
func (s *Store) record(ctx context.Context, id uuid.UUID, event string) error {
	_, err := s.q.Exec(ctx, `INSERT INTO outbox (id, aggregate_id, event_type) VALUES ($1, $2, $3)`,
		uuid.New(), id, event)
	if err != nil {
		return fmt.Errorf("write outbox: %w", err)
	}
	return nil
}

func (s *Store) Find(ctx context.Context, id uuid.UUID) (Job, error) {
	job := Job{ID: id}
	err := s.q.QueryRow(ctx, `SELECT bike_ref, state, version FROM jobs WHERE id = $1`, id).
		Scan(&job.Bike, &job.State, &job.Version)
	if errors.Is(err, pgx.ErrNoRows) {
		return Job{}, ErrNotFound
	}
	if err != nil {
		return Job{}, fmt.Errorf("find job: %w", err)
	}
	return job, nil
}

// Create stores a booked job and its event. It must be bound to a transaction.
func (s *Store) Create(ctx context.Context, job Job) error {
	_, err := s.q.Exec(ctx, `INSERT INTO jobs (id, bike_ref, state, version) VALUES ($1, $2, $3, $4)`,
		job.ID, job.Bike, job.State, job.Version)
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.ConstraintName == "jobs_one_open_per_bike" {
		return ErrBikeBusy
	}
	if err != nil {
		return fmt.Errorf("insert job: %w", err)
	}
	return s.record(ctx, job.ID, "JobBooked")
}

// Start moves a job to started if nobody changed it since it was read.
func (s *Store) Start(ctx context.Context, job Job) error {
	tag, err := s.q.Exec(ctx, `UPDATE jobs SET state = 'started', version = version + 1
		 WHERE id = $1 AND version = $2 AND state = 'booked'`, job.ID, job.Version)
	if err != nil {
		return fmt.Errorf("start job: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrConflict
	}
	return s.record(ctx, job.ID, "JobStarted")
}

// InTx runs fn in a transaction and commits it if fn succeeds.
func InTx(ctx context.Context, db DB, fn func(pgx.Tx) error) (err error) {
	tx, err := db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin: %w", err)
	}
	defer func() {
		if rb := tx.Rollback(ctx); rb != nil && !errors.Is(rb, pgx.ErrTxClosed) {
			err = errors.Join(err, fmt.Errorf("rollback: %w", rb))
		}
	}()
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
```

### `internal/workshop/api.go`

```go
package workshop

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"math"
	"net/http"
	"strconv"
	"sync"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"golang.org/x/time/rate"
)

// Limits is the per-caller token bucket (go-middleware sets the shipped values).
type Limits struct {
	Rate  rate.Limit
	Burst int
}

type apiError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// The contract's deprecation notice for /v1.
const (
	DeprecationV1 = "@1795737600"
	SunsetV1      = "Mon, 31 May 2027 00:00:00 GMT"
)

type api struct{ db DB }

// NewRouter is the router the service serves and the tests call.
func NewRouter(db DB, limits Limits) http.Handler {
	a := api{db: db}
	r := chi.NewRouter()
	r.Use(rateLimit(limits))
	r.Post("/v2/jobs", a.book)
	r.Get("/v2/jobs/{id}", a.get)
	r.Post("/v2/jobs/{id}/start", a.start)
	r.Get("/v1/jobs/{id}", func(w http.ResponseWriter, req *http.Request) {
		w.Header().Set("Deprecation", DeprecationV1)
		w.Header().Set("Sunset", SunsetV1)
		a.get(w, req)
	})
	return r
}

// rateLimit keys on X-Subject, which stands in for the authenticated subject.
func rateLimit(limits Limits) func(http.Handler) http.Handler {
	var mu sync.Mutex
	buckets := map[string]*rate.Limiter{}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			subject := r.Header.Get("X-Subject")
			mu.Lock()
			bucket, ok := buckets[subject]
			if !ok {
				bucket = rate.NewLimiter(limits.Rate, limits.Burst)
				buckets[subject] = bucket
			}
			mu.Unlock()
			reservation := bucket.Reserve()
			if wait := reservation.Delay(); wait > 0 {
				reservation.Cancel()
				w.Header().Set("Retry-After", strconv.Itoa(int(math.Ceil(wait.Seconds()))))
				writeError(w, http.StatusTooManyRequests, "RATE_LIMITED", "too many requests")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func writeJSON(w http.ResponseWriter, status int, body []byte) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if _, err := w.Write(body); err != nil {
		slog.Warn("write response", "error", err)
	}
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	body, err := json.Marshal(apiError{Code: code, Message: message})
	if err != nil {
		slog.Error("marshal error body", "error", err)
	}
	writeJSON(w, status, body)
}

func writeDomainError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, ErrNotFound):
		writeError(w, http.StatusNotFound, "NOT_FOUND", err.Error())
	case errors.Is(err, ErrBikeBusy):
		writeError(w, http.StatusConflict, "BIKE_BUSY", err.Error())
	case errors.Is(err, ErrConflict):
		writeError(w, http.StatusConflict, "VERSION_CONFLICT", err.Error())
	case errors.Is(err, errKeyReused):
		writeError(w, http.StatusUnprocessableEntity, "IDEMPOTENCY_KEY_REUSED", err.Error())
	default:
		slog.Error("request failed", "error", err)
		writeError(w, http.StatusInternalServerError, "INTERNAL", "an unexpected error occurred")
	}
}

var errKeyReused = errors.New("this Idempotency-Key was used for a different request")

// book creates a job. With an Idempotency-Key, a repeat returns the stored reply.
func (a api) book(w http.ResponseWriter, r *http.Request) {
	raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 1<<16))
	var in struct {
		Bike string `json:"bike"`
	}
	if err != nil || json.NewDecoder(bytes.NewReader(raw)).Decode(&in) != nil {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "the body is not valid JSON")
		return
	}
	if in.Bike == "" {
		writeError(w, http.StatusUnprocessableEntity, "VALIDATION_FAILED", "bike is required")
		return
	}
	sum := sha256.Sum256(raw)
	key, hash := r.Header.Get("Idempotency-Key"), hex.EncodeToString(sum[:])
	var reply []byte
	err = InTx(r.Context(), a.db, func(tx pgx.Tx) error {
		if key != "" {
			stored, err := claim(r.Context(), tx, key, hash)
			if err != nil || stored != nil {
				reply = stored
				return err
			}
		}
		job := Job{ID: uuid.New(), Bike: in.Bike, State: "booked", Version: 1}
		if err := (&Store{q: tx}).Create(r.Context(), job); err != nil {
			return err
		}
		if reply, err = json.Marshal(job); err != nil {
			return err
		}
		if key == "" {
			return nil
		}
		_, err = tx.Exec(r.Context(), `UPDATE idempotency_keys SET body = $2 WHERE key = $1`, key, reply)
		return err
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, reply)
}

// claim reserves key for this request. A non-nil body is the stored reply of an
// earlier identical request. A concurrent claim of the same key waits here until
// the first transaction ends.
func claim(ctx context.Context, tx pgx.Tx, key, hash string) ([]byte, error) {
	tag, err := tx.Exec(ctx, `INSERT INTO idempotency_keys (key, request_hash, status, body)
		 VALUES ($1, $2, 201, '') ON CONFLICT DO NOTHING`, key, hash)
	if err != nil || tag.RowsAffected() == 1 {
		return nil, err
	}
	var storedHash string
	var body []byte
	if err := tx.QueryRow(ctx, `SELECT request_hash, body FROM idempotency_keys WHERE key = $1`, key).
		Scan(&storedHash, &body); err != nil {
		return nil, err
	}
	if storedHash != hash {
		return nil, errKeyReused
	}
	return body, nil
}

func (a api) get(w http.ResponseWriter, r *http.Request) {
	job, err := a.find(r)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	body, err := json.Marshal(job)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, body)
}

func (a api) find(r *http.Request) (Job, error) {
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		return Job{}, ErrNotFound
	}
	return (&Store{q: a.db}).Find(r.Context(), id)
}

func (a api) start(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Version int `json:"version"`
	}
	if json.NewDecoder(r.Body).Decode(&in) != nil {
		writeError(w, http.StatusBadRequest, "BAD_REQUEST", "the body is not valid JSON")
		return
	}
	job, err := a.find(r)
	if err != nil {
		writeDomainError(w, err)
		return
	}
	job.Version = in.Version
	err = InTx(r.Context(), a.db, func(tx pgx.Tx) error {
		return (&Store{q: tx}).Start(r.Context(), job)
	})
	if err != nil {
		writeDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

### `internal/events/relay.go`

```go
// Package events publishes the outbox and consumes the published events.
package events

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/twmb/franz-go/pkg/kgo"
)

type Envelope struct {
	EventID     uuid.UUID `json:"event_id"`
	EventType   string    `json:"event_type"`
	AggregateID uuid.UUID `json:"aggregate_id"`
}

// Drain publishes every unpublished outbox row and marks it published. It reads
// ALL rows, whoever wrote them: its tests need a database of their own.
func Drain(ctx context.Context, pool *pgxpool.Pool, client *kgo.Client, topic string) (published int, err error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin: %w", err)
	}
	defer func() {
		if rb := tx.Rollback(ctx); rb != nil && !errors.Is(rb, pgx.ErrTxClosed) {
			err = errors.Join(err, fmt.Errorf("rollback: %w", rb))
		}
	}()
	rows, err := tx.Query(ctx, `SELECT id, event_type, aggregate_id FROM outbox
		 WHERE published_at IS NULL ORDER BY occurred_at FOR UPDATE SKIP LOCKED`)
	if err != nil {
		return 0, fmt.Errorf("read outbox: %w", err)
	}
	pending, err := pgx.CollectRows(rows, pgx.RowToStructByPos[Envelope])
	if err != nil {
		return 0, fmt.Errorf("read outbox: %w", err)
	}
	for _, e := range pending {
		value, err := json.Marshal(e)
		if err != nil {
			return 0, fmt.Errorf("marshal %s: %w", e.EventID, err)
		}
		if err := client.ProduceSync(ctx, &kgo.Record{Topic: topic, Value: value}).FirstErr(); err != nil {
			return 0, fmt.Errorf("publish %s: %w", e.EventID, err)
		}
		if _, err := tx.Exec(ctx, `UPDATE outbox SET published_at = now() WHERE id = $1`, e.EventID); err != nil {
			return 0, fmt.Errorf("mark %s: %w", e.EventID, err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit: %w", err)
	}
	return len(pending), nil
}
```

### `internal/events/consumer.go`

```go
package events

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/twmb/franz-go/pkg/kgo"
)

// Consume sends one reminder per event until ctx ends. Offsets are committed
// only after every record of a batch is stored or dead-lettered. Deliberately
// sequential: go-event-consumer owns the production shape (workers, retries).
func Consume(ctx context.Context, pool *pgxpool.Pool, brokers, group, topic string) error {
	client, err := kgo.NewClient(kgo.SeedBrokers(brokers), kgo.ConsumerGroup(group),
		kgo.ConsumeTopics(topic), kgo.DisableAutoCommit(),
		kgo.ConsumeResetOffset(kgo.NewOffset().AtStart()))
	if err != nil {
		return fmt.Errorf("client: %w", err)
	}
	defer client.Close()
	for {
		fetches := client.PollFetches(ctx)
		if ctx.Err() != nil {
			return nil
		}
		if err := fetches.Err(); err != nil {
			return fmt.Errorf("poll: %w", err)
		}
		for _, record := range fetches.Records() {
			var e Envelope
			if err := json.Unmarshal(record.Value, &e); err != nil || e.EventID == uuid.Nil {
				dead := &kgo.Record{Topic: topic + ".dlq", Value: record.Value,
					Headers: []kgo.RecordHeader{{Key: "x-retry-count", Value: []byte("1")}}}
				if err := client.ProduceSync(ctx, dead).FirstErr(); err != nil {
					return fmt.Errorf("dead-letter: %w", err)
				}
				continue
			}
			if err := handle(ctx, pool, group, e); err != nil {
				if ctx.Err() != nil {
					return nil // stopping: the offset stays uncommitted, so it is redelivered
				}
				return fmt.Errorf("handle %s: %w", e.EventID, err)
			}
		}
		if err := client.CommitUncommittedOffsets(ctx); err != nil {
			return fmt.Errorf("commit offsets: %w", err)
		}
	}
}

// handle records the event and does the work in one transaction.
func handle(ctx context.Context, pool *pgxpool.Pool, consumer string, e Envelope) (err error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin: %w", err)
	}
	defer func() {
		if rb := tx.Rollback(ctx); rb != nil && !errors.Is(rb, pgx.ErrTxClosed) {
			err = errors.Join(err, fmt.Errorf("rollback: %w", rb))
		}
	}()
	tag, err := tx.Exec(ctx, `INSERT INTO processed_events (consumer_name, event_id)
		 VALUES ($1, $2) ON CONFLICT DO NOTHING`, consumer, e.EventID)
	if err != nil {
		return fmt.Errorf("dedup: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return tx.Commit(ctx) // duplicate
	}
	if _, err := tx.Exec(ctx, `INSERT INTO reminders (job_id, sent) VALUES ($1, 1)
		 ON CONFLICT (job_id) DO UPDATE SET sent = reminders.sent + 1`, e.AggregateID); err != nil {
		return fmt.Errorf("reminder: %w", err)
	}
	return tx.Commit(ctx)
}
```

## Tests

Harness (`containers.go`, `await.go`, `kafka.go`) and `internal/test/db/` copied unchanged; `migrations/embed.go` exports `FS`.

### `internal/workshop/main_test.go`

```go
package workshop_test

import (
	"os"
	"testing"

	"example.com/workshop/internal/test"
	"example.com/workshop/migrations"
)

// pg is set by TestMain; it stays nil under -short, where every test skips.
var pg *test.Postgres

func TestMain(m *testing.M) {
	os.Exit(test.RunPostgres(m, migrations.FS, func(p *test.Postgres) { pg = p }))
}
```

### `internal/workshop/store_integration_test.go`

```go
package workshop_test

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"example.com/workshop/internal/test"
	testdb "example.com/workshop/internal/test/db"
	"example.com/workshop/internal/workshop"
	"example.com/workshop/migrations"
)

func booked(bike string) workshop.Job {
	return workshop.Job{ID: uuid.New(), Bike: bike, State: "booked", Version: 1}
}

func TestStoreRefusesAStaleStart(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx := context.Background()
	store := workshop.NewStore(pg.Pool).WithTx(testdb.WithTx(t, pg.Pool))
	job := booked("bike-stale")
	if err := store.Create(ctx, job); err != nil {
		t.Fatalf("Create: %v", err)
	}
	first, err := store.Find(ctx, job.ID)
	if err != nil {
		t.Fatalf("Find: %v", err)
	}
	second := first // a second reader of the same version

	if err := store.Start(ctx, first); err != nil {
		t.Fatalf("first Start: %v", err)
	}
	if err := store.Start(ctx, second); !errors.Is(err, workshop.ErrConflict) {
		t.Errorf("second Start = %v, want ErrConflict", err)
	}
	got, err := store.Find(ctx, job.ID)
	if err != nil || got.State != "started" || got.Version != 2 {
		t.Errorf("Find = %+v, %v; want started, version 2", got, err)
	}
}

// An expected constraint error aborts a PostgreSQL transaction. A savepoint
// (Begin on a pgx.Tx) keeps the test's transaction usable afterwards.
func TestStoreRefusesASecondOpenJobForOneBike(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx := context.Background()
	tx := testdb.WithTx(t, pg.Pool)
	store := workshop.NewStore(pg.Pool).WithTx(tx)
	if err := store.Create(ctx, booked("bike-busy")); err != nil {
		t.Fatalf("Create: %v", err)
	}
	second := booked("bike-busy")

	err := workshop.InTx(ctx, tx, func(sp pgx.Tx) error { return store.WithTx(sp).Create(ctx, second) })
	if !errors.Is(err, workshop.ErrBikeBusy) {
		t.Fatalf("Create = %v, want ErrBikeBusy", err)
	}
	if _, err := store.Find(ctx, second.ID); !errors.Is(err, workshop.ErrNotFound) {
		t.Errorf("Find after refusal = %v, want ErrNotFound", err)
	}
}

// Guard test: what rollback isolation cannot show. Another connection never sees
// the writes, so commit behaviour cannot be proven inside WithTx.
func TestRollbackHidesWritesFromOtherConnections(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx := context.Background()
	job := booked("bike-hidden")
	if err := workshop.NewStore(pg.Pool).WithTx(testdb.WithTx(t, pg.Pool)).Create(ctx, job); err != nil {
		t.Fatalf("Create: %v", err)
	}
	if _, err := workshop.NewStore(pg.Pool).Find(ctx, job.ID); !errors.Is(err, workshop.ErrNotFound) {
		t.Errorf("pool Find = %v, want ErrNotFound", err)
	}
}

// Real commit needed: the subject is that the job and its outbox row commit
// together or not at all. Own database: the test adds a constraint to a table.
func TestBookingCommitsJobAndEventTogether(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx := context.Background()
	pool, _ := pg.NewDatabase(t)
	book := func(job workshop.Job) error {
		return workshop.InTx(ctx, pool, func(tx pgx.Tx) error {
			return workshop.NewStore(pool).WithTx(tx).Create(ctx, job)
		})
	}
	count := func(query string, id uuid.UUID) (n int) {
		t.Helper()
		if err := pool.QueryRow(ctx, query, id).Scan(&n); err != nil {
			t.Fatalf("count: %v", err)
		}
		return n
	}
	const jobs = `SELECT count(*) FROM jobs WHERE id = $1`
	const events = `SELECT count(*) FROM outbox WHERE aggregate_id = $1 AND event_type = 'JobBooked'`

	stored := booked("bike-a")
	if err := book(stored); err != nil {
		t.Fatalf("book: %v", err)
	}
	if j, e := count(jobs, stored.ID), count(events, stored.ID); j != 1 || e != 1 {
		t.Errorf("after commit: %d job, %d event; want 1 and 1", j, e)
	}

	if _, err := pool.Exec(ctx, `ALTER TABLE outbox ADD CONSTRAINT refuse CHECK (false) NOT VALID`); err != nil {
		t.Fatalf("add constraint: %v", err)
	}
	refused := booked("bike-b")
	var pgErr *pgconn.PgError
	if err := book(refused); !errors.As(err, &pgErr) || pgErr.ConstraintName != "refuse" {
		t.Fatalf("book = %v, want the refuse constraint", err)
	}
	if j, e := count(jobs, refused.ID), count(events, refused.ID); j != 0 || e != 0 {
		t.Errorf("after failed event write: %d job, %d event; want 0 and 0", j, e)
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
	tables := func() (n int) {
		t.Helper()
		if err := pool.QueryRow(ctx, `SELECT count(*) FROM information_schema.tables
			WHERE table_schema = 'public' AND table_name <> 'goose_db_version'`).Scan(&n); err != nil {
			t.Fatalf("count tables: %v", err)
		}
		return n
	}
	up := tables()
	if _, err := provider.DownTo(ctx, 0); err != nil {
		t.Fatalf("down: %v", err)
	}
	if n := tables(); n != 0 {
		t.Errorf("%d tables left after down", n)
	}
	if _, err := provider.Up(ctx); err != nil {
		t.Fatalf("up again: %v", err)
	}
	if n := tables(); n != up {
		t.Errorf("%d tables after up again, want %d", n, up)
	}
}
```

### `internal/workshop/api_integration_test.go`

```go
package workshop_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"golang.org/x/time/rate"

	"example.com/workshop/internal/test"
	testdb "example.com/workshop/internal/test/db"
	"example.com/workshop/internal/workshop"
)

// roomy keeps the limiter out of tests that are about something else.
var roomy = workshop.Limits{Rate: rate.Inf, Burst: 1}

// call sends one request through the real router in this goroutine, so a router
// built on the test's transaction stays inside it.
func call(t *testing.T, h http.Handler, method, path, body string, headers ...string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	for i := 0; i+1 < len(headers); i += 2 {
		req.Header.Set(headers[i], headers[i+1])
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func decode[T any](t *testing.T, rec *httptest.ResponseRecorder) (out T) {
	t.Helper()
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatalf("decode %q: %v", rec.Body, err)
	}
	return out
}

func rowsFor(t *testing.T, tx pgx.Tx, bike string) (n int) {
	t.Helper()
	if err := tx.QueryRow(context.Background(), `SELECT count(*) FROM jobs WHERE bike_ref = $1`, bike).Scan(&n); err != nil {
		t.Fatalf("count: %v", err)
	}
	return n
}

func TestAPIRepeatedRequestHasOneEffect(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	tx := testdb.WithTx(t, pg.Pool) // the handler's Begin becomes a savepoint
	h := workshop.NewRouter(tx, roomy)
	key := testdb.ID(t, "key").String()

	first := call(t, h, "POST", "/v2/jobs", `{"bike":"bike-repeat"}`, "Idempotency-Key", key)
	again := call(t, h, "POST", "/v2/jobs", `{"bike":"bike-repeat"}`, "Idempotency-Key", key)
	if first.Code != http.StatusCreated || again.Code != http.StatusCreated {
		t.Fatalf("status %d then %d, want 201 twice", first.Code, again.Code)
	}
	if first.Body.String() != again.Body.String() {
		t.Errorf("replay body %s, want %s", again.Body, first.Body)
	}
	if n := rowsFor(t, tx, "bike-repeat"); n != 1 {
		t.Errorf("%d jobs stored, want 1", n)
	}
	other := call(t, h, "POST", "/v2/jobs", `{"bike":"bike-other"}`, "Idempotency-Key", key)
	if other.Code != http.StatusUnprocessableEntity {
		t.Errorf("same key, other body: %d, want 422", other.Code)
	}
	if n := rowsFor(t, tx, "bike-other"); n != 0 {
		t.Errorf("%d jobs stored for the refused request, want 0", n)
	}
}

// Real commit needed: two requests must be on two connections at the same time.
func TestAPIConcurrentRepeatsHaveOneEffect(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx := context.Background()
	id := testdb.ID(t, "bike") // bike reference and idempotency key of this test
	testdb.Scoped(t, pg.Pool, id,
		`DELETE FROM outbox WHERE aggregate_id IN (SELECT id FROM jobs WHERE bike_ref = $1::text)`,
		`DELETE FROM jobs WHERE bike_ref = $1::text`,
		`DELETE FROM idempotency_keys WHERE key = $1::text`,
	)
	h := workshop.NewRouter(pg.Pool, roomy)
	body := `{"bike":"` + id.String() + `"}`

	const callers = 8
	replies := make([]*httptest.ResponseRecorder, callers)
	var wg sync.WaitGroup
	for i := range replies {
		wg.Go(func() { replies[i] = call(t, h, "POST", "/v2/jobs", body, "Idempotency-Key", id.String()) })
	}
	wg.Wait()

	for _, r := range replies {
		if r.Code != http.StatusCreated || r.Body.String() != replies[0].Body.String() {
			t.Errorf("reply %d %s, want 201 %s", r.Code, r.Body, replies[0].Body)
		}
	}
	var jobs, events int
	if err := pg.Pool.QueryRow(ctx, `SELECT count(*), (SELECT count(*) FROM outbox o
		JOIN jobs j ON j.id = o.aggregate_id WHERE j.bike_ref = $1) FROM jobs WHERE bike_ref = $1`,
		id.String()).Scan(&jobs, &events); err != nil {
		t.Fatalf("count: %v", err)
	}
	if jobs != 1 || events != 1 {
		t.Errorf("%d jobs and %d events, want 1 and 1", jobs, events)
	}
}

func TestAPIRateLimitSends429WithRetryAfter(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	// One token an hour: nothing refills while the test runs.
	h := workshop.NewRouter(testdb.WithTx(t, pg.Pool), workshop.Limits{Rate: rate.Every(time.Hour), Burst: 2})
	path := "/v2/jobs/" + uuid.Nil.String()
	for i := range 2 {
		if r := call(t, h, "GET", path, "", "X-Subject", "ada"); r.Code != http.StatusNotFound {
			t.Fatalf("request %d: %d, want 404", i+1, r.Code)
		}
	}
	refused := call(t, h, "GET", path, "", "X-Subject", "ada")
	if refused.Code != http.StatusTooManyRequests {
		t.Fatalf("third request: %d, want 429", refused.Code)
	}
	wait, err := strconv.Atoi(refused.Header().Get("Retry-After"))
	if err != nil || wait < 3590 || wait > 3600 {
		t.Errorf("Retry-After %q, want about 3600 seconds", refused.Header().Get("Retry-After"))
	}
	if got := decode[map[string]string](t, refused)["code"]; got != "RATE_LIMITED" {
		t.Errorf("code %q, want RATE_LIMITED", got)
	}
	if r := call(t, h, "GET", path, "", "X-Subject", "grace"); r.Code != http.StatusNotFound {
		t.Errorf("another caller: %d, want 404", r.Code)
	}
}

// Workflow: each call depends on the one before it.
func TestAPIBookStartAndDeprecatedRead(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	h := workshop.NewRouter(testdb.WithTx(t, pg.Pool), roomy)
	created := call(t, h, "POST", "/v2/jobs", `{"bike":"bike-flow"}`)
	if created.Code != http.StatusCreated {
		t.Fatalf("book: %d %s", created.Code, created.Body)
	}
	job := decode[workshop.Job](t, created)
	path := "/v2/jobs/" + job.ID.String()
	if r := call(t, h, "POST", path+"/start", `{"version":1}`); r.Code != http.StatusNoContent {
		t.Fatalf("start: %d %s", r.Code, r.Body)
	}
	read := call(t, h, "GET", path, "")
	if got := decode[workshop.Job](t, read); got.State != "started" || got.Version != 2 {
		t.Errorf("read back %+v, want started, version 2", got)
	}
	if read.Header().Get("Deprecation") != "" {
		t.Errorf("v2 must not carry a Deprecation header")
	}
	old := call(t, h, "GET", "/v1/jobs/"+job.ID.String(), "")
	if old.Code != http.StatusOK ||
		old.Header().Get("Deprecation") != workshop.DeprecationV1 ||
		old.Header().Get("Sunset") != workshop.SunsetV1 {
		t.Errorf("v1: %d, headers %v", old.Code, old.Header())
	}
}

// One row per error branch the contract documents.
func TestAPIDocumentedErrors(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	tests := []struct {
		name, method, path, body string
		status                   int
		code                     string
	}{
		{"not JSON", "POST", "/v2/jobs", `{`, 400, "BAD_REQUEST"},
		{"no bike", "POST", "/v2/jobs", `{}`, 422, "VALIDATION_FAILED"},
		{"bike busy", "POST", "/v2/jobs", `{"bike":"bike-taken"}`, 409, "BIKE_BUSY"},
		{"unknown job", "GET", "/v2/jobs/" + uuid.Nil.String(), "", 404, "NOT_FOUND"},
		{"malformed id", "GET", "/v2/jobs/7", "", 404, "NOT_FOUND"},
		{"start, not JSON", "POST", "/v2/jobs/7/start", `{`, 400, "BAD_REQUEST"},
		{"start, unknown job", "POST", "/v2/jobs/7/start", `{"version":1}`, 404, "NOT_FOUND"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			h := workshop.NewRouter(testdb.WithTx(t, pg.Pool), roomy)
			if r := call(t, h, "POST", "/v2/jobs", `{"bike":"bike-taken"}`); r.Code != http.StatusCreated {
				t.Fatalf("arrange: %d %s", r.Code, r.Body)
			}
			got := call(t, h, tc.method, tc.path, tc.body)
			if code := decode[map[string]string](t, got)["code"]; got.Code != tc.status || code != tc.code {
				t.Errorf("%s %s = %d %s, want %d %s", tc.method, tc.path, got.Code, code, tc.status, tc.code)
			}
		})
	}
}

func TestAPIStaleStartIsAVersionConflict(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	h := workshop.NewRouter(testdb.WithTx(t, pg.Pool), roomy)
	job := decode[workshop.Job](t, call(t, h, "POST", "/v2/jobs", `{"bike":"bike-old"}`))
	got := call(t, h, "POST", "/v2/jobs/"+job.ID.String()+"/start", `{"version":9}`)
	if code := decode[map[string]string](t, got)["code"]; got.Code != 409 || code != "VERSION_CONFLICT" {
		t.Errorf("start = %d %s, want 409 VERSION_CONFLICT", got.Code, code)
	}
}

// The real database refuses the statement: the reply must say nothing about it.
func TestAPIDatabaseFailureIsAnOpaque500(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	tx := testdb.WithTx(t, pg.Pool)
	if _, err := tx.Exec(context.Background(), `SELECT 1/0`); err == nil {
		t.Fatal("arrange: the transaction should now be aborted")
	}
	got := call(t, workshop.NewRouter(tx, roomy), "GET", "/v2/jobs/"+uuid.Nil.String(), "")
	want := `{"code":"INTERNAL","message":"an unexpected error occurred"}`
	if got.Code != 500 || got.Body.String() != want {
		t.Errorf("reply %d %s, want 500 %s", got.Code, got.Body, want)
	}
}
```

### `internal/events/main_test.go`

```go
package events_test

import (
	"os"
	"testing"

	"example.com/workshop/internal/test"
	"example.com/workshop/migrations"
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

### `internal/events/events_integration_test.go`

```go
package events_test

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/twmb/franz-go/pkg/kgo"

	"example.com/workshop/internal/events"
	"example.com/workshop/internal/test"
)

// Real commit needed: the relay reads committed rows from its own connection.
// Own database: the relay reads every unpublished row.
func TestDrainPublishesEachOutboxRowOnce(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	t.Cleanup(cancel)
	pool, _ := pg.NewDatabase(t)
	topic := broker.NewTopic(t, "jobs")
	client, err := kgo.NewClient(kgo.SeedBrokers(broker.Brokers))
	if err != nil {
		t.Fatalf("client: %v", err)
	}
	t.Cleanup(client.Close)
	want := events.Envelope{EventID: uuid.New(), EventType: "JobBooked", AggregateID: uuid.New()}
	if _, err := pool.Exec(ctx, `INSERT INTO outbox (id, aggregate_id, event_type) VALUES ($1, $2, $3)`,
		want.EventID, want.AggregateID, want.EventType); err != nil {
		t.Fatalf("seed: %v", err)
	}

	for call, expect := range []int{1, 0} {
		n, err := events.Drain(ctx, pool, client, topic)
		if err != nil || n != expect {
			t.Fatalf("Drain call %d = %d, %v; want %d", call+1, n, err, expect)
		}
	}
	var got events.Envelope
	if err := json.Unmarshal(broker.Read(t, topic, 1, 10*time.Second)[0].Value, &got); err != nil || got != want {
		t.Errorf("published %+v (%v), want %+v", got, err, want)
	}
	ends, err := broker.Admin.ListEndOffsets(ctx, topic)
	if err != nil {
		t.Fatalf("end offsets: %v", err)
	}
	if end, ok := ends.Lookup(topic, 0); !ok || end.Offset != 1 {
		t.Errorf("topic end offset %d, want 1", end.Offset)
	}
}

// startConsumer runs the consumer against its own database and stops it, and
// reports its error, when the test ends.
func startConsumer(t *testing.T, pool *pgxpool.Pool, group, topic string) {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- events.Consume(ctx, pool, broker.Brokers, group, topic) }()
	t.Cleanup(func() {
		cancel()
		select {
		case err := <-done:
			if err != nil {
				t.Errorf("consumer: %v", err)
			}
		case <-time.After(30 * time.Second):
			t.Errorf("consumer did not stop")
		}
	})
}

func sent(t *testing.T, pool *pgxpool.Pool, job uuid.UUID) (n int) {
	t.Helper()
	if err := pool.QueryRow(context.Background(),
		`SELECT coalesce(sum(sent), 0) FROM reminders WHERE job_id = $1`, job).Scan(&n); err != nil {
		t.Fatalf("count reminders: %v", err)
	}
	return n
}

// Real commit needed: the consumer writes on its own connection.
func TestConsumeDoesTheWorkOnceForADuplicate(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	pool, _ := pg.NewDatabase(t)
	topic, group := broker.NewTopic(t, "jobs"), broker.Name("reminders")
	e := events.Envelope{EventID: uuid.New(), EventType: "JobBooked", AggregateID: uuid.New()}
	value, err := json.Marshal(e)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	broker.Publish(t, topic, value)
	broker.Publish(t, topic, value) // the redelivery
	startConsumer(t, pool, group, topic)

	// Offset 2 committed = both records consumed. Only now is "once" meaningful.
	broker.AwaitCommitted(t, group, topic, 2)
	if n := sent(t, pool, e.AggregateID); n != 1 {
		t.Errorf("%d reminders sent, want 1", n)
	}
}

func TestConsumeDeadLettersAPoisonRecordAndCarriesOn(t *testing.T) {
	test.Integration(t)
	t.Parallel()
	pool, _ := pg.NewDatabase(t)
	topic, group := broker.NewTopic(t, "jobs"), broker.Name("reminders")
	dlq := topic + ".dlq"
	if _, err := broker.Admin.CreateTopic(context.Background(), 1, 1, nil, dlq); err != nil {
		t.Fatalf("create %s: %v", dlq, err)
	}
	t.Cleanup(func() {
		if _, err := broker.Admin.DeleteTopic(context.Background(), dlq); err != nil {
			t.Errorf("delete %s: %v", dlq, err)
		}
	})
	good := events.Envelope{EventID: uuid.New(), EventType: "JobBooked", AggregateID: uuid.New()}
	value, err := json.Marshal(good)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	broker.Publish(t, topic, []byte("not json"))
	broker.Publish(t, topic, value)
	startConsumer(t, pool, group, topic)

	broker.AwaitCommitted(t, group, topic, 2)
	dead := broker.Read(t, dlq, 1, 10*time.Second)[0]
	if string(dead.Value) != "not json" {
		t.Errorf("dead-lettered %q, want the original bytes", dead.Value)
	}
	if len(dead.Headers) != 1 || dead.Headers[0].Key != "x-retry-count" || string(dead.Headers[0].Value) != "1" {
		t.Errorf("headers %v, want x-retry-count 1", dead.Headers)
	}
	if n := sent(t, pool, good.AggregateID); n != 1 {
		t.Errorf("%d reminders for the good record, want 1", n)
	}
}
```

## Output

`go test -race -shuffle=on -count=4 ./...` passed in both packages. `go test -short -count=1 ./...` printed `ok` for both with no mention of skips; with `-v` each integration test shows `SKIP`.

## Broken on purpose

Each change was made in a copy, run, and reverted.

| Broken | Observed |
|---|---|
| Deduplication removed | `2 reminders sent, want 1` |
| Booking calls the repository on the pool, not the transaction | `after failed event write: 1 job, 0 event; want 0 and 0` |
| Savepoint removed around the refused insert | `current transaction is aborted ... (SQLSTATE 25P02)` |
| Idempotency claim removed | `status 201 then 409, want 201 twice`; concurrent replies 409 |
| Rate limiter removed | `third request: 404, want 429` |
| A test that commits and does not clean up | The test passes; the package fails: `"public"."jobs": 0 rows before, 1 after` |
| Duplicate counted without waiting for offset 2 (consumer slowed 200 ms) | Passed 3 of 3 with deduplication removed |

## Coverage and open points

| Gate | Result | Where the gaps are |
|---|---|---|
| Statement blocks | 335/438, **FAIL** | 60 blocks in `internal/test/`, 28 in production code |
| Branches (gobco 1.3.4) | 84/214, **FAIL** | Harness, and error branches in `api.go`, `store.go`, `relay.go`, `consumer.go` |

This example is **not finished** against the coverage rule. The production gaps are database, broker and marshalling failure branches: next, add fault cases (an aborted transaction, a closed pool, a deleted topic), delete branches that cannot happen, and list what remains. **For the product owner:** harness exclusions; any production branch proposed as unreachable; the values of the rate limit, key retention and sunset date.

Not run: Ryuk (disabled), CI, more than one service instance (the limiter is per instance).
