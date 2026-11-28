# Lean: Allotment Waitlist, With Patterns Missing

Self-contained. Read for a small product whose code lacks most resilience patterns: what is tested, what is named missing, and why lean changes the number of experiments but not the rules. Worked on paper from the shapes proven in `./02-standard-harbour-pilots.md`; **not run** as written (unverified).

## Input

A council's allotment waitlist: one Go service, one replica, PostgreSQL, and one outbound call to the council's plot registry (an external system) to check that a plot exists. SLO-WAIT-01: the share of `GET /v1/waitlist/{id}` requests answered 200 in under 1,000 ms, objective 99.5 %. "Can we skip chaos, we're tiny? Or just kill the pod in production once to see."

## What the product implements

| Downstream | Pattern | Present? | integration-design (external system, any profile) |
|---|---|---|---|
| plot registry | Timeout | yes: `http.Client{Timeout: 2 * time.Second}` | required |
| plot registry | Deadline propagated | **no**: the request is built with `context.Background()` | required ("pass the remaining deadline down") |
| plot registry | Retry | **missing** | only if idempotent; a read is |
| plot registry | Circuit breaker | **missing** | not required for an external call at lean |
| plot registry | Fallback | **missing**: a registry failure is a 500 | "a defined failure response" required |
| service | Redundancy | one replica | not stated |

## Output: the answer

Lean gets chaos testing like every size (D048.2); it gets fewer experiments, never fewer rules. Nothing runs in production: experiments run only in the run's own throwaway kind cluster; killing a pod in production would need the product owner's signed chaos statement for exactly that, and Chaos Mesh never runs outside the throwaway cluster, so a production pod kill is refused whatever is signed.

Missing, named as findings for `backend-engineer` (no Go build skill implements a breaker or retry yet; the product owner has made that a later wave): no deadline propagation, no fallback, no retry. The tests do not build them.

Experiments (`make chaos`, nightly, never on a pull request):

1. **timeout-propagates** (`go-test`, in-process): the registry stand-in holds requests; the caller's deadline is 500 ms. Asserts the call returns by 500 ms and the stand-in sees the request end. Expected today: **FAIL** (`returned after 2.0s, past the caller's 500ms deadline`): the missing propagation, shown, not hidden.
2. **registry-slow** (Toxiproxy, 3 s latency on the registry proxy): steady state SLO-WAIT-01 ≥ 0.995 over 20 s before; abort below 0.9 over 10 s, 60 s in all. Expected today: **FAIL** by abort (no fallback, every answer waits 2 s), the toxic removed and verified.
3. **pod-kill** (PodChaos, one pod of one): expected **FAIL** while there is one replica; the report says so and names redundancy as a design decision for the product owner, not a test to change.

No breaker or retry experiment is written: there is nothing to prove until the pattern exists. When `backend-engineer` adds them, the experiments of `../templates/pattern-tests.md` apply unchanged.

The report (`artifacts/allotment-waitlist/quality/test-reports/chaos-<date>.md`) lists three FAILs, the three missing patterns with their corrective actions, and what it does not prove (one replica, one node, no load); the product owner approves it.
