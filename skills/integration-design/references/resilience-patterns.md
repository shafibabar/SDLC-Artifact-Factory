# Resilience Patterns for Synchronous Calls

Reference for `integration-design`. Self-contained: the patterns that make a remote synchronous call safe, how much of them each call needs, the numbers to choose, the order they nest in, and what to observe. Rules and numbers only; the code lives in backend-engineer's skills for the configured stack.

## 1. Sizing: How Much Resilience a Call Needs

Fairbanks' risk-driven model (`research/software-architecture/just-enough-software-architecture-fairbanks.md`): spend design effort where the cost of being wrong is high and uncertain, and record consciously what was left light.

| Call | Needs | Why |
|---|---|---|
| In-process: modules of one deployable (a lean monolith) | None of this | No network, no partial failure; a module call fails like any function call |
| External system, any profile | Timeout; retry only if idempotent or keyed; a defined failure response | A partner you don't run will be slow or down; without a timeout your caller hangs |
| Cross-service or external, standard and enterprise | Timeout, retry with backoff and jitter, circuit breaker and bulkhead per downstream, observable fallback | Independent deploys and more traffic make cascading failure likely |
| Hot path, long chain, or a high-fan-in dependency | All of the above plus a timeout budget along the chain | A failure here becomes everyone's failure |

Anything below its row's default is written in the inventory as **risk-accepted**, with the reason (low traffic, a manual fallback exists, the partner has a strong SLA). Silence is not a decision.

Bass's availability tactics (`software-architecture-in-practice-bass.md`) are the vocabulary: *detect* faults (timeouts, health checks), *recover* (retry, graceful degradation), *prevent* (removal from service: the open breaker).

## 2. Timeout: Every Remote Call Has a Deadline

A call without a timeout inherits the downstream's worst case: it hangs, its pool fills, and the hang walks up the chain.

**Budgets nest.** A caller's deadline must exceed its downstream's whole retry envelope (every attempt plus every backoff), or the caller gives up while the downstream is still working and retries on top of it.

```
Partner API, one attempt:                   400 ms
Pricing → Partner retry envelope:           400 + 100 + 400 + 200 + 400 = 1500 ms
Pricing's own budget:                       1600 ms   (exceeds the envelope)
Gateway → Pricing:                          1800 ms
User-facing request:                        2000 ms
```

Pass the **remaining** deadline down with each call, so no downstream works longer than its caller will wait.

## 3. Retry with Backoff and Jitter

- Retry **transient** failures (`503`, `504`, connection reset). Never permanent ones (`400`, `404`, `422`).
- **Capped attempts** (typically 3), exponential backoff (e.g. 100 ms, ×2, max 5 s).
- **Jitter is mandatory:** without it, every caller that failed together retries together and knocks over the recovering downstream. Full jitter: a random delay between 0 and the backoff.
- **Idempotency is a precondition.** A timeout is an *unknown outcome*: the request may have succeeded. Retry reads freely; retry a write only if it carries an **idempotency key** the provider deduplicates on. Otherwise don't auto-retry: record it as pending and reconcile (query the provider, or a scheduled check).

## 4. Circuit Breaker

Stops a caller hammering a downstream that is already down, and fails fast instead of waiting on timeouts.
- **Closed:** calls pass; failures are counted in a rolling window.
- **Open:** the threshold was crossed; calls fail immediately (to the fallback) for the reset timeout.
- **Half-open:** after the reset timeout, **one** probe is let through. Success closes the breaker; failure reopens it.

| Downstream kind | Trips at | Window | Reset |
|---|---|---|---|
| Internal, hot path | 5 consecutive failures | 10 s | 5 s |
| External, tolerant | 50% of at least 20 calls | 30 s | 30 s |
| External, rate-limited | 50% of at least 10 calls | 60 s | 60 s |

**One breaker per downstream**, never one for all: a global breaker opens for healthy partners when one fails. Export its state as a metric; an open breaker is an operational signal.

## 5. Bulkhead

Each downstream gets its own connection pool or concurrency limit, so a slow one exhausts only its own share. When full, fail fast; don't queue without bound. At the transport layer: a separate client (and connection limit) per downstream, not one shared client.

## 6. Fallback

When the breaker is open, the bulkhead full or the call fails, return a **defined, degraded** response, in rough order of preference:
- the last known good value, marked stale;
- a sensible default (an empty list, "pending");
- queue the work and return `202` (turn the failed sync call into async);
- an explicit partial result naming what failed.

A fallback that silently returns wrong data is worse than an error. Every fallback is **observable**: a flag on the response, a metric, a log.

## 7. Nesting Order

```
Bulkhead {             admission: is there capacity at all?
  Circuit breaker {    is this downstream worth calling now?
    Retry {            transient failure: try again with backoff and jitter
      Timeout {        this one attempt has a deadline
        remote call
      }
    }
  }
} otherwise Fallback   any layer refuses or fails: degraded response
```

Timeout innermost so each attempt is bounded; retry outside it so each attempt gets a fresh deadline; breaker outside retry so a call that fails every retry counts once; bulkhead outermost so the whole sequence uses one slot.

## 8. Rate Limiting at the Edge

Overload protection names its algorithm and why (Xu, `system-design-interview-xu.md`): token bucket (bursts allowed up to a capacity), leaky bucket (smooth output), fixed or sliding window counters, sliding window log. Enforce at the gateway for cross-cutting limits and in the service for endpoint-specific ones; a distributed limiter names its shared store and how check-and-increment is atomic. A rejected caller gets HTTP `429` with the `X-RateLimit-*` headers (and `Retry-After`), so it can back off instead of retrying blind. Gateway configuration: `api-gateway-design`.

## 9. What to Observe

Per downstream: breaker state, retry count, timeout count, fallback count, latency percentiles; per async consumer: lag and Dead Letter Queue depth (`opentelemetry-instrumentation`). Trace context crosses both sync calls and event headers, so one request is one trace.

## 10. Checklist per Synchronous Integration

- [ ] Timeout set; remaining deadline passed down; budgets exceed retry envelopes.
- [ ] Retries only on transient errors, capped, with jitter; writes only with an idempotency key.
- [ ] One breaker and one pool per downstream, thresholds chosen for that downstream.
- [ ] A defined, observable fallback.
- [ ] Anything lighter than the profile's default recorded as risk-accepted, with its reason.
