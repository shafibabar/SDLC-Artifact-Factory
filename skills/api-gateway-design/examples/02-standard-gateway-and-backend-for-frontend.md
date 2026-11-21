# Example 2 — Standard: Business Logic and Aggregation Kept Out of the Gateway

Self-contained. **Rentwise** rents out tools and party equipment. **Standard** profile, three services behind one public API: **Catalog**, **Bookings** and **Billing**, plus a mobile app and a web front end. The container diagram places one gateway as the north-south entry.

## Input

> **User:** "Have the gateway work out the late fee when a rental is returned, and build the mobile home-screen payload by calling Bookings, Catalog and Billing and merging them. The gateway checks tokens, so the services can skip that."

## Working it

- **Late fee in the gateway:** declined. A late fee is a business rule; in the gateway it becomes an unowned service every context depends on. The rule lives in Billing, and the gateway only routes to it.
- **The home-screen payload:** declined as a gateway job. Composing three services' data for one screen is client-specific aggregation; it would make the edge change with every screen. A **backend-for-frontend** for the mobile app, behind the gateway and inside the mesh, composes it. The gateway authenticates, limits and routes the request to that BFF.
- **"Services can skip the token check":** declined. Every service verifies identity itself and decides authorization; a header the gateway adds is never trusted alone, because a request can reach a service without passing the gateway.
- **Gateway and mesh:** both. The gateway guards traffic entering the cluster; the mesh handles service-to-service identity and retries.
- **Rate limits:** per API key, a **sliding window counter** (close to a sliding log's accuracy at a fixed window's memory cost, Xu's default) at the edge, with a tighter limit on the expensive reports endpoint inside Bookings. The counters live in a shared store with one atomic increment, so the limit holds across gateway instances; rejections return `429` with a retry hint.
- **Product:** the default stack names no gateway, so Kong is a proposal pending an ADR; the role does not change with the product.
- **Configuration:** declarative files in version control, a diff against the running gateway reviewed before a change ships, a stateless gateway, three instances, rollback to the previous reviewed files. No live edits.

## Output: `artifacts/rentwise/deploy/api-gateway-design.md` (frontmatter omitted in a reply)

````markdown
---
name: api-gateway-design
product: rentwise
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-11-20
summary: One gateway validates tokens, limits per API key and routes to Catalog, Bookings, Billing and a mobile backend-for-frontend; no business rules sit at the edge.
traces-to: [design/architecture/container-diagram.md, design/architecture/integration-design.md]
---

# API Gateway Design for Rentwise

**Readers:** platform-engineer, enterprise-architect, security-engineer, the product owner
**Question it answers:** what does the gateway route, check and limit, what stays out of it, and how is its configuration changed safely?

- **Profile:** standard
- **Gateway:** yes: Kong (proposal pending an ADR)

## Gateway Decision

The container diagram places one gateway as the north-south entry for three services and a mobile client. The gateway and the service mesh are both present: the gateway guards entry, the mesh carries service-to-service identity.

## Routes

| Route | Upstream | Owner | Auth |
|---|---|---|---|
| /v1/catalog | catalog service | catalog team | none: public read |
| /v1/bookings | bookings service | bookings team | required |
| /v1/billing | billing service | billing team | required |
| /mobile/home | mobile backend-for-frontend | mobile team | required |

## Authentication

- **Validates:** token signature, expiry and issuer; anonymous requests to protected routes get 401
- **Authorization stays in the services:** every service verifies identity itself and decides what the caller may do; a header the gateway adds, such as a user id, is never trusted alone

## Rate Limits

| Route or caller | Algorithm and why | Key | Limit and burst | Layer | Shared store and atomic operation | On store failure |
|---|---|---|---|---|---|---|
| all protected routes | sliding window counter: near a log's accuracy at a fixed window's memory cost | API key | 600 per minute, burst 60 | edge | Redis, one atomic increment with expiry | fail open with an alert |
| /v1/bookings reports | token bucket: allows a short burst, caps the sustained rate of an expensive endpoint | API key | 10 per minute, burst 3 | service | Redis, one atomic increment with expiry | fail closed |

Rejected requests return 429 with a Retry-After hint; the limits are documented in the API contract.

## Transforms

- Add a request id and strip internal response headers. No business rules (the late fee is Billing's) and no aggregation (the home screen is the mobile backend-for-frontend's).

## Telemetry

- Request logs, latency, 4xx and 5xx rates and throughput per API key go to the existing observability stack, with the trace id propagated; alerts on the 5xx rate, the 429 rate and edge latency.

## Configuration and Rollout

- **Source of truth:** declarative files in version control; a diff against the running gateway is produced in CI and reviewed before a change ships
- **State:** stateless gateway, loaded from the files at start
- **Replicas and rollback:** three instances; a change rolls out to one instance first; rollback to the previous reviewed files; an incident uses an expedited review or a rollback, never a live edit

## Open Questions

- Whether partner resellers need their own higher limits; owner: product owner.
````

> **Reply summary:** the late fee stays in Billing and the home-screen composition in a mobile backend-for-frontend behind the gateway; every service still verifies identity and no gateway-added header is trusted alone; rate limits name their algorithm, layers and shared store, with a 429 and a retry hint; configuration is reviewed files in version control on a stateless gateway; Kong is a proposal pending an ADR, not a default; the gateway and the mesh are complementary; the reply contains no implementation code.
