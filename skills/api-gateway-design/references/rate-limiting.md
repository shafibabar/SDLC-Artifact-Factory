# Rate Limiting at the Edge

Reference for `api-gateway-design` step 6. Grounded in Xu (*System Design Interview*, the rate-limiter chapter: five algorithms with trade-offs, where to enforce, what to return, the distributed limiter's shared store and atomicity). Design level only: no implementation code.

"Add a rate limiter" is not a design decision. The algorithm, the key, the layer and the store are, and each is written down.

## Choose the algorithm

| Algorithm | How it works | Strength | Weakness | Fits |
|---|---|---|---|---|
| **Token bucket** | A bucket refills at a fixed rate up to a capacity; each request takes a token | Simple, little memory, allows a burst up to the bucket size | Two numbers (rate and capacity) to tune | Most APIs where short bursts are fine |
| **Leaky bucket** | Requests join a queue drained at a fixed rate | Smooths bursts to a constant rate | A full queue rejects new requests; recent traffic can starve behind old | An upstream that needs a steady inflow |
| **Fixed window counter** | Count requests per fixed window (a minute) | Simple, cheap | Up to twice the limit can pass at a window boundary | Coarse quotas where the boundary burst is acceptable |
| **Sliding window log** | Keep a timestamp per request; count those in the trailing window | Accurate | Memory-heavy at scale | Low-volume, accuracy-critical limits |
| **Sliding window counter** | A weighted blend of the current and previous window's counts | Close to the log's accuracy at the fixed window's memory cost | An approximation | Xu's recommended default for most cases |

Write the choice and the reason: burst tolerance against memory cost. Do not leave the algorithm to the product's default without saying so.

## Choose the key and the limit

The key is what is being limited: the caller, an API key, a partner, an IP address for anonymous traffic. Limit per caller or per key; limit per tenant only when the product is multi-tenant. State the limit as a number per window and the burst allowed, and size it from the NFR specification (the normal and the peak traffic) rather than a round figure.

## Limit at two layers

- **At the edge**, for cross-cutting protection: stop one caller from exhausting shared capacity before traffic reaches any service.
- **At the service**, for endpoint-specific limits the edge cannot know (an expensive export, a write-heavy route).

Document both. An edge limit alone leaves an expensive endpoint exposed to a caller who stays under the edge number; a service limit alone lets abusive traffic cross the cluster boundary.

## A distributed limiter needs a shared store

When the gateway or the service runs more than one instance, the counters must be shared, or each instance enforces its own limit and the real limit is the number of instances times the setting. Name the shared store (a fast in-memory store such as Redis) and the **atomic** operation: a check followed by an increment as two steps races, so use one atomic increment with an expiry, or a single script that does both. A limiter with that race is not a limiter.

With several regions or gateways, state whether a limit is **per region** (each region has its own store and its own allowance) or **global** (one shared allowance, at the cost of cross-region latency), and why.

State what happens when the store is unreachable: fail open (let traffic through, alert) or fail closed (reject), chosen by the cost of abuse against the cost of an outage.

## What the caller sees

A rejected request gets `429 Too Many Requests` and a hint for when to retry: a `Retry-After` header and, if used, headers that show the limit, the remaining allowance and the reset time. Clients are told how to behave, not left to guess. The limit is documented in the API contract so consumers can design for it (`api-contract-design`).

## Record it

Each limit is a row in the design document: route or caller, algorithm and reason, key, limit and burst, layer, shared store and atomic operation, and the failure behaviour.
