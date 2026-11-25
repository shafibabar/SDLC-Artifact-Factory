# Testcontainers for Python Official Documentation and Source
**Authors:** The Testcontainers project (testcontainers/testcontainers-python)
**Domain:** Testing (integration, Python)

Accessed 2026-11-25. Latest 4.15.0, uploaded 2026-07-24, Python >=3.10 (https://pypi.org/pypi/testcontainers/json). Source base: S = https://raw.githubusercontent.com/testcontainers/testcontainers-python/testcontainers-v4.15.0.

## Core Concepts

- Modules ship as extras of one package since 4.0.0; only core follows SemVer, community modules may break in a minor release; database drivers are not installed for you (https://testcontainers-python.readthedocs.io/en/latest/).
- Module path is `testcontainers.community.<name>`. `testcontainers.postgres` is a shim that emits `DeprecationWarning` (S/src/testcontainers/postgres.py). With warnings as errors, old imports would fail (inference).
- `PostgresContainer`: image `postgres:latest`; user, password, database default `test` or the `POSTGRES_*` variables; **driver `psycopg2`**; `get_connection_url(driver=None)` omits the driver; readiness runs `psql` inside the container (S/src/testcontainers/community/postgres/__init__.py).
- `RedpandaContainer` (`testcontainers.community.kafka`): default image `redpanda:v23.1.13`; ports 9092 and 8081; `get_bootstrap_server()`; log wait with a 10 second default start timeout (S/src/testcontainers/community/kafka/_redpanda.py).
- `KafkaContainer`: `confluentinc/cp-kafka:7.6.0`, port 9093, optional `with_kraft()` (S/src/testcontainers/community/kafka/__init__.py).
- Waits: `wait_container_is_ready`, `wait_for`, and string or callable `wait_for_logs` are deprecated; use `waiting_for()` with `LogMessageWaitStrategy` or `HttpWaitStrategy` (S/src/testcontainers/core/waiting_utils.py). The feature page still shows `wait_for_logs` without a notice (S/docs/features/wait_strategies.md).
- Environment: `TC_MAX_TRIES` 120, `TC_POOLING_INTERVAL` 1, `TESTCONTAINERS_RYUK_DISABLED`, `TESTCONTAINERS_RYUK_PRIVILEGED`, `RYUK_CONTAINER_IMAGE`, `TC_HOST` / `TESTCONTAINERS_HOST_OVERRIDE`, `TESTCONTAINERS_CONNECTION_MODE`, `TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE`, `TESTCONTAINERS_HUB_IMAGE_NAME_PREFIX` (S/src/testcontainers/core/config.py).
- Inside a container it needs a Docker client and daemon access (documentation home page).

## Actionable Techniques

- Pin the package and every image tag.
- Use host and mapped-port accessors, never container hostnames; reread them after a restart [unverified that ports change].
- Pass the driver the product uses to `get_connection_url`.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-integration-test, python-chaos-test | W3C-13, 42 | Import paths, defaults, waits |

## Candidate New Skills/Agents

None.

## Key Terminology

Wait Strategy, Ryuk, Mapped Port.

## Caveats

- Nothing was run.
- A Toxiproxy module exists on the `main` branch (https://api.github.com/repos/testcontainers/testcontainers-python/git/trees/main?recursive=1); its path returned 404 at the 4.15.0 tag, so treat it as unreleased [unverified].
- [unverified] Whether `testcontainers[redpanda]` is a declared extra (not seen in the extras list; the class lives in the Kafka module).

## Answers to audit questions

| Question | Answer | Status |
|---|---|---|
| W3C-13: URL uses a driver that must be declared | Default is `psycopg2`; drivers are not bundled | Confirmed |
| W3C-42: dependency list omits `testcontainers[redpanda]` | Extra name not confirmed | [unverified] |
| W3C-42 [GK]: container hostname does not resolve on default bridge; restart changes port | Docker documentation not consulted | [unverified] |
