# Testcontainers Setup — Session Containers, Async Fixtures, Alembic-in-Fixture

Reference for `python-integration-test`. Everything here is loaded only when the
SKILL body points to it. Self-contained: the session-scoped container fixtures,
the two-sighting readiness wait, running `alembic upgrade head` inside the
fixture, the async connection/pool wiring, the poll-with-deadline helper, and the
`pytest -m "not integration"` marker wiring.

Target stack: **FastAPI + asyncpg + aiokafka**, async end to end, per-tenant
**physical** isolation, Redpanda (Kafka API). Runner: `pytest` +
`pytest-asyncio` (`asyncio_mode = "auto"`). Container library:
`testcontainers-python` (`testcontainers[postgres]` and
`testcontainers[redpanda]`).

---

## 1. Dependencies and pytest config

```toml
# pyproject.toml  (managed with uv)
[dependency-groups]
test = [
  "pytest>=8.2",
  "pytest-asyncio>=0.23",
  "pytest-xdist>=3.6",          # optional parallelism — see the container-cost note
  "testcontainers[postgres,redpanda]>=4.5",
  "asyncpg>=0.29",
  "aiokafka>=0.11",
  "alembic>=1.13",
]

[tool.pytest.ini_options]
asyncio_mode = "auto"           # async def tests + async fixtures, no per-test marker
markers = [
  "integration: real Postgres/Redpanda via testcontainers (needs Docker)",
]
```

Run the fast suite anywhere: `pytest -m "not integration"` (the Python analog of
Go's `-short`). Run the real suite where Docker exists: `pytest -m integration`.

---

## 2. Session-scoped Postgres container + the two-sighting readiness wait

`testcontainers-python`'s `PostgresContainer` waits by retrying a connection, but
under load the **first** readiness log Postgres emits is `initdb`'s throwaway
first boot — the server then **restarts**, and a fixture that proceeds on that
first sighting races a brief connection-refused window. Wait until the readiness
line **`database system is ready to accept connections`** has been seen **twice**
(once for `initdb`, once for the real server) before yielding. This is the exact
Python analog of Go's `postgres.BasicWaitStrategies()` note that a port-only wait
races `initdb`'s restart.

```python
# tests/conftest.py
import pytest_asyncio
from testcontainers.postgres import PostgresContainer
from testcontainers.core.waiting_utils import wait_for_logs

PG_READY = r"database system is ready to accept connections"


@pytest_asyncio.fixture(scope="session")
async def pg_container():
    container = PostgresContainer(
        image="postgres:16-alpine",
        username="test",
        password="test",
        dbname="dataestate_test",
    )
    container.start()
    # Wait for the readiness line TWICE — the first is initdb's first-boot server
    # which then restarts; proceeding on it races a connection-refused window.
    wait_for_logs(container, rf"(?s){PG_READY}.*{PG_READY}", timeout=60)
    try:
        yield container
    finally:
        container.stop()


def _pg_dsn(container: PostgresContainer) -> str:
    """asyncpg DSN from a running PostgresContainer (dynamic host port)."""
    host = container.get_container_host_ip()
    port = container.get_exposed_port(5432)   # dynamic — never a fixed host port
    return f"postgresql://test:test@{host}:{port}/dataestate_test"
```

`get_exposed_port` returns the **dynamically allocated** host port; nothing here
maps a fixed host port, so parallel `pytest-xdist` workers never collide.

---

## 3. Run the real Alembic chain inside the fixture

A broken migration must fail the suite, not just production. Run `alembic upgrade
head` (`python-migration`) against the fresh container **before** yielding the
DSN. Alembic's `env.py` reads `sqlalchemy.url` from config; override it with the
container DSN so the revision chain lands on the throwaway database.

```python
# tests/conftest.py  (continued)
from alembic import command
from alembic.config import Config


@pytest_asyncio.fixture(scope="session")
async def migrated_dsn(pg_container) -> str:
    dsn = _pg_dsn(pg_container)
    cfg = Config("alembic.ini")
    # Alembic's config expects the SQLAlchemy URL spelling even though the
    # revisions are hand-written op.execute() raw SQL and the app uses asyncpg.
    cfg.set_main_option("sqlalchemy.url", dsn.replace("postgresql://", "postgresql+psycopg://"))
    command.upgrade(cfg, "head")   # a broken revision raises here → suite fails
    return dsn
```

`command.upgrade` is Alembic's synchronous programmatic entrypoint — fine to call
once at session setup even in an async suite; the per-test data path stays async.

---

## 4. Session asyncpg pool wired to the migrated database

```python
# tests/conftest.py  (continued)
import asyncpg
import pytest_asyncio


@pytest_asyncio.fixture(scope="session")
async def pg_pool(migrated_dsn):
    pool = await asyncpg.create_pool(migrated_dsn, min_size=1, max_size=8)
    try:
        yield pool
    finally:
        await pool.close()
```

**Event-loop caveat (honest asyncpg divergence).** An asyncpg connection/pool is
bound to the event loop it was created on. With `pytest-asyncio` in
`asyncio_mode = "auto"` and the default function-scoped loop, a `session`-scoped
async pool must share one loop across the session — set
`asyncio_default_fixture_loop_scope = "session"` (pytest-asyncio 0.23+) so the
session pool and the tests share a loop. Go has no analog: a `*pgxpool.Pool` is
loop-free and one instance serves the whole binary regardless of goroutines.

```toml
# pyproject.toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "session"
```

---

## 5. Session-scoped Redpanda container

Redpanda speaks the Kafka API, so `aiokafka` connects unchanged. `RedpandaContainer`
exposes a bootstrap-servers string with a dynamic host port.

```python
# tests/conftest.py  (continued)
from testcontainers.redpanda import RedpandaContainer


@pytest_asyncio.fixture(scope="session")
async def redpanda_container():
    container = RedpandaContainer("docker.redpanda.com/redpandadata/redpanda:v24.1.7")
    container.start()
    try:
        yield container
    finally:
        container.stop()


@pytest_asyncio.fixture(scope="session")
async def bootstrap_servers(redpanda_container) -> str:
    return redpanda_container.get_bootstrap_server()   # host:port, dynamic port
```

An `aiokafka` producer/consumer built against `bootstrap_servers` talks to the
real broker — no mock. Auto-topic-creation is on by default in the Redpanda dev
image; create explicit topics in a fixture if a test needs partition control.

---

## 6. Poll-with-deadline helper (never `asyncio.sleep`)

Async effects — the outbox relay publishing, the consumer writing its projection
— complete *eventually*. Poll a predicate under a bounded deadline; a bare
`await asyncio.sleep(1)` is slow when the system is fast and flaky when it is
slow.

```python
# tests/integration/_poll.py
import asyncio
from typing import Awaitable, Callable, TypeVar

T = TypeVar("T")


async def poll_until(
    predicate: Callable[[], Awaitable[T | None]],
    *,
    timeout: float = 10.0,
    interval: float = 0.05,
) -> T:
    """Await predicate() until it returns a truthy value or the deadline passes.

    Fast when the effect is fast; fails with a clear message when it never lands.
    """
    loop = asyncio.get_running_loop()
    deadline = loop.time() + timeout
    while True:
        result = await predicate()
        if result:
            return result
        if loop.time() >= deadline:
            raise AssertionError(f"condition not met within {timeout}s")
        await asyncio.sleep(interval)   # inter-poll backoff only, not a fixed wait
```

Usage: `row = await poll_until(lambda: conn.fetchrow("SELECT ... WHERE id=$1", id))`.

---

## 7. Container-cost note under pytest-xdist

A `session`-scoped fixture runs **once per xdist worker process**, because the
GIL forces real parallelism into separate processes. `pytest -n 4 -m integration`
therefore starts **four** Postgres and **four** Redpanda containers — one pair
per worker — not one shared pair. This is the honest cost the SKILL body flags:
Go recovers speed with `t.Parallel()` over a single container pair per binary;
Python either pays N container pairs for N workers or stays serial and leans on
per-test transaction rollback (see `isolation-and-assertions.md`) for speed.
Budget container RAM against `-n`; in CI, cap workers to what the runner can host.
