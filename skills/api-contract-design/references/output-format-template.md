# API Contract Summary Output Format Template

The full fill-in template for a service's API contract summary artifact. Self-contained — loadable without reading `SKILL.md` first.

This is the **annotated** version — every placeholder explains what belongs there and why. For a literal, fill-in-and-go copy with no explanatory brackets, use `assets/api-contract-summary-template.md` directly, or run `scripts/scaffold-api-contract-design.sh <product> <service-name>` to generate a new contract summary doc from it.

---

```markdown
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
```

The `openapi-spec` frontmatter field is the one thing here a plain markdown design doc wouldn't normally have: a literal path back to the machine-readable `openapi.yaml` this summary describes. The summary itself is what Shafi reviews without IDE tooling, per `CLAUDE.md`'s Artifact Standards — but a human-reviewable summary is only trustworthy if it stays traceable to the actual contract, not a stale paraphrase of it. `openapi-spec` is that traceability link: it satisfies the Artifact Standards requirement that every artifact "reference the requirement, event, or decision that caused it to exist," here anchoring the summary to the spec file it summarizes rather than to a requirement or event. Every row in the Endpoints table above should be checkable against the file at that path — if the two disagree, the OpenAPI spec is the source of truth (per SKILL.md's API-First framing) and this summary is what's out of date.
