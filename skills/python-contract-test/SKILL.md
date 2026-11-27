---
name: python-contract-test
description: >
  Use when test-strategist, backend-engineer or anyone writes, reviews or fixes
  contract tests for Python services (FastAPI, httpx, pytest) in the Implement
  or Quality phase: an OpenAPI breaking-change check with oasdiff against the
  deployed description, provider conformance with openapi-core through the real
  FastAPI app, consumer tests of the real httpx client against a respx double
  checked against the provider's description, event schema compatibility
  (compatibility modes, removed or renamed field, schema registry, jsonschema
  format checking), Pact with pact-python 4 (consumer test, provider
  verification, Provider States, pending and WIP pacts, a provider that checks
  a token), a self-hosted Pact Broker, can-i-deploy and record-deployment, the
  daily Pact impact report, a new enum value in a response, removing a
  documented error response, retiring an endpoint after its sunset, buf
  breaking for gRPC, or a Consumer-Driven Contract with a partner. Produces
  python-contract-test.
version: 2.0.0
phase: implement
owner: test-strategist
created: 2026-07-31
tags: [implement, quality, python, contract-test, consumer-driven, openapi, oasdiff, openapi-core, respx, event-schema, pact, pact-python, pact-broker, can-i-deploy]
produces: python-contract-test
domain: testing
status: stable
related: [test-pyramid, python-integration-test, python-unit-test, test-fixture-design, mock-generation, api-contract-design, event-schema-design, grpc-contract-design, integration-design, context-map-patterns, python-openapi-codegen, python-makefile, python-project-structure, security-implementation, ci-pipeline, cd-pipeline, go-contract-test, react-component-testing, react-api-client]
sources:
  - research/testing/contract-testing-in-action-cruz-prescott.md
  - research/testing/pact-python-official-docs.md
  - research/testing/openapi-conformance-python-official-docs.md
  - research/testing/respx-httpx-official-docs.md
  - research/testing/oasdiff-official-docs.md
  - research/testing/jsonschema-official-docs.md
  - research/testing/pytest-official-docs.md
  - research/testing/python-testing-with-pytest-okken.md
  - research/testing/testing-web-apis-winteringham.md
  - research/testing/github-actions-official-docs.md
  - research/software-architecture/python-backend-development-halstead.md
  - research/software-architecture/building-microservices-newman.md
---

# Python Contract Test

## Purpose

This skill owns how Python services prove they still agree with each other: at the HTTP API, at each event, and at each direct call between two services. A contract test runs in each side's own pipeline with no live counterpart (Cruz and Prescott), so a break is found before deployment and not in production. `test-strategist` authors and applies it, under the same rules as `go-contract-test`; only the tools differ. It is the mechanism behind the Consumer-Driven Contract that `integration-design` and `context-map-patterns` require on every integration. What it does not own: behaviour the API promises (`python-integration-test`), this service's own logic (`python-unit-test`), keeping FastAPI's derived description in step with the authored one (`python-openapi-codegen`), the React app's mocks (`react-component-testing`, `react-api-client`), which changes count as breaking (`api-contract-design`, `event-schema-design`, `grpc-contract-design`).

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off.

| # | Rule | Reason |
|---|---|---|
| C1 | **Every pull request compares the API description with the deployed one**: `oasdiff breaking --fail-on WARN`, plus the shipped severity file, which makes two more changes fail: an optional response field removed or renamed, and a documented error response removed | Without `--fail-on` oasdiff exits 0 on a breaking change; with `ERR` a removed request field passes; it rates the two raised changes as information only |
| C2 | **A new enum value in a response fails by default.** Each case is approved by the product owner and recorded in the exceptions file, which is printed on every run. **That file covers nothing else**: a removed or renamed response field, a removed error response and every other breaking change have no exception, whoever approves and whether or not a caller is known; they ship as a new major version beside the old one (`api-contract-design`) | A caller written against the old values may not handle the new one |
| C3 | **A removed endpoint needs a recorded product-owner sign-off stating the evidence that no caller remains**, even after its sunset date; the check fails without it | The tool knows the date, not who still calls |
| C4 | **Provider conformance runs the real FastAPI app, with its real routes, middleware and handlers, against the authored description file** on every pull request, and fails on an undocumented status and on a documented status no test exercised; `format` is checked | The description the app serves is derived from the code and agrees with it by construction; a validator alone lets an undocumented status through once a `default` exists |
| C5 | **Each consumer tests its real client against a double checked against the provider's description**, asserts the values it reads, and tolerates unknown fields. It never imports the provider's app | `body.get(...)` or a model default turns a missing field into `None` without an error (Tolerant Reader: Newman) |
| C6 | **Events: both the compatibility mode the event design declares and the add-only pass on closed copies** run on every pull request, against the deployed schemas. Mode `NONE` is refused. Emitted bytes are validated with format checking on | On an open schema the declared mode passes a removed or renamed field; jsonschema ignores `format` unless told otherwise |
| C7 | **Every direct service-to-service request/response call is covered by Pact, at every product size, lean included**, on top of C1, C4 and C5, never in place of them. No trigger and no decision record is needed. A partner or another team is covered the same way and must agree to run its half | A description proves shape; Pact proves what a consumer relies on |
| C8 | **Pact runs once a day on a schedule and produces an impact report; it does not run on a build or pull request.** Pact tests live in `pact_tests/`, outside `tests/` and so outside `make ci`, and carry the registered `pact` marker; a run that collects no test fails | It needs the broker, which `make ci` must not need |
| C9 | **A service's deployment runs `can-i-deploy` against the latest recorded Pact results and is refused when it shows a broken caller**; `record-deployment` follows a successful deployment | The daily run does not block a merge, so the deployment is the gate |
| C10 | **The Pact Broker is self-hosted and open source.** PactFlow or any paid service is refused without the product owner's approval | Frugality |
| C11 | **Events are not covered by Pact**: no message pact | Events keep the schema checks of C6 |

Every product size follows all eleven. **Lean** means fewer boundaries to cover, never a missing check: a lean product with two services that call each other runs Pact on a self-hosted broker.

## What every answer states

**Keep the answer as short as was asked.** State only the items below that the question touches, each **in words**, even when pointing at a script or template.

1. **What runs when.** Every pull request: the API-description gate, conformance, consumer tests, event checks. Daily: Pact and its report. At deployment: `can-i-deploy`.
2. **Whenever Pact is mentioned**: a pull request is **not** blocked by Pact; a breaking change can be merged and surfaces in the **next day's report**; the deployment check is what refuses it. A commit no Pact run has recorded cannot deploy until the run is started by hand for it.
3. **What a tool passes silently, and whether its exit status is enough**: oasdiff without `--fail-on`, an empty baseline, a removal after sunset; an undocumented status under a `default` response; jsonschema without a format checker, or with one and no `date-time` validator installed; a failing pending pact (provider run exits 0); `can-i-deploy` with `--dry-run` or `--output json`; a registry's declared mode on a removed field.
4. **What is refused or replaced, by name, with the reason** and the compliant version: Pact "only when teams split", Pact on every pull request, a message pact, PactFlow, `latest=True`, `add_custom_header` for a token, `MISSING-VERSION-BUMP`, `|| true`, a hard-coded `BACKWARD`, a hand-written compatibility checker, a consumer test that imports the provider app, a `contract` marker nothing carries.
5. **What stays the default when one case differs**, in the same breath: an approved enum value is one line for one change, and every other enum addition still fails; a retirement record covers one endpoint.
6. **What each check does not prove**: a change of meaning or unit passes every description and schema check; Pact sees only consumers that publish a pact, and only what their matchers pin.
7. **How the check fails the pipeline**: the script's exit status, the test that goes red, or the refused deployment.
8. **Decisions for the product owner**, only where they arise: each exception line, each retirement sign-off, each daily impact report, a paid tool, an outside party that will not run Pact.
9. **One line on what was run.** Code or a workflow not executed is called unverified.

## Which check for which boundary

| Boundary | Every pull request | Daily |
|---|---|---|
| REST API the service provides | Gate against the deployed description (C1 to C3); conformance (C4) | Provider verification of each consumer's pact |
| REST API the service calls | Consumer test against a checked double (C5) | Consumer Pact test, pact published |
| Event produced or consumed | Producer test, consumer test, both registry passes (C6) | Nothing: no Pact |
| Internal gRPC API | `buf breaking`, category `FILE`, against the deployed commit | The Pact rule applies; see the reference for what is unverified |
| Web app calling the API | Owned by `react-component-testing` and `react-api-client` | |

## Procedure

1. Read the API contract, the event design with each event's compatibility mode, the integration design and its consumer list, `pyproject.toml`, the Makefile and the pipelines. List every boundary with its provider and consumers.
2. For each REST API, set up the gate: copy `./scripts/check-openapi-breaking.sh`, `./resources/oasdiff-severity.txt` and the two record files from `./templates/approval-records.md`. Read `./references/http-contracts.md` before changing a flag or explaining a result.
3. Write the failing provider conformance test and consumer tests first, from `./templates/http-contract-tests.md`, in `tests/contract/`.
4. For each event, write the producer and consumer tests from `./templates/event-contract-tests.md` and set up `./scripts/check-event-compatibility.sh` with the mode from the event design. Read `./references/event-contracts.md` first.
5. For each direct request/response call, write the Pact consumer test and the provider verification from `./templates/pact-tests.md`, in `pact_tests/`, and register the `pact` marker. Read `./references/pact.md` first. For a gRPC API read `./references/grpc-contracts.md`.
6. Add the make targets, the pull-request gates, the daily Pact run and the deployment check from `./templates/workflows.md`.
7. See each test fail for the expected reason: break the provider once, break the consumer once, remove a field from a schema, publish an expectation the provider does not meet.
8. Run `./scripts/validate-python-contract-tests.sh <project>` over the tests, workflows, Makefile and `pyproject.toml`, then the tests and both gate scripts; fix and repeat until clean.
9. After a Pact run, write the report with `./scripts/write-pact-impact-report.sh` (format: `./templates/pact-impact-report.md`) and file it under `artifacts/<product>/quality/test-reports/` for the product owner's approval.
10. Tick `./resources/checklist.md` and answer with the statements above.

Worked and run: `./examples/01-lean-garden-plots.md` (two services, every HTTP check, Pact on a self-hosted broker at lean size), `./examples/02-standard-car-share.md` (events: a removal the declared mode lets through), `./examples/03-enterprise-hotel-channel.md` (a partner on Pact, two environments, an approved enum exception, a retired endpoint, gRPC).

## Gotchas

- **"Pact is overkill for a small product; start with schema checks and add Pact when teams split."** *Reason:* that was the old rule and it is reversed. *Instead:* Pact for every direct call at every size, on top of the description checks.
- **Putting Pact in the pull-request workflow to "catch it earlier", or its tests under `tests/`.** *Reason:* every build would need the broker, and `make ci` collects everything under `tests/`. *Instead:* `pact_tests/`, daily run, and say that the deployment check is the gate.
- **Selecting contract tests with `-m contract`.** *Reason:* no test carried that marker, so the job ran nothing (pytest exit 5). *Instead:* contract tests are plain tests in `tests/contract/`, run by `make ci`; only Pact has a marker, added by `pact_tests/conftest.py` and registered in `pyproject.toml`.
- **A "consumer" test that drives the provider's FastAPI app in-process.** *Reason:* it imports the provider, cannot run in the consumer's repository, and tests the provider. *Instead:* the real client against a double checked against the provider's description.
- **Checking the app against the description it serves (`/openapi.json`, schemathesis `from_asgi`).** *Reason:* that description is derived from the code. *Instead:* load the authored file.
- **Passing the token check with `add_custom_header`, or by bypassing the middleware.** *Reason:* the option also adds the header where the consumer recorded none, and a bypass passes everything; both let a consumer that sends no token through. *Instead:* keep the real middleware; a wrapper around the app, in the test only, swaps the recorded example token for one signed with a key made for the run, and never adds a header. The pact holds no working token.
- **Reading the provider's green Pact run as "no consumer is broken".** *Reason:* a failing pending or work-in-progress pact exits 0. *Instead:* build the report from the broker's answers.
- **Using `can-i-deploy --output json` as the deployment check.** *Reason:* with it the command exits 0 on a refusal. *Instead:* the plain command at deployment; the JSON form only feeds the report script.
- **`oasdiff breaking` with no `--fail-on`, or `--fail-on ERR`.** *Reason:* with no flag it exits 0 even on a breaking change, so the check would never fail; `ERR` passes a removed request field. *Instead:* `--fail-on WARN` through the gate script. Say the "would never fail" consequence in words.
- **Taking the previous commit, `HEAD~1` or the main branch as the baseline ("it is the same thing").** *Reason:* a break introduced an earlier commit ago, or merged but not yet deployed, is already in that baseline and passes. *Instead:* refuse it and compare with the description at the commit that is deployed; never accept it "provided it matches what is deployed".
- **Treating "the sunset date has passed" as permission to remove.** *Reason:* oasdiff then reports nothing at all. *Instead:* the retirement record with evidence and sign-off.
- **Adding an enum value as an "additive" change.** *Reason:* it fails by default. *Instead:* the product owner approves that case; one exception line.
- **Offering an exception line for a removed response field or a removed error response ("it was optional", "no caller handles it").** *Reason:* the exceptions file is for a new enum value only, and the gate script refuses any other line. *Instead:* say it fails and is not let through; keep it, or ship a new major version beside the old one.
- **Checking events under the declared mode only, or with a hand-written checker.** *Reason:* `BACKWARD` and `FULL` pass a removed or renamed optional field on an open schema. *Instead:* both passes of the gate script.
- **Closing the published schema (`additionalProperties: false`) to make the registry stricter.** *Reason:* the event design keeps schemas open for tolerant readers. *Instead:* the gate closes copies.
- **`Draft202012Validator(schema)` as the event check.** *Reason:* `format` is ignored without a format checker, and `date-time` is still ignored until `rfc3339-validator` is installed. *Instead:* the helper, which fails on a format nothing would check.
- **A message pact for an event.** *Reason:* events are outside Pact here. *Instead:* the schema checks.
- **A Provider State name that matches no handler.** *Reason:* without a guard the interaction runs with no setup and may pass. *Instead:* the unready store and teardown reset in the template.
- **Seeding Provider State data inside a rollback transaction.** *Reason:* the verifier's request cannot see it. *Instead:* committed rows scoped to the state.
- **`match.str(...)` on a field whose value the consumer branches on.** *Reason:* a type matcher passed a status outside the old set. *Instead:* match the value or a pattern.
- **Code written for `pact.v2`, `Consumer`/`Provider` or `pact-verifier`.** *Reason:* pact-python 4 removed them. *Instead:* `Pact`, `Verifier` and the `pact broker` command.
- **Deploying a commit merged after the last daily run.** *Reason:* the broker has no result for it and refuses. *Instead:* start the Pact workflow by hand for that commit.

## Output

| File | When to open it |
|---|---|
| `./references/http-contracts.md` | The API gate, conformance, consumers; what oasdiff and openapi-core pass |
| `./references/event-contracts.md` | Event checks; modes; what no check detects |
| `./references/pact.md` | Pact flow, daily run, deployment check, selectors, pending, Provider States, a provider that checks a token, broker |
| `./references/grpc-contracts.md` | An internal gRPC API |
| `./templates/http-contract-tests.md` | Writing conformance and consumer tests |
| `./templates/event-contract-tests.md` | Writing producer and consumer event tests |
| `./templates/pact-tests.md` | Writing Pact consumer and provider tests, including a provider behind token-checking middleware |
| `./templates/workflows.md` | Make targets, pull-request gates, the daily Pact workflow, deployment steps |
| `./templates/approval-records.md` | The exceptions and retirements files |
| `./templates/pact-impact-report.md` | The daily report's format |
| `./scripts/check-openapi-breaking.sh` | API gate, every pull request |
| `./scripts/check-event-compatibility.sh` | Event gate, every pull request |
| `./scripts/write-pact-impact-report.sh` | After each Pact run |
| `./scripts/validate-python-contract-tests.sh` | Before hand-off, after every edit |
| `./resources/oasdiff-severity.txt` | The two changes raised to errors; copied beside the description |
| `./resources/checklist.md` | Before answering |

Contract tests are `tests/contract/test_<name>.py` (no marker, in `make ci`, counted by the coverage gate) with their support files `openapi_check.py`, `double.py`, `events.py` and `tokens.py` beside them. Pact tests are `pact_tests/consumer/` and `pact_tests/provider/` with `pact_tests/conftest.py`. The description is `api/openapi.yaml`; schemas are `schemas/events/<context>/<event>/<n>.json`; the report is `artifacts/<product>/quality/test-reports/pact-impact-<date>.md`.
