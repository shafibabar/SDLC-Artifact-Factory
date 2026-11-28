---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says marking a 429 as success inside the test script hides the rejections, and that 429s must instead be counted and reported separately so the gate counts errors the way the SLO does. Saying a 429 from the product's own rate limiter, within its design, need not count as a failure does not fail.
2. It says a 99.5% latency target must be gated at the 99.5th percentile (or on the share of requests slower than 800 ms), not at p99, because p99 can pass while the 99.5% target is missed.
3. It says `constant_throughput` is not an open model: it paces each user, who still waits for each response, so when the server stalls fewer requests are sent and latency is understated. It replaces it with an arrival-rate (open) workload.
4. It says the gate must not read the ramp run that is designed to break the service, and must instead gate on a run held at the target load. Keeping the ramp run to report where the service breaks does not fail.
5. It removes `|| true` so a failed threshold's non-zero exit status fails the CI step, and it removes the retries.
Fail if any of the 5 is missing.
