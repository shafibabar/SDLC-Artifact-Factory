---
name: go-integration-test
description: >
  This plugin's integration-test authority for Go — the destination
  go-unit-test's complexity-quadrant heuristic points to for quadrant-2
  (overcomplicated, post-decomposition wiring) and quadrant-3 (controller/
  Humble Object) code once its wiring, not its logic, is what needs checking.
  Covers: the Testcontainers standard (exact PostgreSQL/Redpanda setup
  convention, shared-container-per-package vs fresh-per-test tradeoff and this
  repo's chosen strategy, startup-time budget — references/testcontainers-
  setup-standard.md); the test-isolation standard (transaction-rollback-per-
  test as the default vs schema-reset vs fresh-container, and the real-commit
  exception for tests that verify commit/transaction-boundary behavior itself
  — references/test-isolation-standard.md); the precise unit-vs-integration
  boundary mirroring go-unit-test's quadrants; worked repository, outbox, and
  idempotent-consumer round-trip tests (references/repository-and-event-
  testing.md); the timeout/flakiness standard (container-startup retry with
  backoff, poll-not-sleep for async effects) and CI-execution standard
  (Testcontainers dynamic port allocation, one container pair per test binary,
  t.Parallel() safety once isolation is transaction-based — references/
  timeout-and-ci-execution-standard.md). Authored by the test-strategist;
  applied by the backend-engineer for go-repository-pattern, go-event-
  publisher, and go-event-consumer. Used during Implement.
version: 2.0.0
phase: implement
owner: test-strategist
created: 2026-06-25
tags: [implement, go, integration-test, testcontainers, postgres, redpanda, hermetic, ci]
produces: go-integration-test
domain: testing
status: stable
related: [go-unit-test, go-repository-pattern, go-event-publisher, go-event-consumer, go-migration, test-fixture-design, distributed-tracing-design]
---

# Go Integration Test

## Purpose

Unit tests prove your logic; integration tests prove it works against the
**real** dependency — the SQL actually runs on PostgreSQL, the optimistic-
concurrency CAS actually conflicts, the outbox row actually publishes to
Redpanda, the idempotent consumer actually dedups on redelivery. A mock can't
catch a wrong column name, a broken migration, or a real transaction-isolation
surprise; only the genuine engine can. This skill is authored by the
test-strategist; the backend-engineer applies it for `go-repository-pattern`,
`go-event-publisher`, and `go-event-consumer`. `go-unit-test` decides what
*doesn't* deserve unit-test effort; this skill is where that code lands.

---

## Testcontainers Standard

Every Postgres/Redpanda-dependent test gets its containers from
`internal/test/containers.go`'s shared helpers, waiting on
`postgres.BasicWaitStrategies()` (a port-only wait races `initdb`'s restart) and
running real migrations in setup so a broken migration fails the test, not just
production. **This repo's chosen strategy is one shared container per test
package via `TestMain`, not a fresh container per test function** — a
Postgres/Redpanda pair costs ~1–3s/~3–5s to become ready, which a large suite
cannot pay per test. Container-level isolation is deliberately given up here;
test-level isolation is recovered below. Full setup code, the reuse-vs-fresh
tradeoff table, and the startup-time budget: `references/testcontainers-setup-
standard.md`.

---

## Test-Isolation Standard

**Default: transaction rollback per test.** Wrap each test in a `pool.Begin(ctx)`
transaction, run the repository against it (repositories accept a narrow
`Querier`/`DBTX` interface, not a concrete pool — `go-repository-pattern`), and
roll back in `t.Cleanup`. Nothing is ever committed, so writes are invisible to
every other test and vanish for free — microseconds, not the milliseconds a
schema reset costs or the seconds a fresh container costs.

**The one exception:** a test whose subject *is* commit/transaction-boundary
behavior itself (an outbox atomicity test, a real concurrent-commit test)
cannot use an uncommitted wrapper — there is nothing for a second transaction or
the outbox relay's polling query to observe. These use a savepoint-based nested
transaction or, more commonly in this repo, real commits scoped to a unique
`freshTenant(t, pool)` id with `t.Cleanup` deleting only that tenant's rows.
Full strategy comparison table and the exception in detail: `references/test-
isolation-standard.md`.

---

## What Belongs in an Integration Test vs. a Unit Test

This mirrors `go-unit-test`'s complexity quadrants (domain complexity ×
collaborator count) from the integration side:

| Quadrant | Verdict here |
|---|---|
| 1 — Domain logic (high complexity, few collaborators) | Never integration-tested — `go-domain-model`'s Aggregates get thorough unit coverage; a real database adds cost with no signal a fake didn't already give |
| 2 — Overcomplicated (high complexity, many collaborators) | After decomposition pulls the complex logic into quadrant 1, the *wiring left behind* gets integration coverage here — proving the pieces connect correctly, not re-proving logic already unit-tested |
| 3 — Controllers/Humble Objects (low complexity, many collaborators) | **This skill's core territory.** A repository (`go-repository-pattern`), an event consumer's transport shell (`go-event-consumer`), a thin chi handler — correctness lives in real SQL/broker semantics a mock can't verify, so integration tests replace unit tests here rather than supplement them |
| 4 — Trivial (low complexity, few collaborators) | No test of either kind, usually — a getter or simple mapper doesn't earn integration cost any more than unit cost |

The repository is the clearest quadrant-3 instance: `go-repository-pattern`
names it a Humble Object explicitly and states its correctness is "verified by
integration tests against a real database, not unit tests with a mocked
driver" — this skill is that promise delivered. Worked repository, outbox, and
idempotent-consumer round-trip tests: `references/repository-and-event-
testing.md`.

---

## Hermetic Seeding and Trace Correlation

Every test seeds exactly the data it needs and relies on `t.Cleanup` for
removal — reading data a test didn't create is a bug, not ambient convenience.
Inject a unique test id into context/headers so a failure's activity is
traceable through OpenTelemetry spans (`distributed-tracing-design`) without a
debugger. Both worked in full: `references/repository-and-event-testing.md`.

---

## Timeout, Flakiness, and CI-Execution Standard

Container startup gets retried (3 attempts, exponential backoff) inside a
bounded 30s timeout — a failed container start is almost always environment
flakiness, not a real failure, and should not silently retry the test itself.
Every wait for an async effect (relay publish, consumer processing) polls with
a deadline; `time.Sleep` never appears. In CI, Testcontainers' dynamic port
allocation makes parallel packages collision-free with no manual coordination,
one container pair serves an entire test binary (not one pair per test), and
`t.Parallel()` is safe at the test-function level once isolation is
transaction-based. Full retry code, poll pattern, and the local-vs-CI
difference table: `references/timeout-and-ci-execution-standard.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Real dependencies | Testcontainers PostgreSQL/Redpanda | Mocked DB/broker called an "integration" test |
| Migrations verified | Real migrations run in setup (`go-migration`) | Schema hand-created, bypassing migrations |
| Container strategy | Shared per package via `TestMain` | Fresh container per test function |
| Isolation strategy | Transaction rollback per test (or documented real-commit exception) | Tests sharing/leaking committed data |
| Quadrant-appropriate | Quadrant-3 Humble Objects get integration coverage, not forced unit mocks | Repository/handler unit-tested with a mocked driver |
| Concurrency proven | Optimistic-concurrency conflict actually tested | CAS assumed, never exercised |
| Idempotency proven | Duplicate delivery tested against real broker | Dedup assumed, not verified |
| Startup hardened | Retry + bounded timeout on container start | Bare container start, no retry, unbounded wait |
| No sleeps | Async effects polled with a deadline | `time.Sleep` waiting for relay/consumer |
| CI-portable & tagged | Docker-only; `-short` skips them; parallel-safe | Depends on an external shared DB or fixed ports |

---

## Anti-Patterns

- **Mocking the database in an "integration" test** — the whole point is the
  real SQL, real constraints, real transaction semantics; with a mock it is a
  mislabeled unit test.
- **One container per test function** — startup cost dominates runtime; share a
  container per package via `TestMain` and isolate at the test level instead.
- **Hand-creating schema in test setup** — bypasses migrations, so a broken
  migration ships green; always apply the real migration chain.
- **Using the transaction-rollback default for a commit-behavior test** — an
  outbox atomicity or real-concurrency test needs an actual commit; use the
  savepoint or tenant-scoped-commit exception instead.
- **`time.Sleep` to "wait for" the outbox relay or consumer** — poll with a
  deadline so the test is fast when the system is fast and fails with a message
  when it is not.
- **Fixed host-port container mappings** — defeats Testcontainers' dynamic
  allocation and reintroduces the port collisions parallel CI relies on it to
  avoid.
- **Forcing quadrant-3 Humble Objects through unit tests with a mocked driver**
  — tests the mock's behavior, not the repository's; verify against the real
  engine instead.

---

## Output Format

Produces integration test files and the container harness:

```
internal/infrastructure/postgres/*_integration_test.go
internal/handlers/events/*_integration_test.go
internal/test/containers.go            (StartPostgres, StartRedpanda, withTx helpers)
```
