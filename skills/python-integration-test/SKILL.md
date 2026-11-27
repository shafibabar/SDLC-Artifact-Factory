---
name: python-integration-test
description: >
  Use when backend-engineer, test-strategist or anyone writes, reviews or fixes
  Python integration tests in the Implement phase: testcontainers-python with
  PostgreSQL (asyncpg) or Redpanda (aiokafka), pytest and pytest-asyncio
  conftest fixtures, event loop errors, Alembic migration tests, repository and
  optimistic-concurrency tests, rollback isolation or real commits, row-level
  security, outbox relay, idempotent consumer, redelivery, dead letter queue,
  waiting without asyncio.sleep, flaky or leaking database tests, skipping
  slow tests, and FastAPI behaviour checks through the real app and database:
  Idempotency-Key replay, rate limit 429, Retry-After, Deprecation header,
  documented error responses, multi-call workflows. Produces
  python-integration-test.
version: 2.0.0
phase: implement
owner: test-strategist
created: 2026-07-31
tags: [implement, python, integration-test, testcontainers, postgres, redpanda, asyncpg, aiokafka, alembic, pytest-asyncio, isolation, api-behaviour, ci]
produces: python-integration-test
domain: testing
status: stable
related: [test-pyramid, test-fixture-design, mock-generation, python-unit-test, python-repository-pattern, python-service-layer, python-migration, python-event-publisher, python-event-consumer, python-fastapi-handler, python-middleware, python-makefile, python-contract-test, python-e2e-test, python-mongodb-repository, go-integration-test, multi-tenancy-design, ci-pipeline, security-implementation]
sources:
  - research/testing/testcontainers-python-official-docs.md
  - research/testing/pytest-official-docs.md
  - research/testing/pytest-asyncio-official-docs.md
  - research/testing/python-testing-with-pytest-okken.md
  - research/testing/unit-testing-khorikov.md
  - research/testing/testing-web-apis-winteringham.md
  - research/software-architecture/architecture-patterns-with-python-percival-gregory.md
  - research/devops-and-delivery/continuous-delivery-humble-farley.md
---

# Python Integration Test

## Purpose

This skill owns how Python code is tested against the real dependencies the product controls: the container harness, database and broker tests, migration tests and API behaviour checks. It follows the same policy as `go-integration-test`. `test-strategist` authors the standard; `backend-engineer` applies it. Isolation and test data rules belong to `test-fixture-design`, layers, retries and gates to `test-pyramid`, doubles to `mock-generation`. Your own database is verified by its end state, never by counting calls (Khorikov). A small set of tests of the real adapter sits beside the many unit tests that use fakes (Percival and Gregory).

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off.

| # | Rule | Reason |
|---|---|---|
| P1 | **The real engine, in a throwaway container the test run starts, on a pinned image tag.** No fake, mock driver, substitute engine or shared server | Only the real engine proves SQL, constraints, isolation and delivery. A third-party service outside the product's control is doubled at your own port instead (`mock-generation`) |
| P2 | **Addresses come only from that container**; `DATABASE_URL` and the like are never read | Migrations and cleanup against another database destroy real data |
| P3 | **The schema comes from the real Alembic revisions** | A hand-built schema lets a broken migration ship |
| P4 | **Roll back each test (default).** A real commit only with a named reason written in the test, under keys or a database of its own, cleanup registered before the first write and its errors reported; never `TRUNCATE` or an unfiltered `DELETE` | `test-fixture-design` |
| P5 | **Wait by polling with a deadline, never a fixed sleep. Assert "once" or "nothing happened" only after proof the input was consumed** | Otherwise the test passes before the code has run |
| P6 | **No test retries or reruns.** Only a container *start* is retried, bounded and logged | `test-pyramid`: retries exist at end-to-end only |
| P7 | **Slow tests carry the `integration` marker and are excluded only on the command line** (`-m "not integration"`). A container that cannot start errors the run, never skips. `make ci` runs them all | A setting or a Docker skip drops the proof silently |
| P8 | **API behaviour the contract promises is tested here**, through the real app and database: repeat-request safety, rate limit, deprecation signal, every documented error branch, multi-call workflows | A schema check proves shape, not that it happens (Winteringham) |
| P9 | **The coverage gate of `python-unit-test` applies**: 100% of lines and branches on the full suite. Approved once as classes and listed in every report: `...` placeholder bodies, `if TYPE_CHECKING:` blocks, and test support under `tests/` (outside the measured source; never code that ships). Machine-generated code is excluded; anything else needs approval | `test-pyramid` and the product owner's decision |

Every product size follows all nine. **Lean** means fewer tests and only the containers the product uses (no broker, no broker container), never fakes in place of the database, shared data or skipped checks.

## What every answer states

**Answer only what was asked, as briefly as it allows.** Include an item below only when the question touches it, say it **once, in a sentence or two**, and add no headings, recap, table, extra code or neighbouring topic. An item that applies is said **in words**, even when pointing at the harness or a fixture: "copy the harness" tells the reader nothing about what it does.

1. **Containers** (setting them up or pointing at the harness): the **pinned image tag**; the wait strategy **by name** (`ExecWaitStrategy`, `psql` over TCP, for `PostgresContainer`; `LogMessageWaitStrategy` on `Started Kafka API server` for Redpanda); the **life cycle**: synchronous session fixture, migrations applied, a failed start errors (never skips), stopped in `finally`. Leftover-row check and Ryuk only if cleanup is the question.
2. **Isolation:** rollback is the default and, **in the same breath**, a real commit uses **keys of the test's own with filtered cleanup (`scoped`), or its own database**. For a test that commits, give the reason; the others stay on rollback.
3. **Refused or replaced, by name:** a `FakeRepository`, mock or SQLite is rejected here because **the database is a dependency the application controls, verified by resulting state in the real database**; the fake stays fine in unit tests of other code.
4. **Redelivery and asynchronous tests:** the **real consumer** (not a copy of its handler); the **second delivery observed** (committed offset passes it); **one bounded wait correlated to this test's event id** (the id's record beside the offset; a per-test topic alone is not correlation); end state **filtered by event id**; dead letter topic empty; the break that turns it red (ignore the "already processed" result, keep the SQL).
5. **Code shown:** names declared or their origin named; each test asserts what its name claims; what a helper does unseen (`db` never commits; `scoped` fails on a cleanup error). **Any async fixture shown works as written:** show `asyncio_mode = "auto"` beside it, or decorate it `@pytest_asyncio.fixture` (and mark its tests).
6. **Event loops:** `asyncio_default_fixture_loop_scope` affects async fixtures only, never synchronous ones; `asyncio_default_test_loop_scope` affects tests. A loop mismatch has two valid remedies: run the tests on the session loop **too**, or share no async resource across loops (the harness's choice).
7. **Slow tests:** `-m "not integration"` on the command line for the fast loop (deselected, proving nothing; exit 5 if none remain) **and** `make ci` still runs everything.
8. **Coverage, whenever it comes up**, even in one line: **coverage flags (`--cov...`, `--cov-fail-under`) belong on the full gate command the `make` target runs, never in `addopts` or shared config, because subset runs then fail.** Only if coverage is the question: 100% lines and branches; the harness under `tests/` needs no exclusion, is listed in the report as test support, and shipped code never moves there or imports it.
9. **Only where they arise:** what lean changes; **decisions for the product owner** (exclusions, waivers; an undecided tenancy model, inventing no `tenant_id`; a promised limit with no value; a production change for testability).
10. **Code not executed** is called unverified, in one line.

## What to test here

| Code | Integration proof | Isolation (fixture) |
|---|---|---|
| Repository: queries, constraints, version check | Real SQL, each refusal | Rollback (`db`) |
| Unit of Work and use case, one request at a time | Stored result; nothing stored without commit | Rollback (`one_pool`) |
| State and outbox row commit together | Both stored; a failed event write stores neither | Real commit, own database |
| Two writers or identical requests at once | One effect; the second held, then refused or replayed | Real commit (`pool` + `scoped`, or own database) |
| Outbox relay, consumer, dead letter queue | Published once; duplicate consumed with one effect; poison record parked, next one handled | Real commit, own database and topic |
| Migration | Down, up; previous release's statements on the new schema | Own database |
| API promise (P8) | Real app; status, headers, body, stored effect | Rollback unless requests run at once |
| Tenant isolation, where the design has it | Through the product's code, as the application role | Rollback |
| Pure domain logic | None here: `python-unit-test` | |

## Procedure

1. Read the code, its transaction boundaries, the API contract, event design, tenancy design, migrations, `pyproject.toml` and existing tests. Add tests with each slice built, not all at the end.
2. Pick rows from the table above and rate depth by risk (`test-pyramid`).
3. Copy the harness from `./templates/harness.md` into `tests/integration/` (and `./templates/harness-broker.md` only if there is a broker). Read `./references/containers-and-ci.md` before changing it, its event loops or CI.
4. Write the failing test first from `./templates/test-skeletons.md`, as `tests/integration/<layer>/test_<module>.py` (a path the `tdd-gate` hook accepts).
5. For database tests read `./references/isolation.md`.
6. For a relay, consumer or any later effect read `./references/events-and-async.md`.
7. For migrations read `./references/migrations.md`; for API promises `./references/api-behaviour-checks.md`.
8. See each test fail for the expected reason. For isolation, deduplication and refusal tests, break the code once and confirm red.
9. Run `./scripts/validate-python-integration-tests.sh <project>`, then `pytest` (needs Docker); fix and repeat until clean.
10. Run the coverage gate (`python-unit-test`) on the full suite.
11. Tick `./resources/checklist.md` and answer with the statements above.

Worked and run on Python 3.14.4, PostgreSQL 17.12 and Redpanda 26.2.7: `./examples/01-lean-choir-library.md` (one repository, rollback, migrations), `./examples/02-standard-bike-workshop.md` (outbox, duplicate delivery, dead letters, API checks), `./examples/03-enterprise-parcel-lockers.md` (carriers in one table with row-level security, concurrent claims, expand migration).

## Gotchas

- **An outbox or two-writer test on the rollback connection.** *Reason:* no other connection sees the rows; "not published" assertions pass for nothing. *Instead:* real commit, reason written, scoped keys or own database.
- **Counting right after publishing the duplicate**, or waiting only for the event's record. *Reason:* both passed with deduplication removed when the consumer was slow. *Instead:* wait for the committed offset to pass the duplicate.
- **Removing only `ON CONFLICT` to prove deduplication matters.** *Reason:* the unique key remains, the duplicate errors and is dead-lettered, and the effect count stays right: a test that ignores the dead letter topic passes. *Instead:* ignore the `INSERT 0 0` result so the work runs again, and assert nothing was dead-lettered.
- **A session-scoped asyncpg pool with only the fixture loop scope changed.** *Reason:* the fixture runs on the session loop, the test on its own; synchronous fixtures are untouched by that setting. *Instead:* synchronous session containers and connections per test, or tests on the session loop too.
- **`TestClient` over the test's connection.** *Reason:* it runs the app on another loop. *Instead:* `httpx.AsyncClient` with `ASGITransport`.
- **Calling Alembic from an async test or fixture.** *Reason:* `env.py` calls `asyncio.run`. *Instead:* synchronous test or fixture.
- **Continuing after an expected constraint error.** *Reason:* PostgreSQL aborts the transaction (`25P02`). *Instead:* a savepoint around the failing call.
- **A tenant test that runs its own filtered SQL.** *Reason:* it proves that query, not the product. *Instead:* call the repository as each tenant; test row-level security separately, unfiltered, after `SET LOCAL ROLE`.
- **A relay test in the shared database.** *Reason:* the relay reads every row. *Instead:* `own_pool`.
- **Container defaults.** *Reason:* `postgres:latest`, an old Redpanda with a 10 second start limit, a `psycopg2` URL. *Instead:* the harness's pins and settings.
- **`-m "not integration"` in `addopts`, or `pytest.skip` without Docker.** *Reason:* the proof disappears from every run. *Instead:* the marker on the command line only.
- **Trusting `-m "not integration"` output as a pass.** *Reason:* deselected tests proved nothing. *Instead:* run the full suite before claiming it.
- **Putting product code under `tests/` to leave it out of coverage.** *Reason:* the class covers test support only. *Instead:* keep it under `src/` and test it.

## Output

| File | When to open it |
|---|---|
| `./templates/harness.md` | Setting up `tests/integration/` |
| `./templates/harness-broker.md` | The product has a broker |
| `./templates/test-skeletons.md` | Writing a test file |
| `./references/containers-and-ci.md` | Images, waiting, event loops, markers, CI, coverage |
| `./references/isolation.md` | Any database test |
| `./references/events-and-async.md` | Broker and asynchronous effects |
| `./references/migrations.md` | Testing a schema change |
| `./references/api-behaviour-checks.md` | HTTP promises |
| `./scripts/validate-python-integration-tests.sh` | Before hand-off, after every edit |
| `./resources/checklist.md` | Before answering |

Tests live in `tests/integration/<layer>/` (the `python-project-structure` layout); the harness is `tests/integration/` (`harness.py`, `conftest.py`, `broker.py`), test support only.
