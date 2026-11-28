# The Experiment: Steady State, Hypothesis, Blast Radius, Abort, Verdict

Self-contained. Read before writing an experiment definition, when a steady state, a hypothesis, an abort condition or a verdict is in question, or when someone reads a pass as proof. Sources: the Principles of Chaos Engineering (POC), Basiri et al., "Automating chaos experiments in production" (ChAP, Netflix, 2019), and the SRE book's chapters on testing for reliability, handling overload and cascading failures, all in `research/testing/chaos-engineering-method-official-docs.md`. Rosenthal and Jones's *Chaos Engineering* was not available to the research and nothing here is drawn from it.

## 1. Steady state: the SLO's own SLI, on output

POC: define steady state as "some measurable output of a system that indicates normal behavior", and "focus on the measurable output of a system, rather than internal attributes". ChAP's steady state is stream starts per second, a count of successful outcomes.

Here the steady state is **the SLI exactly as the product's SLO record defines it** (`slo-definition`): a ratio of good events to valid events. For a latency SLO "requests completing in under 800 ms / all requests", the experiment's steady state is "the share of tide-window requests answered 200 in under 800 ms", with the SLO's objective (for example 0.99). Not "p99 < 800ms" (a percentile is not the SLI), not an average, not CPU or goroutine counts (internals).

How it is measured: `run-chaos-experiment.sh` sends its own steady requests to the product's endpoint (5 a second in the examples) and counts each answer good when its status is one the SLI counts as good and it came back under the threshold. That is the SLI seen from the user's side, which is what the hypothesis is about. Where the product exports the SLI's metric (`http_server_duration_seconds` buckets and `http_server_requests_total`, named by `prometheus-metrics-design`), the report may add the product's own reading for the run's window; the verdict comes from the probe.

The steady state is measured **before** injection for `window_seconds`. If it does not reach the objective, the run is **INVALID** and nothing is injected: a fault cannot be blamed for a breach that was already there (run: a path that answered 404 gave `the steady state did not hold before injection ... nothing was injected`, exit 4).

After removal the probe must keep its own pace (`probe_per_second`) for a whole window before recovery is judged. If it never does — a busy machine or a slow network, not the product — the run is **INVALID**, not a failed recovery: a slow probe must never be read as a product that did not recover. Keep `probe_per_second` modest (5 is the template's value); a shared CI machine was observed unable to sustain 20.

## 2. Hypothesis: users still get X when Y fails

ChAP's form: "users should still be able to stream video when the bookmarks service fails". Write it the same way, naming the fault and the user's outcome: "Users still get a tide window, answered 200 in under 800 ms, while the tide tables answer 2 s late." A hypothesis that only predicts trouble ("the system will struggle") cannot fail, so it proves nothing.

For a pattern proven in-process, the hypothesis names the pattern's defined behaviour and its numbers ("after 5 consecutive failures the breaker opens; while open no call reaches the dependency"), from `./patterns-and-assertions.md`.

## 3. Blast radius

State exactly what the fault may touch, in words the product owner can check: "the tides proxy of this run's cluster: every call from harbour to tides", "one harbour pod in namespace harbour". In the throwaway cluster the blast radius is small by construction. Every Chaos Mesh selector must name exactly the experiment's own namespace and the labels of the pods it may touch; the runner refuses anything wider. One fault at a time: combine two only once each has passed alone. Under a chaos statement, the blast radius is the one the product owner signed.

## 4. Abort: numbers set before injection, removal always

ChAP stops an experiment early on "excessive customer impact", publishes no threshold, and had to raise its error threshold "substantially" for noise. So the abort numbers are this product's, decided and written into the experiment before it runs:

- `sli_below` and `over_seconds`: remove the fault at once when the SLI over the last `over_seconds` falls below `sli_below` (0.9 over 10 s in the examples: a degradation far beyond what a working pattern allows).
- `max_seconds`: the hard bound on how long the fault stays, whatever happens. For a sustained Chaos Mesh fault, the manifest's `duration` repeats that bound inside the cluster, so a fault outlives a dead runner by at most that much; pause time counts toward `duration`.

The runner checks the abort on every probe while the fault is active. An abort removes the fault, verifies the removal, and gives FAIL: the hypothesis was disproved. Run: a product without a fallback, 2 s of latency on its dependency: `abort condition: ... was 0.000 over the last 10 s, below 0.9; the fault was removed at once`, and the proxy listed no toxic afterwards.

Removal happens on every path: pass, fail, abort, an error, and interruption (`Ctrl-C` or `SIGTERM` from the job). Run: `SIGINT` while a 2 s latency toxic was active gave `interrupted while the fault was active; nothing is concluded`, exit 130, and the toxic list was empty. A removal that cannot be verified exits 5 with `THE FAULT MAY STILL BE ACTIVE` and the exact command to remove it.

## 5. Verdicts

| Verdict | Exit | When |
|---|---|---|
| PASS | 0 | Steady state held before; the fault was confirmed active (Toxiproxy lists the toxic; Chaos Mesh reports `AllInjected`); the SLI held its objective during the fault; the removal was verified; the steady state returned within `recovery.within_seconds`. For a pytest run: every test passed, none skipped, and none reported INVALID |
| FAIL | 1 | The SLI fell below the objective during the fault, an abort fired, it did not recover, or a pattern assertion failed |
| REFUSED | 3 | The target is not allowed (see `./where-it-runs.md`); nothing was injected |
| INVALID | 4 | The steady state did not hold before injection; the fault was refused or never confirmed active; a pytest run reported `CHAOS-INVALID`, collected no test (exit 5), skipped a test or broke outside a test |
| (removal) | 5 | The fault's removal could not be verified: it may still be active |
| (interrupted) | 130 | Stopped; the fault was removed first; nothing is concluded |

Exit 2 is a configuration error (a definition or manifest the runner rejects). An INVALID run is never reported as passed and is never retried into a pass: fix the cause, then run again as a new run.

## 6. What a result means

"Passing a test or a series of tests doesn't necessarily prove reliability. However, tests that are failing generally prove the absence of reliability" (SRE book). A PASS says this fault, at this size, for this long, did not break this steady state in this run. ChAP calls its results weaknesses to investigate, not proof of resilience. Every report says so, and names the faults it did not try.

A FAIL is a finding, not a flaky test: it becomes a corrective action for the skill that owns the pattern (`integration-design` for the design, the Python build skills for the code), recorded in the report and taken to the product owner. `disaster-recovery-plan`'s drills are a separate discipline; an experiment does not replace a restore drill.

## The four lines a reviewer reads first

Every experiment definition carries them as fields, and every pytest experiment as a comment above the test:

```
EXPERIMENT  degrade-on-tides-latency
HYPOTHESIS  Users still get a tide window, answered 200 in under 800 ms, while the tide tables answer 2 s late
STEADY      SLO-TIDE-01: share of tide-window requests answered 200 in under 800 ms >= 0.99 over 20 s before injection
ABORT       below 0.9 over 10 s, or 60 s in all; the fault is removed and the removal verified on every path
```
