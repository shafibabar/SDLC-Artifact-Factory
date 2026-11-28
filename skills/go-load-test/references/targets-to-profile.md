# From Stated Targets to a Load Profile

Self-contained. Read when deriving or reviewing a load profile, when asked "how many users, how long, how much data", or when choosing between test types. The profile file is in `../templates/profile.md`. Method sources: the k6 documentation (v2.4.x), Google's SRE books, Gil Tene's wrk2 and HdrHistogram notes, Kleppmann, and Humble and Farley, as recorded in this repository's research notes. Figures marked "run" come from k6 v2.4.0 against a lab Go service on 2026-11-28.

## Contents
The route; what the sources do not give; open and closed models; test types; journey mix and data; what is left to other skills.

## The route, in order

1. **Find the requirement.** In `ideate/nfr-specification.md`, take the performance rows (`NFR-PERF-nn`): the **Environment** cell (the peak, the data size, where), the **Source** (who and how many) and the **Response measure** with its Must, Plan and Stretch levels. Test the Must level unless the test strategy names another. A scalability claim must name its load parameter (Kleppmann): requests a second, read to write ratio, fan-out.
2. **Find the definition of good.** In the SLO record (`slo-definition`), take the availability row (objective, and which answers count as good: for a synchronous API, "a response that is not a 5xx") and the latency row (percentile and limit). Record the row ids. Thresholds copy these; they are never chosen by the test.
3. **Find the limit per subject.** Read the product's rate-limit configuration (`go-middleware`: a token bucket per authenticated subject, default 10 a second sustained, burst 20). Divide the target rate by it: that is the least number of test subjects.
4. **Write the rate.** A requests-per-second figure in the Environment cell is the rate. Use the peak hour, not a daily or monthly average: "Daily averages can mask significant traffic variations" (k6). An average also hides bursts: 200 requests a second in even seconds and none in odd ones has the average of a constant 100 and twice the instantaneous load (SRE).
5. **Record every number the sources do not give** (next section) with who decided it and why.
6. **Fill `tests/load/profile.json`**; the runner refuses it otherwise.

No NFR row or no SLO: there is nothing to verify. Say so and ask `requirements-analyst` or `platform-engineer` for it. Do not invent a target, and do not present a default as one. The indicative tier can still run, because it claims no target.

## What the sources do not give

Each of these is a judgement or a product decision. The skill supplies no default.

| Question | What the sources say | Who decides |
|---|---|---|
| How long must a run be, and how many requests, for a stable 95th or 99th percentile? | Nothing numeric. wrk2 says runs shorter than 10 to 20 seconds "may not present useful information"; an SLO names its own aggregation window (SRE) | Product owner, on the test-strategist's proposal |
| Should warm-up samples count? | A ramp warms caches and connections (SRE, k6); whether to discard those samples is not stated | Recorded as `warm_up` |
| How long a ramp and a hold? | k6 suggests a ramp of 5 to 15 percent of the run and a hold at least five times the ramp | Test-strategist |
| How many virtual users? | k6's estimate: median iteration time times rate, plus a margin for variance. Avoid `maxVUs`: allocating mid-run skews results | Test-strategist; dropped iterations show when it was too few |
| How do "200 concurrent users" become requests a second? | No rule. k6 gives concurrent users from hourly sessions and session length, not a rate | Product owner; or the NFR is restated as a rate |
| How far above peak is a stress test? | "There's no fixed percentage" (k6). Launch peaks have been 15 and 25 times the estimate (SRE) | Product owner |
| How much data? | Only that varied data keeps a cache from being what is measured (k6). The NFR's Environment cell is the source for volume | Product owner |
| What change between two indicative runs matters? | Nothing | Product owner (`tolerance_percent`) |

## Open and closed models

A **closed** model (`constant-vus`, `ramping-vus`) has each virtual user wait for its answer before sending again. When the product slows, the test sends less, so the slow period is under-sampled: coordinated omission (Tene; k6). An **open** model (`constant-arrival-rate`, `ramping-arrival-rate`) starts iterations at the stated rate whatever the answers do.

Run, same service, 20 ms per request with one 5-second stall, 20 seconds:

| Model | Requests | p(90) | p(95) | p(99) | Slowest |
|---|---|---|---|---|---|
| Closed, 2 virtual users | 1,352 | 22 ms | 22 ms | 23 ms | 5,013 ms |
| Open, 50 a second | 1,001 | 3,008 ms | 4,003 ms | 4,801 ms | 5,003 ms |

The closed run saw the stall twice. The open run charged it to the 250 requests that should have been sent during it.

- **A rate target is always tested with the open model.** This includes ramps and the breakpoint test.
- **The closed model is right** where the real callers are a fixed pool that waits for each answer (a batch worker pool, a job runner with a set number of connections) and the target is stated per caller, and for the smoke test. State the reason on the line (`// closed-model: <reason>`); the validator asks for it.
- With the open model, **too few virtual users drop iterations**: k6 cannot start an iteration and counts it in `dropped_iterations` (run: 197 dropped with 2 virtual users against a 150 ms service, with the warning `Insufficient VUs`). The offered load was then lower than stated, so the run is INVALID. Late drops can also mean the product slowed until the users ran out; the remedy is the same, more pre-allocated users, and the latency then shows the slowdown.

## Test types

| Type (k6's names) | Shape | Answers | Tier |
|---|---|---|---|
| Smoke | A few iterations | Do the script, the identities and the gate work? | Both, first |
| Average load | Ramp to the stated peak, hold | Do the targets hold at the stated demand? | Verdict. Indicative at a small rate, for comparison only |
| Stress | The same shape at a higher rate | How does it behave above the peak? | Verdict only |
| Spike | Sudden rise, short stay, back | Does it survive and recover? SRE advises testing both gradual and sudden load, because caches make them differ | Verdict only |
| Soak | The stated demand for hours | Leaks, growing tables, slow drift | Verdict only |
| Breakpoint | Rate rises until a target is missed | Where is the limit for this sizing? Capacity planning then follows (SRE: breaking point and peak give the number of instances) | Verdict only; avoid where the environment adds capacity by itself (k6) |
| Overload check (this skill's name) | One subject above its limit | Does the product shed correctly? See `./gate-and-verdict.md` | Both |

## Journey mix and data

- Model the journeys the NFR row names, in the proportions the requirements state. One endpoint with one payload measures a cache or one row.
- Different requests cost different amounts (SRE: requests a second is a weak unit of capacity), so the mix is part of the profile and of the report.
- Test data is created in the environment under test only: through the public API or the environment's own seed job. Never a copy of customer data without the product owner's decision (`test-fixture-design`). Third-party systems are stand-ins: a load test must not send email, charge cards or call a partner.

## Left to other skills

In-process speed of one function: `go-performance-test`. Faults injected on purpose: `go-chaos-test`. That a single over-limit request gets 429: `go-integration-test`; this skill confirms it still holds under load. The requirement and the SLO themselves: `nfr-specification`, `slo-definition`.
