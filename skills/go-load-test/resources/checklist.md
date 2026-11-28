# Go Load Test Checklist

Copy and tick before hand-off.

## Targets and profile
- [ ] The NFR row (`NFR-PERF-nn`, with its level) and the SLO rows are named by id in `tests/load/profile.json`
- [ ] The error definition is the SLI's (its good statuses), the latency target is the SLO's percentile and limit; no average
- [ ] The rate is the stated peak; every number the sources do not give has `decided_by` and `reason`
- [ ] No target, rate, run length or data volume was invented or offered as a default
- [ ] Steady load is spread over enough subjects to stay within the per-subject rate limit
- [ ] The journey mix and the data variety are the requirement's, or a recorded decision

## Tiers and targets
- [ ] The indicative tier is planned at every product size; its numbers are in the `indicative` block
- [ ] A verdict is planned only where a designated performance environment is approved; otherwise the designation was put to the product owner
- [ ] No address is written into a script, a make line or a workflow; none is read from a variable
- [ ] The designation record has the exact address, sign-off, expiry, sizing, data, generator, test types and token lifetime
- [ ] The designated environment, and only it, serves the designation marker
- [ ] Nothing aims at shared staging, production, a tenant environment or any other undesignated system without the product owner's signed impact statement for that exact address
- [ ] Each impact statement names the address, purpose, test type and profile limit, data and its removal, who and what is affected, how to stop it and who watches, the window, the sign-off and an expiry or single run; its marker is served, or the statement says why it cannot be
- [ ] A run under a statement is reported as a verification, not a capacity verdict, with the statement recorded verbatim

## Gate
- [ ] `lib/gate.js` and the test-type scripts are copied unchanged; only `journey.js` is the product's
- [ ] Every rule is a threshold; no bare `check()`
- [ ] A rate target uses an arrival-rate executor; any closed model states its reason
- [ ] The overload check expects 429 with `Retry-After` and fails on anything else, on no shedding and on too many accepted
- [ ] Nothing hides the exit status: no pipe, `|| true`, leading `-`, `continue-on-error` or `--no-thresholds`
- [ ] No retry of a request or of a run

## Credentials, data, monitoring
- [ ] No stored credential: no `secrets.`, no token file in the repository
- [ ] Verdict-tier tokens state an expiry within the limit of the record and of any statement
- [ ] Test data exists only in the environment under test; third parties are stand-ins
- [ ] Nothing is pushed to any monitoring system; queries read the environment's own Prometheus, pinned to the run
- [ ] `rate()` and `increase()` only on counters; `max_over_time()` or `delta()` on gauges

## Pipeline
- [ ] No load test on a pull request and none in `make ci`
- [ ] The indicative lines are the last lines of `E2E_SUITES`; `make load-indicative` uses the same lines
- [ ] The verdict is a job the publishing job needs; no `release:` trigger
- [ ] k6 is pinned to v2.4.0 with a checksum; no other load tool; no paid service without approval

## Run
- [ ] `validate-go-load-tests.sh` has no FAIL; each WARN judged
- [ ] `make load-indicative` passed and the cluster is gone afterwards
- [ ] The gate was seen to fail once for the expected reason
- [ ] Every result is PASS, FAIL, INVALID or MEASURED from the runner; an INVALID run was fixed and run again, not reported as passed
- [ ] The report was drafted by `write-load-report.sh`, names the tier, says what the run does not prove, and was put to the product owner
- [ ] The reply says in words which tier ran and, for the indicative tier, that it proves nothing about capacity
- [ ] Anything not run (GitHub Actions, a real designated environment, a long soak, large data) is called unverified
