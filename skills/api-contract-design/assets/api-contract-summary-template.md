---
name: api-contract-summary
product: [product name]
service: [service name]
version: 1.0.0
phase: design
created: [date]
owner: enterprise-architect
openapi-spec: artifacts/[product]/design/[service-name]/openapi.yaml
---

# API Contract Summary: [Service Name]

## Endpoints

| Method | Path | Command / Read Model | Auth | Idempotency |
|---|---|---|---|---|
| [GET/POST/PUT/PATCH/DELETE] | [/v1/resource-path] | [Command or Read Model name it maps to] | [BearerAuth / none] | [Yes — Idempotency-Key supported / No — safe method] |

## Breaking Change Log
[No breaking changes recorded yet. When a change from SKILL.md's Versioning Strategy table lands, add a dated row: date, change, version bumped to, sunset date for the prior version.]

## Consumer Registry
[No consumers registered yet. List every known consumer (frontend app, another service, a partner integration) of this API here — this is what Consumer-Driven Contract tests are written against, per SKILL.md's Purpose section. A consumer with no contract test is a change this log cannot protect.]
