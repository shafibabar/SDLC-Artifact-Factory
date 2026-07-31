# E2E Setup and Flow — Bringing Up the System and Driving a Full DataAsset Journey

A complete, self-contained walk-through of the API-level Python e2e surface:
provisioning the running system, the `pytest` fixtures that connect to it, a
worked `ingest → classify → compliance` journey with real HTTP and real
emitted-event assertions, the condition-based poll helper that replaces every
`asyncio.sleep`, and the trace-correlation helper that ties a failing journey to
one connected OpenTelemetry trace.

---

## The Two Surfaces of One Journey

| Surface | Tool | Use for |
|---|---|---|
| **UI e2e** | Playwright, TypeScript (`react-e2e-testing`) | Genuinely user-facing browser journeys — navigation, rendering, accessibility of the flow |
| **API e2e** | `pytest` + `httpx.AsyncClient` against the deployed FastAPI ingress (this file) | Backend-centric journeys — faster, no browser, less flaky |

The same Gherkin journey scenario (`bdd-feature-file`) can bind to either
surface. This file owns the API surface only; the browser surface stays in
TypeScript regardless of the Python backend (see `SKILL.md`'s honest-divergence
note). `playwright-python` is a real, first-class port, but the frontend being
React + TypeScript by default means there is no reason to re-author the browser
suite in Python — Python changes only *what backend* the API journey exercises.

---

## Bringing Up the System — `provision-kind.sh`

The full journey suite runs against an ephemeral `kind` cluster installed from
the **same Helm charts at the same digest** production runs, differing only in a
CI values file. Never docker-compose for the CI suite (`SKILL.md`'s Running-System
Standard). Teardown is guaranteed by a `trap` so a mid-run failure never orphans
the cluster:

```bash
#!/usr/bin/env bash
# tests/e2e/provision-kind.sh — create the cluster, install every service a
# journey touches, print the ingress base URL. Idempotent teardown on any exit.
set -euo pipefail

RUN_ID="${GITHUB_RUN_ID:-local-$(date +%s)}"
CLUSTER="e2e-${RUN_ID}"

teardown() { kind delete cluster --name "${CLUSTER}" >/dev/null 2>&1 || true; }
trap teardown EXIT   # in-runner backstop; CI adds an `if: always()` step + a janitor

kind create cluster --name "${CLUSTER}" --wait 120s

# Same charts, same digest, only the values file differs — Environment Parity.
for svc in dataasset-ingest dataasset-classify compliance-report; do
  helm install "${svc}" "charts/${svc}" \
    --namespace app --create-namespace \
    --values "charts/${svc}/values-e2e.yaml" \
    --set tenant.id="e2e-${RUN_ID}" \
    --wait --timeout 180s          # block until Pods are Ready — a readiness gate, not a sleep
done

kubectl -n app port-forward svc/ingress 8080:80 >/dev/null 2>&1 &
echo "E2E_BASE_URL=http://127.0.0.1:8080"
echo "E2E_KAFKA_BOOTSTRAP=127.0.0.1:9092"
echo "E2E_RUN_ID=${RUN_ID}"
```

`--wait --timeout` is the readiness gate: `helm install --wait` returns only once
every Pod reports Ready, so the test suite never races an unfinished rollout —
the deploy-time analog of the condition-based waits the tests themselves use.

---

## The Fixtures — `tests/e2e/conftest.py`

Session-scoped fixtures expose the running system to every journey test: the
deployed base URL, a network-only `httpx.AsyncClient`, and an `aiokafka` consumer
already subscribed to the real topic so emitted events can be asserted.

```python
# tests/e2e/conftest.py
import os
import pytest
import pytest_asyncio
import httpx
from aiokafka import AIOKafkaConsumer


@pytest.fixture(scope="session")
def base_url() -> str:
    # Set by provision-kind.sh (exported into the CI job env). No default to a
    # localhost app process: an unset URL must fail loudly, never silently point
    # e2e at something that is not the deployed system.
    url = os.environ.get("E2E_BASE_URL")
    assert url, "E2E_BASE_URL not set — provision the kind cluster first"
    return url


@pytest.fixture(scope="session")
def run_id() -> str:
    return os.environ["E2E_RUN_ID"]           # the per-run tenant discriminator


@pytest_asyncio.fixture
async def client(base_url: str):
    # A real network client against the deployed ingress — NOT httpx's ASGITransport
    # (that would import the app in-process and make this an integration test).
    async with httpx.AsyncClient(base_url=base_url, timeout=10.0) as c:
        yield c


@pytest_asyncio.fixture
async def classified_events(run_id: str):
    consumer = AIOKafkaConsumer(
        "dataasset.classified",
        bootstrap_servers=os.environ["E2E_KAFKA_BOOTSTRAP"],
        group_id=f"e2e-{run_id}",             # unique group so each run reads from its own offset
        auto_offset_reset="latest",
        enable_auto_commit=False,
    )
    await consumer.start()
    try:
        yield consumer
    finally:
        await consumer.stop()                 # teardown runs on failure AND success
```

The `client` fixture is a genuine network client — using `httpx`'s in-process
`ASGITransport` here would import the FastAPI app into the test and cross no
network hop, collapsing the e2e test into an integration test (`SKILL.md`'s Scope
Boundary).

---

## The Condition-Based Poll Helper — Never `asyncio.sleep`

An arbitrary `await asyncio.sleep(3)` is the cardinal e2e sin: too short and it
flakes, too long and the suite crawls. Wait for a *condition* with a deadline:

```python
# tests/e2e/waiting.py
import asyncio
import time
from typing import Awaitable, Callable, TypeVar

T = TypeVar("T")


async def eventually(
    probe: Callable[[], Awaitable[T | None]],
    *,
    timeout: float = 15.0,
    interval: float = 0.25,
    what: str = "condition",
) -> T:
    """Poll `probe` until it returns a non-None value or the deadline passes.
    Returns the value; raises AssertionError with a diagnostic on timeout."""
    deadline = time.monotonic() + timeout
    last: T | None = None
    while time.monotonic() < deadline:
        last = await probe()
        if last is not None:
            return last
        await asyncio.sleep(interval)         # a poll interval, not a guess at completion time
    raise AssertionError(f"{what} not satisfied within {timeout:.1f}s (last={last!r})")
```

The `asyncio.sleep(interval)` *inside* the loop is a bounded poll interval, not
the anti-pattern — the anti-pattern is a sleep used *as* the synchronization
mechanism, with no condition checked and no deadline stated.

---

## A Complete API-Level Journey Test

One critical DataAsset journey, driven entirely over HTTP, asserting both the
HTTP end-state (the compliance gap report reflects the classification) and the
real emitted event on Redpanda. Marked `smoke` so it is part of the per-promotion
subset (`flake-and-scope.md`).

```python
# tests/e2e/test_dataasset_journey.py
import json
import pytest
from .waiting import eventually


@pytest.mark.e2e
@pytest.mark.smoke
@pytest.mark.asyncio
async def test_ingest_classify_then_appears_in_compliance_report(
    client, classified_events, run_id
):
    tenant = f"e2e-{run_id}"
    headers = {"X-Tenant-ID": tenant}

    # 1. Authenticate against the deployed auth surface (real middleware chain).
    r = await client.post("/auth/token", json={"steward": "e2e", "tenant": tenant})
    assert r.status_code == 200, r.text
    headers["Authorization"] = f"Bearer {r.json()['access_token']}"

    # 2. INGEST — connect a source; the asset flows through the real pipeline.
    r = await client.post(
        "/sources", headers=headers,
        json={"kind": "s3", "bucket": f"{tenant}-audit", "prefix": "finance/"},
    )
    assert r.status_code == 201, r.text
    source_id = r.json()["id"]

    async def _asset():
        resp = await client.get(f"/sources/{source_id}/assets", headers=headers)
        assets = resp.json().get("items", [])
        return assets[0]["id"] if assets else None

    asset_id = await eventually(_asset, timeout=20.0, what="asset discovered from source")

    # 3. CLASSIFY — a real HTTP command against the classify service.
    r = await client.put(
        f"/assets/{asset_id}/classification", headers=headers,
        json={"sensitivity": "Restricted"},
    )
    assert r.status_code == 202, r.text

    # 3b. EMITTED-EVENT assertion — the DataAssetClassified event actually landed
    #     on the real Redpanda topic with the tenant-scoped payload.
    async def _event():
        batch = await classified_events.getmany(timeout_ms=500)
        for _tp, msgs in batch.items():
            for m in msgs:
                ev = json.loads(m.value)
                if ev.get("asset_id") == asset_id and ev.get("tenant_id") == tenant:
                    return ev
        return None

    event = await eventually(_event, timeout=15.0, what="DataAssetClassified emitted")
    assert event["sensitivity"] == "Restricted"

    # 4. COMPLIANCE — eventually-consistent projection; poll, never sleep.
    async def _report():
        resp = await client.get("/compliance/gap-report", headers=headers)
        restricted = resp.json().get("restricted_assets", [])
        return True if asset_id in restricted else None

    await eventually(_report, timeout=20.0, what="gap report reflects the restricted asset")
```

Every line above is an `httpx` call over the network to a service running as a
real Pod, plus a real `aiokafka` read from the real broker — nothing imports
another service's module, which is precisely what makes it e2e rather than an
elaborate integration test (`SKILL.md`'s Scope Boundary). The HTTP assertions and
the emitted-event assertion together prove the *whole* pipeline: the write
succeeded, the event published, and the downstream projection consumed it.

---

## Test-Trace Correlation

Every request a journey makes carries a stable per-run trace id propagated as a
W3C `traceparent` header, so a failing journey's activity across every service it
touched is one connected OpenTelemetry trace (`distributed-tracing-design`) rather
than a scattered set of per-service logs correlated by timestamp by hand:

```python
# tests/e2e/tracing.py
import os
from opentelemetry import trace
from opentelemetry.propagate import inject


def trace_headers(test_name: str) -> dict[str, str]:
    """Start a span named for the test and return the W3C headers that
    propagate its trace id to every service the journey calls."""
    tracer = trace.get_tracer("python-e2e-test")
    with tracer.start_as_current_span(f"{test_name}::{os.environ['E2E_RUN_ID']}"):
        carrier: dict[str, str] = {}
        inject(carrier)                       # writes `traceparent` into carrier
        return carrier
```

Merge `trace_headers(...)` into the `headers` dict at the top of the journey so
every `httpx` call injects `traceparent`. When a journey fails, its trace id —
logged alongside the failure, the same id `flake-and-scope.md`'s detection record
captures — leads straight to the exact span that broke, across every service the
journey crossed, without re-running under a debugger.

---

## Marker Registration — `pyproject.toml`

```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
markers = [
    "e2e: end-to-end journey against the deployed system (kind cluster)",
    "smoke: the non-destructive per-promotion subset (run with -m smoke)",
    "quarantine: intermittently-flaky e2e under a tracked issue (non-blocking)",
]
```

Registering the markers keeps `--strict-markers` meaningful (an unknown marker
becomes an error, not a silent typo) and lets the CI job carve subsets with
`-m e2e`, `-m smoke`, or `-m "e2e and not quarantine"` — the mechanics detailed in
`flake-and-scope.md`.
