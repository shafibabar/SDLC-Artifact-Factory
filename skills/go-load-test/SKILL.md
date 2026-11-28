---
name: go-load-test
description: >
  Use when test-strategist, platform-engineer or anyone writes, reviews, runs
  or fixes load tests for a Go service in the Quality phase: k6 scripts and
  thresholds, deriving a load profile (rate, virtual users, run length, data)
  from NFR-PERF rows and SLOs, the open arrival-rate model versus virtual
  users and coordinated omission, dropped_iterations, smoke, average-load,
  stress, soak, spike and breakpoint tests, 429 and the rate limiter under
  load, backpressure and overload checks, k6 exit status 99, http_req_failed
  and expected statuses, the nightly indicative load check in the kind
  cluster (make load-indicative), the verdict run in a designated performance
  environment (make load-verdict), the designation record, the load-test
  report, or "can we load test staging / production / on every pull request",
  "does it meet the p95 target", "how many users can it take". Also the k6
  scripts and gate python-load-test reuses. Produces load-test-suite.
version: 3.2.0
phase: quality
owner: test-strategist
created: 2026-06-25
tags: [quality, go, load-test, k6, slo, nfr, arrival-rate, thresholds, rate-limit, backpressure, performance-environment]
produces: load-test-suite
domain: testing
status: stable
related: [go-e2e-test, go-performance-test, go-chaos-test, go-integration-test, nfr-specification, slo-definition, test-pyramid, test-fixture-design, go-middleware, prometheus-metrics-design, alerting-rules-design, environment-config, go-makefile, ci-pipeline, cd-pipeline, python-load-test, go-concurrency-patterns]
sources:
  - research/testing/k6-gating-and-running-official-docs.md
  - research/testing/k6-official-docs.md
  - research/testing/load-test-method-official-docs.md
  - research/testing/load-test-environment-official-docs.md
  - research/testing/kind-official-docs.md
  - research/testing/github-actions-e2e-official-docs.md
  - research/devops-and-delivery/site-reliability-engineering-beyer-jones-petoff-murphy.md
  - research/devops-and-delivery/continuous-delivery-humble-farley.md
  - research/software-architecture/concurrency-in-go-cox-buday.md
  - research/software-architecture/designing-data-intensive-applications-kleppmann.md
---

# Go Load Test

## Purpose

This skill owns how a Go product is tested under load: requests driven at the **deployed** system from outside, judged against the targets the product stated. `test-strategist` authors and runs it; `platform-engineer` supplies the environments. A load test tries to slow a system down and its overload scenarios try to break one, so most of this skill is about two things: making it impossible to aim one at a shared or undesignated system without the product owner's signed impact statement, and making its verdict true. In-process benchmarks belong to `go-performance-test`, injected faults to `go-chaos-test`, the requirement and the objective to `nfr-specification` and `slo-definition`. The k6 scripts are language-neutral; `python-load-test` uses the same ones.

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off.

| # | Rule | Reason |
|---|---|---|
| L1 | **Two tiers.** An **indicative** check in the throwaway kind cluster of `go-e2e-test`: it catches a regression between runs and **proves nothing about capacity**. A **verdict** against the stated targets only in the product's **designated performance environment**, approved by the product owner per product, sized and loaded with data as the requirements state | One shared node that also runs the generator cannot measure capacity (kind and runner documentation); a verdict is only as true as its environment (SRE) |
| L2 | **By default the test refuses any target that is neither the run's own throwaway cluster nor the designated environment: never shared staging, production, a tenant environment or any other undesignated system.** Load goes to another system, staging or production included, only to verify something and only with the product owner's **signed impact statement** of exactly where it runs and what its impact is (address, purpose, test type and profile limit, data and its removal, who and what is affected, how to stop it and who watches, time window, sign-off, expiry or single run); the test refuses otherwise, and refuses a run that would exceed the statement | Load takes a shared system away from everyone and leaves data behind; only the product owner can accept that, and only for a stated purpose |
| L3 | **Load starts only through `run-load-test.sh`** (the make targets), never `k6 run`. The address comes from the run marker, the designation record or the signed impact statement, never from a variable or a flag | A wrong variable must not be able to aim load at a real environment |
| L4 | **The profile is derived from the NFR row and the SLO rows, by id.** Numbers the sources do not give (run length, sample size, warm-up, users to rate, data volume, stress level) are recorded with who decided them. No invented target, no default presented as a fact | A threshold nobody agreed to verifies nothing |
| L5 | **A rate target is tested with the open model** (arrival-rate executors). A closed model only where the real callers are a fixed pool, with the reason stated | A closed model sends less when the product slows and understates latency (coordinated omission) |
| L6 | **Thresholds mirror the SLI**: the statuses it counts as good are declared to k6; latency is judged at the SLO's percentile, on good answers only. Never an average | k6 counts every status outside 200 to 399 as failed; an average hides the tail (SRE, Kleppmann) |
| L7 | **429 inside the limiter's design is not a failure.** Steady load is spread over enough subjects to stay within the limit, and any 429 there fails its own threshold. A separate overload check drives one subject past the limit, where 429 with `Retry-After` is the right answer and anything else fails | One subject at the target rate measures the limiter, not the product |
| L8 | **Every rule is a threshold.** A bare `check()` is not a gate | `check()` never changes k6's exit status |
| L9 | **k6's exit status is read, never masked**: 99 is a crossed threshold. No pipe after the runner, no `continue-on-error`. Exit 0 alone is not a pass | A script that throws in every iteration exits 0 |
| L10 | **A run that dropped iterations or saturated its generator is INVALID, not passed** | The stated load was never offered |
| L11 | **Zero retries.** A second run is a new result | A load verdict that passes on the third try is not a pass (`test-pyramid`) |
| L12 | **Never on a pull request.** Indicative: nightly inside the end-to-end environment run, and by hand. Verdict: before a release, finished before publication, or by hand. Always through a make target | Slow suites stay out of the pull-request check; a `release:` trigger runs too late |
| L13 | **No stored credential.** Indicative: none at all. Designated environment, or a system under an impact statement: short-lived tokens the product owner approved, never a standing secret | A standing token for a load tool is a standing way to overload something |
| L14 | **Test data only in the environment under test; third parties are stand-ins; nothing is pushed into any monitoring system.** The product is observed by reading the environment's own Prometheus, each query pinned to the run | `test-fixture-design`; a fixed window counts other traffic |
| L15 | **One load tool: k6**, pinned (v2.4.0, AGPL-3.0, run as a separate program). No vegeta, no locust. A paid load service or larger paid runner only with the product owner's approval | One gate to keep true; frugality |
| L16 | **A load-test report** under `artifacts/<product>/quality/test-reports/`, approved by the product owner, for every run put forward as evidence | A green job is not an approval |

Every product size follows all sixteen. **Lean** may have only the indicative tier until a performance environment is approved; it never skips load testing and never treats a shared environment as its performance environment.

## What every answer states

**Keep the answer as short as the question.** State, **in words**, each rule above that bears on it; do not only follow it or point at a file. Add nothing the request did not ask about beyond one line where it bears on the question.

1. **Whenever a run or a result is mentioned:** which tier it is. For the indicative tier say that it **proves nothing about capacity** and does not show a target is met; a verdict needs the designated performance environment the product owner approved. A run under an impact statement is a **verification**: a result about that system at that time, not a capacity verdict.
2. **Whenever an environment is mentioned:** by default never shared staging, production, a tenant environment or any other undesignated system; another system only with the product owner's **signed impact statement** of exactly where the load runs and what its impact will be; and the test itself **refuses** otherwise: the address comes from the run marker, the signed, unexpired designation record whose id the environment serves back, or the signed statement (its marker too, where the system can serve one).
3. **Whenever numbers are mentioned:** the profile comes from the NFR row and the SLO rows, **named by id**; name which numbers were judgement calls and who decides them. With no stated target, say there is nothing to verify and ask for it; do not supply one.
4. **Whenever the workload is described:** the open (arrival-rate) model, and why: a closed model slows its own load when the product slows, so it understates latency.
5. **Whenever errors or 429 appear:** a 429 within the limiter's design is not unavailability; steady load stays within the per-subject limit and a 429 there fails a separate threshold; in the overload check 429 with `Retry-After` is the correct answer. k6 counts 429 as failed unless the expected statuses are declared.
6. **Whenever a gate or pipeline is discussed:** a crossed threshold makes k6 exit **99**, which must not be masked; a `check()` alone cannot fail a run; exit 0 alone is not a pass.
7. **Whenever a result is judged:** dropped iterations or a saturated generator make the run **INVALID**, not passed, and say why in words: the generator ran out of virtual users (or CPU), so the intended load was never offered and the numbers describe a lighter test; the fix is more virtual users or a bigger generator, then a re-run. **No retries**.
8. **Whenever timing is discussed:** never on a pull request; indicative nightly in the end-to-end run; verdict before publication.
9. **What is refused or replaced, by name, with the reason** and the compliant version: staging or production without a signed impact statement, `k6 run` by hand, a stored token, vegeta or locust, a paid service without approval, a retry, an average, pushing metrics to shared monitoring.
10. **Whenever the report is mentioned:** it is an artifact the product owner approves, and it says what the run does not prove.
11. **Whenever credentials or a token are mentioned:** say both halves in words: the indicative tier in the throwaway cluster needs **no stored credential at all**; the designated environment, and a system under an impact statement, use a **short-lived token the product owner approves** for the run, never a standing secret.
12. **Only where they arise:** k6 is the one tool, v2.4.0, AGPL-3.0; what lean changes.
13. **One line on what was run.** Anything not run (GitHub Actions, a real designated environment, a long soak, large data) is called unverified.

## Procedure

1. Read the NFR specification, the SLO record, the test strategy, the rate-limit configuration, `sdlc-config.json`, any `tests/load/`, and whether a designation record exists.
2. Derive the profile: read `./references/targets-to-profile.md`, then fill `tests/load/profile.json` from `./templates/profile.md`. Every number has a source id or a named decider.
3. Decide the tiers: read `./references/tiers-and-safety.md`. With no approved performance environment, plan the indicative tier only and put the designation to the product owner (`./templates/designation-record.md`). Load on any other system needs the product owner's signed impact statement from the same file.
4. Copy `./scripts/run-load-test.sh` and `./scripts/validate-go-load-tests.sh` to `tests/load/` unchanged, and the scripts from `./templates/k6-scripts.md`: `lib/gate.js` and the test-type scripts unchanged; write `journey.js`. Read `./references/gate-and-verdict.md` before touching a threshold.
5. Set up the test subjects (`issue-subjects.sh` in `./templates/designation-record.md`).
6. Add the make targets and the suite lines from `./templates/make-targets.md`; add the workflow from `./templates/workflows.md`. Read `./references/when-it-runs.md` for the release gate.
7. Run `./scripts/validate-go-load-tests.sh <product root>`; fix every FAIL, judge each WARN, and run it again until clean.
8. Run `make load-indicative`. See the gate fail once for the expected reason (slow the product, or break the expectation), then pass. Confirm the cluster is gone.
9. Where a designation exists, run `make load-verdict`; a verification on any other system runs only with `make load-verify` and the product owner's signed impact statement. Read the product's own measurements as `./references/observing-the-run.md` says.
10. Draft the report with `./scripts/write-load-report.sh <result files>`, complete it from `./templates/load-test-report.md`, write it under `artifacts/<product>/quality/test-reports/`, and put it to the product owner.
11. Tick `./resources/checklist.md`; go back to step 7 after any change. Answer with the statements above.

Worked and run (k6 v2.4.0, kind v0.33.0, Helm v4.3.2, Go 1.27.4): `./examples/01-lean-ski-lift-status.md` (indicative tier only), `./examples/02-standard-parcel-lockers.md` (a designated environment and a verdict, both ways), `./examples/03-enterprise-school-meals.md` (tenants, an invalid run, a breakpoint measurement, the release gate).

## Gotchas

- **One token at the target rate.** *Reason:* the per-subject limiter answers 429; seen: 60% "failed" on a healthy service. *Instead:* enough subjects that each stays under the limit; the script refuses otherwise.
- **`http_req_failed: rate<0.005` as "the availability SLO".** *Reason:* k6's default counts every 4xx as failed, the SLI does not. *Instead:* declare the SLI's good statuses with `expectedStatuses`.
- **A `check()` for "sheds with 429".** *Reason:* seen: every check failed and k6 exited 0. *Instead:* thresholds on custom metrics.
- **"k6 exited 0, so it passed."** *Reason:* seen: every iteration threw and k6 exited 0; `--no-thresholds` also exits 0. *Instead:* the runner's verdict, which needs requests, thresholds and a summary.
- **`ramping-vus` to find the breaking point.** *Reason:* it throttles itself as the product slows; seen: p(99) 23 ms closed against 4,801 ms open for the same stall. *Instead:* `ramping-arrival-rate` with `abortOnFail`.
- **Raising virtual users until drops stop, then reading the old run.** *Reason:* a run with dropped iterations offered less load. *Instead:* it is INVALID; run again.
- **"The kind run passed, so we meet the p95 target."** *Reason:* the indicative tier judges no target. *Instead:* say indicative, and what a verdict needs.
- **"Staging is fine, the product owner said so in chat."** *Reason:* the test refuses a staging host without a signed statement. *Instead:* the impact statement file, signed, with its address, impact, window and limits.
- **`BASE_URL` from the environment "for flexibility".** *Reason:* one wrong value aims overload at a real system; `127.0.0.1` alone proves nothing. *Instead:* the run marker, the designation record or the signed impact statement.
- **`LOAD_TEST_TOKEN` in repository secrets.** *Reason:* a standing credential. *Instead:* tokens issued for the run and deleted after it.
- **`make load-verdict | tee log`, `|| true`, `continue-on-error`.** *Reason:* seen: a pipe reported 0 for a run that exited 99. *Instead:* leave the status alone; results are already in files.
- **`increase()` on a queue-depth or lag gauge.** *Reason:* Prometheus answers with a number and only a note. *Instead:* `max_over_time()` or `delta()`.
- **A `[2h]` window "to cover the run".** *Reason:* it counts other traffic. *Instead:* pin the query to the run's start and end.
- **Starting the first load line the moment the port opens.** *Reason:* seen: ten of ten smoke requests ended in `EOF`. *Instead:* the runner polls until the product answers.
- **`--out experimental-prometheus-rw` into the environment's Prometheus.** *Reason:* deprecated in k6 v2.4.0, and it writes into monitoring others rely on. *Instead:* results in files; read the product's own metrics.
- **Proposing 50 users, 30 requests a second or two hours "as sensible defaults".** *Reason:* no source gives them. *Instead:* the NFR's number, or a named person's decision in the profile.

## Output

| File | When to open it |
|---|---|
| `./references/targets-to-profile.md` | Deriving a profile; open versus closed; which test type; what the sources do not give |
| `./references/gate-and-verdict.md` | Thresholds, 429, exit statuses, INVALID, the indicative comparison, what a pass means |
| `./references/tiers-and-safety.md` | Where load may go; the guards; credentials; what each tier does not prove |
| `./references/observing-the-run.md` | Reading the product's metrics for a run; asynchronous work |
| `./references/when-it-runs.md` | Triggers, the release gate, pull requests |
| `./templates/profile.md` | Writing `tests/load/profile.json` |
| `./templates/k6-scripts.md` | The k6 files; which test type proves what |
| `./templates/designation-record.md` | The designation record, the marker, the test subjects, and the signed impact statement for load on any other system |
| `./templates/make-targets.md` | Make targets; attaching the indicative tier to the end-to-end environment |
| `./templates/workflows.md` | The verdict workflow; additions to the nightly workflow |
| `./templates/load-test-report.md` | Reporting a run |
| `./scripts/run-load-test.sh` | Copied to the product; the only way a load test starts |
| `./scripts/validate-go-load-tests.sh` | Before hand-off, after every edit |
| `./scripts/write-load-report.sh` | Drafting the report from result files |
| `./resources/checklist.md` | Before answering |

In the product: `tests/load/` (`profile.json`, `designation.json` once approved, `statements/<id>.json` for each signed impact statement, `lib/gate.js`, `journey.js`, one script per planned test type, `issue-subjects.sh`, `indicative-suites.conf`, `load-e2e.conf`, the two scripts), the `load-*` make targets, `.github/workflows/load-verdict.yml` where a designation exists, and one report per evidenced run.
