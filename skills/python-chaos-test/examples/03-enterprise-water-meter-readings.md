# Enterprise: Water Meter Readings, Several Downstreams and One Signed Statement

Self-contained. Read for a Python product with several downstreams, utilities as tenants, a breaker present for one downstream and missing for another, a CPU-bound handler, and a request to run faults outside the throwaway cluster. Worked on paper from the shapes proven in `./02-standard-bike-share-docks.md`; **not run** as written (unverified).

## Input

Water Meter Readings collects meter readings for several water utilities and bills from them. The `readings` service (FastAPI, uvicorn, three replicas of one process each) calls three downstreams: the internal `tariffs` service (hot path), the external payment partner, and the external weather feed used to flag frozen meters. It also validates uploaded batches of readings, CPU-bound, in the request. Tenancy follows the product's own `multi-tenancy-design` decision: utilities share one deployment, rows scoped by utility id (no physical isolation is assumed). SLOs: SLO-READ-01, the share of reading submissions answered 2xx in under 500 ms, 99.9 %; SLO-READ-02, the share of bill requests answered 200 in under 1 s, 99.5 %. The product owner asks: "Before the winter peak, prove the tariff fallback in the designated performance environment, and keep the weekly production chaos the DR plan describes. Start with staging and widen from there."

## What the product implements

| Downstream | Breaker | Retry | Timeout | Bulkhead | Fallback |
|---|---|---|---|---|---|
| tariffs (internal, hot path) | yes, pybreaker 1.4.1 called through `asyncio.to_thread`, `fail_max=5`, `reset_timeout=5` | yes, tenacity, `stop_after_attempt(3)`, `wait_random_exponential(0.1, 5)` | 250 ms per attempt, caller's `asyncio.timeout` | yes, `asyncio.Semaphore(16)` with a bounded acquire | cached tariff, `X-Degraded: cached` |
| payments (external, tolerant) | **missing** | tenacity with a **bare `@retry`** | 3 s | **missing**: one `httpx.AsyncClient` shared with the weather feed | queue and answer 202 |
| weather (external) | **missing** | no | 5 s | **missing**: same shared client | last feed, marked stale |
| batch validation | | | | | **runs on the event loop** (no offload) |

## Output: the answer

**Where.** Every experiment runs nightly in the run's own throwaway kind cluster, at this size as at every other. The staged rollout to staging and wider slices is withdrawn (D048, 2026-11-28), and there is no standing production chaos: `disaster-recovery-plan`'s weekly production experiments are replaced by the scheduled run in the throwaway cluster; a production experiment needs a signed statement each time. The designated performance environment is "any other system": it gets the tariff-fallback check only under a chaos statement the product owner signs (`../templates/chaos-statement.md`): its address, the Toxiproxy API there (set up by `platform-engineer`), one fault (`latency` on the `tariffs` proxy, at most 2,000 ms), the blast radius (bill requests in that environment only), abort below 0.95 over 10 s or 120 s in all, the impact (no other team uses it in the window; the payment partner's sandbox is a stand-in), a one-hour window and an expiry. Chaos Mesh is never installed there, and no pytest experiment runs there.

**Library notes for the tests.** The tariffs breaker is pybreaker: it trips on the 5th failure, the tripping call raises `CircuitBreakerError`, and `current_state` reads `"open"` until a call after the reset moves it to half-open, so half-open is asserted through the probe call. Its `call` holds a thread lock, so concurrent probes are serialised in-process: assert one probe from five callers anyway. Called through `asyncio.to_thread`, the caller's cancellation does not stop the thread: the timeout experiment must show the tariffs stand-in seeing the request end by the deadline, and is expected to **FAIL** today (a finding: an async breaker, or a deadline passed to the synchronous call).

**Missing, named:** no breaker on payments or weather; no bulkhead between them (one slow partner can hold every connection of the shared client); a bare `@retry` on payments that never stops (`../scripts/validate-python-chaos-tests.sh` fails it: `a bare tenacity @retry`); batch validation on the event loop. All are findings for `backend-engineer`; the tests do not add them.

**Experiments.**

| Id | Fault | Hypothesis and assertion | Expected |
|---|---|---|---|
| tariffs-patterns | in-process, `pytest` | breaker, retry, timeout, bulkhead as `../templates/pattern-tests.md`, against tariffs' own settings | breaker, retry, bulkhead PASS; timeout FAIL (thread not cancelled) |
| payments-retry-bounded | in-process, `pytest` | one call against a failing stand-in returns within `bounded` | **FAIL** today: the bare `@retry` never stops |
| batch-stall | in-process, `pytest`, `../templates/event-loop-stall.md` | a 2 s batch validation leaves the same worker's health check under 100 ms | **FAIL** today: the whole worker looks hung; fix: a `ProcessPoolExecutor` |
| tariffs-latency | Toxiproxy 1 s on `tariffs` | bills still 200 under 1 s, `X-Degraded: cached` counted (`fault_header`) | PASS |
| partner-isolation | Toxiproxy 10 s on `weather` while submissions and bills run | submissions unaffected | **FAIL** today: the missing bulkhead, shown |
| readings-pod-kill | PodChaos, one of three `readings` pods | SLO-READ-01 holds | PASS |
| broker-loss | PodChaos on one of three broker pods | outbox drains, lag back to baseline, one effect per event after recovery (`python-integration-test`'s assertion, waited for) | shape only |
| tariffs-latency-perf | Toxiproxy 2 s on `tariffs`, under the signed statement | as tariffs-latency, in the performance environment | run once in the window |

**Tenancy.** Each steady state is measured for two utilities' traffic; a toxic on a per-utility route, where the product has one, must leave the other utility's SLI unchanged. Where the product has no per-utility route, that check is impossible and the report says so; physical isolation is never claimed without the tenancy design saying it.

**Report:** one per run, approved by the product owner; the statement printed verbatim for the performance-environment run, which is a verification of that environment in that window, not proof for production.
