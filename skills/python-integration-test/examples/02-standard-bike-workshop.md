# Standard: a Bike Repair Workshop

Booking jobs over HTTP; each booking writes its event to a Transactional Outbox; a relay publishes it; a consumer sends one reminder per event. One organisation, no tenant column.

Run on 2026-11-27: Python 3.14.4, testcontainers 4.15.0, asyncpg 0.32.0, Alembic 1.20.1, SQLAlchemy 2.1.9, aiokafka 0.15.0, FastAPI 0.165.0, httpx 0.29.0, pytest 9.2.0, pytest-asyncio 1.5.0, `postgres:17.12-alpine`, `redpandadata/redpanda:v26.2.7`.

## Contents
Plan; contract assumed; production code; tests; output; broken on purpose; coverage and open points.

## Plan

| Behaviour | Isolation and reason |
|---|---|
| Stale start refused; second open job refused | Rollback |
| Rollback hides writes from other connections (guard) | Rollback |
| Job and event commit together or not at all | Real commit, own database: the test alters a table |
| Unit of work rolls back without a commit | Rollback, through `one_pool` |
| Repeat request, key reuse, rate limit, errors, deprecation, workflow | Rollback, real app |
| Eight identical requests at once | Real commit, scoped keys: separate connections |
| Relay publishes once | Real commit, own database: it reads every row |
| Duplicate event, poison record | Real commit, own database and topic |
| Migrations down and up again | Own database |

## Contract assumed

`POST /v2/jobs` needs `Idempotency-Key`; a repeat returns the first reply; the same key for another booking is `422 IDEMPOTENCY_KEY_REUSED`. A rate limit per `X-Client-Id` answers `429 RATE_LIMITED` with `Retry-After`. `/v1/jobs/{id}` sends `Deprecation` and `Sunset`. Errors are `{"code": ...}`; an unexpected failure is `500 INTERNAL`. The values are this product's, not defaults.

The consumer is deliberately minimal: no retry with backoff and no worker pool. `python-event-consumer` owns the production shape; its retry paths need their own tests.

## Production code

The harness files and `broker.py` are copied into `tests/integration/`; `conftest.py` changes two lines: `INIT_CONNECTION = register_codecs` (imported from the adapter) and the import of the broker fixtures. Unit tests for `domain/errors.py` are under `tests/unit/` (not shown).

### `migrations/versions/0001_create_jobs.py`

```python
"""create jobs, outbox and idempotency keys

Revision ID: 0001
Revises:
"""
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "CREATE TABLE jobs (id uuid PRIMARY KEY, bike_ref text NOT NULL, "
        "state text NOT NULL, version bigint NOT NULL)"
    )
    op.execute("CREATE UNIQUE INDEX jobs_one_open_per_bike ON jobs (bike_ref) WHERE state <> 'done'")
    op.execute(
        "CREATE TABLE outbox (id uuid PRIMARY KEY, aggregate_id uuid NOT NULL, event_type text NOT NULL, "
        "payload jsonb NOT NULL, occurred_at timestamptz NOT NULL, published_at timestamptz)"
    )
    op.execute(
        "CREATE TABLE idempotency_keys (idempotency_key text PRIMARY KEY, request_hash text NOT NULL, "
        "response jsonb)"
    )


def downgrade() -> None:
    op.execute("DROP TABLE idempotency_keys, outbox, jobs")
```

### `migrations/versions/0002_create_reminders.py`

```python
"""create the reminder consumer's tables

Revision ID: 0002
Revises: 0001
"""
from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "CREATE TABLE processed_events (consumer_name text NOT NULL, event_id uuid NOT NULL, "
        "processed_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (consumer_name, event_id))"
    )
    # No unique key on event_id: a second reminder is possible if deduplication fails.
    op.execute("CREATE TABLE reminders (event_id uuid NOT NULL, job_id uuid NOT NULL)")


def downgrade() -> None:
    op.execute("DROP TABLE reminders, processed_events")
```

### `src/workshop/domain/errors.py`

```python
class JobNotFoundError(Exception):
    """No job has this id."""


class BikeAlreadyBookedError(Exception):
    """The bike already has an open job."""


class StaleJobError(Exception):
    """The job changed since it was read."""


class KeyReusedError(Exception):
    """The Idempotency-Key was used before for a different request."""
```

### `src/workshop/adapters/postgres.py`

```python
"""Jobs, their outbox rows and idempotency keys. Every write uses the caller's transaction."""

import json
from datetime import datetime, timezone
from uuid import UUID, uuid4

import asyncpg

from workshop.domain.errors import BikeAlreadyBookedError, StaleJobError


async def register_codecs(conn: asyncpg.Connection) -> None:
    await conn.set_type_codec("jsonb", encoder=json.dumps, decoder=json.loads, schema="pg_catalog")


class JobRepo:
    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn

    async def book(self, job_id: UUID, bike_ref: str) -> None:
        if not self._conn.is_in_transaction():
            raise RuntimeError("book() needs the caller's transaction")
        try:
            await self._conn.execute(
                "INSERT INTO jobs (id, bike_ref, state, version) VALUES ($1, $2, 'booked', 1)",
                job_id, bike_ref)
        except asyncpg.UniqueViolationError as exc:
            if exc.constraint_name != "jobs_one_open_per_bike":
                raise
            raise BikeAlreadyBookedError(bike_ref) from exc
        await self._conn.execute(
            "INSERT INTO outbox (id, aggregate_id, event_type, payload, occurred_at) "
            "VALUES ($1, $2, 'JobBooked', $3, $4)",
            uuid4(), job_id, {"bike_ref": bike_ref}, datetime.now(timezone.utc))

    async def start(self, job_id: UUID, expected_version: int) -> None:
        updated = await self._conn.fetchval(
            "UPDATE jobs SET state = 'started', version = version + 1 "
            "WHERE id = $1 AND version = $2 AND state = 'booked' RETURNING id",
            job_id, expected_version)
        if updated is None:
            raise StaleJobError(job_id)

    async def get(self, job_id: UUID) -> dict | None:
        row = await self._conn.fetchrow(
            "SELECT id, bike_ref, state, version FROM jobs WHERE id = $1", job_id)
        return None if row is None else {**dict(row), "id": str(row["id"])}


class IdempotencyKeys:
    def __init__(self, conn: asyncpg.Connection) -> None:
        self._conn = conn

    async def claim(self, key: str, request_hash: str) -> bool:
        """True when this transaction owns the key. A concurrent claim waits here."""
        status = await self._conn.execute(
            "INSERT INTO idempotency_keys (idempotency_key, request_hash) VALUES ($1, $2) "
            "ON CONFLICT DO NOTHING", key, request_hash)
        return status == "INSERT 0 1"

    async def store(self, key: str, response: dict) -> None:
        await self._conn.execute(
            "UPDATE idempotency_keys SET response = $2 WHERE idempotency_key = $1", key, response)

    async def stored(self, key: str) -> tuple[str, dict]:
        row = await self._conn.fetchrow(
            "SELECT request_hash, response FROM idempotency_keys WHERE idempotency_key = $1", key)
        return row["request_hash"], row["response"]
```

### `src/workshop/adapters/uow.py`

```python
"""One asyncpg transaction per use case. Rollback is the default (python-service-layer)."""

from types import TracebackType

import asyncpg

from workshop.adapters.postgres import IdempotencyKeys, JobRepo


class AsyncpgUnitOfWork:
    def __init__(self, pool: asyncpg.Pool) -> None:
        self._pool = pool
        self._commit_requested = False

    async def __aenter__(self) -> "AsyncpgUnitOfWork":
        self._commit_requested = False
        self._conn = await self._pool.acquire()
        try:
            self._tx = self._conn.transaction()
            await self._tx.start()
        except BaseException:
            await self._pool.release(self._conn)
            raise
        self.jobs = JobRepo(self._conn)
        self.keys = IdempotencyKeys(self._conn)
        return self

    async def __aexit__(self, exc_type: type[BaseException] | None,
                        exc: BaseException | None, tb: TracebackType | None) -> None:
        try:
            if exc_type is None and self._commit_requested:
                await self._tx.commit()
            else:
                await self._tx.rollback()
        finally:
            await self._pool.release(self._conn)

    async def commit(self) -> None:
        self._commit_requested = True
```

### `src/workshop/service_layer/commands.py`

```python
"""Booking: the job, its event and the idempotency record share one transaction."""

import hashlib
from uuid import UUID, uuid4

from workshop.adapters.uow import AsyncpgUnitOfWork
from workshop.domain.errors import KeyReusedError


async def book_job(bike_ref: str, key: str, uow: AsyncpgUnitOfWork,
                   new_id: UUID | None = None) -> dict:
    request_hash = hashlib.sha256(bike_ref.encode()).hexdigest()
    async with uow:
        if not await uow.keys.claim(key, request_hash):
            stored_hash, response = await uow.keys.stored(key)
            if stored_hash != request_hash:
                raise KeyReusedError(key)
            return response
        job_id = new_id or uuid4()
        await uow.jobs.book(job_id, bike_ref)
        response = {"id": str(job_id), "bike_ref": bike_ref, "state": "booked", "version": 1}
        await uow.keys.store(key, response)
        await uow.commit()
        return response
```

### `src/workshop/entrypoints/fastapi_app.py`

```python
"""HTTP edge. The pool and the limits are injected; production wires them in bootstrap."""

import logging
import math
import time
from uuid import UUID

from fastapi import FastAPI, Header, Request, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from workshop.adapters.uow import AsyncpgUnitOfWork
from workshop.domain import errors
from workshop.service_layer.commands import book_job

log = logging.getLogger("workshop.api")

_ERRORS = {
    errors.JobNotFoundError: (404, "JOB_NOT_FOUND"),
    errors.BikeAlreadyBookedError: (409, "BIKE_ALREADY_BOOKED"),
    errors.StaleJobError: (409, "VERSION_CONFLICT"),
    errors.KeyReusedError: (422, "IDEMPOTENCY_KEY_REUSED"),
}


class Booking(BaseModel):
    bike_ref: str


class Start(BaseModel):
    version: int


def _error(status: int, code: str, headers: dict[str, str] | None = None) -> JSONResponse:
    return JSONResponse({"code": code}, status_code=status, headers=headers)


def create_app(pool, *, rate: float, burst: int, v1_deprecated: str, v1_sunset: str) -> FastAPI:
    app = FastAPI()
    buckets: dict[str, tuple[float, float]] = {}  # per process, per caller

    @app.middleware("http")
    async def rate_limit(request: Request, call_next):
        caller = request.headers.get("X-Client-Id", "anonymous")
        now = time.monotonic()
        tokens, then = buckets.get(caller, (float(burst), now))
        tokens = min(burst, tokens + (now - then) * rate)
        if tokens < 1:
            wait = math.ceil((1 - tokens) / rate)
            return _error(429, "RATE_LIMITED", {"Retry-After": str(wait)})
        buckets[caller] = (tokens - 1, now)
        return await call_next(request)

    async def domain_error(request: Request, exc: Exception) -> JSONResponse:
        return _error(*_ERRORS[type(exc)])

    for kind in _ERRORS:
        app.add_exception_handler(kind, domain_error)

    @app.exception_handler(Exception)
    async def unexpected(request: Request, exc: Exception) -> JSONResponse:
        log.error("unhandled", exc_info=exc)
        return _error(500, "INTERNAL")

    @app.post("/v2/jobs", status_code=201)
    async def book(body: Booking, idempotency_key: str = Header()):
        return await book_job(body.bike_ref, idempotency_key, AsyncpgUnitOfWork(pool))

    @app.post("/v2/jobs/{job_id}/start", status_code=204)
    async def start(job_id: UUID, body: Start):
        async with AsyncpgUnitOfWork(pool) as uow:
            if await uow.jobs.get(job_id) is None:
                raise errors.JobNotFoundError(job_id)
            await uow.jobs.start(job_id, body.version)
            await uow.commit()

    async def read(job_id: UUID) -> dict:
        async with AsyncpgUnitOfWork(pool) as uow:
            job = await uow.jobs.get(job_id)
        if job is None:
            raise errors.JobNotFoundError(job_id)
        return job

    @app.get("/v2/jobs/{job_id}")
    async def get_job(job_id: UUID):
        return await read(job_id)

    @app.get("/v1/jobs/{job_id}")
    async def get_job_v1(job_id: UUID, response: Response):
        job = await read(job_id)
        response.headers["Deprecation"] = v1_deprecated
        response.headers["Sunset"] = v1_sunset
        return job

    return app
```

### `src/workshop/adapters/messaging.py`

```python
"""Outbox relay (python-event-publisher): claim, publish, then mark, in one transaction."""

import json

import asyncpg
from aiokafka import AIOKafkaProducer

_CLAIM = (
    "SELECT id, aggregate_id, event_type, payload, occurred_at FROM outbox "
    "WHERE published_at IS NULL ORDER BY occurred_at LIMIT $1 FOR UPDATE SKIP LOCKED"
)


class OutboxRelay:
    def __init__(self, pool: asyncpg.Pool, producer: AIOKafkaProducer, topic: str) -> None:
        self._pool, self._producer, self._topic = pool, producer, topic

    async def drain_once(self, batch: int = 100) -> int:
        async with self._pool.acquire() as conn, conn.transaction():
            rows = await conn.fetch(_CLAIM, batch)
            for row in rows:
                envelope = {
                    "event_id": str(row["id"]),
                    "event_type": row["event_type"],
                    "aggregate_id": str(row["aggregate_id"]),
                    "occurred_at": row["occurred_at"].isoformat(),
                    "payload": row["payload"],
                }
                await self._producer.send_and_wait(
                    self._topic, json.dumps(envelope).encode(), key=row["aggregate_id"].bytes)
            await conn.execute(
                "UPDATE outbox SET published_at = now() WHERE id = ANY($1::uuid[])",
                [row["id"] for row in rows])
            return len(rows)
```

### `src/workshop/entrypoints/event_consumer.py`

```python
"""One reminder per JobBooked event (python-event-consumer, without its retry paths)."""

import asyncio
import json
import logging
from uuid import UUID

import asyncpg
from aiokafka import AIOKafkaConsumer, AIOKafkaProducer, ConsumerRecord

log = logging.getLogger("workshop.consumer")


class ReminderConsumer:
    def __init__(self, consumer: AIOKafkaConsumer, pool: asyncpg.Pool,
                 dlq: AIOKafkaProducer, name: str) -> None:
        self._consumer, self._pool, self._dlq, self._name = consumer, pool, dlq, name
        self._stopping = asyncio.Event()

    def request_stop(self) -> None:
        self._stopping.set()

    async def run(self) -> None:
        await self._consumer.start()
        try:
            while not self._stopping.is_set():
                batches = await self._consumer.getmany(timeout_ms=200)
                for partition, records in batches.items():
                    for record in records:
                        await self._handle_or_dlq(record)
                        # Only after the work is durable.
                        await self._consumer.commit({partition: record.offset + 1})
        finally:
            await self._consumer.stop()

    async def _handle_or_dlq(self, record: ConsumerRecord) -> None:
        try:
            await self._handle(record)
        except Exception as exc:
            log.exception("handling failed; routing to the dead letter topic")
            await self._dlq.send_and_wait(
                f"{record.topic}.dlq", record.value, key=record.key,
                headers=[("x-dlq-reason", type(exc).__name__.encode())])

    async def _handle(self, record: ConsumerRecord) -> None:
        envelope = json.loads(record.value)
        event_id = UUID(envelope["event_id"])
        async with self._pool.acquire() as conn, conn.transaction():
            status = await conn.execute(
                "INSERT INTO processed_events (consumer_name, event_id) VALUES ($1, $2) "
                "ON CONFLICT DO NOTHING", self._name, event_id)
            if status == "INSERT 0 0":
                log.info("duplicate %s; skipping", event_id)
                return
            await conn.execute(
                "INSERT INTO reminders (event_id, job_id) VALUES ($1, $2)",
                event_id, UUID(envelope["aggregate_id"]))
```

## Tests

### `tests/integration/adapters/test_postgres.py`

```python
"""JobRepo against the real engine. Isolation: rollback (the default)."""

import asyncpg
import pytest

from workshop.adapters.postgres import JobRepo
from workshop.domain.errors import BikeAlreadyBookedError, StaleJobError


async def test_a_stale_start_is_refused_and_changes_nothing(db, test_id):
    repo, job = JobRepo(db), test_id("job")
    async with db.transaction():
        await repo.book(job, "bike-7")
    await repo.start(job, expected_version=1)

    with pytest.raises(StaleJobError):
        await repo.start(job, expected_version=1)

    assert (await repo.get(job))["version"] == 2


async def test_a_second_open_job_for_one_bike_is_refused_with_no_event(db, test_id):
    repo = JobRepo(db)
    async with db.transaction():
        await repo.book(test_id("first"), "bike-8")

    with pytest.raises(BikeAlreadyBookedError):
        async with db.transaction():  # savepoint around the expected refusal
            await repo.book(test_id("second"), "bike-8")

    assert await db.fetchval(
        "SELECT count(*) FROM outbox WHERE aggregate_id = $1", test_id("second")) == 0


async def test_another_connection_cannot_see_the_rolled_back_writes(db, postgres_server, test_id):
    """Guard: why commit behaviour cannot be tested on the db fixture."""
    job = test_id("job")
    async with db.transaction():
        await JobRepo(db).book(job, "bike-9")
    other = await asyncpg.connect(postgres_server.url())
    try:
        assert await other.fetchval("SELECT count(*) FROM jobs WHERE id = $1", job) == 0
    finally:
        await other.close()


async def test_booking_outside_a_transaction_is_refused(db, postgres_server, test_id):
    other = await asyncpg.connect(postgres_server.url())
    try:
        with pytest.raises(RuntimeError, match="caller's transaction"):
            await JobRepo(other).book(test_id("job"), "bike-10")
    finally:
        await other.close()


async def test_a_reused_job_id_is_not_reported_as_a_booked_bike(db, test_id):
    repo = JobRepo(db)
    async with db.transaction():
        await repo.book(test_id("job"), "bike-11")

    with pytest.raises(asyncpg.UniqueViolationError):
        async with db.transaction():
            await repo.book(test_id("job"), "bike-12")
```

### `tests/integration/adapters/test_uow.py`

```python
"""Rollback is the unit of work's default. Isolation: rollback; its transaction is a savepoint."""

from workshop.adapters.uow import AsyncpgUnitOfWork


async def test_leaving_without_commit_stores_nothing(one_pool, db, test_id):
    async with AsyncpgUnitOfWork(one_pool) as uow:
        await uow.jobs.book(test_id("job"), "bike-30")

    assert await db.fetchval("SELECT count(*) FROM jobs WHERE id = $1", test_id("job")) == 0
```

### `tests/integration/service_layer/test_commands.py`

```python
"""Job and event commit together or not at all.

Real commit: the subject is the transaction boundary. Own database: the test alters a table.
"""

import asyncpg
import pytest

from workshop.adapters.uow import AsyncpgUnitOfWork
from workshop.service_layer.commands import book_job


async def counts(pool, job_id):
    return tuple(await pool.fetchrow(
        "SELECT (SELECT count(*) FROM jobs WHERE id = $1), "
        "       (SELECT count(*) FROM outbox WHERE aggregate_id = $1)", job_id))


async def test_booking_stores_the_job_and_its_event(own_pool, test_id):
    job = test_id("job")

    await book_job("bike-1", "key-1", AsyncpgUnitOfWork(own_pool), new_id=job)

    assert await counts(own_pool, job) == (1, 1)


async def test_a_failed_event_write_stores_neither(own_pool, test_id):
    await own_pool.execute("ALTER TABLE outbox ADD CONSTRAINT refuse_all CHECK (false)")
    job = test_id("job")

    with pytest.raises(asyncpg.CheckViolationError):
        await book_job("bike-2", "key-2", AsyncpgUnitOfWork(own_pool), new_id=job)

    assert await counts(own_pool, job) == (0, 0)
    assert await own_pool.fetchval("SELECT count(*) FROM idempotency_keys") == 0
```

### `tests/integration/entrypoints/test_fastapi_app.py`

```python
"""What the API contract promises, through the real app and database.

The values (burst, sunset date, codes) are this product's assumed contract.
"""

import asyncio

import httpx
import pytest

from workshop.entrypoints.fastapi_app import create_app

DEPRECATED = "@1767225600"
SUNSET = "Wed, 30 Jun 2027 00:00:00 GMT"
UNLIMITED = 10_000


def client(pool, *, rate: float = UNLIMITED, burst: int = UNLIMITED) -> httpx.AsyncClient:
    """The app in this event loop, so it shares the test's connection.
    One app per test: the limiter is in memory."""
    app = create_app(pool, rate=rate, burst=burst, v1_deprecated=DEPRECATED, v1_sunset=SUNSET)
    transport = httpx.ASGITransport(app=app, raise_app_exceptions=False)
    return httpx.AsyncClient(transport=transport, base_url="http://test")


def book(api, bike: str, key: str):
    return api.post("/v2/jobs", json={"bike_ref": bike}, headers={"Idempotency-Key": key})


async def stored(db, bike: str) -> tuple[int, int]:
    return tuple(await db.fetchrow(
        "SELECT count(DISTINCT j.id), count(o.id) FROM jobs j "
        "LEFT JOIN outbox o ON o.aggregate_id = j.id WHERE j.bike_ref = $1", bike))


async def test_a_repeated_request_has_one_effect(one_pool, db):
    async with client(one_pool) as api:
        first = await book(api, "bike-20", "key-20")
        second = await book(api, "bike-20", "key-20")

    assert (first.status_code, second.status_code) == (201, 201)
    assert second.json() == first.json()
    assert await stored(db, "bike-20") == (1, 1)


async def test_a_key_reused_for_another_request_is_refused(one_pool, db):
    async with client(one_pool) as api:
        await book(api, "bike-21", "key-21")
        reused = await book(api, "bike-22", "key-21")

    assert (reused.status_code, reused.json()) == (422, {"code": "IDEMPOTENCY_KEY_REUSED"})
    assert await stored(db, "bike-22") == (0, 0)


async def test_concurrent_repeats_have_one_effect(pool, scoped):
    """Real commit: the requests need separate connections. Scoped by bike and key."""
    bike, key = "bike-concurrent", "key-concurrent"
    scoped(key, "DELETE FROM idempotency_keys WHERE idempotency_key = $1")
    scoped(bike,
           "DELETE FROM outbox WHERE aggregate_id IN (SELECT id FROM jobs WHERE bike_ref = $1)",
           "DELETE FROM jobs WHERE bike_ref = $1")

    async with client(pool) as api:
        replies = await asyncio.gather(*(book(api, bike, key) for _ in range(8)))

    assert [r.status_code for r in replies] == [201] * 8
    assert len({r.json()["id"] for r in replies}) == 1
    assert await stored(pool, bike) == (1, 1)


async def test_the_rate_limit_sends_429_with_retry_after_per_caller(one_pool):
    path = "/v2/jobs/00000000-0000-4000-8000-000000000001"
    # One token an hour: no refill can happen during the test.
    async with client(one_pool, rate=1 / 3600, burst=2) as api:
        allowed = [await api.get(path, headers={"X-Client-Id": "a"}) for _ in range(2)]
        limited = await api.get(path, headers={"X-Client-Id": "a"})
        other = await api.get(path, headers={"X-Client-Id": "b"})

    assert [r.status_code for r in allowed] == [404, 404]
    assert (limited.status_code, limited.json()) == (429, {"code": "RATE_LIMITED"})
    assert 0 < int(limited.headers["Retry-After"]) <= 3600
    assert other.status_code == 404


async def test_book_start_and_read_through_both_versions(one_pool):
    async with client(one_pool) as api:
        job = (await book(api, "bike-23", "key-23")).json()["id"]
        started = await api.post(f"/v2/jobs/{job}/start", json={"version": 1})
        current = await api.get(f"/v2/jobs/{job}")
        old = await api.get(f"/v1/jobs/{job}")

    assert started.status_code == 204
    assert (current.json()["state"], current.json()["version"]) == ("started", 2)
    assert "Deprecation" not in current.headers and "Sunset" not in current.headers
    assert old.json() == current.json()
    assert (old.headers["Deprecation"], old.headers["Sunset"]) == (DEPRECATED, SUNSET)


MISSING = "/v2/jobs/00000000-0000-4000-8000-000000000002"


@pytest.mark.parametrize(
    ("method", "path", "body", "headers", "status", "code"),
    [
        pytest.param("GET", MISSING, None, {}, 404, "JOB_NOT_FOUND", id="read-missing"),
        pytest.param("POST", f"{MISSING}/start", {"version": 1}, {}, 404, "JOB_NOT_FOUND",
                     id="start-missing"),
        pytest.param("POST", "/v2/jobs", {"bike_ref": "bike-24"}, {"Idempotency-Key": "key-new"},
                     409, "BIKE_ALREADY_BOOKED", id="second-open-job"),
        pytest.param("POST", "/v2/jobs", {"bike_ref": "bike-25"}, {}, 422, None, id="no-key"),
        pytest.param("POST", "/v2/jobs", {}, {"Idempotency-Key": "key-empty"}, 422, None,
                     id="no-bike"),
    ],
)
async def test_documented_errors_store_nothing(one_pool, db, method, path, body, headers, status, code):
    async with client(one_pool) as api:
        await book(api, "bike-24", "key-24")
        before = await db.fetchval("SELECT count(*) FROM outbox")
        reply = await api.request(method, path, json=body, headers=headers)

    assert reply.status_code == status
    if code:
        assert reply.json() == {"code": code}
    assert await db.fetchval("SELECT count(*) FROM outbox") == before


async def test_a_stale_start_is_a_version_conflict(one_pool):
    async with client(one_pool) as api:
        job = (await book(api, "bike-26", "key-26")).json()["id"]
        reply = await api.post(f"/v2/jobs/{job}/start", json={"version": 9})

    assert (reply.status_code, reply.json()) == (409, {"code": "VERSION_CONFLICT"})


async def test_a_database_failure_is_an_opaque_500(one_pool, db):
    with pytest.raises(Exception, match="division by zero"):
        await db.execute("SELECT 1/0")  # the test's transaction is now aborted
    async with client(one_pool) as api:
        reply = await api.get(MISSING)

    assert (reply.status_code, reply.json()) == (500, {"code": "INTERNAL"})
```

### `tests/integration/adapters/test_messaging.py`

```python
"""The relay publishes each outbox row once.

Real commit, own database: the relay reads every row. Own topic.
"""

import json
from datetime import datetime, timezone

from aiokafka import AIOKafkaProducer

from tests.integration.broker import read_all
from workshop.adapters.messaging import OutboxRelay
from workshop.adapters.uow import AsyncpgUnitOfWork
from workshop.service_layer.commands import book_job


async def test_draining_twice_publishes_once(own_pool, redpanda, new_topic, test_id):
    topic, job = await new_topic(), test_id("job")
    await book_job("bike-1", "key-1", AsyncpgUnitOfWork(own_pool), new_id=job)
    producer = AIOKafkaProducer(bootstrap_servers=redpanda)
    await producer.start()
    try:
        relay = OutboxRelay(own_pool, producer, topic)
        assert (await relay.drain_once(), await relay.drain_once()) == (1, 0)
    finally:
        await producer.stop()

    [record] = await read_all(redpanda, topic)
    event_id = await own_pool.fetchval("SELECT id FROM outbox WHERE aggregate_id = $1", job)
    envelope = json.loads(record.value)
    assert record.key == job.bytes
    assert (envelope["event_id"], envelope["event_type"], envelope["payload"]) == (
        str(event_id), "JobBooked", {"bike_ref": "bike-1"})
    assert datetime.fromisoformat(envelope["occurred_at"]) <= datetime.now(timezone.utc)
```

### `tests/integration/entrypoints/test_event_consumer.py`

```python
"""The real consumer against a real broker.

Real commit, own database and topic: the consumer commits on its own connections.
"""

import asyncio
import json

import pytest
from aiokafka import AIOKafkaConsumer, AIOKafkaProducer

from tests.integration.broker import committed_offset, read_all
from tests.integration.harness import poll_until
from workshop.entrypoints.event_consumer import ReminderConsumer

NAME = "reminders"


@pytest.fixture
async def running(own_pool, redpanda, new_topic, test_id):
    """The real ReminderConsumer on a topic and group of this test's own."""
    topic = await new_topic()
    await new_topic(f"{topic}.dlq")
    group = f"g-{test_id('group')}"
    producer = AIOKafkaProducer(bootstrap_servers=redpanda)
    await producer.start()
    consumer = ReminderConsumer(
        AIOKafkaConsumer(topic, bootstrap_servers=redpanda, group_id=group,
                         enable_auto_commit=False, auto_offset_reset="earliest"),
        own_pool, producer, NAME)
    task = asyncio.create_task(consumer.run())
    try:
        yield producer, topic, group, task
    finally:
        consumer.request_stop()
        try:
            async with asyncio.timeout(15):
                await task  # a consumer that died or hangs fails the test
        finally:
            await producer.stop()


def envelope(event_id, job_id) -> bytes:
    return json.dumps({"event_id": str(event_id), "event_type": "JobBooked",
                       "aggregate_id": str(job_id)}).encode()


def consumed(redpanda, own_pool, group, topic, event_id, offset: int):
    """True once the group has committed past `offset` AND this event id is recorded."""
    async def check() -> bool:
        recorded = await own_pool.fetchval(
            "SELECT count(*) FROM processed_events WHERE consumer_name = $1 AND event_id = $2",
            NAME, event_id)
        return recorded == 1 and await committed_offset(redpanda, group, topic) >= offset
    return check


async def reminders(pool, event_id) -> int:
    return await pool.fetchval("SELECT count(*) FROM reminders WHERE event_id = $1", event_id)


async def test_a_redelivered_event_sends_one_reminder(running, own_pool, redpanda, test_id):
    producer, topic, group, task = running
    event_id, job = test_id("event"), test_id("job")
    for _ in range(2):  # the same event twice: offsets 0 and 1
        await producer.send_and_wait(topic, envelope(event_id, job))

    # Offset 2 committed: the duplicate has been consumed, so "once" now means something.
    await poll_until(consumed(redpanda, own_pool, group, topic, event_id, 2),
                     f"event {event_id} consumed twice", watching=task)

    assert await reminders(own_pool, event_id) == 1
    # A duplicate is skipped, not failed: nothing is dead-lettered.
    assert await read_all(redpanda, f"{topic}.dlq") == []


async def test_a_poison_record_is_dead_lettered_and_the_next_one_handled(
        running, own_pool, redpanda, test_id):
    producer, topic, group, task = running
    event_id = test_id("event")
    await producer.send_and_wait(topic, b"not json", key=b"k")
    await producer.send_and_wait(topic, envelope(event_id, test_id("job")))

    await poll_until(consumed(redpanda, own_pool, group, topic, event_id, 2),
                     f"event {event_id} consumed after the poison record", watching=task)

    [dead] = await read_all(redpanda, f"{topic}.dlq")
    assert (dead.value, dead.key) == (b"not json", b"k")
    assert dict(dead.headers)["x-dlq-reason"] == b"JSONDecodeError"
    assert await reminders(own_pool, event_id) == 1
```

### `tests/integration/test_migrations.py`

```python
"""Migration round trip. Own database; synchronous, because env.py calls asyncio.run."""

TABLES = ("jobs", "outbox", "idempotency_keys", "processed_events", "reminders")


def test_migrations_go_down_and_up_again(postgres_server, own_database):
    def present() -> set[str]:
        rows = postgres_server.run(
            own_database, "SELECT tablename FROM pg_tables WHERE schemaname = 'public'")
        return {r["tablename"] for r in rows} & set(TABLES)

    assert present() == set(TABLES)
    postgres_server.migrate(own_database, "base", down=True)
    assert present() == set()
    postgres_server.migrate(own_database)
    assert present() == set(TABLES)
```

## Output

```text
$ pytest -v
tests/integration/adapters/test_messaging.py::test_draining_twice_publishes_once PASSED
tests/integration/adapters/test_postgres.py::test_a_stale_start_is_refused_and_changes_nothing PASSED
tests/integration/adapters/test_postgres.py::test_a_second_open_job_for_one_bike_is_refused_with_no_event PASSED
tests/integration/adapters/test_postgres.py::test_another_connection_cannot_see_the_rolled_back_writes PASSED
tests/integration/adapters/test_postgres.py::test_booking_outside_a_transaction_is_refused PASSED
tests/integration/adapters/test_postgres.py::test_a_reused_job_id_is_not_reported_as_a_booked_bike PASSED
tests/integration/adapters/test_uow.py::test_leaving_without_commit_stores_nothing PASSED
tests/integration/entrypoints/test_event_consumer.py::test_a_redelivered_event_sends_one_reminder PASSED
tests/integration/entrypoints/test_event_consumer.py::test_a_poison_record_is_dead_lettered_and_the_next_one_handled PASSED
tests/integration/entrypoints/test_fastapi_app.py::test_a_repeated_request_has_one_effect PASSED
tests/integration/entrypoints/test_fastapi_app.py::test_a_key_reused_for_another_request_is_refused PASSED
tests/integration/entrypoints/test_fastapi_app.py::test_concurrent_repeats_have_one_effect PASSED
tests/integration/entrypoints/test_fastapi_app.py::test_the_rate_limit_sends_429_with_retry_after_per_caller PASSED
tests/integration/entrypoints/test_fastapi_app.py::test_book_start_and_read_through_both_versions PASSED
tests/integration/entrypoints/test_fastapi_app.py::test_documented_errors_store_nothing[read-missing] PASSED
tests/integration/entrypoints/test_fastapi_app.py::test_documented_errors_store_nothing[start-missing] PASSED
tests/integration/entrypoints/test_fastapi_app.py::test_documented_errors_store_nothing[second-open-job] PASSED
tests/integration/entrypoints/test_fastapi_app.py::test_documented_errors_store_nothing[no-key] PASSED
tests/integration/entrypoints/test_fastapi_app.py::test_documented_errors_store_nothing[no-bike] PASSED
tests/integration/entrypoints/test_fastapi_app.py::test_a_stale_start_is_a_version_conflict PASSED
tests/integration/entrypoints/test_fastapi_app.py::test_a_database_failure_is_an_opaque_500 PASSED
tests/integration/service_layer/test_commands.py::test_booking_stores_the_job_and_its_event PASSED
tests/integration/service_layer/test_commands.py::test_a_failed_event_write_stores_neither PASSED
tests/integration/test_migrations.py::test_migrations_go_down_and_up_again PASSED
24 passed
```

The whole suite passed on each of five further runs in a row.

## Broken on purpose

Each change was made in a copy, run, and reverted.

| Broken | Observed |
|---|---|
| Duplicate result ignored (SQL kept) | `assert 2 == 1` reminders |
| Only `ON CONFLICT DO NOTHING` removed | The duplicate raises, is dead-lettered and its offset committed; reminders stay 1; only the empty dead letter assertion fails |
| The same, with that assertion deleted | **The test passed** |
| Duplicate result ignored, consumer slowed 200 ms, wait for the event id's record without the offset | **Passed** 3 of 3 runs with deduplication removed |
| The same, waiting for offset 2 as written | Failed 3 of 3: `assert 2 == 1` |
| Unit of work opens no transaction | `assert (1, 0) == (0, 0)`: a job without its event |
| `uow.commit()` removed | `assert (0, 0) == (1, 1)` |
| Savepoint removed around the refused insert | `InFailedSQLTransactionError: current transaction is aborted` |
| Idempotency claim ignored | `(201, 409) == (201, 201)`; concurrent replies 409 |
| Rate limiter removed | `404 != 429` |
| Relay never marks rows | `(1, 1) == (1, 0)` |
| Consumer swallows a poison record | The poison test fails |
| Consumer dies while a test waits | The wait fails at once with the consumer's error |
| `fastapi.testclient.TestClient` on the test's connection | `RuntimeError`: the connection belongs to another event loop |
| A committed row not cleaned up | The test passes; the run fails at teardown: `public.idempotency_keys: 0 rows before, 1 after` |
| A cleanup statement with a wrong table name | Teardown error `cleanup failed` |

## Coverage and open points

First full gate run: 202/204 statements and 28/30 branches (exit 1): two refusal paths in the repository had no test. After adding the last two tests of `adapters/test_postgres.py`: 24 ran, line coverage 204/204, branch coverage 30/30, exit 0. The report lists `tests/integration/` support files as test support.

**For the product owner:** the values of the rate limit, idempotency key retention (no sweep exists) and the sunset date. Not proven: more than one service instance (the limiter is per instance), crash recovery between publish and mark, the production consumer's retries. Not run: Ryuk (disabled), CI.
