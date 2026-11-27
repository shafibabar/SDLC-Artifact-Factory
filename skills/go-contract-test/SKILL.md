---
name: go-contract-test
description: >
  Use when test-strategist, backend-engineer or anyone writes, reviews or fixes
  contract tests for Go services in the Implement or Quality phase: an OpenAPI
  breaking-change check with oasdiff against the deployed description, provider
  conformance with kin-openapi through the real router, consumer tests against
  a spec-validated double, event schema compatibility (compatibility modes,
  removed or renamed field, schema registry), Pact with pact-go (consumer test,
  provider verification, Provider States, pending and WIP pacts), a self-hosted
  Pact Broker, can-i-deploy and record-deployment, the daily Pact impact report,
  a new enum value in a response, removing a documented error response,
  retiring an endpoint after its sunset, buf breaking for gRPC, or a
  Consumer-Driven Contract with a partner. Produces go-contract-test.
version: 3.0.0
phase: implement
owner: test-strategist
created: 2026-06-25
tags: [implement, quality, go, contract-test, consumer-driven, openapi, oasdiff, event-schema, pact, pact-broker, can-i-deploy]
produces: go-contract-test
domain: testing
status: stable
related: [test-pyramid, go-integration-test, go-unit-test, test-fixture-design, mock-generation, api-contract-design, event-schema-design, grpc-contract-design, integration-design, context-map-patterns, go-openapi-codegen, go-makefile, ci-pipeline, cd-pipeline, react-component-testing, react-api-client]
sources:
  - research/testing/contract-testing-in-action-cruz-prescott.md
  - research/testing/pact-go-official-docs.md
  - research/testing/oasdiff-official-docs.md
  - research/testing/go-toolchain-official-docs.md
  - research/testing/testing-web-apis-winteringham.md
  - research/testing/github-actions-official-docs.md
  - research/software-architecture/building-microservices-newman.md
---

# Go Contract Test

## Purpose

This skill owns how Go services prove they still agree with each other: at the HTTP API, at each event, and at each direct call between two services. A contract test runs in each side's own pipeline with no live counterpart (Cruz and Prescott), so a break is found before deployment and not in production. `test-strategist` authors and applies it. It is the mechanism behind the Consumer-Driven Contract that `integration-design` and `context-map-patterns` require on every integration. What it does not own: behaviour the API promises (`go-integration-test`), this service's own logic (`go-unit-test`), the React app's mocks and shell-to-remote contracts (`react-component-testing`, `react-api-client`), which changes count as breaking (`api-contract-design`, `event-schema-design`, `grpc-contract-design`).

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off.

| # | Rule | Reason |
|---|---|---|
| C1 | **Every pull request compares the API description with the deployed one**: `oasdiff breaking --fail-on WARN`, plus the shipped severity file, which makes two more changes fail: an optional response field removed or renamed, and a documented error response removed | Without `--fail-on` oasdiff exits 0 on a breaking change; with `ERR` a removed request field passes; it rates the two raised changes as information only |
| C2 | **A new enum value in a response fails by default.** Each case is approved by the product owner and recorded in the exceptions file, which is printed on every run. **That file covers nothing else**: a removed or renamed response field, a removed error response and every other breaking change have no exception, whoever approves and whether or not a caller is known; they ship as a new major version beside the old one (`api-contract-design`) | A caller written against the old values may not handle the new one |
| C3 | **A removed endpoint needs a recorded product-owner sign-off stating the evidence that no caller remains**, even after its sunset date; the check fails without it | The tool knows the date, not who still calls |
| C4 | **Provider conformance runs the real router, middleware and handlers** against the description on every pull request, and fails on an undocumented status and on a documented status no test exercised | Generated stubs conform by construction; the library alone lets an undocumented status through |
| C5 | **Each consumer tests its real client against a double checked against the provider's description**, asserts the values it reads, and tolerates unknown fields | A missing field decodes to zero without an error (Tolerant Reader: Newman) |
| C6 | **Events: both the compatibility mode the event design declares and the add-only pass on closed copies** run on every pull request, against the deployed schemas. Mode `NONE` is refused | On an open schema the declared mode passes a removed or renamed field |
| C7 | **Every direct service-to-service request/response call is covered by Pact, at every product size, lean included**, on top of C1, C4 and C5, never in place of them. No trigger and no decision record is needed. A partner or another team is covered the same way and must agree to run its half | A description proves shape; Pact proves what a consumer relies on |
| C8 | **Pact runs once a day on a schedule and produces an impact report; it does not run on a build or pull request.** Pact tests carry `//go:build pact`, outside `make ci` | It needs a native library and a reachable broker |
| C9 | **A service's deployment runs `can-i-deploy` against the latest recorded Pact results and is refused when it shows a broken caller**; `record-deployment` follows a successful deployment | The daily run does not block a merge, so the deployment is the gate |
| C10 | **The Pact Broker is self-hosted and open source.** PactFlow or any paid service is refused without the product owner's approval | Frugality |
| C11 | **Events are not covered by Pact**: no message pact | Events keep the schema checks of C6 |

Every product size follows all eleven. **Lean** means fewer boundaries to cover, never a missing check: a lean product with two services that call each other runs Pact on a self-hosted broker.

## What every answer states

**Keep the answer as short as was asked.** State only the items below that the question touches, each **in words**, even when pointing at a script or template.

1. **What runs when.** Every pull request: the API-description gate, conformance, consumer tests, event checks. Daily: Pact and its report. At deployment: `can-i-deploy`.
2. **Whenever Pact is mentioned**: a pull request is **not** blocked by Pact; a breaking change can be merged and surfaces in the **next day's report**; the deployment check is what refuses it. A commit no Pact run has recorded cannot deploy until the run is started by hand for it.
3. **What a tool passes silently, and whether its exit status is enough**: oasdiff without `--fail-on`, an empty baseline, a removal after sunset; a Pact verification that finds no pact; a failing pending pact (provider run exits 0); `can-i-deploy --dry-run`; a registry's declared mode on a removed field.
4. **What is refused or replaced, by name, with the reason** and the compliant version: Pact "only when teams split", Pact on every pull request, a message pact, PactFlow, `Latest: true`, `MISSING-VERSION-BUMP`, `|| true`, a hard-coded `BACKWARD`, a hand-written compatibility checker.
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

1. Read the API contract, the event design with each event's compatibility mode, the integration design and its consumer list, the Makefile and the pipelines. List every boundary with its provider and consumers.
2. For each REST API, set up the gate: copy `./scripts/check-openapi-breaking.sh`, `./resources/oasdiff-severity.txt` and the two record files from `./templates/approval-records.md`. Read `./references/http-contracts.md` before changing a flag or explaining a result.
3. Write the failing provider conformance test and consumer tests first, from `./templates/http-contract-tests.md`.
4. For each event, write the producer and consumer tests from `./templates/event-contract-tests.md` and set up `./scripts/check-event-compatibility.sh` with the mode from the event design. Read `./references/event-contracts.md` first.
5. For each direct request/response call, write the Pact consumer test and the provider verification from `./templates/pact-tests.md`. Read `./references/pact.md` first. For a gRPC API read `./references/grpc-contracts.md`.
6. Wire the pull-request gates, the daily Pact run, the make targets and the deployment check from `./templates/workflows.md`.
7. See each test fail for the expected reason: break the provider once, break the consumer once, remove a field from a schema, publish an expectation the provider does not meet.
8. Run `./scripts/validate-go-contract-tests.sh <paths>` over the tests, workflows and Makefile, then the tests and both gate scripts; fix and repeat until clean.
9. After a Pact run, write the report with `./scripts/write-pact-impact-report.sh` (format: `./templates/pact-impact-report.md`) and file it under `artifacts/<product>/quality/test-reports/` for the product owner's approval.
10. Tick `./resources/checklist.md` and answer with the statements above.

Worked and run: `./examples/01-lean-dance-studio.md` (two services, every HTTP check, Pact on a self-hosted broker at lean size), `./examples/02-standard-pet-kennel.md` (events: a removal the declared mode lets through), `./examples/03-enterprise-ferry-ticketing.md` (a partner on Pact, two environments, an approved enum exception, a retired endpoint, gRPC).

## Gotchas

- **"Pact is overkill for a small product; start with schema checks and add Pact when teams split."** *Reason:* that was the old rule and it is reversed. *Instead:* Pact for every direct call at every size, on top of the description checks.
- **Putting Pact in the pull-request workflow to "catch it earlier".** *Reason:* every build would need the native library and the broker. *Instead:* daily run, and say that the deployment check is the gate.
- **Reading the provider's green Pact run as "no consumer is broken".** *Reason:* a failing pending or work-in-progress pact exits 0. *Instead:* build the report from `can-i-deploy` answers.
- **`oasdiff breaking` with no `--fail-on`, or `--fail-on ERR`.** *Reason:* with no flag it exits 0 even on a breaking change, so the check would never fail; `ERR` passes a removed request field. *Instead:* `--fail-on WARN` through the gate script. Say the "would never fail" consequence in words.
- **Treating "the sunset date has passed" as permission to remove.** *Reason:* oasdiff then reports nothing at all. *Instead:* the retirement record with evidence and sign-off.
- **Adding an enum value as an "additive" change.** *Reason:* it fails by default. *Instead:* the product owner approves that case; one exception line.
- **Offering an exception line for a removed response field or a removed error response ("it was optional", "no caller handles it").** *Reason:* the exceptions file is for a new enum value only, and the gate script refuses any other line. *Instead:* say it fails and is not let through; keep it, or ship a new major version beside the old one.
- **Checking events under the declared mode only.** *Reason:* `BACKWARD` and `FULL` pass a removed or renamed optional field on an open schema. *Instead:* both passes.
- **Closing the published schema (`additionalProperties: false`) to make the registry stricter.** *Reason:* the event design keeps schemas open for tolerant readers. *Instead:* the gate closes copies.
- **A message pact for an event.** *Reason:* events are outside Pact here. *Instead:* the schema checks.
- **A Provider State name that matches no handler.** *Reason:* pact-go raises no error; the interaction runs without setup and may pass. *Instead:* the `BeforeEach` guard in the template.
- **Seeding Provider State data inside a rollback transaction.** *Reason:* the verifier's request cannot see it. *Instead:* committed rows scoped to the state.
- **`Like(...)` on a field whose value the consumer branches on.** *Reason:* a type matcher passed a status outside the old set. *Instead:* match the value or a pattern.
- **`FailIfNoPactsFound` left false.** *Reason:* zero pacts verified is a pass. *Instead:* set it.
- **Deploying a commit merged after the last daily run.** *Reason:* the broker has no result for it and refuses. *Instead:* start the Pact workflow by hand for that commit.

## Output

| File | When to open it |
|---|---|
| `./references/http-contracts.md` | The API gate, conformance, consumers; what oasdiff and kin-openapi pass |
| `./references/event-contracts.md` | Event checks; modes; what no check detects |
| `./references/pact.md` | Pact flow, daily run, deployment check, selectors, pending, Provider States, broker |
| `./references/grpc-contracts.md` | An internal gRPC API |
| `./templates/http-contract-tests.md` | Writing conformance and consumer tests |
| `./templates/event-contract-tests.md` | Writing producer and consumer event tests |
| `./templates/pact-tests.md` | Writing Pact consumer and provider tests |
| `./templates/workflows.md` | Pull-request gates, the daily Pact workflow, make targets, deployment steps |
| `./templates/approval-records.md` | The exceptions and retirements files |
| `./templates/pact-impact-report.md` | The daily report's format |
| `./scripts/check-openapi-breaking.sh` | API gate, every pull request |
| `./scripts/check-event-compatibility.sh` | Event gate, every pull request |
| `./scripts/write-pact-impact-report.sh` | After each Pact run |
| `./scripts/validate-go-contract-tests.sh` | Before hand-off, after every edit |
| `./resources/oasdiff-severity.txt` | The two changes raised to errors; copied beside the description |
| `./resources/checklist.md` | Before answering |

Tests sit beside the code: `<implementation>_contract_test.go` (no tag, in `make ci`) and `*_pact_test.go` (`//go:build pact`, tests named `TestPact...`). The harness is `internal/test/contract/` (test support only). Schemas are `schemas/events/<context>/<event>/<n>.json`; the report is `artifacts/<product>/quality/test-reports/pact-impact-<date>.md`.
