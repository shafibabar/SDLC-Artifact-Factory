---
name: go-contract-test
description: >
  Teaches Consumer-Driven Contract testing in a frugal, schema-first way — verifying
  that service boundaries agree using the shared OpenAPI contract (provider verified
  against the spec, consumers generated from it) and schema validation for events,
  rather than standing up a Pact broker by default. Covers provider verification,
  consumer expectations, event-schema compatibility checks, and where heavier CDC
  tooling is justified. Enforces the architecture's Consumer-Driven Contracts.
  Used by the test-strategist during Implement and Quality.
version: 1.1.0
phase: implement
owner: test-strategist
created: 2026-06-25
tags: [implement, quality, contract-test, consumer-driven, openapi, schema, pact]
---

# Go Contract Test

## Purpose

When two services talk, each makes assumptions about the other's shape — and a silent change on one side breaks the other in production. Contract tests catch that break at **build time**: they verify that a provider still satisfies what its consumers expect, and that consumers only depend on what the provider actually offers. This is the enforcement mechanism for the **Consumer-Driven Contract** pattern the enterprise-architect mandates on every Customer/Supplier relationship (`integration-design`, `context-map-patterns`).

The frugal stance: we already have **one shared OpenAPI contract** that both sides generate from, so most contract testing is schema verification — no Pact broker required.

---

## Frugality First: Schema-Based Contracts

For HTTP boundaries, the contract already exists and is already shared: the `openapi.yaml` (`api-contract-design`). The backend generates its server from it (`go-openapi-codegen`); the frontend and consuming services generate their clients from it (`react-api-client`). That shared generation is itself a strong contract — neither side can hand-write a divergent shape.

Contract testing then verifies the two things generation alone can't:

1. **Provider verification** — the running provider actually conforms to the spec (not just the generated stubs, but real responses).
2. **Consumer expectation** — each consumer declares the subset of the contract it uses, so a provider can know what it may safely change.

```go
// Provider verification: assert real responses validate against the OpenAPI schema.
func TestProvider_ConformsToOpenAPI(t *testing.T) {
    doc := loadOpenAPI(t, "api/openapi.yaml")
    router := newRealRouter(t)                       // the actual handlers + middleware

    resp := doRequest(t, router, "GET", "/v1/data-assets", validJWT(t))
    require.NoError(t, validateAgainstSchema(doc, "GET", "/v1/data-assets", resp)) // real response ⊆ spec
}
```

`kin-openapi` validates real requests/responses against the spec — so a handler that drifts from the contract fails the build, with no broker to operate.

---

## Consumer-Driven: Who Drives the Contract

"Consumer-driven" means the **consumer's** needs define the contract the provider must honour — not the provider dictating shapes. In practice:

- Each consumer has a test declaring exactly the fields and endpoints it depends on.
- The provider's verification runs the union of all consumers' expectations.
- The provider may freely change anything **no consumer depends on**; a change to something a consumer needs fails that consumer's contract test.

This maps to the additive-vs-breaking rule: additive changes (new optional fields) keep all consumer contracts green; removing or changing a consumed field breaks the responsible consumer's test — exactly the signal you want, at build time.

---

## Event Contracts — Schema Compatibility

Asynchronous boundaries (Redpanda topics) are contracts too. The event schema is the wire contract (`event-schema-design`); the contract test verifies **compatibility** rather than a request/response shape.

```go
// A producer's emitted event must validate against the registered schema for its subject.
func TestEvent_DataAssetClassified_MatchesSchema(t *testing.T) {
    schema := loadEventSchema(t, "data-asset-classified-v1")
    evt := buildClassifiedEvent()
    require.NoError(t, validateJSON(schema, marshal(evt)))   // producer ⊆ schema
}

// And evolution stays backward-compatible (mirrors the registry's BACKWARD mode).
func TestEventSchema_BackwardCompatible(t *testing.T) {
    require.NoError(t, checkCompatibility(t, "data-asset-classified", "BACKWARD"))
}
```

Consumers, in turn, test that they tolerate the schema they read — including unknown additional fields (forward-compatibility), so an additive producer change doesn't break them.

---

## Provider Verification Loop

The provider runs all consumer expectations in CI on every change, so it learns immediately if it has broken anyone:

```
consumers declare expectations (committed in the repo / shared)
        │
provider CI runs: real provider ⊨ every consumer expectation + OpenAPI conformance
        │
   green ⇒ safe to deploy   |   red ⇒ a consumer would break — fix or version
```

Because we're solo and the services share one repo/contract, this loop is a CI job, not cross-team broker choreography — frugal by design.

One versioning subtlety once services deploy independently: green against the consumer expectations **at HEAD** does not prove safety against the consumer version **actually running in production**. Pin each consumer's expectation files to the deployed version (a tag or commit recorded at deploy time) and verify the provider against both HEAD and deployed expectations. This is the frugal, file-based answer to Pact's "can-i-deploy" question.

---

## When Heavier CDC Tooling Is Justified

Pact (with a broker) earns its keep when contracts cross **team or repository boundaries** and you need independent deploy coordination and versioned contract negotiation between parties who don't share a codebase. For a solo operator with a shared contract, that machinery is overhead.

**Decision rule:** stay schema-based (OpenAPI + event-schema validation) until there's a genuine multi-party, multi-repo integration that needs brokered contract negotiation — then adopt `pact-go` for that specific boundary and record it as an ADR. Don't pay for the broker before the problem exists.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Schema-first | Provider verified against shared OpenAPI; clients generated | Hand-written divergent shapes on each side |
| Provider verification | Real responses validated against the spec in CI | Only generated stubs checked, not real behaviour |
| Consumer-driven | Consumers declare what they use; provider honours the union | Provider dictates shapes; consumers guess |
| Event compatibility | Emitted events validated + BACKWARD-compat checked | Event shape changes unverified |
| Build-time catch | Contract breaks fail CI before deploy | Breaks discovered in production |
| Frugal tooling | Schema validation by default; Pact only when multi-party | A Pact broker stood up for a solo, single-repo system |

---

## Anti-Patterns

- **Testing the generated stubs instead of the running provider** — codegen conformance is free; the contract test must exercise real handlers and middleware, where drift actually happens.
- **Provider-driven "contracts"** — a provider asserting its own output shape verifies nothing a consumer relies on; the consumer's declared subset is the contract.
- **Consumers asserting the full response shape** — a consumer that pins every field breaks on additive changes it never cared about; declare only the fields it reads.
- **Skipping event contracts** — the Redpanda topics are boundaries exactly like HTTP; an unverified Domain Event schema change is a production break waiting for a redeploy.
- **Verifying only HEAD-to-HEAD** — independent deploys mean the deployed consumer version is the one that breaks; pin and verify deployed expectations too.
- **Standing up a Pact broker pre-emptively** — infrastructure without a multi-party problem; adopt it per-boundary, with an ADR, when the problem is real.

---

## Output Format

Produces contract verification tests:

```
internal/test/contract/provider_openapi_test.go     (provider ⊨ OpenAPI)
internal/test/contract/consumer_*_test.go            (per-consumer expectations)
internal/test/contract/event_schema_test.go          (event ⊨ schema + compatibility)
```
