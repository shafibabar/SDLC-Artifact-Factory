# Example 3 — Enterprise: Per-Region Gateways, a Named Rate-Limit Algorithm and Reviewed Changes

Self-contained. **Tidewater** supplies grid-balancing data to energy retailers through a partner-facing API. **Enterprise** profile, about a dozen services, deployed in an EU and a US region because partner data stays in its region (a stated product constraint). The container diagram places one gateway per region as the north-south entry.

## Input

> **User:** "Just add a rate limiter. Put the check of which retailer may read which meter in a gateway plugin, and have services trust the `X-Retailer-Id` header the gateway sets. During incidents we'll edit routes in the admin API."

## Working it

- **"Just add a rate limiter"** is not a decision. Per retailer API key, a **token bucket**: it allows the short bursts retailers' batch jobs produce and caps the sustained rate, with two numbers to tune. Enforced at the edge for cross-cutting protection and again at the service for the expensive meter-history endpoint. Counters live in a shared store with one atomic increment, because a check followed by an increment races. The limit is **per region**: each region has its own store and allowance (a global limit would add cross-region latency to every call). A rejection is `429` with a `Retry-After` hint; if a store is unreachable the edge fails open with an alert, the history endpoint fails closed.
- **Which retailer may read which meter** is authorization. It stays in the services, decided from the verified token; a gateway plugin would split the model across two layers that drift.
- **Trusting `X-Retailer-Id`:** declined. A header is only as trustworthy as its path; every service verifies the token (or the mesh identity) and reads identity from it. The gateway is the first check, not the only one; mutual TLS proves the calling service, not the end retailer.
- **Live edits in the admin API during incidents:** declined. Configuration is declarative files in version control, with a diff against each running gateway reviewed in CI. In an incident the same path runs faster: an expedited review, or a rollback to the previous reviewed files. A live edit leaves the running gateway different from the repository.
- **Placement vs configuration:** one gateway per region was decided at Design by the enterprise-architect; the platform-engineer configures it at Deploy.
- **No tenant keys:** limits are per retailer API key; Tidewater's tenancy, if any, comes from `multi-tenancy-design`.

## Output: `artifacts/tidewater/deploy/api-gateway-design.md` (frontmatter omitted in a reply)

````markdown
---
name: api-gateway-design
product: tidewater
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-11-20
summary: A gateway in each of two regions validates tokens, limits per retailer key by token bucket with a regional shared store, and is changed only through reviewed files.
traces-to: [design/architecture/container-diagram.md, design/architecture/integration-design.md, ideate/nfr-specification.md]
---

# API Gateway Design for Tidewater

**Readers:** platform-engineer, enterprise-architect, security-engineer, the product owner
**Question it answers:** what does the gateway route, check and limit, what stays out of it, and how is its configuration changed safely?

- **Profile:** enterprise
- **Gateway:** yes: one per region (EU and US); the product is Kong, a proposal pending an ADR

## Gateway Decision

The container diagram places one gateway per region as the north-south entry, because retailer data stays in its region. Each gateway is paired with the service mesh in its region: the gateway guards entry, the mesh carries service-to-service identity.

## Routes

| Route | Upstream | Owner | Auth |
|---|---|---|---|
| /v1/meters | meter service | metering team | required |
| /v1/meters/history | meter-history service | metering team | required |
| /v1/forecasts | forecast service | forecasting team | required |

## Authentication

- **Validates:** token signature, expiry and issuer for the retailer's credential; anonymous requests get 401
- **Authorization stays in the services:** every service verifies identity itself and decides which retailer may read which meter; a header the gateway adds, such as a retailer id, is never trusted alone, and mutual TLS proves the calling service, not the retailer

## Rate Limits

| Route or caller | Algorithm and why | Key | Limit and burst | Layer | Shared store and atomic operation | On store failure |
|---|---|---|---|---|---|---|
| all routes | token bucket: allows the bursts of retailer batch jobs and caps the sustained rate | retailer API key | 1200 per minute, burst 200, per region | edge | a regional Redis, one atomic increment with expiry | fail open with an alert |
| /v1/meters/history | sliding window counter: a rolling limit for an expensive endpoint without a per-request log | retailer API key | 30 per minute, per region | service | a regional Redis, one atomic increment with expiry | fail closed |

Limits are per region (each region has its own store and allowance) because a global allowance would add cross-region latency to every call. Rejected requests return 429 with a Retry-After hint.

## Transforms

- Add a request id and strip internal headers. No business rules and no aggregation at the edge.

## Telemetry

- Request logs, latency, 4xx and 5xx rates and throughput per retailer key go to the existing observability stack in each region, with the trace id propagated; alerts on the 5xx rate, the 429 rate and edge latency.

## Configuration and Rollout

- **Source of truth:** declarative files in version control, one set per region; a diff against each running gateway is produced in CI and reviewed before a change ships
- **State:** stateless gateways, loaded from the files at start
- **Replicas and rollback:** three instances per region; a change rolls out to one region first; rollback to the previous reviewed files; an incident uses an expedited review or a rollback, never a live edit in the admin interface or API

## Open Questions

- Whether a retailer served from both regions needs one combined allowance; owner: product owner, with the platform-engineer.
````

> **Reply summary:** a token bucket per retailer key at the edge plus a sliding window counter on the expensive endpoint, with a regional shared store and atomic increment and a 429 with a retry hint; retailer-to-meter authorization stays in the services and no gateway-added header is trusted alone; configuration is reviewed files in version control on stateless gateways, changed in an incident by an expedited review or a rollback, never live; placement was decided at Design and configuration is the platform-engineer's at Deploy; no implementation code.
