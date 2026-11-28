# Pattern Experiments in pytest

Self-contained. Use when writing the experiment for a circuit breaker, retry, timeout or bulkhead. **Write these for the product**: they are the lab's tests, run on 2026-11-28 (Python 3.15.2, pytest 9.2.0, pytest-asyncio 1.5.0, httpx 0.29.0, purgatory 3.0.2, tenacity 9.2.1), each passing on the correct product five runs in a row and failing on a broken copy (messages in `../references/patterns-and-assertions.md`). Keep every assertion; rename the client and its module to the product's.

## What the product must expose

The tests read, never invent, the product's settings, and observe its breaker. The lab product (`../examples/02-standard-bike-share-docks.md`) exposes, per downstream client:

- its configuration (`DownstreamConfig`: threshold `breaker_failures`, reset `breaker_reset_s`, `max_attempts`, `initial_backoff_s`, `attempt_timeout_s`, pool size `max_concurrent`, `acquire_timeout_s`);
- `breaker_state()` and the list of `transitions` (from purgatory's `state_changed` events: `closed`, `opened`, `half-opened`);
- one exception for every way the dependency is unavailable (`Unavailable`), a separate one for a permanent answer (`Permanent`), and the caller's own `TimeoutError` passed through unchanged.

Where the product lacks one of these, that is the first finding: a breaker whose state cannot be observed cannot be proven, and a pattern that is not there is named as **missing** (`../references/patterns-and-assertions.md`). **No Python build skill implements a breaker, a retry policy or a bulkhead today**; do not write the pattern into the test. For another library read the state its own way (pybreaker `current_state` `"open"`; aiobreaker `CircuitBreakerState.OPEN`) and keep the assertions.

Two settings are changed by a test, each with its reason in a comment: the reset (5 s shortened to 0.5 s so the test is quick) and, for counting retries one call at a time, a threshold high enough that the breaker stays out of the count. Nothing else.

### `tests/chaos/test_stations_client.py`

```python
# tests/chaos/test_stations_client.py: each resilience pattern of the stations client proven by its defined
# behaviour (integration-design §3 to §5), measured by time and counted at the dependency, against the client's
# own configuration. Run only through run-chaos-experiment.sh.
import asyncio
import dataclasses
import statistics
import time

import httpx
import pytest

from app.downstream import DownstreamClient, DownstreamConfig, Permanent, Unavailable
from tests.chaos.support.chaostest import Dependency, Fault, FaultTransport, bounded, invalid, require_injected, until


@pytest.fixture
async def dependency():
    dep = await Dependency().start()
    yield dep
    await dep.stop()


def client_for(dep: Dependency, **change) -> DownstreamClient:
    # The product's own settings; a test changes only what it must, and says why.
    return DownstreamClient("stations", dataclasses.replace(DownstreamConfig(dep.url), **change))


async def expect_state(client: DownstreamClient, want: str, when: str) -> None:
    got = await client.breaker_state()
    if got != want:
        pytest.fail(f"{when}: breaker is {got}, want {want}")


# EXPERIMENT  breaker-transitions
# HYPOTHESIS  After breaker_failures consecutive failed calls the breaker opens; while open no call reaches the
#             dependency; after the reset one probe is let through; a failed probe reopens it, a good one closes it.
async def test_breaker_opens_at_the_threshold_and_recovers(dependency):
    reset = 0.5  # the product's 5 s reset, shortened so the test is quick; nothing else changes
    client = client_for(dependency, breaker_reset_s=reset)
    threshold = client.config.breaker_failures
    await bounded(client.get_json("/v1/stations/S1"))
    await expect_state(client, "closed", "steady state")  # purgatory's names: closed, opened, half-opened

    dependency.fault = Fault(status=503)
    for n in range(1, threshold + 1):
        with pytest.raises(Unavailable):
            await bounded(client.get_json("/v1/stations/S1"))
        await expect_state(client, "closed" if n < threshold else "opened",
                          f"after {n} consecutive failed call(s) (threshold {threshold})")
    if dependency.calls < threshold:
        invalid(f"only {dependency.calls} requests reached the dependency for {threshold} failed calls")

    before = dependency.calls
    for i in range(20):
        start = time.monotonic()
        with pytest.raises(Unavailable):
            await bounded(client.get_json("/v1/stations/S1"))
        took = time.monotonic() - start
        if took > 0.02:
            pytest.fail(f"open call {i} took {took * 1000:.0f} ms; an open breaker fails at once")
    if dependency.calls != before:
        pytest.fail(f"while open, {dependency.calls - before} request(s) reached the dependency, want 0")

    await asyncio.sleep(reset)  # the reset itself is what is under test, not a wait for the system
    before = dependency.calls
    callers = await asyncio.gather(*(bounded(client.get_json("/v1/stations/S1")) for _ in range(5)),
                                   return_exceptions=True)  # five callers at once; the probe still fails
    if not all(isinstance(c, Unavailable) for c in callers):
        pytest.fail(f"half-open callers got {callers}, want Unavailable for each")
    if dependency.calls - before != client.config.max_attempts:
        pytest.fail(f"half-open let {dependency.calls - before} requests through from 5 callers, want one probe "
                    f"call ({client.config.max_attempts} attempts)")
    await expect_state(client, "opened", "after a failed probe")

    await asyncio.sleep(reset)
    dependency.fault = None
    await bounded(client.get_json("/v1/stations/S1"))
    await expect_state(client, "closed", "after a good probe")
    want = ["opened", "half-opened", "opened", "half-opened", "closed"]
    if client.transitions != want:
        pytest.fail(f"transitions {client.transitions}, want {want}")
    await client.aclose()


# EXPERIMENT  retry-bounded-jittered
# HYPOTHESIS  A failing call reaches the dependency exactly max_attempts times, each wait within its doubling cap
#             with jitter; a 404 is tried once; the caller's deadline stops it; a dependency that stays down gets at
#             most breaker_failures x max_attempts requests however many calls are made.
async def test_retry_is_bounded_jittered_and_stops_at_the_deadline(dependency):
    dependency.fault = Fault(status=503)
    first_waits = []
    for run in range(10):
        client = client_for(dependency, breaker_failures=1000)  # breaker out of the way for this count only
        before = len(dependency.arrivals)
        with pytest.raises(Unavailable):
            await bounded(client.get_json("/v1/stations/S1"))
        arrivals = dependency.arrivals[before:]
        if len(arrivals) != client.config.max_attempts:
            pytest.fail(f"run {run}: the dependency received {len(arrivals)} attempts for one call, "
                        f"want exactly {client.config.max_attempts}")
        for k in range(1, len(arrivals)):
            cap = client.config.initial_backoff_s * 2 ** (k - 1)
            wait = arrivals[k] - arrivals[k - 1]
            if wait > cap + 0.03:
                pytest.fail(f"run {run}: wait before attempt {k + 1} was {wait * 1000:.0f} ms, over its cap {cap * 1000:.0f} ms")
        first_waits.append(arrivals[1] - arrivals[0])
        await client.aclose()
    if statistics.pstdev(first_waits) < 0.005:
        pytest.fail(f"no jitter: the first waits were {[round(w * 1000) for w in first_waits]} ms")

    dependency.fault = None
    client = client_for(dependency)
    before = dependency.calls
    with pytest.raises(Permanent):
        await bounded(client.get_json("/v1/stations/missing"))
    if dependency.calls - before != 1:
        pytest.fail(f"a 404 reached the dependency {dependency.calls - before} times, want once")

    dependency.fault = Fault(status=503, delay=0.1)  # each attempt takes 100 ms: the deadline falls inside the retries
    deadline = client.config.attempt_timeout_s / 2
    start = time.monotonic()
    with pytest.raises(TimeoutError):
        async with asyncio.timeout(deadline):
            await client.get_json("/v1/stations/S1")
    if time.monotonic() - start > deadline + 0.05:
        pytest.fail(f"the call returned after {time.monotonic() - start:.3f}s, past the caller's {deadline}s deadline")
    await client.aclose()

    client = client_for(dependency)
    before = dependency.calls
    for _ in range(50):
        with pytest.raises(Unavailable):
            await bounded(client.get_json("/v1/stations/S1"))
    most = client.config.breaker_failures * client.config.max_attempts
    if dependency.calls - before > most:
        pytest.fail(f"retry storm: 50 calls sent {dependency.calls - before} requests, want at most {most}")
    await client.aclose()


async def test_connection_errors_are_retried_up_to_the_cap(dependency):
    transport = FaultTransport()
    client = DownstreamClient("stations", DownstreamConfig(dependency.url), transport=transport)
    transport.set(Fault(error=httpx.ConnectError))
    with pytest.raises(Unavailable):
        await bounded(client.get_json("/v1/stations/S1"))
    require_injected(transport)
    if transport.calls != client.config.max_attempts or dependency.calls != 0:
        pytest.fail(f"{transport.calls} attempts ({dependency.calls} reached the dependency), "
                    f"want {client.config.max_attempts} and 0")
    await client.aclose()


# EXPERIMENT  deadline-propagates
# HYPOTHESIS  The call returns by the caller's deadline with the caller's TimeoutError, and the dependency sees
#             its request end by then: no dependency works longer than its caller waits.
async def test_deadline_propagates_to_the_dependency(dependency):
    client = client_for(dependency)
    dependency.fault = Fault(delay=5.0)
    deadline = client.config.attempt_timeout_s / 3
    start = time.monotonic()
    with pytest.raises(TimeoutError):
        async with asyncio.timeout(deadline):
            await client.get_json("/v1/stations/S1")
    returned = time.monotonic() - start
    if returned > deadline + 0.05:
        pytest.fail(f"the call returned after {returned:.3f}s, past the caller's {deadline}s deadline")
    if dependency.calls == 0:
        invalid("the request never reached the dependency")
    if not await until(lambda: dependency.cancelled, 1.0):
        pytest.fail("the dependency never saw its request end: the caller's deadline did not reach it")
    ended = dependency.cancelled[0] - dependency.arrivals[0]
    if ended > deadline + 0.1:
        pytest.fail(f"the dependency saw its request end {ended:.3f}s after it arrived, past the caller's {deadline}s deadline")

    for _ in range(client.config.breaker_failures):  # the caller giving up is not the dependency failing
        try:
            async with asyncio.timeout(deadline):
                await client.get_json("/v1/stations/S1")
        except (TimeoutError, Unavailable):
            pass
    await expect_state(client, "closed", f"after {client.config.breaker_failures} calls the caller cancelled")
    await client.aclose()


# EXPERIMENT  bulkhead-per-downstream
# HYPOTHESIS  With every slot of the stations pool held, one more stations call is refused at once, and a call
#             to another downstream is still served.
async def test_saturated_pool_does_not_exhaust_another(dependency):
    other = await Dependency().start()
    stations = client_for(dependency, attempt_timeout_s=3.0)  # slow calls must outlive the check
    weather = DownstreamClient("weather", DownstreamConfig(other.url))
    dependency.fault = Fault(delay=2.0)
    held = [asyncio.create_task(stations.get_json(f"/v1/stations/S{i}")) for i in range(stations.config.max_concurrent)]
    await until(lambda: dependency.calls == stations.config.max_concurrent, 2.0, "every slot of the stations pool held")
    start = time.monotonic()
    with pytest.raises(Unavailable):
        await bounded(stations.get_json("/v1/stations/extra"))
    if time.monotonic() - start > 0.02:
        pytest.fail(f"the full pool took {(time.monotonic() - start) * 1000:.0f} ms to refuse; it must refuse at once")
    start = time.monotonic()
    try:
        await bounded(weather.get_json("/v1/forecast"))
    except Unavailable as exc:
        pytest.fail(f"another downstream's pool was exhausted too: {exc}")
    if time.monotonic() - start > 0.1:
        pytest.fail(f"another downstream waited {(time.monotonic() - start) * 1000:.0f} ms behind the full pool")
    for task in held:
        task.cancel()
    await asyncio.gather(*held, return_exceptions=True)
    await stations.aclose()
    await weather.aclose()
    await other.stop()
```

## Running them

Only through the runner, as the `pytest` experiment of `./experiment-definition.md`. By hand the guard refuses every test. A test that hangs is a defect in the test: every call goes through `bounded`.
