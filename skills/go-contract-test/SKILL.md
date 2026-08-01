---
name: go-contract-test
description: >
  This plugin's Consumer-Driven Contract testing authority for Go — the third
  test boundary alongside go-unit-test (this service's own logic) and
  go-integration-test (this service's own code against a real dependency it
  owns): a contract test verifies the wire-level agreement between two
  independently-deployed services, without either side's real implementation
  running end-to-end in the same test. Covers the frugal schema-based default
  (OpenAPI provider verification + event-schema compatibility, no broker —
  references/schema-based-contract-and-event-compatibility.md) and the full
  Pact-based escalation once a boundary crosses team/repo lines: the consumer
  test generating a pact file against a Pact-DSL mock provider, provider
  verification replaying those exact interactions with Provider State fixture
  setup (references/pact-consumer-driven-workflow.md,
  references/provider-state-setup-standard.md), and contract-versioning via a
  self-hosted Pact Broker's can-i-deploy gate plus Pending/WIP Pacts
  (references/contract-versioning-and-can-i-deploy.md). Enforces the
  architecture's Consumer-Driven Contracts (`context-map-patterns`,
  `integration-design`). Authored and applied by the test-strategist during
  Implement and Quality.
version: 2.0.0
phase: implement
owner: test-strategist
created: 2026-06-25
tags: [implement, quality, contract-test, consumer-driven, openapi, schema, pact, provider-state, can-i-deploy]
produces: go-contract-test
domain: testing
status: stable
related: [go-integration-test, go-unit-test, api-contract-design, context-map-patterns, event-schema-design, go-openapi-codegen, test-pyramid]
---

# Go Contract Test

## Purpose

When two independently-deployable services talk, each makes assumptions about the other's shape — a silent change on one side breaks the other in production. A contract test catches that break at **build time**, on each side's own CI, without either side's real implementation running end-to-end against the other. This is the enforcement mechanism for the **Consumer-Driven Contract** pattern `context-map-patterns` mandates on every Customer/Supplier relationship. Two tiers exist: a frugal, schema-based default that covers this repo's current solo/single-repo scale, and a full Pact-based Consumer-Driven Contract workflow for the day a boundary genuinely crosses team or repository lines. Neither tier is "contract testing done partially" — the schema tier is a legitimate, complete design at its scale; the Pact tier is a different, stronger guarantee, not the same test pointed at a bigger library.

---

## The Boundary: Contract Test vs. Integration Test vs. Schema Test

- **Integration test (`go-integration-test`)** — verifies *this service's own code* against a real dependency *this service owns*: the real Postgres it writes to, the real Redpanda topic it publishes on. Failure means our code is wrong.
- **Contract test (this skill)** — verifies the *wire-level agreement* between two independently-deployed services: this service as consumer of another team's API, or as provider to another team's consumer. Neither side's real implementation runs end-to-end in the same test — the consumer test talks to a generated mock, never the real provider; provider verification replays recorded requests against the real provider, but the consumer's real code never runs in that test. Failure means the contract drifted, not that either side's internal logic is wrong.
- **Schema test vs. true CDC test** — within contract testing itself, a schema check (`kin-openapi` against `openapi.yaml`) proves structural shape: required fields, correct types, valid enums. It does not prove the *specific value combinations* a consumer depends on stay compatible across a change that preserves type but changes meaning (an enum silently widened to free text is schema-valid and contract-broken). Pact's exact-interaction replay is what closes that gap. Full detail: `references/schema-based-contract-and-event-compatibility.md`.

---

## Two Tiers: Schema-Based Default vs. Pact Escalation

| | Stay schema-based | Escalate to Pact (`pact-go`) |
|---|---|---|
| Trigger | Single repo, one shared `openapi.yaml`/event-schema both sides generate from | Boundary crosses a team or repository line — independent deploy schedules, no shared codegen source |
| Consumer check | Declares the fields/endpoints it reads; provider verified structurally | Exact recorded interactions (request → specific response) replayed against the real provider |
| Deploy gate | File-pinning: verify provider against HEAD **and** each consumer's pinned deployed-version expectations | Pact Broker `can-i-deploy`, queried against real historical verification results |
| Cost | One CI job, no new infrastructure | A self-hosted Pact Broker (Postgres-backed), Provider State fixture wiring on the provider side |

**Decision rule:** stay schema-based until there is a genuine multi-party, multi-repo integration that needs brokered contract negotiation between parties who don't share a codebase — then adopt `pact-go` for that specific boundary and record it as an ADR. Don't stand up the Broker before the problem exists.

---

## Schema-Based Contracts (Frugal Default)

The contract already exists and is already shared: `openapi.yaml` (`api-contract-design`). The backend generates its server from it (`go-openapi-codegen`); consumers generate clients from it. Contract testing then verifies the two things generation alone can't: the running provider's **real** responses conform (not just its stubs), and each consumer's declared subset of the contract stays honoured. Event-topic boundaries (Redpanda) get the same treatment via schema-compatibility checks (`event-schema-design`). Provider verification loop, consumer-expectation pattern, event-compatibility tests, and the file-pinning deployed-version answer: `references/schema-based-contract-and-event-compatibility.md`.

---

## Consumer-Driven: Who Drives the Contract

"Consumer-driven" means the **consumer's** needs define what the provider must honour, in both tiers — not the provider dictating shapes. The provider may freely change anything no consumer depends on; changing something a consumer needs fails that consumer's contract test, exactly the signal wanted at build time. A provider asserting its own output shape verifies nothing; a consumer that pins the full response shape breaks on additive changes it never used.

---

## Pact-Based Consumer-Driven Contract Workflow (Escalation Path)

Consumer side: a `pact-go` test defines exact interactions against a Pact-generated local mock, and the consumer's **real client code** runs against that mock — the side effect is a generated pact file (JSON), a byproduct of testing the consumer, never hand-written. Provider side: the Pact Verifier replays each recorded interaction's exact request against the real, running provider and asserts the real response matches, using named **Provider States** to set up required fixtures first. CI wiring: the consumer's pipeline publishes its pact file(s) to the Broker after every green run; the provider's pipeline fetches the latest-and-deployed pacts from the Broker, verifies, and publishes results back — neither pipeline ever checks out the other's code. Full worked consumer/provider tests and the exact CI steps for both sides: `references/pact-consumer-driven-workflow.md`. Provider State fixture-setup rules, including why it requires real commits rather than `go-integration-test`'s default transaction-rollback isolation: `references/provider-state-setup-standard.md`.

---

## Contract Versioning and can-i-deploy

Neither tier hand-manages a semantic contract version — both tie versioning to the actual deployable artifact version (`$GIT_SHA`). The Pact tier's deploy gate is `pact-broker can-i-deploy`, querying the Broker's compatibility matrix of every consumer × provider version verified against each other, run immediately before deploy on **both** sides. **Frugal choice:** a self-hosted, open-source Pact Broker (Postgres-backed, the same database this stack already runs) — not PactFlow, a commercial SaaS that must be flagged against CLAUDE.md's frugality constraint before ever being adopted. Pending Pacts and WIP Pacts keep a newly published consumer expectation from instantly failing the provider's build before that team can react. Full reasoning, the frugal-vs-paid comparison, and the exact `can-i-deploy` wiring: `references/contract-versioning-and-can-i-deploy.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Correct tier chosen | Schema-based for shared-repo boundaries; Pact only for a real multi-party, multi-repo need, recorded as an ADR | Pact/Broker infrastructure stood up with no multi-party problem, or a cross-team boundary left on schema-only |
| Real responses verified | Provider verification exercises real handlers/middleware (both tiers) | Only generated stubs checked; drift in real logic goes uncaught |
| Consumer-driven | Consumer declares/records only what it reads; provider honours the union | Provider dictates shapes; consumer pins the full response |
| Schema vs. exact-interaction understood | Schema tier's structural-only limit stated explicitly where relied on | "Contract test" used loosely to imply exact-interaction guarantees the schema tier doesn't provide |
| Event compatibility | Emitted events schema-validated + `BACKWARD`-compat checked | Event shape changes unverified |
| Pact interactions exact | Consumer test's mock built from real client code against recorded interactions, not a hand-rolled fake | Hand-written stub substituted for the Pact-generated mock |
| Provider States correct | One named state per handler, exact string match, unrecognized state fails loudly | Generic/substring-matching handler; silent no-op on a misspelled state |
| Provider State fixtures durable | Real, tenant-scoped commits (`go-integration-test`'s real-commit exception) | Transaction-rollback isolation used for fixtures the Verifier's separate request can't see |
| Deploy gated on compatibility | `can-i-deploy` (or file-pinning HEAD+deployed check) blocks deploy on failure | Deploy proceeds regardless of contract-verification result |
| Frugal broker choice | Self-hosted, open-source Pact Broker; PactFlow flagged and approved explicitly if ever considered | Commercial SaaS adopted without an explicit frugality-constraint check |
| Build-time catch | Contract breaks fail CI before deploy, on both sides independently | Breaks discovered in production |
| No pending-pact build breaks | Pending/WIP Pacts non-blocking on first failure once multiple consumers exist | A new consumer expectation instantly reds the provider's build |

---

## Anti-Patterns

- **Testing the generated stubs instead of the running provider** — codegen conformance is free; the contract test must exercise real handlers and middleware, where drift actually happens.
- **Provider-driven "contracts"** — a provider asserting its own output shape verifies nothing a consumer relies on.
- **Consumers asserting the full response shape** — breaks on additive changes it never cared about; declare only what's read.
- **Skipping event contracts** — Redpanda topics are boundaries exactly like HTTP; an unverified Domain Event schema change is a production break waiting for a redeploy.
- **Treating schema validation as exact-interaction CDC** — a type-preserving, meaning-changing edit (enum widened to free text) passes schema validation and breaks a consumer; know which guarantee is actually in force.
- **Verifying only HEAD-to-HEAD** — independent deploys mean the deployed version is the one that breaks; pin and verify deployed expectations, or use `can-i-deploy`.
- **Standing up a Pact Broker pre-emptively** — infrastructure without a multi-party problem; adopt per-boundary, with an ADR, when the problem is real.
- **Reaching for PactFlow to skip standing up the open-source Broker** — a paid SaaS substituted for a small one-time self-hosting task; requires explicit frugality-constraint approval first.
- **Provider State fixtures seeded inside a rollback transaction** — the Verifier's request is a real, separate call; nothing it can see was ever committed.
- **A generic Provider State handler matching on substrings** — hides a misspelled or unrecognized state instead of failing loudly.
- **No Pending/WIP Pact policy with multiple consumers** — a provider's build breaks the instant any consumer iterates, discouraging exactly the incremental contract evolution CDC is meant to enable.

---

## Output Format

```
internal/test/contract/provider_openapi_test.go        (schema tier: provider ⊨ OpenAPI)
internal/test/contract/consumer_*_test.go               (schema tier: per-consumer expectations)
internal/test/contract/event_schema_test.go             (schema tier: event ⊨ schema + compatibility)
internal/test/contract/consumer/*_pact_test.go          (Pact tier: consumer test, writes pacts/*.json)
internal/test/contract/provider/*_verify_test.go        (Pact tier: provider verification)
internal/test/contract/provider/state_handlers.go       (Pact tier: named Provider State → fixture setup)
```

Every file in the Pact tier follows `references/pact-consumer-driven-workflow.md`'s exact interaction/CI shape and `references/provider-state-setup-standard.md`'s fixture rules — not an ad hoc variant per boundary.
