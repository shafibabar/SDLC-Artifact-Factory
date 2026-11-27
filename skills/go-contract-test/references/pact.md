# Pact: Consumer-Driven Contracts on a Self-Hosted Broker

Self-contained. Read when adding, changing or explaining Pact for a direct request/response call between two services. Results marked "run" were observed with pact-go v2.9.1, Pact Broker 2.124.0 and `pact-broker` client 1.78.0. Method from Cruz and Prescott, *Contract Testing in Action*; API facts from the pact-go and Pact Broker documentation.

## Contents

The rule; what Pact adds; the flow; why it runs daily; the deployment check; selectors; pending and work-in-progress pacts; Provider States; a provider that checks a token; matchers; the broker; what is refused.

## The rule

**Every direct service-to-service request/response call is covered by Pact, at every product size, lean included.** There is no trigger to wait for and no decision record needed to adopt it. Pact is added **on top of** the API-description checks (`./references/http-contracts.md`); it replaces none of them. A consumer outside the product (a partner, another team) is covered the same way, and that party must agree to run its half. Events are not covered by Pact.

## What Pact adds

A description check proves that a response has the agreed shape. It says nothing about the particular values and combinations a consumer depends on. In a Pact consumer test the consumer's real client runs against a mock built from exact interactions (this request, that response), and the recorded interactions are then replayed against the real provider. The consumer's needs define what the provider must keep honouring: the provider is free to change anything no consumer recorded.

| Check | Catches | Misses |
|---|---|---|
| Description gate and conformance | Any change of documented shape, for all callers, known or not | What a caller relies on beyond the shape |
| Pact | A provider change that breaks what a known consumer actually does | Callers that publish no pact; shape nobody reads |

## The flow

1. **Consumer test** (`//go:build pact`): writes `pacts/<consumer>-<provider>.json`. The file is a by-product, never hand-written.
2. **Publish** with the commit as the version and the branch: `pact-broker publish ./pacts --consumer-app-version "$GIT_SHA" --branch "$GIT_BRANCH"`. Versions are commits; nobody maintains a contract version number.
3. **Provider verification** (`//go:build pact`): fetches the pacts chosen by the selectors, replays them against the real router with Provider States, and publishes the results (from the pipeline only, never from a laptop).
4. **Impact report**: one `can-i-deploy --output json` per service and environment, turned into the report by `./scripts/write-pact-impact-report.sh`.
5. **At deployment**: `can-i-deploy`, then deploy, then `record-deployment`.

Neither side checks out the other's code. The broker is the only thing they share.

## Why it runs daily and not on every build

Pact needs a native library (cgo) and a reachable broker. It therefore stays behind the `pact` build tag, outside `make ci`, and runs **once a day on a schedule** (and by hand). Every build and pull request runs only the cheaper description and event checks.

Say the consequence in plain words whenever Pact comes up: **a pull request is not blocked by Pact. A change that breaks a consumer can be merged, and shows up in the next day's report.** What stops it reaching users is the deployment check.

## The deployment check

A deployment of a service runs `pact-broker can-i-deploy --pacticipant <service> --version <commit> --to-environment <environment>` and is refused on exit 1. It runs no test: it asks the broker whether the latest recorded results say this commit works with what is in that environment.

Observed (run):

| Situation | Answer |
|---|---|
| Provider commit whose verification failed against the consumer in production | Exit 1 |
| Consumer commit with an expectation the deployed provider has not been verified against | Exit 1 |
| A commit no Pact run has recorded | Exit 1: `No pacts or verifications have been published for version ...` |
| Consumer, when no provider version is recorded in that environment yet | Exit 1. The provider deploys first |
| Provider with no failing consumer | Exit 0 |
| A service name or an environment the broker does not know | Exit 1 with an error, no table |
| Any of the above with `--dry-run` | **Exit 0**, the refusal only printed |

So a commit can deploy only after a Pact run has recorded it: the daily run, or the same workflow started by hand for that commit. `record-deployment` runs once the deployment can no longer fail; it is what tells the broker what "in production" means. A library that is released and not deployed uses `record-release`.

## Selectors

Verify against `MainBranch`, `MatchingBranch` and `DeployedOrReleased`. `Latest: true` is the newest pact from **any** branch, so a colleague's experiment decides the result; it is refused. Deployment selectors only work once deployments are recorded.

Set `FailIfNoPactsFound: true`. Without it a verification that finds no pact at all passes, with one `ERROR` log line as the only sign (run). `SoftFail` is never set.

## Pending and work-in-progress pacts

Without these, a consumer adding an expectation turns the provider's next run red before anyone on the provider side has seen it.

- **Pending** (`EnablePending: true`, with `ProviderBranch` and `ProviderVersion` set): a pact that has never passed against the provider's branch is verified, its result recorded, and a failure does not fail the run.
- **Work in progress** (`IncludeWIPPactsSince`): the same for pacts published from a consumer's feature branch.

Observed (run): with a new, unmet expectation the provider's `go test` exits **0** and prints `Pending Failures`; the same run with pending off exits 1. The failed result is still recorded, and `can-i-deploy` refuses the consumer's commit. Once a pact has passed on the provider's main branch it is no longer pending, and a later failure fails the run.

This is why the daily report is built from the broker's answers and not from the provider run's exit status.

## Provider States

Each recorded interaction names the state it needs (`Given("class ... is open with 4 seats left")`); the provider maps that exact text to setup code.

- **The text is part of the contract.** A handler map key that differs by one character is simply never called. pact-go v2.9.1 raises no error for a state without a handler (run): the request runs with no setup, and an interaction expecting "nothing exists" passes by accident.
- **Guard against that**: reset to a failing condition in `BeforeEach`, and let only a state handler clear it, as the template does. An unmatched state then fails (run).
- **One state, one handler**; no handler that matches on part of the text.
- **Build the handler map in a function** that receives what setup needs (the store, the pool, `t`). A package-level map cannot reach `t`.
- `setup` is `true` before the interaction and `false` after it.
- **Real commits, scoped data.** The verifier's request reaches the provider on its own connection, so data inside an open transaction is invisible: `go-integration-test`'s default rollback isolation cannot be used. Seed committed rows keyed to the ids the state names, and remove exactly those (`test-fixture-design`). Never reset whole tables between interactions.
- Two interactions must give the same result in any order.

## A provider that checks a token

The verifier replays the header the consumer recorded, so a provider behind real token-checking middleware answers 401 and the verification fails. Three rules, each observed in a run (`../templates/pact-tests.md`, "When the provider checks a token"):

1. **The real middleware stays.** Removing or bypassing it in the test router makes every interaction pass, including one that sends no token: a silent pass. Give the router a key made for the run and let a `RequestFilter` swap the recorded token for one signed with it. Nothing else about sign-in changes in the test.
2. **The filter replaces a header and never adds one.** A filter that always sets it passes a consumer that forgot to send a token.
3. **The pact holds no credential.** The consumer records an unsigned, token-shaped example with a `Regex` on the bearer shape; a working or never-expiring token in a pact is a leaked credential, and `Like` accepts any string.

Each sign-in refusal the consumer handles is its own interaction with one Provider State ("no token → 401", "expired token → 401"); for the expired case the filter must sign an expired token, or the case passes for the wrong reason. Pact proves a check only where such an interaction exists: a provider that drops its audience check stays green unless a consumer recorded that refusal. The token rules themselves are `security-implementation`'s.

## Matchers decide what Pact notices

Observed (run): the provider began returning a status outside the old set. A pact that matched the field with `Regex("open", "^(open|full|cancelled)$")` failed verification. A pact that matched it with `Like("open")` **passed**: a type matcher accepts any string. Match a field by value or pattern where the consumer's behaviour depends on the value, and by type where it only passes the value through.

## The broker

Self-hosted, open source (`pactfoundation/pact-broker`, pinned tag, its own PostgreSQL database), run like any other service of the product. Credentials come from the pipeline's secrets. **PactFlow**, the hosted commercial service, is refused without the product owner's approval, including its "bi-directional" mode, in which a provider's OpenAPI description is compared with consumer pacts without replaying them: that is a paid feature and gives up the replay.

Observed (run): the broker container exits with status 0 if PostgreSQL is not accepting connections yet; `test` and `production` environments exist from the start, others are created with `create-environment`.

## Refused, by name

`--dry-run` on `can-i-deploy`; `SoftFail`; `Latest: true`; a missing `FailIfNoPactsFound`; publishing verification results from a developer machine; a Pact test without the `pact` build tag; Pact in `make ci` or on a pull-request trigger; message pacts; PactFlow without approval; a hand-written pact file.
