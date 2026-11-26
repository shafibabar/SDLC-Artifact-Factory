---
name: python-unit-test
description: >
  Use when backend-engineer, test-strategist or anyone writes, reviews or fixes
  Python unit tests in the Implement phase: pytest, test-first (TDD),
  parametrize tables, fixtures and conftest.py, deriving cases (boundaries,
  decision tables, state transitions), pytest-asyncio and async tests that pass
  while checking nothing, fakes and fake Unit of Work, AsyncMock and mocking a
  publisher or repository, fake clocks, Hypothesis property tests, or Python
  coverage: pytest-cov, coverage.py, --cov-fail-under, 100% line and branch
  gates, pragma no cover and exclusions. Produces pytest-suite.
version: 2.0.0
phase: implement
owner: test-strategist
created: 2026-07-31
tags: [implement, python, pytest, unit-test, parametrize, fixtures, pytest-asyncio, fakes, hypothesis, tdd, coverage, branch-coverage]
produces: pytest-suite
domain: testing
status: stable
related: [test-pyramid, mock-generation, test-fixture-design, go-unit-test, python-domain-model, python-service-layer, python-repository-pattern, python-project-structure, python-makefile, python-integration-test, python-contract-test, python-mutation-test]
sources:
  - research/testing/unit-testing-khorikov.md
  - research/testing/software-testing-craftsman-jorgensen.md
  - research/testing/python-testing-with-pytest-okken.md
  - research/testing/pytest-official-docs.md
  - research/testing/pytest-asyncio-official-docs.md
  - research/testing/coverage-official-docs.md
  - research/testing/hypothesis-official-docs.md
  - research/software-architecture/architecture-patterns-with-python-percival-gregory.md
---

# Python Unit Test

## Purpose

This skill owns how Python unit tests are derived, written and measured; the other Python test skills take it as the baseline. It follows the same policy as `go-unit-test`; only the mechanics differ. `test-strategist` authors the standard; `backend-engineer` applies it. `test-pyramid` owns layers and gates, `mock-generation` the rules for doubles, `test-fixture-design` test data.

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off.

| # | Rule | Reason |
|---|---|---|
| U1 | **Test first:** write a failing test, see it fail for the expected reason, write the least code that passes, refactor | The `tdd-gate` hook checks only that a matching test file exists, never order |
| U2 | **Assert behaviour through the public surface, not internal state**: never a `_field` or internal call count | Such tests break on refactors that preserve behaviour (Khorikov) |
| U3 | **No real world:** no file system, network, database, clock or randomness the test does not control; no sleeping | Results would vary between runs; a real dependency belongs in `python-integration-test` |
| U4 | **Doubles:** a managed dependency is verified by state through a fake; mock only a port for an unmanaged one; never assert on a stub | One rule across every test (`mock-generation`) |
| U5 | **Coverage is 100% of lines and branches.** Excluded without a per-file entry: machine-generated code, and two classes the product owner approved once (`...` placeholder bodies, `if TYPE_CHECKING:` blocks), listed in every report. Any other exclusion needs its own reason and approval. Never offer or record a lower figure | `test-pyramid` and the product owner's decision |
| U6 | **A "no result" blocks the build** (failed or partial run, unmeasured file, unapproved exclusion). Remedy: change the code or tests, or list an exception for approval. Never report unmeasured code as passing | A gate that guesses proves nothing |
| U7 | **A waiver exists only for a measured result above 90% and under 100%,** after the product owner reviews it and records comments, per measure and per run | None before a result; none at 90% or below |

Every product size follows all seven. **Lean** means fewer cases and packages, never a lower figure, a skipped gate or tests written afterwards.

## What every answer states

Say these in words, beside any code; code that follows a rule silently leaves the reader free to undo it.

1. **What kind of code it is** (quadrant) and which test proves each part. "Trivial" and glue code is still covered or listed.
2. **How the cases were derived**, naming the technique, what was collapsed and what was not tried.
3. **What is replaced or refused, by name, with the reason** (a private-state or call assertion on our own code is replaced because it **breaks when the code is refactored** although behaviour is unchanged; mocks are for unmanaged dependencies such as a broker, email or a third-party API): "`repo.save.assert_awaited_once()` is removed: the repository is ours, so the test reads the saved state". Give the compliant version.
4. **What stays the default when one case differs**: "this publisher gets a mock; every repository still gets a fake, with no call assertions".
5. **What a tool does that the reader cannot see**, whichever applies: an un-awaited async *test* fails on pytest 8.4 and later, but a forgotten `await` inside a test passes with only a warning unless that warning is an error; `assert_called_once` passes for a call never awaited; a mock verifies nothing until asserted; an empty parametrize list is skipped and the run stays green; autospec rejects wrong arguments; each script's exit codes.
6. **Sketches:** every name declared or its origin named; each test asserts what its name claims.
7. **Coverage, whenever it comes up:** that **branch measurement must be switched on** (`branch = true`; the gate runs with it); that **a lower figure or a lone percentage is not the gate** and no coverage flag stays in shared settings (`--cov-fail-under=100` may sit on the full gate command only, never as the whole check); that the gate **reads the JSON report of a full run and fails on any line not run or branch not taken**, and in the same place that **all three of: machine-generated code is excluded automatically; `...` placeholder bodies and `if TYPE_CHECKING:` blocks are approved once as a class and listed in every report (say "listed in every report"); any other exclusion needs its own reason and the product owner's approval**; that **the tool's own exit status is not enough**, because it passes at 100% with a pragma, `omit`, branch measurement off or an unimported folder; both measures as counts; the unmeasured cases (alternatives inside one line; zero-iteration loops; docstring-only bodies; child processes; hidden or skipped tests); generated files and the approved-class lines by file; other exclusions pending or approved; skipped tests counted (reported, not blocking); that the gate ignores the product's own coverage settings; a "no result" blocks the build, with its two remedies; a unit-only or filtered run gives no verdict.
8. **At this size:** what lean changes and what it does not.
9. **Decisions for the product owner**: each exclusion, each waiver after a result, any rule the request leaves undefined.
10. **What was run.** Code not executed is called unverified.

## What deserves which test

| Code | Proof |
|---|---|
| Domain logic: complex, few collaborators | Thorough parametrized unit tests |
| Complex and many collaborators | Split first: logic into plain classes, a thin wrapper left (Humble Object) |
| Use case or handler: simple, many collaborators | One test per way it ends, against fakes; adapters and routes in integration tests |
| Trivial | Through the behaviour that uses it; else its own small test, or listed |

## Procedure

1. Read the code or requirement, acceptance criteria, ports, `tests/fakes.py`, `pyproject.toml` and the test strategy's exclusion register.
2. Classify the code with the table above.
3. Derive the cases; open `./references/deriving-test-cases.md` for limits, condition combinations or state changes.
4. Copy from `./templates/unit-test-skeletons.md` into `tests/unit/<layer>/test_<module>.py` with Write, before the implementation. A module holding only Protocols or errors needs its matching test file too, or the hook refuses it.
5. Run it; see it fail for the expected reason. Then write the least code to pass and refactor.
6. For tables, fixtures, time or randomness read `./references/test-shape-fixtures-isolation.md`; for async code `./references/async-and-silent-passes.md`; for doubles or test value `./references/doubles-and-value.md`; for invariants or untrusted input `./references/property-based-testing.md`.
7. Check `pyproject.toml` against `./templates/pytest-settings.md`.
8. Run `./scripts/validate-python-unit-tests.sh tests/unit tests/conftest.py tests/fakes.py` (those that exist), then `pytest`; fix and repeat until clean.
9. Read `./references/coverage-gate.md`, then run `./scripts/check-python-coverage.sh` on the full suite. For each gap add the behaviour case it reveals; for each "no result" change the code or tests, or list the exception as pending (the build stays blocked); rerun until it passes.
10. Copy `./templates/coverage-report.md` to `artifacts/<product>/quality/test-reports/` and fill it from the full run, for the product owner's approval.
11. Tick `./resources/checklist.md` and answer with the statements above.

Worked cases with real gate output: `./examples/01-lean-bakery-stamps.md` (all lines run, two branches missed), `./examples/02-standard-class-booking.md` (decision table, fake Unit of Work, mock, a listed class and a blocked pragma), `./examples/03-enterprise-energy-billing.md` (tenants, properties, concurrency, a waivable result beside one that is not).

## Gotchas

- **"An async test that is never awaited passes silently."** *Reason:* false on current pytest: it fails. The silent pass is a forgotten `await` *inside* a test. *Instead:* make those warnings errors.
- **`--cov-fail-under` in `addopts`.** *Reason:* subset runs fail on coverage, and at 100 it still passes with code hidden. *Instead:* no coverage flags in shared settings; run the gate.
- **`# pragma: no cover` or `omit` as routine.** *Reason:* each is an exclusion needing approval; only the two classes are pre-approved, and a `...` inside working code is not one. *Instead:* test it, change it, or list it.
- **"All lines ran, so branches are fine."** *Reason:* an `if` without `else` has a second path. *Instead:* read the branch count.
- **Asserting `repo.save` was awaited.** *Reason:* the repository is managed. *Instead:* read the record back; for "must not save", assert it is unchanged.
- **A fake that returns the stored object itself.** *Reason:* the state assertion passes with `save` or `commit` missing. *Instead:* copy on read, roll back by default.
- **Mocking a broker publish from a command handler with an outbox.** *Reason:* the handler publishes nothing. *Instead:* assert the outbox row.
- **Patching a function by its import path.** *Reason:* it couples the test to the module's insides. *Instead:* pass the port in and autospec it.
- **`datetime.now()`, `asyncio.sleep(1)` or global `random`.** *Reason:* the run decides the result. *Instead:* inject them.
- **Adding calls with no assertion to reach 100%.** *Reason:* coverage proves only that code ran. *Instead:* write the behaviour case, or delete dead code.

## Output

| File | When to open it |
|---|---|
| `./references/deriving-test-cases.md` | Choosing cases |
| `./references/test-shape-fixtures-isolation.md` | Tables, fixtures, time, randomness |
| `./references/async-and-silent-passes.md` | Async code, or a suspicious pass |
| `./references/doubles-and-value.md` | Fakes, mocks, quadrants |
| `./references/property-based-testing.md` | Hypothesis |
| `./references/coverage-gate.md` | Running or reporting coverage |
| `./templates/unit-test-skeletons.md` | Writing test files |
| `./templates/pytest-settings.md` | Settings and pinned tools |
| `./templates/coverage-report.md` | Reporting a full run |
| `./scripts/validate-python-unit-tests.sh` | Before hand-off, after every edit |
| `./scripts/check-python-coverage.sh` | The coverage gate |
| `./resources/checklist.md` | Before answering |

Tests mirror the package under `tests/unit/` (`tests/unit/domain/test_dataasset.py`, the `python-project-structure` layout), with shared fakes in `tests/fakes.py` and fixtures in `conftest.py`.
