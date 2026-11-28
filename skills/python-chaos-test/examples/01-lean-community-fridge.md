# Lean: Community Fridge, With Patterns Missing and a Blocking Call

Self-contained. Read for a small Python product whose code lacks most resilience patterns and calls a synchronous client from `async def`: what is tested, what is named missing, and why lean changes the number of experiments but not the rules. Worked on paper from the shapes proven in `./02-standard-bike-share-docks.md`; **not run** as written (unverified).

## Input

A neighbourhood's community fridge: one FastAPI service, one replica, one uvicorn process, PostgreSQL, and one outbound call to the council's food-safety register (an external system) to check that a donor is registered. SLO-FRIDGE-01: the share of `GET /v1/fridge/{id}/contents` requests answered 200 in under 1,000 ms, objective 99.5 %. The developer asks: "We're tiny. Can we just run one test that kills the database container with testcontainers, and maybe pull the plug in production once to see?"

## What the product implements

| Downstream | Pattern | Present? | integration-design (external system, any profile) |
|---|---|---|---|
| food-safety register | Timeout | partly: `requests.get(url, timeout=2)`, **called from `async def`** | required |
| food-safety register | Deadline propagated | **no**: the synchronous call cannot be cancelled by the caller | required ("pass the remaining deadline down") |
| food-safety register | Retry | **missing** | only if idempotent; a read is |
| food-safety register | Circuit breaker | **missing** | not required for an external call at lean |
| food-safety register | Fallback | **missing**: a register failure is a 500 | "a defined failure response" required |
| service | Redundancy | one replica, one worker | not stated |

## Output: the answer

Lean gets chaos testing like every size (D048.2); it gets fewer experiments, never fewer rules. **Where:** only the run's own throwaway kind cluster, created by `make chaos` and deleted after it; no testcontainers stack per test (the product owner decided on 2026-11-28 that Python experiments run in the throwaway cluster only), and nothing in production: a production pod kill would need the product owner's signed chaos statement for exactly that, and Chaos Mesh never runs outside the throwaway cluster, so it is refused whatever is signed. Application-level and Toxiproxy faults first.

**Missing, named** as findings for `backend-engineer` (no Python build skill implements a breaker or retry yet; the product owner has made that a later wave): no deadline propagation, no retry, no fallback, and a **blocking call inside `async def`**. The tests do not build any of them.

Experiments (nightly, never on a pull request, never in `make ci`: every file under `tests/chaos/`, which the coverage gate leaves out with `--skip-suite chaos`, and marked `chaos` by the folder's `conftest.py`, which refuses a run the runner did not start):

1. **event-loop-stall** (`pytest`, `../templates/event-loop-stall.md`): while the register stand-in holds a request for 2 s, the same worker's health check is timed. Expected today: **FAIL** ("the whole worker looks hung": the synchronous `requests.get` blocks the loop for the whole 2 s, so the health check and every other request wait). With one replica and one worker there is no other worker to keep answering: the report says so. The fix belongs to the service: an async client (`httpx.AsyncClient`) or `asyncio.to_thread`.
2. **timeout-propagates** (`pytest`, in-process): the stand-in holds requests; the caller's deadline is 500 ms. Expected today: **FAIL**: the call returns after 2 s and the stand-in never sees the request end.
3. **register-slow** (Toxiproxy, 3 s latency on the register proxy): steady state SLO-FRIDGE-01 ≥ 0.995 over 20 s before; abort below 0.9 over 10 s, 60 s in all. Expected today: **FAIL** by abort (no fallback), the toxic removed and verified.
4. **pod-kill** (PodChaos, one pod of one): expected **FAIL** while there is one replica; redundancy is a design decision for the product owner, not a test to change.

No breaker or retry experiment is written: there is nothing to prove until the pattern exists. When `backend-engineer` adds them, the experiments of `../templates/pattern-tests.md` apply.

The report (`artifacts/community-fridge/quality/test-reports/chaos-<date>.md`) lists four FAILs, the missing patterns with their corrective actions, and what it does not prove (one replica, one node, no load); the product owner approves it.
