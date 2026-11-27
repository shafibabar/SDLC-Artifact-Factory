# HTTP Contracts: the API-Description Checks

Self-contained. Read when setting up, changing or explaining the checks every pull request runs on a REST API: the breaking-change gate, provider conformance and consumer tests. Results marked "run" were observed with oasdiff 1.39.0 and kin-openapi v0.153.0 on OpenAPI 3.1 descriptions.

## Contents

The gate and its baseline; what the gate fails and passes; what oasdiff passes silently; exceptions; retiring an endpoint; conformance; consumers; what none of this proves.

## The gate and its baseline

`./scripts/check-openapi-breaking.sh` compares the description **that is deployed** with the one about to merge. Comparing with the main branch is not enough once services deploy on their own schedule: what breaks a caller is a difference from what is running. The deployed description is read from the commit the deployment recorded (`git show "$DEPLOYED_REF:api/openapi.yaml"`).

The script runs `oasdiff breaking --fail-on WARN --severity-levels <file> --config <empty file>`.

- **`--fail-on WARN`, not `ERR`.** With `ERR`, removing a request field or a query parameter passes (run). `api-contract-design` counts both as breaking for a caller that sends them.
- **The severity file** (`./resources/oasdiff-severity.txt`) raises two changes oasdiff rates as information to errors: `response-optional-property-removed` (an optional response field removed, or renamed, which oasdiff sees as removed plus added) and `response-non-success-status-removed` (a documented error response removed). An unknown id in the file, or a missing file, makes oasdiff exit 106.
- **The empty `--config`** stops a stray `.oasdiff.yaml` in the working folder from switching paths off. One with `match-path` made a breaking change exit 0 (run).
- A missing, empty or unreadable baseline is a failure (exit 2). The first release of an API is stated with `--first-release`; nothing is compared, and the report says so.

## What the gate fails and passes (run)

| Change | Gate |
|---|---|
| Remove a response field, required or optional; rename one | Fails |
| Change a response field's type; drop its format; make it nullable or optional | Fails |
| **Add an enum value to a response**; widen an enum to a free string | Fails |
| Remove a documented error status, a success status, a media type, a response header or a response schema | Fails |
| Remove an endpoint that is not deprecated, or before its sunset date | Fails |
| Remove an endpoint after its sunset date | oasdiff passes; the script fails without a retirement record |
| New required request field; optional request field made required; request enum value removed; request `maxLength` added; security added | Fails |
| Remove a request field or a query parameter | Fails (`WARN`) |
| Add an optional response field, an endpoint, a status, a `/v2/` path | Passes |
| Change only a description: the **meaning** or unit of a field | **Passes. Nothing here detects it** |

## What oasdiff passes silently (run)

- **No `--fail-on` flag: exit 0 with breaking changes listed.** The exit status is only meaningful with the flag.
- An empty baseline file, a baseline with `paths: {}`, a YAML file that is not an OpenAPI description: exit 0. The script refuses all three before calling oasdiff.
- `--fail-on MISSING-VERSION-BUMP`: a type change passes once `info.version` has a higher major number. Refused: a breaking change is a new `/v2/` path beside `/v1/`, never a change to `/v1/` in place (`api-contract-design`).
- A removal after the sunset date: no finding at all, in `breaking` and in `changelog`.

## Exceptions

The only way past the gate is a line in `api/contract-exceptions.txt`, approved by the product owner (`./templates/approval-records.md`). The script prints every line on every run and fails on a line without `approved-by:` and `approved-on:`. The most common case is a new enum value in a response: it fails by default, and each case is approved separately. Never `|| true`, `continue-on-error`, a lowered severity or a deleted baseline.

## Retiring an endpoint

`api-contract-design` allows removal only after the sunset date and when no caller remains. oasdiff checks the first and cannot know the second. The script therefore requires, for every removed endpoint, a line in `api/endpoint-retirements.txt` with the sunset date, the evidence that no caller remains, and the product owner's dated sign-off. It fails without one.

## Provider conformance

The harness in `./templates/http-contract-tests.md` sends requests through the **real router, middleware and handlers** and validates each real response against the description. Generated server stubs prove nothing here: they are produced from the description.

What kin-openapi's `ValidateResponse` passes unless the harness stops it:

| Silent pass | Harness |
|---|---|
| A status the description does not document, without `IncludeResponseStatus: true` (run) | Sets it |
| An undocumented status when a `default` response exists (read) | Requires an explicit entry; lists `default` as never exercised |
| A body where the documented response has no content or no schema (read) | Fails |
| A malformed `uuid` (run) | Registers the validator |
| A documented status no test ever produced | Fails the package after the run |
| Statuses 301, 304, 307, 308 and every `HEAD` request are not validated at all (read) | Status still has to be documented; the body is not checked. State it |
| A response field the description does not declare (run) | Not stopped: schemas stay open |

Fails correctly without help (run): wrong type, missing required field, value outside an enum, `null` where not allowed, wrong content type, empty body, missing required header, malformed `date-time`.

Behaviour the contract promises (repeat-request safety, rate limits, deprecation headers, each error branch's stored effect) is tested in `go-integration-test`. Conformance proves shape only.

## Consumers

- **A Go consumer** tests its real client against a double whose canned responses are validated against the provider's description. It asserts the **values** it reads: decoding a response that lacks a field gives a zero value and no error (run). It tolerates unknown fields (no `DisallowUnknownFields`), and treats an enum value it does not know as a safe default.
- A consumer declares only what it reads. A consumer that pins the whole response breaks on an additive change it never used.
- **The web app** builds its mocks from types generated from the same description; `react-component-testing` and `react-api-client` own that, and shell-to-remote contracts. Nothing for the web app was run for this skill.
- This replaces the older practice of committing expectation files pinned to a deployed version: the deployed-description diff answers "what is running" for the description, and Pact answers it for what callers rely on (`./references/pact.md`).

## What none of this proves

A description check proves the shape both sides agreed on paper. It does not prove a caller's real expectations: a consumer may rely on a value, or a combination, that the description allows to change. That is the distinction Cruz and Prescott draw between a schema test and a contract test, and it is why Pact runs on top of these checks.
