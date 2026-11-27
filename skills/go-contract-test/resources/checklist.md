# Go Contract Test Checklist

Copy and tick before hand-off. A line that does not apply is struck through with the reason, never left blank.

## Boundaries
- [ ] Every HTTP API, every event and every direct service-to-service call is listed, each with its provider and consumers
- [ ] Every product size has all of it; lean has fewer boundaries, not fewer checks

## Every pull request: API description
- [ ] `check-openapi-breaking.sh` compares with the **deployed** description; a missing baseline fails; a first release is stated
- [ ] `--fail-on WARN`, the shipped severity file and the script's own empty config are in use; no `MISSING-VERSION-BUMP`, `|| true` or `continue-on-error`
- [ ] Every exception line carries the product owner's name and date; the run printed them
- [ ] Every removed endpoint has a retirement line with sunset date, no-caller evidence and sign-off
- [ ] Conformance drives the real router; `IncludeResponseStatus` set; every documented status exercised; no `default` response left
- [ ] Each consumer test runs the real client against a double checked against the provider's description, and asserts values
- [ ] Consumers tolerate unknown fields and unknown enum values

## Every pull request: events
- [ ] `modes.txt` gives each event the mode from the event design; none is `NONE`
- [ ] `check-event-compatibility.sh` ran both passes against the deployed schemas
- [ ] Producer test validates emitted bytes with `AssertFormat()` and the closed copy
- [ ] Consumer test reads a validated sample of every published version through the real handler
- [ ] No message pact exists

## Daily: Pact
- [ ] Every direct request/response call has a consumer Pact test and a provider verification, lean included
- [ ] Every Pact file starts with `//go:build pact`; nothing in `make ci` or a pull-request workflow runs Pact
- [ ] Selectors are main branch, matching branch, deployed or released; `FailIfNoPactsFound: true`; pending and work-in-progress on; no `SoftFail`, no `Latest: true`
- [ ] Each Provider State has a handler with the consumer's exact text; a `BeforeEach` guard makes an unmatched state fail
- [ ] State data is committed and scoped to the state, and removed afterwards
- [ ] Results are published only by the scheduled run
- [ ] The impact report is written from the broker's answers and filed for the product owner's approval
- [ ] The broker is self-hosted and open source; no paid service without approval
- [ ] An outside consumer has agreed in writing to run its half

## Deployment
- [ ] Each service's deployment runs `can-i-deploy` for the target environment and stops on exit 1; no `--dry-run`
- [ ] `record-deployment` runs after a successful deployment
- [ ] The answer says a pull request is not blocked by Pact and a break can surface in the next day's report

## Run
- [ ] `validate-go-contract-tests.sh` has no FAIL; each WARN judged
- [ ] Each new test was seen to fail with the code broken once
- [ ] Anything not run is called unverified
