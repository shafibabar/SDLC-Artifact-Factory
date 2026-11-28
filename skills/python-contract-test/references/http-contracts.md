# HTTP Contracts: the API-Description Checks

Self-contained. Read when setting up, changing or explaining the checks every pull request runs on a REST API: the breaking-change gate, provider conformance and consumer tests. Results marked "run" were observed with oasdiff 1.39.0, openapi-core 0.23.1, httpx 0.29.0, respx 0.23.1 and schemathesis 4.34.4 on OpenAPI 3.1 descriptions.

## Contents

The gate and its baseline; what the gate fails and passes; what oasdiff passes silently; exceptions; retiring an endpoint; the two descriptions of a FastAPI service; conformance; consumers; what none of this proves.

## The gate and its baseline

`../scripts/check-openapi-breaking.sh` compares the description **that is deployed** with the one about to merge. Comparing with the main branch is not enough once services deploy on their own schedule: what breaks a caller is a difference from what is running. The deployed description is read from the commit the deployment recorded (`git show "$DEPLOYED_REF:api/openapi.yaml"`).

The script runs `oasdiff breaking --fail-on WARN --severity-levels <file> --config <empty file>`. oasdiff reads descriptions, not code, so the script is the same program `go-contract-test` ships; each skill owns its copy and a test keeps the two identical.

- **`--fail-on WARN`, not `ERR`.** With `ERR`, removing a request field or a query parameter passes (run). `api-contract-design` counts both as breaking for a caller that sends them.
- **The severity file** (`../resources/oasdiff-severity.txt`) raises two changes oasdiff rates as information to errors: `response-optional-property-removed` (an optional response field removed, or renamed, which oasdiff sees as removed plus added) and `response-non-success-status-removed` (a documented error response removed). A missing file makes oasdiff exit 106 (run).
- **The empty `--config`** stops a stray `.oasdiff.yaml` in the working folder from switching paths off. One with `match-path` made a breaking change exit 0 (run).
- A missing, empty or unreadable baseline is a failure (exit 2). The first release of an API is stated with `--first-release`; nothing is compared, and the report says so.

## What the gate fails and passes (run)

| Change | Gate |
|---|---|
| Remove a response field, required or optional; rename one | Fails |
| Change a response field's type | Fails |
| **Add an enum value to a response** | Fails |
| Remove a documented error status | Fails |
| Remove an endpoint that is not deprecated | Fails |
| Remove an endpoint after its sunset date | oasdiff passes; the script fails without a retirement record |
| Make an optional request field required | Fails |
| Remove a request field or a query parameter | Fails (`WARN`) |
| Add an optional response field, a `/v2/` path beside `/v1/` | Passes |
| Change only a description: the **meaning** or unit of a field | **Passes. Nothing here detects it** |

## What oasdiff passes silently (run)

- **No `--fail-on` flag: exit 0 with breaking changes listed.** The exit status is only meaningful with the flag.
- An empty baseline file, a baseline with `paths: {}`, a YAML file that is not an OpenAPI description: exit 0. The script refuses all three before calling oasdiff.
- `--fail-on MISSING-VERSION-BUMP`: a renamed response field passes once `info.version` has a higher major number. Refused: a breaking change is a new `/v2/` path beside `/v1/`, never a change to `/v1/` in place (`api-contract-design`).
- A removal after the sunset date: no finding at all.

## Exceptions

One change, and only one, can pass the gate by approval: **a new enum value in a response**. It fails by default; the product owner approves each case separately, and the approval is a line in `api/contract-exceptions.txt` (`../templates/approval-records.md`). The script prints every line on every run, fails on a line without `approved-by:` and `approved-on:`, and fails on a line that is about anything else.

Every other finding has **no exception**, whoever approves it and whether or not a caller is known to depend on it: a removed or renamed response field (optional included), a removed documented error response, a type change, a removed endpoint before its sunset. These are breaking changes, and `api-contract-design` gives the only route: a new major version run beside the old one, the old one never changed in place. Say "this fails and is not let through", never "record an exception". Never `|| true`, `continue-on-error`, a lowered severity or a deleted baseline.

## Retiring an endpoint

`api-contract-design` allows removal only after the sunset date and when no caller remains. oasdiff checks the first and cannot know the second. The script therefore requires, for every removed endpoint, a line in `api/endpoint-retirements.txt` with the sunset date, the evidence that no caller remains, and the product owner's dated sign-off. It fails without one.

## The two descriptions of a FastAPI service

A FastAPI service has two descriptions: the one **authored** and approved first (`api/openapi.yaml`, `api-contract-design`), and the one the app **derives** from its code and serves at `/openapi.json` (`python-openapi-codegen`). Every check in this skill reads the authored file. The derived one describes whatever the code does: in the run for this skill it documented `200` and `422` for an operation whose authored description documents `200`, `400`, `404` and `500`. A conformance tool pointed at the served description therefore proves the code agrees with itself.

## Provider conformance

The harness in `../templates/http-contract-tests.md` sends requests through the **real app with its real routes, middleware and handlers**, in-process, and validates each real response against the authored description with openapi-core. Pydantic models and generated examples prove nothing here: they are the code describing itself.

What openapi-core's response validation passes unless the harness stops it:

| Silent pass | Harness |
|---|---|
| An undocumented status when a `default` response or a range such as `4XX` exists (run) | Requires the exact status; lists `default` as never exercised |
| A body where the documented response has no content (run) | Fails |
| A documented status no test ever produced | A test compares the case table with the description and fails |
| A response field the description does not declare (run) | Not stopped: schemas stay open |

Fails correctly without help (run): an undocumented status with no `default`, wrong type, missing required field, value outside an enum, `null` where not allowed, wrong content type, empty body, a malformed `uuid` or `date-time`, an unknown path or method.

openapi-core is the validator this harness uses; another library that fails the same cases against the authored file satisfies the rule. Schemathesis, the tool Halstead names for Python services, generates requests and can run on top (`from_path` on the authored file with an in-process session: run); it does not show that each documented status was exercised, and its `from_asgi` loader reads the served description.

Behaviour the contract promises (repeat-request safety, rate limits, deprecation headers, each error branch's stored effect) is tested in `python-integration-test`: every documented error branch deserves a test of what happens, not only of its shape (Winteringham). Conformance proves shape only.

## Consumers

- **A Python consumer** tests its real client against a double whose canned responses are validated against the provider's description. It asserts the **values** it reads: `body.get("field")`, or a model with a default, turns a missing or misspelt field into `None` with no error (run). It tolerates unknown fields (no `extra="forbid"`), and treats an enum value it does not know as a safe default: Newman's Tolerant Reader.
- **The consumer's test never imports the provider's app.** A test that drives the provider in-process (`ASGITransport(app=provider_app)`) cannot run in the consumer's repository and is a provider test under another name.
- The double is a `respx.Router` handed to the client as `httpx.MockTransport(router.async_handler)`. Run with respx 0.23.1 and httpx 0.29.0: a request no route matches raises; **a route never called fails only when `assert_all_called()` is called**, and the bare `respx_mock` fixture does not fail on it either. httpx no longer accepts `app=` on a client (run: `TypeError`).
- A consumer declares only what it reads. A consumer that pins the whole response breaks on an additive change it never used.
- **The web app** builds its mocks from types generated from the same description; `react-component-testing` and `react-api-client` own that, and shell-to-remote contracts. Nothing for the web app was run for this skill.
- This replaces the older practice of committing expectation files pinned to a deployed version: the deployed-description diff answers "what is running" for the description, and Pact answers it for what callers rely on (`./pact.md`).

## What none of this proves

A description check proves the shape both sides agreed on paper. It does not prove a caller's real expectations: a consumer may rely on a value, or a combination, that the description allows to change. That is the distinction Cruz and Prescott draw between a schema test and a contract test, and it is why Pact runs on top of these checks. In the lean example a provider that began returning ids in upper case passed the gate, conformance and the consumer test, and failed Pact.
