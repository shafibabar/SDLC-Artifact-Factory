---
name: python-e2e-test
description: >
  Use when test-strategist or anyone writes, reviews, runs or fixes end-to-end
  tests for a Python (FastAPI) product in the Quality phase: pytest journey
  tests through the deployed services over real network hops with httpx, the
  throwaway kind cluster they run in and its one script (make e2e), the
  conftest guard that refuses any target but the run's own cluster, a client
  bound to one address (absolute URL, redirect), tests/e2e/journeys and
  tests/e2e/smoke, read-only smoke tests on promotion, seeding test data,
  eventually polling instead of time.sleep or asyncio.sleep, OpenTelemetry
  traceparent trace id on failure, one retry and a quarantine list for a flaky
  journey (pytest-rerunfailures, --reruns), keeping e2e out of make ci and the
  coverage gate, the nightly and before-release workflow, the end-to-end test
  report, a product with both Go and Python services, or "can we run pytest
  e2e against staging / with Docker Compose / with ASGITransport / on every
  pull request". Produces python-e2e-test-suite.
version: 2.0.0
phase: quality
owner: test-strategist
created: 2026-07-31
tags: [quality, python, e2e, end-to-end, pytest, httpx, kind, smoke, journey, quarantine, trace-correlation, ci]
produces: python-e2e-test-suite
domain: testing
status: stable
related: [go-e2e-test, test-pyramid, test-fixture-design, acceptance-criteria, python-integration-test, python-unit-test, python-contract-test, python-makefile, python-load-test, helm-chart, environment-config, ci-pipeline, cd-pipeline, blue-green-deployment, disaster-recovery-plan, react-e2e-testing, distributed-tracing-design, sdlc-config-management, uat-plan]
sources:
  - research/testing/pytest-e2e-mechanics-official-docs.md
  - research/testing/opentelemetry-python-official-docs.md
  - research/testing/httpx-guards-and-polling-official-docs.md
  - research/testing/pytest-official-docs.md
  - research/testing/pytest-asyncio-official-docs.md
  - research/testing/respx-httpx-official-docs.md
  - research/testing/kind-official-docs.md
  - research/testing/helm-official-docs.md
  - research/testing/kubectl-official-docs.md
  - research/testing/github-actions-e2e-official-docs.md
  - research/testing/opentelemetry-go-trace-context-official-docs.md
  - research/testing/python-testing-with-pytest-okken.md
  - research/testing/testing-web-apis-winteringham.md
  - research/testing/unit-testing-khorikov.md
  - research/testing/agile-testing-crispin-gregory.md
  - research/devops-and-delivery/continuous-delivery-humble-farley.md
  - research/software-architecture/python-backend-development-halstead.md
---

# Python End-to-End Test

## Purpose

This skill owns how a Python product is tested end to end: a few pytest journeys driven through the **deployed** services with `httpx`. `test-strategist` authors and runs it. The environment the journeys run in is owned by `go-e2e-test` for every stack; this skill carries its own copy of that one script and everything that is Python. End-to-end tests create and delete data, so most of this skill is about making it impossible for them to do that anywhere but in a cluster their own run created. Policy on layers, retries and when suites run belongs to `test-pyramid`; test data rules to `test-fixture-design`.

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off. The numbers match `go-e2e-test`.

| # | Rule | Reason |
|---|---|---|
| E1 | **Few journeys, each traced to acceptance criteria (`AC-US-n.m`), each needing more than one deployed part.** Everything else is proven at a lower layer | The top layer is the slowest and most brittle (Crispin and Gregory); the pyramid's shape follows from proving each behaviour at the lowest layer that can (Khorikov, `test-pyramid`) |
| E2 | **The environment is a throwaway Kubernetes cluster (kind) created for the run**, holding every chart of the product, the web shell and the dependencies. Never Docker Compose. **Never a shared, staging, production or tenant environment** | Journeys write and delete. Compose is a second deployment description (`environment-config`) |
| E3 | **One script creates the cluster, installs, waits, runs the suites, collects evidence and always deletes the cluster**, also when a suite fails or the run is interrupted. A product with Go and Python services has one environment and one script run, with one suite line per language | A provisioning script with an exit trap deletes the cluster before pytest starts |
| E4 | **Every `kind`, `helm` and `kubectl` command names the kubeconfig file created for the run** and its context. Never the caller's kubeconfig or current context, never `use-context`. The Python guard reads the marker the same way | Without it the command acts on whatever cluster the caller last used |
| E5 | **Journeys refuse to start unless their target is their own run's cluster**, proven by a marker the script put in it. Addresses come only from that marker; a client reaches one address and refuses any other, an absolute URL and a redirect included | A wrong variable must not be able to aim a write at a real environment; `base_url` alone does not confine an `httpx` client |
| E6 | **Every end-to-end file is under `tests/e2e/`**, journeys in `journeys/` and smoke tests in `smoke/`, marked `e2e` or `smoke` by folder. `make ci` and the coverage gate leave the folder out by path (`--skip-suite e2e`) | Python has no build that leaves files out: path and guard do that work |
| E7 | **Smoke tests are read-only**, in their own folder, and the smoke client refuses every write. A selection that runs no test fails. Smoke is the only selection that may address a deployed environment | It runs on every promotion, against real data |
| E8 | **Test data is created through the public API.** A direct database write only inside the throwaway cluster, as a plain `INSERT`, never an upsert. Each test removes exactly what it created, also when it fails | An upsert overwrites rows that were already there (`test-fixture-design`) |
| E9 | **Wait by polling with a deadline**, in tests and in the script. No `time.sleep`, no `asyncio.sleep`, no `sleep` as a wait | A fixed wait is either flaky or slow (Winteringham) |
| E10 | **A failed journey prints a trace id that the services received**: SDK tracer provider, W3C propagator, instrumented client, a span that covers the requests | With no SDK the id is all zeros and no header is sent |
| E11 | **Flaky tests follow `test-pyramid`**: one retry, by exact node id, done by the suite runner at this layer only; quarantine in a list file with an issue and a deadline; red after the deadline. No skip, no rerun-until-green | pytest exits 0 for a test that passed on its rerun: a retried pass is flaky, not green |
| E12 | **Never on a pull request, never in `make ci`. Nightly, before a release (finishing before publication) and by hand**, always through `make e2e`. No stored credential, `permissions: contents: read`, no cloud resource created or deleted | A `release: published` run starts after the release is out |
| E13 | **Evidence on failure** (all logs of every Pod, events, cluster state) **and a test report** under `artifacts/<product>/quality/test-reports/`, approved by the product owner | A red run nobody can diagnose gets re-run, not fixed |

Every product size follows all thirteen. **Lean** means fewer releases and fewer journeys, never no journeys, a lighter stand-in or a shared environment.

## What every answer states

**Keep the answer as short as the question.** State, **in words**, each rule above that bears on it; do not only follow it or point at a file. Add nothing the request did not ask about beyond one line where it bears on the question.

1. **Whenever an environment is mentioned:** the suite runs only in a throwaway kind cluster that its own run creates and deletes, **at every product size, lean included** (say those words when the product is lean or a lighter stand-in such as Docker Compose is proposed); it never runs against a shared, staging, production or tenant environment; every `kind`, `helm` and `kubectl` command uses the run's own kubeconfig file, never the caller's current context; the journeys refuse to start if the cluster does not carry their run's marker. For a product with Go services too: one environment and one script run, owned by `go-e2e-test`, with one suite line per language.
2. **Whenever smoke tests are mentioned:** they only read; they are separately selected, in their own folder, so a journey that creates or deletes data cannot be part of the selection (a `smoke` marker on a journey does not make it safe); the smoke client refuses every write; a selection that runs no test fails; smoke is the one selection that may address a deployed environment.
3. **Whenever seeding or test data is mentioned:** through the public API; a direct write only in the throwaway cluster, plain `INSERT`, never an upsert; seeding and deletion refuse any address that is not the run's own; each test removes what it created, also when it fails.
4. **What is refused or replaced, by name, with the reason** and the compliant version: Docker Compose, staging as the journey target, an address from an environment variable, `ASGITransport` or `TestClient` as "end-to-end", a pull-request trigger, `release: published` as the pre-release gate, a sleep, a skip, a rerun loop or `--reruns` in `addopts`.
5. **Readiness and teardown, when the script or a pipeline is discussed:** Helm 4 needs `--wait` written out; the script then waits for each rollout; teardown runs on failure and on interruption and is done by the script itself, in the same script that runs pytest.
6. **Whenever a trace id is mentioned:** say in words that with no OpenTelemetry setup in the test process the id is all zeros and nothing is sent to the product; that the fix has three parts, a tracer provider from the SDK, the W3C trace-context propagator, and an instrumented HTTP client that **replaces the plain `httpx` client** (name the replacement, do not only show it in code); and that the span stays open while the requests are sent.
7. **Whenever retries or quarantine are mentioned:** at most **one** retry per failed test, at the end-to-end layer only, and name the larger number as refused; a test that passed only on the retry is **flaky, not green**, which pytest's exit status does not show; a quarantined test **never counts as passed**, and each one is a line in a list file with an issue and a deadline, after which the run is red (`test-pyramid` owns the rule).
8. **A failure report:** which test, first attempt and retry, the trace id, where the evidence is. **Whenever the test report is mentioned:** it is an artifact the product owner approves; a chat message or a dashboard does not replace that approval.
9. **Whenever the everyday run is mentioned:** `make ci` and the coverage gate never collect `tests/e2e` (`--skip-suite e2e`); a bare `pytest` does collect it, and every end-to-end test is then refused before a request is sent; `mypy` checks the files like any test code.
10. **Whenever triggers or a release are mentioned:** never on a pull request; nightly, by hand, and before a release as a job the publishing job needs. Say in words that `release: published` fires **after** publication, so a run started by it cannot stop the release.
11. **Only where they arise:** what lean changes and what it does not; what the kind cluster does not prove; decisions for the product owner (a copy of real data, approval of the report).
12. **One line on what was run.** Anything not run, including every GitHub Actions behaviour, is called unverified.

## Procedure

1. Read the test strategy (journeys and smoke subset), the acceptance criteria, the deployment plan and charts, `sdlc-config.json`, `pyproject.toml`, and any existing `tests/e2e/`.
2. Choose the journeys: read `./references/journeys-and-waiting.md`. Push down whatever one deployed part can prove alone.
3. Set up the environment: copy `./scripts/run-e2e-environment.sh` and `./scripts/run-python-e2e-suite.sh` to `tests/e2e/` unchanged; fill `tests/e2e/e2e.conf` and one values file per release from `./templates/environment-config.md`. List **every** release. If the product already has the Go twin's environment, add suite lines to it and nothing else. Read `./references/environment.md` first.
4. Copy the suite from `./templates/python-suite.md`: `support.py`, `conftest.py` and the two self-check files unchanged; then write the product fixtures, one journey per user goal and the smoke tests. Read `./references/safety-guards.md` first. For state with no public route, read `./templates/direct-database-seed.md`.
5. Add the dependencies and settings from `./templates/pytest-configuration.md`, the make targets from `./templates/make-targets.md` and the workflow from `./templates/workflows.md`; read `./references/ci-and-release.md` for the release gate.
6. Run `./scripts/validate-python-e2e-tests.sh <product root>`; fix every FAIL, judge each WARN, and run it again until clean.
7. Run `make e2e`. See each new journey fail once for the expected reason (break the behaviour or the expectation), then pass. Confirm the cluster is gone afterwards.
8. For a flaky or quarantined test read `./references/retry-and-quarantine.md`.
9. Fill `./templates/test-report.md` from `e2e-evidence/` and write it under `artifacts/<product>/quality/test-reports/`; put it to the product owner.
10. Tick `./resources/checklist.md`; go back to step 6 after any change. Answer with the statements above.

Worked and run (kind v0.33.0, Helm v4.3.2, Python 3.15.2, pytest 9.2.0, httpx 0.29.0): `./examples/01-lean-lost-property.md` (one service, its database and the web shell, in the full cluster), `./examples/02-standard-museum-loans.md` (two services, an asynchronous hop, a failing and a flaky run, an interrupted run), `./examples/03-enterprise-air-quality.md` (Go and Python suites in one environment, tenants, a quarantined test, the release gate, smoke on promotion).

## Gotchas

- **`httpx.Client(base_url=cluster)` "can only reach the cluster".** *Reason:* an absolute URL ignores `base_url`, and a redirect leaves it. *Instead:* the bound client, which refuses both before sending.
- **`pytest -m smoke` "runs only safe tests".** *Reason:* a marker selects; it does not stop a write, and anyone can put it on a journey. *Instead:* the smoke folder and the read-only client.
- **`pytest tests/e2e ...` in a target or workflow.** *Reason:* seen: exit 0 when every test was skipped, and exit 0 with a rerun plugin when a test passed on its rerun. *Instead:* `run-python-e2e-suite.sh`.
- **`--reruns 1` (or `--reruns 2`) in `addopts`.** *Reason:* it retries unit and integration tests too and reports a flaky test as passed. *Instead:* no rerun setting; the runner retries once.
- **`--only-rerun ""` "to rerun only real flakes".** *Reason:* an empty pattern matches every failure. *Instead:* nothing; see above.
- **`tracer.start_as_current_span(...)` in a helper that returns headers.** *Reason:* with no SDK provider the id is all zeros, and the span ends before any request. *Instead:* the `journey` fixture and the instrumented client.
- **`HTTPXClientInstrumentor().instrument()` and a custom or mock transport.** *Reason:* it covers only the standard transports. *Instead:* wrap the transport itself, as the bound client does.
- **`kubernetes.config.load_kube_config()` to read the marker.** *Reason:* with no arguments it reads the caller's kubeconfig and current context. *Instead:* `kubectl --kubeconfig <the run's file>`, as the shipped guard does.
- **A provisioning step with `trap cleanup EXIT`, pytest in the next step.** *Reason:* the trap fires when that script ends. *Instead:* one script creates, tests and deletes.
- **"Seed idempotently with `ON CONFLICT DO UPDATE`."** *Reason:* it overwrites existing rows. *Instead:* a plain `INSERT`; a clash fails the test.
- **`ASGITransport(app=app)` "to make e2e faster".** *Reason:* the product then runs inside the test: no chart, no image, no hop. *Instead:* that is an integration test; keep it there.
- **`@pytest.mark.quarantine` or `@pytest.mark.skip`.** *Reason:* no issue, no deadline, nothing enforces either. *Instead:* a line in `quarantine-python.txt`.
- **`timeout_method = "thread"`.** *Reason:* seen: the process ends with no teardown and no report. *Instead:* the runner's limit, or the `signal` method.
- **`release: types: [published]` as "pre-release".** *Reason:* it runs after publication. *Instead:* the publishing job `needs` the suite.
- **A journey for every criterion.** *Reason:* it duplicates lower layers in the slowest one. *Instead:* one journey per user goal that needs several deployed parts.

## Output

| File | When to open it |
|---|---|
| `./references/environment.md` | The environment, its script, teardown; a product with Go services too; a run that fails before a test |
| `./references/safety-guards.md` | Anything that decides where requests go: guard, client, seeding, smoke |
| `./references/journeys-and-waiting.md` | Choosing or writing a journey; polling; trace ids |
| `./references/retry-and-quarantine.md` | A flaky journey; how the verdict is computed; `pytest-rerunfailures` |
| `./references/ci-and-release.md` | Triggers, the release gate, permissions, smoke on promotion |
| `./templates/environment-config.md` | Writing `e2e.conf` and values files; suite lines for two languages |
| `./templates/python-suite.md` | Writing the Python files |
| `./templates/direct-database-seed.md` | State no public API can create |
| `./templates/pytest-configuration.md` | Dependencies and settings; what `pytest`, `mypy` and the coverage gate do with the files |
| `./templates/make-targets.md` | Adding `make e2e` |
| `./templates/workflows.md` | The nightly, release and by-hand workflow |
| `./templates/test-report.md` | Reporting a run |
| `./scripts/run-e2e-environment.sh` | Copied to the product; started by `make e2e` |
| `./scripts/run-python-e2e-suite.sh` | Copied to the product; one selection with retry and quarantine |
| `./scripts/validate-python-e2e-tests.sh` | Before hand-off, after every edit |
| `./resources/checklist.md` | Before answering |

In the product: `tests/e2e/support.py`, `tests/e2e/conftest.py`, `tests/e2e/journeys/`, `tests/e2e/smoke/`, `tests/e2e/e2e.conf`, `tests/e2e/values/`, the two scripts, `tests/e2e/quarantine-python.txt` when needed, the `e2e` make targets, `.github/workflows/e2e.yml`, and one report per evidenced run. Browser journeys belong to `react-e2e-testing` and Go journeys to `go-e2e-test`; both run in the same environment as further lines of `E2E_SUITES`.
