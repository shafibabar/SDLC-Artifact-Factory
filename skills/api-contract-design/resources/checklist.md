# Checklist: API Contract

Resource for `api-contract-design`. Run after `./scripts/validate-api-contract-design.sh` and `./scripts/validate-openapi-spec.sh` are clean; the scripts check structure, this list checks judgement. One agent authors every contract for a product, so this pass replaces the review board that keeps a many-team portfolio consistent.

## Resources and methods
- [ ] Every resource name comes from the Ubiquitous Language, not a table or a generic noun; collections are plural, kebab-case, nested at most one level.
- [ ] Every Command Catalog entry has an endpoint; every Read Model has a `GET`.
- [ ] No free-floating verb endpoint; any `resource:verb` custom method is a genuine non-CRUD action that a field update could not express.
- [ ] A `GET` never changes state.

## Responses
- [ ] Every error, on every documented failure branch, uses the one error envelope with the right status code; never a failure in a `200`.
- [ ] A `500` exposes no internal detail.
- [ ] Every collection uses the shared cursor pagination with a capped limit and a deterministic order.
- [ ] Every `202 Accepted` points to a fully specified Operation (name, done, response or error).
- [ ] A resource that two writers can race on carries `ETag` and `If-Match`, with a mismatch code distinct from a business-rule conflict.

## Idempotency, security and tenancy
- [ ] An `Idempotency-Key` is on each request a retry could repeat (creating or action `POST`, custom methods), with the retention window stated; none on `GET`, `PUT` or `DELETE`.
- [ ] A global security scheme applies to every operation, health endpoints excluded; every service verifies the token itself.
- [ ] No tenant path variable or isolation assumed unless the product is multi-tenant.

## Change and lifecycle
- [ ] The path carries a major version; additive changes need no new one, and the contract tells consumers to ignore unknown fields.
- [ ] A breaking change is a new version run beside the old, with a deprecation notice and a sunset sized to the consumers.
- [ ] The summary states the audience; a partner or public API is flagged, and consumers are in the registry.
- [ ] The spec is written first and sits at `design/<service>/openapi.yaml`; it was not generated from the code.

## Scope
- [ ] The contract is testable: every documented status code, error branch and response header could be asserted by a contract test.
- [ ] No implementation code appears in the contract or the summary.
