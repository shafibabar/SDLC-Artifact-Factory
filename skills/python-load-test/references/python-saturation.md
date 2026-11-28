# Observing a Python Service Under Load

Self-contained. Read when a run fails or goes INVALID and the cause is wanted, when a report needs the service's own measurements, when 503 answers appear, or when someone proposes sending k6's metrics to a monitoring system. Facts come from the official uvicorn 0.54.0, asyncpg 0.32.0, Python 3.15 and prometheus_client 0.26.0 documentation and source (research note `python-service-saturation-official-docs.md`); everything marked "run" was run on 2026-11-28 against a lab FastAPI service on 127.0.0.1 with k6 v2.4.0 and PostgreSQL 17.12 in a throwaway container. No Prometheus server was run for this skill: the query rules below are `go-load-test`'s, which were evaluated there.

## Contents
Three sources of a 5xx; the pool; the event loop; runtime metrics and several workers; reading Prometheus for a run; what belongs elsewhere.

## Three sources of a 5xx, and how the gate treats each

| Answer | Comes from | How to tell | Run |
|---|---|---|---|
| 503, body `Service Unavailable`, `text/plain`, `connection: close` | **uvicorn itself**, at `--limit-concurrency`: it rejects, it does not queue, and logs "Exceeded concurrency limit." The application never sees the request, so its own request metrics do not count it | The Python `journey.js` counts it as `server_shed`; the application's request counter is lower than k6's count by exactly these | 252 of 324 at 24 a second with the limit at 10 (50 ms per request); the application counted 74 answers, all 200 |
| Any other 5xx | **The application** (an unhandled error, or the service's own answer to an exhausted pool), or a proxy in front of it | `app_server_error`; it appears in the application's own metrics too | 70 answers 503 with a JSON body at a 0.2 s acquire timeout, all in the application's counter |
| No answer (status 0) | A refused, reset or timed-out connection: a crashed or killed worker, a proxy timeout | `no_answer` | Not observed: a worker killed with SIGKILL mid-run was restarted by uvicorn and the run showed no failure; whether k6 resent the request on a new connection or held no connection on that worker was not determined |

**The gate treats every one of them as the SLI defines it.** With the usual SLI ("a response that is not a 5xx"), each is a bad answer and counts in `http_req_failed`; the test never adds 503 to the good statuses to make a run pass. In the overload check uvicorn's 503 is a wrong answer: the limiter should have answered 429 first (run: `overload_wrong_answer` crossed, 223 of 400 answers were uvicorn's 503, FAIL). The split exists for the report and for the fix: a `server_shed` count means `--limit-concurrency` is below what the load needs (or below the virtual users' idle connections); an application 5xx means the service's own code or its pool. `../scripts/sort-server-errors.sh` prints it. If an SLO genuinely excludes deliberate shedding, that is `slo-definition`'s row to change, by id, never the test's.

Other facts that shape the 503 picture:

- `--limit-concurrency` is off by default, per process, and **counts open connections**, keep-alive ones included (run: ten idle connections, the eleventh request 503). k6 holds one connection per virtual user, so a limit at or below the virtual users answers 503 at almost any rate; `check-python-profile.sh` warns.
- Under Gunicorn, `--limit-concurrency` is not supported, and `uvicorn.workers` is deprecated in favour of the separate `uvicorn-worker` package (uvicorn's deployment page). Gunicorn's `--timeout` kills a worker silent for 30 s by default; what a client sees then (status 0, or a proxy's 502) was not run.
- uvicorn's own worker health check did not restart a worker whose event loop was blocked: four requests to a handler blocking for 8 s with `--workers 2 --timeout-worker-healthcheck 2` all answered 200 after 16 s, and no worker was replaced (run). A blocked loop shows as latency, not as a restart.
- k6 does not expose the `Connection` response header (run), so `journey.js` identifies uvicorn's 503 by body and content type.

## The database pool

asyncpg's `create_pool` defaults to `min_size=10, max_size=10`, per process. `Pool.acquire(timeout=None)` waits with no limit: a pool too small for the load makes **every request wait**, so exhaustion shows as rising latency and no error.

| Run: pool of 2, 100 ms queries, 24 a second, one process | Result |
|---|---|
| `acquire()` with no timeout | INVALID (exit 4): p(95) 2,198 ms, 34 iterations dropped (the virtual users ran out waiting), no error at all; `db_pool_in_use` 2 of 2 at every read during the run |
| `acquire(timeout=0.2)` | FAIL (exit 1): 70 answers 503 from the application, p(95) 311 ms, nothing dropped |

So: read `db_pool_in_use` against `db_pool_max` for every run (`../templates/saturation-metrics.md` exports them from `get_size()`, `get_idle_size()` and `get_max_size()`); in use equal to max through the hold, with latency climbing and no errors, is pool exhaustion. **Recommend an acquire timeout to the service's owner** (`python-service-layer`: its unit of work calls `pool.acquire()` without one) so exhaustion becomes an error the SLI counts and the latency stays bounded. The timeout value and the answer it maps to are the service's decision; this skill does not set them. The pool's total across processes is `max_size` times workers times replicas, and it must fit PostgreSQL's `max_connections` (`python-service-skeleton`).

## The event loop

One blocking call inside `async def` (a synchronous driver, `time.sleep`, heavy CPU work) stops every request that process holds. Python's standard library has **no event-loop lag metric**: asyncio's debug mode only logs callbacks slower than `slow_callback_duration` (100 ms by default) and its checks are too expensive to leave on. Measure it with a probe: a task that sleeps a fixed interval and records how late it wakes (`../templates/saturation-metrics.md`, histogram `event_loop_lag_seconds`).

Run: three blocking 500 ms calls during a quiet period raised the `le="1.0"` bucket by 3 and the `le="0.5"` bucket by 2 while `le="0.25"` did not move: each stall made the probe wake about half a second late; during average load five such calls turned the run FAIL (p(95) 388 ms against 300) while the probe read about half a second at each stall and under 5 ms otherwise. During pool exhaustion the probe stayed under 5 ms: the loop was free and the requests were waiting for a connection. That difference, a slow service with a free loop against a slow service with a blocked loop, is what the probe is for.

Plain `def` path operations run in a thread pool of 40 tokens by default (AnyIO, Starlette); what happens when the tokens are exhausted is not stated in the documentation and was not run.

## Runtime metrics, and several workers

- prometheus_client's `process_*` metrics (CPU, memory, file descriptors) exist **on Linux only** (run: on macOS the default registry held only `python_gc_*` and `python_info`). Take CPU, throttling and memory from the container (cAdvisor) in any case.
- With several workers, a scrape is answered by whichever process takes it (run: a counter read 215, 131, 132, 216, 133 on successive scrapes). Use prometheus_client's **multiprocess mode** (`PROMETHEUS_MULTIPROC_DIR`, set by the start-up shell and emptied between runs, `MultiProcessCollector` on `/metrics`): counters and histograms then add up across processes (run: 401, 402, 403, 404). Its limits: custom collectors (CPU and memory) and `set_function` do not work, so no `process_*` metrics at all (run), and gauges need a `multiprocess_mode` (`livesum` for pool use).
- OpenTelemetry's `process.runtime.*` metric names are deprecated (opentelemetry-instrumentation-system-metrics 0.66b2); use the `process.*` and `cpython.*` names if that library is the source.

## Reading Prometheus for a run

Read only the Prometheus of the environment under test, push nothing into any monitoring system (no `--out` to a remote write, no annotations on shared dashboards; k6's `experimental-prometheus-rw` and `influxdb` outputs are deprecated since v2.4.0), and pin every query to the run: evaluate at the result file's `ended` with a range equal to the run's length. A fixed window such as `[2h]` counts other traffic.

| Question | Query shape |
|---|---|
| Did uvicorn shed? | k6's `server_shed` count; the application's `sum by (code) (increase(<requests_total>[<length>s]))` shows only what reached it |
| Was the pool exhausted? | `max_over_time(db_pool_in_use[<length>s]) / max_over_time(db_pool_max[<length>s])`: 1 through the hold is exhaustion. Gauges are sampled at scrapes, so a short peak can be missed |
| Was the event loop blocked? | `histogram_quantile(0.99, sum by (le) (rate(event_loop_lag_seconds_bucket[<length>s])))`, and the count above the 0.1 s bucket |
| Throttled, or growing? | `increase(container_cpu_cfs_throttled_periods_total[...]) / increase(container_cpu_cfs_periods_total[...])`; `delta(container_memory_working_set_bytes[...])` and `max_over_time(...)` |
| Did it recover? | The same queries pinned to a window after `ended` |

`rate()` and `increase()` only on counters (`_total`, a histogram's `_bucket`, `_count`, `_sum`); on a gauge use `max_over_time()` or `delta()`. Prometheus answers `increase()` on a gauge with a number and only a note. Metric names come from `prometheus-metrics-design`.

## Boundary with `python-chaos-test`

This skill observes what the service does when its own request volume is the stress: the server's own 503, pool exhaustion and event-loop lag as they occur. Injecting a fault on purpose (a slow dependency, a deliberately stalled event loop, a killed worker) at ordinary volume is `python-chaos-test`'s experiment. Neither replaces the other.
