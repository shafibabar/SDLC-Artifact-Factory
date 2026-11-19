---
name: api-contract-summary
product: [product name]
service: [service name]
version: 1.0.0
phase: design
created: [date]
summary: [one sentence, ≤ 200 chars — what this artifact establishes; indexed as its memory-engine abstract]
owner: enterprise-architect
audience: [internal | partner | public]
openapi-spec: artifacts/[product]/design/[service-name]/openapi.yaml
---

# API Contract Summary: [Service Name]

<!-- Path: artifacts/<product>/design/<service>/api-contract-summary.md, beside the openapi.yaml it describes
     (copied into the service repository at Implement). Lean: skipped (the spec alone). Standard and enterprise: required.
     A summary the product owner can read without tooling; it must stay traceable to the spec through openapi-spec.
     audience: partner or public APIs get the full deprecation discipline (versioning-and-lifecycle). -->

## Endpoints

| Method | Path | Command / Read Model | Auth | Idempotency |
|---|---|---|---|---|
| [GET/POST/PUT/PATCH/DELETE] | [/v1/resource-path] | [Command or Read Model name it maps to] | [BearerAuth / none] | [Yes — Idempotency-Key supported / No — safe method] |

## Breaking Change Log
[No breaking changes recorded yet. When a breaking change lands, add a dated row: date, change, version bumped to, sunset date for the prior version.]

## Consumer Registry
[No consumers registered yet. List every known consumer (frontend app, another service, a partner integration) of this API here — this is what Consumer-Driven Contract tests are written against. A consumer with no contract test is a change this log cannot protect.]
