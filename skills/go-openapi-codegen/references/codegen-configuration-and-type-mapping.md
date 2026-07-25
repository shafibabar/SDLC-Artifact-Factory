# Codegen Configuration and Type Mapping

Full standard referenced from `SKILL.md`'s "Tooling and Configuration" and "Type-Mapping
Standard" sections — the complete, annotated `oapi-codegen` config, the strict-server response
pattern, the OpenAPI-to-Go scalar mapping, and precisely how `oapi-codegen` represents
`api-contract-design`'s Field Mask, Long-Running Operation (Operation resource), and Resource
Revision (ETag) patterns as generated Go types. Self-contained — usable without the parent
`SKILL.md` body already in context.

---

## The Complete `oapi-codegen` Configuration

```yaml
# internal/handlers/http/cfg.yaml
package: http
output: openapi_gen.go

generate:
  models: true          # Go structs for every components/schemas entry
  chi-server: true       # ServerInterface + chi route registration (RegisterHandlers)
  strict-server: true    # handlers return typed response objects — see "Strict Server" below
  client: true            # typed client for internal consumers and contract tests
  embedded-spec: true     # GetSwagger() returns the parsed spec compiled into the binary

output-options:
  nullable-type: true     # nullable: true properties generate nullable.Nullable[T], not *T
  name-normalizer: ToCamelCase

compatibility:
  old-merge-schemas: false
```

| Option | Why this value, not the alternative |
|---|---|
| `models: true` | Every request/response/error shape becomes a real Go type — the whole point of contract-first codegen; turning it off would leave handlers hand-typing what the spec already declares. |
| `chi-server: true` | Matches the tech-stack default (`net/http` + `chi`) and `go-chi-handler`'s router; a different server target (`gin-server`, `echo-server`) would require rewriting that skill's entire routing convention. |
| `strict-server: true` | See "Strict Server Pattern" below — eliminates the class of bugs where a handler forgets to call `WriteHeader` or encodes the wrong shape. |
| `client: true` | One config, one generation run, produces the server types and the typed client from the same schema objects — never two independently-drifting type sets for the same contract. |
| `embedded-spec: true` | The kin-openapi request-validation middleware (`references/validation-middleware-and-versioning.md`) needs an `*openapi3.T` at runtime. `embedded-spec` compiles the exact spec used for codegen into the binary via a generated `GetSwagger()` function, so the validator can never load a stale or missing `api/openapi.yaml` from disk at runtime — the spec the server validates against is provably the same spec the types were generated from. |
| `nullable-type: true` | Required for the Field Mask representation below — without it, every optional field is a bare pointer, which cannot distinguish "omitted" from "explicit null" (see Field Masks section). |
| `old-merge-schemas: false` | Uses the current (non-legacy) `allOf`/schema-composition merge behavior — the legacy mode exists only for pre-2.x config migration and is never opted into on a new service. |

The `//go:generate` directive lives in a small hand-written sibling file, never inside the
generated output itself:

```go
// internal/handlers/http/gen.go
//go:generate go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen -config cfg.yaml ../../../api/openapi.yaml
package http
```

---

## Strict Server Pattern

`strict-server: true` generates a `StrictServerInterface` with one method per operation, where
each method takes a typed request object and returns `(ResponseObject, error)` instead of writing
to `http.ResponseWriter` directly:

```go
// GENERATED — one method per OpenAPI operation
type StrictServerInterface interface {
    ClassifyDataAsset(ctx context.Context, request ClassifyDataAssetRequestObject) (ClassifyDataAssetResponseObject, error)
}

// GENERATED — one type per declared response, implementing ClassifyDataAssetResponseObject
type ClassifyDataAsset204Response struct{}
type ClassifyDataAsset404JSONResponse ErrorResponse
type ClassifyDataAsset409JSONResponse ErrorResponse
```

The hand-written implementation returns one of the generated response-variant types; the
generated `strictHandler` wrapper (also emitted by `chi-server` + `strict-server`) is what
actually calls `w.WriteHeader` and encodes the body — a hand-written handler can no longer forget
a status code or serialize the wrong shape, because it never touches `ResponseWriter` at all. This
is the same discriminated-union simulation Go's lack of sum types otherwise forces by hand: the
generated interface plus per-status types stand in for `oneof`.

Adding a new operation to the spec adds a new method to `StrictServerInterface`. Any struct
already implementing it fails to compile until the method is added — a compiler-enforced forcing
function that makes forgetting to implement a new endpoint a build error, not a runtime 501. This
is a **build break, not a contract break**: see "Versioning Standard" in
`references/validation-middleware-and-versioning.md` for why the two are different claims.

---

## OpenAPI-to-Go Type-Mapping Standard

| OpenAPI schema | Generated Go type | Notes |
|---|---|---|
| `type: string` | `string` | |
| `type: string, format: uuid` | `uuid.UUID` via `x-go-type: uuid.UUID` + `x-go-type-import` (never the default `openapi_types.UUID` wrapper) | Matches `internal/domain`'s own ID type (`go-project-structure`'s `package-layout-standard.md` names `github.com/google/uuid` as one of the only three imports a domain package may carry) — a handler passes a decoded ID straight to the domain layer with no boundary conversion. |
| `type: string, format: date-time` | `time.Time` | oapi-codegen's default for this format; no override needed. |
| `type: integer` / `type: number` | `int` / `int64` / `float32` per `format` (`int32`, `int64`, `float`, `double`) | Declare `format` explicitly in the spec — an integer with no `format` defaults to a plain `int`, which is a 32-bit width footgun on a platform where `int` is 32 bits; always declare `int64` for any ID-adjacent or money-adjacent numeric field. |
| `type: boolean` | `bool` | |
| `type: array` | `[]T` | |
| `type: object` with `properties` | named `struct` | One named type per schema, deduplicated across every `$ref` site — a schema referenced from three operations generates once, not three times. |
| `type: object` with no `properties` (freeform) | `map[string]interface{}` | See the `Operation.response` field below — this is the shape a deliberately-untyped schema produces, not a modeling mistake to "fix" by adding properties oapi-codegen doesn't know about. |
| Optional property, `nullable: false` (or absent) | `*T` | Pointer distinguishes "not sent" from "sent" — cannot distinguish "sent as null" from "not sent" (both are `nil`). |
| Optional property, `nullable: true` | `nullable.Nullable[T]` (`github.com/oapi-codegen/nullable`) | Three states via `.IsSpecified()` / `.IsNull()` / `.Get()` — see Field Masks below. |

`x-go-type` is oapi-codegen's schema-level extension for overriding the generated Go type when the
default mapping isn't the type this codebase actually wants — used here only for `uuid.UUID`; it
is not a general-purpose escape hatch for reshaping generated models, and a new use of it should
be rare and reviewed, not the default way to "fix" a mapping that reads oddly.

### Field Masks in Generated Code

`api-contract-design`'s Field Mask pattern (`references/advanced-resource-patterns.md` in that
skill) has two parts, and codegen represents them differently:

1. **Per-field omitted-vs-null semantics** on an ordinary `PATCH` body (`sensitivityLevel` set,
   `notes` explicitly cleared, everything else left alone). With `nullable-type: true` and the
   schema property marked `nullable: true`, oapi-codegen generates `nullable.Nullable[string]`
   instead of `*string`. `req.Notes.IsSpecified()` is false when the field was omitted entirely;
   `true` with `.IsNull()` true when the client sent `"notes": null`; `true` with `.Get()`
   returning a value when the client sent a real string. This gives the omitted/null/value
   distinction real type-level teeth instead of relying on convention alone — a `*string` field
   cannot make this distinction because Go's `encoding/json` leaves it `nil` in both the omitted
   and explicit-null cases.
2. **The `updateMask` query parameter** (`?updateMask=sensitivityLevel,notes`) is declared in the
   spec as `type: string` — a plain comma-separated field-path list, not an array-typed parameter.
   It generates as an ordinary optional string field (`*string`) on the operation's generated
   `Params` struct; splitting it into individual field paths is hand-written code, since
   oapi-codegen has no schema-level concept of "this string is a delimited list of these other
   properties' names."

### Long-Running Operations in Generated Code

The `Operation` schema (`name`, `done`, `response`, `error` — `api-contract-design`'s
`references/advanced-resource-patterns.md`) generates as:

```go
// GENERATED
type Operation struct {
    Name     string                  `json:"name"`
    Done     bool                    `json:"done"`
    Response *map[string]interface{} `json:"response,omitempty"`
    Error    *Error                  `json:"error,omitempty"`
}
```

`Response` generates as `map[string]interface{}` (not a concrete resource type) precisely because
the schema itself is freeform — "shaped like whatever the triggering call would have returned,"
which varies per operation and cannot be a single Go type. Hand-written code that polls an
`Operation` must re-`json.Marshal`/`Unmarshal` this field into the concrete expected resource type
once `Done` is true — this is a real consequence of the pattern's polymorphism, not a codegen gap
to work around. `Error`, by contrast, generates as the same named `Error` struct every other
`ErrorResponse.error` site in the spec produces — because `Operation.error` is a `$ref` to a
concretely-typed schema, oapi-codegen deduplicates it into the one generated type, reused, not
redefined.

### Resource Revisions in Generated Code

`ETag`/`If-Match` are declared as plain `type: string` header parameters — a response header
(`ETag`) and a request header (`If-Match`). Both generate as ordinary `string`/`*string` fields
(the request-side `If-Match` is optional, hence a pointer; a strict-server response type that sets
a header does so through the generated response object's `Headers` field). The revision value is
never given a numeric or timestamp Go type even if the underlying implementation happens to be one
— `api-contract-design` defines it as an **opaque** identifier, and a Go type that invites parsing
or arithmetic on it (an `int` revision counter, a `time.Time`) would contradict that opacity and
invite a hand-written comparison the server, not the client, is supposed to own.

---

## Client Generation

`generate: {client: true}` on the same config, against the same spec, produces a typed HTTP client
in the same generated file — consumed by internal service-to-service callers and by
Consumer-Driven Contract tests (`go-contract-test`, `integration-design`). Generating client and
server from one config run is deliberate: a hand-rolled client and a generated server can drift
independently; a client generated from the identical schema objects cannot.
