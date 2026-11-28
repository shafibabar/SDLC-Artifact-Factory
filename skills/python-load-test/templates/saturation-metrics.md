# Saturation Metrics a Load Test Reads from a FastAPI Service

Self-contained. Copy when a Python service under load test does not yet export its database-pool use and its event-loop lag. These are measurements for observing a run, not part of the test: the module belongs to the service (its lifespan is `python-service-skeleton`'s, its metric names are `prometheus-metrics-design`'s), and this page only holds what the load test needs it to expose. `db_pool_in_use` and `db_pool_max` are the names `prometheus-metrics-design` already uses; `event_loop_lag_seconds` is new and is proposed to it.

Run on 2026-11-28 (Python 3.15.2, FastAPI 0.165.0, uvicorn 0.54.0, asyncpg 0.32.0, prometheus-client 0.26.0, PostgreSQL 17.12 in a throwaway container, macOS arm64): the file below was extracted from this page, started from a lab service's lifespan, and read through `/metrics` during load, with one process and with four workers in multiprocess mode.

## Why these, and why a probe

- **No standard metric exists for either.** Python's standard library has no event-loop lag metric (asyncio's debug mode only logs callbacks slower than `slow_callback_duration`, 100 ms by default, and costs too much to leave on); prometheus_client's default registry offers `python_gc_*` and `python_info`, and its `process_*` metrics exist on Linux only (run: on macOS the default registry held only the four `python_*` names). asyncpg's pool exposes `get_size()`, `get_idle_size()` and `get_max_size()` but exports nothing.
- **Pool exhaustion is silent by default.** `pool.acquire()` waits with no limit unless it is given a timeout, so a pool that is too small shows as rising latency, not as errors (run: p(95) 2,189 ms and no error at all). The gauges show the cause: in use equal to the maximum through the run.
- **A blocked event loop stops everything in that process.** A blocking call inside `async def` (here `time.sleep`) stalls every request the process holds. The probe measures how late a fixed sleep wakes up: under 5 ms normally, about half a second at each 500 ms stall (run).

### `app/observability/saturation.py`

```python
# app/observability/saturation.py: database-pool use and event-loop lag, for reading a service under load.
# Start watch_saturation(pool) as a task from the lifespan; prometheus_client exposes the metrics on /metrics.
import asyncio

from prometheus_client import Gauge, Histogram

# livesum: with several workers in multiprocess mode, the values of the live processes are added up.
POOL_IN_USE = Gauge("db_pool_in_use", "asyncpg connections checked out of the pool", multiprocess_mode="livesum")
POOL_MAX = Gauge("db_pool_max", "asyncpg pool max_size", multiprocess_mode="livesum")
LOOP_LAG = Histogram(
    "event_loop_lag_seconds",
    "How late a fixed asyncio sleep woke up: time this process's event loop could run nothing else",
    buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5),
)


async def watch_saturation(pool=None, interval: float = 0.05) -> None:
    """Sleep a fixed interval, record how late the wake-up was, and refresh the pool gauges. Cancel on shutdown."""
    loop = asyncio.get_running_loop()
    while True:
        started = loop.time()
        await asyncio.sleep(interval)
        LOOP_LAG.observe(max(0.0, loop.time() - started - interval))
        if pool is not None:
            POOL_IN_USE.set(pool.get_size() - pool.get_idle_size())
            POOL_MAX.set(pool.get_max_size())
```

Start it after the pool is open, and cancel it before the pool closes:

```text
probe = asyncio.create_task(watch_saturation(app.state.pool))
yield
probe.cancel()
```

## What was seen

| Case | `/metrics` during the run |
|---|---|
| One process, pool of 2, 24 requests a second of 100 ms queries (verdict INVALID: p(95) 2,198 ms, 34 iterations dropped, no error) | `db_pool_in_use 2.0` and `db_pool_max 2.0` at each of 16 reads a second apart during the run (1.0 before and after); all 335 lag observations under 0.005 s: the loop was free, the requests were waiting for a connection |
| One process, three blocking 500 ms calls | `event_loop_lag_seconds_bucket{le="0.25"}` stayed at 2, `le="1.0"` rose from 2 to 5 (one per stall) and `le="0.5"` from 2 to 4: each stall made the probe wake about half a second late |
| Four workers, `PROMETHEUS_MULTIPROC_DIR` set and `/metrics` built from `MultiProcessCollector` | One `db_pool_in_use` and one `db_pool_max` line, the sums over the four processes (`db_pool_max 8.0` for four pools of 2, on three scrapes in a row); one set of lag buckets for all processes; no `process_*` or `python_gc_*` line at all |
| Four workers **without** multiprocess mode | Each scrape answered from whichever worker took it: a request counter read 215, 131, 132, 216, 133 on successive scrapes |

## Rules that follow

- **Several workers need prometheus_client's multiprocess mode**, or a scrape describes one process chosen at random. `PROMETHEUS_MULTIPROC_DIR` is set by the start-up shell, not in Python, and emptied between runs; custom collectors and `set_function` do not work in that mode, which is why the probe sets the gauges itself. One uvicorn process per container (`python-dockerfile`) avoids the question: each replica is scraped separately.
- **CPU and memory come from the container**, not from prometheus_client: `container_cpu_cfs_throttled_periods_total`, `container_memory_working_set_bytes` (cAdvisor), as `./load-test-report.md` lists.
- **Set an acquire timeout in the service** so exhaustion becomes visible as an error the SLI counts (run: 70 answers 503 at a 0.2 s timeout, p(95) bounded at 311 ms). The value and the answer it maps to are the service's decision (`python-service-layer` owns the unit of work that acquires the connection); this skill only reads the result.
- **The gauges are sampled at each scrape.** A peak between two scrapes is missed; the lag histogram is not, because every probe interval is counted.
