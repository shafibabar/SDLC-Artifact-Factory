# Containers and CI

Self-contained. Use when setting up or changing the Testcontainers harness, or running integration tests in CI. Run on Go 1.27.4, testcontainers-go v0.45.0, Docker 29.9.3 (Docker Desktop) unless marked otherwise.

## Contents
Lifecycle; images and ports; start and stop; skipping; CI; coverage.

## Lifecycle

`go test` builds one test binary per package, so "shared" containers means shared within one package, started in `TestMain`.

| Choice | Verdict |
|---|---|
| A container per test function | Refused: start-up is paid by every test, and isolation already comes from rollback or an own database |
| One set per package, in `TestMain` | **Standard** |
| One reused across packages | Not used: reuse by name is experimental in Testcontainers |

`TestMain` has no `*testing.T`. Start helpers therefore return errors, and containers are terminated after `m.Run` with `testcontainers.TerminateContainer`. Inside a single test, use `testcontainers.CleanupContainer(t, ctr)`, registered **before** checking the start error, because a container can exist after a failed start.

## Images and ports

- Pin exact tags and match production's major version. The harness pins `postgres:17.12-alpine` and `redpandadata/redpanda:v26.2.7`; check what production runs and change them in one place.
- PostgreSQL: the module has no default wait strategy; use `postgres.BasicWaitStrategies()` (the ready log line twice, then the port). A port check alone can pass during the first, temporary start. Do not name the database `postgres`.
- The module starts PostgreSQL with `fsync=off` (v0.45.0 source): these tests prove nothing about durability after a crash.
- Redpanda: take the address from `KafkaSeedBroker`; the host port is random. The module starts it with `--memory=1G --smp=1`.
- The harness publishes ports on 127.0.0.1 only, because the credentials are fixed test values. Without that setting Docker publishes on every interface.

## Start and stop

- The harness retries a failed **start** up to three times, each attempt with its own deadline, terminating any half-started container and logging each failure. The numbers (3 attempts, 2 minutes each, 40 pool connections) are chosen values, not measurements.
- Ryuk, Testcontainers' cleanup container, removes labelled resources when the test process dies. It is on by default; disable it (`TESTCONTAINERS_RYUK_DISABLED=true`) only where the CI job cleans up itself. The runs for this skill had it disabled, so its behaviour here is unverified. Observed with it disabled: after a panic in a test, the PostgreSQL container was still running.
- A Docker-API runtime is required. A container that cannot start must fail the package: never use `SkipIfProviderIsNotHealthy`. Observed: with `DOCKER_HOST` pointing at nothing, Testcontainers used the default socket and the tests passed, so read the "Resolved Docker Host" line it logs.

## Other stores

The harness covers PostgreSQL and Redpanda only. For MongoDB, a graph extension or another store the product uses, apply the same rules with that engine's container, and report that no template here was run for it.

## Skipping

| Command | What runs |
|---|---|
| `go test -short ./...` | Unit tests; each integration test skips. The harness starts nothing. Output says `ok` and does not mention skips without `-v` |
| `go test -race -shuffle=on ./...` | Everything; needs Docker |

Put `test.Integration(t)` first in every integration test. Do not exit `TestMain` under `-short`: the package's unit tests disappear with it. Do not use a build tag.

## CI

- Integration tests run in `make ci` on every pull request (`go-makefile`, `ci-pipeline`).
- Packages run in parallel by default, each with its own containers: size runners for that, or lower `go test -p`.
- A cold runner pulls images first. Pull them in a step of their own so a pull does not eat the test timeout. `go-makefile`'s `make test` target sets `-timeout=120s`; a slow start can exceed it.
- A test that gives different results on unchanged code is a defect (`test-pyramid`: no retry at this layer). Usual causes here: shared rows, a global reader, a missing wait, the same unique value in parallel tests.
- `t.Parallel` is safe when each test has its own rows, database and topic. Rollback tests each hold a connection until they end, so the pool must be larger than `-parallel` (default GOMAXPROCS); observed: with all connections held, `Begin` waits until its context ends. Bound waits with a context (Cox-Buday: context deadlines).

## Coverage

Integration tests count towards the statement and branch gates, which `go-unit-test` runs on the full suite (a `-short` run gives no verdict). Observed on the three examples:

- Both gates work with this `TestMain` (it calls `os.Exit` explicitly, which gobco needs). The branch gate runs package by package, so containers start again for it.
- The branch gate counts only a package's own tests.
- `internal/test/` is measured like any other code and none of the examples' harness error paths are covered. Code `TestMain` runs after `m.Run` is not recorded. So the gates **fail** until the harness is tested or each file is listed as an exclusion with a reason and approved by the product owner. Pending is not approved; the build stays blocked.
- Error branches in repositories can often be reached honestly with a real database: run a failing statement first in the test's transaction, and the next call returns a real error.
