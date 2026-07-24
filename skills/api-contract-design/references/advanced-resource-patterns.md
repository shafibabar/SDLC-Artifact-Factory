# Advanced Resource Patterns

Grounded in JJ Geewax's *API Design Patterns* (`research/software-architecture/api-design-patterns-geewax.md`) — the four/five patterns this skill's core resource model doesn't cover on its own: actions that aren't clean CRUD, async work that needs a pollable status shape, concurrent-writer safety, and precise partial-update semantics.

## Custom Methods

*Stub — to be filled by sub-issue #237. Brief: the `POST /{resource}:verb` pattern (colon-suffixed, resource-scoped) as the disciplined fallback for actions that genuinely aren't a create/read/update/delete on the resource — explicitly distinct from `SKILL.md`'s "Verb endpoints" anti-pattern, which forbids free-floating RPC-style endpoints, not this narrower, resource-scoped exception. A worked example using this repo's own domain (e.g. `POST /v1/estate-scans/{id}:cancel`).*

## Long-Running Operations

*Stub — to be filled by sub-issue #237. Brief: the full `Operation` resource shape (`name`/`id`, `done: boolean`, and once done, either `response` or `error`) that a `202 Accepted` status URL should return when polled — extending `SKILL.md`'s existing 202 row, which currently specifies the initial response but not the status-check response. The `error` field reuses `SKILL.md`'s existing `ErrorResponse` shape exactly, not a new error type. A worked YAML example plus `GET /operations/{id}` polling semantics.*

## Resource Revisions (Optimistic Concurrency)

*Stub — to be filled by sub-issue #237. Brief: `etag`/`If-Match` for resources with real concurrent-writer risk — explicitly distinct from `SKILL.md`'s existing `409 Conflict` row (Aggregate business-rule violations), this is about detecting a lost update from two clients racing on the same record. A worked example on a plausible concurrent-writer resource from this repo's own domain (e.g. `DataAsset` or `ComplianceGap`).*

## Field Masks

*Stub — to be filled by sub-issue #237. Brief: the `updateMask`/`fieldMask` convention clarifying `PATCH` partial-update semantics — an omitted field means "leave unchanged," distinct from an explicit `null` meaning "clear the field." A brief note on an optional response-side field mask for large resources.*

## Singleton Sub-resources

*Stub — to be filled by sub-issue #237. Brief: the one-per-parent, Get/Update-only pattern (no List, Create, or Delete) for settings-like resources with no independent lifecycle — a narrower, more specific case than `SKILL.md`'s general "nest only one level deep" sub-resource rule. One short worked example.*
