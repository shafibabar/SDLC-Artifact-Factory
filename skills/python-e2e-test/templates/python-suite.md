# The Python End-to-End Suite

Self-contained. Copy these files into `tests/e2e/` when a product gets its first end-to-end journey. Every file below was run as written on 2026-11-28 with Python 3.15.2, pytest 9.2.0, pytest-asyncio 1.5.0, httpx 0.29.0, `opentelemetry-api` and `opentelemetry-sdk` 1.45.2, `opentelemetry-instrumentation-httpx` 0.66b2 and mypy 2.4.1 (`strict`), against a kind v0.33.0 cluster (Kubernetes v1.37.0) on macOS arm64. Python 3.12, the version `python-makefile` sets for products, was not run. Dependencies and pytest settings are in `./pytest-configuration.md`.

## The three rules of the layout

1. **Every end-to-end file is under `tests/e2e/`.** The coverage gate of `python-unit-test` leaves that folder out by path (`--skip-suite e2e`), so `make test` and `make ci` never collect it.
2. **The folder decides what a test is.** `tests/e2e/journeys/` holds journeys, which may create and delete data and run only in the throwaway cluster. `tests/e2e/smoke/` holds read-only smoke tests. `conftest.py` puts the `e2e` or `smoke` marker on each test from its folder; a test anywhere else under `tests/e2e/`, a journey marked `smoke` and a smoke test marked `e2e` stop the run with a usage error (run: exit 4).
3. **Addresses never come from the environment in a journey.** They come from the run marker inside the cluster that `run-e2e-environment.sh` created.

| Folder | Files | Selected by |
|---|---|---|
| `tests/e2e/` | `support.py`, `conftest.py`: guard, bound clients, polling, tracing. Nothing here writes by itself | Both selections |
| `tests/e2e/journeys/` | Product fixtures, seeding, journeys, guard self-checks | `run-python-e2e-suite.sh journeys` only |
| `tests/e2e/smoke/` | Smoke tests, the read-only self-check | `run-python-e2e-suite.sh smoke` only |

The smoke selection collects the smoke folder and nothing else, so a journey cannot be part of it; the `smoke` client is the only client a smoke test can get, and it refuses every write.

| Copy unchanged | Write for the product |
|---|---|
| `support.py`, `conftest.py`, `journeys/test_guard_selfcheck.py`, `smoke/test_smoke_guard.py`, and an empty `__init__.py` in `tests/`, `tests/e2e/`, `tests/e2e/journeys/` and `tests/e2e/smoke/` | `journeys/conftest.py` (clients and one create helper per kind of test data), one `journeys/test_journey_<name>.py` per journey, `smoke/test_smoke.py` |

The product below is a museum's exhibit loans; replace `loan`, `/loans` and the endpoint names (`api`, `couriers`) with the product's own. Endpoint names are the ones listed under `E2E_ENDPOINTS` in `tests/e2e/e2e.conf` (`./environment-config.md`).

## Copy unchanged

### `tests/e2e/support.py`

```python
"""End-to-end support: the run marker, clients bound to one address, polling.

Nothing here reads an address from the environment. The journey side gets its
addresses from the marker inside the cluster its own run created; the smoke side
is given one base address and can only read from it.
"""

from __future__ import annotations

import asyncio
import ipaddress
import json
import os
import re
import subprocess
import time
from collections.abc import Awaitable, Callable, Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import TypeVar

import httpx
from opentelemetry.instrumentation.httpx import AsyncOpenTelemetryTransport, SyncOpenTelemetryTransport

T = TypeVar("T")
RUN_ID = re.compile(r"[a-z0-9][a-z0-9-]{0,39}")
DEFAULT_PORTS = {"http": 80, "https": 443}
START_WITH = "start the suite with tests/e2e/run-e2e-environment.sh (make e2e)"


class Refused(Exception):
    """A request, a seed or a whole run that the safety guards will not let through."""


def check_loopback(hostport: str) -> None:
    """Accepts only a literal loopback IP with a port: a host name could resolve anywhere."""
    host, _, port = hostport.rpartition(":")
    try:
        address = ipaddress.ip_address(host.strip("[]"))
        number = int(port)
    except ValueError:
        raise Refused(f"{hostport!r} is not a literal IP address and port") from None
    if not address.is_loopback or not 0 < number < 65536:
        raise Refused(f"{hostport!r} is not on this machine (loopback only)")


def check_kubeconfig_path(path: str, environ: Mapping[str, str]) -> None:
    """Refuses the caller's own kubeconfig: the default file and anything KUBECONFIG names."""
    if not path or not os.path.isabs(path):
        raise Refused(f"E2E_KUBECONFIG is not set to an absolute path: {START_WITH}")
    if not os.path.isfile(path):
        raise Refused(f"E2E_KUBECONFIG names no file: {path}")
    resolved = Path(path).resolve()
    own = [Path.home() / ".kube" / "config"]
    own += [Path(item) for item in environ.get("KUBECONFIG", "").split(os.pathsep) if item]
    if any(candidate.exists() and candidate.resolve() == resolved for candidate in own):
        raise Refused(f"E2E_KUBECONFIG is the caller's own kubeconfig ({path}); the suite uses only the file the script created for this run")


class _Rule:
    """One allowed scheme, host and port; optionally reads only."""

    def __init__(self, base: httpx.URL, read_only: bool) -> None:
        if base.scheme not in DEFAULT_PORTS or not base.host:
            raise Refused(f"{str(base)!r} is not an http or https address")
        self.allowed = (base.scheme, base.host, base.port or DEFAULT_PORTS[base.scheme])
        self.read_only = read_only

    def check(self, request: httpx.Request) -> None:
        url = request.url
        # httpx gives port None for a scheme's default port, so compare the filled-in value.
        target = (url.scheme, url.host, url.port or DEFAULT_PORTS.get(url.scheme, 0))
        if target != self.allowed:
            raise Refused(f"refusing request to {url.scheme}://{url.netloc.decode()}: this client is bound to "
                          f"{self.allowed[0]}://{self.allowed[1]}:{self.allowed[2]}")
        if self.read_only and request.method not in ("GET", "HEAD"):
            raise Refused(f"refusing {request.method} {url.path}: smoke tests are read-only")


class BoundTransport(httpx.BaseTransport):
    """Refuses, before anything is sent, a request to any other address (an absolute
    URL and a redirect hop included) and, when read-only, every write. The transport
    inside it is the instrumented one, so each request carries `traceparent`."""

    def __init__(self, base: httpx.URL, *, read_only: bool) -> None:
        self._rule = _Rule(base, read_only)
        self._inner = SyncOpenTelemetryTransport(httpx.HTTPTransport(trust_env=False))

    def handle_request(self, request: httpx.Request) -> httpx.Response:
        self._rule.check(request)
        return self._inner.handle_request(request)

    def close(self) -> None:
        self._inner.close()


class AsyncBoundTransport(httpx.AsyncBaseTransport):
    """The same refusal for httpx.AsyncClient."""

    def __init__(self, base: httpx.URL, *, read_only: bool) -> None:
        self._rule = _Rule(base, read_only)
        self._inner = AsyncOpenTelemetryTransport(httpx.AsyncHTTPTransport(trust_env=False))

    async def handle_async_request(self, request: httpx.Request) -> httpx.Response:
        self._rule.check(request)
        return await self._inner.handle_async_request(request)

    async def aclose(self) -> None:
        await self._inner.aclose()


def bound_client(base_url: str, *, read_only: bool, headers: Mapping[str, str] | None = None) -> httpx.Client:
    """A client that reaches base_url and nothing else. Passing `transport=` also
    keeps proxy settings of the environment out of it."""
    base = httpx.URL(base_url)
    return httpx.Client(base_url=base, transport=BoundTransport(base, read_only=read_only), headers=headers,
                        follow_redirects=False, timeout=httpx.Timeout(15.0), trust_env=False)


def bound_async_client(base_url: str, *, read_only: bool, headers: Mapping[str, str] | None = None) -> httpx.AsyncClient:
    base = httpx.URL(base_url)
    return httpx.AsyncClient(base_url=base, transport=AsyncBoundTransport(base, read_only=read_only), headers=headers,
                             follow_redirects=False, timeout=httpx.Timeout(15.0), trust_env=False)


@dataclass(frozen=True)
class Env:
    """The throwaway cluster this run created. require_throwaway_cluster is the only
    way to get one."""

    run_id: str
    endpoints: Mapping[str, str]  # name -> 127.0.0.1:port, as written by the script

    def addr(self, name: str) -> str:
        if name not in self.endpoints:
            raise Refused(f"this run's cluster has no endpoint {name!r} (see E2E_ENDPOINTS in tests/e2e/e2e.conf)")
        return self.endpoints[name]

    def require_throwaway(self, hostport: str) -> None:
        """Every direct connection (a database for seeding) passes through this."""
        if hostport not in self.endpoints.values():
            raise Refused(f"refusing {hostport!r}: it is not an endpoint of this run's throwaway cluster")

    def client(self, name: str, *, headers: Mapping[str, str] | None = None) -> httpx.Client:
        return bound_client(f"http://{self.addr(name)}", read_only=False, headers=headers)

    def async_client(self, name: str, *, headers: Mapping[str, str] | None = None) -> httpx.AsyncClient:
        return bound_async_client(f"http://{self.addr(name)}", read_only=False, headers=headers)


def env_from_marker(run_id: str, data: Mapping[str, str]) -> Env:
    """Checks the marker against this run and keeps only loopback addresses."""
    if data.get("run-id") != run_id:
        raise Refused(f"run marker says run {data.get('run-id')!r}, this run is {run_id!r}")
    endpoints = {key.removeprefix("endpoint."): value for key, value in data.items() if key.startswith("endpoint.")}
    for name, address in endpoints.items():
        try:
            check_loopback(address)
        except Refused as exc:
            raise Refused(f"endpoint {name}: {exc}") from None
    if not endpoints:
        raise Refused("run marker names no endpoint")
    return Env(run_id, endpoints)


def require_throwaway_cluster(environ: Mapping[str, str] | None = None) -> Env:
    """Refuses unless the kubeconfig the script wrote for this run leads to a cluster
    on this machine that carries this run's marker. Reads E2E_RUN_ID and
    E2E_KUBECONFIG and no address."""
    environ = os.environ if environ is None else environ
    run_id = environ.get("E2E_RUN_ID", "")
    if not RUN_ID.fullmatch(run_id):
        raise Refused(f"E2E_RUN_ID is not set: {START_WITH}")
    kubeconfig = environ.get("E2E_KUBECONFIG", "")
    check_kubeconfig_path(kubeconfig, environ)
    context = f"kind-e2e-{run_id}"

    def kubectl(*arguments: str) -> str:
        # kubectl on the run's own file and context; --cache-dir keeps its
        # discovery cache out of ~/.kube/cache. A Kubernetes client library is not
        # used: its default loader reads the caller's kubeconfig and can write to it.
        command = ["kubectl", "--kubeconfig", kubeconfig, "--context", context,
                   "--cache-dir", str(Path(kubeconfig).parent / "kube-cache"), "--request-timeout=30s", *arguments]
        try:
            done = subprocess.run(command, capture_output=True, text=True, timeout=60, check=False)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise Refused(f"kubectl {' '.join(arguments)}: {exc}") from None
        if done.returncode != 0:
            raise Refused(f"kubectl {' '.join(arguments)}: {done.stderr.strip()}")
        return done.stdout

    try:
        server = kubectl("config", "view", "--minify", "-o", "jsonpath={.clusters[0].cluster.server}")
    except Refused as exc:
        raise Refused(f"no context {context} in {kubeconfig}: {exc}") from None
    try:
        check_loopback(httpx.URL(server).netloc.decode())
    except Refused as exc:
        raise Refused(f"the cluster's API server: {exc}") from None
    try:
        raw = kubectl("get", "configmap", "e2e-run-marker", "-n", "default", "-o", "json")
    except Refused as exc:
        raise Refused(f"this cluster carries no run marker, so this run did not create it: {exc}") from None
    data = json.loads(raw).get("data") or {}
    return env_from_marker(run_id, data)


def eventually(what: str, check: Callable[[], T], *, within: float, interval: float = 0.2) -> T:
    """Calls check until it returns, or fails at the deadline with the last reason.
    check raises AssertionError (or cannot connect) while the effect is not there
    yet. This is the only way a test waits: no fixed sleep."""
    deadline = time.monotonic() + within
    while True:
        try:
            return check()
        except (AssertionError, httpx.TransportError) as exc:
            last = exc
        if time.monotonic() >= deadline:
            raise AssertionError(f"{what}: not true within {within:g}s; last: {last!r}") from last
        time.sleep(interval)  # e2e-poll-interval: a pause between checks inside a deadline, not a wait


async def eventually_async(what: str, check: Callable[[], Awaitable[T]], *, within: float, interval: float = 0.2) -> T:
    """The same for async tests."""
    deadline = time.monotonic() + within
    while True:
        try:
            return await check()
        except (AssertionError, httpx.TransportError) as exc:
            last = exc
        if time.monotonic() >= deadline:
            raise AssertionError(f"{what}: not true within {within:g}s; last: {last!r}") from last
        await asyncio.sleep(interval)  # e2e-poll-interval: a pause between checks inside a deadline, not a wait
```

### `tests/e2e/conftest.py`

```python
"""Shared by journeys and smoke tests: what a test is, the guard, tracing, the
trace id on failure, and the read-only smoke client. Copy unchanged."""

from __future__ import annotations

import os
from collections.abc import Generator, Iterator
from pathlib import Path

import httpx
import pytest
from opentelemetry import propagate, trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.sampling import ALWAYS_ON
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

from tests.e2e.support import Env, Refused, bound_client, require_throwaway_cluster

HERE = Path(__file__).parent.resolve()
TRACE_ID = pytest.StashKey[str]()


def pytest_configure(config: pytest.Config) -> None:
    config.addinivalue_line("markers", "e2e: a journey through the deployed product; runs only in the throwaway cluster of its own run")
    config.addinivalue_line("markers", "smoke: a read-only check; the only selection that may address a deployed environment")


def _folder(item: pytest.Item) -> str:
    path = item.path.resolve()
    return path.relative_to(HERE).parts[0] if HERE in path.parents else ""


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    """The folder decides what a test is, so a marker cannot be forgotten or misused."""
    for item in items:
        folder = _folder(item)
        if not folder:
            continue
        if folder == "journeys" and item.get_closest_marker("smoke") is None:
            item.add_marker(pytest.mark.e2e)
        elif folder == "smoke" and item.get_closest_marker("e2e") is None:
            item.add_marker(pytest.mark.smoke)
        else:
            raise pytest.UsageError(
                f"{item.nodeid}: an end-to-end test is either a journey in tests/e2e/journeys/ or a read-only smoke "
                "test in tests/e2e/smoke/, never both and never anywhere else under tests/e2e/")


@pytest.fixture(scope="session")
def env() -> Env:
    """The throwaway cluster of this run. Refuses unless the target is the cluster
    this run created; addresses then come only from that cluster's run marker."""
    try:
        return require_throwaway_cluster()
    except Refused as exc:
        reason = str(exc)
    pytest.fail(f"REFUSED: end-to-end journeys run only against the throwaway cluster of their own run.\n  {reason}", pytrace=False)


@pytest.fixture(scope="session")
def _tracing() -> Iterator[None]:
    """An SDK tracer provider and the W3C propagator. Without the provider a span's
    trace id is all zeros and no `traceparent` header is sent."""
    provider = TracerProvider(sampler=ALWAYS_ON)
    trace.set_tracer_provider(provider)
    propagate.set_global_textmap(TraceContextTextMapPropagator())
    yield
    provider.shutdown()


@pytest.fixture(autouse=True)
def journey(request: pytest.FixtureRequest, _tracing: None) -> Iterator[str]:
    """Runs for every end-to-end test. A journey first passes the guard, whether or
    not it asks for `env`. Then one span is opened that every request of the test
    travels under; it stays open until the test and its cleanup are over. Yields
    the trace id, which a failed test prints."""
    if _folder(request.node) == "journeys":
        request.getfixturevalue("env")
    with trace.get_tracer("e2e").start_as_current_span(request.node.nodeid) as span:
        context = span.get_span_context()
        if not context.is_valid:
            pytest.fail("no valid trace id: the SDK tracer provider is not in use (is OTEL_SDK_DISABLED set?)", pytrace=False)
        trace_id = trace.format_trace_id(context.trace_id)
        request.node.stash[TRACE_ID] = trace_id
        yield trace_id


@pytest.hookimpl(wrapper=True)
def pytest_runtest_makereport(item: pytest.Item, call: pytest.CallInfo[None]) -> Generator[None, pytest.TestReport, pytest.TestReport]:
    report = yield
    trace_id = item.stash.get(TRACE_ID, None)
    if report.failed and trace_id:
        report.sections.append(("trace", f"trace_id={trace_id}"))
    return report


@pytest.fixture
def smoke() -> Iterator[httpx.Client]:
    """The only client of a smoke test: it reads from E2E_SMOKE_URL and refuses
    every write and every other address before anything is sent."""
    base = os.environ.get("E2E_SMOKE_URL", "")
    if httpx.URL(base).scheme not in ("http", "https") or not httpx.URL(base).host:
        pytest.fail("REFUSED: set E2E_SMOKE_URL to the base address the read-only smoke tests read from, "
                    "for example http://127.0.0.1:8080", pytrace=False)
    tenant = os.environ.get("E2E_SMOKE_TENANT", "")
    with bound_client(base, read_only=True, headers={"X-Tenant": tenant} if tenant else None) as client:
        yield client
```

### `tests/e2e/journeys/test_guard_selfcheck.py`

```python
"""These tests keep the safety guards honest on every run. Each one is a case
that must be refused. Copy unchanged."""

from __future__ import annotations

import http.server
import socketserver
import threading
from collections.abc import Iterator

import pytest

from tests.e2e.support import Env, Refused, bound_client, env_from_marker


class _Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True

    def server_bind(self) -> None:  # no reverse lookup of the host name
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = "127.0.0.1", self.server_address[1]


@pytest.fixture
def two_servers() -> Iterator[tuple[str, str, list[str]]]:
    """A local address that redirects to a second local address, which records
    every request it receives."""
    received: list[str] = []
    servers: list[_Server] = []

    class Elsewhere(http.server.BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            received.append(f"{self.command} {self.path}")
            self.send_response(200)
            self.send_header("Content-Length", "0")
            self.end_headers()

        do_POST = do_GET

        def log_message(self, format: str, *args: object) -> None:
            pass

    class Redirects(Elsewhere):
        def do_GET(self) -> None:
            self.send_response(302)
            self.send_header("Location", f"http://127.0.0.1:{servers[0].server_port}/landed")
            self.send_header("Content-Length", "0")
            self.end_headers()

    for handler in (Elsewhere, Redirects):
        server = _Server(("127.0.0.1", 0), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        servers.append(server)
    yield f"http://127.0.0.1:{servers[1].server_port}", f"http://127.0.0.1:{servers[0].server_port}", received
    for server in servers:
        server.shutdown()
        server.server_close()


def test_guard_client_refuses_another_address(env: Env, two_servers: tuple[str, str, list[str]]) -> None:
    _, elsewhere, received = two_servers
    with env.client("api") as api:
        with pytest.raises(Refused, match="refusing request"):
            api.post(f"{elsewhere}/anything", json={"x": 1})  # an absolute URL does not follow base_url
    assert received == [], "the other address received a request; the refusal must come before anything is sent"


def test_guard_client_refuses_a_redirect_to_another_address(two_servers: tuple[str, str, list[str]]) -> None:
    here, _, received = two_servers
    with bound_client(here, read_only=False) as client:
        assert client.get("/start").status_code == 302  # redirects are not followed unless asked
        with pytest.raises(Refused, match="refusing request"):
            client.get("/start", follow_redirects=True)
    assert received == []


def test_guard_seeding_refuses_an_address_outside_the_cluster(env: Env) -> None:
    for address in ("db.staging.example:5432", "10.0.0.7:5432", "127.0.0.1:5432", "localhost:5432"):
        with pytest.raises(Refused):
            env.require_throwaway(address)
    env.require_throwaway(env.addr("api"))


def test_guard_marker_must_be_this_run_and_loopback(env: Env) -> None:
    cases = {
        "another run's marker": {"run-id": "someone-else", "endpoint.api": "127.0.0.1:30080"},
        "an address off this machine": {"run-id": env.run_id, "endpoint.api": "10.20.30.40:443"},
        "a host name": {"run-id": env.run_id, "endpoint.api": "api.staging.example:443"},
        "no endpoint": {"run-id": env.run_id},
    }
    for name, data in cases.items():
        with pytest.raises(Refused):
            env_from_marker(env.run_id, data)
            pytest.fail(f"{name} was accepted")
```

### `tests/e2e/smoke/test_smoke_guard.py`

```python
"""Keeps the read-only guard honest on every smoke run. Copy unchanged."""

from __future__ import annotations

import httpx
import pytest

from tests.e2e.support import Refused


def test_smoke_writes_are_refused(smoke: httpx.Client) -> None:
    for method in ("POST", "PUT", "PATCH", "DELETE"):  # smoke-refusal-check: each must be refused
        with pytest.raises(Refused, match="read-only"):
            smoke.request(method, "/", json={"x": 1})


def test_smoke_client_refuses_another_address(smoke: httpx.Client) -> None:
    with pytest.raises(Refused, match="refusing request"):
        smoke.get("http://192.0.2.1/elsewhere")  # refused before anything is sent
```

## Write for the product

### `tests/e2e/journeys/conftest.py`

```python
"""Clients and test data for the journeys. Written for the product."""

from __future__ import annotations

import itertools
import re
from collections.abc import Callable, Iterator
from typing import Any

import httpx
import pytest

from tests.e2e.support import Env

_counter = itertools.count(1)


@pytest.fixture
def ref(env: Env, request: pytest.FixtureRequest) -> Callable[[], str]:
    """References that belong to one test of one run: run id, test name, a counter.
    Nothing is random, so a failure can be found again in the logs."""
    name = re.sub(r"[^a-z0-9]+", "-", request.node.name.lower()).strip("-")
    return lambda: f"{env.run_id}-{name}-{next(_counter)}"


@pytest.fixture
def api(env: Env) -> Iterator[httpx.Client]:
    with env.client("api") as client:
        yield client


@pytest.fixture
def couriers(env: Env) -> Iterator[httpx.Client]:
    with env.client("couriers") as client:
        yield client


@pytest.fixture
def create_loan(api: httpx.Client) -> Iterator[Callable[..., dict[str, Any]]]:
    """Creates a loan the way a user would, through the public API, and removes
    exactly what it created, also when the test fails. A failed removal fails the test."""
    made: list[str] = []

    def create(**fields: Any) -> dict[str, Any]:
        reply = api.post("/loans", json=fields)
        assert reply.status_code == 201, f"create loan: {reply.status_code} {reply.text}"
        loan: dict[str, Any] = reply.json()
        made.append(loan["id"])
        return loan

    yield create
    problems = []
    for loan_id in reversed(made):
        reply = api.delete(f"/loans/{loan_id}")
        if reply.status_code not in (204, 404):
            problems.append(f"{loan_id}: {reply.status_code}")
    assert not problems, f"cleanup of loans failed: {problems}"
```

### `tests/e2e/journeys/test_journey_loan.py`

```python
from __future__ import annotations

from collections.abc import Callable
from typing import Any

import httpx

from tests.e2e.support import Env, eventually, eventually_async


def test_journey_requested_loan_gets_a_courier_pickup(
    api: httpx.Client, couriers: httpx.Client, create_loan: Callable[..., dict[str, Any]], ref: Callable[[], str]
) -> None:
    """AC-US-3.1, AC-US-3.2: a registrar requests the loan of an exhibit and the
    courier service schedules its pickup. Two deployed services and their database
    take part; the pickup arrives later, so the test polls for it."""
    made = create_loan(reference=ref(), exhibit="bronze-mirror", due="2026-12-20")
    assert made["status"] == "pending"

    def confirmed() -> dict[str, Any]:
        reply = api.get(f"/loans/{made['id']}")
        assert reply.status_code == 200, reply.text
        loan: dict[str, Any] = reply.json()
        assert loan["status"] == "confirmed", f"loan status {loan['status']!r}"
        return loan

    loan = eventually(f"loan {made['id']} confirmed", confirmed, within=20)

    reply = couriers.get(f"/pickups/{loan['body']['downstream_id']}")
    assert reply.status_code == 200, reply.text
    assert reply.json()["body"]["source_id"] == made["id"]


def test_journey_withdrawn_loan_is_gone(api: httpx.Client, create_loan: Callable[..., dict[str, Any]], ref: Callable[[], str]) -> None:
    """AC-US-3.4: a withdrawn loan request can no longer be read."""
    made = create_loan(reference=ref(), exhibit="jade-comb", due="2026-12-21")
    assert api.delete(f"/loans/{made['id']}").status_code == 204
    assert api.get(f"/loans/{made['id']}").status_code == 404


async def test_journey_loan_is_confirmed_async(env: Env, ref: Callable[[], str]) -> None:
    """AC-US-3.2, in the async form: the same wait with httpx.AsyncClient and
    eventually_async. The test removes what it created, also when it fails."""
    async with env.async_client("api") as api:
        reply = await api.post("/loans", json={"reference": ref(), "exhibit": "ivory-dice", "due": "2026-12-22"})
        assert reply.status_code == 201, reply.text
        loan_id = reply.json()["id"]
        try:

            async def confirmed() -> None:
                current = await api.get(f"/loans/{loan_id}")
                assert current.status_code == 200 and current.json()["status"] == "confirmed", current.text

            await eventually_async(f"loan {loan_id} confirmed", confirmed, within=20)
        finally:
            removed = await api.delete(f"/loans/{loan_id}")
            assert removed.status_code in (204, 404), f"cleanup of loan {loan_id}: {removed.status_code}"
```

### `tests/e2e/smoke/test_smoke.py`

```python
from __future__ import annotations

import httpx


def test_smoke_loans_can_be_listed(smoke: httpx.Client) -> None:
    """Reads the loan list: the service is up, its database answers and the read
    path works. It creates nothing."""
    reply = smoke.get("/loans")
    assert reply.status_code == 200, reply.text
    assert isinstance(reply.json(), list)
```

## What to keep when changing these

- **The guard.** A journey passes `require_throwaway_cluster` before its first request, whether or not it asks for `env`. Started by hand, every journey ends as an error that begins `REFUSED:` and nothing is sent.
- **The client.** Clients come from `env.client(...)`, `env.async_client(...)` or the `smoke` fixture. `httpx.Client(base_url=...)` is not a guard: an absolute URL ignores `base_url` (run: the other address received the request). The bound transport refuses another address, an absolute URL and a redirect hop before anything is sent, and it ignores proxy settings of the environment.
- **The trace id.** `conftest.py` sets up the SDK tracer provider and the W3C propagator and opens one span per test; the bound transport is the instrumented one. A plain `httpx` client sends no `traceparent`.
- **Test data** is created through the public API by a fixture that removes exactly what it created after the `yield`, also when the test fails, and fails the test when a removal fails. A product with no public way to create some state uses `./direct-database-seed.md`.
- **A wait** is `eventually(...)` or `eventually_async(...)` with a deadline. The one `sleep` in each is the pause between two checks and carries the comment `e2e-poll-interval`, which the validator looks for.
- **A journey's docstring names the acceptance criteria** it proves (`AC-US-n.m`); the test report lists them.
- **A smoke test only reads**, through `smoke`. The comment `smoke-refusal-check` on the one line that lists write methods tells the validator that those requests are there to be refused.
- **No skip, no `xfail`, no rerun marker, no quarantine marker.** An unstable test goes into `tests/e2e/quarantine-python.txt` with an issue and a deadline (`../references/retry-and-quarantine.md`).
- **Sync or async.** Both forms were run in one suite with `asyncio_mode = "auto"` and function-scoped loops. The session fixtures here are synchronous on purpose: a session-scoped async fixture needs a session-scoped loop.
