# Standard: Bike-Share Docks, the Lab That Was Run

Self-contained. Read for the whole procedure on a standard Python product, with every pattern present and proven both ways, the event-loop stall, a real Toxiproxy, and the runner's `pytest` and `toxiproxy` tools end to end. Run on 2026-11-28 on macOS arm64 with Python 3.15.2 in a uv 0.13.9 virtual environment: FastAPI 0.165.0, uvicorn 0.54.0, httpx 0.29.0, pytest 9.2.0, pytest-asyncio 1.5.0, purgatory 3.0.2, tenacity 9.2.1, pybreaker 1.4.1 (library facts only), prometheus-client 0.26.0, and Toxiproxy v2.13.0 (the official `toxiproxy-server-darwin-arm64`, SHA-256 `21e5d0cb…4705c` equal to the release's `checksums.txt`, bound to 127.0.0.1). The run marker was served by a stand-in `kubectl`; **no kind cluster and no Chaos Mesh were run for this skill** (that path is `go-chaos-test`'s, run there with the same runner: unverified here).

## Input

A city's bike-share. The `docks` service answers `GET /v1/dock-availability?station=` by calling the internal `stations` service on the hot path; it also serves a CPU-bound monthly usage report. SLO-DOCK-01: the share of dock-availability requests answered 200 in under 800 ms, objective 99 %. Two replicas, one uvicorn process each. Single-tenant: the product has no tenants, so no tenant experiment is planned (a tenancy experiment follows the product's own `multi-tenancy-design` decision, never an assumed physical isolation).

## Step 1: what the product implements

| Downstream | Pattern | Present? | Settings | integration-design |
|---|---|---|---|---|
| stations | Circuit breaker | yes (purgatory) | trips at 5 consecutive failed calls, 5 s reset, one probe (an `asyncio.Lock`, because purgatory admits every caller in half-open) | same |
| stations | Retry | yes (tenacity) | 3 attempts, full jitter, 100 ms doubling to 5 s, transient only | same |
| stations | Timeout | yes | 300 ms per attempt; the caller's `asyncio.timeout(0.7)` cancels the request | same; **but the 0.7 s deadline is shorter than the ~1.2 s retry envelope** (finding) |
| stations | Bulkhead | yes | `asyncio.Semaphore(8)`, acquire bounded to 10 ms | one pool per downstream |
| stations | Fallback | yes | last good answer, `X-Degraded: stale`; 503 + `Retry-After` if none | observable fallback |
| service | Event loop | yes | the usage report runs in `asyncio.to_thread` | (python-async-concurrency) |
| service | Lag probe | yes | `event_loop_lag_seconds`, copied from `python-load-test`'s `saturation-metrics.md` template | |

## The product's code (the lab)

These are the product's files the experiments ran against; a real product has its own. `app/observability/saturation.py` is `python-load-test`'s template, unchanged, and is not repeated here.

### `pyproject.toml`

```toml
[project]
name = "docks"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "fastapi==0.165.0",
    "uvicorn==0.54.0",
    "httpx==0.29.0",
    "purgatory==3.0.2",            # the lab's breaker; a product chooses its own
    "tenacity==9.2.1",             # the lab's retry policy
    "prometheus-client==0.26.0",
]

[dependency-groups]
dev = ["pytest==9.2.0", "pytest-asyncio==1.5.0"]

[tool.pytest.ini_options]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "function"
asyncio_default_test_loop_scope = "function"
strict = true
testpaths = ["tests"]
pythonpath = ["."]
```

### `app/downstream.py`

```python
# app/downstream.py: one resilient client per downstream, nested as integration-design orders it:
# bulkhead { circuit breaker { retry { timeout { call } } } } otherwise the caller's fallback.
import asyncio
from dataclasses import dataclass

import httpx
from purgatory import AsyncCircuitBreakerFactory
from purgatory.domain.model import OpenedState  # purgatory's open-state error; not exported by the package
from tenacity import AsyncRetrying, retry_if_exception_type, stop_after_attempt, wait_random_exponential


@dataclass(frozen=True)
class DownstreamConfig:
    """integration-design's "internal, hot path" row."""

    base_url: str
    breaker_failures: int = 5        # trips at 5 consecutive failed calls
    breaker_reset_s: float = 5.0     # open for 5 s, then one probe
    max_attempts: int = 3
    initial_backoff_s: float = 0.1   # full jitter: uniform(0, 0.1), then uniform(0, 0.2) ... capped at 5 s
    max_backoff_s: float = 5.0
    attempt_timeout_s: float = 0.3
    max_concurrent: int = 8          # this downstream's own pool
    acquire_timeout_s: float = 0.01  # a full pool refuses at once


class Unavailable(Exception):
    """Every way the downstream can be unavailable: breaker open, pool full, retries used up."""


class Transient(Exception):
    """5xx or 429: worth another attempt."""


class Permanent(Exception):
    """4xx: tried once, never retried, and not a breaker failure."""


class DownstreamClient:
    def __init__(self, name: str, config: DownstreamConfig, transport: httpx.AsyncBaseTransport | None = None) -> None:
        self.name = name
        self.config = config
        self._http = httpx.AsyncClient(base_url=config.base_url, transport=transport, timeout=config.attempt_timeout_s)
        # The caller's own cancellation and a permanent answer are not the downstream failing.
        self._breakers = AsyncCircuitBreakerFactory(
            default_threshold=config.breaker_failures, default_ttl=config.breaker_reset_s,
            exclude=[asyncio.CancelledError, Permanent])
        self.transitions: list[str] = []
        self._breakers.add_listener(self._on_event)
        self._pool = asyncio.Semaphore(config.max_concurrent)
        self._probe = asyncio.Lock()

    def _on_event(self, name: str, event_type: str, payload: object) -> None:
        if event_type == "state_changed":
            self.transitions.append(payload.state)  # "closed", "opened", "half-opened"

    async def breaker_state(self) -> str:
        return (await self._breakers.get_breaker(self.name)).context.state

    async def get_json(self, path: str) -> dict:
        try:
            async with asyncio.timeout(self.config.acquire_timeout_s):
                await self._pool.acquire()
        except TimeoutError:
            raise Unavailable(f"{self.name}: bulkhead full") from None
        try:
            breaker = await self._breakers.get_breaker(self.name)
            if breaker.context.state == "closed":
                async with breaker:
                    return await self._with_retry(path)
            # purgatory lets every concurrent caller through in half-open; integration-design allows one probe.
            if self._probe.locked():
                raise Unavailable(f"{self.name}: circuit half-open, probe in flight")
            async with self._probe, breaker:
                return await self._with_retry(path)
        except OpenedState:
            raise Unavailable(f"{self.name}: circuit open") from None
        except (Transient, httpx.TransportError, TimeoutError) as exc:
            # An attempt's own timeout ends here as Unavailable, never as the caller's TimeoutError.
            raise Unavailable(f"{self.name}: {exc!r}") from exc
        finally:
            self._pool.release()

    async def _with_retry(self, path: str) -> dict:
        retrying = AsyncRetrying(
            stop=stop_after_attempt(self.config.max_attempts),
            wait=wait_random_exponential(multiplier=self.config.initial_backoff_s, max=self.config.max_backoff_s),
            retry=retry_if_exception_type((Transient, httpx.TransportError, TimeoutError)),
            reraise=True,
        )
        async for attempt in retrying:
            with attempt:
                async with asyncio.timeout(self.config.attempt_timeout_s):
                    answer = await self._http.get(path)
                if answer.status_code >= 500 or answer.status_code == 429:
                    raise Transient(f"{self.name} answered {answer.status_code}")
                if answer.status_code >= 400:
                    raise Permanent(f"{self.name} answered {answer.status_code}")
                return answer.json()
        raise AssertionError("unreachable: tenacity re-raises the last attempt")

    async def aclose(self) -> None:
        await self._http.aclose()
```

### `app/main.py`

```python
# app/main.py: the docks service. GET /v1/dock-availability calls the internal stations service on the hot path.
import asyncio
import hashlib
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, Response
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

from app.downstream import DownstreamClient, DownstreamConfig, Permanent, Unavailable
from app.observability.saturation import watch_saturation

CALLER_DEADLINE_S = 0.7  # under SLO-DOCK-01's 800 ms


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.stations = DownstreamClient("stations", DownstreamConfig(os.environ.get("STATIONS_URL", "http://stations:8080")))
    app.state.last_good = {}
    probe = asyncio.create_task(watch_saturation())
    yield
    probe.cancel()
    await app.state.stations.aclose()


app = FastAPI(lifespan=lifespan)


@app.get("/healthz")
async def healthz() -> dict:
    return {"status": "ok"}


@app.get("/metrics")
async def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/v1/dock-availability")
async def dock_availability(station: str, response: Response) -> dict:
    try:
        async with asyncio.timeout(CALLER_DEADLINE_S):
            answer = await app.state.stations.get_json(f"/v1/stations/{station}")
    except Permanent:
        response.status_code = 404
        return {"error": "unknown station"}
    except (Unavailable, TimeoutError):
        if station in app.state.last_good:
            response.headers["X-Degraded"] = "stale"
            return app.state.last_good[station]
        response.status_code = 503
        response.headers["Retry-After"] = "5"
        return {"error": "stations unavailable"}
    app.state.last_good[station] = answer
    return answer


def _usage_digest(rounds: int) -> str:
    """CPU-bound: a month of dock events folded into one digest."""
    digest = b""
    for i in range(rounds):
        digest = hashlib.sha256(digest + i.to_bytes(8, "big")).digest()
    return digest.hex()


@app.get("/v1/usage-report")
async def usage_report(rounds: int = 400_000) -> dict:
    # CPU-bound work leaves the event loop: the worker keeps answering while it runs.
    return {"digest": await asyncio.to_thread(_usage_digest, rounds)}
```

## Output: the run

Tests from `../templates/pattern-tests.md`, `../templates/event-loop-stall.md` and `../templates/toxiproxy-setup.md`, support from `../templates/chaos-support.md`, all extracted from these pages and run:

| Run | Result |
|---|---|
| The pattern tests, five times in a row | `5 passed` each time (about 6.5 s) |
| A bare `pytest tests/chaos` (no runner) | `5 errors`, each `CHAOS-REFUSED`; `-m "not chaos"` deselected all 5 |
| Runner, `patterns-in-process` (`pytest`), correct product | `== PASS ... every pattern assertion held (8 pytest test(s))`; `Toxiproxy reset answered 204; toxics left on: none`; exit 0 |
| Runner, the same on the breaker-that-never-trips copy | `== FAIL ... pytest: 2 failed, 0 error(s) of 5`; exit 1 |
| Runner, a misspelt toxic type | `== INVALID ... Toxiproxy answered 400: {"error":"invalid toxic type","status":400} (no fault was injected)` |
| Runner, a selection that collected nothing | `== INVALID ... pytest collected no test (exit 5)`; exit 4 |
| Runner, an all-skipped selection | `== INVALID ... pytest skipped 1 of 1 test(s): a skipped experiment proves nothing` |
| Runner, `toxiproxy` tool, 2 s latency, loopback statement, correct product | `== PASS`: SLI 1.000 before (50 requests), during (29) and after; `DELETE answered 204; the proxy no longer lists the toxic` |
| The same on a copy with no fallback | `abort condition: ... was 0.000 over the last 5 s, below 0.9; the fault was removed at once`; FAIL; no toxic left |

The loopback statement was a lab device (`approved_by` said "lab (not a product-owner sign-off)"); a real statement is the product owner's.

## Each pattern, both ways

| Pattern | Correct product | Broken copy | Failure message |
|---|---|---|---|
| Breaker | pass | threshold × 1000 in the factory | `after 5 consecutive failed call(s) (threshold 5): breaker is closed, want opened` |
| Breaker, one probe | pass | the `asyncio.Lock` removed | `half-open let 15 requests through from 5 callers, want one probe call (3 attempts)` |
| Breaker, the 1.2.0 one-call test | (n/a) | threshold × 1000 | **passed** in 0.11 s; the breaker read `closed` |
| Retry | pass | tenacity's `stop` removed | `the call did not return within 5.0s: a retry with no bound, or a deadline that never fired` (3 tests) |
| Timeout | pass | `asyncio.shield` around the request | `the dependency saw its request end 0.310s after it arrived, past the caller's 0.1s deadline` |
| Cancellation not a failure | pass | `CancelledError` not excluded | `after 5 calls the caller cancelled: breaker is opened, want closed` |
| Bulkhead | pass | one semaphore for both clients | `another downstream's pool was exhausted too: weather: bulkhead full` |
| Event loop | pass (stalled worker 913 ms, other 1 ms, after 2 ms; lag over 0.5 s 0 → 1) | the report computed on the loop | `the whole worker looks hung: its health check took 1231 ms while the usage report ran (1.3 s)` |
| Degradation (deployed) | pass | no fallback | the runner aborted at an SLI of 0.000 |

## Findings for the report

- **Budgets do not nest:** under 2 s of latency every answer came at about 700 ms, the caller's deadline, so every call ended as the caller's cancellation and the breaker never opened; the fallback held the SLI at 1.000, with 100 ms to spare. Corrective action for `backend-engineer`: a caller deadline above the retry envelope, or fewer or shorter attempts (`integration-design` §2).
- **purgatory admits every caller in half-open**; the product's lock is what gives one probe. A product on purgatory without it fails the one-probe assertion.

## What the report says it does not prove

A passing run shows these faults did not break SLO-DOCK-01 in this run. It does not show: behaviour in the real cluster network (no kind run here), a pod kill, a broker outage (no broker), shedding under the product's own load (`python-load-test`), a `--workers N` deployment (two separate processes were used), or any combination of faults.
