---
name: go-integration-test
description: >
  Use when backend-engineer, test-strategist or anyone writes, reviews or fixes
  Go integration tests in the Implement phase: Testcontainers for Go with
  PostgreSQL (pgx) or Redpanda, TestMain, -short, goose migration tests,
  repository and optimistic-concurrency tests, rollback isolation or real
  commits, row-level security, outbox relay, idempotent consumer, redelivery,
  dead letter queue, waiting for async effects without time.Sleep, flaky or
  leaking database tests, and API behaviour checks through the real router:
  Idempotency-Key replay, rate limit 429, Retry-After, Deprecation header,
  documented error responses, multi-call workflows. Produces
  go-integration-test.
version: 3.0.0
phase: implement
owner: test-strategist
created: 2026-06-25
tags: [implement, go, integration-test, testcontainers, postgres, redpanda, migrations, isolation, api-behaviour, ci]
produces: go-integration-test
domain: testing
status: stable
related: [test-pyramid, test-fixture-design, mock-generation, go-unit-test, go-repository-pattern, go-migration, go-event-publisher, go-event-consumer, go-chi-handler, go-middleware, go-service-layer, api-contract-design, go-contract-test, go-e2e-test, go-chaos-test, go-makefile, multi-tenancy-design, distributed-tracing-design]
sources:
  - research/testing/testcontainers-go-official-docs.md
  - research/testing/unit-testing-khorikov.md
  - research/testing/testing-web-apis-winteringham.md
  - research/testing/go-toolchain-official-docs.md
  - research/testing/go-coverage-official-docs.md
  - research/testing/software-testing-craftsman-jorgensen.md
  - research/software-architecture/concurrency-in-go-cox-buday.md
  - research/devops-and-delivery/continuous-delivery-humble-farley.md
---

# Go Integration Test

## Purpose

This skill owns how Go code is tested against the real dependencies the product controls: the container harness, database and broker tests, migration tests and API behaviour checks. `test-strategist` authors the standard; `backend-engineer` applies it. Isolation and test data rules belong to `test-fixture-design`, layers, retries and gates to `test-pyramid`, doubles to `mock-generation`. Your own database is verified by its end state, never by counting calls (Khorikov).

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off.

| # | Rule | Reason |
|---|---|---|
| I1 | **The real engine, in a throwaway container the test run starts, on a pinned image tag.** No mock driver, substitute engine or shared server | Only the real engine proves SQL, constraints, isolation and delivery. A third-party service outside the product's control is doubled at your own port instead (`mock-generation`) |
| I2 | **Addresses come only from that container**; `DATABASE_URL` and the like are never read | Migrations and cleanup against another database destroy real data |
| I3 | **The schema comes from the real migrations**, applied by the tool deployment uses | A hand-built schema lets a broken migration ship |
| I4 | **Roll back each test (default).** A real commit only with a named reason written in the test, under keys or a database of its own, cleanup registered first and its errors reported; never `TRUNCATE` or an unfiltered `DELETE` | `test-fixture-design` |
| I5 | **Wait by polling with a deadline, never `time.Sleep`. Assert "once" or "nothing happened" only after proof the input was consumed** | Otherwise the test passes before the code has run |
| I6 | **No test retries.** Only a container *start* is retried, bounded and logged | `test-pyramid`: retries exist at end-to-end only |
| I7 | **`-short` skips each integration test with `t.Skip`**; no `os.Exit` skip in `TestMain`, no build tag. A container that cannot start fails the run. Integration tests stay in `make ci` | An exit hides unit tests too; a tag or a Docker skip drops the proof silently |
| I8 | **API behaviour the contract promises is tested here**, through the real router and database: repeat-request safety, rate limit, deprecation signal, every documented error branch, multi-call workflows | A schema check proves shape, not that it happens (Winteringham) |
| I9 | **The coverage gates of `go-unit-test` apply**: 100% statement blocks and branches. Excluded without per-file approval: generated code, and test support in the module's `internal/test/` (approved once as a class, listed in every report, never code that ships) | The gates fail when non-test code imports `internal/test/`; any other exclusion needs approval |

Every product size follows all nine. **Lean** means fewer tests and only the containers the product uses (no broker, no broker container), never mocks in place of the database, shared data or skipped checks.

## What every answer states

**Keep it short.** Answer what was asked and state only the items below that it touches. Add no coverage, validator or harness material the request did not ask about, beyond one line where it bears on the question. An item that applies is said **in words**, even when pointing at the harness or an example: "copy the harness unchanged" tells the reader nothing about what it does.

1. **Containers**, whenever the answer sets them up or points at the harness: the **pinned image tag**; the wait strategy **by name**, `postgres.BasicWaitStrategies()` (or the readiness log line plus the listening port); and the life cycle: a start step that **returns an error**, so `TestMain` needs no `*testing.T`, with termination **after `m.Run`** (inside a single test: `testcontainers.CleanupContainer` registered **before** the error check).
2. **Isolation.** Whenever rollback is named as the default, name **in the same breath** what a test needing a real commit uses: **data scoped to the test** with filtered cleanup (or a database of its own). Testcontainers' snapshot/restore resets the whole database, so it is only for a database no other test is using. For a test that commits, give the reason and say every other database test stays on rollback.
3. **What is refused or replaced, by name, with the reason** and the compliant version. A fake or mock database proposed for these tests is rejected because **the database is a dependency the application controls, and the repository is verified by the resulting state in the real database**; a fake stays fine in unit tests of other code.
4. **Redelivery and other asynchronous tests:** name the **real consumer under test** (not a copy of its handler); show how the **second delivery is observed** (the committed offset passes it); **wait with a bound**; assert the end state **filtered by event id**; name the broken code that turns the test red.
5. **Helpers the answer relies on:** what they do that the reader cannot see (`TestMain` fails on leftover rows; `WithTx` never commits; `Scoped` fails the test on a cleanup error; `go test -short` prints `ok` while skipping).
6. **Sketches:** every name declared or its origin named; each test asserts what its name claims; cleanup errors reported.
7. **Coverage, only when the request is about it** (otherwise at most one line): both gates, 100%; `internal/test/` is left out as the approved test-support class, listed in every report, never code that ships (the gates fail if non-test code imports it or it holds `package main`; nested modules and copied logic nothing imports go unnoticed); every other exclusion has a reason, is pending until the product owner approves it, and blocks the build meanwhile.
8. **Only where they arise:** what lean changes and what it does not; decisions for the product owner (exclusions and waivers; an undecided tenancy model, inventing no `tenant_id`; a promised limit or deprecation with no value; a production change needed for testability).
9. **One line on what was run.** Code not executed is called unverified.

## What to test here

| Code | Integration proof | Isolation |
|---|---|---|
| Repository: queries, constraints, version check | Real SQL, each refusal | Rollback |
| State and outbox row commit together | Both stored; a failed event write stores neither | Real commit |
| Two writers or two identical requests at once | One effect; the second held, then refused or replayed | Real commit |
| Outbox relay, consumer, dead letter queue | Published once; duplicate consumed with one effect; poison record parked, next one handled | Real commit, own database and topic |
| Migration | Up, down, up; previous release's statements on the new schema | Own database |
| API promise (I8) | Real router; status, headers, body, stored effect | Rollback unless requests run at once |
| Row-level security, where the tenancy design has it | Another tenant denied, as the application role | Rollback |
| Pure domain logic | None here: `go-unit-test` | |

## Procedure

1. Read the code, its transaction boundaries, the API contract, event design, tenancy design, migrations, `go.mod` and existing tests. Add tests with each slice built, not all at the end.
2. Pick rows from the table above and rate depth by risk (`test-pyramid`).
3. Copy the harness from `./templates/harness.md` into `internal/test/` (and `./templates/harness-broker.md` only if there is a broker); copy `db/tx.go` and `db/scope.go` from `test-fixture-design`. Read `./references/containers-and-ci.md` before changing the harness or CI.
4. Write the failing test first from `./templates/test-skeletons.md`, as `<implementation>_integration_test.go` (the `tdd-gate` hook accepts it, and exempts `internal/test/`).
5. For database tests read `./references/isolation.md`.
6. For relay, consumer or any later effect read `./references/events-and-async.md`.
7. For migrations read `./references/migrations.md`; for API promises `./references/api-behaviour-checks.md`.
8. See each test fail for the expected reason. For isolation, deduplication and refusal tests, break the code once and confirm red (deduplication: keep the SQL and ignore its "already processed" result).
9. Run `./scripts/validate-go-integration-tests.sh <paths>`, then `go test -race -shuffle=on ./...` (needs Docker); fix and repeat until clean.
10. Run both coverage gates (`go-unit-test`) on the full suite.
11. Tick `./resources/checklist.md` and answer with the statements above.

Worked and run on Go 1.27.4, PostgreSQL 17.12 and Redpanda 26.2.7: `./examples/01-lean-choir-library.md` (one repository, rollback, migrations), `./examples/02-standard-bike-workshop.md` (outbox, duplicate delivery, dead letters, API checks), `./examples/03-enterprise-parcel-lockers.md` (carriers in one database with row-level security, concurrent claims, expand migration).

## Gotchas

- **An outbox or two-writer test inside the rollback transaction.** *Reason:* no other connection sees the rows; "not published" assertions pass for nothing. *Instead:* real commit, reason written, scoped data or own database.
- **Counting right after publishing the duplicate.** *Reason:* it passed with deduplication removed when the consumer was slow. *Instead:* wait until the committed offset passes the duplicate.
- **A relay test in the shared database.** *Reason:* the relay reads every row, including other tests'. *Instead:* `NewDatabase`.
- **Continuing after an expected constraint error.** *Reason:* PostgreSQL aborts the transaction (`25P02`). *Instead:* run the failing statement in a savepoint (`tx.Begin`).
- **Row-level security tested as the container's user.** *Reason:* a superuser bypasses it. *Instead:* `SET LOCAL ROLE` to the application role.
- **Calling `Save` on the pool in a test.** *Reason:* state commits without its event. *Instead:* bind with `WithTx`.
- **Removing only `ON CONFLICT` to prove deduplication matters.** *Reason:* the unique key remains, so the second insert errors (`23505`) and no duplicate effect appears. *Instead:* ignore the zero-rows result so the work runs again.
- **`testing.Short()` in `TestMain` before `flag.Parse`.** *Reason:* it panics. *Instead:* `flag.Parse()` first, as the harness's `Short` does.
- **`TestMain` that exits under `-short`.** *Reason:* every test in the package vanishes. *Instead:* `test.Integration(t)` in each integration test.
- **Trusting a wrong `DOCKER_HOST` to fail.** *Reason:* in the run for this skill, Testcontainers fell back to the default socket. *Instead:* check the Docker host it logs.
- **A panic or `-timeout` with Ryuk disabled.** *Reason:* `TestMain`'s cleanup never runs and the container stays. *Instead:* keep Ryuk, or remove containers in the CI job.
- **Putting product code in `internal/test/` to lift it out of coverage.** *Reason:* the class covers test support only. *Instead:* keep shipped code outside and test it.
- **A build tag to keep these tests out of the fast run.** *Reason:* they leave `make ci` and the gates. *Instead:* `-short`.
- **`t.Parallel` tests inserting the same unique value.** *Reason:* the second blocks until the first rolls back. *Instead:* distinct values per test.

## Output

| File | When to open it |
|---|---|
| `./templates/harness.md` | Setting up `internal/test/` |
| `./templates/harness-broker.md` | The product has a broker |
| `./templates/test-skeletons.md` | Writing a test file |
| `./references/containers-and-ci.md` | Images, lifecycle, `-short`, CI, coverage |
| `./references/isolation.md` | Any database test |
| `./references/events-and-async.md` | Broker and asynchronous effects |
| `./references/migrations.md` | Testing a schema change |
| `./references/api-behaviour-checks.md` | HTTP promises |
| `./scripts/validate-go-integration-tests.sh` | Before hand-off, after every edit |
| `./resources/checklist.md` | Before answering |

Tests sit beside the code (`internal/<package>/*_integration_test.go`, one `main_test.go` per package that needs containers); the harness is `internal/test/` (test support only).
