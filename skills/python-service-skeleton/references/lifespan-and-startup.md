# Lifespan, App Factory, and Startup — Worked Reference

The complete composition root for a FastAPI service on the repo stack (FastAPI +
`asyncpg` + `aiokafka` against Redpanda, per-tenant physical isolation, the
`DataAsset` domain). Every stage below is grounded in the same ordering
discipline `go-service-skeleton` mandates; where Python diverges from Go it is
called out inline rather than papered over.

---

## `app/config.py` — fail-fast settings

Pydantic `BaseSettings` (`pydantic-settings`) is the Python analog of Go's
aggregated-error config loader. It reads non-secret values from the environment,
reads secrets from mounted files, and — critically — raises a single
`ValidationError` listing **every** invalid/missing field at once, not just the
first. That is the fail-fast property `go-service-skeleton`'s `config.Load()`
provides by hand; Pydantic gives it for free.

```python
from pathlib import Path
from pydantic import Field, PostgresDsn
from pydantic_settings import BaseSettings, SettingsConfigDict


def _read_secret_file(path: str) -> str:
    # Secrets arrive as mounted files (a projected Secret volume), never as env
    # vars — env is world-readable via /proc; a mounted file is not.
    return Path(path).read_text(encoding="utf-8").strip()


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="DATAASSET_", frozen=True)

    # non-secret, from environment
    postgres_host: str
    postgres_port: int = 5432
    postgres_db: str
    kafka_bootstrap: str                       # Redpanda advertises the Kafka API
    kafka_consumer_group: str = "data-asset-svc"
    pool_min_size: int = 2
    pool_max_size: int = 10
    tenant_id: str = Field(..., description="physical-isolation tenant this pod serves")

    # secret, from a mounted file path given in env
    postgres_password_file: str

    @property
    def dsn(self) -> str:
        pw = _read_secret_file(self.postgres_password_file)
        return (
            f"postgresql://app:{pw}@{self.postgres_host}:"
            f"{self.postgres_port}/{self.postgres_db}"
        )


def load_settings() -> Settings:
    # Raising here aborts startup before uvicorn binds the port — the process
    # exits non-zero and Kubernetes reports CrashLoopBackOff, which is exactly
    # what a misconfigured pod should do.
    return Settings()  # ValidationError aggregates all field errors
```

Per-tenant **physical** isolation: each pod serves exactly one `tenant_id`, so
the tenant is a startup-time setting, not a per-request lookup. The value still
belongs in every SQL `WHERE` clause (defense in depth), but the pod boundary is
the primary isolation guarantee.

---

## `app/main.py` — the lifespan composition root

```python
import contextlib
from contextlib import asynccontextmanager

import asyncpg
import uvicorn
from aiokafka import AIOKafkaConsumer
from fastapi import FastAPI

from app.config import Settings, load_settings
from app.health import Readiness, health_router
from app.errors import register_exception_handlers
from app.routers.data_asset import data_asset_router


async def open_pool(settings: Settings) -> asyncpg.Pool:
    # Pool sized from capacity math, not defaults: min_size keeps warm
    # connections for steady load, max_size caps concurrency so a traffic spike
    # cannot exhaust Postgres' own max_connections across all pods.
    return await asyncpg.create_pool(
        dsn=settings.dsn,
        min_size=settings.pool_min_size,
        max_size=settings.pool_max_size,
        command_timeout=5.0,           # no query blocks the event loop forever
    )


async def start_consumer(settings: Settings) -> AIOKafkaConsumer:
    consumer = AIOKafkaConsumer(
        "data-asset-events",
        bootstrap_servers=settings.kafka_bootstrap,
        group_id=settings.kafka_consumer_group,
        enable_auto_commit=False,      # manual offset commit — see python-event-consumer
        auto_offset_reset="earliest",
    )
    await consumer.start()             # connects to Redpanda; raises if unreachable
    return consumer


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = load_settings()                          # Stage 1: config
    app.state.settings = settings

    pool = await open_pool(settings)                    # Stage 2: asyncpg pool
    app.state.pool = pool

    consumer = await start_consumer(settings)           # Stage 3: aiokafka
    app.state.consumer = consumer

    ready = Readiness(pool)                             # Stage 4: readiness gate
    app.state.ready = ready
    ready.set_ready()

    try:
        yield                                          # <-- app serves traffic here
    finally:
        # Reverse of startup. `finally` guarantees teardown even if uvicorn
        # tears down the loop after a fatal error, so no dependency leaks.
        ready.set_not_ready()                          # Shutdown 1: stop passing readiness
        await consumer.stop()                          # Shutdown 2: leave the consumer group cleanly
        await pool.close()                             # Shutdown 3: close pool LAST, after all queries drain


def create_app() -> FastAPI:
    app = FastAPI(title="data-asset-service", lifespan=lifespan)
    app.include_router(health_router)                  # /healthz/live, /healthz/ready
    app.include_router(data_asset_router, prefix="/v1")
    register_exception_handlers(app)                   # single DomainError boundary
    return app


if __name__ == "__main__":
    # See references/server-and-health.md for the full uvicorn config; this is
    # the minimal entrypoint. uvicorn — not this code — owns SIGTERM handling.
    uvicorn.run("app.main:create_app", factory=True, host="0.0.0.0", port=8000)
```

### Why the order is fixed (per stage)

| Stage | Depends on | Why it cannot move earlier |
|---|---|---|
| 1. Config | nothing | Everything after is parameterized by it; a bad config must abort before any socket opens. |
| 2. Pool | config | Needs the DSN and pool sizing from stage 1. |
| 3. Consumer | config | Needs `kafka_bootstrap`; started after the pool so a DB failure fails faster/cheaper than a broker connect. |
| 4. Readiness gate | pool | The gate's `SELECT 1` needs a live pool to check; building it earlier would check a `None`. |
| `yield` | all four | The mechanical instant traffic begins — nothing may be unconstructed past this line. |

### Why teardown is strict reverse order

- **not-ready first** — flips `/healthz/ready` to 503 so the Kubernetes endpoint
  controller pulls this pod from the Service before any connection is refused;
  the load balancer drains gracefully instead of throwing errors at clients.
- **consumer.stop() next** — leaves the consumer group cleanly (commits final
  offsets, triggers a clean rebalance) *before* the pool it writes into is gone.
- **pool.close() last** — closing the pool before the consumer stops would yank
  a connection out from under an in-flight consume-and-write transaction. The
  pool is the last thing standing, exactly as `go-service-skeleton` closes it
  after `g.Wait()`.

---

## App factory vs module-scope singleton

`create_app()` returning a fresh `FastAPI` — passed to uvicorn as
`factory=True` — is the injectable composition root. A test builds an app with a
fake pool and fake consumer by calling a variant factory, never importing a
module-level `app = FastAPI()` singleton (which would run the real `lifespan`
against real Postgres on import). This is the direct analog of Go's `run()`
funnel: one place constructs the world, and tests can construct a different one.

```python
# tests build their own app with fakes — no real Postgres, no real Redpanda
def create_test_app(pool, consumer) -> FastAPI:
    @asynccontextmanager
    async def test_lifespan(app: FastAPI):
        app.state.pool = pool
        app.state.consumer = consumer
        app.state.ready = Readiness(pool)
        app.state.ready.set_ready()
        yield
    app = FastAPI(lifespan=test_lifespan)
    app.include_router(health_router)
    app.include_router(data_asset_router, prefix="/v1")
    register_exception_handlers(app)
    return app
```

---

## Honest Python-vs-Go divergences at the composition root

- **No hand-rolled signal handling.** Go's skeleton calls
  `signal.NotifyContext(...)` and supervises goroutines in an `errgroup`. Python
  does neither: uvicorn catches `SIGTERM`/`SIGINT` and drives the drain, then
  calls `lifespan` teardown. Application code that installs its own
  `signal.signal(...)` handler races uvicorn and corrupts the drain.
- **Weaker encapsulation.** Go's `internal/` package privacy is compiler-
  enforced; Python has only `_underscore` convention and `import-linter` as a CI
  fitness function (see `python-project-structure`). Nothing at runtime stops a
  router from reaching around `app.state` and building its own pool — the
  discipline is enforced by review and CI, not the language.
- **The GIL bounds what this process should do.** The `lifespan` here wires an
  I/O-bound service (Postgres, Redpanda, S3/Drive) — exactly the workload
  `asyncio` handles well, since the GIL is released during I/O waits. CPU-bound
  document parsing/OCR stays a separate, independently-scaled service; do not
  add a `ProcessPoolExecutor` to this request-handling skeleton to "use more
  cores" — that is a different service's problem (`data-pipeline-implementation`).
- **Code-first OpenAPI.** FastAPI derives the OpenAPI schema *from* the Pydantic
  models and route signatures at runtime — there is no spec-first artifact the
  way a hand-written Go handler pairs with a separate contract. The schema at
  `/openapi.json` is generated, so the models *are* the contract; keep them
  honest.
