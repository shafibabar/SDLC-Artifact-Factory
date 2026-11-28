# Python Service Saturation from Official Documentation: uvicorn limits, asyncpg pools, event-loop lag and runtime metrics
**Authors:** The Uvicorn project (encode/uvicorn); Gunicorn authors (benoitc/gunicorn); MagicStack (asyncpg); Python Software Foundation (docs.python.org); The Prometheus Authors (client_python); OpenTelemetry Authors (opentelemetry-python-contrib); AnyIO, Starlette and FastAPI authors
**Domain:** Testing (load and performance, Python services)

Accessed 2026-11-28. uvicorn 0.54.0, 2026-09-25, BSD-3-Clause (https://pypi.org/pypi/uvicorn/0.54.0/json), docs and source read at tag `0.54.0`. gunicorn 27.0.1, 2026-11-12, MIT (https://pypi.org/pypi/gunicorn/27.0.1/json). asyncpg 0.32.0, 2026-10-06, Apache-2.0 (https://pypi.org/pypi/asyncpg/0.32.0/json), source read at tag `v0.32.0`. Python docs at https://docs.python.org/3/, which showed "Python 3.15.2 documentation". prometheus-client 0.26.0, 2026-07-24, "Apache-2.0 AND BSD-2-Clause" (https://pypi.org/pypi/prometheus-client/json), read at tag `v0.26.0`. opentelemetry-instrumentation-system-metrics 0.66b2, 2026-10-29, Apache-2.0, classifier "Development Status :: 4 - Beta" (https://pypi.org/pypi/opentelemetry-instrumentation-system-metrics/json), read at tag `v0.66b2`. anyio 4.16.0, 2026-11-01, MIT; starlette 1.10.0, 2026-10-24, BSD-3-Clause (docs read at tag `1.10.0`); fastapi 0.165.0, 2026-11-18, MIT.

Sources:
- [US] https://raw.githubusercontent.com/encode/uvicorn/0.54.0/docs/settings.md
- [UD] https://raw.githubusercontent.com/encode/uvicorn/0.54.0/docs/deployment/index.md
- [UC] https://raw.githubusercontent.com/encode/uvicorn/0.54.0/uvicorn/config.py
- [UH] https://raw.githubusercontent.com/encode/uvicorn/0.54.0/uvicorn/protocols/http/h11_impl.py
- [UF] https://raw.githubusercontent.com/encode/uvicorn/0.54.0/uvicorn/protocols/http/flow_control.py
- [USV] https://raw.githubusercontent.com/encode/uvicorn/0.54.0/uvicorn/server.py
- [GS] https://raw.githubusercontent.com/benoitc/gunicorn/27.0.1/docs/content/reference/settings.md
- [AP] https://magicstack.github.io/asyncpg/current/api/index.html
- [APS] https://raw.githubusercontent.com/MagicStack/asyncpg/v0.32.0/asyncpg/pool.py
- [APC] https://raw.githubusercontent.com/MagicStack/asyncpg/v0.32.0/asyncpg/compat.py
- [AT] https://docs.python.org/3/library/asyncio-task.html
- [AD] https://docs.python.org/3/library/asyncio-dev.html
- [AE] https://docs.python.org/3/library/asyncio-eventloop.html
- [DM] https://docs.python.org/3/library/devmode.html
- [PC] https://raw.githubusercontent.com/prometheus/client_python/v0.26.0/docs/content/collector/_index.md
- [PM] https://raw.githubusercontent.com/prometheus/client_python/v0.26.0/docs/content/multiprocess/_index.md
- [OS] https://raw.githubusercontent.com/open-telemetry/opentelemetry-python-contrib/v0.66b2/instrumentation/opentelemetry-instrumentation-system-metrics/src/opentelemetry/instrumentation/system_metrics/__init__.py
- [OR] https://raw.githubusercontent.com/open-telemetry/opentelemetry-python-contrib/v0.66b2/instrumentation/README.md
- [AY] https://anyio.readthedocs.io/en/stable/threads.html
- [ST] https://raw.githubusercontent.com/Kludex/starlette/1.10.0/docs/threadpool.md
- [FA] https://fastapi.tiangolo.com/async/

## Core Concepts

**uvicorn limits**
- `--limit-concurrency`: "Maximum number of concurrent connections or tasks to allow, before issuing HTTP 503 responses" [US]; default `None`, no limit [UC].
- Exceeding it rejects, it does not queue: when `len(connections)` or `len(tasks)` reaches the limit, the request is served by `service_unavailable` instead of the app and "Exceeded concurrency limit." is logged as a warning [UH]. That app sends status 503, `content-type: text/plain; charset=utf-8`, `connection: close`, body `Service Unavailable` [UF]. The count is per server process (source; the docs do not say per worker).
- `--backlog`: "Maximum number of connections to hold in the TCP accept queue, passed to the socket's `listen()` call", default 2048 [US].
- `--workers`: "Number of worker processes. Defaults to the `$WEB_CONCURRENCY` environment variable if available, or 1" [US]. Workers are started with spawn: "Unlike gunicorn, uvicorn does not use pre-fork" [UD]. Whether workers share state: not stated; each is a separate process, so in-process state (a rate limiter, a cache, `--limit-concurrency`'s counter) is per worker (inference from [UD] [UH]).
- `--timeout-keep-alive`: closes keep-alive connections with no new data within the timeout, default 5 s [US].
- `--limit-max-requests`: "Maximum number of requests to service before terminating the process", default `None`; `--limit-max-requests-jitter` default 0 [US] [UC]. On reaching it the process logs "Maximum request limit of %d exceeded. Terminating process." [USV].
- `--timeout-graceful-shutdown`: "Maximum number of seconds to wait for graceful shutdown", default `None` [US] [UC]. On expiry running tasks are cancelled and "Cancel %s running task(s), timeout graceful shutdown exceeded" is logged; with `None` the server waits for connections and tasks with no bound unless forced by a second SIGINT [USV].
- `--timeout-worker-healthcheck`: seconds to wait for a worker to answer a healthcheck, default 5 [US].

**Gunicorn with the uvicorn worker**
- uvicorn's deployment page shows `gunicorn -k uvicorn.workers.UvicornWorker`, says "The `uvicorn.workers` module is deprecated and will be removed in a future release", points to the separate `uvicorn-worker` package, and says "`--limit-concurrency` [is] not yet supported when running with Gunicorn" [UD].
- gunicorn: `--workers` default 1, "generally in the `2-4 x $(NUM_CORES)` range"; `--worker-connections` default 1000, "only affects the `gthread` and `gevent` worker types"; `--timeout` default 30, "Workers silent for more than this many seconds are killed and restarted", and for non-sync workers "it just means that the worker process is still communicating"; `--graceful-timeout` default 30; `--backlog` default 2048 [GS].

**asyncpg pool**
- `create_pool(dsn=None, *, init_size=None, min_size=10, max_size=10, max_queries=50000, max_inactive_connection_lifetime=300.0, connect=None, setup=None, init=None, reset=None, ...)` [AP]. `max_queries`: queries after which a connection is replaced; `max_inactive_connection_lifetime`: idle connections above `min_size` closed after this many seconds, 0 disables [AP].
- `command_timeout` is not a named `create_pool` parameter; it passes through `**connect_kwargs` to `connect()`, "The default timeout for operations on this connection" [AP].
- `Pool.acquire(*, timeout=None)`: "A timeout for acquiring a Connection" [AP]. With `timeout=None` the source awaits the free-connection queue (an `asyncio.LifoQueue` subclass) with no bound; otherwise it uses `compat.wait_for` [APS], which is `asyncio.wait_for` on Python 3.12+ [APC]. `asyncio.wait_for` raises `TimeoutError` on expiry (builtin since 3.11) [AT]. The asyncpg docs name no exception: not stated.
- Introspection: `get_size()`, `get_idle_size()`, `get_min_size()`, `get_max_size()` (added 0.25.0), `get_init_size()` (0.32.0), `is_closing()` (0.28.0) [AP]. A waiter count is not listed: not stated.

**asyncio event-loop lag**
- Debug mode is enabled by `PYTHONASYNCIODEBUG=1`, Python Development Mode, `asyncio.run(..., debug=True)` or `loop.set_debug()` [AD]. Development Mode is `-X dev` or `PYTHONDEVMODE=1` and turns on asyncio debug mode [DM].
- In debug mode: non-threadsafe APIs raise when called from the wrong thread; slow I/O selector calls are logged; "Callbacks taking longer than 100 milliseconds are logged" [AD]. `loop.slow_callback_duration`: "Default value is 100 milliseconds" [AE].
- Cost: Development Mode "introduces additional runtime checks that are too expensive to be enabled by default" [DM]; asyncio "runs in production mode" by default [AD]. A plain "not for production" sentence is not stated.
- An event-loop lag metric or API: not stated in the standard library [AE] [AD]; `loop.time()` is the loop's monotonic clock [AE].

**Runtime metrics**
- prometheus_client default process collector: `process_cpu_seconds_total`, `process_virtual_memory_bytes`, `process_resident_memory_bytes`, `process_start_time_seconds`, `process_open_fds`, `process_max_fds`, "only currently available on Linux"; platform collector: `python_info`; GC collector: `python_gc_objects_collected_total`, `python_gc_objects_uncollectable_total`, `python_gc_collections_total` [PC].
- Multiprocess mode: `PROMETHEUS_MULTIPROC_DIR` set from the startup shell (not Python) and wiped between runs. Limitations: "Custom collectors do not work (e.g. cpu and memory metrics)", gauges cannot use `set_function`, Info and Enum do not work, no pushgateway, no `pid` label on gauges, no exemplars, label remove/clear unsupported. Gauges take `multiprocess_mode` (`all` default, `min`, `max`, `sum`, `mostrecent`, `live*` variants); `mark_process_dead` is for gunicorn's `child_exit` hook [PM].
- OpenTelemetry system metrics 0.66b2 (Beta on PyPI; the contrib README lists semconv status "development") [OR]: defaults include `process.cpu.time`, `process.cpu.utilization`, `process.memory.usage`, `process.memory.virtual`, `process.open_file_descriptor.count`, `process.thread.count`, `process.context_switches`, `cpython.gc.collections`, `cpython.gc.collected_objects`, `cpython.gc.uncollectable_objects`; "Out-of-spec `process.runtime` prefixed metrics are deprecated and will be removed in future versions" [OS]. No event-loop metric is listed [OS].

**Threadpool for sync endpoints**
- FastAPI runs a plain `def` path operation or dependency "in an external threadpool" [FA]. Starlette: "The default thread pool size is only 40 _tokens_", shared with other libraries; raise it via AnyIO's limiter `total_tokens` [ST]. AnyIO: "The default AnyIO worker thread limiter has a value of 40" [AY]. What happens when the tokens are exhausted: not stated [ST].

## Actionable Techniques (design is this note's)

- In the gate, classify a 503 with body `Service Unavailable` and `connection: close` as uvicorn's concurrency shed, separate from application 5xx; both still count against the SLI [UF].
- Record `--workers`, replicas and `--limit-concurrency` with the result; overload must exceed per-subject rate × workers × replicas before a per-process rate limiter returns 429 [UD] (inference).
- Always pass `acquire(timeout=...)`; sample `get_size()` and `get_idle_size()` during the run; size = max and idle = 0 marks pool exhaustion [AP].
- Measure loop lag yourself: a task that sleeps a fixed interval and records `loop.time()` overshoot; run debug mode only in a diagnostic run, not the measured one [AE] [DM].
- With several workers and prometheus_client, expect no process metrics from the multiprocess registry; take CPU and memory from the container (cAdvisor) instead [PM] (inference).

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-load-test | uvicorn's own 503 not told apart from app failure | Reject-not-queue semantics, exact status, headers and body, warning log line |
| python-load-test | Per-process rate limits make 429s appear later than expected | Workers are separate spawned processes; Gunicorn does not support `--limit-concurrency` |
| python-load-test | Pool exhaustion not observed | Pool defaults, unbounded `acquire()` by default, `get_size`/`get_idle_size` |
| python-load-test | Runtime saturation signals | prometheus_client and OTel metric names; multiprocess limitations; 40-token threadpool |
| python-chaos-test | W3C-45: stalled event loop makes the process look hung | Debug mode, 100 ms slow-callback log, no stdlib lag metric |

## Caveats

- Nothing was run. No package was installed and no server, pool or loop was exercised.
- Pages were read through a fetch tool that summarises each page against a question; quotations were requested verbatim but not every page was read end to end.
- Not stated: whether uvicorn workers share state (inference from process model); the asyncpg acquire-timeout exception (traced through source to `asyncio.wait_for`; on Python < 3.12 asyncpg's `_asyncio_compat` was not read); a pool waiter-count API.
- Not stated: a stdlib event-loop lag metric; a quantified cost of asyncio debug mode; what Starlette does when the 40 tokens are exhausted (callers presumably wait; not confirmed).
- Not stated: whether prometheus_client's process and GC collectors are exported in multiprocess mode. The OTel contrib README marks system-metrics "Metrics support: No", which contradicts the package's purpose; read as served.
- The uvicorn-worker package and FastAPI's pages carry no pinned version; FastAPI was read as served.
