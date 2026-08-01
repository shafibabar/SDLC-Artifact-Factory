---
name: python-service-skeleton
description: >
  Teaches the backend-engineer to build a FastAPI service skeleton — the
  lifespan async context manager as the composition root and
  startup/reverse-ordered-shutdown boundary (yield separates the two), uvicorn
  as the ASGI server handling SIGTERM graceful shutdown, health endpoints, and
  app assembly. The Python analog of go-service-skeleton.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, fastapi, asgi, uvicorn, lifespan, lifecycle, graceful-shutdown, composition-root, readiness]
produces: python-composition-root
domain: backend
status: stable
related: [go-service-skeleton, python-project-structure, python-middleware]
tools: [Bash]
---

# Python Service Skeleton

## Purpose

The composition root of a FastAPI service is its `lifespan` async context manager — the one place that knows the concrete world (which Postgres, which Redpanda, which config) and wires it together. Unlike Go's `main.go`, FastAPI collapses *startup*, *shutdown*, and *the boundary between them* into a single function: everything before `yield` is startup, everything after is teardown, and the `yield` itself is the moment the app is ready to serve. This is the direct Python analog of `go-service-skeleton`'s six-stage startup + reverse-ordered shutdown — but the process-lifecycle machinery Go writes by hand (`signal.NotifyContext`, the errgroup, `srv.Shutdown`) is instead owned by the ASGI server, `uvicorn`. The artifact under review here is the *ordering* inside `lifespan` and the *contract* between it and `uvicorn`, not any single line.

Honest divergence up front: Go's composition root explicitly installs signal handlers and supervises every goroutine. In Python you do **not** hand-roll signal handling — `uvicorn` catches `SIGTERM`/`SIGINT`, stops accepting new connections, drains in-flight requests, and only then runs your `lifespan` teardown. Fighting that with your own `signal` handlers is an anti-pattern (below).

---

## The Lifespan Composition Root

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    # --- startup: ordered, each stage depends on the one before ---
    settings = load_settings()                       # 1. config (fail-fast)
    app.state.pool = await open_pool(settings)       # 2. asyncpg pool
    app.state.consumer = await start_consumer(...)   # 3. aiokafka
    app.state.ready = Readiness(app.state.pool)      # 4. readiness gate
    yield                                            # <-- app serves here
    # --- shutdown: reverse order of startup ---
    app.state.ready.set_not_ready()
    await app.state.consumer.stop()
    await app.state.pool.close()
```

The startup order is fixed for the same reason Go's is: config parameterizes everything after it; dependencies must be proven constructible before the readiness gate is built against them; the gate must exist before `yield` because `yield` is the mechanical instant traffic begins. Teardown is startup reversed — mark not-ready first, then stop the consumer, then close the pool last so no in-flight query loses its connection. Full worked `main.py` with real `asyncpg`/`aiokafka`/config wiring and per-stage rationale: `references/lifespan-and-startup.md`.

`lifespan=` is passed to `FastAPI(lifespan=lifespan)` — the modern replacement for the deprecated `@app.on_event("startup")`/`("shutdown")` decorators, which cannot guarantee reverse ordering or share local state across the boundary the way a single generator can.

---

## The App Factory

Build the app in a `create_app()` factory, not at module scope:

```python
def create_app() -> FastAPI:
    app = FastAPI(lifespan=lifespan)
    app.include_router(health_router)
    app.include_router(data_asset_router, prefix="/v1")
    register_exception_handlers(app)
    return app
```

A factory keeps construction explicit and injectable — tests build an app with fake dependencies instead of importing a module-level singleton. Routers are mounted here (Starlette's `APIRouter`), and the single `@app.exception_handler(DomainError)` boundary is registered here (its content belongs to `python-error-handling`). Full factory + router-mounting sequence: `references/lifespan-and-startup.md`.

---

## Graceful Shutdown Is uvicorn's Job

Run the process with `uvicorn`, which owns the signal → drain → teardown sequence:

```python
uvicorn.run(create_app(), host="0.0.0.0", port=8000)
```

On `SIGTERM` (what Kubernetes sends before `SIGKILL`) or `SIGINT` (`Ctrl-C`), `uvicorn` stops accepting new connections, waits a bounded interval for in-flight requests to finish, then triggers `lifespan` teardown. That drain deadline is a `uvicorn` server setting, and it must be sized to fit **under** Kubernetes' `terminationGracePeriodSeconds` (30s) alongside the `preStop` hook — the exact parameter name, value, and the arithmetic against the grace period live in `references/server-and-health.md`. You never call `signal.signal(...)` or `signal.NotifyContext`'s Python equivalent yourself; doing so races `uvicorn`'s own handler and breaks the drain.

---

## Readiness vs Liveness — the Lifecycle Contract

Two separate endpoints, never merged:

- **`/healthz/live`** (liveness) — answers "is the process fundamentally stuck." Returns 200 unconditionally, touching **no** dependency. A liveness probe that pings Postgres turns one database blip into a fleet-wide restart storm.
- **`/healthz/ready`** (readiness) — answers "can this instance serve traffic right now." Checks critical dependencies (a bounded `SELECT 1` on the pool, consumer connectivity) and flips to not-ready the instant `lifespan` teardown begins, so the load balancer drains this pod before it stops accepting connections.

This skill owns only the *ordering* contract: the readiness gate is built after dependencies are proven constructible (startup stage 4, never earlier) and set not-ready before any teardown step (shutdown step 1, never later). Full handler code, the readiness-gating-on-dependencies pattern, and the Kubernetes probe mapping: `references/server-and-health.md`.

---

## Configuration Loading

Config is a Pydantic `BaseSettings` (`pydantic-settings`) loaded fail-fast in stage 1: non-secret values from environment, secrets from mounted files (never secrets in env). A missing or wrong-typed required field aborts startup with **every** validation error reported at once (Pydantic aggregates them), not just the first. Full `Settings` model: `references/lifespan-and-startup.md`.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Single lifespan boundary | One `@asynccontextmanager` with `yield` separating startup/shutdown | `on_event` decorators, or state built at module scope | Read `lifespan` against `references/lifespan-and-startup.md` |
| Startup order held | config → pool → consumer → readiness, then `yield` | Readiness gate built before the pool exists | Read stages top-to-bottom to the `yield` |
| Reverse teardown | not-ready → consumer.stop → pool.close, after `yield` | Pool closed before consumer stops | Read post-`yield` order |
| No hand-rolled signals | No `signal.signal`/`loop.add_signal_handler` in app code | A custom SIGTERM handler racing uvicorn | `grep -rn "signal.signal\|add_signal_handler" app/` — no hits |
| Drain under grace period | uvicorn drain deadline < `terminationGracePeriodSeconds` | Unbounded or ≥ grace-period drain | Read the server setting against `references/server-and-health.md` |
| Liveness dependency-free | `/healthz/live` calls no dependency | A pool query on the liveness path | Read the liveness handler |
| Readiness gated | Gate flips not-ready at teardown start | not-ready set after drain, or never | Read gate position vs teardown order |
| App factory | `create_app()` returns a fresh app | Module-level `app = FastAPI()` singleton | `grep -n "def create_app" app/` |
| Fail-fast config | Pydantic `BaseSettings`, all errors at once | First-error-only ad-hoc `os.environ[...]` | Read the `Settings` model |
| Type gate green | `mypy`/`pyright` clean (ports are unchecked at runtime) | Type errors ignored | CI type step — see `python-project-structure` |

---

## Anti-Patterns

- **Hand-rolling `signal.signal(SIGTERM, ...)`** — races uvicorn's own handler; the two fight over the drain and in-flight requests get dropped. Let uvicorn own signals; put teardown after `yield`.
- **`@app.on_event("startup")` / `("shutdown")`** — deprecated, cannot guarantee reverse-ordered teardown, and can't share local state across the boundary. Use one `lifespan` generator.
- **Module-scope `app = FastAPI()` with globals** — makes the composition root un-injectable; tests can't substitute fakes. Build in `create_app()`.
- **Closing the pool before stopping the consumer** — yanks connections out from under an in-flight consume/write. Teardown is strict reverse order.
- **A dependency check on the liveness path** — one Postgres blip becomes a fleet-wide kill-and-restart storm. Liveness returns 200 unconditionally.
- **A readiness check with side effects** — a probe that writes, or runs a business query instead of a `SELECT 1`, turns probe frequency into accidental load.
- **Unbounded uvicorn drain** — a drain deadline at or above the pod grace period means Kubernetes `SIGKILL`s mid-drain. Size it under the grace period with margin.
- **Constructing the pool inside a router or repository** — bypasses the composition root and makes lifecycle untrackable. All wiring lives in `lifespan`; handlers read it off `app.state`/`Depends`.

---

## Output Format

`app/main.py` (the `lifespan`, `create_app()`, and the `uvicorn.run` entrypoint) and `app/config.py` (`Settings`), built exactly to the standard above — not a skeleton to fill in freely:

- `lifespan` follows the fixed startup order, `yield`, then strict reverse teardown, each stage boundary visible as a comment a reviewer can check without re-deriving.
- No `signal.*` handler exists in application code — uvicorn owns graceful shutdown; its drain deadline is set below the Kubernetes grace period.
- `create_app()` returns a fresh app with routers mounted and the `DomainError` exception boundary registered; there is no module-level singleton.
- `/healthz/live` returns 200 with no dependency call; `/healthz/ready` checks the pool with a bounded query and reflects the readiness gate.
- `config.py`'s `Settings` is a Pydantic `BaseSettings` that aggregates all validation errors at startup, never returning on the first.

Full worked lifespan + app factory + config: `references/lifespan-and-startup.md`. Full uvicorn config, SIGTERM handling, and health-endpoint standard: `references/server-and-health.md`.
