# HTTP Contract Tests: Harness and Skeletons

Self-contained. Copy when a Python service provides or calls an HTTP API. These tests live in `tests/contract/`, carry no marker, run in `make ci` on every pull request and count towards the coverage gate. Run on Python 3.15.2 with pytest 9.2.0, pytest-asyncio 1.5.0, FastAPI 0.165.0, httpx 0.29.0, respx 0.23.1, openapi-core 0.23.1 and PyYAML 6.0.4, and type-checked with mypy 2.4.1 in strict mode (the code is the lean example's; replace `plots`, `rentals` and the paths with the product's names). Other versions are unverified.

## Contents

Dependencies; harness (`openapi_check.py`, `double.py`); provider conformance test; consumer test; what each one fails on; limits.

## Dependencies

Add to the product's one `pyproject.toml` (owned by `python-makefile`); keep its pytest table as it is (`asyncio_mode = "auto"`, `pythonpath = [".", "src"]`).

```toml
[dependency-groups]
dev = [
    "httpx==0.29.0",
    "openapi-core==0.23.1",
    "pyyaml==6.0.4",
    "types-pyyaml==6.0.12.20261122",
    "respx==0.23.1",
]
```

`tests/__init__.py` and `tests/contract/__init__.py` exist and are empty.

## Harness: copy unchanged into `tests/contract/`

It is test support under `tests/`, so it is outside the measured source and is listed in the coverage report as test support; nothing that ships may import it.

### `tests/contract/openapi_check.py`

```python
"""Test support for contract tests: checks real HTTP responses against an
authored OpenAPI description. It must never be imported by code that ships."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

import httpx
import yaml
from openapi_core import OpenAPI
from openapi_core.datatypes import RequestParameters
from werkzeug.datastructures import Headers, ImmutableMultiDict

METHODS = ("get", "put", "post", "delete", "options", "head", "patch", "trace")
Key = tuple[str, str, str]  # ("GET", "/v1/plots/{id}", "404")


class _Request:
    """An httpx request in the shape openapi-core reads."""

    def __init__(self, request: httpx.Request) -> None:
        self.host_url = f"{request.url.scheme}://{request.url.netloc.decode()}"
        self.path = request.url.path
        self.method = request.method.lower()
        self.body = request.content or None
        self.content_type = request.headers.get("content-type", "")
        self.parameters = RequestParameters(
            query=ImmutableMultiDict(request.url.params.multi_items()),
            header=Headers(list(request.headers.items())),
            cookie=ImmutableMultiDict(),
        )


class _Response:
    """An httpx response in the shape openapi-core reads."""

    def __init__(self, response: httpx.Response) -> None:
        self.status_code = response.status_code
        self.headers = Headers(list(response.headers.items()))
        self.content_type = response.headers.get("content-type", "")
        self.data = response.content or None


class Description:
    """One authored OpenAPI description, read from its file and never from the
    running app: FastAPI's own /openapi.json describes the code, not the contract."""

    def __init__(self, path: Path | str) -> None:
        self.path = Path(path)
        self._document: dict[str, Any] = yaml.safe_load(self.path.read_text(encoding="utf-8"))
        self._openapi = OpenAPI.from_file_path(str(self.path))

    def _resolve(self, node: dict[str, Any]) -> dict[str, Any]:
        while "$ref" in node:
            target: Any = self._document
            for part in node["$ref"].removeprefix("#/").split("/"):
                target = target[part.replace("~1", "/").replace("~0", "~")]
            node = target
        return node

    def _operations(self) -> list[tuple[str, str, dict[str, Any]]]:
        found = []
        for template, item in self._document.get("paths", {}).items():
            for method in METHODS:
                if method in self._resolve(item):
                    found.append((method.upper(), template, self._resolve(item)[method]))
        return found

    def documented(self) -> set[Key]:
        """Every (METHOD, path template, status) the description documents.
        "default" and ranges such as "2XX" are returned as written: no case can
        name them, so they surface as responses that were never exercised."""
        return {
            (method, template, str(status))
            for method, template, operation in self._operations()
            for status in operation.get("responses", {})
        }

    def _operation_for(self, method: str, path: str) -> tuple[str, dict[str, Any]]:
        matches = []
        for verb, template, operation in self._operations():
            pattern = "".join(
                "[^/]+" if part.startswith("{") else re.escape(part)
                for part in re.split(r"(\{[^}]*\})", template)
            )
            if verb == method and re.fullmatch(pattern, path):
                matches.append((template.count("{"), template, operation))
        if not matches:
            raise AssertionError(f"{method} {path} is not an operation of {self.path.name}")
        _, template, operation = min(matches)
        return template, operation

    def check(self, response: httpx.Response) -> Key:
        """Fail unless the response is one the description documents for the
        request that produced it. Returns (METHOD, path template, status)."""
        request = response.request
        method, status = request.method.upper(), str(response.status_code)
        template, operation = self._operation_for(method, request.url.path)
        label = f"{method} {template} {status}"
        responses = operation.get("responses", {})
        # openapi-core accepts any status once "default" or a range such as
        # "4XX" exists; the contract has to name each status.
        if status not in {str(key) for key in responses}:
            raise AssertionError(f"{label}: status {status} is not documented for this operation")
        errors = list(self._openapi.iter_response_errors(_Request(request), _Response(response)))
        if errors:
            details = []
            for error in errors:
                cause = error.__cause__
                nested = getattr(cause, "schema_errors", None) or ()
                details += [item.message for item in nested] or [str(cause or error)]
            raise AssertionError(f"{label}: " + "; ".join(details))
        documented = self._resolve(responses[status] if status in responses else responses[int(status)])
        # openapi-core does not look at a body the description does not describe.
        if response.content and not documented.get("content"):
            raise AssertionError(f"{label}: a body was sent where the description documents none")
        return (method, template, status)
```

### `tests/contract/double.py`

```python
"""Test support: a stand-in for a provider in a consumer's test. It must never
be imported by code that ships, and it never imports the provider's code."""

from __future__ import annotations

from typing import Any

import httpx
import respx

from tests.contract.openapi_check import Description


class ProviderDouble:
    """Every canned response is checked against the provider's description when
    it is added, so the consumer is never tested against a response the
    provider does not promise."""

    def __init__(self, description: Description, base_url: str = "http://provider.test") -> None:
        self._description = description
        self._base_url = base_url
        # A request no route matches raises; assert_all_called() is ours to call.
        self._router = respx.Router(base_url=base_url, assert_all_mocked=True, assert_all_called=True)

    def respond(
        self,
        method: str,
        path: str,
        status: int,
        *,
        json: Any = None,
        headers: dict[str, str] | None = None,
    ) -> respx.Route:
        request = httpx.Request(method, self._base_url + path)
        self._description.check(httpx.Response(status, json=json, headers=headers, request=request))
        return self._router.route(method=method, path=path).mock(
            return_value=httpx.Response(status, json=json, headers=headers)
        )

    def client(self) -> httpx.AsyncClient:
        """The httpx client to hand to the real client under test."""
        return httpx.AsyncClient(
            transport=httpx.MockTransport(self._router.async_handler), base_url=self._base_url
        )

    def assert_all_called(self) -> None:
        """Fail when a canned response was never asked for."""
        self._router.assert_all_called()
```

## Provider conformance test: adapt

One file per provider, `tests/contract/test_<provider>_conformance.py`. It drives the **real app** built by the product's own factory, with its real routes, middleware and handlers, in-process over `httpx.ASGITransport`, and checks every real response against the **authored** description file. The data behind the port can be a fake store, as here, or the real database from `python-integration-test`'s harness; which behaviour is proved against the database is that skill's subject. Give every documented status a case, one row each with its own id (Okken): the last test fails when a documented response has none.

### `tests/contract/test_plots_conformance.py`

```python
"""Provider conformance: the real plots app, with its real routes, middleware
and handlers, answers only what api/openapi.yaml documents."""

from __future__ import annotations

from pathlib import Path

import httpx
import pytest

from plots.entrypoints.fastapi_app import Plot, PlotStore, create_app
from tests.contract.openapi_check import Description, Key

SPEC = Description(Path(__file__).parents[2] / "api" / "openapi.yaml")
PLOT = "3f0a1d52-6c1d-4f6e-9a57-2f1c5f0d9b11"


class FakeStore:
    def __init__(self, *plots: Plot) -> None:
        self._plots = {plot.id: plot for plot in plots}

    async def find(self, plot_id: str) -> Plot | None:
        return self._plots.get(plot_id)


class BrokenStore:
    async def find(self, plot_id: str) -> Plot | None:
        raise RuntimeError("the database is away")


# One case for every response the description documents: the store behind the
# app, and the request that must produce exactly that status.
CASES: dict[Key, tuple[PlotStore, str]] = {
    ("GET", "/v1/plots/{id}", "200"): (
        FakeStore(Plot(PLOT, "Plot 7", "free", 25, free_from="2026-12-01T09:00:00Z", note="by the gate")),
        f"/v1/plots/{PLOT}",
    ),
    ("GET", "/v1/plots/{id}", "400"): (FakeStore(), "/v1/plots/not-a-uuid"),
    ("GET", "/v1/plots/{id}", "404"): (FakeStore(), f"/v1/plots/{PLOT}"),
    ("GET", "/v1/plots/{id}", "500"): (BrokenStore(), f"/v1/plots/{PLOT}"),
}


@pytest.mark.parametrize("key", sorted(CASES), ids=" ".join)
async def test_the_response_is_the_documented_one(key: Key) -> None:
    store, path = CASES[key]
    # raise_app_exceptions=False: the documented 500 is read, not raised here.
    transport = httpx.ASGITransport(app=create_app(store), raise_app_exceptions=False)
    async with httpx.AsyncClient(transport=transport, base_url="http://plots.test") as client:
        response = await client.request(key[0], path)
    assert SPEC.check(response) == key


def test_every_documented_response_has_a_case() -> None:
    never_exercised = sorted(SPEC.documented() - set(CASES))
    assert not never_exercised, "documented responses that no contract test exercises: " + ", ".join(
        " ".join(key) for key in never_exercised
    )
```

- `ASGITransport` does not run the app's lifespan (stated in the httpx documentation), so the factory receives what lifespan would have set.
- A provider that checks a token gets a `401` and a `403` case with tokens signed by a key made for the run: `./pact-tests.md`, "When the provider checks a token".

## Consumer test: adapt

One file beside nothing of the provider's: `tests/contract/test_<consumer>_<provider>_client.py`. The **real client** runs against the double; each canned response is checked against the provider's description first, so the test cannot drift from what the provider promises. The test never imports the provider's app: when the provider is in another repository, the description is a copy fetched at the provider's deployed commit.

### `tests/contract/test_rentals_plots_client.py`

```python
"""Consumer contract: the real rentals client against a double that only
answers what the plots description promises. Nothing here imports plots."""

from __future__ import annotations

from pathlib import Path

import pytest

from rentals.adapters.plots_client import Plot, PlotNotFound, PlotsClient
from tests.contract.double import ProviderDouble
from tests.contract.openapi_check import Description

# The provider's description. In another repository: a copy fetched at the
# provider's deployed commit.
PLOTS = Description(Path(__file__).parents[2] / "api" / "openapi.yaml")
PLOT = "3f0a1d52-6c1d-4f6e-9a57-2f1c5f0d9b11"


async def test_rentals_reads_a_free_plot() -> None:
    double = ProviderDouble(PLOTS)
    double.respond(
        "GET",
        f"/v1/plots/{PLOT}",
        200,
        # "note" is a field rentals does not read: the client must ignore it.
        json={"id": PLOT, "name": "Plot 7", "status": "free", "sizeSquareMetres": 25, "note": "by the gate"},
    )
    async with double.client() as http:
        plot = await PlotsClient(http).plot(PLOT)
    # The values, not just "no error": a misspelt field name shows here.
    assert plot == Plot(id=PLOT, name="Plot 7", status="free", size_square_metres=25)
    assert plot.rentable()
    double.assert_all_called()


async def test_rentals_learns_a_plot_is_missing() -> None:
    double = ProviderDouble(PLOTS)
    double.respond(
        "GET", f"/v1/plots/{PLOT}", 404, json={"error": {"code": "not_found", "message": "No plot has this id."}}
    )
    async with double.client() as http:
        with pytest.raises(PlotNotFound):
            await PlotsClient(http).plot(PLOT)
    double.assert_all_called()


def test_a_status_rentals_does_not_know_is_not_rentable() -> None:
    # The double cannot serve a value outside the documented set, so the
    # tolerant default is tested on the client's own model.
    assert not Plot(id=PLOT, name="Plot 7", status="waitlist", size_square_metres=25).rentable()
```

## What was seen to fail

Each line is one change made to the lean example, with the test that went red.

| Change | Result |
|---|---|
| Provider renames `sizeSquareMetres` | Conformance: `'sizeSquareMetres' is a required property` |
| Provider answers `410` where `404` is documented | Conformance: `status 410 is not documented for this operation` |
| Provider returns a status value outside the enum | Conformance: `'waitlist' is not one of ['free', 'rented', 'closed']` |
| Provider returns `P-7` as the id, or `next week` as `freeFrom` | Conformance: `'P-7' is not a 'uuid'`; `'next week' is not a 'date-time'` |
| The `500` case is removed from the table | `documented responses that no contract test exercises: GET /v1/plots/{id} 500` |
| The description gains a `default` response | The same test fails, listing `GET /v1/plots/{id} default`; a `418` answered under it fails as not documented |
| Consumer's canned response lacks a required field, or holds a status outside the enum | Consumer test fails at `respond`: the provider does not promise it |
| Consumer reads `body.get("size_square_metres")` | Value assertion: `size_square_metres=None`, wanted `25`. Reading the body raised nothing |
| Consumer never makes the call | `RESPX: some routes were not called!` (from `assert_all_called()`) |
| Consumer calls a path the double has no answer for | `AllMockedAssertionError: ... not mocked!` |
| Consumer rejects a field it does not know | Fails on the extra `note` in the canned response |

## Limits to state

- openapi-core alone accepts any status once the description has a `default` or a range such as `4XX`, and ignores a body sent where the documented response has no content (both run). The harness fails both.
- A response field the description does not declare passes: response schemas stay open so that additions do not break readers (run).
- `uuid` and `date-time` formats are checked by openapi-core without extra setup (run). Any other format the description relies on was not run; test that a wrong value is refused before trusting it.
- A request for an operation the description does not have (a `HEAD`, an unknown path) fails the check; nothing is skipped silently (run).
- `fastapi.testclient.TestClient` was not used: it runs the app on another event loop (`python-integration-test`).
- A case marked `skip` or `xfail` is a documented response nobody exercised; the validator warns on it.
- Schemathesis can be run **on top** of this test to explore inputs nobody thought of: `schemathesis.openapi.from_path("api/openapi.yaml")` with `case.call_and_validate(session=ASGIClient(app), base_url=...)` checked the in-process app against the authored file and failed an undocumented status (`ST103`), with schemathesis 4.34.4. It does not replace the table: a run that only ever produced `404` passed, so it does not show that each documented status was exercised. Its `from_asgi("/openapi.json", app)` loader reads the description the app serves (here `200` and `422`), not the authored one (`200`, `400`, `404`, `500`), and is not used. It sends real requests that create and delete data, so give it a fake store or a throwaway database.
