---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says the missing 429s do not show the rate limiter is broken: a limiter kept in process memory counts per worker process, so with 4 workers and 3 replicas the 429s begin only above about 50 × 4 × 3 = 600 requests per second for that client (assuming requests spread evenly).
2. It says the 503s with body `Service Unavailable` come from uvicorn's `--limit-concurrency`, which rejects excess requests without queueing them, so the application never saw them and they must not be logged as application errors.
3. It keeps those 503s in the availability SLI as unavailability (unless the SLI's own definition says otherwise), rather than dropping them because they came from the server.
4. It says latency rising with no errors is a sign of asyncpg pool exhaustion, because `pool.acquire()` waits with no limit unless an acquire timeout is set. It rejects "the soak passed" because latency far over target is a failure even with 0% errors.
5. It says Python's standard library provides no event-loop lag metric, so the lag has to be measured by the service itself, and it says a stalled event loop makes the whole process look hung.
Fail if any of the 5 is missing.
