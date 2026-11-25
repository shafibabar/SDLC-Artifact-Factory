# pact-go v2 and Pact Broker Official Documentation
**Authors:** Pact Foundation (pact-foundation/pact-go, docs.pact.io)
**Domain:** Testing (contract)

Accessed 2026-11-25. pact-go latest v2.9.1, 2026-11-17 (https://api.github.com/repos/pact-foundation/pact-go/releases/latest), MIT. Pact Broker OSS is MIT, self-hosted on PostgreSQL, with a Docker image (https://github.com/pact-foundation/pact_broker).

## Core Concepts

- **Setup:** `go get .../pact-go/v2`, install the CLI, then `pact-go -l DEBUG install` for the native FFI library. Needs cgo and a C compiler; default library directory needs sudo. (https://github.com/pact-foundation/pact-go)
- **Consumer:** `consumer.NewV2Pact` (README) or `NewV4Pact` (https://raw.githubusercontent.com/pact-foundation/pact-go/v2.9.1/consumer/http_v4.go); `AddInteraction`, `ExecuteTest`.
- **V4 async messages:** `NewAsynchronousPact`, `AddAsynchronousMessage` (https://raw.githubusercontent.com/pact-foundation/pact-go/v2.9.1/message/v4/asynchronous_message.go).
- **Provider:** `HTTPVerifier.VerifyProvider(t, VerifyRequest{...})` with `ProviderBaseURL`, `BrokerURL`, `ConsumerVersionSelectors`, `EnablePending`, `IncludeWIPPactsSince (*time.Time)`, `ProviderBranch`, `ProviderVersion`, `PublishVerificationResults`, `FailIfNoPactsFound`, `StateHandlers`, `MessageHandlers`, `RequestTimeout` (default 10s); `ProviderStatesSetupURL` is deprecated. (https://raw.githubusercontent.com/pact-foundation/pact-go/v2.9.1/provider/verify_request.go)
- **State handler type:** `func(setup bool, state ProviderState) (ProviderStateResponse, error)`; `StateHandlers` is a map by state name (https://raw.githubusercontent.com/pact-foundation/pact-go/v2.9.1/models/provider_state.go). The repository's docs/provider.md still shows older `V3` type names.
- **Selector fields:** `Tag`, `FallbackTag`, `Latest`, `Consumer`, `DeployedOrReleased`, `Deployed`, `Released`, `Environment`, `MainBranch`, `MatchingBranch`, `Branch` (https://raw.githubusercontent.com/pact-foundation/pact-go/v2.9.1/provider/consumer_version_selector.go).
- **Recommended selectors:** mainBranch, branch, matchingBranch, deployedOrReleased. Deployment selectors need recorded deployments or releases. `latest: true` alone is not recommended (race across branches). (https://docs.pact.io/pact_broker/advanced_topics/consumer_version_selectors)
- **Pending pacts:** enable flag plus provider branch, consumer branch and version, Broker 2.60.0+. (https://docs.pact.io/pact_broker/advanced_topics/pending_pacts) **WIP:** `includeWipPactsSince`, with pending enabled and a recent date. (https://docs.pact.io/pact_broker/advanced_topics/wip_pacts)
- **can-i-deploy:** `pact-broker can-i-deploy --pacticipant P --version V --to-environment E`, exit 0 safe, 1 not; without `--to-environment` it compares with latest versions. Then `record-deployment --pacticipant P --version V --environment E`. (https://docs.pact.io/pact_broker/can_i_deploy)
- `record-deployment` marks the previous version undeployed and is called once deployment can no longer fail; environments are created with `create-environment` (`test`, `production` pre-created); libraries use `record-release`. (https://docs.pact.io/pact_broker/recording_deployments_and_releases)
- `--retry-while-unknown` (default 0), `--retry-interval` (10s), `--dry-run` always exits success; publish with `--branch`. (https://docs.pact.io/pact_broker/client_cli/readme)

## Actionable Techniques

- Verify with selectors `MainBranch`, `MatchingBranch`, `DeployedOrReleased`, plus pending, WIP and `ProviderBranch`; set `FailIfNoPactsFound`.
- Pipeline order: publish, verify, can-i-deploy, deploy, record-deployment.
- Publish results only from CI (https://raw.githubusercontent.com/pact-foundation/pact-go/v2.9.1/docs/provider.md). Forbid `--dry-run` and `SoftFail` in gates (design inference).

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| go-contract-test, cd-pipeline | W3B-36, 37; narrative 3 | API fields and Broker flow |

## Candidate New Skills/Agents

None.

## Key Terminology

Pacticipant, Provider State, Consumer Version Selector, Pending Pact, WIP Pact, can-i-deploy.

## Caveats

- Nothing compiled; the native library install was not tried.
- docs/messages.md shows the V3 API.
- [unverified] Message provider verification in v4; current Broker release; README note on `/tmp` and recent Go.

## Answers to audit questions

| Question (batch ID) | Answer | Status |
|---|---|---|
| Narrative 3: can-i-deploy `--to-environment` and `Deployed` need a recorded deployment | Yes | Confirmed |
| W3B-37: pending/WIP flags exist and must be set | Yes | Confirmed |
| W3B-37: native library setup required | Yes | Confirmed |
| W3B-37: v2 selector and state-handler types | As listed above | Confirmed from v2.9.1 source |
| W3B-37: `{Latest: true}` means main-branch latest | No; use `MainBranch` | Refutes the skill's description |
| W3B-38: replay misses an enum widened to free text | Not addressed by these pages | Unverified |
