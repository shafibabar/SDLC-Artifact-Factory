# Integration Harness (PostgreSQL)

Copy both files into `tests/integration/` with an empty `tests/__init__.py` and `tests/integration/__init__.py`. Change only the values named below. Run on Python 3.14.4 with testcontainers 4.15.0, asyncpg 0.32.0, Alembic 1.20.1, SQLAlchemy 2.1.9, pytest 9.2.0 and pytest-asyncio 1.5.0; other versions are unverified.

## Contents
Dependencies and settings; change only; `harness.py`; `conftest.py`.

## Dependencies and settings

Add to the product's one `pyproject.toml` (owned by `python-makefile`); keep its pytest table unchanged.

```toml
[project]
dependencies = ["asyncpg==0.32.0", "alembic==1.20.1", "sqlalchemy[asyncio]==2.1.9"]

[dependency-groups]
dev = ["testcontainers==4.15.0", "httpx==0.29.0"]   # httpx only for API behaviour tests
```

The harness's async fixtures are plain `@pytest.fixture` functions, so the table must keep:

```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
```

The table already registers the `integration` marker, sets `pythonpath = [".", "src"]` and function-scoped event loops. These fixtures are built for that: containers and migrations are synchronous session fixtures, and every connection is opened on the test's own loop. Add no `-m` to `addopts`. Coverage flags (`--cov...`, `--cov-fail-under`) belong on the full gate command the `make` target runs, never in `addopts` or shared config, because subset runs then fail.

Alembic: `alembic.ini` and `migrations/env.py` come from `python-migration`, whose `env.py` takes a URL set by the caller before `DATABASE_URL`.

## Change only

| Value | Where |
|---|---|
| Image tag (match production) | `POSTGRES_IMAGE` |
| Start attempts (a chosen value) | `START_ATTEMPTS` |
| The product's connection set-up, for example `register_codecs` | `INIT_CONNECTION` in `conftest.py` (import it there) |
| Folder holding `alembic.ini`, if the harness moves | `ROOT` |
| Name of Alembic's version table, if configured | `migrate` |

The folder is test support outside the measured source, so the coverage gate needs no exclusion for it. List these files in the coverage report as test support. Nothing under `src/` may import `tests`.

### `tests/integration/harness.py`

```python
"""Integration test harness: throwaway containers started by the test run itself,
the real Alembic migrations and a leftover check. Test support only."""

import asyncio
import itertools
import logging
import time
from collections.abc import Awaitable, Callable
from pathlib import Path
from typing import Any, TypeVar

import asyncpg
import pytest
from alembic import command
from alembic.config import Config
from testcontainers.community.postgres import PostgresContainer

# Pin the tag to the version production runs.
POSTGRES_IMAGE = "postgres:17.12-alpine"

# Chosen values, not measurements.
START_ATTEMPTS = 3

# The folder holding alembic.ini (this file is tests/integration/harness.py).
ROOT = Path(__file__).resolve().parents[2]

log = logging.getLogger("integration.harness")
C = TypeVar("C")
T = TypeVar("T")


def start_with_retry(name: str, make: Callable[[], C], start: Callable[[C], Any]) -> C:
    """Retry a container START only, never a test. A half-started container is removed."""
    failures: list[Exception] = []
    for attempt in range(1, START_ATTEMPTS + 1):
        container = make()
        try:
            start(container)
            return container
        except Exception as exc:  # reported below; the run fails after the last attempt
            log.warning("start %s: attempt %d of %d failed: %r", name, attempt, START_ATTEMPTS, exc)
            failures.append(exc)
            try:
                container.stop()  # type: ignore[attr-defined]
            except Exception as stop_exc:
                log.warning("start %s: removing the failed container: %r", name, stop_exc)
                failures.append(stop_exc)
        except BaseException:  # interrupted during the start: remove, do not retry
            container.stop()  # type: ignore[attr-defined]
            raise
        if attempt < START_ATTEMPTS:
            time.sleep(attempt)  # backoff between container starts, not a wait for an effect
    raise ExceptionGroup(f"{name} did not start", failures)


def loopback(container: Any, *ports: int) -> Any:
    """Publish the ports on 127.0.0.1 only, on random host ports."""
    for port in ports:
        container.ports[f"{port}/tcp"] = ("127.0.0.1", None)
    return container


class PostgresServer:
    """One throwaway server with the migrations applied to its database."""

    DATABASE = "app_test"

    def __init__(self) -> None:
        def make() -> PostgresContainer:
            container = PostgresContainer(
                POSTGRES_IMAGE, username="test", password="test", dbname=self.DATABASE, driver=None
            )
            container.ports.clear()  # drop the all-interfaces default before binding
            return loopback(container, 5432)

        # PostgresContainer.start() waits with ExecWaitStrategy: psql over TCP in the container.
        self._container = start_with_retry(POSTGRES_IMAGE, make, lambda c: c.start())
        self._numbers = itertools.count(1)

    def url(self, database: str = DATABASE) -> str:
        """The only source of a database address. DATABASE_URL is never read."""
        host = self._container.get_container_host_ip()
        port = self._container.get_exposed_port(5432)
        return f"postgresql://test:test@{host}:{port}/{database}"

    def migrate(self, database: str = DATABASE, revision: str = "head", *, down: bool = False) -> None:
        """Run the real Alembic chain, as deployment does. Call from synchronous code only:
        env.py calls asyncio.run."""
        url = self.url(database).replace("postgresql://", "postgresql+asyncpg://", 1)
        with pytest.MonkeyPatch.context() as env:
            env.setenv("DATABASE_URL", url)  # an env.py that reads it still gets this container
            config = Config(str(ROOT / "alembic.ini"))
            config.set_main_option("sqlalchemy.url", url.replace("%", "%%"))
            (command.downgrade if down else command.upgrade)(config, revision)
        if not down and not self.run(database, "SELECT to_regclass('alembic_version') AS t")[0]["t"]:
            raise RuntimeError(f"migrations did not reach {database}: check how env.py picks its URL")

    def run(self, database: str, sql: str) -> list[asyncpg.Record]:
        """One statement from synchronous code (fixtures, migration tests)."""

        async def go() -> list[asyncpg.Record]:
            connection = await asyncpg.connect(self.url(database))
            try:
                return await connection.fetch(sql)
            finally:
                await connection.close()

        return asyncio.run(go())

    def create_database(self) -> str:
        name = f"it_{next(self._numbers)}"
        self.run(self.DATABASE, f'CREATE DATABASE "{name}"')
        return name

    def drop_database(self, name: str) -> None:
        self.run(self.DATABASE, f'DROP DATABASE "{name}" WITH (FORCE)')

    def row_counts(self) -> dict[str, int]:
        """Rows in every table of the shared database; a difference is a leak."""
        tables = self.run(
            self.DATABASE,
            "SELECT format('%I.%I', table_schema, table_name) AS name FROM information_schema.tables "
            "WHERE table_type = 'BASE TABLE' AND table_schema NOT IN ('pg_catalog', 'information_schema')",
        )
        return {
            t["name"]: self.run(self.DATABASE, f"SELECT count(*) AS n FROM {t['name']}")[0]["n"]
            for t in tables
        }

    def close(self) -> None:
        self._container.stop()


async def poll_until(
    check: Callable[[], Awaitable[T]], what: str, *, timeout: float = 15.0,
    watching: "asyncio.Task[Any] | None" = None,
) -> T:
    """Await check() until it returns a truthy value; fail at the deadline.
    watching: a background task (a consumer) whose death fails the wait at once."""
    last: object = None
    try:
        async with asyncio.timeout(timeout):
            while True:
                if watching is not None and watching.done():
                    watching.result()  # raises what killed it
                    raise AssertionError(f"{what}: the background task ended early")
                last = await check()
                if last:
                    return last
                await asyncio.sleep(0.02)  # gap between polls; the deadline bounds the wait
    except TimeoutError:
        raise AssertionError(f"{what}: not observed within {timeout}s (last value: {last!r})") from None
```

### `tests/integration/conftest.py`

```python
"""Integration fixtures. Containers start only when a selected test asks for one."""

import uuid
from collections.abc import AsyncIterator, Callable, Iterator
from pathlib import Path

import asyncpg
import pytest

from tests.integration.harness import PostgresServer

HERE = Path(__file__).parent
# The product's connection set-up, e.g. register_codecs (python-repository-pattern), or None.
INIT_CONNECTION = None
_NAMESPACE = uuid.UUID("6f9c1b4e-0000-4000-8000-000000000001")


@pytest.hookimpl(tryfirst=True)  # before pytest applies -m
def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    for item in items:
        if HERE in item.path.parents:
            item.add_marker(pytest.mark.integration)


@pytest.fixture(scope="session")
def postgres_server() -> Iterator[PostgresServer]:
    """One container per test process. A start failure errors the tests; nothing skips."""
    server = PostgresServer()
    try:
        server.migrate()
        before = server.row_counts()
        yield server
        after = server.row_counts()
        leaks = [
            f"{table}: {before.get(table, 0)} rows before, {after.get(table, 0)} after"
            for table in sorted(before.keys() | after.keys())
            if before.get(table, 0) != after.get(table, 0)
        ]
        assert not leaks, "tests changed the shared database:\n  " + "\n  ".join(leaks)
    finally:
        server.close()


@pytest.fixture
async def db(postgres_server: PostgresServer) -> AsyncIterator[asyncpg.Connection]:
    """Default isolation: one connection inside a transaction that is never committed.
    The code's own conn.transaction() nests as a savepoint."""
    connection = await asyncpg.connect(postgres_server.url())
    try:
        if INIT_CONNECTION:
            await INIT_CONNECTION(connection)
        transaction = connection.transaction()
        await transaction.start()
        try:
            yield connection
        finally:
            await transaction.rollback()
    finally:
        await connection.close()


class OnePool:
    """Stands where code expects a pool and hands out the test's one connection, so
    its transaction becomes a savepoint inside the test's. Not for concurrent use."""

    def __init__(self, connection: asyncpg.Connection) -> None:
        self._connection = connection

    def acquire(self) -> "_Lease":
        return _Lease(self._connection)

    async def release(self, connection: asyncpg.Connection) -> None:
        assert connection is self._connection


class _Lease:
    """Awaitable and async context manager, like asyncpg's pool.acquire()."""

    def __init__(self, connection: asyncpg.Connection) -> None:
        self._connection = connection

    def __await__(self):
        yield from ()
        return self._connection

    async def __aenter__(self) -> asyncpg.Connection:
        return self._connection

    async def __aexit__(self, *exc: object) -> None:
        return None


@pytest.fixture
def one_pool(db: asyncpg.Connection) -> OnePool:
    return OnePool(db)


@pytest.fixture
async def pool(postgres_server: PostgresServer) -> AsyncIterator[asyncpg.Pool]:
    """Real commits in the shared database. Only with a named reason, and with scoped."""
    async with asyncpg.create_pool(postgres_server.url(), init=INIT_CONNECTION) as committed:
        yield committed


@pytest.fixture
def own_database(postgres_server: PostgresServer) -> Iterator[str]:
    """A migrated database for one test, dropped afterwards: for code that reads every
    row (a relay, a consumer, a scheduler) and for migration tests."""
    name = postgres_server.create_database()
    try:
        postgres_server.migrate(name)
        yield name
    finally:
        postgres_server.drop_database(name)


@pytest.fixture
async def own_pool(postgres_server: PostgresServer, own_database: str) -> AsyncIterator[asyncpg.Pool]:
    async with asyncpg.create_pool(postgres_server.url(own_database), init=INIT_CONNECTION) as pool:
        yield pool


@pytest.fixture
def test_id(request: pytest.FixtureRequest) -> Callable[[str], uuid.UUID]:
    """Unique per test and label, identical on every run."""
    return lambda label: uuid.uuid5(_NAMESPACE, f"{request.node.nodeid}/{label}")


@pytest.fixture
async def scoped(postgres_server: PostgresServer) -> AsyncIterator[Callable[..., None]]:
    """Cleanup for committed rows. Call BEFORE the first write:
    scoped(key, "DELETE ... WHERE ... = $1", ...) lists every table written, children first."""
    registered: list[tuple[object, tuple[str, ...]]] = []

    def register(key: object, *deletes: str) -> None:
        assert deletes, "list every table this test writes"
        registered.append((key, deletes))

    yield register

    errors: list[str] = []
    connection = await asyncpg.connect(postgres_server.url())
    try:
        for key, deletes in reversed(registered):
            for statement in deletes:
                try:
                    await connection.execute(statement, key)
                except Exception as exc:  # report every failure, then fail
                    errors.append(f"{statement}: {exc!r}")
    finally:
        await connection.close()
    assert not errors, "cleanup failed:\n  " + "\n  ".join(errors)
```
