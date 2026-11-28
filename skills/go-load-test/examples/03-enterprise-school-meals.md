# Enterprise: School Meal Orders, Tenants, an Invalid Run and a Breakpoint

A multi-tenant Go product: 120 school districts order meals through one `orders` service, with a database per tenant tier. The product has a designated performance environment. This example shows a verdict run that was **invalid** and why that is not a pass, the corrected run, a breakpoint measurement and what it may be used for, a test type nobody planned, and the release gate.

Run on 2026-11-28: k6 v2.4.0, GNU Make 3.81, macOS arm64. The product was a lab stand-in (a Go service with a per-subject token bucket of 10 a second, burst 20, answering in 150 ms) serving the designation marker on 127.0.0.1; the runner, the k6 files and the make targets are the shipped ones (`../templates/`). The load was spread evenly over six test subjects. A per-district traffic mix, a noisy-neighbour check between tenants, a real performance environment, a real identity provider and GitHub Actions were **not run**.

## Input

| Source | Says |
|---|---|
| `NFR-PERF-01` | Environment: Sunday 18:00-21:00 ordering peak, 36 menu and order reads a second across 120 districts, the largest district a fifth of them; 1.4 million pupils. Response measure: P95 ≤ 400 ms (Must), ≤ 250 ms (Plan), ≤ 150 ms (Stretch) |
| SLO record, row `R-01` | Availability 99.9%; good event: not a 5xx |
| SLO record, row `R-03` | Latency: 95% of reads under 400 ms |
| `charts/orders/values.yaml` | Rate limit 10 a second per subject, burst 20 |
| `tests/load/designation.json` | `perf-school-meals-2026-11`, approved by the product owner, expires in 14 days; sizing "4 replicas of 1 CPU and 512 Mi; one PostgreSQL per tenant tier, 4 CPU and 16 Gi: half the production replica count, stated as such"; test types smoke, average-load, breakpoint, overload; tokens at most 240 minutes; generator "one self-hosted runner of 8 CPU in the environment's network, private repository" |

## From the targets to the profile

| Profile value | Derived how |
|---|---|
| `nfr.level` Must; threshold `p(95)<400` | The test strategy tests the Must level. Plan and Stretch are reported from the same run's figures, not gated |
| Error threshold `rate<0.001000` | `R-01`: 1 minus 0.999 |
| Rate 36 a second | The NFR's Environment cell |
| At least 4 subjects, 6 used | 36 divided by the limit of 10. Each subject is a test user of a synthetic district; tokens come from `LOAD_TOKEN_CMD`, 200 minutes each, inside the record's 240 |
| Which districts the subjects belong to, and in what proportion | **Judgement.** The NFR says the largest district is a fifth of the traffic. Modelling that needs subjects in districts of each tenant tier and a weighted choice in `journey.js`; the product owner decides the weights. Not run here |
| Hold 1 minute for the rehearsal, 3 hours for the release run | **Judgement**, recorded. The rehearsal is what was run |
| Breakpoint ceiling 60 a second | The most six subjects may send; a higher ceiling needs more subjects |

## A verdict run that proves nothing

The first profile gave the average-load test 3 virtual users. `make load-verdict-one TYPE=average-load`:

```text
level=warning msg="Insufficient VUs, reached 3 active VUs and cannot initialize more" executor=constant-arrival-rate scenario=hold
== INVALID: verdict average-load test (k6 exit 99)
   1127 iterations were dropped: the generator did not offer the stated load (too few virtual users, or the target slowed until they ran out)
   also crossed: dropped_iterations: count==0
make: *** [load-verdict-one] Error 4
```

1,210 requests were sent where about 2,340 were due: the product was tested at roughly half the stated rate. The latency of the requests that did go out was inside the target (p(95) 152 ms), and that is exactly why the run must not be read: a reply of "latency was fine" would report a result for a load nobody asked about. The verdict is **INVALID**, exit status 4, and the job is red.

What was done: the estimate was redone (150 ms per iteration times 36 a second is about 6 busy users; 60 were pre-allocated as margin, a decision recorded in the profile) and the test was run **again as a new run**. Nothing was retried automatically.

## The corrected run

`make load-verdict`:

```text
== PASS: verdict smoke test (k6 exit 0)
== PASS: verdict average-load test (k6 exit 0)
== PASS: verdict overload test (k6 exit 0)
```

Average load: 2,160 judged requests, p(95) 152 ms against 400 ms, no errors, no 429, no dropped iterations, generator at 0.3% of its CPUs. Against the other levels: Plan (250 ms) met, Stretch (150 ms) missed by 2 ms; neither is gated. Overload: one subject at 40 a second for 20 seconds, 219 accepted (221 allowed), 582 answered 429 with `Retry-After`.

## A breakpoint measurement

For this run the stand-in was limited to serving about 20 requests a second. `make load-verdict-one TYPE=breakpoint`:

```text
== MEASURED: verdict breakpoint test (k6 exit 99)
   the climb stopped at about 25.0 requests per second (http_req_duration{expected_response:true}: p(95)<400)
```

k6 exited 99 because a target was missed, which is how a breakpoint run is meant to end; the runner reports MEASURED and exits 0, and the run is not part of `make load-verdict`. What the figure means: with the recorded sizing, the latency target was first missed at about 25 a second, below the stated peak of 36. That is a finding for `platform-engineer` and the product owner (more capacity, or a changed target), raised as an escalation, not a number to tune the test around. Capacity planning from a breaking point (how many instances for the peak with spare) is theirs. The environment here does not add capacity by itself; where one does, k6 advises against breakpoint tests.

## A test type nobody planned

`make load-verdict-one TYPE=soak`:

```text
PROFILE ERROR in tests/load/profile.json:
  verdict.soak: this test type is not planned for this tier
make: *** [load-verdict-one] Error 2
```

A soak needs a profile entry with a length someone decided, and the designation record must list it (`REFUSED: the designation does not allow the soak test` otherwise). Both are the product owner's to add.

## The release gate

The publishing workflow calls `.github/workflows/load-verdict.yml` and its publishing job `needs` it (`../templates/workflows.md`; not run on GitHub Actions). With the first profile the release would have stopped on exit 4: an invalid verdict blocks a release exactly as a failed one does. The nightly end-to-end run carries the indicative lines for the same product, in a throwaway cluster, with test-only identities and no stored credential.

## What the reply said

> The first verdict run was **INVALID**, not a pass: 1,127 iterations were dropped because 3 virtual users could not offer 36 requests a second, so the product was tested at about half the stated load. I raised the pre-allocated users to 60 (recorded in the profile as a judgement) and ran it again as a new run; no retry was used. Second run, verdict tier, designated environment `perf-school-meals-2026-11`: **PASS** for smoke, average load and overload against `NFR-PERF-01` (Must: P95 ≤ 400 ms at 36 a second) and SLO rows `R-01` and `R-03`; observed p(95) 152 ms over 2,160 requests, open arrival-rate model, six subjects each inside the 10-a-second limit, 582 correct 429 answers in the overload check. It holds for the recorded sizing (half of production's replicas) and a one-minute hold; the three-hour release run, a per-district mix and the tenant noisy-neighbour check have not been run. The breakpoint run measured the first missed target at about 25 a second in a deliberately limited stand-in. The report is ready for your approval.
