---
name: test-fixture-design
description: >
  Use when test-strategist, backend-engineer or anyone writes, reviews or fixes
  test fixtures or test data: how database tests are isolated (transaction
  rollback or committed data), test data builders, factory fixtures, Object
  Mothers, seed data, setup and teardown (t.Cleanup, pytest yield fixtures),
  TRUNCATE between tests, parallel or order-dependent flaky tests, outbox or
  concurrent-commit tests, fixed clocks, IDs and random seeds, golden files and
  -update, stored old event fixtures, tenant-scoped test data, or test data in
  a shared, staging or production database. Go and Python.
version: 3.0.0
phase: implement
owner: test-strategist
created: 2026-06-25
tags: [implement, go, python, fixtures, test-data, hermetic, isolation, builder, object-mother, golden-files, seeding, cleanup]
produces: go-test-fixtures
domain: testing
status: stable
related: [test-pyramid, go-unit-test, go-integration-test, go-contract-test, go-e2e-test, python-unit-test, python-integration-test, python-e2e-test, mock-generation, multi-tenancy-design]
sources:
  - research/testing/unit-testing-khorikov.md
  - research/testing/python-testing-with-pytest-okken.md
  - research/testing/testing-web-apis-winteringham.md
  - research/software-architecture/pragmatic-programmer-hunt-thomas.md
  - research/domain-driven-design/versioning-event-sourced-system-young.md
  - research/testing/testcontainers-go-official-docs.md
  - research/testing/go-toolchain-official-docs.md
---

# Test Fixture Design

## Purpose

This skill owns how test data is built, isolated and removed, for every layer and both backend languages. Containers and runner settings belong to `go-integration-test` and `python-integration-test`; test doubles to `mock-generation`; retries, quarantine and gates to `test-pyramid`. A test that works only because of data it did not set up is programming by coincidence (Hunt and Thomas).

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off.

| # | Rule | Reason |
|---|---|---|
| F1 | **Each test creates, owns and removes its data.** It never reads data it did not create, and no live data object is shared between tests | Shared fixture state couples tests (Khorikov); results then depend on order and leftovers |
| F2 | **Database tests roll back each test** (the default) | Nothing is committed, so no other test can see the writes and there is nothing to delete |
| F3 | **Scoped data only when a real commit is needed**, with the reason written in the test. Then the test commits under keys only it uses and deletes exactly those | A wrapping transaction hides uncommitted rows from other connections and cannot show commit behaviour |
| F4 | **Cleanup is registered when the resource is created** (`t.Cleanup`, pytest `yield`), runs on failure too, and reports its own errors | A leak appears exactly when a test fails; an ignored error becomes another test's mystery |
| F5 | **No reset of shared tables in a test's setup or cleanup** (`TRUNCATE`, unfiltered `DELETE`, schema drop) | It destroys the rows of tests running in parallel |
| F6 | **Time, IDs and randomness are controlled**: injected clock, fixed or test-derived IDs, seeded generator | A value that differs per run makes a failure unrepeatable |
| F7 | **Fixtures reach only a throwaway database**, addressed by what the test run itself started; any other address is refused | Migrations and cleanup against a developer, staging or production database destroy real data |
| F8 | **A golden file changes only after its diff has been read** and the behaviour change is intended | Regenerating to turn a failure green approves a change nobody looked at |

Every product size follows all eight (`test-pyramid` plans every layer at every size). **Lean** means fewer fixtures: literals in unit tests, one rollback fixture, a builder only once construction repeats. It never means shared seed data, skipped cleanup or a shared database.

## What every answer states

State these in a reply as well as in code; code that follows a rule silently leaves the reader free to undo it.

1. **Isolation chosen:** rollback, or scoped data with the named reason a real commit is needed.
2. **What is replaced or refused**, by name, with the rule's reason: e.g. "the `TRUNCATE` in cleanup is removed because parallel tests lose their rows". If asked to skip a rule, give the compliant version and the reason; no switch, "override" or "just this once".
3. **How it applies at this size**, saying that lean changes the number of fixtures, not the rules.
4. **Decisions for the product owner**, when they arise: a tenancy model not yet decided (`multi-tenancy-design` has no default); a wish to use production-derived data (no rule here permits or covers it, so ask); a golden-file diff that changes behaviour; a rule that cannot be met with the current code (for example a repository that only accepts a pool).
5. **What was run.** Code not executed is called unverified.

## Which fixture, which isolation

| Situation | Fixture | Isolation |
|---|---|---|
| Unit test (no real I/O) | Small inline literals, one per case (`go-unit-test`, `python-unit-test`) | Nothing to clean |
| The same type built in many tests, differing in a few fields | Test data builder or pytest factory fixture | As the layer requires |
| One named configuration recurs and its details are not under test | Object Mother (a function returning a complete, named object) | As the layer requires |
| Database test, one connection | Builder plus rollback fixture | Roll back (F2) |
| Code under test opens its own transaction | Same; its transaction becomes a savepoint inside the test's, if production code needs no change | Roll back |
| Subject **is** commit behaviour (state and outbox row commit together; two concurrent writers) | Seed helper plus scoped cleanup | Scoped data (F3) |
| Another connection or process must see the data (running server, relay, worker, contract provider state, end-to-end) | Seed helper; `go-contract-test`, `go-e2e-test`, `python-e2e-test` own their seeding | Scoped data (F3) |
| Broker | A topic and consumer group of the test's own | A published message cannot be rolled back |

A **seed helper** writes to a database; it is not an Object Mother, which only constructs.

**The scope key comes from the product's tenancy design** (`multi-tenancy-design`). Pooled: a tenant ID of the test's own on every row. Schema per tenant: a schema of the test's own. Database per tenant: the throwaway database standing for that tenant, plus the test's own row IDs. Single tenant: the test's own aggregate IDs; invent no `tenant_id`. Isolation tests between tenants seed two and prove neither sees the other.

## Procedure

1. Read the code under test, its transaction boundaries, the tenancy design and existing fixtures. Pick the stack from the service's language.
2. For each test, choose the row above. For anything touching a database, broker or running process, read `./references/isolation-and-cleanup.md` first.
3. For builders, mothers, clocks, IDs or seeds, read `./references/builders-and-determinism.md`. For large expected output or stored events, read `./references/golden-and-event-fixtures.md`.
4. Copy the helpers needed from `./templates/go-fixtures.md` or `./templates/python-fixtures.md`. Put shared Go helpers under `internal/test/`, golden files under `testdata/`, Python fixtures under `tests/`. Create files with Write.
5. If an existing suite is being moved to a different isolation, list each test with its current and new isolation and reason, check the list against F1 to F8, then change them.
6. Run `./scripts/validate-test-fixtures.sh <test paths>`; fix every FAIL, judge every WARN, re-run until clean.
7. Run the tests, then again in another order (Go: `go test -shuffle=on`) and in parallel where the suite does so. An order-dependent failure is fixed in the fixture, not retried (`test-pyramid`).
8. Tick `./resources/checklist.md` and answer with the five statements above.

Worked cases: `./examples/01-lean-tool-library.md` (one Python service, single tenant, run), `./examples/02-standard-ticket-refunds.md` (Go, PostgreSQL, outbox real commit, golden file), `./examples/03-enterprise-insurance-claims.md` (pooled and siloed tenants, old event versions, parallel shards).

## Gotchas

- whenever a test commits data: that a **cleanup failure is reported** (it fails or logs on the test, never an ignored error), and show that in the sketch;
- **Wrapping an outbox or concurrent-writer test in the rollback transaction.** The second connection sees nothing, so it fails or, if it asserts absence, passes for nothing. Use scoped data and say why.
- **Reaching for scoped data "to be safe", or because the tenant ID is there.** Rollback is the default; a real commit needs a named reason.
- **Scoped keys and a process that reads every row.** A relay or batch job picks up other tests' rows. Filter it to the test's keys or give that test a schema or database of its own.
- **Cleanup that lists one table.** Every table the test or the code under test wrote under the scope, children first.
- **`defer` inside a Go helper.** It runs when the helper returns, while the test still needs the resource; use `t.Cleanup`.
- **Registering cleanup after the seeding.** A failure half-way leaves rows behind; register first.
- **Random IDs as builder defaults.** Default to fixed values; derive per-test IDs from the test name where committed rows must not collide.
- **A "mother" named for a state it never sets.** `MakeArchivedAsset` that only raises a version number tests nothing; set the real lifecycle state through the domain's own behaviour and assert the precondition.
- **`DATABASE_URL` winning over the container address.** A migration step may read it by itself; pass the throwaway address explicitly and refuse others.
- **Regenerating old event fixtures from current code.** They then prove only that today's code reads today's shape.

## Output

| File | When to open it |
|---|---|
| `./references/isolation-and-cleanup.md` | Any database, broker or process-spanning test |
| `./references/builders-and-determinism.md` | Builders, mothers, clock, IDs, randomness |
| `./references/golden-and-event-fixtures.md` | Golden files, stored events, message fixtures |
| `./templates/go-fixtures.md` | Writing Go helpers |
| `./templates/python-fixtures.md` | Writing pytest fixtures |
| `./scripts/validate-test-fixtures.sh` | Before hand-off and after every edit |
| `./resources/checklist.md` | After the script passes |
