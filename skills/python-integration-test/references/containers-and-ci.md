# Containers, Event Loops and CI

Self-contained. Use when setting up or changing the testcontainers-python harness, chasing an event-loop error, or running integration tests in CI. Behaviour marked "seen" was run on Python 3.14.4, testcontainers 4.15.0, pytest 9.2.0, pytest-asyncio 1.5.0, Docker 29.9.3 (Docker Desktop); anything else says so. Library facts also come from the testcontainers-python, pytest and pytest-asyncio documentation; marking slow tests and selecting with `-m` follows Okken.

## Contents
Lifecycle; images and ports; waiting; start failures and cleanup; event loops; excluding slow tests; parallel runs; CI; coverage.

## Lifecycle

A session fixture lives for one test process. Containers start only when a selected test asks for one.

| Choice | Verdict |
|---|---|
| A container per test | Refused: start-up is paid by every test, and isolation already comes from rollback or an own database |
| One PostgreSQL (and one broker, if used) per process, session-scoped, synchronous | **Standard** |
| A long-running shared server, a compose stack, a CI service container | Refused: the test run did not start it, so its data and address are not the run's own |
| Reuse across runs | Not used |

The fixture yields inside `try` and stops the container in `finally`; `stop()` removes the container and its volumes (testcontainers 4.15.0 source).

## Images and ports

- Pin exact tags and match production's major version: `postgres:17.12-alpine`, `redpandadata/redpanda:v26.2.7`. The module defaults are not safe: `PostgresContainer()` is `postgres:latest`, `RedpandaContainer()` an old Redpanda.
- Import from `testcontainers.community.postgres` and `testcontainers.community.kafka`; the older paths are deprecated shims.
- `PostgresContainer` defaults its URL driver to `psycopg2`, which is not installed for you. The harness passes `driver=None` and builds the URL itself: plain `postgresql://` for asyncpg, `postgresql+asyncpg://` for Alembic.
- Take host and port from the container. The harness publishes on 127.0.0.1 only, with random host ports, because the credentials are fixed test values; by default Docker publishes on every interface. With a remote Docker host that binding is unreachable (not run).

## Waiting

| Container | Wait strategy, by name | What it proves |
|---|---|---|
| `PostgresContainer` | Built in: `ExecWaitStrategy`, running `psql` over TCP (`--host 127.0.0.1`) inside the container | The final server answers. Seen: the ready log line had appeared twice when `start()` returned; the first, temporary start-up server is not what the TCP query reaches |
| `RedpandaContainer` | Built in: `LogMessageWaitStrategy` for `Started Kafka API server` | The Kafka API is up. Its default limit is 10 seconds; the harness passes 60 |

Add no `sleep` and no `wait_for_logs` (deprecated). A custom PostgreSQL image waited on by a log line must see the line twice, or query over TCP.

## Start failures and cleanup

- The harness retries a failed **start** up to three times, logs each failure, removes the half-started container and then raises. Three is a chosen value. Seen with an image tag that does not exist: three attempts, then `ExceptionGroup`.
- A container that cannot start makes the tests **error**. Never `pytest.skip` or `importorskip` for a missing Docker. Seen with `DOCKER_HOST` pointing at nothing: errors, no skips.
- Ryuk, Testcontainers' cleanup container, removes labelled containers when the test process dies. It is on by default; `TESTCONTAINERS_RYUK_DISABLED=true` turns it off. All runs for this skill had it disabled, so its behaviour is unverified. Seen with it disabled: after a hard process exit (`os._exit`), the PostgreSQL container was still running. Disable it only where the CI job removes containers itself.

## Event loops

An asyncpg connection, pool or aiokafka client works only on the event loop that created it. Under the shared settings each test has its own loop, shared by its function-scoped async fixtures. So the harness shares no async resource across loops:

- containers and migrations are **synchronous** session fixtures (Alembic's `env.py` calls `asyncio.run`; seen inside an async test: `asyncio.run() cannot be called from a running event loop`);
- connections, pools, producers and consumers are **function-scoped async** fixtures.

### Which setting affects what

| Setting | Affects | Does not affect |
|---|---|---|
| `asyncio_default_fixture_loop_scope` | The loop of async fixtures | Synchronous fixtures, tests |
| `asyncio_default_test_loop_scope` | The loop of async tests | Fixtures |

Seen: a synchronous session fixture had no running loop and could call `asyncio.run` under every combination below. Per object, the same is set with `loop_scope=` on `@pytest_asyncio.fixture` and `@pytest.mark.asyncio`.

### A session-scoped async resource

| Settings | Result (seen) |
|---|---|
| Both `function` (shared settings) | `ScopeMismatch` |
| Only the test loop scope `session` | `ScopeMismatch` |
| Only the fixture loop scope `session` | Fixture and test on different loops; with an asyncpg pool, `InterfaceError: ... another operation is in progress` |
| Both `session` | Passes |
| `scope="session", loop_scope="session"` on the fixture and `@pytest.mark.asyncio(loop_scope="session")` on its tests | Passes, settings unchanged |

Two remedies are valid for a loop mismatch: **run the tests on the session loop too** (settings, or the marker), or **share no async resource across loops**. The harness takes the second, so the settings shared with unit tests stay as they are.

### Async fixtures need auto mode or the plugin's decorator

The harness and the examples use plain `@pytest.fixture` on `async def`, which works only with `asyncio_mode = "auto"`. Seen in strict mode (the pytest-asyncio default): the test errors. Under strict mode use `@pytest_asyncio.fixture` and mark the tests `@pytest.mark.asyncio` (seen to pass).

## Excluding slow tests

`tests/integration/conftest.py` marks everything below it `integration`.

| Command | What runs |
|---|---|
| `pytest -m "not integration"` | The fast loop. Integration tests are reported as `deselected` and no container starts. If nothing else exists, pytest exits 5 |
| `make test` / `make ci` | Everything; needs Docker. The coverage gate clears `addopts` and gives no verdict when any test is deselected |

The `-m` goes on the command line only: never in `addopts`, never an `--ignore` of the folder.

## Parallel runs

Without a plugin pytest runs tests one at a time, and rollback keeps them fast. With `pytest-xdist` each worker is a process with its own session fixtures. Seen with `-n 3` on the standard example: three PostgreSQL containers and two Redpanda containers (only workers that ran broker tests started one), all removed. Budget memory per worker; every test still owns its rows, database and topic.

## Other stores

The harness covers PostgreSQL and Redpanda only. For MongoDB, a graph extension, RabbitMQ or another store the product uses, apply the same rules with that engine's container, and report that no template here was run for it.

## CI

- Integration tests run in `make ci` on every pull request (`python-makefile`, `ci-pipeline`).
- Pull images in a step of their own so a pull is not mistaken for a hung test.
- A test with different results on unchanged code is a defect; no retry and no rerun plugin at this layer (`test-pyramid`). Usual causes: shared rows, a code path that reads every row, a missing wait, an object from another event loop.
- Bound every wait (`asyncio.timeout`), including awaiting a background task at teardown.

## Coverage

Integration tests count towards the line and branch gate of `python-unit-test`, run on the full suite. Coverage flags (`--cov...`, `--cov-fail-under`) belong on the full gate command the `make` target runs (the gate script passes them), never in `addopts` or shared config, because subset runs then fail. Seen: all three examples reached 100% of both measures with this harness. The gate measures the source folders only, so the harness under `tests/` is outside it: add no exclusion or `omit` entry for it, list it in the report as test support, and never move code that ships into `tests/`. The validator fails shipped code that imports `tests`; code copied into `tests/` that nothing imports goes unnoticed.
