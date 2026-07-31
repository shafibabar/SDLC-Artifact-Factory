# Pact Consumer-Driven Contract Workflow (Escalation Path)

Self-contained detail for `go-contract-test`'s escalation tier — adopted per-boundary, with an ADR, once a boundary genuinely crosses team/repo lines (parent `SKILL.md`'s "Two Tiers" section states the trigger). Tooling: `pact-go` v2 (`github.com/pact-foundation/pact-go/v2`), the Go client for the open-source Pact framework. Grounded in `research/testing/contract-testing-in-action-cruz-prescott.md` (Ch. 3–9).

## Why This Is a Different Test, Not the Same Test Pointed at a New Library

The schema tier (`schema-based-contract-and-event-compatibility.md`) validates structure. Pact's consumer test defines **exact interactions** — a specific request triggers a specific expected response, down to the actual field values the consumer's code depends on — and generates a mock HTTP server from those interactions. The consumer's real client code runs against that mock. The side effect of running the test is a generated **pact file** (JSON): the contract is a byproduct of testing the consumer, never a document written by hand first.

## Consumer Side: Generate the Pact

```go
// internal/test/contract/consumer/data_catalog_pact_test.go
package contract

func TestConsumer_GetDataAsset_Pact(t *testing.T) {
    mockProvider, err := consumer.NewV2Pact(consumer.MockHTTPProviderConfig{
        Consumer: "estate-scan-service",
        Provider: "data-catalog-service",
        PactDir:  "./pacts",
    })
    require.NoError(t, err)

    mockProvider.
        AddInteraction().
        Given("a classified data asset with id abc123 exists").
        UponReceiving("a request for data asset abc123").
        WithRequest("GET", "/v1/data-assets/abc123", func(b *consumer.V2RequestBuilder) {
            b.Header("Authorization", matchers.S("Bearer valid-jwt"))
        }).
        WillRespondWith(200, func(b *consumer.V2ResponseBuilder) {
            b.Header("Content-Type", matchers.S("application/json")).
                JSONBody(matchers.MapMatcher{
                    "id":               matchers.Like("abc123"),
                    "sensitivityLevel": matchers.Term("Restricted", "Public|Internal|Confidential|Restricted"),
                })
        })

    err = mockProvider.ExecuteTest(t, func(cfg consumer.MockServerConfig) error {
        client := datacatalog.NewClient(fmt.Sprintf("http://%s:%d", cfg.Host, cfg.Port))
        asset, err := client.GetDataAsset(context.Background(), "abc123")
        require.NoError(t, err)
        require.Equal(t, "Restricted", asset.SensitivityLevel)
        return nil
    })
    require.NoError(t, err)
}
```

Running this test writes `pacts/estate-scan-service-data-catalog-service.json` — the recorded interaction, including the `Given(...)` string, which becomes the Provider State the provider side must satisfy (`provider-state-setup-standard.md`). The consumer's real HTTP client (`datacatalog.NewClient`) is exercised against the mock, not a hand-rolled fake — a wire-format bug in the client itself is caught here too.

## Provider Side: Replay the Recorded Interactions

```go
// internal/test/contract/provider/data_catalog_verify_test.go
package contract

func TestProvider_VerifyAgainstConsumerPacts(t *testing.T) {
    verifier := provider.NewVerifier()

    err := verifier.VerifyProvider(t, provider.VerifyRequest{
        ProviderBaseURL:             "http://localhost:8080",
        BrokerURL:                   os.Getenv("PACT_BROKER_URL"),
        PublishVerificationResults:  true,
        ProviderVersion:             os.Getenv("GIT_SHA"),
        ConsumerVersionSelectors: []types.ConsumerVersionSelector{
            {Latest: true},              // latest main-branch pact per consumer
            {Deployed: true},            // + whatever is actually deployed right now
        },
        StateHandlers: providerStateHandlers, // provider-state-setup-standard.md
    })
    require.NoError(t, err)
}
```

The Verifier issues the *exact recorded request* from each interaction against the real, running provider — real handlers, real middleware, real database behind it — and asserts the real response matches what the consumer's mock promised. The consumer's real code never runs in this test; that is what keeps a contract test from becoming a same-process integration test (parent `SKILL.md`'s boundary section).

## Exact CI Wiring

**Consumer pipeline** (runs in the consuming service's own CI):

1. `go test ./internal/test/contract/consumer/...` — regenerates `pacts/*.json`.
2. Publish: `pact-broker publish ./pacts --consumer-app-version=$GIT_SHA --branch=$GIT_BRANCH --broker-base-url=$PACT_BROKER_URL`.
3. Before deploying the consumer: `pact-broker can-i-deploy --pacticipant estate-scan-service --version=$GIT_SHA --to-environment=production --broker-base-url=$PACT_BROKER_URL` — deploy job fails closed if this returns non-zero.

**Provider pipeline** (runs in the providing service's own CI, independently):

1. `go test ./internal/test/contract/provider/...` — this is `TestProvider_VerifyAgainstConsumerPacts` above; it fetches the latest + deployed pacts from the Broker (no local file dependency on the consumer's repo) and publishes verification results back to the same Broker, tagged with the provider's own `$GIT_SHA`.
2. Before deploying the provider: the identical `can-i-deploy` check, run with `--pacticipant data-catalog-service`.

Neither pipeline ever checks out or builds the other service's code. The Broker is the only shared state between the two CI systems — this is what makes the two sides independently deployable while still gated on compatibility.

## Test-Pyramid Placement

Both the consumer test and the provider verification run entirely within their own side's CI, with **no network call to the real counterpart at test time** — the consumer test talks to a Pact-generated local mock; the provider test replays against its own real, locally running instance. This places contract tests below full integration/E2E tests in cost, above pure unit tests in cross-service confidence — a scope claim, not a replacement for either layer (Cruz & Prescott Ch. 1, 12; mirrored in `test-pyramid`).
