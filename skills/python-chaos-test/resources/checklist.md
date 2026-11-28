# Python Chaos Experiments: Checklist

Self-contained. Copy into the working notes and tick each line before answering or handing off. A line that cannot be ticked is either fixed or stated in the answer as open.

## Plan
- [ ] Every downstream listed with each pattern **present** (with its settings and its library) or **missing**; every missing pattern named in the answer and the report, with its corrective action (no Python build skill provides a breaker, retry policy or bulkhead yet).
- [ ] Every experiment targets the run's own throwaway kind cluster, or a system named in a **signed, current** chaos statement (`tests/chaos/statements/<id>.json`); no per-test testcontainers stack, no staging "stage".
- [ ] Chaos Mesh appears only as the pinned release line of `tests/chaos/chaos-e2e.conf`; never under a statement, never installed by hand.
- [ ] The fault for each hypothesis uses the first tool that can produce it: `FaultTransport` or the stand-in `Dependency`, then `stall_app`, then Toxiproxy, then Chaos Mesh.

## Each experiment
- [ ] Hypothesis worded "users still get X when Y fails".
- [ ] Steady state is the SLO's SLI exactly (id, words, good statuses, threshold, objective), not a percentile or an average.
- [ ] Blast radius in words; every Chaos Mesh selector names exactly its own namespace and the pods' labels.
- [ ] Abort numbers set (`sli_below`, `over_seconds`, `max_seconds`); a sustained Chaos Mesh fault has a `duration` no longer than `max_seconds`.
- [ ] Where the product marks degraded answers, `fault_header` is set.
- [ ] A `pytest` definition carries `-m chaos`, `-p no:cacheprovider`, `-p no:rerunfailures`, `-o addopts=""` and `--tb=short`, and nothing that narrows or retries it.

## Each pattern test
- [ ] Reads the product's own settings; invents no threshold; any setting a test changes is commented with why.
- [ ] Breaker: closed below the threshold, open at it **as configured**, fails fast with zero calls reaching the dependency, one probe after the reset (five callers at once), reopened by a failed probe, closed by a good one; state read the library's own way; caller cancellation excluded.
- [ ] Retry: exactly the attempt cap at the dependency, waits within caps with jitter, a permanent answer once, stopped by the caller's deadline, at most threshold × attempts while the dependency stays down; a `stop` exists; every call inside `bounded`.
- [ ] Timeout: the caller's `TimeoutError` by its deadline, and the dependency sees its request end.
- [ ] Bulkhead: a full pool refuses at once (the semaphore's wait is bounded); another downstream is served.
- [ ] Event loop: a blocking call stalls only its own worker (lag probe, same-worker health check, another worker); the product's CPU-bound handler does not stall its worker.
- [ ] Degradation asserted on the answer the SLI counts.
- [ ] DLQ, idempotency and 429 only confirmed under a fault, not re-proven (`python-integration-test`).
- [ ] Every Toxiproxy answer checked (the `toxics` fixture, never `toxiproxy-python`); every chaos file under `tests/chaos/`.

## Running
- [ ] `./tests/chaos/validate-python-chaos-tests.sh .`: no FAIL; each WARN judged.
- [ ] `make test` still passes with `--skip-suite chaos`; a bare `pytest tests/chaos` is refused.
- [ ] `make chaos` run; one pattern broken on purpose failed for the stated reason; restored; the cluster is gone.
- [ ] No retry anywhere; never on a pull request; not in `make ci`.

## Report
- [ ] `artifacts/<product>/quality/test-reports/chaos-<date>.md` from `../templates/chaos-experiment-report.md`, frontmatter complete, verdicts and reasons verbatim, what it does not prove, corrective actions, put to the product owner for approval.
- [ ] One line on what was run; everything not run called unverified.
