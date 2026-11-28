# The Gate: Thresholds, Exit Statuses and the Verdict

Self-contained. Read when writing or reviewing thresholds, when a run fails or passes unexpectedly, when 429 or 503 answers appear, or when deciding what a result means. The gate (`lib/gate.js`, the test-type scripts and `run-load-test.sh`) is the same program for a Go and a Python service; `go-load-test` owns its full reasoning and ran every exit status below with k6 v2.4.0 on 2026-11-28. This skill ran the same gate against a FastAPI lab service the same day; those runs are marked "run (Python)".

## Contents
What k6 exits with; mirroring the SLI; 429; the server's own 503; rules that can fail; invalid runs; no retries; the indicative comparison; what a pass means.

## What k6 exits with

| Situation | k6 exit |
|---|---|
| Every threshold held | 0 |
| A threshold crossed (at the end, or by `abortOnFail`) | **99** |
| Interrupted by SIGINT or SIGTERM | 105 |
| Exception while loading the script or in `setup()` (also the gate's own `REFUSED` and `PROFILE ERROR`) | 107 (run (Python): `k6 run` by hand, and 24 a second over one subject) |
| **Exception in every iteration** | **0** |
| Every `check()` failed, no threshold on `checks` | **0** |
| `--no-thresholds` | 0 whatever happened |

So 99 means the service missed a target, 105 means nobody knows, 107 means the test is broken, and **0 means nothing by itself**. `run-load-test.sh` reads the status and the summary together and gives one verdict:

| Verdict | Runner exit | When |
|---|---|---|
| PASS / INDICATIVE PASS | 0 | k6 exit 0, thresholds present, requests sent, nothing dropped, generator not saturated |
| MEASURED | 0 | A breakpoint run: the rate reached; never a gate |
| FAIL | 1 | k6 exit 99, or an indicative regression beyond the tolerance |
| REFUSED | 3 | The target is not allowed; no request of the test was sent |
| INVALID | 4 | The run proves nothing (below). **INVALID outranks FAIL**: a run that dropped load and also crossed thresholds is INVALID, with the crossed thresholds listed |
| ABORTED | 130 | k6 exit 105 |

Never hide the status: no `|| true`, no leading `-` in a make recipe, no `continue-on-error`, no pipe after the runner (a pipe reports the last command's 0 for a run that exited 99).

## Mirroring the SLI

1. **Declare what the SLI counts as good.** k6 counts only 200 to 399 as expected, so a healthy service whose limiter answers 429 "fails" (run with `go-load-test`: 60% failed on a service with no 5xx). `http.setResponseCallback(http.expectedStatuses(...))` with the SLO's good statuses makes `http_req_failed` the SLI's error ratio; its threshold is `rate < 1 - objective`.
2. **Judge latency on good answers only**: `http_req_duration{expected_response:true}`. Fast error answers otherwise pull the percentile down. Never an average.
3. **Catch a broken test separately**: `wrong_answer` counts an answer that is neither the journey's expected status nor a server error, threshold `rate==0`.

A threshold is the SLO's own percentile. A 99.5% objective on "requests under 800 ms" is a ratio of requests over the limit, not a p99: gate the ratio the SLI defines.

## 429: when it is right and when it is wrong

- **Inside the stated demand there must be none.** The profile spreads the rate over enough subjects that each stays within one process's rate (`./targets-to-profile.md`); a 429 there fails `rate_limited: count==0`, named for what it is, and means the profile or the limiter configuration is wrong.
- **In the overload check 429 is the expected answer.** One subject is driven above the processes' total. The run fails when an answer is neither accepted nor 429 (`overload_wrong_answer`), when a 429 lacks `Retry-After` (`shed_correct`), when nothing is shed (`shed_total: count>0`), when more is accepted than the total rate times seconds plus burst (`accepted_total`), or, in the verdict tier, when accepted requests miss the latency target. Run (Python): one worker, 120 accepted and 281 shed, PASS; four workers with the profile at one process's rate, 219 accepted against at most 121, FAIL.

What good looks like past the limit (SRE): the excess is answered fast and cheaply, accepted requests stay fast, and the service recovers without help when the load drops. Silent queuing (everything accepted, latency climbing) and collapse (5xx or no answer for everything) both fail.

## The server's own 503

uvicorn answers 503 itself when `--limit-concurrency` is reached; the application never sees those requests. **The gate counts it as the SLI defines it**: under "not a 5xx" it is a bad answer in `http_req_failed`, and in the overload check it is a wrong answer. It is never added to the good statuses. It is told apart, not excused: the Python `journey.js` counts it as `server_shed` (503, body `Service Unavailable`, `text/plain`), separately from the application's 5xx and from requests with no answer, and `../scripts/sort-server-errors.sh` prints the split for the report. Run (Python): average load with the limit at 10, FAIL, all 252 failures `server_shed`; overload, FAIL on `overload_wrong_answer`. Details and the fix: `./python-saturation.md`.

## Every rule must be able to fail the run

A `check()` never changes the exit status. A rule stated only in a `check()` is not a rule: use a threshold on a custom metric or on `checks`. A Rate metric with no samples passes its threshold, so "every X has Y" also needs "there was at least one X".

## Invalid runs

A run is INVALID, never passed, when:

- **Iterations were dropped.** The generator did not offer the stated load: too few virtual users, or the service slowed until they ran out. Run (Python): an exhausted asyncpg pool with no acquire timeout, 34 dropped, p(95) 2,198 ms, no error; INVALID, with the crossed latency threshold listed. The remedy is more pre-allocated virtual users (and then the latency shows the slowdown), or the service's fix; then a new run.
- **The generator was saturated**: less than 20% of its CPU left idle (k6's guidance). The runner measures the CPU time k6 used against the machine's CPUs; it cannot see other processes.
- **No request was sent, no threshold was declared, k6 wrote no summary, or k6 exited with anything but 0 or 99.**

An invalid run is not evidence for or against the service.

## No retries

A load verdict is one run. A failed run is investigated, not repeated until green (`test-pyramid`: zero retries below the end-to-end layer). A second run after a fix is a new result with its own report. The scripts send each request once.

## The indicative comparison

The indicative tier judges no latency target. For the average-load line the runner compares the gated percentile with the previous passing run and fails when it rose by more than the profile's `tolerance_percent`; two runs are compared only when test type and shape, scripts and profile (by hash), k6 version, CPU count, architecture, system and `LOAD_RUNNER_CLASS` match. Run (Python, `../examples/01-lean-seed-library.md`): 2.69 ms, then 2.55 ms (within tolerance), then 12.64 ms after an 8 ms delay was added (a rise of 369.2%, FAIL). A difference is a prompt to look at the change, never a capacity figure.

## What a pass means

A verdict-tier PASS says: at this rate, for this run's length, in the environment, sizing, workers, replicas and data the designation records, the SLI met its objective. It does not prove the rolling SLO window; `alerting-rules-design` watches that in production. A run under an impact statement is a verification of that system at that time, not a capacity verdict.
