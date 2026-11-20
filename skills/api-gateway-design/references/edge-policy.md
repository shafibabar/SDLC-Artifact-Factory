# Edge Policy: What the Gateway Does, and What It Never Does

Reference for `api-gateway-design` steps 4, 5 and 7. Grounded in `api-gateway-patterns` (a synthesis of Kong's documentation, Newman and Xu, not one book) and Xu (authentication, rate limiting and routing at the gateway; domain logic kept out). Placement (gateway or none, where it sits, what the diagram records) is decided at Design in `container-diagram`, § Gateway Placement; this file is the configuration view. Design level only: no implementation code.

## The two planes

The gateway governs **north-south** traffic, a client crossing into the cluster. The service mesh governs **east-west** traffic, one service calling another inside it. They are complementary, never alternatives: a request meets the gateway first (TLS termination, token validation, rate limits), then travels the mesh between services (mutual TLS, retries, per-call telemetry). "We have a mesh, so no gateway" leaves the outer boundary unguarded: a mesh authenticates workloads, not users, and does not limit external callers. "We have a gateway, so no mesh" leaves service-to-service traffic with no workload identity. Edge authentication belongs at the gateway; workload identity belongs in the mesh.

## Routes

Each route maps a path or host to one upstream, and records the owner and the auth requirement taken from that service's API contract (`api-contract-design`).

| Route | Upstream | Owner | Auth |
|---|---|---|---|
| a path or host pattern | the service it forwards to | the team that owns the upstream | required, or none for a public or health endpoint |

Health and readiness endpoints are the only unauthenticated routes, and are not exposed to the public edge.

## Authentication at the edge, authorization in the service

The gateway validates the credential once (a token's signature, expiry and issuer, or an API key), rejects anonymous traffic with `401`, and forwards verified claims. That is authentication offload: it proves **who** the caller is.

It is not the authorization authority. What a caller may do to which record (attribute-based access, ownership, any tenant rule) is decided by each service from the verified token. Moving those decisions into gateway plugins splits the model across two layers that drift apart, and recreates a smart edge that is hard to change.

**Zero trust (D047-12).** The gateway is the first check, not the only one:
- every service verifies the token or the mesh identity on each request;
- a header the gateway adds (a user id, a customer id) is never trusted on its own, because a request can reach a service without passing the gateway; a service reads identity from the verified token;
- a service never skips its checks because "the gateway already did".

## What the gateway holds, and never holds

| Holds (client-agnostic edge policy) | Never holds |
|---|---|
| Routing to the right upstream | Business rules: pricing, discounts, eligibility, workflow steps |
| TLS termination | Aggregation of several services' data for one screen |
| Token validation | Authorization decisions about a record |
| Rate limits and quotas | State a restore plan must cover |
| Generic header and body hygiene | Client-specific response shaping |
| Edge logs and metrics | |

A gateway with business logic becomes an unowned service every context depends on (Xu; Newman's smart endpoints, dumb pipes). Keep its policy set small and generic.

## Generic transforms

Allowed: add a request id, strip internal headers from responses, normalise a header, reject an oversized body. Not allowed: reshaping a response for one front end, stitching several upstream responses, or applying a rule that depends on the data.

## The backend-for-frontend boundary

A **gateway** is generic edge policy shared by all clients. A **backend-for-frontend** (BFF) is a service per client experience (web, mobile) that aggregates and reshapes several downstream calls into exactly what that front end needs. It sits **behind** the gateway, inside the mesh, and is owned by the team for that experience.

When one screen needs a payload composed from several services, build or extend a BFF; do not encode the composition as a gateway transform. The gateway's part is small: authenticate, limit and route the request to the BFF.

## TLS

The gateway holds the public certificate and terminates the client's TLS. Behind it the mesh establishes new mutual TLS between workloads; the client's channel and the workload channel are separate. Certificate issue and renewal are managed as configuration like everything else.
