---
name: api-gateway-design
description: >
  Configure the edge API gateway that the container diagram placed, at Deploy:
  start from the diagram's gateway section (gateway or none; a single
  application needs no gateway, only an ingress); routes to upstreams; token
  validation at the edge that proves who the caller is while every service still
  verifies identity and decides authorization itself; rate limits chosen by
  named algorithm (token bucket, leaky bucket, fixed or sliding window) at the
  edge and again at the service, with an atomic shared store and a 429 with a
  retry hint; generic header and body hygiene only, never business rules or
  aggregation (that is a backend-for-frontend behind the gateway); edge
  telemetry into the existing stack; configuration as reviewed declarative
  files in version control on a stateless gateway, never edited live. The
  gateway complements the service mesh; neither replaces the other. Kong is one
  worked example. Use when configuring, reviewing or changing the gateway.
  Used by platform-engineer.
version: 2.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-31
tags: [deploy, platform, api-gateway, edge, routing, rate-limiting, authentication, declarative-config]
produces: api-gateway-design
domain: architecture
status: stable
related: [container-diagram, zero-trust-design, access-control-model, kubernetes-manifest, gitops-workflow, api-contract-design, multi-tenancy-design, environment-config, glossary-management, methodology-review]
sources:
  - research/devops-and-delivery/api-gateway-patterns.md
  - research/software-architecture/system-design-interview-xu.md
---

# API Gateway Design

## Purpose

A gateway collapses edge concerns (routing, token validation, rate limits, edge telemetry) into one reviewed policy layer instead of repeating them in every service. Done badly it becomes an unowned service full of business rules, or a false comfort that lets services skip their own checks. **Readers:** platform-engineer, enterprise-architect, security-engineer, the product owner (what the edge protects and what it does not). **Question:** what does the gateway route, check and limit, what stays out of it, and how is its configuration changed safely?

The research behind this skill is a synthesis of Kong's documentation, Newman and Xu, not one book; the role is vendor-neutral and Kong is one example (`./references/kong-example.md`). Whether there is a gateway at all, where it sits and what it may hold is decided at Design on the container diagram (`container-diagram`, § Gateway Placement); this skill configures what that diagram placed. The output is `artifacts/<product>/deploy/api-gateway-design.md` (`./templates/api-gateway-design.md`); the default stack names no gateway, so the product is the one agreed, or a proposal pending an ADR.

| Profile | What this holds |
|---|---|
| Lean | Usually nothing: one application, so the ingress routes to it and it validates tokens itself. A short note says so |
| Standard | Routes, token validation, rate limits, generic transforms, telemetry, and how configuration is changed |
| Enterprise | As standard, plus the gateway per region, an owner, the shared limit store, and the rollout and rollback of a config change |

## Procedure

1. **Read** the container diagram's gateway section (gateway or none, what it holds, where client-specific shaping lives), the API contracts (routes and their auth), the NFR specification (traffic, abuse risk), the tenancy model, and `sdlc-config.json`.
2. **Confirm there is a gateway.** The diagram says none (a single application): configure the ingress only, with TLS, routing and logs, and stop; the application validates tokens itself. Say what would change that (several deployables behind one public API, per-key limits).
3. **Choose the product** from what is agreed; with none agreed, name one as a proposal pending an ADR. The role does not change with the product.
4. **Define the routes** (`./references/edge-policy.md`): path or host to upstream, the owner, and the auth requirement of each, taken from the API contracts.
5. **Set authentication at the edge:** validate the token, reject anonymous traffic, and forward verified claims. It proves *who* only: authorization, ABAC and any tenant rule stay in each service, and every service verifies identity itself; a header the gateway adds is never trusted on its own.
6. **Design the rate limits** (`./references/rate-limiting.md`): name the algorithm and why, the key (caller, API key, partner), the limit, the layer (edge and again at the service for endpoint-specific limits), the shared store and its atomic operation, and the `429` with a retry hint.
7. **Keep transforms generic:** add a request id, strip internal headers, normalise. No business rule, and no aggregation of several services for one screen (a backend-for-frontend behind the gateway does that).
8. **Wire edge telemetry** into the existing observability stack: request logs, latency, 4xx and 5xx, throughput per caller.
9. **Manage configuration as files** (`./references/configuration-and-operations.md`): declarative, in version control, a diff against the running gateway reviewed before a change ships, a stateless gateway, never a live edit in an admin UI or API.
10. **Validate and loop:** run `./scripts/validate-api-gateway-design.sh <file>`, fix every FAIL, re-run until clean; then `./resources/checklist.md`.
11. **Present** with the reason for every request declined (§ Gotchas). Always state: whether there is a gateway at all, and where it sits (per region too), is a Design decision made by the enterprise-architect on the container diagram, and configuring it is the platform-engineer's task at Deploy, so "install Kong" is first a design decision; the default tech stack names no gateway, so the product is an agreed choice or a proposal pending an ADR, never "because the platform names it"; the gateway holds client-agnostic edge policy only (no business rules, no aggregation, no authorization); every service still verifies identity, and a gateway-added header is never trusted alone; each rate limit names its algorithm, layers and shared store; configuration lives in version control as a reviewed diff, and the gateway or ingress is stateless and disposable (database-less in Kong); the gateway and the mesh are complementary, not alternatives; Kong is an example, not a default; and no implementation code appears in the answer. Answering in a reply: the declined requests and their reasons once, then the design once, without its YAML frontmatter block.

Examples: `./examples/01-lean-no-gateway.md` (a single application asking for Kong), `./examples/02-standard-gateway-and-backend-for-frontend.md` (business logic and aggregation kept out of the gateway), `./examples/03-enterprise-regional-gateways.md` (per-region gateways, a named rate-limit algorithm and reviewed config changes).

## Gotchas

- **"Put the loyalty discount calculation in the gateway."** *Reason:* a gateway with business rules becomes an unowned service every context depends on. *Instead:* the rule lives in the owning service; the gateway only routes to it.
- **"Compose the dashboard payload from three services in the gateway."** *Reason:* client-specific aggregation makes the edge a monolith that changes with every screen. *Instead:* a backend-for-frontend behind the gateway.
- **"The gateway validated the token, so services can skip the check."** *Reason:* a request can reach a service without passing the gateway, and no actor is trusted by position. *Instead:* every service verifies identity and decides authorization; the gateway is the first check.
- **"Trust the user-id header the gateway adds."** *Reason:* a header is only as trustworthy as the path it travelled. *Instead:* services read identity from the verified token, never from a header alone.
- **"Check which partner may see which record in a gateway plugin."** *Reason:* that splits the authorization model across two layers that drift. *Instead:* authorization stays in the services; the gateway proves who.
- **"Just add a rate limiter."** *Reason:* "a limiter" is not a decision; algorithms differ in burst tolerance and memory cost, and a check-then-increment can race. *Instead:* name the algorithm, the layers, the key, and the shared store with an atomic operation.
- **"Edit the route in the admin UI during the incident."** *Reason:* a live edit is unreviewed, unrecorded and lost at the next deploy. *Instead:* a change to the files in version control, with the diff reviewed, applied the normal way; in an incident, an expedited review or a rollback to the previous reviewed files.
- **"Install Kong to be safe" for one application.** *Reason:* a gateway in front of one application is another system to run with nothing to house. *Instead:* the ingress routes to the application, which validates tokens; add a gateway when several deployables share a public API or per-key limits appear.
- **"We have a mesh, so no gateway" (or the reverse).** *Reason:* they cover different planes: the gateway guards traffic entering the cluster, the mesh guards service-to-service traffic. *Instead:* both where both exist.
- **"One rate limit per tenant."** *Reason:* tenancy is not a plugin default. *Instead:* limit per caller or key; limit per tenant only for a multi-tenant product (`multi-tenancy-design`).

## References

| Question | File |
|---|---|
| Routes, authentication versus authorization, identity, generic transforms, the backend-for-frontend boundary | `./references/edge-policy.md` |
| Rate-limit algorithms, layers, the shared store, the `429` response | `./references/rate-limiting.md` |
| Declarative config in version control, the reviewed diff, a stateless gateway, telemetry, rollout | `./references/configuration-and-operations.md` |
| One worked example (Kong) | `./references/kong-example.md` |
| The artifact | `./templates/api-gateway-design.md` |
| Checking before hand-off | `./resources/checklist.md` |
