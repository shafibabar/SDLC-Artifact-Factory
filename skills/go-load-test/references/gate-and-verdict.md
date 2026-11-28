# The Gate: Thresholds, Exit Statuses and the Verdict

Self-contained. Read when writing or reviewing thresholds, when a run fails or passes unexpectedly, when 429 answers appear, or when deciding what a result means. Everything marked "run" was run on 2026-11-28 with k6 v2.4.0 (darwin arm64; the image `grafana/k6:2.4.0`, digest `sha256:d41bb79cd8de5a7ad619b53570e3712633e8bff0937010a5c6c57a4747e7a276`, gave the same exit status for a crossed threshold).

## Contents
What k6 exits with; mirroring the SLI; 429; rules that can fail; invalid runs; no retries; the indicative comparison; what a pass means.

## What k6 exits with

The documentation says only "non-zero" for a failed threshold. The codes are constants in k6's source, and these were observed:

| Situation | Exit | Run |
|---|---|---|
| Every threshold held | 0 | Yes |
| A threshold crossed at the end | **99** | Yes |
| A threshold with `abortOnFail` stopped the run early | 99 | Yes (stopped after 2 seconds) |
| Interrupted by SIGINT or SIGTERM | 105 | Yes, both |
| Exception while loading the script, or in `setup()` | 107 | Yes, both |
| **Exception in every iteration** | **0** | Yes: three iterations threw, k6 logged each and exited 0 |
| Every `check()` failed, no threshold on `checks` | **0** | Yes: "0 out of 5" succeeded |
| The same with `checks: ['rate==1']` | 99 | Yes |
| `--no-thresholds` | 0 whatever happened | Yes |
| `exec.test.abort()` 108, `exec.test.fail()` 110, invalid configuration 104 | | From the source; not run |

So: 99 means the product missed a target; 105 means nobody knows; 107 and the others mean the test is broken; and **0 means nothing by itself**. `run-load-test.sh` reads the status and the summary together and gives one verdict.

| Verdict | Runner exit | When |
|---|---|---|
| PASS / INDICATIVE PASS | 0 | k6 exit 0, thresholds present, requests sent, nothing dropped, generator not saturated |
| MEASURED | 0 | A breakpoint run: it reports the rate reached and is never a gate |
| FAIL | 1 | k6 exit 99, or an indicative regression beyond the tolerance |
| REFUSED | 3 | The target is not allowed; no request of the test was sent |
| INVALID | 4 | The run proves nothing: see below |
| ABORTED | 130 | k6 exit 105 |

Never hide the status: no `|| true`, no leading `-` in a make recipe, no `continue-on-error`, no pipe after the runner (run: `k6 ... | grep` reported grep's 0 for a run that exited 99).

## Mirroring the SLI

The earlier gate could not give a true verdict. Run: one test subject at 30 requests a second against a healthy service with the product's own limiter (10 a second per subject): k6 reported `http_req_failed` 60.46% (182 of 301), the threshold `rate<0.005` was crossed and k6 exited 99, while the service returned no 5xx at all. The SLI it claimed to copy counts every non-5xx answer as good.

Three corrections, all in `lib/gate.js`:

1. **Declare what the SLI counts as good.** k6 counts only 200 to 399 as expected. `http.setResponseCallback(http.expectedStatuses(...))` with the SLO's definition makes `http_req_failed` the SLI's error ratio. Its threshold is `rate < 1 - objective`.
2. **Judge latency on good answers only**: `http_req_duration{expected_response:true}`. Fast error answers otherwise pull the percentile down (SRE: distinguish the latency of successful and failed requests). Run: with the service unreachable every request "took" 0 ms and a latency threshold alone passed.
3. **Catch a broken test separately.** Counting 4xx as good would let a run of 401 answers pass. `wrong_answer` counts any answer that is neither the journey's expected status nor a server error, with threshold `rate==0`.

Run with the corrected gate: healthy service exit 0; slowed to 150 ms against a 100 ms target exit 99 on latency; one 500 in twenty exit 99 on the error ratio.

## 429: when it is right and when it is wrong

A 429 from the rate limiter is the product working as designed, not unavailability.

- **Inside the stated demand, there must be none.** The profile spreads the rate over enough subjects that each stays under its limit; the script refuses to start otherwise. A 429 there means the profile or the limiter configuration is wrong, and it fails its own threshold (`rate_limited: count==0`), named for what it is. It is not counted as an SLO error.
- **In the overload check, 429 is the expected answer.** One subject is driven above its limit. The run fails when an answer is neither accepted nor 429 (`overload_wrong_answer`), when a 429 lacks `Retry-After` (`shed_correct`), when nothing is shed (`shed_total: count>0`), when more is accepted than rate times seconds plus burst (`accepted_total`), or, in the verdict tier, when accepted requests miss the latency target (`accepted_duration`).

That a single request over the limit gets 429 with the right body is proven in `go-integration-test`. The load test confirms the behaviour holds under load.

What good looks like past the limit (SRE, "Addressing Cascading Failures"): the product serves errors or degraded answers for the excess "but not significantly reduce the rate at which it successfully handles requests", fails "early and cheaply", and recovers without help when the load drops.

| Shape | Seen as | Verdict |
|---|---|---|
| Graceful: excess shed fast, accepted requests still fast | 281 of 400 answered 429 with `Retry-After`, 119 accepted at 0.3 ms (run) | Pass |
| Limiter not engaging | 401 accepted, none shed (run) | Fail |
| Silent queuing: everything accepted, latency climbing | accepted p(95) 833 ms and 142 dropped iterations (run) | Fail, reported INVALID because the generator ran out of users |
| Collapse | 5xx or timeouts for every request | Fail |

Livelock looks like saturation: CPU busy, little completed (Cox-Buday). Accepted throughput in the report, not CPU alone, shows the difference.

## Every rule must be able to fail the run

A `check()` records a result and never changes the exit status (k6 documentation; run). A rule stated only in a `check()` is not a rule. Use a threshold on a custom metric, or on `checks` (optionally by tag). A Rate metric with no samples passes its threshold (run), so a rule of the form "every X has Y" also needs "there was at least one X".

## Invalid runs

A run is INVALID, never passed, when:

- **Iterations were dropped.** The generator did not offer the stated load. The scripts threshold `dropped_iterations` too, so plain k6 exits 99; the runner separates the two meanings.
- **The generator was saturated.** k6's guidance is to keep at least 20% of the generator's CPU idle; above that, measured times are too long. The runner measures the CPU time k6 used and calls the run invalid at 80% of the machine's CPUs. It cannot see other processes: on a shared machine, low k6 usage does not prove the generator was unhindered. This check has no automated test.
- **No request was sent, or no threshold was declared, or k6 wrote no summary, or k6 exited with anything but 0 or 99.**

Fix the test and run again. An invalid run is not evidence for or against the product.

## No retries

A load verdict is one run. A failed run is investigated, not repeated until green (`test-pyramid`: zero retries below the end-to-end layer). A second run after a fix is a new result with its own report. The scripts send each request once: a client-side retry would hide the error it should count.

## The indicative comparison

The indicative tier never judges latency against a target. For the average-load line the runner compares the gated percentile with the previous passing run and fails when it rose by more than the profile's `tolerance_percent`.

Two runs are compared only when all of these match: test type and shape, the scripts and profile (by hash), the k6 version, CPU count, architecture, operating system and `LOAD_RUNNER_CLASS`. Otherwise the result says "not comparable" and names what changed.

What still differs between two "comparable" runs and cannot be controlled: other tenants of the hosted runner's hardware (GitHub documents no performance guarantee), the kind node and the generator sharing the same CPUs, and whatever else the runner was doing. So a difference is a prompt to look at the change, and the report says so. Run: 1.87 ms then 1.89 ms on the same machine (within tolerance); 11.83 ms after an 8 ms delay was added to the service (reported as a rise of 533.9%, red).

## What a pass means

A verdict-tier PASS says: at this rate, for this run's length, in the environment and with the data the designation records, the SLI met its objective. It does not prove the rolling window: an SLO over 28 days cannot be shown by a run of minutes or hours. Every report states this, and `alerting-rules-design` watches the real window in production.
