---
name: python-load-test
description: >
  Use when test-strategist, platform-engineer or anyone writes, reviews, runs
  or fixes load tests for a Python (FastAPI, uvicorn, asyncpg) service in the
  Quality phase: k6 scripts and thresholds, a load profile from NFR-PERF rows
  and SLOs, uvicorn workers and replicas, the per-process rate limiter and
  when 429 begins, uvicorn's own 503 from --limit-concurrency, asyncpg pool
  exhaustion and acquire timeouts, event-loop lag under load, prometheus
  multiprocess mode, the open arrival-rate model versus locust users and
  coordinated omission, dropped_iterations, smoke, average-load, stress,
  soak, spike and breakpoint tests, k6 exit status 99, the nightly
  indicative check in the kind cluster (make load-indicative), the verdict
  in a designated performance environment (make load-verdict), the
  designation record and signed impact statement, the load-test report, or
  "can we load test staging / production / on every pull request", "replace
  locust", "does it meet the p95 target". Produces load-test-suite.
version: 2.0.0
phase: quality
owner: test-strategist
created: 2026-07-31
tags: [quality, python, fastapi, uvicorn, asyncpg, load-test, k6, slo, nfr, arrival-rate, thresholds, rate-limit, performance-environment]
produces: load-test-suite
domain: testing
status: stable
related: [go-load-test, python-e2e-test, python-performance-test, python-chaos-test, python-integration-test, python-middleware, python-dockerfile, python-makefile, python-service-layer, python-service-skeleton, nfr-specification, slo-definition, test-pyramid, test-fixture-design, prometheus-metrics-design, alerting-rules-design, environment-config, ci-pipeline, cd-pipeline]
sources:
  - research/testing/python-service-saturation-official-docs.md
  - research/testing/k6-gating-and-running-official-docs.md
  - research/testing/k6-official-docs.md
  - research/testing/load-test-method-official-docs.md
  - research/testing/load-test-environment-official-docs.md
  - research/software-architecture/python-backend-development-halstead.md
  - research/devops-and-delivery/site-reliability-engineering-beyer-jones-petoff-murphy.md
  - research/devops-and-delivery/continuous-delivery-humble-farley.md
---

# Python Load Test

## Purpose

This skill owns how a Python product is tested under load: requests driven at the **deployed** service from outside, judged against the targets the product stated. `test-strategist` authors and runs it; `platform-engineer` supplies the environments. The gate, the k6 scripts, the runner, the records and the report writer are the ones `go-load-test` owns, kept here as copies a test holds identical (`tests/scripts/python-load-copies.test.sh`); a product with Go and Python services runs one load suite. What is Python's is the server's shape: the rate limiter, uvicorn's concurrency limit and the database pool are **counted per process**, uvicorn can answer 503 before the application sees a request, a pool waits forever by default, and one blocking call stops the event loop. Halstead's recommendation stands: k6 is the one tool, no locust. In-process speed belongs to `python-performance-test`, injected faults to `python-chaos-test`, the targets to `nfr-specification` and `slo-definition`.

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off.

| # | Rule | Reason |
|---|---|---|
| L1 | **Two tiers.** An **indicative** check in the throwaway kind cluster of the end-to-end run: it catches a regression between runs and **proves nothing about capacity**. A **verdict** against the stated targets only in the product's **designated performance environment**, approved by the product owner per product, sized (workers, replicas, pool) and loaded with data as the requirements state | One shared node that also runs the generator cannot measure capacity; a verdict is only as true as its environment (SRE) |
| L2 | **By default the test refuses any target that is neither the run's own throwaway cluster nor the designated environment: never shared staging, production, a tenant environment or any other undesignated system.** Load goes to another system, staging or production included, only to verify something and only with the product owner's **signed impact statement** of exactly where it runs and what its impact is; the test refuses otherwise, and refuses a run that would exceed it | Load takes a shared system away from everyone and leaves data behind; only the product owner can accept that |
| L3 | **Load starts only through `run-load-test.sh`** (the make targets), never `k6 run`. The address comes from the run marker, the designation record or the signed statement, never from a variable | A wrong variable must not aim load at a real environment |
| L4 | **The profile is derived from the NFR row and the SLO rows, by id.** Numbers the sources do not give are recorded with who decided them. No invented target, no default presented as a fact | A threshold nobody agreed to verifies nothing |
| L5 | **A rate target is tested with the open model** (arrival-rate executors). locust users, `constant_throughput` included, wait for each answer: a closed model | A closed model sends less when the service slows and understates latency (coordinated omission) |
| L6 | **Thresholds mirror the SLI**: its good statuses are declared to k6; latency is judged at the SLO's percentile on good answers only. Never an average. **uvicorn's own 503 counts as the SLI defines it** (a 5xx is bad), and is reported apart from the application's 5xx | k6 counts every status outside 200 to 399 as failed; hiding the server's shedding hides a configuration fault |
| L7 | **429 inside the limiter's design is not a failure.** The profile states **workers × replicas** and the per-process limit; steady load keeps each subject within **one process's** rate, and any 429 there fails its own threshold. The overload check drives one subject past the per-process rate times the processes, where 429 with `Retry-After` is right | The in-memory limiter counts per process: 429 appears only above the total, and unevenly |
| L8 | **Every rule is a threshold.** A bare `check()` is not a gate | `check()` never changes k6's exit status |
| L9 | **k6's exit status is read, never masked**: 99 is a crossed threshold. No pipe, `|| true` or `continue-on-error`. Exit 0 alone is not a pass | A script that throws in every iteration exits 0 |
| L10 | **A run that dropped iterations or saturated its generator is INVALID, not passed**, and INVALID outranks FAIL | The stated load was never offered |
| L11 | **Zero retries.** A second run is a new result | `test-pyramid` |
| L12 | **Never on a pull request.** Indicative: nightly inside the end-to-end run, and by hand. Verdict: before a release, finished before publication. Always through a make target | Slow suites stay out of the pull-request check; a `release:` trigger runs too late |
| L13 | **No stored credential.** Indicative: none at all. Designated environment, or a system under a statement: short-lived tokens the product owner approved, never a standing `LOAD_TEST_TOKEN` | A standing token is a standing way to overload something |
| L14 | **Test data only in the environment under test; third parties are stand-ins; nothing is pushed into any monitoring system.** The service is observed through the environment's own Prometheus, each query pinned to the run: pool in use, event-loop lag, the container's CPU and memory | `test-fixture-design`; a fixed window counts other traffic |
| L15 | **One load tool: k6**, pinned (v2.4.0, AGPL-3.0, a separate program). No locust, no vegeta. A paid service only with the product owner's approval | One gate to keep true; frugality |
| L16 | **A load-test report** under `artifacts/<product>/quality/test-reports/`, approved by the product owner, for every run put forward as evidence | A green job is not an approval |

Every product size follows all sixteen. **Lean** may have only the indicative tier until a performance environment is approved; it never skips load testing and never treats a shared environment as its performance environment.

## What every answer states

**Keep the answer as short as the question.** State, **in words**, each rule above that bears on it; do not only follow it or point at a file.

1. **Whenever a run or a result is mentioned:** which tier it is. For the indicative tier say that it **proves nothing about capacity**; a verdict needs the designated performance environment the product owner approved. A run under an impact statement is a **verification**, not a capacity verdict.
2. **Whenever an environment is mentioned:** by default never shared staging, production, a tenant environment or any other undesignated system; another system only with the product owner's **signed impact statement** of exactly where the load runs and what its impact will be; and the test itself **refuses** otherwise (run marker, signed unexpired designation whose id the environment serves, or the signed statement).
3. **Whenever numbers are mentioned:** the profile comes from the NFR row and the SLO rows, **named by id**; name which numbers were judgement calls and who decides them. With no stated target, say there is nothing to verify and ask for it.
4. **Whenever the workload is described:** the open (arrival-rate) model, and why: a closed model (locust's users) slows its own load when the service slows, so it understates latency.
5. **Whenever errors, 429 or 503 appear:** a 429 within the limiter's design is not unavailability; it begins only above the per-process rate times **workers × replicas**, so steady load keeps each subject within one process's rate and the overload check must exceed the total. uvicorn's own 503 at `--limit-concurrency` counts against the SLI like any 5xx, is told apart from the application's 5xx, and is never added to the good statuses.
6. **Whenever a gate or pipeline is discussed:** a crossed threshold makes k6 exit **99**, which must not be masked; a `check()` alone cannot fail a run; exit 0 alone is not a pass.
7. **Whenever a result is judged:** dropped iterations or a saturated generator make the run **INVALID**, not passed, and say why: the intended load was never offered (too few virtual users, or the service slowed until they ran out, as an exhausted pool does), so the numbers describe a lighter test. **No retries**.
8. **Whenever slowness is diagnosed:** pool exhaustion shows as latency with no error unless the service sets an acquire timeout (the service's decision, `python-service-layer`); a blocked event loop shows in the lag probe; process metrics are Linux-only and several workers need multiprocess mode.
9. **Whenever timing is discussed:** never on a pull request; indicative nightly in the end-to-end run; verdict before publication.
10. **What is refused or replaced, by name, with the reason:** staging or production without a signed statement, `k6 run` by hand, a stored token, locust, a paid service without approval, a retry, an average, pushing metrics to shared monitoring.
11. **Whenever the report is mentioned:** an artifact the product owner approves, saying what the run does not prove.
12. **Whenever credentials are mentioned:** both halves: the indicative tier needs **no stored credential at all**; the designated environment, and a system under a statement, use a **short-lived token the product owner approves**, never a standing secret.
13. **Only where they arise:** k6 is the one tool, v2.4.0, AGPL-3.0; what lean changes.
14. **One line on what was run.** Anything not run (GitHub Actions, a real designated environment, a Python service in a real kind cluster, a long soak, Gunicorn) is called unverified.

## Procedure

1. Read the NFR specification, the SLO record, the test strategy, the rate-limit configuration, the Dockerfile and chart (workers, replicas, `--limit-concurrency`, pool size), the tenancy decision, `sdlc-config.json`, any `tests/load/`, and whether a designation record exists.
2. Derive the profile: read `./references/targets-to-profile.md`, then fill `tests/load/profile.json` from `./templates/profile.md`, `server` block included.
3. Decide the tiers: read `./references/tiers-and-safety.md`. With no approved performance environment, plan the indicative tier only and put the designation to the product owner (`./templates/designation-record.md`).
4. Copy `./scripts/run-load-test.sh`, `./scripts/validate-python-load-tests.sh` and `./scripts/check-python-profile.sh` to `tests/load/` unchanged, and the files of `./templates/k6-scripts.md`; write `journey.js`. Read `./references/gate-and-verdict.md` before touching a threshold.
5. Set up the test subjects (`issue-subjects.sh`); ask the service's owner for the saturation metrics (`./templates/saturation-metrics.md`) if they are missing.
6. Add the make targets and suite lines from `./templates/make-targets.md` and the workflow from `./templates/workflows.md`; read `./references/when-it-runs.md`.
7. Run `make load-validate`; fix every FAIL, judge each WARN, and run it again until clean.
8. Run `make load-indicative`; see the gate fail once for the expected reason, then pass.
9. Where a designation exists, run `make load-verdict`; a verification elsewhere only with `make load-verify` and the signed statement. Read the service's measurements as `./references/python-saturation.md` says.
10. Draft the report with `./scripts/write-load-report.sh <result files>` and `./scripts/sort-server-errors.sh <k6 summaries>`, complete it from `./templates/load-test-report.md`, and put it to the product owner.
11. Tick `./resources/checklist.md`; go back to step 7 after any change. Answer with the statements above.

Worked and run (k6 v2.4.0 against a FastAPI lab service; FastAPI 0.165.0, uvicorn 0.54.0, asyncpg 0.32.0, Python 3.15.2, PostgreSQL 17.12): `./examples/01-lean-seed-library.md` (indicative tier only, a regression), `./examples/02-standard-harbour-berths.md` (two processes, a limiter not multiplied, a verdict), `./examples/03-enterprise-orchard-cooperative.md` (pool exhaustion INVALID, then FAIL, then PASS; a signed statement on staging).

## Gotchas

- **The profile copies `python-middleware`'s 10 a second as the subject's limit.** *Reason:* each process has its own buckets; seen: four workers accepted 219 where 121 were allowed. *Instead:* the per-process rate times workers times replicas; `check-python-profile.sh`.
- **"503s under load, so the app is failing."** *Reason:* uvicorn answers 503 itself at `--limit-concurrency`, counting idle keep-alive connections too; seen: 252 of 324, none reached the app. *Instead:* `sortServerError`; raise the limit above the connections the load needs.
- **Adding 503 to `good_statuses` "because it is deliberate shedding".** *Reason:* the SLI counts a 5xx as bad. *Instead:* report it apart; an SLO change is `slo-definition`'s.
- **"Latency doubled but there are no errors, so the database is fine."** *Reason:* `acquire()` waits forever by default; seen: p(95) 2,198 ms, zero errors, pool 2 of 2. *Instead:* read `db_pool_in_use`; recommend an acquire timeout to the service's owner.
- **Raising virtual users until drops stop, then reading the old run.** *Reason:* it offered less load. *Instead:* INVALID; run again.
- **One `/metrics` scrape of a multi-worker service.** *Reason:* it describes one worker; seen: 215, 131, 132 on successive scrapes. *Instead:* multiprocess mode, or one process per container.
- **`asyncio` debug mode in a measured run "to see slow callbacks".** *Reason:* its checks are too expensive for a measurement. *Instead:* the lag probe.
- **locust with `constant_throughput` "for an open model".** *Reason:* each user still waits for its answer. *Instead:* k6's arrival-rate executors.
- **"The kind run passed, so we meet the p95 target."** *Reason:* the indicative tier judges no target. *Instead:* say indicative, and what a verdict needs.
- **"Staging is fine, the product owner said so in chat."** *Reason:* the test refuses a staging host without a signed statement. *Instead:* the statement file, signed.
- **`LOAD_TEST_TOKEN` in repository secrets; `make load-verdict | tee log`.** *Reason:* a standing credential; a pipe reports 0 for a run that exited 99. *Instead:* per-run tokens; leave the status alone.
- **Proposing 50 users or 30 requests a second "as sensible defaults".** *Reason:* no source gives them. *Instead:* the NFR's number, or a named person's decision.

## Output

| File | When to open it |
|---|---|
| `./references/targets-to-profile.md` | Deriving a profile; workers, replicas and the per-process limiter; open versus closed; test types |
| `./references/gate-and-verdict.md` | Thresholds, 429, the server's own 503, exit statuses, INVALID, what a pass means |
| `./references/tiers-and-safety.md` | Where load may go; the guards; credentials; what each tier does not prove |
| `./references/python-saturation.md` | 503 sources, pool exhaustion, event-loop lag, runtime metrics, Prometheus queries for a run |
| `./references/when-it-runs.md` | Triggers, the release gate, pull requests |
| `./templates/profile.md` | Writing `tests/load/profile.json` |
| `./templates/k6-scripts.md` | The k6 files and the Python `journey.js` |
| `./templates/designation-record.md` | The designation record, the marker, the test subjects, the signed impact statement |
| `./templates/make-targets.md` | Make targets; attaching the indicative tier to the end-to-end environment |
| `./templates/workflows.md` | The verdict workflow; additions to the nightly workflow |
| `./templates/saturation-metrics.md` | Pool and event-loop metrics the service should export |
| `./templates/load-test-report.md` | Reporting a run |
| `./scripts/run-load-test.sh` | Copied to the product; the only way a load test starts |
| `./scripts/validate-python-load-tests.sh` | Before hand-off, after every edit |
| `./scripts/check-python-profile.sh` | With the validator: workers, replicas, the per-process limiter, subjects |
| `./scripts/write-load-report.sh`, `./scripts/sort-server-errors.sh` | Drafting the report from result files and k6 summaries |
| `./resources/checklist.md` | Before answering |

In the product: `tests/load/` (`profile.json`, `designation.json` once approved, `statements/<id>.json`, `lib/gate.js`, `journey.js`, the test-type scripts, `issue-subjects.sh`, `indicative-suites.conf`, `load-e2e.conf`, the three scripts), the `load-*` make targets, `.github/workflows/load-verdict.yml` where a designation exists, and one report per evidenced run.
