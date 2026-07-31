# Schema-Based Contract Tests — the pytest Harness

Reference for `python-contract-test`. This is the frugal, no-broker default: plain `pytest`
asserting that a FastAPI provider's **real** responses and a service's emitted Redpanda events
conform to the shared `openapi.yaml` and registered event JSON Schemas. Everything here runs in
one CI job with no new infrastructure. Async throughout — `pytest-asyncio` with
`asyncio_mode = "auto"`.

Dependencies (each justified against the frugality constraint, all open source):
`pytest`, `pytest-asyncio`, `httpx` (ASGI transport), `jsonschema` (Draft 2020-12), and
`referencing` — the library `jsonschema` now requires for `$ref` resolution, since
`jsonschema.RefResolver` was deprecated in v4.18. `PyYAML` loads the `openapi.yaml` document.

---

## conftest.py — async client + schema-loading fixtures

```python
# tests/contract/conftest.py
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, AsyncIterator

import pytest
import yaml
from httpx import ASGITransport, AsyncClient
from jsonschema import Draft202012Validator
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012

from app.main import app  # the real FastAPI application

CONTRACT_ROOT = Path(__file__).parent
OPENAPI_PATH = CONTRACT_ROOT.parent.parent / "openapi.yaml"
EVENT_SCHEMA_DIR = CONTRACT_ROOT.parent.parent / "schemas" / "events"


@pytest.fixture(scope="session")
def openapi_document() -> dict[str, Any]:
    """The single shared contract, loaded once per session."""
    return yaml.safe_load(OPENAPI_PATH.read_text())


@pytest.fixture(scope="session")
def schema_registry(openapi_document: dict[str, Any]) -> Registry:
    """Build a referencing Registry so jsonschema can resolve the document's
    internal #/components/schemas/* $refs. This replaces the deprecated
    RefResolver — the modern jsonschema API takes a Registry instead."""
    resource = Resource.from_contents(openapi_document, default_specification=DRAFT202012)
    return Registry().with_resource(uri="urn:openapi", resource=resource)


@pytest.fixture
async def provider() -> AsyncIterator[AsyncClient]:
    """Exercise the REAL FastAPI handlers (routing, dependencies, middleware,
    serializers) over ASGI transport — no live socket, no running server, but
    every layer of the real app runs. This is the point of a contract test:
    verify what the running provider actually emits, not a Pydantic example."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://provider") as client:
        yield client
```

`ASGITransport` is the load-bearing choice: it drives the real application object in-process, so
the response under assertion is produced by the same handler, dependency graph, and response model
serialization that runs in production — not a stub and not the OpenAPI `example` value.

---

## Resolving a response schema out of openapi.yaml

```python
# tests/contract/_resolve.py
from typing import Any


def response_schema(
    document: dict[str, Any], path: str, method: str, status: str = "200"
) -> dict[str, Any]:
    """Pull the JSON Schema for one operation's response body out of the
    OpenAPI document. Returns the schema node; its internal $refs are resolved
    at validation time by the referencing Registry, not here."""
    operation = document["paths"][path][method.lower()]
    content = operation["responses"][status]["content"]["application/json"]
    return content["schema"]
```

---

## test_provider_openapi.py — real responses ⊨ openapi.yaml

Cases live in a `parametrize` table — the Python realization of a Go table test. Each row is one
independently-reported case with its own `id`. Every row exercises a real endpoint and validates
its real response body against the resolved contract schema.

```python
# tests/contract/test_provider_openapi.py
import pytest
from jsonschema import Draft202012Validator

from ._resolve import response_schema

# (path, method, status, seed_fixture) — the endpoints under contract.
CONTRACT_CASES = [
    ("/data-assets/{asset_id}", "get", "200", "a_classified_data_asset"),
    ("/data-assets", "get", "200", "two_data_assets"),
    ("/data-assets", "post", "201", None),
]


@pytest.mark.parametrize(
    "path,method,status,seed",
    CONTRACT_CASES,
    ids=[f"{m.upper()} {p} -> {s}" for p, m, s, _ in CONTRACT_CASES],
)
async def test_response_conforms_to_contract(
    provider, openapi_document, schema_registry, request, path, method, status, seed
):
    if seed:
        request.getfixturevalue(seed)  # seed state for this specific case

    url = path.format(asset_id="11111111-1111-1111-1111-111111111111")
    if method == "get":
        resp = await provider.get(url)
    else:
        resp = await provider.post(
            "/data-assets",
            json={"name": "quarterly-report.xlsx", "source": "google-drive"},
        )

    assert resp.status_code == int(status)
    schema = response_schema(openapi_document, path, method, status)
    validator = Draft202012Validator(schema, registry=schema_registry)
    errors = sorted(validator.iter_errors(resp.json()), key=str)
    assert not errors, "\n".join(e.message for e in errors)
```

Note `iter_errors` (not `validate`): it collects **every** conformance failure at once, so a broken
response reports all its drifts in one run instead of failing on the first field.

---

## Consumer side — declare ONLY what you read

A consumer must not pin the full response shape; it declares the narrow subset of fields it actually
reads. This is what makes the test *consumer-driven*: the provider stays free to add fields the
consumer ignores, and the consumer's test breaks only when a field it truly depends on drifts.

```python
# tests/contract/test_consumer_classification_worker.py
import pytest

# The classification-worker consumer reads exactly these fields off a DataAsset.
CONSUMER_FIELDS = [
    ("id", str),
    ("sensitivity", str),      # consumer branches on this enum
    ("tenant_id", str),        # per-tenant physical isolation routing
    ("source", str),
]


@pytest.mark.parametrize(
    "field,expected_type",
    CONSUMER_FIELDS,
    ids=[f for f, _ in CONSUMER_FIELDS],
)
async def test_consumer_required_fields_present(provider, a_classified_data_asset, field, expected_type):
    resp = await provider.get("/data-assets/11111111-1111-1111-1111-111111111111")
    body = resp.json()
    assert field in body, f"consumer depends on '{field}' — provider dropped it"
    assert isinstance(body[field], expected_type), (
        f"consumer expects '{field}' as {expected_type.__name__}, "
        f"got {type(body[field]).__name__}"
    )
```

A dropped or retyped field the worker reads fails this consumer's own CI — the exact build-time
signal wanted. A field the worker never lists can change freely.

---

## Worked DataAsset event contract — Redpanda topic boundary

A Redpanda (Kafka-API) topic is a boundary exactly like HTTP. The service publishes
`DataAssetClassified` events via `aiokafka`; downstream consumers deserialize them. The contract is
the registered JSON Schema, and the test proves the **event-builder function** produces a payload
that conforms — without publishing to a real broker (that is `python-integration-test`'s job).

`schemas/events/data_asset_classified.v1.json` (the registered contract):

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:events:data_asset_classified:v1",
  "type": "object",
  "required": ["event_id", "occurred_at", "tenant_id", "asset_id", "sensitivity"],
  "additionalProperties": false,
  "properties": {
    "event_id": {"type": "string", "format": "uuid"},
    "occurred_at": {"type": "string", "format": "date-time"},
    "tenant_id": {"type": "string"},
    "asset_id": {"type": "string", "format": "uuid"},
    "sensitivity": {"type": "string", "enum": ["public", "internal", "confidential", "restricted"]}
  }
}
```

```python
# tests/contract/test_event_schema.py
import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

from app.events.builders import build_data_asset_classified
from app.domain.data_asset import DataAsset, Sensitivity

SCHEMA_DIR = Path(__file__).parent.parent.parent / "schemas" / "events"


def load_schema(name: str) -> dict:
    return json.loads((SCHEMA_DIR / name).read_text())


async def test_emitted_event_conforms_to_registered_schema():
    asset = DataAsset(
        id="22222222-2222-2222-2222-222222222222",
        tenant_id="acme",
        name="payroll.xlsx",
        source="s3",
        sensitivity=Sensitivity.RESTRICTED,
    )
    # The real builder the aiokafka producer path calls — not a hand-rolled dict.
    payload = json.loads(build_data_asset_classified(asset).value.decode())

    schema = load_schema("data_asset_classified.v1.json")
    errors = sorted(Draft202012Validator(schema).iter_errors(payload), key=str)
    assert not errors, "\n".join(e.message for e in errors)
```

---

## Backward-compatibility check — the schema-evolution guard

`event-schema-design` mandates `BACKWARD` compatibility: a new schema version must not break
consumers still reading the previous one. The rule, asserted mechanically: **a new version may only
add OPTIONAL fields — a newly added property must NOT appear in the `required` array, and no existing
required field may be removed or retyped.** This test compares the committed v1 schema against the
proposed v2 schema at build time.

```python
# tests/contract/test_event_backward_compat.py
import json
from pathlib import Path

SCHEMA_DIR = Path(__file__).parent.parent.parent / "schemas" / "events"


def load(name: str) -> dict:
    return json.loads((SCHEMA_DIR / name).read_text())


def assert_backward_compatible(old: dict, new: dict) -> None:
    old_required = set(old.get("required", []))
    new_required = set(new.get("required", []))
    old_props = old.get("properties", {})
    new_props = new.get("properties", {})

    # 1. No previously-required field may be dropped.
    dropped = old_required - new_required
    assert not dropped, f"BACKWARD break: required field(s) removed: {sorted(dropped)}"

    # 2. A field added in the new version must be OPTIONAL for old producers.
    added_required = (new_required - old_required) & (set(new_props) - set(old_props))
    assert not added_required, (
        f"BACKWARD break: new field(s) marked required: {sorted(added_required)} "
        "— old producers won't emit them"
    )

    # 3. No retained field may change type.
    for field in old_props.keys() & new_props.keys():
        assert old_props[field].get("type") == new_props[field].get("type"), (
            f"BACKWARD break: field '{field}' changed type"
        )


def test_v2_is_backward_compatible_with_v1():
    assert_backward_compatible(
        load("data_asset_classified.v1.json"),
        load("data_asset_classified.v2.json"),
    )
```

This closes the honest gap named in the SKILL body: `jsonschema` conformance proves the *current*
payload is structurally valid; `assert_backward_compatible` proves an *evolution* of the schema does
not silently break a consumer still on the prior version. Neither, however, is exact-interaction CDC
— a type-preserving, meaning-changing edit (an enum widened to free text) passes all three checks and
still breaks a consumer. That gap is what a `pact-python` escalation would close, per the SKILL body's
decision rule; see `provider-consumer-ci.md` for when that escalation is warranted.

---

## pyproject.toml wiring

```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"          # async def tests run without a per-test marker
testpaths = ["tests"]
markers = ["contract: wire-level agreement between independently-deployed services"]
```

Run the contract layer alone in CI with `pytest -m contract tests/contract/`.
```
