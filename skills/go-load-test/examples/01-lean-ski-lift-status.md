# Lean: Ski-Lift Status, the Indicative Tier Only

One Go service tells skiers which lifts are open. The product is lean: one service, one database, a short NFR table, and **no approved performance environment yet**. This example shows what lean still gets (the indicative tier, every night), what it must not claim, a nightly run going red on a slower build, and how the question "does it meet the target?" is answered.

Run on 2026-11-28: k6 v2.4.0, kind v0.33.0 (Kubernetes v1.37.0), Helm v4.3.2, kubectl v1.36.1, Docker 29.9.3, GNU Make 3.81, macOS arm64. The service was a lab stand-in (a Go service with a per-subject token bucket of 10 a second, burst 20) installed from a chart by the unmodified `run-e2e-environment.sh` of `go-e2e-test`; the runner, the k6 files and the suite lines are the shipped ones (`../templates/`). Nothing was run on GitHub Actions.

## Input

| Source | Says |
|---|---|
| `NFR-PERF-01` (short form, Must only) | Environment: Saturday 08:00-09:00 first-lift peak, 15 status reads a second; 14 lifts. Response measure: P95 ≤ 500 ms (Must) |
| SLO record, rows `R-01`, `R-02` | Availability 99%, good event: not a 5xx. Latency: 95% under 500 ms |
| Rate limit | The `go-middleware` default, 10 a second per subject, burst 20 |
| Designation record | None. The product owner has not approved a performance environment |

## The profile: an `indicative` block and nothing else

### `tests/load/profile.json`

```json
{
  "product": "ski-lift-status",
  "nfr": {
    "id": "NFR-PERF-01",
    "level": "Must",
    "environment": "Saturday 08:00-09:00 first-lift peak: 15 status reads a second; 14 lifts, one season of history"
  },
  "slo": {
    "availability": {
      "id": "R-01",
      "objective": 0.99,
      "good_statuses": [
        {
          "min": 200,
          "max": 499
        }
      ]
    },
    "latency": {
      "id": "R-02",
      "percentile": 95,
      "under_ms": 500
    }
  },
  "limiter": {
    "per_subject_per_second": 10,
    "burst": 20,
    "source": "go-middleware RateLimit default (not overridden)"
  },
  "data": {
    "description": "14 lifts created through the public API by the suite's setup; reads spread over all 14",
    "distinct_items": 14,
    "decided_by": "test-strategist",
    "reason": "the whole resort"
  },
  "indicative": {
    "smoke": {
      "iterations": 10,
      "max_duration": "30s",
      "decided_by": "test-strategist",
      "reason": "enough to show the script, the identities and the gate work"
    },
    "average-load": {
      "rate_per_second": 6,
      "ramp_up": "5s",
      "hold": "30s",
      "virtual_users": 20,
      "warm_up": "excluded",
      "tolerance_percent": 40,
      "decided_by": "product owner, 2026-11-28",
      "reason": "a rate the nightly runner offers easily; 40% is the change worth a look"
    },
    "overload": {
      "rate_per_second": 40,
      "seconds": 10,
      "virtual_users": 20,
      "decided_by": "test-strategist",
      "reason": "four times the limit, long enough to empty the burst"
    }
  }
}
```

There is no `verdict` block, so no verdict-tier test can be started. Run: `make load-verdict` stopped at once with `PROFILE ERROR in tests/load/profile.json: verdict.smoke: this test type is not planned for this tier` (exit 2); with a `verdict` block and no designation record the runner answers `REFUSED` instead. The rate of 6 a second is a decision about what a nightly runner can offer, not the NFR's 15. The ids of the NFR and SLO rows are still recorded, so the day an environment is approved the `verdict` block is derived from the same rows.

## A night that passes

The three lines of `tests/load/indicative-suites.conf` run last in `make e2e`. By hand, `make load-indicative` runs the same lines in a cluster of their own (about 70 seconds in all):

```text
== creating cluster e2e-local-1795843103-44189 (kubeconfig /var/folders/.../tmp.XlgpIfslGC/kubeconfig)
== installing labsvc from charts/labsvc
== waiting for endpoint api on 127.0.0.1:51754
== suite: ./tests/load/run-load-test.sh --tier indicative --type smoke --endpoint api --subjects-cmd ./tests/load/issue-subjects.sh
== load test: tier indicative, type smoke, target http://127.0.0.1:51754 (throwaway kind cluster e2e-local-1795843103-44189, created and deleted by this run)
== INDICATIVE PASS: indicative smoke test (k6 exit 0)
   Indicative only: this run proves nothing about capacity or about any stated target.
== INDICATIVE PASS: indicative average-load test (k6 exit 0)
   comparison with the previous run: within tolerance
   Indicative only: this run proves nothing about capacity or about any stated target.
== INDICATIVE PASS: indicative overload test (k6 exit 0)
   Indicative only: this run proves nothing about capacity or about any stated target.
== deleting cluster e2e-local-1795843103-44189
== end-to-end run local-1795843103-44189 passed; cluster deleted
```

The address `127.0.0.1:51754` was read from the cluster's run marker; nothing in the product's files names an address. Average load: 181 judged requests, p(95) 1.94 ms against 1.85 ms the night before (a change of 5.0%, tolerance 40%). Overload: 119 requests accepted (121 allowed), 281 answered 429, each with `Retry-After`. The first night had no baseline and reported "no previous result to compare with".

## A night that goes red

A build that adds 8 ms to every read:

```text
== FAIL: indicative average-load test (k6 exit 0)
   p(95) rose 537.9% against the previous run (1.85 ms to 11.80 ms), more than the 40% the profile allows
   Indicative only: this run proves nothing about capacity or about any stated target.
suite FAILED: ./tests/load/run-load-test.sh --tier indicative --type average-load --endpoint api ...
== collecting evidence into .../e2e-evidence
== deleting cluster e2e-local-1795843175-44792
== end-to-end run local-1795843175-44792 FAILED; evidence in .../e2e-evidence
```

`make load-indicative` exited 2 and the cluster was gone. k6 itself exited 0 here: no threshold was crossed, and 11.8 ms is far inside the 500 ms target. The run is red because of the comparison, which is the only thing this tier judges about speed. Nothing was retried; the failed result did not become the next baseline.

## The report

Drafted by `../scripts/write-load-report.sh` from that night's three result files, for `artifacts/ski-lift-status/quality/test-reports/load-indicative-2026-11-28.md` (the commit reads "unknown" because the lab folder was not a repository):

```text
---
name: load-test-report-2026-11-28
version: 1.0.0
phase: quality
owner: test-strategist
created: 2026-11-28
summary: Indicative load check for ski-lift-status at commit unknown: smoke INDICATIVE PASS, average-load FAIL, overload INDICATIVE PASS. Proves nothing about capacity.
traces-to: [ideate/nfr-specification.md (NFR-PERF-01), the SLO record (R-01, R-02), commit unknown]
---
```

**Verdict**

**FAIL** (indicative tier). smoke INDICATIVE PASS, average-load FAIL, overload INDICATIVE PASS.

**Indicative only.** This run was made in a throwaway kind cluster on the machine that also ran the load generator. It can show a change between two runs. It proves nothing about capacity and does not show that any stated target is met; that needs a verdict run in the product's designated performance environment.

- average-load: p(95) rose 537.9% against the previous run (1.85 ms to 11.80 ms), more than the 40% the profile allows

**Comparison with the previous run**

Two indicative runs are compared only when the test type, its shape, the scripts and profile, the k6 version and the runner (CPU count, architecture, system, runner class) are the same.

- average-load, `http_req_duration{expected_response:true,scenario:hold} p(95)`: now 11.80 ms, previous 1.85 ms, change 537.9% (tolerance 40%). Outcome: regression.

**What this run does not prove**

- Capacity, and whether any stated target (NFR or SLO) is met: this tier never shows either.
- Anything about production sizing: one kind node on the machine that also runs the load generator, small data, test-only identities.
- A difference from the previous run is a prompt to look, not a measurement: the runner is shared and its size depends on the repository's visibility.
- [Add what is specific to this product and run.]

## "Does it meet the 500 ms target at 15 a second?"

> That has not been tested, and the nightly check cannot tell you. It is the **indicative tier**: 6 requests a second in a throwaway kind cluster on the same machine as the load generator. It shows that last night's build was not slower than the one before and that the rate limiter sheds correctly. **It proves nothing about capacity and does not show that `NFR-PERF-01` (P95 ≤ 500 ms at 15 reads a second) or SLO rows `R-01` and `R-02` are met.** A verdict needs a designated performance environment that you approve for this product, sized and loaded with data as the requirement states; the test refuses to run anywhere else, and it will not be pointed at staging or production. Until then the reports and the release notes say that no target was verified. What I need from you: approval of an environment (address, sizing, data, an expiry date), and decisions on the numbers no source gives, such as how long to hold the peak. I ran `make load-indicative` twice locally; nothing was run on GitHub Actions.
