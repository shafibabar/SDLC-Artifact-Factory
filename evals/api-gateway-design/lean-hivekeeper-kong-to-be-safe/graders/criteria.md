---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says the lean container diagram has no gateway: the Kubernetes ingress routes traffic to the one application, and the application validates tokens itself; a gateway adds a component to run and secure without a second service to protect, and it names what would change that, such as several services, several client types, partner traffic needing edge quotas, or a need for one shared edge policy (D047-6; `api-gateway-patterns.md`, Core Concepts, "Where the gateway sits relative to Ingress + mesh").
2. It states that placement of a gateway is decided at Design on the container diagram (by the enterprise-architect) and that gateway configuration is a later Deploy task (platform-engineer), so the "install Kong" request is first a design decision, not an install step (D047-11; `api-gateway-patterns.md`, Actionable Techniques, "Draw the two planes explicitly on the Container Diagram").
3. It rejects the role-checking plugin: the gateway may prove who the caller is (authentication offload), but what an inspector, admin or viewer may do to which record is authorization and stays in the application (`api-gateway-patterns.md`, Actionable Techniques, "Offload authn at the edge, keep authz in the app"; Caveats, "Gateway edge-authz is deliberately out of scope").
4. It rejects "the app can skip token validation": with or without a gateway, the application verifies the token itself, and a gateway would only ever be the first check, never the only one (D047-12; zero trust).
5. It rejects live edits through an admin UI: any gateway or ingress configuration is declarative, kept in version control and changed by a reviewed diff, ideally on a stateless (for Kong, DB-less) gateway that is disposable (`api-gateway-patterns.md`, Actionable Techniques, "Keep gateway config declarative and in Git"; Core Concepts, "DB-less mode").
6. It treats Kong as one example product, not the plugin's default: it notes that no gateway is named in the tech-stack defaults, so a chosen product needs an agreed decision (an ADR) rather than "because the platform names it" (`api-gateway-patterns.md`, Caveats, "Kong is one implementation").
7. It does not assume per-tenant consumers, tenant isolation or per-tenant rate limits, since the request does not say Hivekeeper is multi-tenant (D047-7).
8. The reply contains no Go, Python or other implementation code. A short YAML or table sketch of routing or policy is the artifact and is allowed, and is not counted as code (D047-10).
Fail if any of the 8 is missing.
