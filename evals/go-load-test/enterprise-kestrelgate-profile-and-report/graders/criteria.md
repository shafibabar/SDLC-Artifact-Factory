---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It derives the load profile from the stated targets (450 requests per second and p99 under 300 ms from NFR-PERF-04, and the SLO), and it does not present the 1 hour, no warm-up and 10,000 quotes as standard defaults: run length, warm-up and data volume are stated as judgements or product decisions recorded in the report.
2. It says the 2,300 dropped iterations make the run invalid rather than passed, because the load generator lacked virtual users and so did not deliver the intended load.
3. It says `increase()` is for counters only and replaces it for the `dispatch_queue_depth` gauge with a gauge-appropriate measure (for example `delta()` or the difference between its values at the start and end of the run).
4. It pins the Prometheus query to the run's start and end, instead of a fixed two-hour window evaluated at an arbitrary time, so other traffic is not counted.
5. It rejects running the load test on every pull request, placing it nightly or by hand and before a release, and it says the load-test report is approved by the product owner, not only by the tech lead.
Fail if any of the 5 is missing.
