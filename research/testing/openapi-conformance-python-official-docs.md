# openapi-core and Schemathesis Official Documentation
**Authors:** The python-openapi project (python-openapi/openapi-core); the Schemathesis project (schemathesis/schemathesis)
**Domain:** Testing (contract conformance, OpenAPI)

Accessed 2026-11-28. openapi-core latest 0.23.1, 2026-04-02, BSD-3-Clause, Python >=3.10,<4 (https://pypi.org/pypi/openapi-core/0.23.1/json); docs read at tag `0.23.1`: O = https://raw.githubusercontent.com/python-openapi/openapi-core/0.23.1. Schemathesis latest 4.34.4, 2026-11-27, MIT, Python >=3.11 (https://pypi.org/pypi/schemathesis/4.34.4/json); docs read at tag `v4.34.4`: S = https://raw.githubusercontent.com/schemathesis/schemathesis/v4.34.4.

## Core Concepts

**openapi-core**

- Supports OpenAPI 3.0, 3.1 and 3.2; validates and unmarshals request and response data. (O/README.md)
- Load: `from openapi_core import OpenAPI`; `openapi = OpenAPI.from_file_path("openapi.json")`. The description itself is validated on load unless `Config(spec_validator_cls=None)`. (O/README.md, O/docs/configuration.md)
- Response check: `openapi.validate_response(request, response)` raises if invalid; `openapi.unmarshal_response(request, response)` validates and returns `result.data` and `result.headers`; `openapi.iter_response_errors(request, response)` collects errors instead of raising on the first. Request equivalents: `validate_request`, `unmarshal_request`, `iter_request_errors`. (O/docs/validation.md, O/docs/unmarshalling.md)
- The specification version is detected; `V31ResponseValidator` and `V31ResponseUnmarshaller` can be forced through `Config(response_validator_cls=...)`. (O/docs/configuration.md)
- Request and response objects must implement the library's `Request` and `Response` protocols. Official wrappers exist for aiohttp, Django, Falcon, FastAPI, Flask, Requests, Starlette and Werkzeug. An httpx wrapper is not in the official documentation. (O/README.md, O/docs/reference/protocols.md)
- Requests wrappers: `RequestsOpenAPIRequest(request)`, `RequestsOpenAPIResponse(response)` from `openapi_core.contrib.requests`. (O/docs/integrations/requests.md)
- Starlette wrappers: `StarletteOpenAPIRequest(request)`, `StarletteOpenAPIResponse(response)` from `openapi_core.contrib.starlette`; they wrap Starlette server-side objects inside a handler. (O/docs/integrations/starlette.md)
- Middleware: `app.add_middleware(FastAPIOpenAPIMiddleware, openapi=openapi)` from `openapi_core.contrib.fastapi.middlewares` (FastAPI 0.11x to 0.13x) and `StarletteOpenAPIMiddleware`; "all your requests and responses will be validated"; `response_cls=None` skips response validation. (O/docs/integrations/fastapi.md, O/docs/integrations/starlette.md)
- What the middleware returns to the caller when a response is invalid is not stated in the pages read.
- Status lookup order in source: the exact status, then the range key (`2XX`), then `default`; otherwise `ResponseNotFound` ("Unknown response http status"). (O/openapi_core/templating/responses/finders.py, O/openapi_core/templating/responses/exceptions.py)
- An undocumented content type gives `MediaTypeNotFound` ("Content for the following mimetype not found"). (O/openapi_core/templating/media_types/exceptions.py)
- Body errors are `InvalidData`, a missing body `MissingData`, headers `MissingRequiredHeader` and `InvalidHeader`. (O/openapi_core/validation/response/exceptions.py)
- Formats: the `format` keyword is checked; built-in validators include `date`, `date-time`, `binary`, `uuid`, `byte`, "depending on the OpenAPI version". Custom ones go in `Config(extra_format_validators={...})`. (O/docs/validation.md, O/docs/configuration.md)
- Unknown properties are allowed when `additionalProperties` is omitted; `Config(additional_properties_default_policy="forbid")` rejects them. (O/docs/configuration.md)
- `Config(response_properties_default_policy="required")` treats every documented response property as required; described as useful for "contract completeness checks in tests". (O/docs/configuration.md)
- Not documented as provided: request generation, a record of which documented statuses were exercised, any check that every operation was called.

**Schemathesis**

- Generates inputs from an OpenAPI (2.0, 3.0, 3.1, 3.2), GraphQL or gRPC description and checks responses; every phase uses Hypothesis. (S/README.md, S/docs/index.md, S/docs/explanations/data-generation.md)
- It "sends real requests that create, change and delete data". (S/README.md)
- Loaders: `schemathesis.openapi.from_url`, `from_path`, `from_file`, `from_dict`, `from_asgi(path, app)`, `from_wsgi(path, app)`. (S/docs/reference/python.md, S/src/schemathesis/openapi/loaders.py)
- `from_asgi("/openapi.json", app)` runs the app in-process with no server; `path` is the route where the app serves its own description. The ASGI lifespan is started on load and shut down at interpreter exit. (S/docs/guides/python-apps.md)
- The public `from_path(path, config=, encoding=)` takes no app. Testing an authored description file against an in-process app is documented for the CLI only: `st run openapi.yaml --app project.asgi:app`. (S/src/schemathesis/openapi/loaders.py, S/docs/guides/python-apps.md)
- pytest: `@schema.parametrize()` creates one test per operation; the body calls `case.call_and_validate()`. `schemathesis.pytest.from_fixture("name")` builds the schema from a fixture; `schemathesis.pytest.parametrize(a=..., b=...)` covers several schemas. (S/docs/explanations/pytest.md)
- Phases: examples, coverage, fuzzing, stateful. Under pytest the stateful phase is not run by `parametrize()`; use `schema.as_state_machine()` and its `.TestCase`. Several adaptive features run only under the CLI. (S/docs/explanations/pytest.md, S/README.md)
- `max_examples` is 100 by default per operation in the fuzzing phase. (S/docs/explanations/pytest.md)
- Checks, all on by default except `max_response_time`: `not_a_server_error`, `status_code_conformance`, `content_type_conformance`, `response_headers_conformance`, `response_schema_conformance`, `negative_data_rejection`, `positive_data_acceptance`, `missing_required_header`, `unsupported_method`, `allow_header_conformance`, `use_after_free`, `ensure_resource_availability`, `ignored_auth`, `object_level_authorization`. They import from `schemathesis.checks`. (S/docs/reference/checks.md)
- Select with `case.call_and_validate(checks=[...])` or `excluded_checks=[...]`. (S/docs/reference/checks.md)
- `status_code_conformance` fails with ST103 "Undocumented status code" unless the status, a wildcard such as `2XX`, or `default` is documented. (S/docs/reference/checks.md)
- `response_schema_conformance` enforces `format` by default (`validate-formats`, default `true`). (S/docs/reference/checks.md)
- Existing hand-written tests can call `api_schema["/users/{user_id}"]["GET"].validate_response(response)`; there "a status code the schema does not document is not an error". (S/docs/guides/schema-conformance.md)
- Custom session: `schemathesis.python.asgi.ASGIClient(app)`, a `requests.Session` subclass, passed as `call_and_validate(session=client)` from a module-scoped fixture. (S/docs/guides/python-apps.md)
- Auth: static headers, or `@schema.auth()` with `get` and `set` methods. The `ignored_auth` check and some coverage cases deliberately send requests without valid credentials. (S/docs/guides/python-apps.md, S/docs/faq.md)
- Determinism: CLI `--seed INTEGER` and `--generation-deterministic`. The CLI ignores Hypothesis's `ci` profile; tests under the pytest plugin follow Hypothesis settings profiles. (S/docs/reference/cli.md, S/docs/guides/cicd.md)
- CLI: `schemathesis run LOCATION` (alias `st`), `--phases`, `--checks`, `--exclude-checks`, `--max-examples`, `--mode positive|negative|all`. Exit codes: 0 all checks passed, 1 a check failed, 2 could not run or tested nothing, 130 interrupted. (S/docs/reference/cli.md)
- Coverage of the description is reported by a separate tool, TraceCov; its "Responses" dimension records statuses the API actually returned, and documented statuses that need server state "stay uncovered until a test puts the API in that state". (S/docs/guides/coverage.md)
- A setting that fails a run because a documented status was never returned is not stated in the official documentation.
- Generated data "may be rejected by your API if the validation rules are not expressed in your schema". (S/docs/faq.md)

## Actionable Techniques (design is this note's)

- Schemathesis `from_asgi` exercises the real router, middleware and handlers in-process and fails on an undocumented status, content type or body. With FastAPI it reads the description the app generates, so a hand-authored description needs a separate comparison or the CLI `--app` form.
- For hand-written provider tests, adapt the test client's request and response to the openapi-core protocols and call `validate_response`; `ResponseNotFound` covers the undocumented status.
- "A documented status no test exercised" needs the test suite's own bookkeeping (record each operation and status validated, compare with the description); neither tool documents it as a gate.
- Keep format checking on in both tools; add `extra_format_validators` for custom formats.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-contract-test | Provider conformance runs the real app on every pull request | `from_asgi` in-process run with lifespan; openapi-core `validate_response` |
| python-contract-test | Fail on an undocumented status | `status_code_conformance` (ST103); `ResponseNotFound` |
| python-contract-test | Fail on a documented status no test exercised | Not provided by either tool as a gate; TraceCov only reports it |
| python-contract-test | Format assertion | `validate-formats` default `true`; openapi-core built-in `uuid`, `date-time` validators |

## Candidate New Skills/Agents

None.

## Key Terminology

Response Validation, Unmarshalling, Property-Based Testing, Check, Stateful Testing.

## Caveats

- Nothing was run. No package was installed.
- [unverified] Whether `validate_response` raises `ResponseNotFound` and `MediaTypeNotFound` directly or wrapped in another error; the classes were read in source, the raise path was not traced.
- [unverified] Which built-in format validators are active for an OpenAPI 3.1 description beyond the list quoted.
- [unverified] Whether an httpx or Starlette `TestClient` response can be passed to the Requests wrapper.
- Schemathesis 4.34.4 was one day old on the access date.
