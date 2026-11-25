# Testcontainers for Go Official Documentation
**Authors:** Testcontainers project (golang.testcontainers.org); pgx note from jackc/pgx
**Domain:** Testing (integration)

Accessed 2026-11-25. Latest release v0.45.0, 2026-11-05 (https://api.github.com/repos/testcontainers/testcontainers-go/releases/latest); it has breaking changes moving some client adapters into examples modules (https://github.com/testcontainers/testcontainers-go/releases).

## Core Concepts

- `testcontainers.Run(ctx, image, customizers...)` is the recommended start. Register cleanup **before** checking the error, because a container can exist after a failed start: `CleanupContainer(t, ctr)` in tests, `TerminateContainer` with `defer` elsewhere. (https://golang.testcontainers.org/features/creating_container/)
- `ParallelContainers` starts several; reuse by name is experimental. (same page)
- **Postgres:** `postgres.Run`; no default wait strategy, use `BasicWaitStrategies()` (log line twice plus listening port). `Snapshot`/`Restore` reset state between tests; do not use the `postgres` database name; `WithSQLDriver("pgx")` avoids the slower exec fallback. (https://golang.testcontainers.org/modules/postgres/)
- **Redpanda:** `redpanda.Run`, `KafkaSeedBroker(ctx)`, options such as `WithAutoCreateTopics`; documented example image `docker.redpanda.com/redpandadata/redpanda:v23.3.3`; `RunContainer` is deprecated. (https://golang.testcontainers.org/modules/redpanda/)
- **Ryuk** removes labelled resources; disable only in CI with its own cleanup (`TESTCONTAINERS_RYUK_DISABLED`). (https://golang.testcontainers.org/features/garbage_collector/)
- Needs a Docker-API runtime; tested on Docker for Linux and Docker Desktop, other setups not actively tested. (https://golang.testcontainers.org/system_requirements/docker/) Tested against the two latest Go releases. (https://golang.testcontainers.org/system_requirements/)
- **pgxpool (v5.13.0 page):** no `AcquireTimeout` field; bound acquisition with the context. `HealthCheckPeriod` defaults to 1 minute. (https://pkg.go.dev/github.com/jackc/pgx/v5/pgxpool; https://raw.githubusercontent.com/jackc/pgx/master/pgxpool/pool.go)

## Actionable Techniques

- Write start helpers that return errors, so `TestMain` needs no `*testing.T`; terminate after `m.Run` (design inference).
- Skip per test with `t.Skip` under `testing.Short()` (https://pkg.go.dev/testing).
- Pin image tags.
- Bound pool acquisition with `context.WithTimeout`.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| go-integration-test | W3B-26, 29, 30 | Cleanup order, wait strategies, snapshot |
| go-chaos-test | W3B-45 | pgxpool facts |

## Candidate New Skills/Agents

None.

## Key Terminology

Wait Strategy, Reaper (Ryuk), Container Customizer, Snapshot.

## Caveats

- Documentation pages are unversioned.
- [unverified] Startup time budgets; GitHub-hosted runner specifics; which Redpanda tag is current.

## Answers to audit questions

| Question (batch ID) | Answer | Status |
|---|---|---|
| W3B-45: pgxpool has no "AcquireTimeout" setting | Correct | Confirmed |
| W3B-45: HealthCheckPeriod default 1 minute | Correct | Confirmed |
| W3B-26: helpers needing a real `*testing.T` | `CleanupContainer` takes `t`; `Run` plus `TerminateContainer` works without | Confirmed from docs; skill code not compiled |
| go-integration-test: Docker availability | Docker-API runtime required | Confirmed |
