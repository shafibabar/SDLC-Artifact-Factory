# The Event-Loop Stall Experiment

Self-contained. Use for every Python service that serves requests with asyncio (FastAPI, Starlette, any ASGI app under uvicorn). A blocking call inside `async def` (`time.sleep`, a synchronous HTTP or database client) or CPU-bound work on the event loop stops **every** request of that worker until it returns, health checks included: to an orchestrator and to its users the whole worker looks hung (the "whole-process-appears-to-hang" signature the Halstead research note names for a stalled asyncio loop under injected latency, `research/software-architecture/python-backend-development-halstead.md`; Fresh-Eyes finding W3C-45). Go's runtime has no such single point; this experiment is the Python counterpart of `go-chaos-test`'s lock-order experiment.

## What it asserts

| Test | Fault | Asserts | Fails on |
|---|---|---|---|
| `test_blocking_call_stalls_only_its_worker` | `stall_app` (`./chaos-support.md`) makes a 1 s blocking call inside `async def` on one worker | The worker's own lag probe records a wake-up later than 0.5 s; its health check on a second connection waits for the stall (if not, INVALID: the fault never took effect); another worker answers in under 100 ms; after the request that carried the fault ends, the worker answers in under 100 ms and the probe records no new late wake-up | Another worker held up (one worker, or a shared lock); a stall that outlives its fault |
| `test_cpu_bound_report_does_not_stall_the_worker` | None injected: the product's own CPU-bound handler runs (1.3 s in the lab) | The same worker's health check stays under 100 ms throughout | The handler computing on the loop: "the whole worker looks hung" |

**The lag probe is the product's**, not the test's: `event_loop_lag_seconds`, the histogram of `python-load-test`'s template `saturation-metrics.md` (a task that sleeps 50 ms and records how late it woke). The load test observes saturation with it; this experiment reads it from the stalled worker's own `/metrics`, through a connection pinned to that worker. A product without it gets the probe from that template (owned there, not copied here); until then the lag assertion is missing and the report says so.

**The fix belongs to the service**, never to the test: offload blocking or CPU-bound work with `asyncio.to_thread` (I/O, or a C extension that releases the GIL) or a `ProcessPoolExecutor` (pure-Python CPU work: `python-async-concurrency`), and never call a synchronous client from `async def`. `../scripts/validate-python-chaos-tests.sh` warns on `time.sleep` and `requests` inside `async def` in the product's code.

**Workers:** the lab starts two uvicorn processes on two loopback ports, which stands for two workers or two replicas (one uvicorn process per container, `python-dockerfile`). With `uvicorn --workers N` the kernel decides which worker takes a connection, so pin each client to one connection (`httpx.Limits(max_connections=1)`) and check the `x-worker-pid` answer header, as the test does.

## Seen (2026-11-28, Python 3.15.2, uvicorn 0.54.0, FastAPI 0.165.0, prometheus-client 0.26.0)

- Correct product, three runs: `2 passed` each. The stalled worker's health check took 913 ms, the other worker's 1 ms, the stalled worker's 2 ms after the fault; lag observations over 0.5 s on that worker went from 0 to 1, and none was added in the quiet second after.
- Product whose usage report computes on the loop (`asyncio.to_thread` removed): `the whole worker looks hung: its health check took 1231 ms while the usage report ran (1.3 s); offload CPU-bound work (asyncio.to_thread or a process pool)`.
- A report that finished in 439 ms gave `CHAOS-INVALID: the report took 439 ms: too short to tell a stalled worker from a free one`: the test sizes its own load and refuses to conclude on too little.

Not run: the same experiment against the deployed product in the throwaway cluster (a stall endpoint in a shipped image is not allowed; the in-process form above is the one this skill gives), and a `ProcessPoolExecutor` variant (unverified).

### `tests/chaos/test_event_loop_stall.py`

```python
# tests/chaos/test_event_loop_stall.py: a blocking call inside async def stalls every request of that worker,
# health checks included, while other workers keep answering; and the product's own slow handler does not.
# Two uvicorn processes stand for two workers (or replicas). Run only through run-chaos-experiment.sh.
import asyncio
import os
import re
import socket
import subprocess
import sys
import time

import httpx
import pytest

from tests.chaos.support.chaostest import invalid

HEALTH_UNDER = 0.1  # a health check answers in under 100 ms (the readiness probe's own budget is larger)


def free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@pytest.fixture
async def workers():
    """Two worker processes of the product, each with the stall fault available; stopped on every path."""
    procs, urls = [], []
    for _ in range(2):
        port = free_port()
        procs.append(subprocess.Popen(
            [sys.executable, "-m", "uvicorn", "tests.chaos.support.stall_app:app", "--host", "127.0.0.1",
             "--port", str(port), "--log-level", "warning"], env={**os.environ, "STATIONS_URL": "http://127.0.0.1:9"}))
        urls.append(f"http://127.0.0.1:{port}")
    try:
        for url in urls:
            async def up(url=url):
                try:
                    async with httpx.AsyncClient(trust_env=False) as c:
                        return (await c.get(url + "/healthz", timeout=0.5)).status_code == 200
                except httpx.HTTPError:
                    return False
            deadline = time.monotonic() + 15
            while not await up():
                if time.monotonic() > deadline:
                    invalid(f"worker {url} did not start within 15 s")
                await asyncio.sleep(0.1)  # poll interval inside a deadline
        yield urls
    finally:
        for p in procs:
            p.terminate()
        for p in procs:
            p.wait(timeout=10)


def lag_over(metrics: str, bound: str = "0.5") -> int:
    """Lag observations above `bound` seconds, from the product's event_loop_lag_seconds histogram
    (python-load-test's saturation probe)."""
    count = float(re.search(r"^event_loop_lag_seconds_count (\S+)", metrics, re.M).group(1))
    under = float(re.search(r'^event_loop_lag_seconds_bucket\{le="%s"\} (\S+)' % re.escape(bound), metrics, re.M).group(1))
    return int(count - under)


async def timed_get(client: httpx.AsyncClient, path: str, **kw) -> tuple[float, httpx.Response]:
    start = time.monotonic()
    answer = await client.get(path, **kw)
    return time.monotonic() - start, answer


# EXPERIMENT  event-loop-stall
# HYPOTHESIS  While one worker runs a 1 s blocking call inside async def, its event-loop lag probe records it,
#             its own health check waits for it, and another worker keeps answering in under 100 ms; once the
#             call ends, the worker answers in under 100 ms again.
async def test_blocking_call_stalls_only_its_worker(workers):
    a, b = workers
    limits = httpx.Limits(max_connections=1)  # one connection each, so each client stays on its worker
    async with httpx.AsyncClient(base_url=a, limits=limits, trust_env=False, timeout=5) as a1, \
            httpx.AsyncClient(base_url=a, limits=limits, trust_env=False, timeout=5) as a2, \
            httpx.AsyncClient(base_url=b, limits=limits, trust_env=False, timeout=5) as b1:
        for client in (a2, b1):
            took, _ = await timed_get(client, "/healthz")
            if took >= HEALTH_UNDER:
                invalid(f"steady state did not hold before the fault: health took {took * 1000:.0f} ms")
        lag_before = lag_over((await a2.get("/metrics")).text)

        stall = asyncio.create_task(a1.get("/healthz", headers={"x-chaos-stall-ms": "1000"}))
        await asyncio.sleep(0.1)  # let the stall begin; this sleep is the experiment's timing, not a wait for the system
        (same_took, same), (other_took, other) = await asyncio.gather(timed_get(a2, "/healthz"), timed_get(b1, "/healthz"))
        await stall
        if same.headers["x-worker-pid"] != stall.result().headers["x-worker-pid"]:
            invalid("the health check reached another process than the stalled one")
        if same_took < 0.5:
            invalid(f"the same worker's health check took {same_took * 1000:.0f} ms: the stall never took effect")
        if other_took >= HEALTH_UNDER:
            pytest.fail(f"another worker took {other_took * 1000:.0f} ms to answer while one worker was stalled")

        took, _ = await timed_get(a2, "/healthz")  # the fault is gone with the request that carried it
        if took >= HEALTH_UNDER:
            pytest.fail(f"after the stall the worker still took {took * 1000:.0f} ms to answer")
        lag_after = lag_over((await a2.get("/metrics")).text)
        if lag_after - lag_before < 1:
            invalid("the event-loop lag probe recorded no wake-up later than 0.5 s: the stall was not seen")
        print(f"stalled worker health {same_took * 1000:.0f} ms, other worker {other_took * 1000:.0f} ms, "
              f"after {took * 1000:.0f} ms; lag observations over 0.5 s: {lag_before} -> {lag_after}")
        await asyncio.sleep(1.0)  # one quiet second, then no new late wake-up
        if lag_over((await a2.get("/metrics")).text) != lag_after:
            pytest.fail("the event-loop lag probe kept recording late wake-ups after the stall ended")


# EXPERIMENT  slow-report-offloaded
# HYPOTHESIS  While the CPU-bound usage report runs, the same worker's health check still answers in under 100 ms.
async def test_cpu_bound_report_does_not_stall_the_worker(workers):
    a, _ = workers
    limits = httpx.Limits(max_connections=1)
    async with httpx.AsyncClient(base_url=a, limits=limits, trust_env=False, timeout=30) as a1, \
            httpx.AsyncClient(base_url=a, limits=limits, trust_env=False, timeout=30) as a2:
        report = asyncio.create_task(timed_get(a1, "/v1/usage-report", params={"rounds": 6_000_000}))
        await asyncio.sleep(0.1)  # the report is running
        worst = 0.0
        while not report.done():
            took, _ = await timed_get(a2, "/healthz")
            worst = max(worst, took)
            await asyncio.sleep(0.05)  # probe interval while the report runs
        report_took, answer = await report
        if answer.status_code != 200 or report_took < 0.5:
            invalid(f"the report took {report_took * 1000:.0f} ms: too short to tell a stalled worker from a free one")
        if worst >= HEALTH_UNDER:
            pytest.fail(f"the whole worker looks hung: its health check took {worst * 1000:.0f} ms while the usage "
                        f"report ran ({report_took:.1f} s); offload CPU-bound work (asyncio.to_thread or a process pool)")
```
