# pytest-asyncio Official Documentation
**Authors:** The pytest-asyncio project (pytest-dev/pytest-asyncio)
**Domain:** Testing (async, Python)

Accessed 2026-11-25. Latest 1.5.0, Python >=3.10, needs pytest>=8.4 (https://pypi.org/pypi/pytest-asyncio/json). Doc pages are `stable`.

## Core Concepts

- `asyncio_mode`: `strict` (default; only marked tests and `@pytest_asyncio.fixture` fixtures) or `auto` (all async tests and fixtures; suited to asyncio-only projects). CLI `--asyncio-mode` overrides config (https://pytest-asyncio.readthedocs.io/en/stable/concepts.html; .../reference/configuration.html).
- One event loop per collector level; tests default to a function loop. `loop_scope` on the marker shares a wider loop. Tests run sequentially (concepts page).
- `asyncio_default_fixture_loop_scope`: unset means the fixture's own scope; a future version will default to `function`. `asyncio_default_test_loop_scope`: unset means `function`. Values include `module`, `package`, `session`, `class`, `function` (configuration page).
- 1.0.0 (2025-05-26) removed the `event_loop` fixture; 1.2.0 raises on invalid loop-scope values; 1.4.0 deprecated overriding `event_loop_policy` (https://pytest-asyncio.readthedocs.io/en/stable/reference/changelog.html).

## Actionable Techniques

- Pin the version; set `asyncio_mode` and both loop-scope options once.
- With session-scoped async fixtures (database pool, container client), set both scopes to `session`.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-unit-test, python-integration-test | W3C-1, 12 | Mode, loop-scope settings, removed fixture |

## Candidate New Skills/Agents

None.

## Key Terminology

Event Loop Scope, Strict Mode, Auto Mode.

## Caveats

- Nothing was run. [unverified] Exact version that added the test loop-scope option.

## Answers to audit questions

| Question | Answer | Status |
|---|---|---|
| W3C-12 [GK setting name] | `asyncio_default_test_loop_scope` | Confirmed |
| W3C-12: test and session fixture use different loops when only the fixture scope is set | Test default stays `function` | Confirmed |
