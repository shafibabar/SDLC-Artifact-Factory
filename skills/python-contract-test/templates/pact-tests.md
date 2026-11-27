# Pact Tests: Consumer, Provider and Provider States

Self-contained. Copy for every direct request/response call between two services, at every product size. Pact tests live in `pact_tests/`, **outside `tests/`**, so `make ci` never collects them; the daily run does (`./workflows.md`). Run on Python 3.15.2 (macOS arm64) with pact-python 4.2.0 (`pact-python-ffi` 0.5.13.0), the `pact` command of `pact-python-cli` 1!1.0.0, pytest 9.2.0, uvicorn 0.54.0 and httpx 0.29.0 against Pact Broker 2.124.0, and type-checked with mypy 2.4.1 in strict mode (the code is the lean example's; replace the names). pact-python 4 removed the older `pact.v2` interface (`Consumer`, `Provider`) and the `pact-verifier` command: code written for them does not import.

## Contents

Settings; `conftest.py`; consumer test; provider verification; when the provider checks a token; what was seen; setup notes.

## Settings

Add to the product's one `pyproject.toml` (owned by `python-makefile`). The marker line joins the existing `markers` list; with the strict settings an unregistered marker stops every Pact run with an error (run: exit 3).

```toml
[dependency-groups]
dev = [
    "pact-python==4.2.0",
    "pact-python-cli==1!1.0.0",   # the `pact broker ...` command; no longer installed with pact-python
    "uvicorn==0.54.0",
]

[tool.pytest.ini_options]
markers = [
    "integration: needs a real database or broker; not a unit test",
    "pact: Pact consumer or provider test; daily run only, never in make ci",
]
```

`testpaths` stays `["tests"]`. Nothing is added to `addopts`.

## `conftest.py`: copy unchanged

Everything under `pact_tests/` gets the `pact` marker here, so no test can be left without it, and a pact file is written only for a test that passed.

### `pact_tests/conftest.py`

```python
"""Pact tests run in the daily Pact workflow only. They sit outside tests/, so
`make ci` never collects them, and every one of them carries the pact marker."""

from __future__ import annotations

from collections.abc import Callable, Generator, Iterator
from pathlib import Path

import pytest
from pact import Pact

HERE = Path(__file__).parent
PACTS = HERE.parent / "pacts"
CALL_PASSED = pytest.StashKey[bool]()


@pytest.hookimpl(tryfirst=True)  # before pytest applies -m
def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    for item in items:
        if HERE in item.path.parents:
            item.add_marker(pytest.mark.pact)


@pytest.hookimpl(wrapper=True)
def pytest_runtest_makereport(
    item: pytest.Item, call: pytest.CallInfo[None]
) -> Generator[None, pytest.TestReport, pytest.TestReport]:
    report = yield
    if report.when == "call":
        item.stash[CALL_PASSED] = report.passed
    return report


@pytest.fixture
def record_pact(request: pytest.FixtureRequest) -> Iterator[Callable[[str, str], Pact]]:
    """record_pact("rentals", "plots") starts a pact whose file is written to
    ./pacts when, and only when, the test passed. pact-python does not write
    the file by itself, and would also write a failed test's interactions."""
    started: list[Pact] = []

    def start(consumer: str, provider: str) -> Pact:
        started.append(Pact(consumer, provider).with_specification("V4"))
        return started[-1]

    yield start
    if request.node.stash.get(CALL_PASSED, False):
        for pact in started:
            pact.write_file(PACTS)
```

## Consumer test: adapt

The **real client** runs against Pact's mock server; the pact file in `./pacts` is a by-product, never written by hand. Record only the fields the consumer reads, and match by value or pattern any field the consumer's behaviour depends on.

### `pact_tests/consumer/test_rentals_plots_pact.py`

```python
"""Pact consumer test: what rentals relies on when it calls plots. The real
client runs against Pact's mock; pacts/rentals-plots.json is a by-product."""

from __future__ import annotations

from collections.abc import Callable

import httpx
import pytest
from pact import Pact, match

from rentals.adapters.plots_client import PlotNotFound, PlotsClient

PLOT = "3f0a1d52-6c1d-4f6e-9a57-2f1c5f0d9b11"


@pytest.fixture
def pact(record_pact: Callable[[str, str], Pact]) -> Pact:
    return record_pact("rentals", "plots")


async def test_rentals_reads_a_free_plot(pact: Pact) -> None:
    (
        pact.upon_receiving("a request for a free plot")
        .given(f"plot {PLOT} is free and measures 25 square metres")
        .with_request("GET", f"/v1/plots/{PLOT}")
        .will_respond_with(200)
        .with_body(
            # Only the fields rentals reads. The status is matched against the
            # values rentals understands, not just "some string".
            {
                "id": PLOT,
                "name": match.str("Plot 7"),
                "status": match.regex("free", regex=r"^(free|rented|closed)$"),
                "sizeSquareMetres": match.int(25),
            },
            content_type="application/json",
        )
    )
    with pact.serve() as mock:
        async with httpx.AsyncClient(base_url=str(mock.url)) as http:
            plot = await PlotsClient(http).plot(PLOT)
    assert plot.rentable()
    assert plot.size_square_metres == 25


async def test_rentals_learns_a_plot_is_missing(pact: Pact) -> None:
    (
        pact.upon_receiving("a request for a plot that does not exist")
        .given(f"no plot {PLOT} exists")
        .with_request("GET", f"/v1/plots/{PLOT}")
        .will_respond_with(404)
    )
    with pact.serve() as mock:
        async with httpx.AsyncClient(base_url=str(mock.url)) as http:
            with pytest.raises(PlotNotFound):
                await PlotsClient(http).plot(PLOT)
```

## Provider verification: adapt

The verifier replays each recorded request over HTTP against the **real app**, served by uvicorn in a thread of the test process so that state handlers reach the same store. Each `given(...)` text from the consumer must be a key of `states`, character for character.

### `pact_tests/provider/test_plots_provider_pact.py`

```python
"""Pact provider verification: plots honours what its consumers recorded. The
verifier replays each recorded request against the real app over HTTP."""

from __future__ import annotations

import os
import socket
import threading
import time
from collections.abc import Callable, Iterator
from datetime import date, timedelta
from typing import Any

import pytest
import uvicorn
from pact import Verifier

from plots.entrypoints.fastapi_app import Plot, create_app

PLOT = "3f0a1d52-6c1d-4f6e-9a57-2f1c5f0d9b11"


class StateStore:
    """The provider's data for one verification run. Until a Provider State
    handler calls set(), every request fails, so an interaction whose state
    name matches no handler cannot pass by accident."""

    def __init__(self) -> None:
        self._ready = False
        self._plots: dict[str, Plot] = {}

    async def find(self, plot_id: str) -> Plot | None:
        if not self._ready:
            raise RuntimeError("no Provider State handler ran for this interaction")
        return self._plots.get(plot_id)

    def forget(self) -> None:
        self._ready, self._plots = False, {}

    def set(self, *plots: Plot) -> None:
        self._ready, self._plots = True, {plot.id: plot for plot in plots}


def states(store: StateStore) -> dict[str, Callable[[], None]]:
    """Each Provider State name, exactly as the consumer wrote it, and its setup."""
    return {
        f"plot {PLOT} is free and measures 25 square metres": lambda: store.set(Plot(PLOT, "Plot 7", "free", 25)),
        f"no plot {PLOT} exists": lambda: store.set(),
    }


def must_env(name: str) -> str:
    value = os.environ.get(name, "")
    assert value, f"{name} is not set; the verification would not know what it is recording"
    return value


@pytest.fixture
def store() -> StateStore:
    return StateStore()


@pytest.fixture
def provider_url(store: StateStore) -> Iterator[str]:
    """The real app on a loopback port, served by uvicorn in a thread: state
    handlers run in this process and reach the same store."""
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    server = uvicorn.Server(uvicorn.Config(create_app(store), log_level="warning"))
    thread = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True)
    thread.start()
    deadline = time.monotonic() + 10
    while not server.started:
        assert time.monotonic() < deadline and thread.is_alive(), "the provider did not start"
        time.sleep(0.01)
    try:
        yield f"http://127.0.0.1:{listener.getsockname()[1]}"
    finally:
        server.should_exit = True
        thread.join(10)


def test_plots_honours_its_consumers(provider_url: str, store: StateStore) -> None:
    known, unknown = states(store), []

    def provider_state(state: str, action: str, parameters: dict[str, Any] | None) -> None:
        if action == "setup" and state in known:
            known[state]()
            return
        # Teardown, or a name with no handler: the store goes back to unready,
        # so a request that had no setup answers 500 at once.
        store.forget()
        if action == "setup":
            unknown.append(state)

    verifier = (
        Verifier("plots", host="127.0.0.1")
        .add_transport(url=provider_url)
        .state_handler(provider_state, teardown=True)
        .set_error_on_empty_pact()
        .broker_source(
            must_env("PACT_BROKER_BASE_URL"),
            username=os.environ.get("PACT_BROKER_USERNAME"),
            password=os.environ.get("PACT_BROKER_PASSWORD"),
            selector=True,
        )
        .consumer_version(main_branch=True)
        .consumer_version(matching_branch=True)
        .consumer_version(deployed_or_released=True)
        .provider_branch(must_env("GIT_BRANCH"))
        .include_pending()
        .include_wip_since(date.today() - timedelta(days=14))
        .build()
    )
    # Results are recorded only by the scheduled run, never from a laptop.
    if os.environ.get("PACT_PUBLISH_RESULTS") == "true":
        verifier.set_publish_options(version=must_env("GIT_SHA"), branch=must_env("GIT_BRANCH"))
    try:
        verifier.verify()
    except RuntimeError:
        pytest.fail(
            f"a consumer's expectation is not met (Provider States with no handler: {unknown}):\n"
            + verifier.output(strip_ansi=True),
            pytrace=False,
        )
    # A failing pending or work-in-progress pact does not raise: show it.
    print(verifier.output(strip_ansi=True))
    assert not unknown, f"Provider States with no handler: {unknown}"
```

When the provider reads from PostgreSQL, a state handler seeds **real, committed rows scoped to that state** (`test-fixture-design`), because the verifier's request arrives on another connection and cannot see an open transaction: `python-integration-test`'s default rollback cannot be used here. `forget` then deletes exactly those rows.

## When the provider checks a token: adapt

Most providers sit behind token-checking middleware. The verifier replays the header the consumer recorded, and the real middleware rejects it (`expected 200 but was 401`). pact-python's `Verifier` has **no request filter**, and its custom-header option cannot do the job (table below). What works keeps the **real app and its real middleware** and changes one thing only: the key they trust is made for this run, and a small wrapper placed around the app in the test swaps the recorded example token for one signed with it. Run with PyJWT 2.15.1 and cryptography 50.0.2 against an RS256 middleware that checks signature, issuer, audience, expiry and scope. `TokenRules` is this example's own way of handing the app its key and rules; use the provider's.

### `tests/contract/tokens.py`

```python
"""Test support: a signing key made for this test run and tokens signed with
it. No key or token here exists outside the run. Never imported by code that ships."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import jwt
from cryptography.hazmat.primitives.asymmetric import rsa

from plots.entrypoints.fastapi_app import TokenRules

ISSUER = "https://sign-in.garden.example"
AUDIENCE = "plots"
SCOPE = "plots:read"

RUN_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)
RULES = TokenRules(public_key=RUN_KEY.public_key(), issuer=ISSUER, audience=AUDIENCE, scope=SCOPE)


def sign(*, scope: str = SCOPE, expires_in: timedelta = timedelta(minutes=5)) -> str:
    """A token carrying what the consumer's real token carries."""
    claims = {
        "iss": ISSUER,
        "aud": AUDIENCE,
        "sub": "rentals",
        "scope": scope,
        "exp": datetime.now(timezone.utc) + expires_in,
    }
    return jwt.encode(claims, RUN_KEY, algorithm="RS256")
```

The provider's conformance test uses the same key for its documented `401` and `403` cases: `{}` as headers for "no token", `{"Authorization": f"Bearer {sign(scope='sheds:read')}"}` for "wrong scope", and `create_app(store, RULES)`.

### Consumer: add to `pact_tests/consumer/test_rentals_plots_pact.py`

```python
# The shape of a token and not a token: no key signed it, so the pact file
# holds no credential.
EXAMPLE_TOKEN = "eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJleGFtcGxlIn0.c2lnbmF0dXJl"
# A pattern on the shape: the mock then refuses a request with no token.
# match.str would accept any string at all.
BEARER = match.regex(f"Bearer {EXAMPLE_TOKEN}", regex=r"^Bearer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$")
FREE = f"plot {PLOT} is free and measures 25 square metres"
```

Every interaction that needs a token adds `.with_header("Authorization", BEARER)` after `.with_request(...)`, and its test builds the client with `PlotsClient(http, token=EXAMPLE_TOKEN)`. The two refusals the consumer handles are interactions of their own:

```python
async def test_rentals_is_refused_without_a_token(pact: Pact) -> None:
    # No header is recorded, so verification sends none.
    (
        pact.upon_receiving("a request for a free plot without a token")
        .given(FREE)
        .with_request("GET", f"/v1/plots/{PLOT}")
        .will_respond_with(401)
    )
    with pact.serve() as mock:
        async with httpx.AsyncClient(base_url=str(mock.url)) as http:
            with pytest.raises(PlotsRefusedToken):
                await PlotsClient(http).plot(PLOT)


async def test_rentals_is_refused_with_an_expired_token(pact: Pact) -> None:
    # One Provider State carries both facts: each state's setup replaces the last.
    (
        pact.upon_receiving("a request for a free plot with an expired token")
        .given(f"{FREE} and the caller's token has expired")
        .with_request("GET", f"/v1/plots/{PLOT}")
        .with_header("Authorization", BEARER)
        .will_respond_with(401)
    )
    with pact.serve() as mock:
        async with httpx.AsyncClient(base_url=str(mock.url)) as http:
            with pytest.raises(PlotsRefusedToken):
                await PlotsClient(http, token=EXAMPLE_TOKEN).plot(PLOT)
```

### Provider: add to `pact_tests/provider/test_plots_provider_pact.py`

`StateStore` gains a `token_expired` flag that `forget` clears and `set(..., token_expired=True)` raises; `states` gains the expired-token entry; the fixture serves `ReplaceToken(create_app(store, RULES), store)` in place of the bare app (`from tests.contract.tokens import RULES, sign`).

```python
        f"plot {PLOT} is free and measures 25 square metres and the caller's token has expired": lambda: store.set(
            Plot(PLOT, "Plot 7", "free", 25), token_expired=True
        ),
```

```python
class ReplaceToken:
    """Wraps the real app for verification only. A request that carries an
    Authorization header gets a token signed with the key made for this run
    in place of the recorded example; a request recorded without one is passed
    on bare. Nothing inside the app, its middleware included, is changed."""

    def __init__(self, app: Any, store: StateStore) -> None:
        self._app, self._store = app, store

    async def __call__(self, scope: dict[str, Any], receive: Any, send: Any) -> None:
        if scope["type"] == "http" and any(name == b"authorization" for name, _ in scope["headers"]):
            life = timedelta(minutes=-1) if self._store.token_expired else timedelta(minutes=5)
            token = f"Bearer {sign(expires_in=life)}".encode()
            headers = [(name, token if name == b"authorization" else value) for name, value in scope["headers"]]
            scope = {**scope, "headers": headers}
        await self._app(scope, receive, send)
```

### What was seen with a token

| Situation | Result |
|---|---|
| Real middleware, nothing swaps the token | Fails: `expected 200 but was 401` |
| The wrapper above, key made per run | Passes, all four interactions. A provider demanding another audience still fails with 401, another scope with 403 |
| `Verifier.add_custom_header("Authorization", <signed token>)` | It **replaces** a recorded header **and adds one where none was recorded**: the "no token" and "expired token" interactions fail (`expected 401 but was 200`) |
| The same custom header, a consumer that never sends a token and recorded no refusal | **Passes.** The forgotten token is never noticed |
| The wrapper, the same consumer | Fails: `expected 200 but was 401` |
| **Token middleware bypassed in the app under test** | **Passes** for a pact with no token at all. Only the two refusal interactions notice (`expected 401 but was 200`) |
| A wrapper that always sets the header | **Passes for a consumer that never sends a token**; the "no token" interaction is what goes red |
| "Expired token → 401" with nothing swapping the token | **Passes for the wrong reason** (the example token is unsigned) and stays green when the provider stops checking expiry |
| The same with the wrapper signing an expired token | Goes red when the provider stops checking expiry |
| A working token recorded in the pact | The pact file, and the broker, then hold a credential |
| Header matched with `match.str` | The mock accepts `Bearer not a token at all` |
| Two `given` states on one interaction | Each setup replaces the last: the result depends on their order |
| Provider drops only its audience check | **Stays green**: no interaction covers it. Pact proves a check only where a refusal interaction exists |

The wrapper sees interaction requests only: Provider State calls go to pact-python's own callback server, not to the app. A token injected from a Provider State was tried and did not work: `match.regex` takes no generator, and with `match.str(value, generator=generate.provider_state(...))` no generator was written to the pact, so the recorded example was replayed (401), with a function handler and with a URL handler alike.

## What was seen

| Situation | Result |
|---|---|
| Broker holds no pact for the provider | Test fails: `No pacts found for provider`. This is the default in pact-python 4.2.0 |
| The same with `set_error_on_empty_pact(enabled=False)` | **Test passes** |
| Verification run without `set_publish_options` | Nothing is recorded: the broker does not know the provider version |
| Provider changes a value the consumer pinned (pact verified before on `main`) | Test fails, exit 1; the failed result is recorded |
| Consumer adds an expectation the provider does not meet, `include_pending()` | **Test passes**, exit 0; the output shows `Pending Failures`; the failed result is recorded, and `can-i-deploy` refuses the consumer |
| The same without `include_pending()` | Test fails |
| Consumer publishes from a feature branch; `include_wip_since(...)` set | The pact is verified as "work in progress"; a failure is printed and does not fail the test |
| A state name with no handler, guard in place | Fails at once: `expected 404 but was 500`, and the message names the state |
| The same without the store guard | The request runs with no setup. The "nothing exists" interaction **passed** by accident |
| A state missing from a `state_handler({...})` mapping | Fails, after about two minutes of retries (`setup state change handlers has failed`). The function form above fails at once |
| An interaction recorded with no `given` at all | The handler is called with the state `""`; fails with the guard: `expected 404 but was 500` |
| The store guard removed, a state name with no handler | Verification passes; the test still fails on its last line, which names the state |
| Provider starts returning `waitlist`; consumer matched `status` with `match.regex` | Fails: `Expected 'waitlist' to match '^(free|rented|closed)$'` |
| The same, consumer matched `status` with `match.str("free")` | **Passes**: a type-only matcher accepts any string |
| A consumer test that fails | Its interaction is **not** written (the `record_pact` fixture). A fixture that writes the file in plain teardown wrote it anyway |
| One consumer test deleted, `pacts/` left in place | The old interaction stays in the file: `write_file` merges. `make pact-consumer` removes `pacts/` first |
| `-m pact` selects no test, or the folder is empty | pytest exits 5, and the make target fails |
| A Pact test file placed under `tests/` | `pytest tests` collects and runs it: Pact would be in `make ci`. The validator fails it |

## Setup notes

- `pip install pact-python` brings the native library as a wheel (`pact-python-ffi`); nothing is compiled and nothing was written under the home folder in these runs. Linux wheels exist per the project's release notes; installing them was not run for this skill.
- `Verifier("plots", host="127.0.0.1")`: with the default host, `add_transport(url="http://127.0.0.1:...")` raises `Host mismatch: 127.0.0.1 != localhost`.
- `verify()` raises `RuntimeError` on a failed verification and returns nothing to check; `verifier.output(strip_ansi=True)` holds the detail.
- Set `PACT_DO_NOT_TRACK=true` wherever Pact runs, a laptop included: the library otherwise sends anonymous usage events.
- The official examples use `requests` and `aiohttp` clients; the `httpx.AsyncClient` used here worked against the mock from an async test.
- Message pacts are not used: events are checked by schema (`./event-contract-tests.md`).
