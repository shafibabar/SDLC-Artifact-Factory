# Lean: a School's Lost-Property Register

One Python service (`lost-property`, FastAPI) with a PostgreSQL database and a small web shell; one team, no tenants, no broker. **Lean changes the number of releases and journeys. It does not change the environment**: the suite still runs in a throwaway kind cluster that the run creates and deletes, through the same script, guard and folders.

Run on 2026-11-28: Python 3.15.2, pytest 9.2.0, httpx 0.29.0, uv 0.13.9, kind v0.33.0 (Kubernetes v1.37.0), Helm v4.3.2, kubectl v1.36.1, Docker 29.9.3, macOS arm64. The service in the run was a lab stand-in configured with this product's resource (`items`) and its charts; the scripts, the guard and the suite files are the shipped ones, unchanged.

## Plan

| Journey | Acceptance criteria | Why it is end-to-end |
|---|---|---|
| A handed-in item is kept and listed | AC-US-1.1, AC-US-1.2 | The deployed service must reach its deployed database through the chart's configuration |
| A reclaimed item is gone | AC-US-1.4 | The same path, for removal |

| Proven lower instead | Layer |
|---|---|
| Which fields an item needs, date rules | Unit (`python-unit-test`) |
| SQL, constraints, migration | Integration (`python-integration-test`) |
| Response shapes | Contract (`python-contract-test`) |

Two journeys and one read-only smoke test are the whole suite. The browser journey ("a caretaker records a found scarf on the page") belongs to `react-e2e-testing` and would be one more line of `E2E_SUITES`; the web shell is installed and awaited here so that suite has something to open.

## Files

`support.py`, `conftest.py`, `journeys/test_guard_selfcheck.py`, `smoke/test_smoke_guard.py` and the two scripts are copied unchanged (`../templates/python-suite.md`).

### `tests/e2e/e2e.conf`

```bash
# tests/e2e/e2e.conf: read by tests/e2e/run-e2e-environment.sh
E2E_NODE_IMAGE="kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
E2E_NAMESPACE="lost-property"
E2E_BUILD="make e2e-images"
E2E_IMAGES="lost-property:e2e web-shell:e2e"
E2E_RELEASES="
postgres|deploy/e2e/postgres|tests/e2e/values/postgres.yaml
lost-property|charts/lost-property|tests/e2e/values/lost-property.yaml
web-shell|charts/web-shell|tests/e2e/values/web-shell.yaml
"
E2E_ENDPOINTS="
api|30080
web|30081
"
E2E_SMOKE_ENDPOINT="api"
E2E_SUITES="
uv run ./tests/e2e/run-python-e2e-suite.sh journeys
uv run ./tests/e2e/run-python-e2e-suite.sh smoke
"
```

### `tests/e2e/values/lost-property.yaml`

```yaml
env:
  RESOURCE: items
  DATABASE_URL: postgres://app:e2e-only-not-a-secret@postgres:5432/app
service:
  type: NodePort
  nodePort: 30080
```

The database is not published to the test process: no journey here needs a direct write, so `E2E_ENDPOINTS` has no `db` line.

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
    """References that belong to one test of one run; nothing is random."""
    name = re.sub(r"[^a-z0-9]+", "-", request.node.name.lower()).strip("-")
    return lambda: f"{env.run_id}-{name}-{next(_counter)}"


@pytest.fixture
def api(env: Env) -> Iterator[httpx.Client]:
    with env.client("api") as client:
        yield client


@pytest.fixture
def create_item(api: httpx.Client) -> Iterator[Callable[..., dict[str, Any]]]:
    """Hands an item in through the public API and removes exactly what it
    created, also when the test fails."""
    made: list[str] = []

    def create(**fields: Any) -> dict[str, Any]:
        reply = api.post("/items", json=fields)
        assert reply.status_code == 201, f"hand in item: {reply.status_code} {reply.text}"
        item: dict[str, Any] = reply.json()
        made.append(item["id"])
        return item

    yield create
    problems = []
    for item_id in reversed(made):
        reply = api.delete(f"/items/{item_id}")
        if reply.status_code not in (204, 404):
            problems.append(f"{item_id}: {reply.status_code}")
    assert not problems, f"cleanup of items failed: {problems}"
```

### `tests/e2e/journeys/test_journey_found_item.py`

```python
from __future__ import annotations

from collections.abc import Callable
from typing import Any

import httpx


def test_journey_handed_in_item_is_kept(api: httpx.Client, create_item: Callable[..., dict[str, Any]], ref: Callable[[], str]) -> None:
    """AC-US-1.1, AC-US-1.2: a caretaker hands an item in and finds it again in the
    register. The deployed service and its deployed database take part, wired by
    the chart."""
    reference = ref()
    made = create_item(reference=reference, description="blue scarf", found_in="gym")

    reply = api.get("/items")
    assert reply.status_code == 200, reply.text
    listed = [item for item in reply.json() if item["id"] == made["id"]]
    assert listed and listed[0]["body"]["reference"] == reference, f"item {made['id']} is not in the register"


def test_journey_reclaimed_item_is_gone(api: httpx.Client, create_item: Callable[..., dict[str, Any]], ref: Callable[[], str]) -> None:
    """AC-US-1.4: a reclaimed item can no longer be read."""
    made = create_item(reference=ref(), description="lunch box", found_in="hall")
    assert api.delete(f"/items/{made['id']}").status_code == 204
    assert api.get(f"/items/{made['id']}").status_code == 404
```

### `tests/e2e/smoke/test_smoke.py`

```python
from __future__ import annotations

import httpx


def test_smoke_register_can_be_read(smoke: httpx.Client) -> None:
    """Reads the register: the service is up and its database answers. It creates
    nothing."""
    reply = smoke.get("/items")
    assert reply.status_code == 200, reply.text
    assert isinstance(reply.json(), list)
```

## The run

`make e2e`, start to finish:

```text
== creating cluster e2e-pe2e-lab-9 (kubeconfig /.../tmp.T2CEZyf0Uk/kubeconfig)
== loading images: lost-property:e2e web-shell:e2e
== installing postgres from deploy/e2e/postgres
== installing lost-property from charts/lost-property
== installing web-shell from charts/web-shell
== waiting for endpoint api on 127.0.0.1:63153
== waiting for endpoint web on 127.0.0.1:63154
== suite: uv run ./tests/e2e/run-python-e2e-suite.sh journeys
tests/e2e/journeys/test_guard_selfcheck.py::test_guard_client_refuses_another_address PASSED
tests/e2e/journeys/test_guard_selfcheck.py::test_guard_client_refuses_a_redirect_to_another_address PASSED
tests/e2e/journeys/test_guard_selfcheck.py::test_guard_seeding_refuses_an_address_outside_the_cluster PASSED
tests/e2e/journeys/test_guard_selfcheck.py::test_guard_marker_must_be_this_run_and_loopback PASSED
tests/e2e/journeys/test_journey_found_item.py::test_journey_handed_in_item_is_kept PASSED
tests/e2e/journeys/test_journey_found_item.py::test_journey_reclaimed_item_is_gone PASSED
== python journeys: 6 ran, 6 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined
== suite: uv run ./tests/e2e/run-python-e2e-suite.sh smoke
tests/e2e/smoke/test_smoke.py::test_smoke_register_can_be_read PASSED
tests/e2e/smoke/test_smoke_guard.py::test_smoke_writes_are_refused PASSED
tests/e2e/smoke/test_smoke_guard.py::test_smoke_client_refuses_another_address PASSED
== python smoke: 3 ran, 3 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined
== deleting cluster e2e-pe2e-lab-9
== end-to-end run pe2e-lab-9 passed; cluster deleted
```

`validate-python-e2e-tests.sh .` reported `0 FAIL, 0 WARN`. `kind get clusters` afterwards did not list the run's cluster, and the caller's kubeconfig was not created or changed.

## What a reply to "it's a tiny product, just run pytest against the dev database with Docker Compose" says

- No: the suite runs in a throwaway kind cluster created for the run, **at every product size, lean included**, and never against a shared, dev or staging environment, because journeys create and delete data and because Compose is a second description of the deployment that the charts do not keep in step.
- Lean is already the small version: three releases, two journeys, one smoke test; the run above took 49 seconds with the images already built.
- `pytest tests/e2e` by hand, with any address variable, is refused before a request is sent: the journeys take their addresses only from the marker inside the cluster their own run created.
- There is no lighter variant to offer: the product owner decided on 2026-11-28 that every size uses the cluster.
