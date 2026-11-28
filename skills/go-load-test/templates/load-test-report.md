---
name: load-test-report-[YYYY-MM-DD]
version: 1.0.0
phase: quality
owner: test-strategist
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: which tier ran against which commit, each test type's verdict, and for the indicative tier the words "proves nothing about capacity"; for a run under an impact statement, "not a capacity verdict"]
traces-to: [ideate/nfr-specification.md (NFR-PERF-[nn]), the SLO record ([row ids]), commit [sha]]
---

# Load Test Report: [product], [YYYY-MM-DD]

<!-- Path: artifacts/<product>/quality/test-reports/load-[tier]-[YYYY-MM-DD].md, written with Write. The product
     owner approves it. Produce the draft with ./scripts/write-load-report.sh <result.json>... from the result
     files of one run, then complete the three bracketed parts: "The product's own measurements", the last
     bullet of "What this run does not prove", and "Not run or unverified". A run under a signed impact statement gets the
     statement field by field and verbatim, and is called a verification, never a capacity verdict. Change no number and no verdict by hand. One report per run put forward as evidence.
     Delete this comment. -->

## Verdict

**[PASS | FAIL | INVALID | INDICATIVE PASS | MEASURED | ABORTED]** ([indicative | verdict] tier). [Each test type and its verdict.]

[Indicative tier, always, in these words: **Indicative only.** This run was made in a throwaway kind cluster on the machine that also ran the load generator. It can show a change between two runs. It proves nothing about capacity and does not show that any stated target is met; that needs a verdict run in the product's designated performance environment.]

[Verdict tier: The verdict holds for the environment, sizing and data recorded below, at the load the profile states, for the length of this run.]

[Under an impact statement, no designation: **Verification only.** This run went to (address), a system named in the impact statement the product owner signed, not a designated performance environment. It is a result about that system at that time, not a capacity verdict.]

- [Each reason the runner printed: crossed thresholds, why a run is invalid, the outcome of the comparison.]

## Run

| Item | Value |
|---|---|
| Tier | [indicative / verdict] |
| Commit | [full sha] |
| Environment | [throwaway kind cluster e2e-(run id), created and deleted by this run / designated performance environment (id)] |
| Address | [the address the runner checked] |
| Designation record | [id: approved by (name) on (date), expires (date) / none: the indicative tier needs none and stores no credential / none: a verification under the signed impact statement below] |
| Impact statement | [id: signed by (name) on (date); see below / omit the row when there is none] |
| Sizing (from the record) | [verdict tier] |
| Data (from the record) | [verdict tier] |
| Load generator (from the record) | [verdict tier] |
| Tokens | [verdict tier or impact statement: issued for the run, at most (n) minutes, deleted after it] |
| Started / ended (UTC) | [the window every monitoring query is pinned to] |
| Tool | k6 [version] |
| Retries | 0 |

## Signed impact statement

[Only for a run under one; delete otherwise. Each field as signed: id, address, purpose, test type, profile allowed (rate, peak, length), data written or touched, how it is removed, other users, other teams, dependent systems, third parties, cost, how to stop it, watched by, window, marker (or why it cannot be served), signed by and date, expiry or single run. Then the statement verbatim as JSON.]

## Targets and where they come from

| Source | Id | What it states |
|---|---|---|
| NFR | NFR-PERF-[nn] ([Must / Plan / Stretch]) | Environment: [the cell, copied] |
| SLO, errors | [row id] | objective [0.995]; good statuses [ranges] |
| SLO, latency | [row id] | p([n]) under [n] ms |
| Rate limit | [where it is configured] | [n]/s per subject, burst [n] |

## Profile and judgement calls

Numbers the sources do not give (run length, ramp, virtual users, data volume, any reduced or raised rate) are decisions, recorded here with who made them.

Test data: [what and how much]; requests spread over [n] items. Decided by [who]: [why].

| Test type | Shape | Subjects | Decided by | Reason |
|---|---|---|---|---|
| [average-load] | [rate, ramp, hold, virtual users, warm-up] | [n] | [who, date] | [why] |

## Thresholds and results

### [test type]: [verdict] (k6 exit status [0 / 99 / other])

Requests: [n] at [n]/s. Latency of answers the SLI counts as good, in ms: [count, min, med, p(90), p(95), p(99), max].

| Metric | Threshold | Result | Observed |
|---|---|---|---|
| `[http_req_failed{scenario:hold}]` | `[rate<0.005000]` | held / **crossed** | [rate] |

## Validity

A run that dropped iterations or saturated its generator is invalid, not passed.

| Test type | Dropped iterations | Generator CPU share (of its CPUs) | Verdict |
|---|---|---|---|
| [average-load] | [0] | [n% of n] | [verdict] |

## Comparison with the previous run

[Indicative tier only. The metric, now and before, the change, the tolerance and the outcome; or why the two runs are not comparable. Delete the section in the verdict tier.]

## The product's own measurements

[From the environment's own Prometheus, each query pinned to the run's start and end: shed answers, queue or pool saturation, CPU throttling, memory at its peak, and for asynchronous work the drain and freshness figures. Write "not read" where none was read; never from another environment's monitoring.]

## What this run does not prove

- [The runner's list for the tier, copied.]
- [What is specific to this product and run.]

## Not run or unverified

[Every planned test type that did not run, and anything in this report that was not observed, with the reason.]

## Approval

| Product owner | Decision | Date | Comments |
|---|---|---|---|
| | approved / rejected | | |
