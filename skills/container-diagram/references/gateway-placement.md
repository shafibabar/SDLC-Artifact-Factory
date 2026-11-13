# Gateway Placement

Whether the system has an API gateway, where it sits, and what it may hold. Self-contained. The decision is enterprise-architect's at Design, drawn on the container diagram (D047-11); routes, plugins and limits are configured by platform-engineer at Deploy (`api-gateway-design`). Sources: `research/devops-and-delivery/api-gateway-patterns.md` (north-south vs east-west, gateway vs backend-for-frontend), `research/software-architecture/system-design-interview-xu.md` (what a gateway does), `research/software-architecture/building-microservices-newman.md` (smart endpoints, dumb pipes).

---

## 1. Gateway or None

| Situation | Decision |
|---|---|
| One application (lean modular monolith) | Usually no gateway: the ingress routes to the application, which validates tokens itself. Say so in the gateway section |
| Several deployables behind one public API, or public API keys and rate limits per customer | One gateway as the north-south entry |
| Two very different clients (web and mobile, or partner API) needing different payloads | The gateway, plus one backend-for-frontend container per client experience behind it |

## 2. Two Planes

- **North-south:** traffic from outside into the system. It enters once, at the gateway (or the ingress when there is none): TLS termination, token validation, rate limits.
- **East-west:** traffic between our containers inside the cluster. It goes through the service mesh (Linkerd: mutual TLS, retries, per-call telemetry), not back through the gateway.

Mark both on the diagram or in its key: the one north-south arrow into the gateway, and a note that container-to-container calls run over the mesh. They are complementary, never alternatives: edge policy at the gateway, service identity in the mesh.

## 3. What the Gateway Holds

| Holds | Never holds |
|---|---|
| Routing to the right container | Business rules: pricing, discounts, eligibility, licensing checks, workflow steps |
| TLS termination | Aggregation of several services' data for one screen (that is a backend-for-frontend) |
| Token validation (who the caller is) | Authorization decisions about what the caller may do to which record |
| Rate limits and quotas per customer or key | State a restore plan has to cover |
| Edge logs and metrics | |

A gateway with business logic becomes an unowned service every context depends on (Xu; Newman's smart endpoints, dumb pipes).

## 4. Identity (D047-12)

The gateway is the first check, not the only one. Every service validates the token or the mesh identity on each request and decides authorization itself (`zero-trust-design`, `access-control-model`). A header the gateway adds ("X-User-Id") is never trusted on its own: anything that reaches a service another way (a misrouted call, a compromised pod) would pass.

## 5. On the Diagram

- The gateway is a container: `[Container: Gateway]`, a named technology, responsibility "routes, validates tokens, limits rates". The default stack names no gateway, so the technology is the agreed product, or, when none is agreed, **Kong (proposed, ADR pending)**: the gateway `api-gateway-design` works through, with the ADR listed under Open Questions. Never a placeholder ("chosen in api-gateway-design", "TBD", "none"): every box names its technology, and a deferral note is not one (Brown).
- One arrow per route group to the containers behind it.
- The gateway section of the artifact records: gateway or none, what it holds, that services verify identity, where client-specific shaping lives, and that configuration is platform-engineer's at Deploy.
