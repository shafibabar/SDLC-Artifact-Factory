# pact-python v4 Official Documentation
**Authors:** Pact Foundation (pact-foundation/pact-python, pact-foundation/pact-cli, docs.pact.io)
**Domain:** Testing (contract)

Accessed 2026-11-28. pact-python latest 4.2.0, 2026-10-23, MIT, Python >=3.11 (https://pypi.org/pypi/pact-python/4.2.0/json). Source and docs read at tag `pact-python/4.2.0`: P = https://raw.githubusercontent.com/pact-foundation/pact-python/pact-python/4.2.0. Pact CLI latest v1.0.0, 2026-11-23, MIT: C = https://raw.githubusercontent.com/pact-foundation/pact-cli/main/README.md.

## Core Concepts

**Versions and packaging**

- The current API is the top-level `pact` package (`from pact import Pact, Verifier, match, generate`), built on the Rust Pact FFI. It was introduced in 3.0.0 (2025-10-06). (P/MIGRATION.md, P/CHANGELOG.md)
- 4.0.0 (2026-10-15) removed the old `pact.v2` module (`Consumer`, `Provider`, the v2 `Verifier`), the `compat-v2` extra and the `pact-verifier` console script, and requires Python 3.11+. Projects that cannot migrate pin `pact-python<4`. (P/MIGRATION.md, P/CHANGELOG.md)
- Still present but deprecated: `BrokerSelectorBuilder.consumer_versions(...)` (use `consumer_version(...)` with keywords). `tag` and `fallback_tag` selectors are "still supported" with `branch` recommended. (P/src/pact/verifier.py)
- `pact-python` itself is a pure-Python wheel (`py3-none-any`) that depends on `pact-python-ffi~=0.5.12` (https://pypi.org/pypi/pact-python/4.2.0/json). `pact-python-ffi` 0.5.13.0 (2026-11-20) publishes `abi3` wheels for macOS 12+ arm64 and x86_64, manylinux_2_28 and musllinux_1_2 on x86_64 and aarch64, and Windows amd64 and arm64 (https://pypi.org/pypi/pact-python-ffi/json). The only documented install step is `pip install pact-python` (P/README.md).
- Classifiers list Python 3.11 to 3.15 (https://pypi.org/pypi/pact-python/json).
- A pytest plugin is registered automatically (entry point `pact`); it only scopes a log run ID per test and is disabled with `-p no:pact`. (P/src/pact/testing/pytest.py, P/pyproject.toml)
- Telemetry: OS type and package version are sent; `PACT_DO_NOT_TRACK=1` disables it. (P/README.md)

**Consumer**

- `Pact("consumer", "provider")`; `.with_specification("V4")` is optional because V4 is the default. (P/docs/consumer.md)
- Interaction chain, exact names: `pact.upon_receiving(description)` then `.given(state, **params)` then `.with_request(method, path)` then `.will_respond_with(status)` then `.with_body(body, content_type="application/json")`. Also `.with_header`, `.with_headers`, `.with_query_parameter`, `.with_query_parameters`. Shared methods apply to the request before `will_respond_with` and to the response after it. (P/docs/consumer.md, P/MIGRATION.md, P/src/pact/interaction/_http_interaction.py)
- The description must be unique within the pact. `given` can be called repeatedly, and takes parameters as keywords or as a dict in the second positional argument. (P/src/pact/pact.py, P/src/pact/interaction/_base.py)
- Matchers live in `pact.match`: `match.int`, `match.float`, `match.number`, `match.str`, `match.bool`, `match.regex(value, regex=...)`, `match.uuid`, `match.date`, `match.time`, `match.datetime`, `match.none`, `match.type`, `match.like`, `match.each_like`, `match.array_containing`, `match.includes`, `match.each_key_matches`, `match.each_value_matches`. (P/src/pact/match/__init__.py, P/docs/consumer.md)
- Generators live in `pact.generate`: `int`, `float`, `hex`, `str`, `regex`, `uuid`, `date`, `time`, `datetime`, `bool`, `mock_server_url`, `provider_state(expression)`. (P/src/pact/generate/__init__.py)
- `with pact.serve() as srv:` starts an in-process mock server on `localhost` and a random port; `srv.url` is a `str` subclass. The real client is constructed with that URL. (P/docs/consumer.md, P/src/pact/pact.py)
- On leaving the block the server raises `MismatchesError` if a request did not match or a defined interaction was never called (`raises=True` is the default). (P/src/pact/pact.py, P/docs/consumer.md)
- The pact file is not written automatically. Call `pact.write_file(directory)`; the default directory is the working directory, the file name is generated, and by default the content is merged into an existing file (`overwrite=False`). (P/src/pact/pact.py, P/MIGRATION.md)
- The consumer guide warns that calling the mock with a generic HTTP client (it names `requests` and `httpx`) instead of the real client "defeats the purpose of the test". (P/docs/consumer.md)
- The official HTTP examples use `requests` and `aiohttp` clients. An example with an `httpx` client is not in the official documentation. (https://github.com/pact-foundation/pact-python/tree/pact-python/4.2.0/examples/http)

**Provider verification**

- `Verifier(name)`, then `.add_transport(url="http://localhost:8080")` (or `protocol`, `port`, `path`, `scheme`), then a source, then `.verify()`. (P/docs/provider.md, P/src/pact/verifier.py)
- Local source: `.add_source(path_or_directory)`; URLs must be `str`. (P/src/pact/verifier.py)
- Broker source: `.broker_source(url, username=..., password=..., token=..., selector=False, use_env=True)`. Missing values are read from `PACT_BROKER_BASE_URL`, `PACT_BROKER_USERNAME`, `PACT_BROKER_PASSWORD`, `PACT_BROKER_TOKEN`. `token` is mutually exclusive with username and password. (P/src/pact/verifier.py)
- `selector=True` returns a `BrokerSelectorBuilder` that must end with `.build()`: `.include_pending()`, `.exclude_pending()`, `.include_wip_since("YYYY-MM-DD" or date)`, `.exclude_wip()`, `.provider_branch(name)`, `.provider_tags(...)`, `.consumer_tags(...)`, `.consumer_version(...)`. (P/src/pact/verifier.py)
- `consumer_version` keywords: `consumer`, `tag`, `fallback_tag`, `latest`, `deployed_or_released`, `deployed`, `released`, `environment`, `main_branch`, `branch`, `matching_branch`, `fallback_branch`. Repeated calls are combined with OR. (P/src/pact/verifier.py)
- In the builder, pending defaults to off and WIP to none. (P/src/pact/verifier.py)
- Results are published by calling `.set_publish_options(version, url=None, branch=None, tags=None)`; the guide wraps the call in `if "CI" in os.environ:`. The first branch set here or in `provider_branch` is reused by the other. (P/docs/provider.md, P/src/pact/verifier.py)
- `.set_error_on_empty_pact(enabled=True)` calls the FFI's `verifier_set_no_pacts_is_error`, described there as "no pacts are found to verify results in an error". The Python docstring describes it as an error for "a Pact file with no interactions". (P/src/pact/verifier.py, P/pact-python-ffi/src/pact_ffi/__init__.py)
- Other options: `.filter(description=, state=)`, `.filter_consumers(...)`, `.set_request_timeout(...)`, `.disable_ssl_verification()`, `.follow_redirects(...)`. (P/src/pact/verifier.py)
- `verify()` raises on failure and returns the verifier on success; there is no return code to check. The FFI wrapper raises `RuntimeError` when execution returns non-zero. `verifier.output()`, `.logs` and `.results` expose detail. (P/MIGRATION.md, P/pact-python-ffi/src/pact_ffi/__init__.py, P/src/pact/verifier.py)

**Provider states**

- `.state_handler(handler, teardown=False, body=None)` accepts a single function, a mapping of state name to function, or a URL string. With a URL, `body` must be a boolean; with functions it must stay `None`. (P/src/pact/verifier.py)
- Handler arguments are `state`, `action` (`"setup"` or `"teardown"`) and `parameters`; with a mapping and `teardown=True` each function takes `action` and `parameters`, with `teardown=False` only `parameters`. The mapping form is labelled recommended. (P/src/pact/types.py, P/docs/provider.md)
- Function and mapping handlers run in the test process, so the provider must run in the same process (a thread) for mocks to be shared. (P/docs/provider.md)
- The empty-string state `""` is "a generic test setup/teardown handler" and is optional in a mapping. Whether it runs before every interaction is not stated in the official documentation. (P/src/pact/verifier.py)

**Sign-in during verification**

- `Verifier.add_custom_header(name, value)` and `.add_custom_headers(mapping)`: "added to every request made to the provider"; the guide's example is an `Authorization` header. (P/src/pact/verifier.py, P/docs/provider.md)
- Whether a custom header replaces a header of the same name recorded in the pact is not stated in the official documentation. (https://docs.rs/pact_ffi/0.5.12/pact_ffi/verifier/fn.pactffi_verifier_add_custom_header.html)
- The `Verifier` class has no request filter, callback or middleware hook for rewriting a replayed request. (P/src/pact/verifier.py)
- docs.pact.io lists the general options: test auth outside Pact, stub the auth service, set up matching credentials through provider states, modify the request (a request filter where the library has one, otherwise "your own middleware or proxy"), or a long-lived token. (https://docs.pact.io/provider/handling_auth)
- `generate.provider_state(expression)` exists. How a Python state handler returns values for it is not stated in the official documentation; handler types return `None`. (P/src/pact/generate/__init__.py, P/src/pact/verifier.py)

**Running a FastAPI provider**

- Both official FastAPI examples start the real app with `Thread(target=uvicorn.run, args=(app,), kwargs={"host": ..., "port": ...}, daemon=True)` in a session-scoped fixture and pass the URL to `add_transport(url=...)`. One polls an endpoint until the server answers. Port selection uses the private helper `pact._util.find_free_port()`. (P/examples/http/requests_and_fastapi/test_provider.py, P/examples/http/service_consumer_provider/test_provider.py)
- No in-process ASGI transport for verification is documented; the verifier replays over HTTP. (P/docs/provider.md)

**Messages:** `upon_receiving(description, "Async")` or `"Sync"` on the consumer and `Verifier.message_handler(...)` on the provider. (P/src/pact/pact.py, P/MIGRATION.md)

**Broker and CLI**

- The consumer guide publishes with the Pact CLI: `pact broker publish <path> --consumer-app-version <v> --auto-detect-version-properties`. (P/docs/consumer.md)
- The CLI is one Rust `pact` binary; `pact broker` includes `publish`, `can-i-deploy`, `can-i-merge`, `record-deployment`, `record-release`, `create-environment`. (C)
- Install routes: shell installer, `pip install pact-python-cli` (1!1.0.0, 2026-11-23, same binary as wheels), npm, GitHub Action `pact-foundation/pact-cli@vX.Y.Z`, Docker image `pactfoundation/pact`. (C, https://pypi.org/pypi/pact-python-cli/json)
- `pact-python-cli` is no longer installed with pact-python. Its 2.x line shipped the Ruby tools (`pact-broker ...`); the `pact_cli` Python module is gone, so the binary is found with `shutil.which("pact")`. On Linux with glibc older than 2.34 pip falls back to the Ruby 2.6.4.0. (P/MIGRATION.md, C)
- docs.pact.io still documents the Ruby form: `pact-broker can-i-deploy --pacticipant P --version V --to-environment E` (exit 0 yes, 1 no) before deploying, `pact-broker record-deployment --pacticipant P --version V --environment E` after, and the image `pactfoundation/pact-cli`. (https://docs.pact.io/pact_broker/can_i_deploy, https://docs.pact.io/pact_broker/client_cli/readme)
- Pending: a failing pending pact does not fail the verification task but the result is still published; needs the provider branch, consumer branch and version, and Broker 2.60.0+. (https://docs.pact.io/pact_broker/advanced_topics/pending_pacts)
- WIP: set a past date (about 30 days, at most about 3 months), a provider branch, and enable pending. (https://docs.pact.io/pact_broker/advanced_topics/wip_pacts)
- Publish verification results only from CI. (https://docs.pact.io/pact_nirvana/step_4)

## Actionable Techniques (design is this note's)

- Pin `pact-python>=4,<5`; import only from `pact`; treat any `pact.v2` import as a defect.
- Consumer: one `Pact` fixture, `serve()` per test, real client built from `srv.url`, `write_file` after the tests.
- Provider: uvicorn in a daemon thread, mapping-based state handlers, `broker_source(selector=True)` with `main_branch`, `matching_branch`, `deployed_or_released`, `include_pending()`, `include_wip_since(...)`, `provider_branch(...)`, `build()`, then `set_error_on_empty_pact()` and CI-only `set_publish_options(...)`.
- Token-checking middleware: prefer a state handler that swaps the token verifier in-process (the official example swaps an auth client this way); use `add_custom_header("Authorization", ...)` only after confirming by a run that it overrides the recorded header.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-contract-test | Pact required for every direct service-to-service call at every size | Current API names and packaging; the requirement itself is not stated in the official documentation |
| python-contract-test | Daily scheduled run | Not stated in the official pages read; only provider-change and pact-change triggers are described |
| python-contract-test | can-i-deploy at deployment | `pact broker can-i-deploy` and `record-deployment`, install routes, exit codes |
| python-contract-test | Provider behind token-checking middleware | `add_custom_header`, state handlers in-process, no request filter |
| python-contract-test | Pending and WIP behaviour | `include_pending()`, `include_wip_since()`, `provider_branch()`; both off by default |

## Candidate New Skills/Agents

None.

## Key Terminology

Pacticipant, Provider State, Consumer Version Selector, Pending Pact, WIP Pact, can-i-deploy.

## Caveats

- Nothing was run. No package was installed and no example was executed.
- [unverified] Flag names of the Rust `pact broker` subcommands (the README lists the subcommands, not their flags); the flags above come from the Ruby client page.
- [unverified] The exact exception type a user sees from `verify()` on a contract mismatch; the source shows `RuntimeError` from the FFI wrapper.
- [unverified] Whether verification results are published when `set_publish_options` is not called.
- pact-python-cli 1!1.0.0 and Pact CLI v1.0.0 were five days old on the access date.
