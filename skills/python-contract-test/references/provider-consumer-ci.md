# Provider & Consumer Sides in CI — File-Pinning, Breaking-Change Detection, and the No-Broker Rationale

Reference for `python-contract-test`. Covers how the same shared contract is exercised on both the
provider and the consumer side, how a breaking change is caught before deploy, and why the frugal
default deliberately runs **without** a Pact Broker — the identical choice `go-contract-test` makes,
realized in Python.

---

## The two sides run the SAME contract, in their OWN pipeline

Both sides generate from and validate against one shared artifact: `openapi.yaml` for HTTP, the
registered event JSON Schemas for Redpanda topics. Neither pipeline ever checks out the other's
code — that is what makes these *contract* tests rather than integration tests.

| Side | What its job asserts | Fails when |
|---|---|---|
| **Provider** (`test_provider_openapi.py`, `test_event_schema.py`) | Real FastAPI handler responses (via `httpx.AsyncClient` ASGI transport) and real event-builder payloads conform to the shared schemas | The running provider drifts from the contract it publishes |
| **Consumer** (`test_consumer_<name>.py`) | The narrow subset of fields this consumer actually reads is present and correctly typed | The provider drops or retypes a field this consumer depends on |

The provider job proves "I still emit what I promised." Each consumer job proves "the field I read is
still there." Together they cover both directions of drift, each catchable on the side that owns the
fix, at build time.

---

## File-pinning: verifying against the DEPLOYED version, not just HEAD

The subtle failure mode: the provider's HEAD may satisfy every consumer's HEAD expectation, yet a
consumer currently **deployed in production** pins an older expectation the provider is about to
break. Verifying only HEAD-to-HEAD misses it, because independent deploys mean the deployed version
is the one that actually breaks.

The frugal answer is file-pinning. Each consumer commits its declared-subset expectation, tagged with
the git SHA it was last deployed at, into the provider's repo:

```
tests/contract/pinned/
  classification-worker@a1b2c3d.json     # deployed to prod at SHA a1b2c3d
  audit-exporter@9f8e7d6.json            # deployed to prod at SHA 9f8e7d6
```

Each pinned file is the exact `(field_path, expected_type)` subset that consumer version reads:

```json
{
  "consumer": "classification-worker",
  "deployed_sha": "a1b2c3d",
  "endpoint": "GET /data-assets/{asset_id}",
  "required_fields": {
    "id": "string",
    "sensitivity": "string",
    "tenant_id": "string",
    "source": "string"
  }
}
```

The provider's CI verifies its real responses against **both** HEAD consumer tests **and** every
pinned deployed-version file:

```python
# tests/contract/test_provider_against_pinned.py
import json
from pathlib import Path

import pytest

PINNED_DIR = Path(__file__).parent / "pinned"
_JSON_TO_PY = {"string": str, "integer": int, "number": float, "boolean": bool, "object": dict, "array": list}

pinned_files = sorted(PINNED_DIR.glob("*.json"))


@pytest.mark.parametrize("pinned_path", pinned_files, ids=[p.stem for p in pinned_files])
async def test_provider_honours_deployed_consumer_expectations(provider, a_classified_data_asset, pinned_path):
    pin = json.loads(pinned_path.read_text())
    resp = await provider.get("/data-assets/11111111-1111-1111-1111-111111111111")
    body = resp.json()
    for field, json_type in pin["required_fields"].items():
        assert field in body, (
            f"deployed consumer {pin['consumer']}@{pin['deployed_sha']} reads '{field}' "
            f"— HEAD provider dropped it; this would break production on deploy"
        )
        assert isinstance(body[field], _JSON_TO_PY[json_type]), (
            f"{pin['consumer']}@{pin['deployed_sha']} expects '{field}' as {json_type}"
        )
```

When a consumer deploys a new version, its CI updates its pinned file (new SHA, new subset) in the
provider repo via PR. The pinned directory is thus a committed, reviewable stand-in for a Pact
Broker's compatibility matrix — the same idea (verify against what is actually deployed, not just
HEAD) implemented as files instead of a running service.

---

## Breaking-change detection in CI

The deploy gate is a plain test-suite exit code — no external query. A break shows up as a red
`pytest` run on the side that must fix it:

```yaml
# .github/workflows/contract.yml (provider side)
name: contract
on: [pull_request, push]
jobs:
  provider-contract:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pipx install uv
      - run: uv sync --frozen
      # Real handler responses + real event payloads vs. the shared schemas,
      # AND every deployed consumer's pinned expectation. Non-zero exit == break.
      - run: uv run pytest -m contract tests/contract/ --tb=short
```

```yaml
# .github/workflows/contract.yml (consumer side, its own repo/pipeline)
jobs:
  consumer-contract:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pipx install uv
      - run: uv sync --frozen
      # Validates the declared-subset fields this consumer reads against the
      # provider contract vendored/fetched into this repo. Non-zero == break.
      - run: uv run pytest -m contract tests/contract/ --tb=short
```

The breaking-change matrix the two jobs jointly enforce:

| Change on provider | Provider HEAD test | Pinned-deployed test | Consumer HEAD test | Verdict |
|---|---|---|---|---|
| Add a field no consumer reads | pass | pass | pass | safe — provider free to add |
| Drop a field a HEAD consumer reads | pass | pass | **FAIL** | caught on consumer CI |
| Drop a field a DEPLOYED consumer reads | pass | **FAIL** | pass | caught on provider CI before deploy |
| Retype a field a consumer reads | pass | **FAIL** / **FAIL** | **FAIL** | caught both sides |
| Widen an enum to free text (same type) | pass | pass | pass | **NOT caught** — schema tier's honest limit |

That last row is the schema tier's structural-only boundary, stated plainly: a type-preserving,
meaning-changing edit is schema-valid and contract-broken. Only exact-interaction CDC catches it.

---

## The no-broker rationale (frugal by design)

A Pact Broker is a running, Postgres-backed service that stores pact files and answers
`can-i-deploy` against a real historical verification matrix. It is genuinely valuable — and
genuinely unnecessary at this repo's scale. The reasons for staying broker-free, identical to
`go-contract-test`'s:

1. **Single repo, one shared contract.** Provider and consumers generate from the same
   `openapi.yaml` and event schemas in one repository. There is no cross-team, cross-repo
   coordination problem for a Broker to solve — the shared file *is* the coordination.
2. **The file-pinning directory is the compatibility matrix.** Committed `pinned/*.json` files, PR
   reviewed, give the same "verify against the deployed version" guarantee as a Broker's matrix,
   with zero running infrastructure and full git history.
3. **Frugality (`CLAUDE.md`).** "Open-source over paid tooling… prefer simpler solutions over
   sophisticated ones when outcomes are equivalent." A self-hosted Broker is open source but is still
   a service to deploy, back up, and monitor for a problem that does not yet exist. **PactFlow**, the
   hosted commercial alternative, must be flagged against the frugality constraint and explicitly
   approved before ever being considered — it is a paid SaaS.

## When to escalate to `pact-python` + a Broker

Adopt the heavier tier **only** when a boundary genuinely crosses a team or repository line —
independent deploy schedules, no shared codegen source, a consumer team that cannot review a pinned
file in the provider's repo. At that point:

- Write the consumer test as an **exact-interaction** `pact-python` test (a specific request → a
  specific expected response, run against the Pact-generated local mock), not a schema assertion —
  the two are mechanically different tests.
- Set up **Provider States**: named precondition strings (`"a classified data asset exists"`) mapped
  to fixture-setup code on the provider side before each recorded interaction is replayed.
- Adopt **Pending/WIP Pacts** so a newly published consumer expectation does not instantly red the
  provider's build before that team can react.
- Replace file-pinning with `pact-broker can-i-deploy` against a **self-hosted, open-source** Broker.
- **Record the escalation as an ADR** naming the specific multi-party boundary that justified it.

Do not stand up any of this pre-emptively. Each item is dormant capability for a future multi-party
engagement, not a retrofit the current single-repo product needs — exactly the posture
`go-contract-test` holds for Go.

---

## Honest Python-vs-Go divergences in the CI shape

- **Test runner + packaging.** Go runs `go test ./...`; Python runs `uv run pytest -m contract` with
  `uv sync --frozen` for reproducible installs. `uv` is the frugal, fast dependency manager the
  python-* skills default to.
- **Async gating.** The provider fixture is an `async def … yield` async generator under
  `pytest-asyncio` (`asyncio_mode = "auto"`), because the FastAPI + asyncpg + aiokafka stack is async
  end to end. Go's contract tests are synchronous — no event-loop gating exists or is needed there.
- **Parametrize vs. table tests.** The pinned-file and consumer-field suites use
  `@pytest.mark.parametrize` (one reported case per row) where Go would use a `[]struct{…}` slice and
  a `for` range loop. Same Specification-by-Example intent; Python reports each row as a named case.
- **Validation library.** Go's `kin-openapi` vs. Python's `jsonschema` + `referencing` Registry. Both
  validate real responses structurally; the no-broker, file-pinning deploy gate is identical.
```
