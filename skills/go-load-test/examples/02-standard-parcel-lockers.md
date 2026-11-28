# Standard: Parcel Lockers, a Verdict in the Designated Environment

A Go service answers pickup-code lookups for parcel lockers. The product has an approved performance environment, so it gets both tiers. This example shows the route from the requirement to the profile, a passing verdict, the same verdict failing truthfully, and the report.

Run on 2026-11-28: k6 v2.4.0, GNU Make 3.81, macOS arm64. The product was a lab stand-in (a Go service with a per-subject token bucket of 10 a second, burst 20) serving the designation marker on 127.0.0.1; the runner, the k6 files, the profile, the designation record and the make targets are the shipped ones (`../templates/`), so they are not repeated here. No real identity provider, no real performance environment and no two-hour soak was used: those parts are unverified.

## Input

| Source | Says |
|---|---|
| `NFR-PERF-01` (`ideate/nfr-specification.md`) | Environment: weekday 17:00-19:00 pickup peak, 24 pickup-code lookups a second from 9,000 couriers and customers, 200,000 open parcels. Response measure: P95 ≤ 300 ms (Must), ≤ 150 ms (Plan) |
| SLO record, row `R-01` | Availability 99.5%; good event: a response that is not a 5xx |
| SLO record, row `R-02` | Latency: 95% of lookups under 300 ms |
| `charts/lockers/values.yaml` | Rate limit 10 a second per subject, burst 20 (the `go-middleware` default) |

## From the targets to the profile

| Profile value | Derived how |
|---|---|
| Rate 24 a second | The NFR's Environment cell, a peak figure. No conversion from "9,000 couriers and customers" was attempted: no source has one |
| At least 3 subjects, 4 used | 24 divided by the limit of 10 per subject. With one subject the script stops: `PROFILE ERROR: 24/s over 1 subject(s) is 24.00/s each, above the limiter's 10/s per subject` |
| Good statuses 200 to 499, error threshold `rate<0.005000` | `R-01`: not a 5xx; 1 minus 0.995 |
| Latency threshold `p(95)<300` on good answers | `R-02`, Must level |
| Hold 2 minutes, ramp 20 seconds, 40 virtual users, warm-up excluded | **Judgement**, recorded with the product owner's name: no source gives a run length or a sample size. About 2,900 requests are judged |
| Stress at 36 a second, soak of 2 hours, spike to 38 | **Judgement**, each recorded |

## The verdict run

`make load-verdict` (smoke, average load, overload), 172 seconds:

```text
== load test: tier verdict, type smoke, target http://127.0.0.1:18080 (designated performance environment perf-parcel-lockers-2026-11)
== PASS: verdict smoke test (k6 exit 0)
== load test: tier verdict, type average-load, target http://127.0.0.1:18080 (designated performance environment perf-parcel-lockers-2026-11)
== PASS: verdict average-load test (k6 exit 0)
== load test: tier verdict, type overload, target http://127.0.0.1:18080 (designated performance environment perf-parcel-lockers-2026-11)
== PASS: verdict overload test (k6 exit 0)
```

The other planned types, each with `make load-verdict-one TYPE=<type>`: stress PASS (4,321 judged requests at 36 a second, p(95) 0.31 ms), spike PASS (targets judged on the minute after the spike: 1,441 requests, p(95) 0.35 ms), breakpoint MEASURED ("no target was missed up to the ceiling of the climb", 40 a second, the most four subjects may send), soak PASS only with its hold shortened to 20 seconds. The two-hour soak was not run.

## The same verdict, failing truthfully

The stand-in was slowed to 400 ms per lookup and `make load-verdict` run again:

```text
== PASS: verdict smoke test (k6 exit 0)
== FAIL: verdict average-load test (k6 exit 99)
   crossed: http_req_duration{expected_response:true,scenario:hold}: p(95)<300
make: *** [load-verdict] Error 1
```

p(95) was 402 ms over 2,881 requests. Make stopped at the failing line (its own exit status 2), so the overload line did not run and the job that called it is red. Nothing was retried. Smoke passed because it judges answers, not speed.

## The report

Drafted by `../scripts/write-load-report.sh` from the three result files of the passing run and written to `artifacts/parcel-lockers/quality/test-reports/load-verdict-2026-11-28.md`. Excerpts as generated (the commit reads "unknown" because the lab folder was not a repository):

**Run**

| Item | Value |
|---|---|
| Tier | verdict |
| Commit | unknown |
| Environment | designated performance environment perf-parcel-lockers-2026-11 |
| Address | http://127.0.0.1:18080 |
| Designation record | perf-parcel-lockers-2026-11: approved by Product owner on 2026-11-28, expires 2026-12-28 |
| Sizing (from the record) | 3 replicas of 1 CPU and 512 Mi, PostgreSQL 2 CPU and 8 Gi: the sizing NFR-PERF-01 is stated for |
| Data (from the record) | 200,000 open parcels, loaded by the environment's seed job; no copy of customer data |
| Load generator (from the record) | one runner of 4 CPU inside the environment's network |
| Tokens | issued for the run, at most 180 minutes, deleted after it |
| Started / ended (UTC) | 2026-11-28T05:02:31Z / 2026-11-28T05:05:22Z |
| Tool | k6 v2.4.0 (commit/dd9395906d, go1.26.11, darwin/arm64) |
| Retries | 0 |

**Targets and where they come from**

| Source | Id | What it states |
|---|---|---|
| NFR | NFR-PERF-01 (Must) | Environment: Weekday 17:00-19:00 pickup peak: 24 pickup-code lookups a second from 9,000 couriers and customers; 200,000 open parcels |
| SLO, errors | R-01 | objective 0.995; good statuses [{"min": 200, "max": 499}] |
| SLO, latency | R-02 | p(95) under 300 ms |
| Rate limit | go-middleware RateLimit default; charts/lockers/values.yaml rateLimit | 10/s per subject, burst 20 |

**Profile and judgement calls**

Numbers the sources do not give (run length, ramp, virtual users, data volume, any reduced or raised rate) are decisions, recorded here with who made them.

Test data: 200,000 open parcels loaded by the environment's own seed job, as NFR-PERF-01 states; lookups spread over 500 of them; requests spread over 500 items. Decided by product owner, 2026-11-28: the NFR gives the volume; how many of them the test reads is a judgement.

| Test type | Shape | Subjects | Decided by | Reason |
|---|---|---|---|---|
| smoke | iterations 10; max_duration 30s | 4 | test-strategist | enough to show the script, the tokens and the gate work |
| average-load | rate_per_second 24; ramp_up 20s; hold 2m; virtual_users 40; warm_up excluded | 4 | product owner, 2026-11-28 | rate from NFR-PERF-01; no source gives a run length or a sample size, so two minutes at peak (about 2,900 requests) was chosen and is to be reviewed |
| overload | rate_per_second 40; seconds 30; virtual_users 20 | 4 | test-strategist | four times the limit |

**average-load: PASS (k6 exit status 0)**

Requests: 3119 at 22.28/s. Latency of answers the SLI counts as good (`http_req_duration{expected_response:true,scenario:hold}`), in ms: avg 0.24, count 2880, max 5.07, med 0.22, min 0.10, p(90) 0.30, p(95) 0.34, p(99) 0.43.

| Metric | Threshold | Result | Observed |
|---|---|---|---|
| `dropped_iterations` | `count==0` | held | count 0, rate 0 |
| `http_req_duration{expected_response:true,scenario:hold}` | `p(95)<300` | held | count 2880, max 5.07, p(90) 0.30, p(95) 0.34, p(99) 0.43 |
| `http_req_failed{scenario:hold}` | `rate<0.005000` | held | rate 0 |
| `rate_limited` | `count==0` | held | count 0, rate 0 |
| `wrong_answer` | `rate==0` | held | rate 0 |

**overload: PASS (k6 exit status 0)**

Requests: 1201 at 40.03/s. Latency of answers the SLI counts as good (`http_req_duration{expected_response:true}`), in ms: avg 0.23, count 1201, max 1.56, med 0.21, min 0.10, p(90) 0.28, p(95) 0.32, p(99) 0.42.

| Metric | Threshold | Result | Observed |
|---|---|---|---|
| `accepted_duration` | `p(95)<300` | held | count 319, max 1.28, p(90) 0.28, p(95) 0.37, p(99) 0.41 |
| `accepted_total` | `count<=321` | held | count 319, rate 10.63 |
| `accepted_total` | `count>0` | held | count 319, rate 10.63 |
| `dropped_iterations` | `count==0` | held | count 0, rate 0 |
| `overload_wrong_answer` | `rate==0` | held | rate 0 |
| `shed_correct` | `rate==1` | held | rate 1 |
| `shed_total` | `count>0` | held | count 882, rate 29.40 |

**Validity**

A run that dropped iterations or saturated its generator is invalid, not passed.

| Test type | Dropped iterations | Generator CPU share (of its CPUs) | Verdict |
|---|---|---|---|
| smoke | 0 | 7.7% of 10 | PASS |
| average-load | 0 | 0.2% of 10 | PASS |
| overload | 0 | 0.3% of 10 | PASS |

**What this run does not prove**

- The rolling SLO window: one run shows the targets held at this load for this run's length, not for 28 days.
- Production itself: the result holds for the sizing and data recorded in the designation, nothing larger.
- Faults injected on purpose and the speed of a single function: the chaos-test and performance-test skills of the product's language.
- [Add what is specific to this product and run.]

The agent then completed "The product's own measurements" ("not read: the stand-in had no Prometheus"), the product-specific bullet and "Not run or unverified" (the two-hour soak; GitHub Actions), and put the report to the product owner.

## What the reply said

> Verdict tier, in the designated performance environment `perf-parcel-lockers-2026-11` (approved by the product owner, expires 2026-12-28): **PASS** for smoke, average load and overload. Targets come from `NFR-PERF-01` (24 lookups a second, P95 ≤ 300 ms, Must) and SLO rows `R-01` and `R-02`. The run length (2 minutes at peak), the 40 virtual users and the exclusion of warm-up are judgement calls recorded in the profile, not source figures. The load used the open arrival-rate model over 4 subjects so that each stayed inside the 10-a-second limit; no 429 occurred there, and in the overload check 882 of 1,201 requests were correctly answered 429 with `Retry-After`. No iterations were dropped, nothing was retried. The result holds for the recorded sizing and data and for this run's length, not for the 28-day window. The two-hour soak and the GitHub Actions workflow were not run. The report is ready for your approval.
