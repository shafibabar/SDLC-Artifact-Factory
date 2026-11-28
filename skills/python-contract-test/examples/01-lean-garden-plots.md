# Lean: a Community Garden's Plot Rentals

Two Python services in one repository: `plots` serves the garden's plots, `rentals` calls `GET /v1/plots/{id}` before taking a rental. No events, so no event checks. Lean means two services and one call; it still gets every check, **including Pact on a self-hosted broker**, because `rentals` calls `plots` directly.

Run on 2026-11-28: Python 3.15.2 (macOS arm64), uv 0.13.9, pytest 9.2.0, FastAPI 0.165.0, httpx 0.29.0, respx 0.23.1, openapi-core 0.23.1, oasdiff 1.39.0, pact-python 4.2.0 with `pact-python-ffi` 0.5.13.0, `pact-python-cli` 1!1.0.0, `pactfoundation/pact-broker:3.2.0-pactbroker2.124.0` on `postgres:17-alpine`. Not run: the GitHub Actions workflow files (their make targets were run by hand in the same order) and `make contract-baseline` (the baseline was copied in by hand).

## Plan

| Boundary | Every pull request | Daily |
|---|---|---|
| `plots` API description | `make api-gate`: `check-openapi-breaking.sh` against the deployed description | |
| `plots` as provider | Conformance test through the real app, every documented status | Pact verification of `rentals`' pact |
| `rentals` as consumer | Real client against a double checked against the description | Pact consumer test, pact published |
| Deployment of either | | `can-i-deploy` before, `record-deployment` after |

Size of the broker at lean: one `pact-broker` container and one small PostgreSQL database, self-hosted. Nothing paid.

## Files

`tests/contract/openapi_check.py` and `double.py`, the two contract tests, `pact_tests/conftest.py`, the two Pact tests, the make targets and both workflows are the files in `../templates/http-contract-tests.md`, `../templates/pact-tests.md` and `../templates/workflows.md`, unchanged: those templates were cut from this example (without the `event-gate` target, since there are no events).

### `api/openapi.yaml`

```yaml
openapi: 3.1.0
info:
  title: Plots API
  version: 1.0.0
paths:
  /v1/plots/{id}:
    get:
      operationId: getPlot
      parameters:
        - name: id
          in: path
          required: true
          schema: { type: string, format: uuid }
      responses:
        "200":
          description: The plot.
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Plot" }
        "400":
          description: The id is not a UUID.
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Error" }
        "404":
          description: No plot has this id.
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Error" }
        "500":
          description: Unexpected failure.
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Error" }
components:
  schemas:
    Plot:
      type: object
      required: [id, name, status, sizeSquareMetres]
      properties:
        id: { type: string, format: uuid }
        name: { type: string }
        status: { type: string, enum: [free, rented, closed] }
        sizeSquareMetres: { type: integer, minimum: 1 }
        freeFrom: { type: string, format: date-time }
        note: { type: string }
    Error:
      type: object
      required: [error]
      properties:
        error:
          type: object
          required: [code, message]
          properties:
            code: { type: string }
            message: { type: string }
```

### `src/plots/entrypoints/fastapi_app.py`

```python
"""The plots service: a community garden's plots and whether each can be rented."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from typing import Protocol

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


@dataclass(frozen=True)
class Plot:
    id: str
    name: str
    status: str
    size_square_metres: int
    free_from: str | None = None
    note: str | None = None


class PlotStore(Protocol):
    async def find(self, plot_id: str) -> Plot | None: ...


def _error(status: int, code: str, message: str) -> JSONResponse:
    return JSONResponse(status_code=status, content={"error": {"code": code, "message": message}})


def create_app(store: PlotStore) -> FastAPI:
    app = FastAPI(title="Plots API", version="1.0.0")

    @app.exception_handler(Exception)
    async def unexpected(_: Request, __: Exception) -> JSONResponse:
        return _error(500, "internal", "Unexpected failure.")

    @app.get("/v1/plots/{plot_id}", operation_id="getPlot")
    async def get_plot(plot_id: str) -> JSONResponse:
        try:
            uuid.UUID(plot_id)
        except ValueError:
            return _error(400, "invalid_id", "The id is not a UUID.")
        plot = await store.find(plot_id)
        if plot is None:
            return _error(404, "not_found", "No plot has this id.")
        body: dict[str, object] = {
            "id": plot.id,
            "name": plot.name,
            "status": plot.status,
            "sizeSquareMetres": plot.size_square_metres,
        }
        if plot.free_from is not None:
            body["freeFrom"] = plot.free_from
        if plot.note is not None:
            body["note"] = plot.note
        return JSONResponse(body)

    return app
```

### `src/rentals/adapters/plots_client.py`

```python
"""The rentals service's client for the plots service."""

from __future__ import annotations

from dataclasses import dataclass

import httpx

RENTABLE = "free"


class PlotNotFound(Exception):
    pass


class PlotsUnavailable(Exception):
    pass


@dataclass(frozen=True)
class Plot:
    id: str
    name: str
    status: str
    size_square_metres: int

    def rentable(self) -> bool:
        # A status this client does not know is treated as not rentable.
        return self.status == RENTABLE


class PlotsClient:
    def __init__(self, http: httpx.AsyncClient) -> None:
        self._http = http

    async def plot(self, plot_id: str) -> Plot:
        response = await self._http.get(f"/v1/plots/{plot_id}")
        if response.status_code == 404:
            raise PlotNotFound(plot_id)
        if response.status_code != 200:
            raise PlotsUnavailable(f"plots answered {response.status_code}")
        body = response.json()
        # Only the fields rentals reads; anything else in the body is ignored.
        return Plot(
            id=body["id"],
            name=body["name"],
            status=body["status"],
            size_square_metres=body["sizeSquareMetres"],
        )
```

Both are written compactly to keep the example short: a product splits them into the layers of `python-project-structure` and builds responses from Pydantic models. `src/plots/`, `src/rentals/` and their subfolders each hold an empty `__init__.py`.

## Every pull request

```text
$ uv run pytest tests                                # in the product: part of make test
8 passed

$ make api-gate                                      # after removing the optional field `note` from the description
exceptions in force: 0
1 changes: 1 error, 0 warning, 0 info
error   [response-optional-property-removed] at .contract-baseline/openapi.yaml
        in API GET /v1/plots/{id}
                removed the optional property `note` from the response with the `200` status
FAIL: breaking change. Keep the change additive, or publish it as a new major version beside the old one.
removed endpoints: 0
RESULT: FAIL
make: *** [api-gate] Error 1                         # make exits 2
```

The same removal with plain `oasdiff breaking --fail-on WARN` exits 0 (`No breaking changes to report`): oasdiff rates it as information. The shipped severity file is what turns it into a failure. Failing test runs for a broken provider and a broken consumer are listed in `../templates/http-contract-tests.md`. The coverage gate of `python-unit-test`, which `make test` runs, was not run for this example.

## The daily Pact run

```text
$ make pact-consumer
2 passed
$ make pact-publish                                  # GIT_SHA=7c2d9e4 GIT_BRANCH=main
Pact successfully published for rentals version 7c2d9e4 and provider plots.
$ make pact-provider                                 # PACT_PUBLISH_RESULTS=true
1 passed
$ make pact-report                                   # make exits 2 on the first day: nothing is deployed yet
```

The report it wrote on the first day (frontmatter and fixed text omitted):

```markdown
**1 check(s) need attention.**

| Service | Environment | Result | What the broker said |
|---|---|---|---|
| plots | production | verified | There are no missing dependencies |
| rentals | production | NOT VERIFIED | There is no verified pact between version 7c2d9e4 of rentals and a version of plots currently in production (no version is currently recorded as deployed/released in this environment) |
```

## First deployment and unknown commits

```text
$ pact broker can-i-deploy --pacticipant rentals --version 7c2d9e4 --to-environment production
Computer says no                                                                    # exit 1
$ pact broker can-i-deploy --pacticipant plots --version 7c2d9e4 --to-environment production
Computer says yes                                                                   # exit 0
$ pact broker record-deployment --pacticipant plots --version 7c2d9e4 --environment production
$ pact broker can-i-deploy --pacticipant rentals --version 7c2d9e4 --to-environment production
Computer says yes                                                                   # exit 0
$ pact broker record-deployment --pacticipant rentals --version 7c2d9e4 --environment production
$ make pact-report                                                                  # exit 0
| plots | production | verified | All required verification results are published and successful |
| rentals | production | verified | All required verification results are published and successful |
$ pact broker can-i-deploy --pacticipant plots --version 0000000 --to-environment production
No pacts or verifications have been published for version 0000000 of plots         # exit 1
```

So the provider deploys first, and a commit no Pact run has seen cannot deploy until `pact-daily` is started by hand for it.

## A breaking change, as it surfaced

For this run `plots` was changed to return ids in upper case (commit `e58a1c3`). An upper-case UUID is still a `uuid`, so the description did not change and every pull-request check stayed green. `rentals` compares the id it gets with the one it asked for, and its pact pins that value: this is what Cruz and Prescott mean by the values a consumer relies on beyond the shape.

```text
$ uv run pytest tests                                # conformance and consumer contract tests
8 passed
$ make api-gate
RESULT: PASS (shape only: a change of meaning, unit or behaviour is not detected)

$ make pact-provider                                 # next daily run, commit e58a1c3
    $.id -> Expected '3F0A1D52-6C1D-4F6E-9A57-2F1C5F0D9B11' (String) to be equal to '3f0a1d52-6c1d-4f6e-9a57-2f1c5f0d9b11' (String)
There were 1 pact failures
1 failed                                             # make exits 2
$ make pact-report                                   # make exits 2
| plots | production | BROKEN | The verification for the pact between the version of rentals currently in production (7c2d9e4) and version e58a1c3 of plots failed |
| production | rentals 7c2d9e4 | plots e58a1c3 | FAILED |
$ pact broker can-i-deploy --pacticipant plots --version e58a1c3 --to-environment production
The verification for the pact between the version of rentals currently in production (7c2d9e4) and version e58a1c3 of plots failed
Computer says no                                     # exit 1: the deployment is refused
```

The pull request that made the change was **not** blocked by Pact, and here nothing else blocked it either. The break appeared in the next day's run and report, and the deployment check refused the commit.

## For the product owner

- The daily report is approved by the product owner (`artifacts/garden-plots/quality/test-reports/pact-impact-2026-11-28.md`).
- No exception or retirement record exists yet; both files hold only their comment lines.
