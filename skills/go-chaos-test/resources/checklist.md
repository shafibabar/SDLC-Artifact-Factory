# Chaos Experiments: Checklist

Self-contained. Copy into the working notes and tick each line before answering or handing off. A line that cannot be ticked is either fixed or stated in the answer as open.

## Plan
- [ ] Every downstream listed with each pattern **present** (with its settings) or **missing**; every missing pattern named in the answer and the report, with its corrective action.
- [ ] Every experiment targets the run's own throwaway cluster, or a system named in a **signed, current** chaos statement (`tests/chaos/statements/<id>.json`); nothing else.
- [ ] Chaos Mesh appears only as the pinned release line of `tests/chaos/chaos-e2e.conf`; never under a statement, never installed by hand.
- [ ] The fault for each hypothesis uses the first tool that can produce it: in-process `RoundTripper` or hook, then Toxiproxy, then Chaos Mesh.

## Each experiment
- [ ] Hypothesis worded "users still get X when Y fails".
- [ ] Steady state is the SLO's SLI exactly (id, words, good statuses, threshold, objective), not a percentile or an average.
- [ ] Blast radius in words; every Chaos Mesh selector names exactly its own namespace and the pods' labels.
- [ ] Abort numbers set (`sli_below`, `over_seconds`, `max_seconds`); a sustained Chaos Mesh fault has a `duration` no longer than `max_seconds`.
- [ ] Where the product marks degraded answers, `fault_header` is set, so a fault that never reached the measured path is INVALID.
- [ ] No `spec.scheduler`; a repeated fault is a `Schedule`.

## Each pattern test
- [ ] Reads the product's own settings; invents no threshold.
- [ ] Breaker: closed below the threshold, open at it, fails fast with zero calls reaching the dependency, half-open not before the reset with one probe, reopened by a failed probe, closed by a good one.
- [ ] Retry: exactly the attempt cap at the dependency, waits within caps with jitter, a permanent answer once, stopped by the caller's deadline, at most threshold × attempts while the dependency stays down; every call has its own deadline.
- [ ] Timeout: returns by the caller's deadline and the dependency sees the request end.
- [ ] Bulkhead: a full pool refuses at once; another downstream is served.
- [ ] Degradation and shedding asserted on the answer the SLI counts.
- [ ] Lock order exercised through the shipped code, with a stall detector and a goroutine dump.
- [ ] DLQ, idempotency and 429 only confirmed under a fault, not re-proven (`go-integration-test`).
- [ ] Every Toxiproxy call's error checked (`chaostest.AddToxic`); every file `//go:build chaos`.

## Running
- [ ] `./tests/chaos/validate-go-chaos-tests.sh .`: no FAIL; each WARN judged.
- [ ] `make chaos` run; one pattern broken on purpose failed for the stated reason; restored; the cluster is gone.
- [ ] No retry anywhere; never on a pull request; not in `make ci`.

## Report
- [ ] `artifacts/<product>/quality/test-reports/chaos-<date>.md` from `../templates/chaos-experiment-report.md`, frontmatter complete, verdicts and reasons verbatim, what it does not prove, corrective actions, put to the product owner for approval.
- [ ] One line on what was run; everything not run called unverified.
