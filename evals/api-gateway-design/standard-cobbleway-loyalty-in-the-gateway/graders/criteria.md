---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects the loyalty discount in the gateway: pricing and discount rules are business rules that belong in a service (rewards or orders) owned by a bounded context; a gateway with business logic becomes an unowned service every context depends on (`system-design-interview-xu.md`, Core Concepts, "API Gateway as the single entry point": keep domain logic out; `api-gateway-patterns.md`, Core Concepts, "Gateway vs. BFF").
2. It rejects composing the dashboard payload in the gateway and puts it in a backend-for-frontend (BFF) service behind the gateway, because client-specific aggregation does not belong in client-agnostic edge policy; it may suggest one BFF per client experience, such as web and mobile (`api-gateway-patterns.md`, Actionable Techniques, "Reserve the gateway for client-agnostic policy; push client-shaping to a BFF").
3. It lists what the gateway does hold, as client-agnostic edge policy: routing, TLS termination, token validation with rejection of anonymous traffic, rate limits and quotas, generic header hygiene, and edge logs and metrics (`api-gateway-patterns.md`, Core Concepts, "The gateway is the single north-south entry point").
4. It rejects "the services can skip token checks": every service verifies identity and decides authorization itself, the gateway is the first check and never the only one, and a header or claim the gateway forwards is not trusted on its own (D047-12; `api-gateway-patterns.md`, Actionable Techniques, "Offload authn at the edge, keep authz in the app").
5. It states that the gateway (north-south, client to cluster) and the service mesh (east-west, service to service) are complementary and neither replaces the other, so the design keeps the mesh for in-cluster identity and retries (`api-gateway-patterns.md`, Core Concepts, "Gateway (north-south) vs. service mesh (east-west)").
6. It puts the edge in version control: gateway configuration is declarative and changes as a reviewed diff, run stateless (for Kong, DB-less) so a pod is disposable, and edge logs, latency, 4xx/5xx rates and per-consumer throughput feed the existing observability stack (`api-gateway-patterns.md`, Actionable Techniques, "Keep gateway config declarative and in Git" and "Emit edge telemetry into the existing observability stack").
7. It says that Kong is an example, not the default, because the platform's tech-stack defaults name no gateway; the user's "the platform names it" is corrected, and the gateway product is confirmed by an ADR if not already agreed (`api-gateway-patterns.md`, Caveats, "Kong is one implementation"; D047-11 and W2-28).
8. It does not assume per-tenant consumers or tenant isolation, since the request does not say Cobbleway is multi-tenant (D047-7).
9. The reply contains no Go, Python or other implementation code. A short YAML or table sketch of routing or policy is allowed and is not counted as code (D047-10).
Fail if any of the 9 is missing.
