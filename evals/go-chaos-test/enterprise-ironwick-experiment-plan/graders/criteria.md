---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It requires a steady-state hypothesis written before the fault is injected, on an output metric as the product's SLO defines it (for example the success rate or latency of payment requests), in place of judging the dashboards afterwards. It also says the experiment is invalid, not passed, if that steady state did not hold before injection.
2. It fixes the abort watcher so the fault is always removed when the abort condition is met, when the experiment ends or fails, or when the run is interrupted, and the removal is verified. A watcher that only exits leaves the packet loss in place.
3. It replaces the `scheduler` field with a separate Chaos Mesh `Schedule` object, because the `scheduler` field inside an experiment was removed in Chaos Mesh 2.0.
4. It does not re-prove the Dead Letter Queue in the chaos experiment, because that is already proven by integration tests. A check that the Dead Letter Queue still holds while the network fault is active is acceptable.
5. It refuses to write a circuit breaker inside the test. It says that if the `ledger` service has no breaker on `fraud-scoring`, the reply or the report states plainly that the pattern is missing, rather than testing a stand-in.
Fail if any of the 5 is missing.
