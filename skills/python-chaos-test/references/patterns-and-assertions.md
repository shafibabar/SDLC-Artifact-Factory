# Each Pattern, Its Defined Behaviour and the Assertion That Proves It (Python)

Self-contained. Read when writing or reviewing an experiment for a resilience pattern in a Python product, when the product lacks a pattern, when a test "proves" a pattern with one call, when choosing how to read a breaker library's state, or for the event-loop, DLQ, idempotency and 429 rows. Definitions and numbers come from `integration-design` (resilience patterns, "internal, hot path" row: trip at 5 consecutive failures, a 10 s window, a 5 s reset, one half-open probe; 3 attempts, 100 ms doubling to 5 s, full jitter; the remaining deadline passed down; one pool per downstream; nesting bulkhead → breaker → retry → timeout). Library facts come from `research/testing/python-resilience-libraries-official-docs.md` (pybreaker 1.4.1, aiobreaker 1.2.0, purgatory 3.0.2, tenacity 9.2.1, Python 3.15 docs). Each assertion below was run on 2026-11-28 against the lab product of `../examples/02-standard-bike-share-docks.md`, passing on the correct code and failing on a deliberately broken copy; the failure messages are quoted.

## First: what does the product implement?

Read the product's client code for each downstream and list, per pattern, **present** (with its settings: threshold, window, reset, attempts, backoff, attempt timeout, pool size, acquire bound, fallback) or **missing**. The experiments test what is present, against the product's own settings read from its configuration, never numbers chosen by the test. A setting that differs from `integration-design`'s row is a finding for the report, not something the test quietly accepts.

**No Python build skill implements a circuit breaker, a retry policy or a bulkhead today** (`python-async-concurrency` gives `asyncio.Semaphore` and `asyncio.timeout()`, `python-error-handling` a `retryable` flag, `python-middleware` a rate limiter). The product owner has made building them a gap for a later wave (D048, 2026-11-28). So a pattern the product lacks is **named as missing** in the answer and the report ("the docks service has no circuit breaker on its call to the stations service; `integration-design` requires one on a hot-path call"), with its corrective action. Do not build one inside the test, and do not "prove" it with a stand-in: the lab uses purgatory and tenacity only to show what a correct experiment looks like, never as the product's choice.

## Circuit breaker

**Defined:** closed, failures counted; open once the threshold is reached, every call failing at once for the reset time; half-open after it, **one** probe let through; a good probe closes it, a failed one reopens it. One breaker per downstream; its state exported as a metric.

**Assert, in order** (`test_breaker_opens_at_the_threshold_and_recovers`):
1. A healthy call; state closed. (If not, INVALID.)
2. Fault the dependency (503). After each of the first threshold−1 failed calls the state is still closed; after the threshold-th, open. One failed call is one breaker failure: the retry sits inside the breaker.
3. While open: 20 calls each fail with the product's "unavailable" error in under 20 ms, and the dependency counts **zero** new requests.
4. After the reset, five callers at once with the dependency still failing: exactly one call's attempts reach the dependency; every caller gets "unavailable". The probe failed: open again.
5. After the next reset, clear the fault: the probe succeeds and the state is closed. The recorded transitions are exactly `opened, half-opened, opened, half-opened, closed`.

**Seen failing:** a breaker built with a threshold that never trips while the configuration says 5: `after 5 consecutive failed call(s) (threshold 5): breaker is closed, want opened`, and `retry storm: 50 calls sent 150 requests, want at most 15`. The 1.2.0 test (one call while the link resets, asserting a fast "unavailable" in under 1 s) **passed** on that same broken breaker, in 0.11 s, and the breaker read `closed` afterwards. One fast failure is not a breaker.

**Library differences** (run: pybreaker 1.4.1 and purgatory 3.0.2 with a threshold of 5):

| | pybreaker 1.4.1 | aiobreaker 1.2.0 | purgatory 3.0.2 |
|---|---|---|---|
| Trips | on the threshold-th failure (`>=`); seen: calls 1–4 raised the error, call 5 raised `CircuitBreakerError` and read `open` | on the threshold-th failure (source) | on the threshold-th failure; seen: call 5 re-raised the **original** error, call 6 raised `OpenedState` |
| State | `current_state`: `"open"`, `"half-open"`, `"closed"` | `CircuitBreakerState.OPEN` (an enum, not a string) | `context.state`: `"opened"`, `"half-opened"`, `"closed"`; `state_changed` events through `add_listener` |
| Half-open | entered lazily by the next call after the reset: `current_state` read `open` after the reset until a call was made | not run | the same; seen: **all five concurrent callers were let through** (15 requests): no one-probe limit, so the product must add one (the lab holds an `asyncio.Lock` while not closed) |
| asyncio | `call_async` needs Tornado; `call` holds a thread lock while the function runs | native asyncio; last release 2021, treat as unmaintained | native asyncio, MIT, maintained; `OpenedState` is not exported (`purgatory.domain.model`) |
| Caller's cancellation | does not arise (synchronous `call`) | not checked | counts any exception, `CancelledError` included, unless listed in `exclude`; seen: without it, `after 5 calls the caller cancelled: breaker is opened, want closed` |

So: assert the threshold **as configured** and read the state the library's own way; poll for half-open only through a call, never by reading the state after a sleep; exclude the caller's cancellation and permanent answers (4xx) from the failure count.

## Retry with backoff and jitter

**Defined:** transient failures only (5xx, 429, connection errors, an attempt's own timeout), capped attempts, exponential backoff with full jitter, never past the caller's deadline; a write retried only with an idempotency key.

**Assert** (`test_retry_is_bounded_jittered_and_stops_at_the_deadline`), every call inside `bounded` (5 s) so an unbounded retry fails instead of hanging:
- One call against a dependency that keeps failing: the dependency receives **exactly** `max_attempts` (3).
- The wait before attempt *k* is within its cap (100 ms, then 200 ms, plus 30 ms of slack), and across 10 calls the first wait varies (population standard deviation at least 5 ms: jitter).
- A 404 reaches the dependency once.
- With each attempt taking 100 ms and the caller's deadline at 150 ms, the call ends with the caller's `TimeoutError` by the deadline (+50 ms).
- 50 calls against a dependency that stays down send at most threshold × attempts (15): the open breaker caps the load.
- A connection error (`FaultTransport`, `httpx.ConnectError`) is retried up to the cap, and nothing reaches the dependency.

**Seen failing:** tenacity's `stop` removed: three tests failed with `the call did not return within 5.0s: a retry with no bound, or a deadline that never fired`. Without `bounded` the run would hang. **tenacity traps:** a bare `@retry` "retries forever without waiting" (run: 1,000 attempts in 0.014 s); `wait_exponential` has no jitter, `wait_random_exponential` is full jitter (`uniform(0, min(multiplier × 2^(n−1), max))`); with `reraise=False` the caller sees `RetryError`, not the last error; `statistics["attempt_number"]` counts attempts per call. `../scripts/validate-python-chaos-tests.sh` fails a `retry`, `Retrying` or `AsyncRetrying` with no `stop`.

## Timeout and deadline propagation

**Defined:** every remote call has a deadline; the caller's remaining deadline reaches the dependency, so no dependency works longer than its caller waits. In asyncio the caller's `asyncio.timeout()` cancels the task, and the cancellation must reach the open request.

**Assert** (`test_deadline_propagates_to_the_dependency`): the dependency holds every request; the caller's deadline is a third of the attempt timeout; the call ends with the caller's `TimeoutError` by the deadline (+50 ms), and the dependency sees its client go away by the deadline (+100 ms). Then, five calls the caller cancels leave the breaker **closed**: the caller giving up is not the dependency failing.

**Seen failing:** the request shielded from cancellation (`asyncio.shield`, the same as running a synchronous client in a thread with its own timeout): `the dependency saw its request end 0.310s after it arrived, past the caller's 0.1s deadline`. **Trap:** an attempt's own `asyncio.timeout` raises `TimeoutError` too; map it to "unavailable" inside the client so the caller never mistakes it for its own deadline.

**Budgets nest** (`integration-design`): the caller's deadline must exceed the whole retry envelope. Seen in the lab: a 700 ms handler deadline over 3 attempts of 300 ms plus backoff (about 1.2 s) meant every call under a slow dependency ended as the caller's cancellation, so the breaker never opened; the fallback still kept the SLI. That is a finding for the report, not a test to loosen.

## Bulkhead

**Defined:** one pool or concurrency limit per downstream; when full, fail fast; never queue without bound. `asyncio.Semaphore.acquire()` takes no timeout ("use `asyncio.wait_for()`"), so a bare `async with semaphore:` queues without bound: the product bounds the wait (`asyncio.timeout(acquire_timeout)` around `acquire()`).

**Assert** (`test_saturated_pool_does_not_exhaust_another`): hold every slot of downstream A with slow requests; one more call to A fails with "unavailable" in under 20 ms; a call to downstream B succeeds in under 100 ms.

**Seen failing:** one semaphore shared by both clients: `another downstream's pool was exhausted too: weather: bulkhead full`.

## Graceful degradation and load shedding

**Defined:** a defined, observable degraded answer when a dependency fails (`integration-design` §6); an overloaded service rejects early and cheaply.

**Assert on the answer the SLI counts:** deployed, under 2 s of Toxiproxy latency on the dependency, every answer for a station seen before is **200 in under 800 ms**, marked `X-Degraded: stale` (`../templates/toxiproxy-setup.md`); the runner's `fault_header` makes a fault that marked no answer INVALID. **Seen failing:** a copy with no fallback made the runner abort at an SLI of 0.000.

**Shedding (unverified here):** uvicorn's `--limit-concurrency` answers 503 `Service Unavailable` with `connection: close` and **no** `Retry-After`, per process, before the application sees the request (`research/testing/python-service-saturation-official-docs.md`); an application-level limit that sets `Retry-After` belongs to the product. Shedding under the product's own traffic is `python-load-test`'s overload check.

## Event-loop stall

A blocking call inside `async def`, or CPU-bound work on the loop, stalls every request of that worker, health checks included; another worker keeps answering. The experiment, its lag probe and what was seen: `../templates/event-loop-stall.md`.

## DLQ, idempotency and 429: confirm, do not re-prove

`python-integration-test` proves that a poison record is parked on the DLQ, that a redelivered event has one effect and that the rate limiter answers 429 with `Retry-After` (W3-D23). Chaos does not repeat those tests. It confirms they **still hold while a fault is active**: for example, with the broker's pod killed mid-batch (Chaos Mesh in the throwaway cluster), the integration test's duplicate-delivery assertion run against the deployed consumer after recovery shows one effect per event. Write it as a `pytest` experiment whose test runs while the fault is active.

## Event-driven rows (shapes, not run)

None of these was run in this rebuild (unverified): the lab product has no broker.

| Row | Fault | Steady state and assertion |
|---|---|---|
| Broker outage | Chaos Mesh `PodChaos` pod-kill on one broker pod of the throwaway cluster's broker release (never the last broker) | Outbox rows unpublished during the outage, drained to zero after; consumer lag back to its baseline in the stated window; count in = count out |
| Poison message under a fault | A poison record published while the consumer's database is slowed (Toxiproxy latency) | The record lands on `<topic>.dlq` once; the next record is handled |
| Duplicate delivery under a fault | Consumer pod killed after processing, before commit | Redelivered; one effect per event, **waited for** (poll until the duplicate was consumed, then count) |
| Graceful shutdown | `PodChaos` pod-kill during steady requests, two replicas | The SLI holds; in-flight requests finish |

Never kill a container this run did not create: the 1.2.0 template killed a broker container with no ownership check. In the throwaway cluster the selector names the run's own namespace and pods; testcontainers' `stop()` removes a container and it has no restart helper, which is one more reason chaos runs in the cluster, not in a per-test container stack (D048, 2026-11-28).

## Boundary with load testing

This skill injects one isolated fault. `python-load-test`'s overload check makes the product's own traffic the stressor and observes the same lag probe. A product can pass one and fail the other.
