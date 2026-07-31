---
name: python-unit-test
description: >
  Teaches the backend-engineer to write Python unit tests with pytest —
  function-scoped @pytest.fixture, @pytest.mark.parametrize example tables,
  pytest-asyncio for async domain/service tests, the fakes-over-mocks
  discipline (a set-backed FakeRepository over pytest-mock, per Khorikov +
  cosmic-python), AAA structure, and coverage. The fast domain-model layer.
  The Python analog of go-unit-test.
version: 1.0.0
phase: quality
owner: backend-engineer
created: 2026-07-31
tags: [quality, python, pytest, unit-test, fixtures, parametrize, pytest-asyncio, fakes-over-mocks, aaa, coverage, four-pillars, tdd]
related: [go-unit-test, python-domain-model, python-service-layer, test-fixture-design]
tools: [Bash]
---

# Python Unit Test

## Purpose

Unit tests are the base of the pyramid: fast, deterministic, isolated checks that a
function, value object, or Aggregate behaves correctly. They run in milliseconds against
in-memory fakes — never a real database, broker, clock, or socket — so a service can have
thousands of them and each pinpoints one unit. This skill is the Python analog of
`go-unit-test`; the backend-engineer applies it **test-first** (TDD) for
`python-domain-model` and `python-service-layer`, and every other Python test skill
(`python-integration-test`, `python-contract-test`) treats this one's conventions —
fixture shape, parametrize tables, fakes-over-mocks — as baseline, not something to
restate.

Three Python realities diverge honestly from Go and shape everything below:

- **Fixtures + parametrize replace Go's table-driven struct.** Go packs cases into a
  `[]struct{name; want}` looped with `t.Run`; pytest splits the two roles — `@pytest.fixture`
  supplies dependencies by injection, `@pytest.mark.parametrize` supplies the example table
  as decorator rows, each reported as its own pass/fail. Neither is "more correct"; they are
  different idioms for the same AAA discipline.
- **Async is not free — `pytest-asyncio` is load-bearing.** The stack (FastAPI + asyncpg +
  aiokafka) is `async def` end to end, so `async def test_` coroutines need an event loop.
  Go's `testing.T` runs any goroutine synchronously; pytest needs `asyncio_mode = "auto"`
  configured or the coroutine is never awaited and the test **silently passes without
  running** — a failure mode with no Go equivalent.
- **No compiler-enforced privacy.** Go's unexported fields cannot be reached from a test in
  another package, so a test *must* assert through the public surface. Python's `_underscore`
  is convention only — a test *can* reach private state, which makes the discipline of
  asserting observable behaviour (below) a rule you enforce, not one the compiler enforces.

---

## Discovery and Plain `assert`

pytest finds tests by convention, no registration: files `test_*.py`, functions `test_`,
classes `Test*` (no `__init__`). A bare module of `test_` functions is a runnable suite —
no base class, no suite object. Test layout mirrors package layout without wiring.

Assert with Python's bare `assert`, never `unittest`'s `assertEqual`/`assertTrue`. pytest's
assertion rewriting unpacks a failed `assert got == want` into a recursive diff of both
operands — so the failure message is generated from the expression, no custom message
needed. This is the single biggest ergonomic win over `unittest` and the reason this repo
does **not** use the `unittest` vocabulary anywhere.

```python
def test_restricted_outranks_internal():
    assert Sensitivity.RESTRICTED.outranks(Sensitivity.INTERNAL)   # rewritten diff on fail
```

---

## Fixtures and Parametrize — The Core

A `@pytest.fixture` function's return (or `yield`) value is injected into any test naming
it as a parameter — pytest's composable replacement for xUnit `setUp`/`tearDown`. `scope=`
controls lifetime: `function` (default, per test — the unit-layer default), `class`,
`module`, `session`. A `yield` fixture runs setup before the yield and teardown after,
guaranteed even when the test fails. Fixtures in `conftest.py` are auto-discovered by every
test file in that directory tree — never imported.

`@pytest.mark.parametrize` turns one test function into N independent cases, each a row of
input/expected data reported with its own id — Specification by Example in code. Adding a
case is adding a data row, not copy-pasting a test. Always give each row an explicit `id=`
so a failure names the case, not `test[0-1-2]`.

For the unit layer, default to **function scope** (cheap, isolated) and a **factory
fixture** when a test needs many configured domain objects
(`make_data_asset(tenant=…, sensitivity=…)`). Fixture scopes, `conftest.py` layering,
`yield` teardown, factory fixtures, parametrize `id=` tables, and a full worked DataAsset
domain + service unit test: `references/fixtures-and-parametrize.md`.

---

## Async Tests with pytest-asyncio

Domain and service code here is `async def`, so its unit tests are too. Configure
`asyncio_mode = "auto"` in `pyproject.toml` (`[tool.pytest.ini_options]`) so `async def
test_` functions and `async def … yield` async fixtures run under an event loop without
per-test `@pytest.mark.asyncio` boilerplate. **Verify the mode is set** — an un-awaited
coroutine test is reported as passed, catching nothing (the async analog of an
assertion-free test). Config, async fixtures, and the async FakeUnitOfWork drive:
`references/fakes-async-coverage.md`.

---

## Fakes Over Mocks — Mock Only the Unmanaged Edge

This repo follows Khorikov's classical school and cosmic-python's fakes-over-mocks
discipline. The rule for what earns a mock at all is the **managed vs. unmanaged
dependency** distinction:

- A **managed dependency** (your own Postgres, reachable only through your code) is verified
  by its **end state** — a set-backed `FakeRepository` / `FakeUnitOfWork` for unit tests,
  a `testcontainers-python` integration test for the real thing. **Never** a call-count
  mock on a repository.
- An **unmanaged dependency** (an aiokafka publish, a third-party HTTP call — a side effect
  observable outside your app) *is* the behaviour that matters, so a `pytest-mock` `mocker`
  patch verifying the interaction is the correct and only tool.

Prefer a set-backed fake over `pytest-mock` for the owned path: assert on resulting state,
not on how the code called its collaborators. **Never assert on a stub** — verifying a call
that was only there to supply data couples the test to an implementation detail with zero
behavioural payoff. The `FakeRepository`/`FakeUnitOfWork` implementations, the four-pillars
rationale, and the narrow `mocker` use for the unmanaged edge: `references/fakes-async-coverage.md`.

---

## AAA and One Behaviour Per Test

Each test (or each parametrize row) follows **Arrange–Act–Assert**: build the world, call
one thing, assert one observable outcome. More than one Act in a test usually means it is
secretly an integration test or should split into two. Assert on **observable behaviour
through the public surface** (`asset.sensitivity`, a returned DTO, a raised domain
exception) — never a private `_field` or an internal call count, even though Python lets
you reach them. Name tests after the behaviour in plain language
(`test_returns_error_when_tenant_is_empty`), not the method signature.

This is Khorikov's four pillars — protection against regressions, resistance to
refactoring, fast feedback, maintainability — held as **multiplicative, not additive**: a
test that asserts a private call count *looks* like more protection but destroys resistance
to refactoring, zeroing out the rest. The full four-pillars framing is
`references/fakes-async-coverage.md`.

---

## Coverage — A Signal, Never a Target

Wire `pytest-cov` (`--cov=src --cov-report=term-missing`) for a *gap signal* only. Coverage
tells you a line executed, not that a meaningful assertion ran — an assertion-free test
inflates it to 100% while catching nothing. Use it to find under-tested domain code (a
useful negative signal); never accept a coverage number as evidence a suite is good. The
suggested per-layer gate and its honest caveat: `references/fakes-async-coverage.md`.

---

## Rules

- **No real world.** No filesystem, network, database, or uncontrolled clock — fakes and
  injected time only. A "unit" test needing a real database is an integration test; move it
  to `python-integration-test`.
- **Function-scoped fixtures at the unit layer**, factory fixtures for many objects,
  `conftest.py` for sharing — never an import.
- **Parametrize with explicit `id=`** for every example table.
- **`asyncio_mode = "auto"`** configured and verified, or async tests silently no-op.
- **Fakes for managed dependencies, `mocker` only for the unmanaged edge.** Never a
  call-count mock on a repository; never assert on a stub.
- **Assert observable behaviour**, never private state or call counts (a Python discipline,
  not a compiler guarantee). One behaviour per test.
- **Test-first (TDD).** The test precedes the code; the `tdd-gate` hook verifies it.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Isolated | Fakes + injected time; no real FS/network/DB | A "unit" test hitting Postgres |
| Fixtures unit-appropriate | Function scope; factory fixture for many objects | `session`-scoped mutable state shared across tests |
| Parametrized tables | `@pytest.mark.parametrize` with explicit `id=` | Copy-pasted near-identical `test_` funcs |
| Async wired | `asyncio_mode = "auto"`; async tests actually run | `async def test_` un-awaited, silently passing |
| Fakes over mocks | Set-backed fake for the owned path | Call-count mock on a repository |
| Mock only unmanaged edge | `mocker` for aiokafka/HTTP interaction only | Asserting on a stub that only supplied data |
| AAA, one behaviour | Single Act; one observable assertion | Multiple Acts; assertion on a private `_field` |
| Coverage as signal | `--cov` reported, not chased | A coverage % accepted as proof of quality |
| Test-first | Test precedes code (`tdd-gate`) | Tests written after, to fit the code |

---

## Anti-Patterns

- **`unittest.TestCase` transliteration** — `assertEqual`/`setUp` inheritance instead of
  bare `assert` + fixtures; discards pytest's assertion rewriting and composability.
- **Missing `asyncio_mode`** — an `async def test_` that is collected, never awaited, and
  reported green while asserting nothing.
- **Call-count mock on a repository** — a managed dependency verified by interaction instead
  of end state; Khorikov's classical-school violation.
- **Asserting on a stub** — verifying a call that only arranged input; couples to an
  implementation detail with zero behavioural payoff.
- **Reaching private state** — `asset._sensitivity` in an assertion because Python lets you;
  breaks resistance to refactoring exactly as a Go private-field access would if it compiled.
- **Parametrize without `id=`** — failures read `test_x[0-1-2]` instead of naming the case.
- **Chasing a coverage number** — writing assertion-free tests to hit a percentage.
- **One giant test function** — a failure in the third scenario hides the rest; parametrize
  rows report every case independently.

---

## Output Format

Produces pytest test files, written before the code they cover (TDD):

```
tests/domain/test_data_asset.py            (parametrized invariant tests — no I/O)
tests/application/test_classify_asset.py    (service tests against FakeUnitOfWork)
tests/conftest.py                           (shared fixtures: factories, fakes)
pyproject.toml                              ([tool.pytest.ini_options]: asyncio_mode, markers)
```
