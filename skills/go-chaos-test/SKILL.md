---
name: go-chaos-test
description: >
  Use when test-strategist or anyone writes, reviews, runs or fixes chaos or
  fault-injection experiments for a Go service in the Quality phase: proving a
  circuit breaker, retry with backoff and jitter, timeout and deadline
  propagation, bulkhead, graceful degradation, load shedding or lock order
  under an injected fault; a fault-injecting http.RoundTripper, a build-tagged
  chaos hook, Toxiproxy toxics, Chaos Mesh PodChaos, NetworkChaos or Schedule
  on kind; the steady-state hypothesis on the SLO, blast radius, abort
  conditions and fault removal; the chaos run in the throwaway cluster (make
  chaos), the signed chaos statement for any other system, PASS, FAIL,
  REFUSED or INVALID, the chaos-experiment report; or "kill pods in
  production", "run chaos on staging", "is one fast failure proof the breaker
  works", "add chaos to the pull request". Produces chaos-experiment-suite.
version: 3.0.0
phase: quality
owner: test-strategist
created: 2026-06-25
tags: [quality, go, chaos, fault-injection, resilience, circuit-breaker, retry, bulkhead, toxiproxy, chaos-mesh, kind, steady-state, abort]
produces: chaos-experiment-suite
domain: testing
status: stable
related: [go-e2e-test, go-load-test, go-integration-test, integration-design, slo-definition, prometheus-metrics-design, test-pyramid, go-concurrency-patterns, go-middleware, go-error-handling, disaster-recovery-plan, ci-pipeline, go-makefile, python-chaos-test, test-fixture-design, glossary-management]
sources:
  - research/testing/chaos-engineering-method-official-docs.md
  - research/testing/chaos-mesh-and-toxiproxy-details-official-docs.md
  - research/testing/go-resilience-fault-injection-official-docs.md
  - research/testing/toxiproxy-official-docs.md
  - research/testing/chaos-mesh-official-docs.md
  - research/testing/kind-official-docs.md
  - research/testing/kubectl-official-docs.md
  - research/testing/helm-official-docs.md
  - research/testing/go-toolchain-official-docs.md
  - research/devops-and-delivery/site-reliability-engineering-beyer-jones-petoff-murphy.md
  - research/devops-and-delivery/devops-handbook-kim-humble-debois-willis.md
  - research/software-architecture/building-microservices-newman.md
  - research/software-architecture/concurrency-in-go-cox-buday.md
---

# Go Chaos Test

## Purpose

This skill owns how a Go product's resilience patterns are proven under a deliberately injected fault: a dependency that answers late, fails or vanishes; a pod killed; a network cut. `test-strategist` authors and runs it. An experiment states a steady state on the product's own SLI before anything is injected, injects one fault, and tries to disprove that users keep getting what the SLO promises (Principles of Chaos Engineering; Netflix's ChAP). Each pattern is then proven by its defined behaviour, measured, never by "it failed fast once". Most of the rest is about where a fault may go: a chaos experiment is an attempt to break something. The patterns' definitions and thresholds belong to `integration-design`; their code to the Go build skills; the throwaway cluster to `go-e2e-test`; load as the stressor to `go-load-test`; DLQ, idempotency and 429 behaviour to `go-integration-test`.

## Fixed rules

A request does not change these, whoever makes it. Do the work as the rules require, say where it differs from what was asked and why, and never offer to switch a rule off.

| # | Rule | Reason |
|---|---|---|
| C1 | **Where: by default only the run's own throwaway kind cluster** (`go-e2e-test`'s environment). Any other system (a designated environment, staging, production) only with the product owner's **signed chaos statement** of exactly where, which faults and their limits, the blast radius, the abort conditions and the impact; the runner **refuses** otherwise, with nothing injected, and refuses an experiment beyond what was signed | A fault on a shared system is an incident for everyone on it; only the product owner can accept that, case by case |
| C2 | **The privileged injector (Chaos Mesh) only inside the throwaway cluster.** Its daemon runs with host PID, privileged and host mounts, and the chart creates ClusterRoles even when namespaced | Equivalent to root on every node it runs on |
| C3 | **Application-level and proxy faults first**: a fault-injecting `RoundTripper` or a build-tagged hook, then Toxiproxy. Cluster faults (pod kill, network) in the throwaway cluster at every product size | The narrowest tool that produces the fault is the most deterministic |
| C4 | **No standing production chaos.** Experiments run on a schedule in the throwaway cluster; a production experiment needs a signed statement each time | Decision of 2026-11-28 |
| C5 | **The steady state is the SLO's own SLI, written before injection** (the share of requests answered good under the threshold, exactly as `slo-definition` defines it; never "p99 < 800ms"), measured from outside, and it must hold before the fault or the run is INVALID | An output the user sees, not an internal (POC); no baseline, no result |
| C6 | **A pattern is proven only by a measurable assertion of its defined behaviour**, against the product's own configured thresholds (`integration-design`): table below. Every fault's injection error is checked and the fault confirmed active | One fast failure proves no breaker (seen: the old test passed with a breaker that could never open) |
| C7 | **Abort conditions are numbers set before injection** (SLI below x over y seconds, z seconds in all); the abort removes the fault and ends the experiment | A threshold chosen while watching is no rail |
| C8 | **The fault is always removed, on pass, failure, abort and interruption, and its removal verified** (Toxiproxy no longer lists the toxic; the Chaos Mesh object is gone) | A left fault poisons every later test |
| C9 | **Verdicts: PASS, FAIL, REFUSED, INVALID.** A fault never confirmed active, or a steady state that did not hold before it, is INVALID, never passed | An experiment that injected nothing proves nothing |
| C10 | **No retries.** One run, one result | `test-pyramid`: zero retries below end-to-end |
| C11 | **Every chaos file carries `//go:build chaos`**; chaos never runs in `make ci` or on a pull request; it starts only through `run-chaos-experiment.sh` | W3-D10; the address comes from the run marker or the statement, never from a variable |
| C12 | **Test what the product implements, and name a missing pattern as missing.** Do not invent a breaker for the product; building it is a gap for the Go build skills | Decision of 2026-11-28 |
| C13 | **DLQ, idempotency and 429 are proven in `go-integration-test`**; here they are only confirmed to hold while a fault is active | W3-D23 |
| C14 | **A chaos-experiment report** under `artifacts/<product>/quality/test-reports/`, approved by the product owner | D048.5 |

Every product size follows all fourteen; size changes how many experiments, never which rules.

## What each pattern must show

| Pattern | Assertion (thresholds read from the product's config) | Fails on |
|---|---|---|
| Circuit breaker | Closed below the threshold; open at exactly it; while open every call fails fast and the dependency counts **zero** calls; half-open after the reset (not before) and admits one probe; a failed probe reopens; a good probe closes | No threshold; one-call tests |
| Retry | Exactly the attempt cap reaches the dependency; each wait within its doubling cap, with jitter; a permanent answer is tried once; the caller's deadline stops it; a dependency that stays down receives at most threshold × attempts | No bound; a retry storm |
| Timeout | The call returns by the caller's deadline with `context.DeadlineExceeded`, and the dependency sees its request end then | A deadline not propagated |
| Bulkhead | One downstream's full pool refuses at once; another downstream is still served | A shared pool |
| Degradation, shedding | The answer the SLI counts: 200 under the threshold, marked degraded; over the limit, 503 with `Retry-After` at once | No fallback; no limit |
| Lock order | Moves in both directions under contention all complete; a partial deadlock shows as progress stopped with goroutines flat and CPU idle, a livelock with CPU pegged | An inverted order |

Detail, the integration-design numbers and the event-driven rows: `./references/patterns-and-assertions.md`.

## What every answer states

**Keep the answer as short as the question.** State, **in words**, each point below that bears on it; do not only follow it or point at a file.

1. **Where it runs:** by default only the run's own throwaway kind cluster; any other system, staging and production included, only under the product owner's **signed chaos statement** (where, which faults, blast radius, abort conditions, impact), and the runner **refuses** otherwise, with nothing injected.
2. **Chaos Mesh only inside the throwaway cluster** (privileged daemon, host PID); application-level and Toxiproxy faults first.
3. **The steady-state hypothesis on the SLO's output metric**, named by its id and worded as the SLO defines it, measured before injection.
4. **Each pattern's measurable assertion** from the table, never "it failed fast".
5. **The abort conditions as numbers**, and that the fault is removed on every path and its **removal verified**.
6. **INVALID** when the fault was never confirmed active or the steady state did not hold before it; **no retries**.
7. **Never on a pull request**, never in `make ci`; scheduled in the throwaway cluster, no standing production chaos.
8. **A pattern the product lacks is named as missing**, not built in the test.
9. **The report is an artifact the product owner approves**, and says what the run does not prove.
10. **One line on what was run**; anything not run is called unverified.

## Procedure

1. Read the SLO record, `integration-design`'s inventory for each downstream, the product's client code (which patterns exist, with which settings), the test strategy and `sdlc-config.json`. List each pattern as present (with its settings) or **missing**.
2. Plan: read `./references/where-it-runs.md`. Default target: the throwaway cluster. Any other system: draft `./templates/chaos-statement.md` for the product owner to sign; until signed, plan nothing there.
3. Write one experiment definition per hypothesis from `./templates/experiment-definition.md`: steady state from the SLO, fault, blast radius, abort numbers. Read `./references/experiment-method.md` first.
4. Copy the test support unchanged (`./templates/chaostest-package.md`); write the pattern tests from `./templates/pattern-tests.md` against the product's own client and config.
5. Add Toxiproxy (`./templates/toxiproxy-setup.md`) and, for cluster faults, Chaos Mesh (`./templates/chaos-mesh-manifests.md`, `./references/chaos-mesh-on-kind.md`).
6. Copy `./scripts/run-chaos-experiment.sh` and `./scripts/validate-go-chaos-tests.sh` to `tests/chaos/` unchanged; add the suite lines, make targets and workflow from `./templates/environment-and-make.md`.
7. Run `./scripts/validate-go-chaos-tests.sh <product root>`; fix every FAIL, judge each WARN, and run it again until clean.
8. Run `make chaos`. Break one pattern on purpose and see its experiment fail for that reason, then restore it. Confirm the cluster is gone.
9. Write the report from `./templates/chaos-experiment-report.md` under `artifacts/<product>/quality/test-reports/` and put it to the product owner; a FAIL becomes a corrective action for the owning build skill.
10. Tick `./resources/checklist.md`; after any change, go back to step 7.

Worked: `./examples/01-lean-allotment-waitlist.md` (one downstream, no breaker: named missing), `./examples/02-standard-harbour-pilots.md` (the lab that was run: every pattern both ways, Toxiproxy and Chaos Mesh on kind), `./examples/03-enterprise-regional-bus-fares.md` (several downstreams, a signed statement for one production check).

## Gotchas

- **One call with a latency toxic, asserting a fast error, as "the breaker test".** *Reason:* seen: it passed with a breaker whose threshold could never trip, because the attempt timeout alone returned a fast error. *Instead:* drive past the threshold and assert every state, counting calls at the dependency.
- **`_, _ = proxy.AddToxic(...)`.** *Reason:* seen: a misspelt toxic type was refused (HTTP 400), nothing was injected, and the "service survives" test passed on a product with no fallback. *Instead:* `chaostest.AddToxic`, which marks the run INVALID.
- **A breaker counting each retry.** *Reason:* `integration-design` nests retry inside the breaker, so one failed call is one breaker failure; counting attempts trips it three times too early. *Instead:* assert at the call level.
- **Using gobreaker's default `ReadyToTrip`.** *Reason:* it trips after **more than** five failures; `integration-design` says at five. *Instead:* read the product's setting; the lab sets `>= 5`.
- **An attempt timeout mapped to the caller's deadline error.** *Reason:* seen in the lab: `errors.Is(err, context.DeadlineExceeded)` was true for the dependency's own timeout, so the product surfaced it as the caller's. *Instead:* check `ctx.Err()` of the caller.
- **A test with no deadline of its own around a retry.** *Reason:* seen: with the bound removed, the test hung instead of failing. *Instead:* bound every call (`callCtx`).
- **`clusterScoped: false` for Chaos Mesh on kind.** *Reason:* seen with 2.8.8: the controller could not list RemoteCluster at cluster scope, its caches never synced and no experiment was injected. *Instead:* the chart's default scope, inside the throwaway cluster only, with every selector held to one namespace by the runner.
- **`spec.scheduler` in a manifest.** *Reason:* removed in Chaos Mesh 2.0; seen: `strict decoding error: unknown field "spec.scheduler"`. *Instead:* a `Schedule` resource.
- **`kubectl apply` of a chaos manifest by hand, or `go test -tags chaos` without `-count=1`.** *Reason:* nothing confirms, watches or removes the fault; a cached pass is not a run. *Instead:* the runner.
- **"Staging is fine, the product owner said so in chat."** *Reason:* the runner refuses without the signed file. *Instead:* `./templates/chaos-statement.md`, signed.

## Output

| File | When to open it |
|---|---|
| `./references/where-it-runs.md` | Where a fault may go; the statement; the privileged injector; cadence; credentials and cost |
| `./references/experiment-method.md` | Steady state, hypothesis, blast radius, abort, verdicts, what a pass means |
| `./references/patterns-and-assertions.md` | Each pattern's assertion; missing patterns; DLQ, idempotency, 429; event-driven rows; deadlock and livelock |
| `./references/chaos-mesh-on-kind.md` | Installing and using Chaos Mesh 2.8.8 in the throwaway cluster; what was observed |
| `./templates/experiment-definition.md` | Writing `tests/chaos/experiments/<id>.json` |
| `./templates/chaostest-package.md` | The fault-injecting `RoundTripper`, stand-in dependency and Toxiproxy helpers |
| `./templates/pattern-tests.md` | The Go tests for each pattern and the build-tagged hook |
| `./templates/toxiproxy-setup.md` | Toxiproxy in the throwaway cluster; the deployed experiment |
| `./templates/chaos-mesh-manifests.md` | Chaos Mesh values, PodChaos, NetworkChaos, Schedule |
| `./templates/environment-and-make.md` | Suite lines, the release line, make targets, the workflow |
| `./templates/chaos-statement.md` | Any system other than the throwaway cluster |
| `./templates/chaos-experiment-report.md` | Reporting a run |
| `./scripts/run-chaos-experiment.sh` | Copied to the product; the only way an experiment starts |
| `./scripts/validate-go-chaos-tests.sh` | Before hand-off, after every edit |
| `./resources/checklist.md` | Before answering |

In the product: `tests/chaos/` (the two scripts, `experiments/*.json`, `mesh/*.yaml`, `charts/toxiproxy/`, `chaos-mesh-values.yaml`, `chaos-e2e.conf`, `chaos-suites.conf`, `statements/<id>.json` for each signed statement), `internal/test/chaostest/`, `*_chaos_test.go` beside the code they prove, the `chaos*` make targets, `.github/workflows/chaos.yml`, and one report per run put forward as evidence.
