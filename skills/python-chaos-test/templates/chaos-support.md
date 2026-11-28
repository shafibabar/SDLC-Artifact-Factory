# The Chaos Test Support

Self-contained. Copy when the first chaos experiment is written. **Copy unchanged**: `tests/chaos/conftest.py` and `tests/chaos/support/` (with an empty `__init__.py` in `tests/`, `tests/chaos/` and `tests/chaos/support/`). The folder is test support, which the coverage gate does not measure (D048, 2026-11-27); it never ships in an image. Run on 2026-11-28 with Python 3.15.2, pytest 9.2.0, pytest-asyncio 1.5.0 (`asyncio_mode = "auto"`) and httpx 0.29.0: every test of `./pattern-tests.md`, `./event-loop-stall.md` and `./toxiproxy-setup.md` uses it.

## How the suite is kept out of the everyday run

Python has no build tag. Two things do that work, both required (W3-D10):

| Where | What | Seen |
|---|---|---|
| **Path** | Every chaos file is under `tests/chaos/`. The coverage gate of `python-unit-test` leaves the folder out with `--skip-suite chaos` (`--ignore=tests/chaos`), which `python-makefile`'s `make test` already passes | `../scripts/validate-python-chaos-tests.sh` fails a chaos test elsewhere and a gate line without `--skip-suite chaos` |
| **Marker and guard** | `conftest.py` registers `chaos`, puts it on every test of the folder, and fails each test with `CHAOS-REFUSED` unless `run-chaos-experiment.sh` started it (`CHAOS_EXPERIMENT_ID`) inside the run (`E2E_RUN_ID`) | Run: a bare `pytest tests/chaos` gave `5 errors`, each `CHAOS-REFUSED`, before anything started; `-m "not chaos"` deselected all 5. The runner reads `CHAOS-REFUSED` as REFUSED |

## What it gives

| Name | What it does | Rule it keeps |
|---|---|---|
| `FaultTransport` | An `httpx.AsyncBaseTransport` that injects a `Fault`: a status (an `httpx.Response` bound to the request), a transport error (an `httpx.TransportError` subclass such as `httpx.ConnectError`), a delay that the caller's cancellation ends | httpx's transport contract: `handle_async_request` returns a response or raises an httpx transport error, never changes the request, delegates `aclose` |
| `Dependency` | A stand-in for a service the product calls, on 127.0.0.1 (stdlib `asyncio.start_server`), with a settable fault, recording every arrival and every client that went away before its answer | Counts are taken **at the dependency**, where "fails fast", "no retry storm" and "the deadline reached it" are measured |
| `invalid` | Ends a test with `CHAOS-INVALID: ...`; the runner turns that into INVALID | A fault never confirmed, or a steady state that did not hold, is never a pass |
| `toxics` (fixture), `Toxics` | Toxiproxy through its HTTP API at `E2E_ADDR_TOXIPROXY` (loopback only, `CHAOS-REFUSED` otherwise): every answer checked, the toxic confirmed listed, every toxic removed at teardown and the removal verified (`CHAOS-FAULT-LEFT` otherwise) | Every injection error checked; removal on every path, verified |
| `bounded`, `until` | A deadline around every call (an unbounded retry fails the test instead of hanging it); a poll inside a deadline | Seen: with tenacity's `stop` removed, `the call did not return within 5.0s: a retry with no bound, or a deadline that never fired` |
| `stall_app` | The product's ASGI app with one fault added: a request carrying `x-chaos-stall-ms` makes a blocking call inside `async def`; every answer names its process | The fault exists only under `tests/chaos/`, never in the shipped app |

Rename `app.main` in `stall_app.py` to the product's ASGI module; nothing else changes.

### `tests/chaos/conftest.py`

```python
# tests/chaos/conftest.py: every test under tests/chaos is a chaos experiment. It is marked `chaos` by folder,
# and it runs only when run-chaos-experiment.sh started it inside the run's throwaway cluster; anywhere else
# (a bare `pytest`, an IDE, `make test` without --skip-suite chaos) every test ends as an error before it starts.
import os
from pathlib import Path

import pytest

from tests.chaos.support.chaostest import toxics  # noqa: F401  (the fixture, for every experiment)

HERE = Path(__file__).parent


def pytest_configure(config: pytest.Config) -> None:
    config.addinivalue_line("markers", "chaos: a chaos experiment; started only by run-chaos-experiment.sh")


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    for item in items:
        if HERE in Path(str(item.path)).parents:
            item.add_marker(pytest.mark.chaos)


@pytest.fixture(autouse=True)
def _started_by_the_runner() -> None:
    if not (os.environ.get("E2E_RUN_ID") and os.environ.get("CHAOS_EXPERIMENT_ID")):
        pytest.fail("CHAOS-REFUSED: a chaos experiment starts only through run-chaos-experiment.sh inside the run's "
                    "throwaway cluster (E2E_RUN_ID and CHAOS_EXPERIMENT_ID are not set)", pytrace=False)
```

### `tests/chaos/support/chaostest.py`

```python
# tests/chaos/support/chaostest.py: test support for chaos experiments. A fault-injecting httpx transport, a
# stand-in dependency that counts what reaches it, Toxiproxy helpers that check every answer and verify removal,
# and the CHAOS-INVALID, CHAOS-REFUSED and CHAOS-FAULT-LEFT lines run-chaos-experiment.sh reads.
import asyncio
import ipaddress
import os
import time
from dataclasses import dataclass

import httpx
import pytest


def invalid(message: str) -> None:
    """End the test as INVALID: the experiment proved nothing (no fault took effect, or no steady state before it)."""
    pytest.fail(f"CHAOS-INVALID: {message}", pytrace=False)


@dataclass(frozen=True)
class Fault:
    status: int = 0                  # answer this status
    error: type[httpx.TransportError] | None = None  # or fail the request with this httpx transport error
    delay: float = 0.0               # wait first; the wait ends when the caller's task is cancelled


class FaultTransport(httpx.AsyncBaseTransport):
    """Wraps a transport and injects the current Fault. Keeps httpx's transport contract: returns an
    httpx.Response bound to the request, raises only httpx.TransportError subclasses (which the client and every
    retry policy see as a real transport failure), never changes the request, and lets cancellation through."""

    def __init__(self, inner: httpx.AsyncBaseTransport | None = None) -> None:
        self._inner = inner or httpx.AsyncHTTPTransport()
        self._fault: Fault | None = None
        self.calls = 0
        self.injected = 0

    def set(self, fault: Fault) -> None:
        self._fault = fault

    def clear(self) -> None:
        self._fault = None

    async def handle_async_request(self, request: httpx.Request) -> httpx.Response:
        self.calls += 1
        fault = self._fault
        if fault is None:
            return await self._inner.handle_async_request(request)
        self.injected += 1
        if fault.delay:
            await asyncio.sleep(fault.delay)  # cancellable: the caller's deadline ends it
        if fault.error is not None:
            raise fault.error("injected fault", request=request)
        if fault.status:
            return httpx.Response(fault.status, headers={"content-type": "text/plain; charset=utf-8"},
                                  content=b"injected fault", request=request)
        return await self._inner.handle_async_request(request)

    async def aclose(self) -> None:
        await self._inner.aclose()


def require_injected(transport: FaultTransport) -> None:
    if transport.injected == 0:
        invalid("the fault was never injected: no request met it")


class Dependency:
    """A stand-in for a service the product calls, on 127.0.0.1. Answers `healthy` (a JSON body) while no fault is
    set; records when each request arrived and when a client went away before its answer (a deadline that reached
    the dependency)."""

    def __init__(self, healthy: bytes = b'{"ok": true}') -> None:
        self.healthy = healthy
        self.fault: Fault | None = None
        self.arrivals: list[float] = []
        self.cancelled: list[float] = []
        self._server: asyncio.Server | None = None
        self.url = ""

    async def start(self) -> "Dependency":
        self._server = await asyncio.start_server(self._serve, "127.0.0.1", 0)
        self.url = "http://127.0.0.1:%d" % self._server.sockets[0].getsockname()[1]
        return self

    async def stop(self) -> None:
        self.fault = None
        if self._server is not None:
            self._server.close()
            await self._server.wait_closed()

    @property
    def calls(self) -> int:
        return len(self.arrivals)

    async def _serve(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        try:
            head = await reader.readuntil(b"\r\n\r\n")
        except (asyncio.IncompleteReadError, asyncio.LimitOverrunError, ConnectionError):
            writer.close()
            return
        path = head.split(b" ", 2)[1].decode()
        self.arrivals.append(time.monotonic())
        fault = self.fault
        if fault is not None and fault.delay:
            try:
                gone = await asyncio.wait_for(reader.read(1), fault.delay)
            except TimeoutError:
                gone = None
            except ConnectionError:
                gone = b""
            if gone == b"":
                self.cancelled.append(time.monotonic())
                writer.close()
                return
        status, body = 200, self.healthy
        if fault is not None and fault.status:
            status, body = fault.status, b"injected fault"
        elif path.endswith("/missing"):
            status, body = 404, b"not found"
        writer.write(b"HTTP/1.1 %d X\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"
                     % (status, len(body), body))
        try:
            await writer.drain()
        except ConnectionError:
            pass
        writer.close()


def toxiproxy_url() -> str:
    """The Toxiproxy API of this run's throwaway cluster, published on loopback by run-e2e-environment.sh."""
    address = os.environ.get("E2E_ADDR_TOXIPROXY", "")
    host, _, port = address.rpartition(":")
    try:
        loopback = ipaddress.ip_address(host).is_loopback and port.isdigit()
    except ValueError:
        loopback = False
    if not (os.environ.get("E2E_RUN_ID") and loopback):
        pytest.fail(f"CHAOS-REFUSED: E2E_RUN_ID and a loopback E2E_ADDR_TOXIPROXY are set only inside this run's "
                    f"environment (got {address!r})", pytrace=False)
    return f"http://{address}"


class Toxics:
    """Adds toxics through Toxiproxy's HTTP API with every answer checked (the Python client's add_toxic returns
    nothing), confirms each is listed, and removes every one at teardown with the removal verified."""

    def __init__(self, api: str) -> None:
        self._http = httpx.Client(base_url=api, timeout=15, trust_env=False)
        self._added: list[tuple[str, str]] = []

    def add(self, proxy: str, name: str, type_: str, attributes: dict, stream: str = "downstream") -> None:
        answer = self._http.post(f"/proxies/{proxy}/toxics", json={
            "name": name, "type": type_, "stream": stream, "toxicity": 1.0, "attributes": attributes})
        if answer.status_code != 200:
            invalid(f"adding toxic {name!r} to {proxy!r}: Toxiproxy answered {answer.status_code}: "
                    f"{answer.text.strip()} (no fault was injected)")
        self._added.append((proxy, name))
        if not self._listed(proxy, name):
            invalid(f"toxic {name!r} was accepted but {proxy!r} does not list it")

    def remove(self, proxy: str, name: str) -> None:
        self._added.remove((proxy, name))
        self._http.delete(f"/proxies/{proxy}/toxics/{name}")
        if self._listed(proxy, name):
            pytest.fail(f"CHAOS-FAULT-LEFT: toxic {name!r} is still listed on {proxy!r} after removal", pytrace=False)

    def remove_all(self) -> None:
        left = []
        for proxy, name in list(self._added):
            try:
                self.remove(proxy, name)
            except pytest.fail.Exception:
                left.append(f"{proxy}/{name}")
        self._http.close()
        if left:
            pytest.fail(f"CHAOS-FAULT-LEFT: toxics still listed after removal: {', '.join(left)}", pytrace=False)

    def _listed(self, proxy: str, name: str) -> bool:
        try:
            answer = self._http.get(f"/proxies/{proxy}/toxics")
            return answer.status_code != 200 or any(t.get("name") == name for t in answer.json())
        except (httpx.HTTPError, ValueError):
            return True  # unknown counts as present: never claim a removal that was not seen


@pytest.fixture
def toxics():
    adder = Toxics(toxiproxy_url())
    yield adder
    adder.remove_all()


async def bounded(awaitable, seconds: float = 5.0):
    """Every call in a chaos test has a deadline of its own: an unbounded retry fails the test instead of hanging it."""
    try:
        async with asyncio.timeout(seconds):
            return await awaitable
    except TimeoutError:
        pytest.fail(f"the call did not return within {seconds}s: a retry with no bound, or a deadline that never fired")


async def until(condition, within: float, what: str = "") -> bool:
    """Poll a condition inside a deadline. With `what`, not reaching it is INVALID (the setup never happened)."""
    deadline = time.monotonic() + within
    while not condition():
        if time.monotonic() > deadline:
            if what:
                invalid(f"not reached within {within}s: {what}")
            return False
        await asyncio.sleep(0.01)  # poll interval inside a deadline
    return True
```

### `tests/chaos/support/stall_app.py`

```python
# tests/chaos/support/stall_app.py: the product's ASGI app with one fault added, for chaos runs only. A request
# carrying x-chaos-stall-ms makes a blocking call inside async def, exactly the defect the experiment imitates.
# Every answer says which process served it. Nothing here ships: it lives under tests/chaos.
import os
import time

from app.main import app as product

PID = str(os.getpid()).encode()


async def app(scope, receive, send):
    if scope["type"] != "http":
        return await product(scope, receive, send)
    stall = dict(scope["headers"]).get(b"x-chaos-stall-ms")
    if stall:
        time.sleep(int(stall) / 1000)  # the injected fault: the event loop can run nothing else meanwhile

    async def send_with_pid(message):
        if message["type"] == "http.response.start":
            message = {**message, "headers": [*message.get("headers", []), (b"x-worker-pid", PID)]}
        await send(message)

    await product(scope, receive, send_with_pid)
```
