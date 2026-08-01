---
name: go-openapi-codegen
description: >
  Teaches contract-first Go development — generating server types, the strict
  ServerInterface, request/response models, and a typed client from the
  OpenAPI 3.1 contract with oapi-codegen, so hand-written code can never drift
  from the published API. Covers the exact codegen configuration and why each
  option is chosen, the generated-vs-hand-written boundary and its CI
  freshness check, the OpenAPI-to-Go type-mapping standard — including how
  oapi-codegen represents api-contract-design's Field Mask, Long-Running
  Operation (Operation resource), and Resource Revision (ETag) patterns as
  generated Go types — the kin-openapi request-validation middleware wired
  into go-chi-handler's/go-middleware's chain, and the versioning standard for
  what happens to generated code on an additive versus a breaking contract
  change. Full config and type-mapping detail in
  references/codegen-configuration-and-type-mapping.md; validation-middleware
  wiring and versioning consequences in
  references/validation-middleware-and-versioning.md. Used by the
  backend-engineer during Implement.
version: 2.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, openapi, codegen, oapi-codegen, contract-first, chi, kin-openapi, versioning]
produces: go-openapi-generated-code
domain: backend
status: stable
related: [api-contract-design, go-chi-handler, go-project-structure, go-middleware, go-makefile]
---

# Go OpenAPI Codegen

## Purpose

The API contract is designed before the code (contract-first — `api-contract-design`). The
OpenAPI 3.1 document is the single source of truth for routes, request/response shapes, and
error envelopes. Code generation makes that truth enforceable: server types and route interfaces
are *generated from* the spec, so a handler that doesn't match the contract fails to compile.
This skill owns the Go-implementation side of that contract only — resource design, versioning
*policy*, and the Field Mask/Long-Running-Operation/Resource-Revision patterns themselves are
`api-contract-design`'s; this skill owns how `oapi-codegen` represents each as generated Go.

---

## Tooling and Configuration

Default to **`oapi-codegen`** (`github.com/oapi-codegen/oapi-codegen`) targeting `net/http` +
`chi`, generating models, a strict `chi-server`, and a typed `client` from one config against
`api/openapi.yaml`:

```yaml
# internal/handlers/http/cfg.yaml
package: http
output: openapi_gen.go
generate: { models: true, chi-server: true, strict-server: true, client: true, embedded-spec: true }
output-options: { nullable-type: true }   # nullable: true properties → nullable.Nullable[T], not *T
```

`embedded-spec: true` compiles the exact spec used for codegen into the binary (`GetSwagger()`) so
the runtime request validator (below) can never load a stale copy from disk. `nullable-type: true`
is required for the Field Mask representation (see the type-mapping reference). `strict-server:
true` generates handlers that return typed response objects instead of writing to
`http.ResponseWriter`, eliminating "wrong status / forgot to return" bugs — see the reference for
the full response-variant pattern. Full annotated config and per-option rationale:
`references/codegen-configuration-and-type-mapping.md`.

The contract is authored by the enterprise-architect; the backend-engineer generates against it
and never edits it to fit the implementation — a wrong contract changes upstream first.

---

## The Generated / Hand-Written Boundary

```
api/openapi.yaml (source of truth) → oapi-codegen → internal/handlers/http/openapi_gen.go (GENERATED)
                                                            ↓ implemented by
                                      internal/handlers/http/*.go (HAND-WRITTEN)
```

Naming, co-location, and the mechanical freshness check (`go generate ./...` +
`git diff --exit-code`) are `go-project-structure`'s authoritative standard
(`references/package-layout-standard.md`'s "Generated-vs-Hand-Written Boundary") and
`go-makefile`'s `ci` target — not restated here. **Generated files are never edited**; they carry
a `DO NOT EDIT` header and are regenerated, not patched.

```go
// Hand-written: implement the generated strict interface; translate to the application layer.
func (a *API) ClassifyDataAsset(ctx context.Context, req ClassifyDataAssetRequestObject) (ClassifyDataAssetResponseObject, error) {
    cmd := commands.ClassifyDataAsset{DataAssetID: req.Id, Sensitivity: domain.SensitivityLevel(req.Body.SensitivityLevel)}
    if err := a.classify.Handle(ctx, cmd); err != nil {
        return classifyErrorResponse(err), nil // map domain error → typed response
    }
    return ClassifyDataAsset204Response{}, nil
}
```

---

## Type-Mapping Standard

Core scalar mapping: `string`→`string`, `format: uuid`→`uuid.UUID` via `x-go-type` (matching
`internal/domain`'s own ID type, not oapi-codegen's default wrapper), `format: date-time`→
`time.Time`, `integer`/`number`→sized Go numerics per an explicit `format`, `object`-with-no-
properties→`map[string]interface{}`. Full table: `references/codegen-configuration-and-type-mapping.md`.

Three `api-contract-design` patterns get specific generated shapes:

- **Field Mask** — an ordinary optional field marked `nullable: true` generates
  `nullable.Nullable[T]`, giving the omitted/explicit-null/value distinction real type-level teeth
  (a bare `*T` cannot make it — both omitted and null decode to `nil`). The `updateMask` query
  parameter is a plain `type: string`, generating as `*string`; splitting it into field paths is
  hand-written.
- **Long-Running Operation** — `Operation.response` generates as `map[string]interface{}`
  (the schema is deliberately freeform); `Operation.error` generates as the same named `Error`
  struct every other `ErrorResponse.error` `$ref` site produces, deduplicated, not redefined.
- **Resource Revision** — `ETag`/`If-Match` generate as plain `string`/`*string` header fields,
  never a numeric or timestamp type, preserving the opacity `api-contract-design` requires.

Full reasoning and generated struct listings: `references/codegen-configuration-and-type-mapping.md`.

---

## Request Validation at the Boundary

Beyond typed binding, requests are validated against the OpenAPI schema at runtime by
`kin-openapi`'s validator (`github.com/oapi-codegen/nethttp-middleware`), mounted as the **last
middleware before the handler** in `go-middleware`'s chain — immediately after `RateLimit` — so a
spec violation is rejected fully observable (traced, logged, correlated) but before it ever reaches
`decodeJSON` or a handler. Its `AuthenticationFunc` is a deliberate no-op:
`go-chi-handler`'s `Authenticate` already validated the JWT earlier in the same chain, so this
validator documents the `security` requirement without re-checking it. Its `ErrorHandler` routes
into `go-chi-handler`'s `ErrorResponse` envelope under a distinct `SPEC_VALIDATION_FAILED` code —
never left as the middleware's own default plain-text response, and never confused with
`go-chi-handler`'s own `VALIDATION_FAILED` (its hand-written `validate()`, for structural rules
OpenAPI's schema vocabulary can't express). Neither validation layer replaces the other. Full
wiring code and the `Options` construction: `references/validation-middleware-and-versioning.md`.

---

## Versioning Standard

`api-contract-design`'s additive/breaking classification (new optional field or endpoint =
no version bump; removed/renamed field, changed type, or removed endpoint = bump to `/v2/`) has a
distinct generated-code consequence on each side: an additive field addition compiles unchanged;
an additive *endpoint* addition still forces a hand-written change (a new `StrictServerInterface`
method breaks the build until implemented — a build break, not a contract break); every breaking
case fails the build loudly (a removed/changed field no longer compiles where it's used). During
the mandatory six-month parallel-run sunset, `/v1/` and `/v2/` generate into version-suffixed
sibling subpackages (`internal/handlers/http/v1/`, `.../v2/`), each with its own spec, generated
file, and CI freshness check — collapsing back to the flat, unversioned layout the moment `/v1/`
is retired. Full table and directory listing: `references/validation-middleware-and-versioning.md`.

---

## Client Generation (for Consumers)

The same config's `client: true` generates a typed client for internal consumers and Consumer-
Driven Contract tests (`go-contract-test`) from the identical schema objects the server uses —
never a second, independently hand-rolled client that can drift from the server's own types.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Contract-first | Spec authored before code; code generated from it | Spec written after, or by hand to match code |
| Generated code integrity | DO-NOT-EDIT, regenerated only; `go generate` + `git diff --exit-code` clean in CI | Hand-edits, or committed generated code stale relative to the spec |
| Strict server | Handlers return typed responses | Raw `ResponseWriter` writes bypassing the contract |
| Type-safety at the boundary | `format: uuid`/`date-time` map to `uuid.UUID`/`time.Time`, never bare `string` | A UUID or timestamp field left as `string`, pushing parsing into every consumer |
| Field Mask fidelity | `nullable: true` fields generate `nullable.Nullable[T]`; omitted/null/value all distinguishable | A bare `*T` used where omitted-vs-null must be told apart |
| Spec validation wired, no duplicate auth | `nethttpmiddleware` mounted last-before-handler, `ErrorHandler` routes to `ErrorResponse`, `AuthenticationFunc` a no-op | Middleware absent/default error output, or a second independent JWT check inside it |
| Validation-coverage check | Every schema constraint (enum, format, required, length) is enforced by the spec validator, not re-typed by hand | Enum/format/required checks re-implemented ad hoc in a handler `validate()` |
| Versioning consequence honored | Breaking changes bump `/v2/` and generate into a version-suffixed subpackage; `/v1/` stays frozen and gated | A breaking change regenerated in place over `/v1/`'s existing generated code |
| Single source of truth | One spec drives server + clients + contract tests | Divergent hand-written client/server shapes |

---

## Anti-Patterns

- **Editing generated files** — the fix evaporates on the next `go generate`; the committed code lies about what the spec produces until then. Same failure mode as **generated code in `.gitignore`**, which hides drift from review and the CI freshness check entirely.
- **Code-first "contract"** — writing handlers, then reverse-engineering a spec from them.
- **Bending the spec to fit the implementation** — a wrong contract changes upstream, never by a quiet local edit.
- **Restating spec constraints by hand** — re-implementing enum/format/required checks duplicates the schema and guarantees drift; the spec validator middleware enforces them from the source.
- **A `*T` field where the schema needs `nullable.Nullable[T]`** — silently collapses "omitted" and "explicit null" into the same `nil`, breaking Field Mask semantics.
- **A second JWT check inside the spec validator's `AuthenticationFunc`** — two independent code paths that can disagree about what counts as a valid token.
- **Regenerating a breaking change in place over `/v1/`'s package** — destroys the frozen version's generated code mid-sunset, breaking every consumer still calling it.

---

## Output Format

```
internal/handlers/http/gen.go             (//go:generate directive; config: references/codegen-configuration-and-type-mapping.md)
internal/handlers/http/cfg.yaml            (oapi-codegen config)
internal/handlers/http/openapi_gen.go      (GENERATED — models, StrictServerInterface, client, routing)
internal/handlers/http/router.go           (mounts the kin-openapi validator; wiring in references/validation-middleware-and-versioning.md)
internal/handlers/http/*.go                 (hand-written ServerInterface implementations)
```

During a parallel-version sunset, `v1/` and `v2/` sibling subpackages replace the flat layout —
full directory listing: `references/validation-middleware-and-versioning.md`.
