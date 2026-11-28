---
name: go-e2e-test
description: >
  Use when test-strategist, platform-engineer or anyone writes, reviews, runs
  or fixes end-to-end tests for a Go product in the Quality phase: journey
  tests through the deployed services over real network hops, the throwaway
  kind cluster and the one script that creates it, installs every Helm chart,
  runs the tests and tears it down (make e2e), kubeconfig and kube-context
  isolation, Helm 4 --wait and kubectl rollout readiness, the e2e and smoke
  build tags, read-only smoke tests on promotion (-tags smoke), seeding test
  data, polling instead of time.Sleep, OpenTelemetry traceparent trace id on
  failure, one retry and quarantine of a flaky journey, nightly and
  before-release e2e workflow, release published trigger, logs on failure, the
  end-to-end test report, or "can we run e2e against staging / with Docker
  Compose / on every pull request". Also the environment python-e2e-test and
  react-e2e-testing run in. Produces go-e2e-test-suite.
version: 3.0.0
phase: quality
owner: test-strategist
created: 2026-06-25
tags: [quality, go, e2e, end-to-end, kind, helm, smoke, journey, quarantine, trace-correlation, ci]
produces: go-e2e-test-suite
domain: testing
status: stable
related: [test-pyramid, test-fixture-design, acceptance-criteria, go-integration-test, go-unit-test, go-makefile, helm-chart, environment-config, ci-pipeline, cd-pipeline, blue-green-deployment, disaster-recovery-plan, react-e2e-testing, python-e2e-test, distributed-tracing-design, sdlc-config-management, uat-plan, go-load-test]
sources:
  - research/testing/kind-official-docs.md
  - research/testing/helm-official-docs.md
  - research/testing/kubectl-official-docs.md
  - research/testing/opentelemetry-go-trace-context-official-docs.md
  - research/testing/github-actions-e2e-official-docs.md
  - research/testing/github-actions-official-docs.md
  - research/testing/go-toolchain-official-docs.md
  - research/testing/unit-testing-khorikov.md
  - research/testing/agile-testing-crispin-gregory.md
  - research/testing/testing-web-apis-winteringham.md
  - research/testing/testing-vv-dictionary-quigley.md
  - research/devops-and-delivery/continuous-delivery-humble-farley.md
  - research/devops-and-delivery/cloud-native-devops-kubernetes-arundel-domingus.md
  - research/software-architecture/building-microservices-newman.md
---

# Go End-to-End Test

## Purpose

This skill owns how a Go product is tested end to end: a few journeys driven through the **deployed** services, and the environment they run in, which the Python and browser suites share. `test-strategist` authors and runs it; `platform-engineer` supplies the charts. End-to-end tests create and delete data, so most of this skill is about making it impossible for them to do that anywhere but in a cluster their own run created. Policy on layers, retries and when suites run belongs to `test-pyramid`; test data rules to `test-fixture-design`.

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off.

| # | Rule | Reason |
|---|---|---|
| E1 | **Few journeys, each traced to acceptance criteria (`AC-US-n.m`), each needing more than one deployed part.** Everything else is proven at a lower layer | The top layer is the slowest and most brittle (Crispin and Gregory); the pyramid's shape follows from proving each behaviour at the lowest layer that can (Khorikov, `test-pyramid`) |
| E2 | **The environment is a throwaway Kubernetes cluster (kind) created for the run**, holding every chart of the product, the web shell and the dependencies. Never Docker Compose. **Never a shared, staging, production or tenant environment** | Journeys write and delete. Compose is a second deployment description (`environment-config`) |
| E3 | **One script creates the cluster, installs, waits, runs the suites, collects evidence and always deletes the cluster**, also when a suite fails or the run is interrupted. Teardown is a step of that script, not only an exit trap | A provisioning script with an exit trap deletes the cluster before the tests start |
| E4 | **Every `kind`, `helm` and `kubectl` command names the kubeconfig file created for the run** and its context. Never the caller's kubeconfig or current context, never `use-context` | Without it the command acts on whatever cluster the caller last used |
| E5 | **Journeys refuse to start unless their target is their own run's cluster**, proven by a marker the script put in it. Addresses come only from that marker; a client reaches one address and refuses any other | A wrong variable must not be able to aim a write at a real environment |
| E6 | **Every end-to-end file is a `_test.go` file with a build tag**; journeys are `e2e && !smoke`. `make ci` and the coverage gates never compile them | Go tags only add files: a file with no tag joins every build |
| E7 | **Smoke tests are read-only**, in files tagged `smoke`, and the smoke build cannot compile or send a write. A selection that runs no test fails. Smoke is the only selection that may address a deployed environment | It runs on every promotion, against real data |
| E8 | **Test data is created through the public API.** A direct database write only inside the throwaway cluster, as a plain `INSERT`, never an upsert. Each test removes exactly what it created | An upsert overwrites rows that were already there (`test-fixture-design`) |
| E9 | **Wait by polling with a deadline**, in tests and in the script. No `time.Sleep`, no `sleep` | A fixed wait is either flaky or slow (Winteringham) |
| E10 | **A failed journey prints a trace id that the services received**: SDK tracer provider, W3C propagator, instrumented client, span ended | With no SDK the id is all zeros and no header is sent |
| E11 | **Flaky tests follow `test-pyramid`**: one retry, by exact name; quarantine with an issue and a deadline; red at the deadline. No `t.Skip`, no rerun-until-green | A retried pass is flaky, not green |
| E12 | **Never on a pull request. Nightly, before a release (finishing before publication) and by hand**, always through `make e2e`. No stored credential, `permissions: contents: read`, no cloud resource created or deleted | A `release: published` run starts after the release is out |
| E13 | **Evidence on failure** (all logs of every Pod, events, cluster state) **and a test report** under `artifacts/<product>/quality/test-reports/`, approved by the product owner | A red run nobody can diagnose gets re-run, not fixed |

Every product size follows all thirteen. **Lean** means fewer releases and fewer journeys, never no journeys, a lighter stand-in or a shared environment.

## What every answer states

**Keep the answer as short as the question.** State, **in words**, each rule above that bears on it; do not only follow it or point at a file. Add nothing the request did not ask about beyond one line where it bears on the question.

1. **Whenever an environment is mentioned:** the suite runs only in a throwaway kind cluster that its own run creates and deletes, **at every product size, lean included** (say those words when the product is lean or a lighter stand-in such as Docker Compose is proposed); it never runs against a shared, staging, production or tenant environment; every `kind`, `helm` and `kubectl` command uses the run's own kubeconfig file, never the caller's current context; the journeys refuse to start if the cluster does not carry their run's marker.
2. **Whenever smoke tests are mentioned:** they only read; they are in separately tagged files, so a journey that creates or deletes data cannot be part of the selection (`-tags smoke` adds files, it removes none, which is why journeys are tagged `e2e && !smoke`); the smoke client refuses every write; a selection that runs no test fails; smoke is the one selection that may address a deployed environment.
3. **Whenever seeding or test data is mentioned:** through the public API; a direct write only in the throwaway cluster, plain `INSERT`, never an upsert; seeding and deletion refuse any address that is not the run's own; each test removes what it created, also when it fails.
4. **What is refused or replaced, by name, with the reason** and the compliant version: Docker Compose, staging as the journey target, a pull-request trigger, `release: published` as the pre-release gate, `--rollback-on-failure`, a sleep, a skip, a rerun loop.
5. **Readiness and teardown, when the script or a pipeline is discussed:** Helm 4 needs `--wait` written out (without it Helm waits for hooks only and reports success with no Pod ready); the script then waits for each rollout; teardown runs on failure and on interruption and is done by the script itself.
6. **A failure report:** which test, first attempt and retry, the trace id, where the evidence is. A test that passed only on the retry is called flaky. **Whenever the test report is mentioned:** it is an artifact the product owner approves; a chat message or a dashboard does not replace that approval.
7. **Only where they arise:** what lean changes and what it does not; what the kind cluster does not prove (one node, no cloud load balancer, a mesh or ingress only if installed); decisions for the product owner (a copy of real data, approval of the report).
8. **One line on what was run.** Anything not run, including every GitHub Actions behaviour, is called unverified.

## Procedure

1. Read the test strategy (journeys and smoke subset), the acceptance criteria, the deployment plan and charts, `sdlc-config.json`, and any existing `tests/e2e/`.
2. Choose the journeys: read `./references/journeys-and-waiting.md`. Push down whatever one deployed part can prove alone.
3. Set up the environment: copy `./scripts/run-e2e-environment.sh` and `./scripts/run-go-e2e-suite.sh` to `tests/e2e/` unchanged; fill `tests/e2e/e2e.conf` and one values file per release from `./templates/environment-config.md`. List **every** release. Read `./references/environment.md` before changing how anything is created, awaited or deleted.
4. Copy the suite from `./templates/go-suite.md`: guard, client, polling, tracing and self-checks unchanged; then write the seed helpers, one journey per user goal and the smoke tests. Read `./references/safety-guards.md` first. For state with no public route, read `./templates/direct-database-seed.md`.
5. Add the make targets from `./templates/make-targets.md` and the workflow from `./templates/workflows.md`; read `./references/ci-and-release.md` for the release gate.
6. Run `./scripts/validate-go-e2e-tests.sh <product root>`; fix every FAIL, judge each WARN, and run it again until clean.
7. Run `make e2e`. See each new journey fail once for the expected reason (break the behaviour or the expectation), then pass. Confirm the cluster is gone afterwards.
8. For a flaky or quarantined test read `./references/retry-and-quarantine.md`.
9. Fill `./templates/test-report.md` from `e2e-evidence/` and write it under `artifacts/<product>/quality/test-reports/`; put it to the product owner.
10. Tick `./resources/checklist.md`; go back to step 6 after any change. Answer with the statements above.

Worked and run (kind v0.33.0, Helm v4.3.2, Go 1.27.4): `./examples/01-lean-beekeepers-inspections.md` (one service, its database and the web shell, in the full cluster), `./examples/02-standard-observatory-bookings.md` (two services, an asynchronous hop, a failing and a flaky run), `./examples/03-enterprise-blood-donation.md` (tenants, a quarantined test, the release gate, smoke on promotion).

## Gotchas

- **"`-tags smoke` runs only the smoke tests."** *Reason:* tags add files; every untagged file runs too. *Instead:* tag every file; journeys `e2e && !smoke`.
- **A provisioning step with `trap cleanup EXIT`, tests in the next step.** *Reason:* the trap fires when that script ends. *Instead:* one script creates, tests and deletes.
- **`helm install` without `--wait` "succeeded".** *Reason:* Helm 4 waits for hooks only; seen: exit 0 with 0 of 1 Pods. *Instead:* `--wait=watcher --wait-for-jobs --timeout`, then `kubectl rollout status`.
- **`--rollback-on-failure` (or `--atomic`) for a clean failure.** *Reason:* it uninstalls the release, and the failed Pods' logs go with it. *Instead:* leave it out; the cluster is deleted anyway.
- **`kind create cluster` without `--kubeconfig`.** *Reason:* seen: it switches the caller's current context to the new cluster. *Instead:* a kubeconfig file for the run, named on every command.
- **`kubectl wait pod -l ...` right after an install.** *Reason:* a selector that matches nothing fails at once. *Instead:* wait for the workload's rollout.
- **`kubectl logs -l ...` as evidence.** *Reason:* with a selector it prints 10 lines. *Instead:* `--tail=-1`, per Pod.
- **Reading the base URL from an environment variable.** *Reason:* one wrong value aims the journeys at a real environment; `127.0.0.1` alone proves nothing (a port-forward). *Instead:* addresses from the run marker.
- **"Seed idempotently with `ON CONFLICT DO UPDATE`."** *Reason:* it overwrites existing rows. *Instead:* a plain `INSERT`; a clash fails the test.
- **`otel.Tracer(...).Start` with no setup.** *Reason:* all-zero id, no header; also nothing is sent if the client was built before the propagator was set. *Instead:* `setupTracing()` first, then the client.
- **`go test ... || go test -run "$(failed)"`.** *Reason:* an empty list reruns everything; a zero-test selection exits 0. *Instead:* `run-go-e2e-suite.sh`.
- **`release: types: [published]` as "pre-release".** *Reason:* it runs after publication. *Instead:* the publishing job `needs` the suite.
- **A helper in a plain `.go` file behind a tag.** *Reason:* the coverage gates cannot measure it and block. *Instead:* `_test.go` files only.
- **Starting the script with `&` from another script.** *Reason:* SIGINT is then ignored and cannot be trapped. *Instead:* run it in the foreground; SIGTERM still works.
- **A journey for every criterion.** *Reason:* it duplicates lower layers in the slowest one. *Instead:* one journey per user goal that needs several deployed parts.

## Output

| File | When to open it |
|---|---|
| `./references/environment.md` | Creating, awaiting, reaching or deleting the environment; a run that fails before a test |
| `./references/safety-guards.md` | Anything that decides where requests go: guard, seeding, smoke |
| `./references/journeys-and-waiting.md` | Choosing or writing a journey; polling; trace ids |
| `./references/retry-and-quarantine.md` | A flaky journey; how the verdict is computed |
| `./references/ci-and-release.md` | Triggers, the release gate, permissions, smoke on promotion |
| `./templates/environment-config.md` | Writing `e2e.conf` and values files |
| `./templates/go-suite.md` | Writing the Go files |
| `./templates/direct-database-seed.md` | State no public API can create |
| `./templates/make-targets.md` | Adding `make e2e` |
| `./templates/workflows.md` | The nightly, release and by-hand workflow |
| `./templates/test-report.md` | Reporting a run |
| `./scripts/run-e2e-environment.sh` | Copied to the product; started by `make e2e` |
| `./scripts/run-go-e2e-suite.sh` | Copied to the product; one selection with retry and quarantine |
| `./scripts/validate-go-e2e-tests.sh` | Before hand-off, after every edit |
| `./resources/checklist.md` | Before answering |

In the product: `tests/e2e/*_test.go`, `tests/e2e/e2e.conf`, `tests/e2e/values/`, the two scripts, `tests/e2e/quarantine.txt` when needed, the `e2e` make targets, `.github/workflows/e2e.yml`, and one report per evidenced run. Browser journeys belong to `react-e2e-testing` and Python journeys to `python-e2e-test`; both run in this environment as further lines of `E2E_SUITES`.
