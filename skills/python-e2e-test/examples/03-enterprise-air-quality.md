# Enterprise: a Regional Air-Quality Network, Go and Python Together

A multi-tenant platform: each city authority is a tenant. `readings` is a Go service (PostgreSQL) that takes sensor readings; `alerts` is a Python service (FastAPI) that raises an alert when a reading is over its limit; a web shell shows both. This example shows **one environment for two languages**, tenant isolation proven across services, a quarantined test, the release gate, and smoke tests after each tenant's deployment.

Run on 2026-11-28: Python 3.15.2, pytest 9.2.0, httpx 0.29.0, uv 0.13.9, Go 1.27.4, kind v0.33.0 (Kubernetes v1.37.0), Helm v4.3.2, kubectl v1.36.1, Docker 29.9.3, macOS arm64. Both services in the run were a lab stand-in configured with this product's resources and charts; the scripts, guards and copied suite files of both skills are the shipped ones, unchanged.

## Plan

| Journey | Language | Acceptance criteria | Why it is end-to-end |
|---|---|---|---|
| A reading over the limit raises an alert | Python | AC-US-7.1, AC-US-7.2 | Two deployed services and a later effect |
| One authority cannot read another's reading or alert | Python | AC-US-9.1 | Tenant isolation must hold across both services as deployed, not only in one service's queries |
| A corrected reading is alerted again | Python | AC-US-7.4 | Same path; **quarantined** after two flakes |
| A recorded reading is kept; a withdrawn reading is gone | Go | AC-US-6.1, AC-US-6.3 | The Go service and its database as deployed (`go-e2e-test` owns those files) |

A journey that crosses both services is written once, here in Python: it drives both over the network and imports neither. Which language holds it is the team's choice; it is never written twice.

## Files

`support.py`, `conftest.py`, `journeys/test_guard_selfcheck.py`, `smoke/test_smoke_guard.py` and `run-python-e2e-suite.sh` are copied unchanged from this skill. `run-e2e-environment.sh`, `run-go-e2e-suite.sh` and the Go files in `tests/e2e/*_test.go` come from `go-e2e-test`; `run-e2e-environment.sh` is the same program in both skills, so the product keeps one copy.

### `tests/e2e/e2e.conf`

```bash
# tests/e2e/e2e.conf: read by tests/e2e/run-e2e-environment.sh
E2E_NODE_IMAGE="kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
E2E_NAMESPACE="air-quality"
E2E_BUILD="make e2e-images"
E2E_IMAGES="readings:e2e alerts:e2e web-shell:e2e"
E2E_RELEASES="
postgres|deploy/e2e/postgres|tests/e2e/values/postgres.yaml
alerts|charts/alerts|tests/e2e/values/alerts.yaml
readings|charts/readings|tests/e2e/values/readings.yaml
web-shell|charts/web-shell|tests/e2e/values/web-shell.yaml
"
E2E_ENDPOINTS="
api|30080
alerts|30081
web|30082
"
E2E_SMOKE_ENDPOINT="api"
# One environment, one script run, one suite line per language and selection.
E2E_SUITES="
./tests/e2e/run-go-e2e-suite.sh journeys
uv run ./tests/e2e/run-python-e2e-suite.sh journeys
./tests/e2e/run-go-e2e-suite.sh smoke
uv run ./tests/e2e/run-python-e2e-suite.sh smoke
uv run ./tests/e2e/run-python-e2e-suite.sh quarantine
"
```

### `tests/e2e/values/readings.yaml`

```yaml
env:
  RESOURCE: readings
  DATABASE_URL: postgres://app:e2e-only-not-a-secret@postgres:5432/app
  DOWNSTREAM_URL: http://alerts:8080
  DOWNSTREAM_RESOURCE: alerts
  DOWNSTREAM_DELAY_MS: "1500"
service:
  type: NodePort
  nodePort: 30080
```

### `tests/e2e/quarantine-python.txt`

```text
# node id | issue URL | deadline (two weeks from quarantine unless the strategy says otherwise)
tests/e2e/journeys/test_journey_alerts.py::test_journey_corrected_reading_is_alerted_again | https://github.com/example-org/air-quality/issues/512 | 2026-12-09
```

Go tests are quarantined in `tests/e2e/quarantine.txt`, by Go test name. The two lists stay separate: each runner refuses the other's lines.

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
# Test-only tenants of the end-to-end values files. No real authority exists in the suite.
NORTH = {"X-Tenant": "e2e-north"}
SOUTH = {"X-Tenant": "e2e-south"}


@pytest.fixture
def ref(env: Env, request: pytest.FixtureRequest) -> Callable[[], str]:
    """References that belong to one test of one run; nothing is random."""
    name = re.sub(r"[^a-z0-9]+", "-", request.node.name.lower()).strip("-")
    return lambda: f"{env.run_id}-{name}-{next(_counter)}"


@pytest.fixture
def north(env: Env) -> Iterator[httpx.Client]:
    with env.client("api", headers=NORTH) as client:
        yield client


@pytest.fixture
def south(env: Env) -> Iterator[httpx.Client]:
    with env.client("api", headers=SOUTH) as client:
        yield client


@pytest.fixture
def north_alerts(env: Env) -> Iterator[httpx.Client]:
    with env.client("alerts", headers=NORTH) as client:
        yield client


@pytest.fixture
def south_alerts(env: Env) -> Iterator[httpx.Client]:
    with env.client("alerts", headers=SOUTH) as client:
        yield client


@pytest.fixture
def create_reading(north: httpx.Client) -> Iterator[Callable[..., dict[str, Any]]]:
    """Records a reading for the north authority through the public API and removes
    exactly what it created, also when the test fails."""
    made: list[str] = []

    def create(**fields: Any) -> dict[str, Any]:
        reply = north.post("/readings", json=fields)
        assert reply.status_code == 201, f"record reading: {reply.status_code} {reply.text}"
        reading: dict[str, Any] = reply.json()
        made.append(reading["id"])
        return reading

    yield create
    problems = []
    for reading_id in reversed(made):
        reply = north.delete(f"/readings/{reading_id}")
        if reply.status_code not in (204, 404):
            problems.append(f"{reading_id}: {reply.status_code}")
    assert not problems, f"cleanup of readings failed: {problems}"
```

### `tests/e2e/journeys/test_journey_alerts.py`

```python
from __future__ import annotations

from collections.abc import Callable
from typing import Any

import httpx

from tests.e2e.support import eventually


def _alerted(client: httpx.Client, reading_id: str) -> dict[str, Any]:
    """Polls until the reading carries its alert; returns the reading."""

    def check() -> dict[str, Any]:
        reply = client.get(f"/readings/{reading_id}")
        assert reply.status_code == 200, reply.text
        reading: dict[str, Any] = reply.json()
        assert reading["status"] == "confirmed", f"reading status {reading['status']!r}"
        return reading

    return eventually(f"reading {reading_id} alerted", check, within=20)


def test_journey_reading_over_the_limit_raises_an_alert(
    north: httpx.Client, north_alerts: httpx.Client, create_reading: Callable[..., dict[str, Any]], ref: Callable[[], str]
) -> None:
    """AC-US-7.1, AC-US-7.2: a sensor reading over its limit is recorded by the
    readings service and the alerts service raises an alert for it, later."""
    made = create_reading(reference=ref(), sensor="quay-3", pm25=91)
    reading = _alerted(north, made["id"])

    reply = north_alerts.get(f"/alerts/{reading['body']['downstream_id']}")
    assert reply.status_code == 200, reply.text
    assert reply.json()["body"]["source_id"] == made["id"]


def test_journey_one_authority_cannot_read_anothers(
    north: httpx.Client, south: httpx.Client, south_alerts: httpx.Client,
    create_reading: Callable[..., dict[str, Any]], ref: Callable[[], str],
) -> None:
    """AC-US-9.1: what the north authority records, the south authority can read
    neither in the readings service nor in the alerts service."""
    made = create_reading(reference=ref(), sensor="mill-road", pm25=120)
    reading = _alerted(north, made["id"])

    assert south.get(f"/readings/{made['id']}").status_code == 404
    assert south_alerts.get(f"/alerts/{reading['body']['downstream_id']}").status_code == 404
    listed = south.get("/readings")
    assert listed.status_code == 200 and all(item["id"] != made["id"] for item in listed.json())


def test_journey_corrected_reading_is_alerted_again(
    north: httpx.Client, create_reading: Callable[..., dict[str, Any]], ref: Callable[[], str]
) -> None:
    """AC-US-7.4: a corrected reading that is still over the limit is alerted again."""
    first = create_reading(reference=ref(), sensor="quay-3", pm25=88)
    _alerted(north, first["id"])
    second = create_reading(reference=ref(), sensor="quay-3", pm25=95, corrects=first["id"])
    _alerted(north, second["id"])
```

### `tests/e2e/smoke/test_smoke.py`

```python
from __future__ import annotations

import httpx


def test_smoke_readings_can_be_listed_for_the_tenant(smoke: httpx.Client) -> None:
    """Reads the readings of the tenant in E2E_SMOKE_TENANT (none: the default
    tenant). The service is up, its database answers, the tenant is known. It
    creates nothing."""
    reply = smoke.get("/readings")
    assert reply.status_code == 200, reply.text
    assert isinstance(reply.json(), list)
```

## The run

`make e2e`, with the per-test lines of both runners shortened:

```text
== suite: ./tests/e2e/run-go-e2e-suite.sh journeys
--- PASS: TestJourney_RecordedReadingIsKept (0.01s)
--- PASS: TestJourney_WithdrawnReadingIsGone (0.01s)
== journeys: 5 ran, 5 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined
== suite: uv run ./tests/e2e/run-python-e2e-suite.sh journeys
tests/e2e/journeys/test_journey_alerts.py::test_journey_reading_over_the_limit_raises_an_alert PASSED
tests/e2e/journeys/test_journey_alerts.py::test_journey_one_authority_cannot_read_anothers PASSED
== python journeys: 6 ran, 6 passed first time, 0 flaky, 0 failed, 0 skipped, 1 quarantined
QUARANTINED tests/e2e/journeys/test_journey_alerts.py::test_journey_corrected_reading_is_alerted_again: left out here, proves nothing (issue https://github.com/example-org/air-quality/issues/512, deadline 2026-12-09)
== suite: ./tests/e2e/run-go-e2e-suite.sh smoke
== smoke: 2 ran, 2 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined
== suite: uv run ./tests/e2e/run-python-e2e-suite.sh smoke
== python smoke: 3 ran, 3 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined
== suite: uv run ./tests/e2e/run-python-e2e-suite.sh quarantine
tests/e2e/journeys/test_journey_alerts.py::test_journey_corrected_reading_is_alerted_again PASSED
== python quarantine: 1 ran, 1 passed first time, 0 flaky, 0 failed, 0 skipped, 1 quarantined
QUARANTINED tests/e2e/journeys/test_journey_alerts.py::test_journey_corrected_reading_is_alerted_again: pass (issue https://github.com/example-org/air-quality/issues/512, deadline 2026-12-09); not blocking, and not counted as passed
== deleting cluster e2e-pe2e-lab-10
== end-to-end run pe2e-lab-10 passed; cluster deleted
```

- **One cluster, one run.** The Go journeys and the Python journeys ran one after the other against the same four releases; each runner read the same run marker through the run's own kubeconfig and wrote its own files into the one results folder (`journeys-summary.json`, `python-journeys-summary.json`).
- **The quarantined test never counts as passed.** It is left out of the blocking selection, runs in the last suite line, and its result is printed as "not blocking". Until 2026-12-09 the report lists AC-US-7.4 as unproven; from the day after, the run is red until the test is restored or removed with a record (`test-pyramid` owns the rule).
- Run with the date moved past the deadline (`E2E_TODAY=2026-12-10`): the journeys selection exited 1 with `quarantine deadline 2026-12-09 has passed`.

## The release gate

The workflow that publishes calls `.github/workflows/e2e.yml` as a job and its publishing job declares `needs: e2e` (`../templates/workflows.md`). `release: types: [published]` is not used: it fires after publication, when nothing can be stopped. The suite tests the release candidate's own images: `E2E_BUILD` pulls them by digest and tags them, instead of building again.

## Smoke tests after each tenant's deployment

`cd-pipeline` runs, for each authority's environment in turn:

```bash
E2E_SMOKE_URL=https://<address of that authority's environment> E2E_SMOKE_TENANT=<tenant id> make e2e-smoke
```

In this product `e2e-smoke` calls both runners (`./tests/e2e/run-go-e2e-suite.sh smoke -- -tenant=<id>` and `uv run ./tests/e2e/run-python-e2e-suite.sh smoke`). Run for this skill against a server outside any cluster, with `E2E_SMOKE_TENANT=e2e-north`: the smoke tests of both runners passed and the server received `GET /readings` requests only, each with the tenant header and a `traceparent`. The smoke tests read as that tenant with a short-lived credential the pipeline supplies; they create nothing, and no journey ever follows them there. A copy of an authority's real data as test data is a question for the product owner (`test-fixture-design`).

## Report excerpt

| Test | Acceptance criteria | First attempt | Retry | Result |
|---|---|---|---|---|
| `test_journey_reading_over_the_limit_raises_an_alert` | AC-US-7.1, AC-US-7.2 | pass | not needed | passed |
| `test_journey_one_authority_cannot_read_anothers` | AC-US-9.1 | pass | not needed | passed |
| `TestJourney_RecordedReadingIsKept` (Go) | AC-US-6.1 | pass | not needed | passed |

| Quarantined | Issue | Deadline | Non-blocking run | Unproven meanwhile |
|---|---|---|---|---|
| `test_journey_corrected_reading_is_alerted_again` | #512 | 2026-12-09 | pass | AC-US-7.4 |

One report covers the run, with the rows of both runners, and goes to the product owner for approval.
