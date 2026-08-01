---
name: python-contract-test
description: >
  Teaches the backend-engineer to write Python consumer-driven contract tests —
  the frugal schema-based default (OpenAPI + event-schema compatibility asserted
  in plain pytest, NO Pact broker, mirroring go-contract-test), parametrized
  schema-conformance cases, and provider/consumer compatibility checks in CI.
  The Python analog of go-contract-test.
version: 1.0.0
phase: quality
owner: backend-engineer
created: 2026-07-31
tags: [quality, python, contract-test, consumer-driven, openapi, event-schema, pytest, schema-conformance, no-broker]
produces: python-contract-test
domain: testing
status: stable
related: [go-contract-test, python-openapi-codegen, event-schema-design, api-contract-design]
tools: [Bash]
---

# Python Contract Test

## Purpose

When two independently-deployable services talk, each assumes something about the other's
shape — a silent change on one side breaks the other in production. A contract test catches
that break at **build time**, on each side's own CI, without either side's real implementation
running end-to-end against the other. This is the Python realization of the **Consumer-Driven
Contract** discipline `go-contract-test` owns for Go, applied to a FastAPI + asyncpg + aiokafka
service against a Redpanda (Kafka-API) event backbone. The default is frugal and schema-based:
plain `pytest` asserting real responses and emitted events conform to the shared `openapi.yaml`
and registered event schemas — **no Pact broker, no new infrastructure**, exactly as
`go-contract-test`'s frugal tier prescribes.

---

## The Boundary: Contract Test vs. Integration Test vs. Schema Test

- **Integration test (`python-integration-test`)** — verifies *this service's own code* against a
  real dependency *it owns*: the real Postgres it writes to (asyncpg + testcontainers), the real
  Redpanda topic it publishes on. Failure means our code is wrong.
- **Contract test (this skill)** — verifies the *wire-level agreement* between two independently
  deployed services: this service as consumer of another team's API, or as provider to another
  team's consumer. Neither side's real implementation runs end-to-end in the same test. Failure
  means the contract drifted, not that either side's internal logic is wrong.
- **Schema test vs. true CDC test** — within contract testing, a schema check proves *structural*
  shape: required fields, correct types, valid enums. It does **not** prove that the specific value
  combinations a consumer depends on stay compatible across a change that preserves type but changes
  meaning (an enum silently widened to free text is schema-valid and contract-broken). Naming that
  limit honestly is mandatory; Pact's exact-interaction replay is what would close it — see below.

---

## Two Tiers: Schema-Based Default vs. Pact Escalation

| | Stay schema-based (this skill's default) | Escalate to Pact (`pact-python`) |
|---|---|---|
| Trigger | Single repo, one shared `openapi.yaml`/event schema both sides generate from | Boundary crosses a team or repository line — independent deploys, no shared codegen source |
| Consumer check | Declares the fields/endpoints it reads; provider verified structurally | Exact recorded interactions replayed against the real provider |
| Deploy gate | File-pinning: verify provider against HEAD **and** each consumer's pinned deployed expectations | Pact Broker `can-i-deploy` against real historical verification results |
| Cost | One CI job, no new infrastructure | A self-hosted Pact Broker (Postgres-backed), Provider State fixture wiring |

**Decision rule:** stay schema-based until there is a genuine multi-party, multi-repo integration
that needs brokered contract negotiation between parties who don't share a codebase — then adopt
`pact-python` for that specific boundary and record it as an ADR. Don't stand up the Broker before
the problem exists. This mirrors `go-contract-test`'s rule exactly; the divergence is only the
library name (`pact-python`, not `pact-go`).

---

## What a Contract Covers

Two boundary kinds, both asserted in plain `pytest`:

1. **OpenAPI response shapes (HTTP).** The contract already exists and is already shared:
   `openapi.yaml` (`api-contract-design`). FastAPI derives its schema *from* the running app
   (`python-openapi-codegen`); consumers generate clients from the same document. The contract test
   verifies the two things codegen alone can't: the running provider's **real** responses conform
   (not just its stubs), and each consumer's declared subset stays honoured. `jsonschema` validates
   a real response body against the resolved response schema pulled from `openapi.yaml`.
2. **Event schemas (Redpanda topics).** A Redpanda topic is a boundary exactly like HTTP. Emitted
   Domain Events (`DataAssetClassified`, `DataAssetDiscovered`) are validated against their
   registered JSON Schema, and every schema change is checked for `BACKWARD` compatibility against
   the previously-deployed version (`event-schema-design`). An unverified event shape change is a
   production break waiting for a redeploy.

Full pytest harness — parametrized schema-conformance cases, the async response fixture, the
event-payload builder assertion, and the worked `DataAsset` event contract:
`references/schema-contract-tests.md`.

---

## Consumer-Driven: Who Drives the Contract

"Consumer-driven" means the **consumer's** needs define what the provider must honour — not the
provider dictating shapes. The provider may freely change anything no consumer depends on; changing
something a consumer needs fails that consumer's contract test, exactly the signal wanted at build
time. A provider asserting its own output shape verifies nothing. A consumer that pins the full
response shape breaks on additive changes it never used — so consumer tests declare **only the
fields they read**, expressed as a `parametrize` table of `(field_path, expected_type)` rows or a
narrowed sub-schema.

---

## Why pytest, and the Honest Python-vs-Go Divergences

- **Async is load-bearing.** The stack is async end to end, so provider-response fixtures and
  event-builder calls are exercised under `pytest-asyncio` (`asyncio_mode = "auto"`) with
  `httpx.AsyncClient` against the FastAPI app via ASGI transport — no live socket needed. Go's
  contract tests are synchronous; here the fixture is an `async def … yield` async generator.
- **Parametrize replaces Go table tests.** Where `go-contract-test` writes a `[]struct{…}` slice
  and a `for` loop, Python uses `@pytest.mark.parametrize` — each schema-conformance case is one row
  reported as its own pass/fail with its own `id`. Same Specification-by-Example intent, different
  mechanics.
- **Validation library differs.** Go uses `kin-openapi`; Python uses `jsonschema` (Draft 2020-12)
  plus `openapi-core` or a manual `$ref` resolve against the `openapi.yaml` document. Both validate
  real responses structurally; neither gives exact-interaction CDC on its own.
- **No shared broker either way — but the reason is identical.** Frugality (`CLAUDE.md`): the
  file-pinning deploy gate needs no running service. This is not a Python limitation; it is the same
  deliberate choice `go-contract-test` makes.

Provider and consumer sides running the same contract, breaking-change detection in CI, and the
full no-broker rationale: `references/provider-consumer-ci.md`.

---

## CI Placement

Contract tests run in **each side's own** pipeline, in the `quality` phase, after unit and
integration tests, before deploy. The provider job validates real handler responses and emitted
events against the shared schemas; each consumer job validates its declared subset. A break fails
CI on that side independently — the counterpart is never checked out. The deploy gate is file-based:
verify the provider against HEAD **and** against each consumer's pinned deployed-version
expectations, so an independent-deploy skew is caught, not just a HEAD-to-HEAD match. Exact CI wiring
and the breaking-change matrix: `references/provider-consumer-ci.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Correct tier chosen | Schema-based for shared-repo boundaries; Pact only for a real multi-party need, recorded as an ADR | Broker stood up with no multi-party problem, or a cross-team boundary left on schema-only |
| Real responses verified | Provider test exercises real FastAPI handlers via `httpx.AsyncClient` ASGI transport | Only generated stubs / Pydantic examples checked |
| Consumer-driven | Consumer declares only what it reads (parametrized field subset) | Provider dictates shapes; consumer pins the full response |
| Schema-vs-exact understood | Structural-only limit stated explicitly where relied on | "Contract test" used to imply exact-interaction guarantees the schema tier lacks |
| Event compatibility | Emitted events schema-validated + `BACKWARD`-compat checked against deployed version | Event shape change unverified |
| Async correctly gated | `asyncio_mode = "auto"`; async fixtures are `async def … yield` generators | Sync-only test misses the real async response path |
| Deploy gated | File-pinning (HEAD + deployed) blocks deploy on failure | Deploy proceeds regardless of contract result |
| Frugal | Plain pytest + jsonschema, no broker; `pact-python` flagged as an ADR escalation only | Broker/PactFlow adopted without an explicit frugality check |
| Build-time catch | Breaks fail CI before deploy, on each side independently | Breaks discovered in production |

---

## Anti-Patterns

- **Testing Pydantic examples instead of the running provider** — codegen conformance is free; the
  contract test must exercise real handlers and middleware via `httpx.AsyncClient`, where drift
  happens.
- **Provider-driven "contracts"** — a provider asserting its own output shape verifies nothing a
  consumer relies on.
- **Consumers asserting the full response shape** — breaks on additive changes it never read;
  declare only the fields consumed.
- **Skipping event contracts** — Redpanda topics are boundaries exactly like HTTP; an unverified
  Domain Event schema change is a production break waiting for a redeploy.
- **Treating schema validation as exact-interaction CDC** — a type-preserving, meaning-changing edit
  passes `jsonschema` and breaks a consumer; know which guarantee is in force.
- **Verifying only HEAD-to-HEAD** — independent deploys mean the deployed version is the one that
  breaks; pin and verify deployed expectations.
- **Sync-only tests on an async stack** — a synchronous test client can miss the real async response
  path; use `pytest-asyncio` and ASGI transport.
- **Standing up a Pact Broker pre-emptively** — infrastructure without a multi-party problem; adopt
  per-boundary, with an ADR, when the problem is real.

---

## Output Format

```
tests/contract/test_provider_openapi.py     (provider real responses ⊨ openapi.yaml)
tests/contract/test_consumer_<name>.py       (per-consumer declared-subset expectations)
tests/contract/test_event_schema.py          (emitted events ⊨ schema + BACKWARD compat)
tests/contract/conftest.py                   (async provider client + schema-loading fixtures)
tests/contract/pinned/<consumer>@<sha>.json  (file-pinned deployed-version expectations)
```

Every file follows `references/schema-contract-tests.md`'s harness shape and
`references/provider-consumer-ci.md`'s CI/pinning rules — not an ad hoc variant per boundary.
