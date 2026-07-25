# Validation Middleware and Versioning

Full standard referenced from `SKILL.md`'s "Request Validation at the Boundary" and "Versioning
Standard" sections — the exact `kin-openapi` middleware wiring and its position in
`go-middleware`'s ordering chain, and precisely what happens to generated Go code when the API
contract changes additively versus breakingly. Self-contained — usable without the parent
`SKILL.md` body already in context.

---

## The Request-Validation Middleware

`github.com/oapi-codegen/nethttp-middleware` wraps `kin-openapi`'s `openapi3filter` validator as
an ordinary `func(http.Handler) http.Handler` — installable with `chi`'s `r.Use(...)` exactly like
any other middleware in `go-middleware`'s chain:

```go
// internal/handlers/http/router.go
swagger, err := GetSwagger()       // GENERATED — embedded-spec: true (see codegen-configuration-and-type-mapping.md)
if err != nil {
    return fmt.Errorf("loading embedded spec: %w", err)
}
swagger.Servers = nil // disable server-URL matching — the router already scopes the mount path

validator := nethttpmiddleware.OapiRequestValidatorWithOptions(swagger, &nethttpmiddleware.Options{
    ErrorHandler: writeSpecValidationError, // routes into go-chi-handler's ErrorResponse envelope
    Options: openapi3filter.Options{
        AuthenticationFunc: openapi3filter.NoopAuthenticationFunc, // see "Security Requirements" below
    },
})
```

### Position in the Chain

`go-middleware`'s ordering standard is `Recoverer → RequestID → Telemetry → Logging →
SecurityHeaders → CORS → Authenticate → RateLimit → handler`. The spec validator mounts as the
**last middleware before the handler, immediately after `RateLimit`** — every earlier stage
(panic isolation, correlation, telemetry, auth, rate limiting) has already run, so a request that
fails spec validation is still fully observable (traced, logged, correlated) even though it never
reaches a handler or `decodeJSON`. Mounting it any earlier would validate a request that hasn't
been authenticated yet against a spec whose `security` requirements assume it has been — mounting
it later (inside the handler) would defeat the entire point of catching spec violations before
handler code runs at all.

### Security Requirements: a No-op, Not a Second Authenticator

The OpenAPI spec's `security: [BearerAuth: []]` (`api-contract-design`'s Authentication section)
declares that every operation requires a bearer token — `openapi3filter` is capable of enforcing
this itself, given an `AuthenticationFunc`. This plugin does **not** wire a second JWT check here:
`go-chi-handler`'s `Authenticate` middleware (`go-middleware`'s chain) already validates the JWT
and populates `r.Context()` with claims, earlier in the same chain. Wiring
`openapi3filter.NoopAuthenticationFunc` here is a deliberate no-op — it tells the spec validator
"trust that authentication already happened," so the contract still *documents* the requirement
(for consumers, for generated clients, for anyone reading the spec) without creating two
independent JWT-validation code paths that could disagree about what counts as a valid token.

### Error Mapping

`nethttpmiddleware.Options.ErrorHandler` is the one hook point where a validation failure crosses
back into `go-chi-handler`'s vocabulary — never left as the middleware's own default plain-text
response:

```go
func writeSpecValidationError(w http.ResponseWriter, message string, statusCode int) {
    writeError(w, nil, statusCode, "SPEC_VALIDATION_FAILED", message) // go-chi-handler's writeError
}
```

`SPEC_VALIDATION_FAILED` is deliberately a distinct code from `go-chi-handler`'s own
`VALIDATION_FAILED` (produced by a handler's hand-written `validate()`) — both are 400s using the
identical `ErrorResponse` envelope, but the code tells a client or support engineer which layer
rejected the request: the spec's declared schema (enums, formats, required, lengths — this
middleware), or a structural rule not expressible in OpenAPI at all (`go-chi-handler`'s own
boundary — see that skill's "Structural Validation at the Boundary"). Neither replaces the other;
a request can fail one and never reach the other, or pass both and still fail domain validation
one layer further in.

---

## Versioning Standard: What Happens to Generated Code

`api-contract-design`'s own versioning table (`SKILL.md`'s "Versioning Strategy") draws the
additive/breaking line at the contract level. This section is its Go-codegen consequence — what
regenerating actually produces on each side of that line.

| Contract change | Contract classification | Generated-code consequence |
|---|---|---|
| New optional response field | Additive — no version bump | Regenerate; the existing named struct gains one new field. Every existing caller of that struct compiles unchanged — Go's structural nature means an added field is source-compatible by construction. |
| New endpoint | Additive — no version bump | Regenerate; `StrictServerInterface` gains one new method. Every type already implementing it **fails to compile** until the method is added — a build break, not a contract break (see "Strict Server Pattern" in `codegen-configuration-and-type-mapping.md`). This is the one additive case that still forces an immediate code change, just not a version bump. |
| Field removed from a response | Breaking — bump to `/v2/` | The field's Go struct field disappears entirely on regeneration against the new spec. Any hand-written code still referencing it fails to compile — which is the correct, loud failure; a removed field silently defaulting to a zero value would be worse. |
| Field type or name changed | Breaking — bump to `/v2/` | Same struct, different field type/name after regeneration — a silent behavior change if the Go compiler didn't also catch it (wrong type used downstream); renamed fields are the more dangerous case since old and new may both compile if the surrounding code is loosely typed (e.g. passed through a `map[string]interface{}`), which is one more reason `Operation.response`-style freeform fields are used sparingly. |
| Endpoint removed | Breaking — bump to `/v2/` | The corresponding `StrictServerInterface` method disappears; the hand-written implementation method becomes dead code the compiler cannot flag as an interface violation (nothing requires it anymore) — remove it explicitly rather than leaving an orphaned handler nobody routes to. |

### Directory Convention During a Parallel-Version Sunset

`api-contract-design` requires `/v1/` and `/v2/` to run in parallel for a minimum six-month sunset
once a breaking change ships. Two independent contracts running simultaneously need two
independent sets of generated code — never one regenerated-in-place set that has forgotten what
`/v1/` looked like:

```
api/openapi_v1.yaml                     ← frozen — no further changes accepted
api/openapi_v2.yaml                     ← the current contract
internal/handlers/http/v1/gen.go         (//go:generate ... openapi_v1.yaml)
internal/handlers/http/v1/openapi_gen.go  ← GENERATED from openapi_v1.yaml
internal/handlers/http/v1/*.go            ← hand-written v1 implementations, frozen alongside the spec
internal/handlers/http/v2/gen.go         (//go:generate ... openapi_v2.yaml)
internal/handlers/http/v2/openapi_gen.go  ← GENERATED from openapi_v2.yaml
internal/handlers/http/v2/*.go            ← hand-written v2 implementations, actively developed
```

This is an extension of `go-project-structure`'s package-layout standard, not a departure from
it: outside a sunset window, a service has exactly one active version and the flat, unversioned
layout that skill already documents (`internal/handlers/http/openapi_gen.go`) applies unchanged.
The version-suffixed subpackages exist only for the duration two contracts must legitimately run
side by side, and collapse back to the flat layout the moment `/v1/` is retired (its subpackage
deleted, not merely stopped being routed to). The CI freshness check
(`go generate ./... && git diff --exit-code`, `go-project-structure`/`go-makefile`) runs across
both subpackages identically during a sunset window — freshness is checked per version, not
waived for the frozen one.

### Client Regeneration

Every version bump regenerates the typed client (`generate: {client: true}`) alongside the server.
A Consumer-Driven Contract test (`go-contract-test`) built against the `/v1/` client keeps
compiling and passing against `/v1/` for the entire sunset period; a new `/v2/` client is a
genuinely new generated type, not a mutation of the `/v1/` one — the two clients coexist in their
respective version subpackages exactly like the server types do.
