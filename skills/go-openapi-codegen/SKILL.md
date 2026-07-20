---
name: go-openapi-codegen
description: >
  Teaches contract-first development in Go — generating server types, request/
  response models, and route stubs from the OpenAPI 3.1 contract with oapi-codegen,
  so the hand-written code can never drift from the published API. Covers the
  generated-vs-handwritten boundary, validating requests against the spec,
  regeneration in CI, and keeping the contract (owned by the enterprise-architect)
  as the single source of truth. Used by the backend-engineer during Implement.
version: 1.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, openapi, codegen, oapi-codegen, contract-first, chi]
---

# Go OpenAPI Codegen

## Purpose

The API contract is designed before the code (contract-first — see `api-contract-design`). The OpenAPI 3.1 document is the single source of truth for routes, request/response shapes, and error envelopes. Code generation makes that truth enforceable: the server types and route interfaces are *generated from* the spec, so a handler that doesn't match the contract fails to compile. Drift between the documented API and the running API becomes impossible.

This skill generates the typed boundary; the hand-written application/domain logic plugs into it.

---

## Tooling

Default to **`oapi-codegen`** (`github.com/oapi-codegen/oapi-codegen`) targeting `net/http` + `chi` — consistent with the tech-stack defaults and the `go-chi-handler` skill. It generates:

- **Models** — Go structs for every schema in the spec (requests, responses, the error envelope).
- **Server interface** — a `ServerInterface` with one method per operation; the router binds it to chi.
- **Request binding** — path/query/body parsing wired to the generated types.

The contract (`api/openapi.yaml`) is authored by the enterprise-architect; the backend-engineer generates against it and does not edit it to fit the implementation — if the contract is wrong, it changes upstream first.

---

## Generation Setup

A `//go:generate` directive plus a pinned config keeps generation reproducible and visible in-repo.

```go
// internal/handlers/http/gen.go
//go:generate go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen -config cfg.yaml ../../../api/openapi.yaml
package http
```

```yaml
# cfg.yaml
package: http
output: openapi_gen.go
generate:
  models: true
  chi-server: true
  strict-server: true   # handlers return typed responses; framework handles encoding
```

`strict-server: true` generates an interface where each handler **returns a typed response object** instead of writing to `http.ResponseWriter` directly — the generated layer handles status codes and encoding, eliminating a class of "wrong status / forgot to return" bugs.

---

## The Generated / Hand-Written Boundary

```
api/openapi.yaml                 ← source of truth (enterprise-architect)
        │  oapi-codegen
        ▼
internal/handlers/http/openapi_gen.go   ← GENERATED: models, ServerInterface, router binding
        │  implemented by
        ▼
internal/handlers/http/*.go              ← HAND-WRITTEN: implements ServerInterface,
                                            calls application-layer command/query handlers
```

| Layer | Generated? | Owner |
|---|---|---|
| Models, server interface, routing | Generated — never edited by hand | oapi-codegen |
| Handler method bodies | Hand-written | backend-engineer |
| Application/domain logic | Hand-written | backend-engineer |

**Generated files are never edited.** They carry a "DO NOT EDIT" header and are regenerated, not patched. Editing them is overwritten on the next `go generate`.

```go
// Hand-written: implement the generated strict interface; translate to the application layer.
func (a *API) ClassifyDataAsset(ctx context.Context, req ClassifyDataAssetRequestObject) (ClassifyDataAssetResponseObject, error) {
    cmd := commands.ClassifyDataAsset{
        DataAssetID: req.Id,
        Sensitivity: domain.SensitivityLevel(req.Body.SensitivityLevel),
        IdempotencyKey: req.Params.IdempotencyKey,
    }
    if err := a.classify.Handle(ctx, cmd); err != nil {
        return classifyErrorResponse(err), nil // map domain error → typed response
    }
    return ClassifyDataAsset204Response{}, nil
}
```

---

## Validation Against the Spec

Beyond typed binding, requests are validated against the OpenAPI schema at runtime using `kin-openapi`'s request validator as middleware — so constraints expressed in the spec (enums, formats, required, lengths) are enforced without restating them by hand. This complements (does not replace) the domain's business validation (two-layer validation — see `go-chi-handler`).

---

## Codegen in CI

Generation is verified in CI so a stale generated file (spec changed, code not regenerated) fails the build:

```bash
go generate ./...
git diff --exit-code   # fails if generated output differs from what's committed
```

This guarantees the committed generated code always matches the committed spec — the contract and the code can never silently diverge.

---

## Client Generation (for Consumers)

The same spec generates **typed clients** for internal consumers and for Consumer-Driven Contract tests (see `integration-design` / test-engineering). A consuming service imports a generated client rather than hand-rolling HTTP calls — the contract binds both sides.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Contract-first | Spec authored before code; code generated from it | Spec written after, or by hand to match code |
| Generated not edited | Generated files carry DO-NOT-EDIT; regenerated only | Hand-edits to generated files |
| Strict server | Handlers return typed responses | Raw `ResponseWriter` writes bypassing the contract |
| Spec validation | Requests validated against the OpenAPI schema | Schema constraints re-implemented by hand or skipped |
| CI freshness check | `go generate` + `git diff --exit-code` in CI | Generated code allowed to drift from the spec |
| Single source of truth | One spec drives server + clients + contract tests | Divergent hand-written client/server shapes |

---

## Anti-Patterns

- **Editing generated files** — the fix evaporates on the next `go generate`, and until then the committed code lies about what the spec produces. Change the spec or the config, then regenerate.
- **Code-first "contract"** — writing handlers, then annotating or reverse-engineering a spec from them. The contract becomes a description of accidents rather than a designed interface.
- **Bending the spec to fit the implementation** — the contract is the enterprise-architect's artifact; if it's wrong, it changes upstream with review, never by a quiet local edit to unblock a build.
- **Restating spec constraints by hand** — re-implementing enum/format/required checks in Go duplicates the schema and guarantees drift; the spec validator middleware enforces them from the source.
- **Bypassing the strict interface** — grabbing `http.ResponseWriter` inside a strict handler to write an ad-hoc response reintroduces the untyped-status bugs strict mode exists to eliminate.
- **Generated code in `.gitignore`** — hiding generation from review breaks the CI freshness check and makes builds depend on the generator's presence. Commit the generated file.

---

## Output Format

Produces generated Go plus the hand-written implementations:

```
internal/handlers/http/gen.go            (//go:generate directive + config)
internal/handlers/http/openapi_gen.go    (GENERATED — models, interface, routing)
internal/handlers/http/*.go              (hand-written ServerInterface implementations)
```
