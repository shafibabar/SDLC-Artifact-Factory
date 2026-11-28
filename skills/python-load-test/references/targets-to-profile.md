# From Stated Targets to a Load Profile for a Python Service

Self-contained. Read when deriving or reviewing a Python product's load profile, when asked "how many users, how long, how much data", when the service has several workers or replicas, or when choosing between test types. The file is in `../templates/profile.md`. `go-load-test` owns this method for every stack; this page holds what a Python product needs of it and what differs. Sources: the k6 documentation (v2.4.x), Google's SRE books, Gil Tene's notes on coordinated omission, Kleppmann, Humble and Farley, and the official uvicorn, asyncpg and prometheus_client documentation, as recorded in this repository's research notes. Figures marked "run" come from k6 v2.4.0 against a lab FastAPI service (FastAPI 0.165.0, uvicorn 0.54.0, Python 3.15.2) on 2026-11-28.

## Contents
The route; the server's shape and the per-process limiter; what the sources do not give; open and closed models; test types; journey mix and data; what is left to other skills.

## The route, in order

1. **Find the requirement.** In `ideate/nfr-specification.md`, take the performance rows (`NFR-PERF-nn`): the **Environment** cell (the peak, the data size), the **Source** and the **Response measure** with its Must, Plan and Stretch levels. Test the Must level unless the test strategy names another.
2. **Find the definition of good.** In the SLO record (`slo-definition`), take the availability row (objective, and which answers count as good: for a synchronous API, "a response that is not a 5xx") and the latency row (percentile and limit). Record the row ids. Thresholds copy these; they are never chosen by the test.
3. **Find the server's shape.** Workers per replica and replicas in the environment under test, and uvicorn's `--limit-concurrency` (next section). Record where each is configured.
4. **Find the limit per subject.** Read the product's rate-limit configuration (`python-middleware`: a token bucket per authenticated subject, default 10 a second sustained, burst 20, **kept in each process's memory**). Multiply by the processes for the profile's total; divide every steady rate by the **per-process** rate for the least number of test subjects.
5. **Write the rate.** A requests-per-second figure in the Environment cell is the rate. Use the peak hour, not a daily average: "Daily averages can mask significant traffic variations" (k6).
6. **Record every number the sources do not give** with who decided it and why.
7. **Fill `tests/load/profile.json`** and run `../scripts/check-python-profile.sh tests/load/profile.json --subjects <n>`; the runner refuses a profile with an unowned number, the check refuses a limiter that was not multiplied.

No NFR row or no SLO: there is nothing to verify. Say so and ask `requirements-analyst` or `platform-engineer` for it. Do not invent a target, and do not present a default as one. The indicative tier can still run, because it claims no target.

## The server's shape and the per-process limiter

A Python service answers from one or more processes, and three things in it count **per process**:

| Counted per process | What it means under load | Run |
|---|---|---|
| `python-middleware`'s rate limiter (in-memory buckets) | One subject meets the per-process rate times workers times replicas before every process answers 429. The overload check must exceed that total or nothing is shed | One worker, one subject at 40 a second for 10 s: 120 accepted, 281 answered 429. Four workers, profile still at 10 a second: 219 accepted against at most 121, **FAIL**. Profile at 40 a second and burst 80 with overload at 160 a second: 358 accepted (at most 481), 1,243 answered 429, PASS |
| uvicorn's `--limit-concurrency` | Above it uvicorn answers 503 itself instead of queuing; the count includes open keep-alive connections, idle ones too | Ten idle connections made the eleventh request a 503 |
| The asyncpg pool | `max_size` connections per process; `acquire()` waits forever by default | See `./python-saturation.md` |

`python-dockerfile` runs one uvicorn process per container and scales with replicas, so normally `workers` is 1 and the processes are the replicas. A subject's requests are **not** spread evenly over processes: k6 keeps a connection per virtual user, and which process a connection lands on is up to the kernel or the Service in front (run: four workers took 219 of 400 requests where four even processes would have taken all of them). So steady load keeps each subject within **one process's** rate: that guarantees no 429 wherever the requests land. The total is only the overload check's ceiling. The shared gate cannot see processes; `check-python-profile.sh` holds this rule.

The throwaway cluster's values file sets the same workers and replicas as the designated environment, or one of the two tiers computes the overload ceiling from the wrong number of processes.

## What the sources do not give

Each of these is a judgement or a product decision. The skill supplies no default.

| Question | What the sources say | Who decides |
|---|---|---|
| How long must a run be, and how many requests, for a stable 95th or 99th percentile? | Nothing numeric; runs shorter than 10 to 20 seconds "may not present useful information" (wrk2); an SLO names its own window (SRE) | Product owner, on the test-strategist's proposal |
| Should warm-up samples count? | A ramp warms caches, connections and the pool; whether to discard those samples is not stated | Recorded as `warm_up` |
| How long a ramp and a hold? | k6 suggests a ramp of 5 to 15 percent of the run and a hold at least five times the ramp | Test-strategist |
| How many virtual users? | Median iteration time times rate, plus a margin (k6); each one holds a connection, which counts against `--limit-concurrency` | Test-strategist; dropped iterations show too few |
| How do "200 concurrent users" become requests a second? | No rule | Product owner; or the NFR is restated as a rate |
| How far above peak is a stress test? | "There's no fixed percentage" (k6) | Product owner |
| How much data? | Only that varied data keeps a cache from being what is measured (k6); the NFR's Environment cell gives volume | Product owner |
| What change between two indicative runs matters? | Nothing | Product owner (`tolerance_percent`) |

## Open and closed models

A **closed** model (`constant-vus`, `ramping-vus`, and locust's users with think time, `constant_throughput` included) waits for each answer before sending again: when the service slows the test sends less, and the slow period is under-sampled (coordinated omission: Tene; k6). An **open** model (`constant-arrival-rate`, `ramping-arrival-rate`) starts iterations at the stated rate whatever the answers do. The earlier version of this skill claimed `constant_throughput` made locust open; it paces each user but still waits for the answer, so it is closed.

Run with `go-load-test` (same k6, same scripts), 20 ms per request with one 5-second stall: closed with 2 users p(99) 23 ms; open at 50 a second p(99) 4,801 ms. The closed run saw the stall twice.

- **A rate target is always tested with the open model**, ramps and the breakpoint test included.
- **The closed model is right** only where the real callers are a fixed pool that waits for each answer, with the reason on the line (`// closed-model: <reason>`), and for the smoke test.
- With the open model, **too few virtual users drop iterations**, and so does a service that slowed until the users ran out (run: pool exhaustion, 34 to 35 dropped). Either way the stated load was not offered: the run is INVALID.

## Test types

| Type (k6's names) | Answers | Tier |
|---|---|---|
| Smoke | Do the script, the identities and the gate work? | Both, first |
| Average load | Do the targets hold at the stated demand? | Verdict. Indicative at a small rate, for comparison only |
| Stress | How does it behave above the peak? | Verdict only |
| Spike | Does it survive and recover? | Verdict only |
| Soak | Leaks, growing tables, a pool or a queue that never drains | Verdict only |
| Breakpoint | Where is the limit for this sizing? | Verdict only; never where the environment scales itself |
| Overload check (this skill's name) | Does the service shed correctly past its limit? | Both |

## Journey mix and data

- Model the journeys the NFR row names, in the proportions the requirements state; one endpoint with one payload measures a cache.
- Test data is created in the environment under test only: through the public API or its own seed job. Never a copy of customer data without the product owner's decision (`test-fixture-design`). Third parties are stand-ins.
- **Tenancy is read from the design**, not assumed: the tenancy decision says whether tenants share a deployment (pooled), so one tenant's load reaches the others, or have their own (siloed). Test subjects follow it: one subject per test tenant or test member, as the design's unit of rate limiting.
- Asynchronous work (a queue fed by the requests): offer the load with k6, wait by polling until the lag gauge is back to its level before the run, then read freshness and correctness from the environment's Prometheus (`./python-saturation.md`).

## Left to other skills

In-process speed of a function: `python-performance-test`. A fault injected on purpose (a slow dependency, an injected event-loop stall): `python-chaos-test`. That one over-limit request gets 429 with the right body: `python-integration-test`; this skill confirms it holds under load. The acquire timeout and the answer it maps to: the service's own skills (`python-service-layer`). The requirement and the SLO: `nfr-specification`, `slo-definition`.
