---
name: api-contract-design
description: >
  Design a service's API contract first, as an OpenAPI 3.1 specification the
  backend and frontend are built against: resources named from the Ubiquitous
  Language, Commands and Read Models mapped to methods, a custom method
  (resource:verb) only where an action is not CRUD, one error envelope with
  the right status codes, a long-running Operation behind 202 Accepted, a
  revision check (ETag, If-Match) for concurrent writers, one cursor
  pagination convention, versioning and a deprecation path sized to the
  consumers (additive change needs no version; breaking change runs a new
  version in parallel, with a Tolerant Reader on the consuming side), an
  Idempotency-Key only where a retry could repeat an effect, and a
  token every service verifies itself. Use when designing, reviewing or
  changing an API contract, adding an endpoint, removing a field or
  deprecating a version. Internal service-to-service calls may be
  grpc-contract-design instead. Used by enterprise-architect.
version: 3.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, api-first, openapi, contract-first, rest, versioning]
produces: openapi-specification
domain: architecture
status: stable
related: [command-catalog, read-model-design, grpc-contract-design, api-gateway-design, integration-design, cqrs-pattern, go-contract-test, python-contract-test, glossary-management, methodology-review]
sources:
  - research/software-architecture/api-design-patterns-geewax.md
  - research/software-architecture/api-first-transformation-lane.md
  - research/software-architecture/building-microservices-newman.md
  - research/testing/testing-web-apis-winteringham.md
---

# API Contract Design

## Purpose

An API built from handlers backwards describes whatever got built, and its breaking changes ship unnoticed. API-first reverses it: the contract is designed, reviewed and agreed before implementation, and the code is held to it. The contract is a product, not plumbing (Lane): the durable interface a later mobile client or partner will be built on, long after the first screen has changed. **Readers:** enterprise-architect, backend-engineer, frontend-engineer, the product owner (what consumers can rely on). **Question:** for each service, what can a caller do, what do they get back, and what happens when the contract changes?

The output is one `design/<service>/openapi.yaml` per service (the manifest path; it is copied into the service repository at Implement) and a summary, `design/<service>/api-contract-summary.md` (`./templates/api-contract-summary.md`). HTTP lives here: the Command Catalog gives the Commands, their rejections and idempotency keys (`command-catalog`); the Read Models give the queries (`read-model-design`). The code is the `go-*` and `python-*` skills.

| Profile | What this holds |
|---|---|
| Lean | The spec only (the summary is skipped): a few resources, one version prefix, the shared error envelope. Sections not needed are omitted |
| Standard | Spec plus summary: custom methods, Operations and revisions where the service needs them |
| Enterprise | As standard, plus the consumer registry, the audience flag, and the deprecation policy for every version in use |

## Procedure

1. **Read** the Command Catalog and Read Models for the service, the Ubiquitous Language, the container diagram (who calls this service), the NFR specification, and `sdlc-config.json`. Note who the consumers are: this product's own front end, other services, or partners.
2. **Choose the interface:** REST over HTTP for a browser, mobile or partner caller; gRPC (`grpc-contract-design`) for an internal service-to-service call that benefits from a strict typed contract.
3. **Name the resources** (`./references/resource-and-method-design.md`): plural nouns from the Ubiquitous Language, kebab-case, nested at most one level; never table names or verbs.
4. **Map Commands and queries to methods:** a Command is a `POST`, `PUT`, `PATCH` or `DELETE` on a resource; a Read Model query is a `GET`. A genuine non-CRUD action is a custom method (`POST /resource/{id}:verb`), only after checking that a field update does not express it.
5. **Specify responses** (`./references/responses-and-errors.md`): status codes, one error envelope, the cursor pagination convention for every collection, a `202 Accepted` with a pollable Operation for long work, a revision check (`ETag`, `If-Match`) where two writers can race.
6. **Decide idempotency:** an `Idempotency-Key` on a request a retry could repeat (a `POST` that creates or triggers an action, a custom method); `PUT` and `DELETE` are idempotent by definition. State how long keys are kept, per product.
7. **Declare security:** a global scheme in the contract, health endpoints excluded. Every service verifies the token itself; a gateway is only the first check (`api-gateway-design`).
8. **Plan change** (`./references/versioning-and-lifecycle.md`): additive change needs no new version and consumers tolerate unknown fields; a breaking change is a new major version run beside the old one, with a deprecation notice and a sunset sized to the consumers. Flag a public or partner-facing API.
9. **Write the summary and the spec** (`./scripts/scaffold-api-contract-design.sh <product> <service>` starts the summary from the template), then **validate and loop:** run `./scripts/validate-api-contract-design.sh <summary>` and `./scripts/validate-openapi-spec.sh <openapi.yaml>`, fix every FAIL, re-run until clean; then `./resources/checklist.md`.
10. **Present** with the reason for every request declined (§ Gotchas). Always state: the OpenAPI 3.1 contract is written first, is the source of truth and gates the code, sits at `design/<service>/openapi.yaml` and is copied into the service repository at Implement; what is breaking (removing or renaming a field, changing a type, removing an endpoint) and what is additive (a new optional field or endpoint, which consumers tolerate); where an `Idempotency-Key` goes (a `POST` that creates or triggers an action, a custom method), that `GET`, `PUT` and `DELETE` need none because they are safe or idempotent by definition, and that the retention window is a decision for this product, with its reason; and that every documented status code, response header and error branch gets a contract test. The reply carries no implementation code. Answering in a reply: the declined requests and their reasons once, then the spec fragments once, without the summary's YAML frontmatter block.

Examples: `./examples/01-lean-recipe-box-three-resources.md` (a small app asking for verb endpoints, 200-with-error bodies and offset paging), `./examples/02-standard-leave-requests-custom-method-and-export.md` (an approve action, a lost update and a slow export), `./examples/03-enterprise-partner-api-deprecation.md` (a field renamed in a live partner API, handled as a breaking change).

## Gotchas

- **"Add `POST /approveInvoice`."** *Reason:* a free-floating verb has no resource, caching or place in the hierarchy. *Instead:* a state change on the resource if the transition is a field the invoice holds; otherwise a custom method `POST /invoices/{id}:approve`.
- **"Return 200 with `{"success": false}`."** *Reason:* clients, gateways, retries and monitoring key on the status code; the error disappears. *Instead:* the right 4xx or 5xx and the standard error envelope.
- **"Use offset pages for the orders list."** *Reason:* on a large, frequently written collection offsets skip or repeat rows as data moves. *Instead:* cursor pagination with a capped limit and a deterministic order; offsets only for a small, stable admin list.
- **"Remove the field from v1; nobody uses it."** *Reason:* removing or renaming a field, changing a type or removing an endpoint breaks any consumer that reads it, known or not. *Instead:* a new major version run beside the old one, a deprecation notice, and a sunset sized to the consumers.
- **"Two weeks' notice is enough for partners."** *Reason:* a partner has its own release cycle; a short notice breaks it. *Instead:* size the sunset to the consumers (a partner API a long period), announce with the `Deprecation` header, and keep the old version running.
- **"Make the key required on every request."** *Reason:* `GET`, `PUT` and `DELETE` are safe or idempotent already; a key there adds storage and ceremony. *Instead:* require it where a retry could repeat an effect.
- **"A 409 covers two people editing."** *Reason:* a business-rule conflict and a lost update are different; the second needs the client to reload. *Instead:* a revision (`ETag`, `If-Match`) with a distinct error code for the mismatch.
- **"Generate the spec from the code later."** *Reason:* the contract then describes what was built, and breaking changes slip through. *Instead:* the spec first, reviewed and checked in CI; the code is generated from it or validated against it.
- **"The gateway checks the token, so the service need not."** *Reason:* a request can reach a service without the gateway, and no actor is trusted by position. *Instead:* every service verifies identity; the gateway is the first check.
- **"Add a tenant to every path."** *Reason:* a tenant path variable is only right for a multi-tenant product that routes that way. *Instead:* decide from `multi-tenancy-design`; do not assume it.

## References

| Question | File |
|---|---|
| Naming, method mapping, custom methods, singletons, field masks, filtering | `./references/resource-and-method-design.md` |
| Status codes, the error envelope, pagination, long-running Operations, revisions | `./references/responses-and-errors.md` |
| Additive versus breaking, Tolerant Reader, deprecation, audience | `./references/versioning-and-lifecycle.md` |
| The summary artifact | `./templates/api-contract-summary.md` |
| Checking before hand-off | `./resources/checklist.md` |
