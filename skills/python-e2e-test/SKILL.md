---
name: python-e2e-test
description: >
  Teaches the backend-engineer to write Python end-to-end tests — pytest
  driving a fully running system (docker-compose or kind), the smallest
  critical-path set (e2e is the top of the pyramid, kept few), real HTTP +
  emitted-event assertions across services, flake control (ret/timeout/data
  setup), and the e2e-vs-integration boundary. The Python analog of go-e2e-test.
version: 1.0.0
phase: quality
owner: backend-engineer
created: 2026-07-31
tags: [quality, python, e2e, end-to-end, kind, httpx, aiokafka, flakiness, quarantine, ci, pytest]
related: [go-e2e-test, python-integration-test, python-fastapi-handler, uat-scenario]
tools: [Bash]
---

# Python End-to-End Test

## Purpose

E2E tests prove the fully-deployed system delivers a user journey — real Pods,
real Services, real network calls — not `pytest` importing another service's
package. This is the top of the pyramid above `python-integration-test`: highest
confidence, highest cost, most prone to flakiness, reserved for critical
journeys only. The discipline is identical to `go-e2e-test`; only the runner
(`pytest` + `pytest-asyncio`), the HTTP client (`httpx.AsyncClient` against the
deployed API), and the flake mechanics (a rerun plugin, pytest markers) differ.

---

## Scope Boundary — E2E vs. Integration

The boundary is which process boundary a test crosses, not which dependency it
touches:

| | `python-integration-test` | `python-e2e-test` (this skill) |
|---|---|---|
| Runs inside | The test process itself | No app process inside the test at all |
| Exercises | This service's own code, imported and called directly, against a real dependency (testcontainers Postgres/Redpanda) | The deployed image, actually running as a Pod, actually receiving traffic |
| Crosses | A dependency boundary (real SQL, real broker) | A real service boundary — real network hop, real DNS, real Linkerd mTLS handshake, real ingress |
| Reached via | Direct `import` and function/coroutine calls | `httpx` over the network, or a browser (`react-e2e-testing`) |
| Multi-service? | Never — one service under test | Often — a journey spans several Bounded Contexts' deployed services |

A test that `import`s another service's module to simulate calling it is not e2e
no matter how many real dependencies sit underneath — no network hop was crossed,
so it is at most an elaborate integration test. A test that drives the real API
endpoint over HTTP from outside the process is e2e even for one service: the
deployed app's ASGI transport, middleware chain, and TLS termination are all
genuinely exercised, none of which an `import` ever touches.

---

## Coverage — Few, Critical-Path Only

Cover the journeys that matter; push permutations down. E2E is the pyramid's
narrow apex, not its default layer:

| Cover with e2e | Push down |
|---|---|
| P1 DataAsset journeys (ingest → classify → compliance report) | Validation rules → unit (`python-unit-test`) |
| Cross-service happy paths + one critical failure path | Repository/outbox/consumer wiring → integration (`python-integration-test`) |
| Auth → action → persistence → event → projection round-trips | Handler request/response shape → `python-fastapi-handler` tests |
| A release smoke slice (the `@pytest.mark.smoke` subset) | Edge-case permutations → unit/integration |

The full-journey inventory should be a handful, not a matrix. Why e2e stays
small, and the rule for choosing the minimal set: `references/flake-and-scope.md`.

---

## Running-System Standard

E2E needs the real, deployed system, not a simplified stand-in. **The full
journey suite runs in an ephemeral `kind` cluster, created fresh per run and
destroyed after** — the same Helm charts at the same digest production runs,
differing only in a CI values file with a synthetic `tenant.id: e2e-<run-id>`
(the Environment Parity law `environment-config` already sets). Never
docker-compose for the full suite: a second, divergently-decaying deployment
description breaks parity for the one layer that most needs to catch real deploy
drift. `docker-compose` is admissible only as a throwaway local convenience for
authoring a single journey — it is never the CI standard and never the parity
source of truth.

pytest drives the journey entirely over the network: an `httpx.AsyncClient`
pointed at the deployed ingress URL yielded by a `session`-scoped fixture, plus
an `aiokafka` consumer subscribed to the real topics to assert emitted events.
Full provisioning (`provision-kind.sh`, `helm install --wait`), the base-URL and
client fixtures, and a complete DataAsset journey test: `references/e2e-setup-and-flow.md`.

**Honest divergence from Go — the UI suite is TypeScript regardless of backend.**
`go-e2e-test` names Playwright UI e2e and API-level Go e2e as two surfaces of one
skill. `playwright-python` exists and is a first-class port, but the frontend is
React + TypeScript by default (`CLAUDE.md`), so genuinely user-facing browser
journeys stay authored in TypeScript under `react-e2e-testing` — Python changes
only *what backend the journey exercises*, not what language the browser suite is
written in. This skill therefore owns the **API-level** e2e surface (pytest +
`httpx` against the deployed FastAPI system); it does not re-author browser e2e in
Python. That makes it a deliberately *thin* analog of its Go sibling.

---

## Cross-Service Assertions — HTTP + Emitted Events

A journey is proven at two real surfaces, both from outside the processes:

- **HTTP** — every step is an `httpx` call to the deployed API: sign in, connect a
  source, classify an asset, fetch the compliance gap report. Assert on real
  status codes and response bodies the deployed middleware actually produced.
- **Emitted events** — subscribe an `aiokafka` consumer to the real Redpanda topic
  and assert the `DataAssetClassified` event actually landed with the expected
  tenant-scoped payload — proving the pipeline published, not just that the write
  returned 200.

Because the pipeline is eventually consistent, the projection updates *after* the
event is processed — assert it by **polling with a deadline**, never
`await asyncio.sleep(n)` as a "give it a second" guess. The poll helper and the
event-assertion pattern: `references/e2e-setup-and-flow.md`.

---

## Flake Control

E2E is inherently flakier than unit/integration — real network hops, DNS, mesh
handshakes, async pipeline lag — a cost to budget, not a defect to chase to zero:

- **Retry** — exactly **one** automatic retry before a genuine failure, bounded
  (never retry-until-green). The Python mechanism (a named plugin and flag) and
  why one retry is a diagnostic, not a pass criterion: `references/flake-and-scope.md`.
- **Quarantine** — a test that flakes across multiple runs moves behind a marker
  that still runs in CI non-blocking, with a tracked issue and a two-week
  deadline — never a silent `pytest.mark.skip` with no issue.
- **Condition-based waits** — every wait is a condition with a deadline, so the
  suite is fast when the system is fast and fails loudly when not.
- **Data isolation** — each run seeds under a unique `tenant_id: e2e-<run-id>` via
  idempotent (`ON CONFLICT`) seed, with guaranteed teardown on failure *and*
  success (the failure branch runs the identical cleanup). Full mechanics:
  `references/flake-and-scope.md`.

---

## CI Placement

The full suite runs **never on `pull_request`** — cost (a multi-service `kind`
cluster costs minutes, not the seconds a testcontainers pair costs) and a
non-zero false-failure rate that would erode trust in a required PR gate. Three
triggers instead: **nightly** (`schedule: cron`), **pre-release**
(`release: published`), and **on-demand** (`workflow_dispatch`). The tagged
`@pytest.mark.smoke` slice runs separately and more often — on every promotion,
directly against the real environment (`-m smoke`), as `cd-pipeline`'s post-deploy
verification and `blue-green-deployment`'s pre-cutover gate assume. Trigger YAML
and the smoke-marker wiring: `references/flake-and-scope.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Scope boundary honored | Crosses a real network hop against the deployed app | "E2E" that `import`s another service's module |
| Few, high-value | Critical journeys only; permutations pushed down | E2E duplicating lower-layer coverage |
| Real full stack | Deployed services + real DB + real broker | Mocked backends called "e2e" |
| Ephemeral, representative env | `kind`, same charts/digest as production | docker-compose stand-in as the CI standard |
| Guaranteed teardown | Cleanup on failure and success, per-run tenant | Happy-path-only cleanup; orphaned data |
| Idempotent seeding | `ON CONFLICT` upsert, run-id-derived IDs | Blind `INSERT`; reruns fail or duplicate |
| No arbitrary sleeps | Condition-based `httpx`/consumer polls with deadlines | `asyncio.sleep` guesses |
| Eventual-consistency aware | Polls for the projected state / emitted event | Asserting immediately after an async action |
| Retry policy explicit | One automatic retry, then genuine failure | Retry-until-green |
| Flaky tests governed | Quarantine marker + issue + deadline; list trends to empty | Ignored, deleted, or silently skipped |
| Full-suite CI-placed correctly | Nightly + pre-release + on-demand; never `pull_request` | Full e2e suite blocking every PR |
| Smoke subset present | `-m smoke` slice runs against real envs on promotion | Promotion trusts the nightly run alone |

---

## Anti-Patterns

- **E2E as the default layer** — a journey test for what unit/integration already
  proves inverts the pyramid into an ice-cream cone.
- **Package-import "e2e"** — `import`ing another service's code to simulate calling
  it never crosses a network boundary; at most it is integration.
- **docker-compose as the CI environment** — a second, divergent deployment
  description breaks Environment Parity for the layer that most needs to catch
  deploy drift; `kind` with the same charts/digest is the standard.
- **Happy-path-only teardown** — a fixture whose failure path skips cleanup leaves
  orphaned tenant data that silently accrues.
- **`asyncio.sleep` as synchronization** — the canonical flake generator; every
  wait is a condition with a deadline.
- **Retry-until-green** — masks the real intermittent bugs (races, ordering) e2e
  exists to catch; one retry is a diagnostic, not a pass criterion.
- **Full suite on every PR** — the cost and flakiness math never closes; nightly
  plus pre-release plus on-demand, with the smoke subset covering promotions, is
  the affordable, sufficient placement.
- **Re-authoring browser e2e in Python** — user-facing browser journeys stay in
  TypeScript under `react-e2e-testing`; this skill owns the API-level surface only.

---

## Output Format

Produces API-level journey tests, the ephemeral-environment script, and the CI
triggers:

```
tests/e2e/conftest.py                (session base-URL, httpx client, aiokafka consumer fixtures)
tests/e2e/test_dataasset_journey.py  (ingest→classify→compliance; HTTP + event asserts; -m smoke subset)
tests/e2e/provision-kind.sh          (kind create, helm install --wait, trap-based teardown)
.github/workflows/e2e-nightly.yml    (nightly/pre-release/on-demand triggers, always() teardown)
```

Full standards: `references/e2e-setup-and-flow.md` (bringing up the system, the
fixtures, the worked DataAsset journey with HTTP + event assertions, the poll
helper, trace correlation) and `references/flake-and-scope.md` (retry plugin,
quarantine marker, condition-based waits, per-run data isolation and teardown,
choosing the minimal critical-path set, CI triggers).
