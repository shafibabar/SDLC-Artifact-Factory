# Python Resilience Libraries from Official Documentation: pybreaker, aiobreaker, purgatory, tenacity, asyncio, testcontainers
**Authors:** Daniel Fernandes Martins (danielfm/pybreaker); Arlyon (arlyon/aiobreaker); Guillaume Gauvrit (mardiros/purgatory); Julien Danjou (jd/tenacity); Python Software Foundation (docs.python.org); Testcontainers project (testcontainers-python); Docker Inc. (docker-py)
**Domain:** Testing (chaos and resilience, Python)

Accessed 2026-11-28. pybreaker 1.4.1, 2025-09-21, BSD (classifier; no licence expression), requires Python >=3.9, "Development Status :: 5 - Production/Stable" (https://pypi.org/pypi/pybreaker/json), source read at tag `v1.4.1`. aiobreaker 1.2.0, 2021-05-17, BSD, requires Python >=3.6, only 3.6 classified (https://pypi.org/pypi/aiobreaker/json); last repository commit 2021-12-27. purgatory 3.0.2, 2026-11-11, MIT, requires Python >=3.11, Production/Stable (https://pypi.org/pypi/purgatory/json); source read on `main` (the tag URL returned 404). tenacity 9.2.1, 2026-10-07, Apache-2.0, requires Python >=3.10 (https://pypi.org/pypi/tenacity/json); source read on `main`. Python docs header "Python 3.15.2 documentation". testcontainers 4.15.0, 2026-07-24, Apache-2.0, requires Python >=3.10 (https://pypi.org/pypi/testcontainers/json); source and docs read on `main`. docker-py docs "stable", no version stated.

Sources:
- [PB] https://raw.githubusercontent.com/danielfm/pybreaker/v1.4.1/src/pybreaker/__init__.py ; [PBR] https://raw.githubusercontent.com/danielfm/pybreaker/v1.4.1/README.rst
- [AB] https://raw.githubusercontent.com/arlyon/aiobreaker/master/aiobreaker/circuitbreaker.py ; [ABS] .../aiobreaker/state.py ; [ABG] https://github.com/arlyon/aiobreaker ; [ABC] https://api.github.com/repos/arlyon/aiobreaker/commits?per_page=1
- [PG] https://raw.githubusercontent.com/mardiros/purgatory/main/src/purgatory/service/_async/circuitbreaker.py ; [PGM] .../src/purgatory/domain/model.py ; [PGI] .../src/purgatory/__init__.py ; [PGD] https://mardiros.github.io/purgatory/ ; [PGL] https://mardiros.github.io/purgatory/user/changelog.html ; [PGO] https://mardiros.github.io/purgatory/user/monitoring.html
- [TD] https://tenacity.readthedocs.io/en/latest/ ; [TI] https://raw.githubusercontent.com/jd/tenacity/main/tenacity/__init__.py ; [TW] https://raw.githubusercontent.com/jd/tenacity/main/tenacity/wait.py
- [SY] https://docs.python.org/3/library/asyncio-sync.html ; [TK] https://docs.python.org/3/library/asyncio-task.html
- [TC] https://raw.githubusercontent.com/testcontainers/testcontainers-python/main/src/testcontainers/core/container.py ; [TL] .../core/labels.py ; [TDC] .../core/docker_client.py ; [TN] .../docs/features/networking.md ; [TG] .../docs/features/garbage_collector.md
- [DP] https://docker-py.readthedocs.io/en/stable/containers.html

## Core Concepts

**pybreaker 1.4.1**
- `CircuitBreaker(fail_max=5, reset_timeout=60, success_threshold=1, exclude=None, listeners=None, state_storage=None, name=None, throw_new_error_on_trip=True)` [PB].
- Trips **at** the threshold: closed-state `on_failure` checks `counter >= fail_max`, so the fail_max-th consecutive failure opens it [PB].
- The tripping call raises `CircuitBreakerError("Failures threshold reached, circuit breaker opened")`, not the original error, unless `throw_new_error_on_trip=False`, which re-raises the original [PB].
- Open: before `reset_timeout` elapses, calls raise `CircuitBreakerError("Timeout not elapsed yet, circuit breaker still open")` without running the function; after it, the next call moves to half-open and runs as the trial [PB].
- Half-open: closes when `success_counter >= success_threshold` (one success by default); any failure reopens it ("Trial call failed, circuit breaker opened") [PB] [PBR].
- `call` holds a per-instance `threading.RLock` while the function runs, so calls on one breaker are serialised in-process and half-open sees one trial at a time; nothing limits trials across processes sharing Redis storage [PB].
- Inspection: `current_state` returns `"open"`, `"half-open"` or `"closed"`; `fail_counter` is consecutive failures; `success_counter`; `open()`, `half_open()`, `close()` force state [PB] [PBR].
- `exclude` takes exception classes or predicates; a match counts as success and resets the failure count [PB].
- Storage: `CircuitMemoryStorage` (default) or `CircuitRedisStorage(state, redis_object, namespace=None, fallback_circuit_state=STATE_CLOSED, cluster_mode=False)`; do not create the Redis client with `decode_responses=True` [PB] [PBR].
- Async: `call_async` uses Tornado's `@gen.coroutine` and requires Tornado ("Optional support for asynchronous Tornado calls"); no asyncio support is stated [PB] [PBR]. Its RLock is held across the `yield`.

**aiobreaker 1.2.0**
- "a fork of pybreaker ... replaces tornado with native asyncio" [ABG]. `CircuitBreaker(fail_max=5, timeout_duration: Optional[timedelta]=None, exclude=None, listeners=None, state_storage=None, name=None)`; unset timeout means 60 s [AB].
- `call` and `async def call_async`; as a decorator it picks the async wrapper when `inspect.iscoroutinefunction(func)` [AB].
- Trips at `counter >= fail_max` and the tripping call raises `CircuitBreakerError` with the original as `__cause__`; half-open closes on one success and reopens on one failure [ABS].
- `current_state` returns a `CircuitBreakerState` enum member (`OPEN`, `CLOSED`, `HALF_OPEN`), not a string; `fail_counter`; `CircuitBreakerError` has `time_remaining` and `sleep_until_open()` [AB] [ABS].
- Maintenance: last release 2021-05-17, last commit 2021-12-27, only Python 3.6 classified, README calls it a packaging learning exercise; no deprecation or archive notice [ABG] [ABC]. Treat as unmaintained.

**purgatory 3.0.2**
- `AsyncCircuitBreakerFactory(default_threshold=5, default_ttl=30, exclude=None, uow=None)` and `SyncCircuitBreakerFactory`; `get_breaker(circuit, threshold=None, ttl=None, exclude=None)`; use `async with await cb.get_breaker("name"):` or `@cb("name")` on an `async def` [PG] [PGD].
- TTL is compared against `time.time()`, so seconds (inference from source; the unit is not stated) [PGM].
- Trips at `failure_count >= threshold` (consecutive; reset on success) but the **tripping call re-raises the original exception**; only later calls raise `OpenedState` ("Circuit {name} is open"), an `Exception` subclass defined in `purgatory.domain.model` and not exported in `__all__` [PGM] [PGI].
- After the TTL the next request runs in half-open; one success closes it, any exception reopens it; no concurrency limit on trials and no lock in the service code [PGM] [PG].
- State strings `"closed"`, `"opened"`, `"half-opened"` on the breaker's context (`.state`, `.failure_count`, `.opened_at`) [PGM]; events via `add_listener(hook)` with `hook(circuit_name, evt_type, payload)`, `evt_type` `"state_changed"` or `"failed"` [PGO].
- Storage: in-memory or Redis unit of work (`AsyncInMemoryUnitOfWork`, `AsyncRedisUnitOfWork`) [PGI]. 3.0.2 drops Python 3.9 and 3.10; 3.0.0 changed the licence to MIT [PGL].

**tenacity 9.2.1**
- Bare `@retry` "retry[s] forever without waiting" [TD]. Defaults: `stop=stop_never`, `wait=wait_none()`, `retry=retry_if_exception_type()`, `reraise=False`, `before_sleep=None` [TI].
- `stop_after_attempt(n)` caps attempts; `stop_after_delay(s)` caps elapsed seconds; combine with `|` [TD].
- `wait_exponential(multiplier=1, max=MAX_WAIT, exp_base=2, min=0)`: "no jitter" [TW]. `wait_random_exponential` (same parameters) is "Full Jitter": `uniform(min, clamped exponential)` [TW]. `wait_exponential_jitter(initial=1, max, exp_base=2, jitter=1, min=0, multiplier=1)` adds `uniform(0, jitter)` before clamping [TW].
- Stop reached: raises `RetryError` (with `last_attempt`) chained from the last exception; `reraise=True` raises the last attempt's own exception instead [TD] [TI].
- `before_sleep=before_sleep_log(logger, level)` fires only before a retry [TD].
- Counting: the decorated function exposes `.statistics` (also `.retry.statistics`), reset per call, keys `start_time`, `attempt_number`, `idle_for`, `delay_since_first_attempt` [TI]. `retry_with(...)` overrides settings per call [TD].
- Async: decorating `async def` works and sleeps are asynchronous; `AsyncRetrying` for `async for` blocks; `sleep=` is overridable [TD].

**Python standard library (3.15.2 docs)**
- `asyncio.Semaphore(value=1)`; `acquire()` has no timeout ("these synchronization primitives do not accept the _timeout_ argument; use ... `asyncio.wait_for()`"); `locked()` "Returns `True` if semaphore can not be acquired immediately"; `BoundedSemaphore` raises `ValueError` if `release()` exceeds the initial value; not thread-safe [SY].
- `asyncio.timeout(delay)` and `timeout_at` added in 3.11; on expiry it cancels the task and converts `CancelledError` to `TimeoutError`, catchable only outside the block; `reschedule()`, `expired()` [TK].
- `wait_for` cancels the awaitable and raises builtin `TimeoutError` (3.11), may exceed its timeout while waiting for cancellation, and is implemented with `timeout()` since 3.12 [TK].
- Cancellation: re-raise `CancelledError` after clean-up; suppressing it "is actively discouraged" and needs `Task.uncancel()`; `shield()` protects the inner task, not the caller [TK].
- A standard-library circuit breaker or retry helper: not stated in any page read.

**testcontainers-python 4.15.0**
- `stop(force=True, delete_volume=True)` removes the container (`remove(force=..., v=...)`); there is no restart, pause or kill helper [TC]. A later `start()` creates a new container (source).
- Exposed ports map to "randomly assigned" host ports; `get_exposed_port` queries Docker on every call with no caching [TN] [TC] [TDC]. Whether a host port survives a restart: not stated [TN] [DP].
- `get_wrapped_container()` returns the docker-py `Container`, which has `kill(signal=None)` (default SIGKILL), `pause()`, `unpause()`, `restart()`, `stop()`, `reload()` [TC] [DP].
- Every non-Ryuk container gets `org.testcontainers=true`, `org.testcontainers.session-id=<uuid4 per process>`, `org.testcontainers.version`, `org.testcontainers.lang=python`; user labels under `org.testcontainers` raise `ValueError` [TL] [TDC]. "Each test session gets a unique session ID, and Ryuk tracks containers by this ID" [TG].

## Actionable Techniques

- Assert a pybreaker or aiobreaker trip on the fail_max-th failure with `CircuitBreakerError`; a purgatory trip on the threshold-th failure with the original exception and `OpenedState` on the next call [PB] [ABS] [PGM].
- Assert state by `current_state == "open"` (pybreaker), `CircuitBreakerState.OPEN` (aiobreaker) or `"opened"` (purgatory); never compare across libraries [PB] [AB] [PGM].
- For asyncio code prefer purgatory or a maintained wrapper over pybreaker's Tornado-only `call_async` [PB] [PGL].
- Count retries with `fn.statistics["attempt_number"]`; set `reraise=True` when the test expects the original exception [TI] [TD].
- Bulkhead: `asyncio.Semaphore(n)`, assert `locked()` at the limit, bound waits with `asyncio.timeout()` [SY] [TK].
- After a container fault, re-read `get_exposed_port`; before killing a container, check its `org.testcontainers.session-id` label matches `testcontainers.core.labels.SESSION_ID` [TC] [TL].

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-chaos-test | Breaker tests assume one trip rule | pybreaker/aiobreaker raise `CircuitBreakerError` at the threshold; purgatory re-raises the original |
| python-chaos-test | Async breaker on the wrong library | pybreaker async is Tornado-only; aiobreaker unmaintained since 2021 |
| python-chaos-test | Retry attempts not counted | tenacity `statistics` keys, `RetryError` vs `reraise`, jitter formulas |
| python-chaos-test | Bulkhead and deadline semantics | Semaphore has no timeout; `asyncio.timeout` cancellation rules |
| python-chaos-test | Faults hit foreign containers | Session-id label, docker-py `kill`/`pause`, port re-read |

## Caveats

- Nothing was run. No package was installed and no breaker, retry, loop or container was exercised.
- Pages were read through a fetch tool that summarises each page against a question; quotations were requested verbatim but not every page was read end to end.
- purgatory, tenacity and testcontainers sources were read on `main`, not at the release tag; they may differ from the released versions.
- Not stated: whether a container's host port is kept after a docker-py `restart()` or `unpause()`; purgatory's TTL unit; a purgatory half-open trial limit; any asyncio support in pybreaker; a standard-library breaker or retry helper; tenacity's per-key statistics semantics in the docs (keys taken from source).
