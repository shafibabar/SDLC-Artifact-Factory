---
name: api-gateway-design
description: >
  Design an edge API gateway for a microservices system: the gateway role at
  the north-south boundary — routing/dispatch to upstreams, authentication
  offload (validate the JWT/API key once at the edge), rate limiting and quota
  enforcement, request/response transformation, and edge observability. Covers
  the crucial gateway-vs-service-mesh distinction (north-south vs east-west;
  complementary, not alternatives — the gateway is the ingress that terminates
  TLS and applies edge policy before traffic enters the Linkerd mesh), the Kong
  specifics (plugin model, declarative decK and Kong Ingress Controller CRDs,
  DB-less mode), gateway-vs-BFF, and when a gateway is warranted. Used by the
  platform-engineer during Deploy when a system needs a managed edge entry point.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-31
tags: [deploy, platform, api-gateway, kong, edge, routing, rate-limiting, mesh]
related: [kubernetes-manifest, gitops-workflow, zero-trust-design, environment-config]
---

# API Gateway Design

## Purpose

An API gateway is the single **north-south** entry point: the one front door through
which all client-to-cluster traffic passes before it reaches any service. It collapses
cross-cutting *edge* concerns into one policy-enforcement layer instead of smearing them
across every service. This skill teaches the platform-engineer what the gateway does,
where it sits relative to Ingress and the Linkerd mesh, and how to configure it
declaratively under this repo's GitOps model.

Kong is the concrete illustration because the platform names it, but the *role*
generalizes to any gateway (Envoy/Contour, Traefik, NGINX Ingress, Gateway-API
implementations). Nothing here commits the repo to Kong — the frugality rule applies if a
lighter gateway meets the same edge-policy and declarative-config needs.

## The Gateway's Responsibilities — Edge Policy, Configured Not Coded

The gateway owns exactly the client-agnostic cross-cutting concerns at the outer boundary:

- **Routing / dispatch** — match the request and forward it to the correct upstream service.
- **Authentication offload** — validate the JWT / API key **once**, at the edge, and reject
  anonymous traffic, so downstream services trust an already-authenticated request. The
  gateway proves *who*; it is **not** the authorization authority (see below).
- **Rate limiting and quota enforcement** — cap throughput per client/tenant so one caller
  cannot exhaust shared edge capacity.
- **Request/response transformation** — add/strip/rename headers, reshape bodies at the edge
  (generic reshaping only — client-specific aggregation belongs in a BFF).
- **Edge observability** — request logs, latency, and status-code metrics for all ingress
  traffic, emitted into the existing stack.

The load-bearing principle: edge policy is **declared, not reimplemented per service**. Full
plugin catalog, config, and worked examples are in `references/kong-configuration.md`.

## The Distinction That Governs Everything — Gateway vs. Service Mesh

This is the single most-confused distinction and the most important one for this repo.

| Plane | Traffic | Governs | Enforced by (here) |
|---|---|---|---|
| **North-South** | client → cluster (crossing the outer boundary) | routing, edge authn, rate limit, TLS termination, edge telemetry | the **gateway** |
| **East-West** | service → service (already inside the cluster) | mTLS identity, retries, per-call telemetry between pods | the **mesh** (Linkerd) |

They solve **different planes** — you do not pick one *or* the other, you run **both**. A
request hits the gateway first (TLS termination, authn, rate limit), then travels the mesh
(mTLS, retries) between services.

**The category error to prevent:** treating "we have Linkerd" as a reason to skip a gateway,
or "we have a gateway" as a reason to skip the mesh. Equally wrong: doing edge authn in the
mesh sidecar, or inter-service mTLS in the gateway. Edge policy belongs at the gateway;
service identity belongs in the mesh; neither substitutes for the other. The full two-plane
treatment, placement topology, and TLS-termination-then-handoff flow are in
`references/gateway-vs-mesh-and-placement.md`.

## Where the Gateway Sits — It *Is* the Ingress in Front of the Mesh

In a Kubernetes + Linkerd topology the gateway **is the ingress**: it terminates client TLS,
applies edge policy (authn, rate limit, transform), and only then hands traffic into the mesh
— where Linkerd re-encrypts with mTLS and manages east-west calls. The gateway is the
outermost trust-boundary crossing; the mesh is the internal identity fabric.

This resolves the `kubernetes-manifest` "ingress-gateway" NetworkPolicy peer: that opaque box
is the gateway/ingress-controller workload — Kong as a Kong Ingress Controller (KIC) — with
its own config, plugins, and TLS-termination responsibility. Placement diagram in
`references/gateway-vs-mesh-and-placement.md`.

## Authn at the Edge, Authz in the App

Use a gateway auth plugin (jwt / OIDC) to **validate** the token and reject anonymous traffic,
then forward verified claims downstream (e.g., as trusted headers). Do **not** move ABAC /
tenant authorization into the gateway — those stay in application code (this repo's
`zero-trust-design` stance: the edge proves *who*, the app decides *what they may do*).
Pushing authz into gateway plugins recreates the "smart gateway" anti-pattern and splits the
authorization model across two layers. The gateway thins the attack surface; it is not the
authorization authority.

## Gateway vs. BFF

- A **gateway** is *generic*, client-agnostic edge policy shared by all clients.
- A **BFF** (Backend-for-Frontend) is a *per-client-experience* service — one for web, one for
  mobile — that aggregates and reshapes multiple downstream calls into exactly what that one
  frontend needs.

Rule of thumb (Newman): put cross-cutting, client-agnostic concerns (authn, rate limit, TLS)
in the gateway; put client-specific aggregation and payload shaping in a **BFF behind** the
gateway. Overloading the gateway with client-specific response shaping recreates a monolithic,
hard-to-change edge — the "smart gateway" anti-pattern. Keep the gateway's plugin set small and
generic. Extended contrast in `references/gateway-vs-mesh-and-placement.md`.

## When a Gateway Is Warranted

- **Warranted** when: multiple services need one managed front door; edge authn/rate-limit/TLS
  would otherwise be duplicated across services; a single reviewed edge-policy surface in Git is
  wanted; per-tenant edge quotas are needed as defense in depth alongside per-namespace limits.
- **Not yet** when: a single service with no cross-cutting edge concerns — a plain Ingress may
  suffice until a second consumer or an edge policy appears. Do not stand up a gateway as
  ceremony; stand it up when a client-agnostic edge concern exists to house.

## Declarative, GitOps-Managed, DB-less

The gateway's entire routing-and-policy surface is a **reviewed file in version control**, never
clicks in an admin UI. In-cluster: express routes and plugins as Kong Ingress Controller CRDs
(`KongPlugin`, `KongConsumer`) reconciled from Git the same way Helm/OpenTofu state is.
Off-cluster: **decK** diffs/syncs a YAML of the whole config against a running Kong. Run
**DB-less** so a gateway pod carries no state a restore plan must cover — config *is* the
manifest, and the pod is disposable and reproducible. Full plugin families, decK/KIC config,
DB-less boot, and per-Consumer rate limiting are in `references/kong-configuration.md`.

## Edge Telemetry Into the Existing Stack

Turn on Kong's request logging/metrics and export to **Prometheus** (and traces to **Tempo** via
OpenTelemetry) so edge latency, 4xx/5xx rates, and per-Consumer throughput land in the same
**Grafana** the mesh and services already use — one pane, edge plus interior.

## References

- `references/gateway-vs-mesh-and-placement.md` — the north-south/east-west split in depth, the
  gateway-as-ingress-in-front-of-mesh topology, TLS termination + edge-auth handoff to app ABAC,
  and the BFF distinction with a worked aggregation example.
- `references/kong-configuration.md` — the Kong plugin model (auth / traffic-control /
  transformation families), declarative decK config + Kong Ingress Controller CRDs on Kubernetes,
  DB-less mode, and GitOps-managed gateway config with per-tenant Consumer rate limiting.

## Quality Criteria

- Exactly one north-south arrow on the Container Diagram (client → gateway/ingress); every
  in-cluster arrow is east-west (mesh). An edge concern on an east-west arrow, or an internal
  concern (mTLS, retries) on the north-south arrow, is a misplacement to fix before shipping.
- Gateway config lives in Git as KIC CRDs or a decK YAML — no live admin-API mutation.
- The gateway validates *who* only; ABAC/tenant authz stays in the application.
- The gateway does not replace the mesh, and the mesh does not replace the gateway.
