# Python Contract Test Checklist

Copy and tick before hand-off. A line that does not apply is struck through with the reason, never left blank.

## Boundaries
- [ ] Every HTTP API, every event and every direct service-to-service call is listed, each with its provider and consumers
- [ ] Every product size has all of it; lean has fewer boundaries, not fewer checks

## Every pull request: API description
- [ ] `check-openapi-breaking.sh` compares with the **deployed** description; a missing baseline fails; a first release is stated
- [ ] `--fail-on WARN`, the shipped severity file and the script's own empty config are in use; no `MISSING-VERSION-BUMP`, `|| true` or `continue-on-error`
- [ ] Every exception line is a new enum value in a response and carries the product owner's name and date; the run printed them. No exception was offered for a removed field or a removed error response
- [ ] Every removed endpoint has a retirement line with sunset date, no-caller evidence and sign-off
- [ ] Conformance drives the real app from its own factory, middleware included, and reads the **authored** `api/openapi.yaml`, never `/openapi.json`
- [ ] Every documented status has a case; the completeness test is present; no `default` or range response is left; no case is skipped
- [ ] Each consumer test runs the real client against a double checked against the provider's description, asserts values, calls `assert_all_called()`, and imports nothing of the provider's
- [ ] Consumers tolerate unknown fields and unknown enum values

## Every pull request: events
- [ ] `modes.txt` gives each event the mode from the event design; none is `NONE`
- [ ] `check-event-compatibility.sh` ran both passes against the deployed schemas
- [ ] Producer test validates the emitted bytes with a format checker and the closed copy; `rfc3339-validator` is installed
- [ ] Consumer test reads a validated sample of every published version through the real handler
- [ ] No message pact and no hand-written compatibility checker exists

## Where the tests live
- [ ] Contract tests are in `tests/contract/`, carry no marker and run in `make ci`; nothing selects them with `-m contract`
- [ ] Pact tests are in `pact_tests/`, outside `tests/`; `pact_tests/conftest.py` marks them; the `pact` marker is registered in `pyproject.toml`; `addopts` selects nothing
- [ ] The Pact make targets were seen to run tests (a run that collects none exits 5)

## Daily: Pact
- [ ] Every direct request/response call has a consumer Pact test and a provider verification, lean included
- [ ] Where the provider checks a token: the real middleware is in the app under test; a wrapper replaces the recorded token with one signed by a key made for the run and never adds a header; `add_custom_header` is not used for it; the pact holds an unsigned example; "no token" and "expired token" refusals are their own interactions
- [ ] Nothing in `make ci` or a pull-request workflow runs Pact
- [ ] Selectors are main branch, matching branch, deployed or released; `set_error_on_empty_pact()`; pending and work-in-progress on; no `latest=True`
- [ ] Each Provider State has a handler with the consumer's exact text; the store starts unready and teardown resets it, so an unmatched state fails
- [ ] State data is committed and scoped to the state, and removed afterwards
- [ ] Results are published only by the scheduled run
- [ ] The impact report is written from the broker's answers and filed for the product owner's approval
- [ ] The broker is self-hosted and open source; no paid service without approval
- [ ] An outside consumer has agreed in writing to run its half

## Deployment
- [ ] Each service's deployment runs `can-i-deploy` for the target environment and stops on exit 1; no `--dry-run` and no `--output json`
- [ ] `record-deployment` runs after a successful deployment
- [ ] The answer says a pull request is not blocked by Pact and a break can surface in the next day's report

## Run
- [ ] `validate-python-contract-tests.sh` has no FAIL; each WARN judged
- [ ] Each new test was seen to fail with the code broken once
- [ ] Anything not run is called unverified
