# API Contract Review Checklist

A single deliberate gate to run over a finished OpenAPI spec, immediately before treating a contract as ready for the Design phase gate. Self-contained — loadable without reading `SKILL.md` first.

Large organizations catch cross-API drift with a governance board reviewing every contract before publication — a real, standing institution that exists because no single author has authority over every producing team. That institution has no referent here: `enterprise-architect` is the sole author of every API contract this factory produces, so the discipline a governance board enforces (consistency checked before a contract ships) still applies, just without the board. Run this checklist once, deliberately, over the finished spec — the same way `scripts/validate-adr.sh` is a distinct, named gate rather than something folded silently into "writing the ADR." It inherits every row from `SKILL.md`'s Quality Criteria table; it adds no new criteria, only the discipline of checking them as one deliberate pass rather than assuming they held because the skill was followed:

- [ ] Every resource name traces to the domain Ubiquitous Language, not a database table or a generic noun
- [ ] Every Command Catalog entry has a corresponding endpoint; every Read Model has a `GET`
- [ ] Every error response, on every documented failure branch, uses the standard `ErrorResponse` shape
- [ ] The path carries a `/v1/` (or current) version prefix
- [ ] `BearerAuth` is applied globally, with only health checks excluded
- [ ] Every mutating endpoint documents `Idempotency-Key` support
- [ ] Every collection endpoint uses the shared cursor-pagination shape, with no per-endpoint variant
- [ ] Every `202 Accepted` status URL resolves to a fully-specified `Operation` resource, not an unspecified "status URL"
- [ ] Any `resource:verb` custom method is a genuine non-CRUD action, not a workaround for a standard method
- [ ] Every resource with real concurrent-writer risk carries `etag`/`If-Match`

A contract that fails any row here is not ready for the Design phase gate, regardless of how much of the spec is otherwise written.
