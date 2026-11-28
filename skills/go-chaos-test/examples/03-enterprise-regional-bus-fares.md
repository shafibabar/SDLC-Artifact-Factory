# Enterprise: Regional Bus Fares, Several Downstreams and One Signed Statement

Self-contained. Read for a product with several downstreams, operators as tenants, a pattern present for one downstream and missing for another, and a request to run a fault outside the throwaway cluster. Worked on paper from the shapes proven in `./02-standard-harbour-pilots.md`; **not run** as written (unverified).

## Input

Regional Bus Fares sells tickets for several bus operators. The `fares` service calls three downstreams: the internal `pricing` service (hot path), the external payments partner, and the external timetable feed. Tenancy follows the product's own `multi-tenancy-design` decision (operators share one deployment, rows scoped by operator id). SLOs: SLO-FARE-01, share of quote requests answered 200 in under 600 ms, 99.9 %; SLO-FARE-02, share of purchases answered 2xx in under 2 s, 99.5 %. The product owner asks: "Before the January timetable change, prove the payments fallback on the designated performance environment, not just in kind. And run chaos weekly in production like the DR plan says."

## What the product implements

| Downstream | Breaker | Retry | Timeout | Bulkhead | Fallback |
|---|---|---|---|---|---|
| pricing (internal, hot path) | yes, 5 / 10 s / 5 s | yes, 3, full jitter | 250 ms, propagated | yes, own pool of 16 | cached price, `X-Degraded: cached` |
| payments (external, tolerant) | **missing** | yes, 2, idempotency key | 3 s, propagated | **missing**: shares the default `http.Client` with timetable | queue and answer 202 |
| timetable (external) | yes, 50 % of 20 / 30 s / 30 s | no (feed is polled) | 5 s | **missing**: same shared client | last feed, marked stale |

## Output: the answer

**Where.** Every experiment runs nightly in the run's own throwaway kind cluster, at this size as at every other. No weekly production chaos: the product owner decided on 2026-11-28 that `disaster-recovery-plan`'s weekly production experiments are replaced by the scheduled run in the throwaway cluster, and a production experiment needs a signed statement each time. The designated performance environment is "any other system": it gets the payments-fallback check only under a chaos statement the product owner signs (`../templates/chaos-statement.md`): the address of the performance environment, the Toxiproxy API there (set up by `platform-engineer`), one fault (`latency` on the `payments` proxy, at most 5,000 ms), the blast radius (purchases in that environment only), abort below 0.95 over 10 s or 120 s in all, the impact (no other team uses it in the window; the payments partner's sandbox is a stand-in, so no real payment), a one-hour window and an expiry. Chaos Mesh is never installed there.

**Missing, named:** no breaker on payments; no bulkhead between payments and timetable (one slow partner can take every connection from the other). Both are findings for `backend-engineer`; the tests do not add them.

**Experiments.**

| Id | Fault | Hypothesis and assertion | Expected |
|---|---|---|---|
| pricing-patterns | in-process, `go-test` | breaker, retry, timeout, bulkhead, degradation exactly as `../templates/pattern-tests.md`, against pricing's own config | PASS |
| pricing-latency | Toxiproxy 1 s on `pricing` | quotes still 200 under 600 ms, `X-Degraded: cached` counted (`fault_header`) | PASS |
| payments-latency | Toxiproxy 5 s on `payments` | purchases answered 202 in under 2 s (queued) | PASS while the fallback holds; no breaker means every purchase waits for its own timeout first, which the report shows |
| partner-isolation | Toxiproxy 10 s on `timetable` while quotes and purchases run | purchases unaffected | **FAIL** today: the shared client's connections are held by the slow feed; this is the missing bulkhead, shown |
| fares-pod-kill | PodChaos, one of three `fares` pods | SLO-FARE-01 holds | PASS |
| broker-loss | PodChaos on one of three broker pods | outbox drains to zero, consumer lag back to baseline, one effect per event (the integration test's duplicate assertion, after recovery) | shape only |
| payments-latency-perf | Toxiproxy 5 s on `payments`, under the signed statement | as payments-latency, in the performance environment | run once in the window |

Tenancy: each experiment's steady state is measured for two operators' traffic; the report shows that a fault aimed at one operator's purchases (a toxic on a per-operator route, where the product has one) leaves the other's SLI unchanged. Where the product has no per-operator route, that check is impossible and the report says so.

**Report:** one per run, approved by the product owner; the statement printed verbatim for the performance-environment run, which is called a verification of that environment in that window, not proof for production.
