---
name: e2e-test-report-[YYYY-MM-DD]
version: 1.0.0
phase: quality
owner: test-strategist
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: which journeys of the product ran end to end against which commit, and the verdict]
traces-to: [implement/test-strategy.md, [commit or run id]]
---

# End-to-End Test Report: [product], [YYYY-MM-DD]

<!-- Path: artifacts/<product>/quality/test-reports/e2e-[YYYY-MM-DD].md, written with Write. The product owner
     approves it. Fill every field from e2e-evidence/run.txt and e2e-evidence/results/python-*-summary.json of
     the run. One report per run put forward as evidence (a release, a phase approval). A product with Go and
     Python journeys writes ONE report for the run, with the rows of both runners. Report only what the run
     showed; write "not run" where something did not run. Delete this comment. -->

## Verdict

[PASS | FAIL]. [One line: n journeys ran, n passed first time, n flaky, n failed twice, n quarantined.]

A passing run confirms only the journeys listed here. It is a set of checks someone specified, not a statement that the product was tested in every way; unscripted exploratory testing is planned in `uat-plan`.

## Run

| Item | Value |
|---|---|
| Commit | [full sha] |
| Images | [built from this commit by `make e2e-images` / release candidate images, by digest] |
| Trigger | [nightly / before release (version) / by hand] |
| Run id | [gh-(run id)-(attempt), or local-...] |
| Environment | Throwaway kind cluster created for this run and deleted after it; cluster deleted: [yes / no, and why] |
| Releases installed | [every release of E2E_RELEASES, in order] |
| Tools | Python [v], pytest [v], httpx [v], kind [v], Helm [v], kubectl [v], Docker [v], node image [name@digest] |

## Journeys

| Test | Acceptance criteria | First attempt | Retry | Result |
|---|---|---|---|---|
| `tests/e2e/journeys/test_journey_[name].py::test_journey_[goal]` | AC-US-[n.m], ... | pass / fail | not needed / pass / fail | passed / **flaky** / **failed** |

Must Have criteria with no passing journey or lower-layer proof: [none | list each; the gate is red for them].

## Read-only smoke tests

| Test | Result |
|---|---|
| `tests/e2e/smoke/test_smoke.py::test_smoke_[name]` | pass / fail |

## Guard self-checks

| Check | Result |
|---|---|
| Client refuses another address (an absolute URL) | pass / fail |
| Client refuses a redirect to another address | pass / fail |
| Seeding refuses an address outside the cluster | pass / fail |
| Marker must be this run's and loopback | pass / fail |
| Smoke client refuses writes and another address | pass / fail |

## Flaky results

A test that failed and then passed on the one retry is flaky, not green.

| Test | Trace id of the failed attempt | Seen before (runs) | Action |
|---|---|---|---|
| [none] | | | [first flake: recorded / second flake: quarantined, with the issue link] |

## Quarantined tests

A quarantined test proves nothing and is not counted as passed. Each entry names what is unproven while it is out.

| Test | Issue | Deadline | Result in the non-blocking run | Criteria unproven meanwhile |
|---|---|---|---|---|
| [none] | | | | |

## Skipped tests

[none | each test the summary lists under `skipped`; a skipped end-to-end test proves nothing and the validator fails on one.]

## What this environment does not prove

[List what differs from production and is therefore unproven by this run, for example: one node, no cloud load balancer, no service mesh unless a release above installs it, no production data volumes, test-only credentials. Name the layer or environment that proves each, or mark it an open question.]

## Evidence

| Item | Location |
|---|---|
| Results (`python-*-summary.json`, the JUnit file and outcome file of each attempt) | [workflow run URL and artifact name, or local path] |
| Pod logs, events, cluster state (collected only when a step failed) | [location / "not collected: the run passed"] |

## Not run or unverified

[Anything in this report that was not run, with the reason.]

## Approval

| Product owner | Decision | Date | Comments |
|---|---|---|---|
| | approved / rejected | | |
