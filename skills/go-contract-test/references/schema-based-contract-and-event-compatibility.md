# Schema-Based Contract and Event-Compatibility Testing (Frugal Default)

Self-contained detail for `go-contract-test`'s default tier: verifying the shared `openapi.yaml` (`api-contract-design`) and Redpanda event schemas (`event-schema-design`) structurally, with no Pact broker. Read this after the parent `SKILL.md`'s "Schema-Based Contracts" and "Event Contracts" sections have named when this tier applies.

## What Schema Validation Proves — and Its Named Limit

`kin-openapi` (or any JSON-Schema validator) checks that a payload has the right shape: required fields present, types correct, enums drawn from the declared set. It does **not** check that the specific *values and combinations* a consumer actually depends on remain compatible across a change that preserves type but changes meaning — Cruz & Prescott's own example (`research/testing/contract-testing-in-action-cruz-prescott.md`) is a field that stays `string` typed but silently widens from a three-value enum to free text: a schema validator passes it; a true Consumer-Driven Contract test (built from the consumer's exact expected values) fails immediately. Schema validation is a real, working substitute for CDC's *structural* guarantee at this repo's solo/single-repo scale — it is not equivalent to CDC's *exact-interaction* guarantee. Do not let "we run contract tests" imply the stronger claim when only the schema tier is in force.

## Provider Verification Against the Shared OpenAPI Contract

```go
// internal/test/contract/provider_openapi_test.go
func TestProvider_ConformsToOpenAPI(t *testing.T) {
    doc := loadOpenAPI(t, "api/openapi.yaml")
    router := newRealRouter(t)                       // the actual handlers + middleware, not stubs

    resp := doRequest(t, router, "GET", "/v1/data-assets/abc123", validJWT(t))
    require.NoError(t, validateAgainstSchema(doc, "GET", "/v1/data-assets/{id}", resp))
}
```

Run this against **real handlers and real middleware**, never the generated stubs — codegen conformance is free and proves nothing; drift happens in the handwritten logic between the generated interface and the real response.

## Consumer Expectations

Each consumer declares, in its own repo/package, exactly the fields and endpoints it reads — not the full response shape:

```go
// internal/test/contract/consumer_estatescan_test.go
func TestConsumer_EstateScan_ReadsSensitivityLevel(t *testing.T) {
    doc := loadOpenAPI(t, "api/openapi.yaml")
    require.True(t, schemaExposesField(doc, "GET", "/v1/data-assets/{id}", "sensitivityLevel"))
}
```

A consumer that pins the *entire* response shape breaks on additive changes it never used; declare only what is actually read.

## Event Contracts — Schema Compatibility

Redpanda topics are contracts too. The event schema (`event-schema-design`) is the wire contract; verify emitted events against it and check that evolution stays `BACKWARD` compatible:

```go
// internal/test/contract/event_schema_test.go
func TestEvent_DataAssetClassified_MatchesSchema(t *testing.T) {
    schema := loadEventSchema(t, "data-asset-classified-v1")
    evt := buildClassifiedEvent()
    require.NoError(t, validateJSON(schema, marshal(evt)))    // producer ⊆ schema
}

func TestEventSchema_BackwardCompatible(t *testing.T) {
    require.NoError(t, checkCompatibility(t, "data-asset-classified", "BACKWARD"))
}
```

Consumers separately test that they tolerate the schema they read, including unknown additional fields (forward-compatibility) — an additive producer change must never break a consumer that only reads known fields.

## The Provider Verification Loop (CI)

```
consumers declare expectations (committed in the repo / shared)
        │
provider CI runs: real provider ⊨ every consumer expectation + OpenAPI conformance
        │
   green ⇒ safe to deploy   |   red ⇒ a consumer would break — fix or version
```

Solo, single-repo, shared contract ⇒ this loop is one CI job, not cross-team broker choreography.

## The File-Pinning Answer to "What's Actually Deployed"

Green against consumer expectations **at HEAD** does not prove safety against the consumer version **actually running in production** once services deploy independently. Pin each consumer's expectation files to the deployed version (a tag or commit recorded at deploy time) and verify the provider against both HEAD and the deployed expectations. This is the frugal, file-based answer to the question Pact's `can-i-deploy` answers with a queryable broker instead — see `contract-versioning-and-can-i-deploy.md` for the tooled version once a boundary escalates.
