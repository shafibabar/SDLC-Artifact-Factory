# Pact: Consumer-Driven Contracts on a Self-Hosted Broker

Self-contained. Read when adding, changing or explaining Pact for a direct request/response call between two services. Results marked "run" were observed with pact-python 4.2.0 (`pact-python-ffi` 0.5.13.0), the `pact` command of `pact-python-cli` 1!1.0.0 and Pact Broker 2.124.0. Method from Cruz and Prescott, *Contract Testing in Action*; API facts from the pact-python and Pact Broker documentation.

## Contents

The rule; what Pact adds; the flow; why it runs daily; the deployment check; selectors; pending and work-in-progress pacts; Provider States; a provider that checks a token; matchers; the broker; what is refused.

## The rule

**Every direct service-to-service request/response call is covered by Pact, at every product size, lean included.** There is no trigger to wait for and no decision record needed to adopt it. Pact is added **on top of** the API-description checks (`./http-contracts.md`); it replaces none of them. A consumer outside the product (a partner, another team) is covered the same way, and that party must agree to run its half. Events are not covered by Pact.

## What Pact adds

A description check proves that a response has the agreed shape. It says nothing about the particular values and combinations a consumer depends on. In a Pact consumer test the consumer's real client runs against a mock built from exact interactions (this request, that response), and the recorded interactions are then replayed against the real provider. The consumer's needs define what the provider must keep honouring: the provider is free to change anything no consumer recorded.

| Check | Catches | Misses |
|---|---|---|
| Description gate and conformance | Any change of documented shape, for all callers, known or not | What a caller relies on beyond the shape |
| Pact | A provider change that breaks what a known consumer actually does | Callers that publish no pact; shape nobody reads |

## The flow

1. **Consumer test** (`pact_tests/consumer/`): the real client runs against `pact.serve()`; the test's fixture then writes `pacts/<consumer>-<provider>.json`. pact-python does not write the file by itself. The file is a by-product, never hand-written.
2. **Publish** with the commit as the version and the branch: `pact broker publish pacts --consumer-app-version "$GIT_SHA" --branch "$GIT_BRANCH"`. Versions are commits; nobody maintains a contract version number.
3. **Provider verification** (`pact_tests/provider/`): fetches the pacts chosen by the selectors, replays them over HTTP against the real app with Provider States, and publishes the results (from the pipeline only, never from a laptop: `set_publish_options` is called only there, and without it nothing is recorded (run)).
4. **Impact report**: one `can-i-deploy --output json` answer per service and environment, turned into the report by `../scripts/write-pact-impact-report.sh`.
5. **At deployment**: `can-i-deploy`, then deploy, then `record-deployment`.

Neither side checks out the other's code. The broker is the only thing they share.

## Why it runs daily and not on every build

Pact needs a reachable broker, which `make ci` must not need. Pact tests therefore sit in `pact_tests/`, outside `tests/`, carry the `pact` marker, and run **once a day on a schedule** (and by hand). `make ci` runs `tests/` and never collects them. Every build and pull request runs only the cheaper description and event checks.

Say the consequence in plain words whenever Pact comes up: **a pull request is not blocked by Pact. A change that breaks a consumer can be merged, and shows up in the next day's report.** What stops it reaching users is the deployment check.

The folder, not the marker, is what keeps Pact out of `make ci`: the coverage gate (`python-unit-test`) runs all of `tests/` and gives no verdict when any test is deselected, so a marker inside `tests/` could not be excluded. The marker is what the daily targets select, and what makes a run that collected nothing fail (exit 5 in the pytest documentation; run).

## The deployment check

A deployment of a service runs `pact broker can-i-deploy --pacticipant <service> --version <commit> --to-environment <environment>` and is refused on exit 1. It runs no test: it asks the broker whether the latest recorded results say this commit works with what is in that environment.

Observed (run):

| Situation | Answer |
|---|---|
| Provider commit whose verification failed against the consumer in production | Exit 1 |
| Consumer commit with an expectation the deployed provider has not been verified against | Exit 1 |
| A commit no Pact run has recorded | Exit 1: `No pacts or verifications have been published for version ...` |
| Consumer, when no provider version is recorded in that environment yet | Exit 1. The provider deploys first |
| Provider with no failing consumer | Exit 0 |
| A service name or an environment the broker does not know | Exit 1 with an error, no table |
| Any refusal with `--dry-run` | **Exit 0**, the refusal only printed |
| Any refusal with `--output json` | **Exit 0**; `summary.deployable` is `false` in the JSON |

So a commit can deploy only after a Pact run has recorded it: the daily run, or the same workflow started by hand for that commit. `record-deployment` runs once the deployment can no longer fail; it is what tells the broker what "in production" means. A library that is released and not deployed uses `record-release` (not run).

## Selectors

Verify against `consumer_version(main_branch=True)`, `consumer_version(matching_branch=True)` and `consumer_version(deployed_or_released=True)`. `latest=True` is the newest pact from **any** branch, so a colleague's experiment decides the result; it is refused. Deployment selectors only work once deployments are recorded.

A verification that finds no pact at all **fails by default** in pact-python 4.2.0 (run); `set_error_on_empty_pact(enabled=False)` makes it pass (run) and is refused. The template states `set_error_on_empty_pact()` so the rule does not rest on a default.

## Pending and work-in-progress pacts

Without these, a consumer adding an expectation turns the provider's next run red before anyone on the provider side has seen it. Both are **off by default** in pact-python's selector builder.

- **Pending** (`include_pending()`, with `provider_branch(...)` set): a pact that has never passed against the provider's branch is verified, its result recorded, and a failure does not fail the run.
- **Work in progress** (`include_wip_since(date)`): the same for pacts published from a consumer's feature branch.

Observed (run): with a new, unmet expectation the provider's test passes, exit **0**, and its output shows `Pending Failures`; the same run without `include_pending()` exits 1. The failed result is still recorded, and `can-i-deploy` refuses the consumer's commit. Once a pact has passed on the provider's main branch it is no longer pending, and a later failure fails the run.

This is why the daily report is built from the broker's answers and not from the provider run's exit status.

## Provider States

Each recorded interaction names the state it needs (`given("plot ... is free and measures 25 square metres")`); the provider maps that exact text to setup code.

- **The text is part of the contract.** A handler key that differs by one character is never called.
- **Guard against that.** The store behind the app starts unready and every state's teardown makes it unready again, so a request with no setup answers 500 and the interaction fails at once; the template also names the unmatched state (run). Without the guard, an interaction expecting "nothing exists" passed by accident (run).
- **Use the single-function form of `state_handler` with `teardown=True`** and look the state up yourself, as the template does. With the mapping form, a state that is missing from the mapping fails only after about two minutes of retries (run).
- **One Provider State per interaction carries every fact it needs.** With two `given` calls, each setup replaced the last and the result depended on their order (run).
- A handler receives the state's parameters as its third argument; it cannot return values to the pact.
- The special state `""` is sent only for an interaction recorded with no state at all (run); it is not a hook that runs before every interaction, so do not rely on it for a reset.
- **Real commits, scoped data.** The verifier's request reaches the provider on its own connection, so data inside an open transaction is invisible: `python-integration-test`'s default rollback isolation cannot be used. Seed committed rows keyed to the ids the state names, and remove exactly those (`test-fixture-design`). Never reset whole tables between interactions.
- State handlers run in the test process, so the app is served from a thread of that process (uvicorn), not from another process or container.

## A provider that checks a token

The verifier replays the header the consumer recorded, so a provider behind real token-checking middleware answers 401 and the verification fails. Three rules, each observed in a run (`../templates/pact-tests.md`, "When the provider checks a token"):

1. **The real middleware stays.** Bypassing it in the app under test makes every interaction pass, including one that sends no token: a silent pass. Give the app a key made for the run and swap the recorded token for one signed with it. Nothing else about sign-in changes in the test.
2. **The swap replaces a header and never adds one.** pact-python's `Verifier` has no request filter. Its `add_custom_header` replaces a recorded header **and adds the header to a request recorded without one** (run), so a consumer that forgot to send a token passes; it is not used for tokens. The mechanism that keeps the rule is a small wrapper around the app, in the test only, that rewrites the `Authorization` header when one is present and passes every other request on untouched. The app itself is not changed.
3. **The pact holds no credential.** The consumer records an unsigned, token-shaped example with `match.regex` on the bearer shape; a working or never-expiring token in a pact is a leaked credential, and `match.str` accepts any string (run).

Each sign-in refusal the consumer handles is its own interaction with one Provider State ("no token → 401", "expired token → 401"); for the expired case the wrapper must sign an expired token, or the case passes for the wrong reason (run). Pact proves a check only where such an interaction exists: a provider that drops its audience check stays green unless a consumer recorded that refusal (run). The token rules themselves are `security-implementation`'s.

Limitation to state: the wrapper is test code standing in front of the app, so it must stay as small as the template's and must never be given the job of deciding who is allowed.

## Matchers decide what Pact notices

Observed (run): the provider began returning a status outside the old set. A pact that matched the field with `match.regex("free", regex="^(free|rented|closed)$")` failed verification. A pact that matched it with `match.str("free")` **passed**: a type matcher accepts any string. Match a field by value or pattern where the consumer's behaviour depends on the value, and by type where it only passes the value through.

## The broker

Self-hosted, open source (`pactfoundation/pact-broker`, pinned tag, its own PostgreSQL database), run like any other service of the product. Credentials come from the pipeline's secrets. **PactFlow**, the hosted commercial service, is refused without the product owner's approval, including its "bi-directional" mode, in which a provider's OpenAPI description is compared with consumer pacts without replaying them: that is a paid feature and gives up the replay.

Observed (run): `test` and `production` environments exist from the start, others are created with `pact broker create-environment`.

## Refused, by name

`--dry-run` or `--output json` on the deployment's `can-i-deploy`; `latest=True`; `set_error_on_empty_pact(enabled=False)`; `add_custom_header` for a token; a bypassed token check; publishing verification results from a developer machine; a Pact test under `tests/`, in `make ci` or on a pull-request trigger; the removed `pact.v2` interface and `pact-verifier` command; message pacts; PactFlow without approval; a hand-written pact file.
