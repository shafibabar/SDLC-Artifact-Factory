---
name: api-gateway-design
product: [product slug]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: whether the product has a gateway, what it routes, validates and limits, and how its configuration is changed]
traces-to: [design/architecture/container-diagram.md, design/architecture/integration-design.md]
---

# API Gateway Design for [Product]

<!-- Path: artifacts/<product>/deploy/api-gateway-design.md. Placement (gateway or none, where it sits) was decided at Design in
     container-diagram § Gateway Placement; this document configures what it placed.
     Lean: usually a short note that there is no gateway (the ingress routes to the application, which validates tokens). Omit the rest.
     Standard and enterprise: every section. Names no code.
     The gateway holds client-agnostic edge policy only: no business rules, no aggregation, no authorization.
     "CDC" means Change Data Capture only; write "Consumer-Driven Contract" in full. -->

**Readers:** [platform-engineer, enterprise-architect, security-engineer, the product owner]
**Question it answers:** what does the gateway route, check and limit, what stays out of it, and how is its configuration changed safely?

- **Profile:** [lean | standard | enterprise]
- **Gateway:** [yes: the product, or "proposal pending an ADR" | no: ingress only]

## Gateway Decision

[From the container diagram: gateway or none and why. If none: the ingress routes to the application, which validates tokens itself; the condition that would change this.]

## Routes

| Route | Upstream | Owner | Auth |
|---|---|---|---|
| [path or host] | [service] | [team] | [required, or none: public or health] |

## Authentication

- **Validates:** [what the gateway checks: token signature, expiry, issuer; or an API key]
- **Authorization stays in the services:** [every service verifies identity itself and decides what the caller may do; a gateway-added header is never trusted alone]

## Rate Limits

| Route or caller | Algorithm and why | Key | Limit and burst | Layer | Shared store and atomic operation | On store failure |
|---|---|---|---|---|---|---|
| [what is limited] | [token bucket, leaky bucket, fixed window counter, sliding window log or sliding window counter; burst tolerance against memory cost] | [caller, API key, partner, address] | [number per window, and burst] | [edge, service, or both] | [the store and the single atomic operation] | [fail open with an alert, or fail closed] |

Rejected requests return `429` with a retry hint.

## Transforms

- [Generic only: add a request id, strip internal headers, reject an oversized body. Client-specific aggregation is a backend-for-frontend behind the gateway.]

## Telemetry

- [Request logs, latency, 4xx and 5xx rates, throughput per caller, sent to the existing observability stack; alerts on the 5xx rate, the 429 rate and edge latency.]

## Configuration and Rollout

- **Source of truth:** [declarative files in version control; a diff against the running gateway reviewed before a change ships]
- **State:** [stateless gateway; the file-based mode where the product has one]
- **Replicas and rollback:** [the instance count (per region at enterprise); a gradual rollout and a rollback to the previous reviewed files; an incident uses an expedited review or a rollback, never a live edit]

## Open Questions

- [A question for the product owner or a named role, with an owner; or "none"]
