# Package Layout Standard

The authoritative, per-package Output Format standard for `go-project-structure`: what belongs in each package, what must never appear there, naming rules, the generated-vs-hand-written boundary, package doc comments, and where package-level errors are declared. Self-contained — usable without the parent `SKILL.md` body already in context. This is the standard a reviewer checks a generated service against; the sibling skills that actually write the *contents* of each file (`go-domain-model`, `go-service-layer`, `go-repository-pattern`, `go-chi-handler`, `go-migration`, `go-openapi-codegen`) are cited at each section, not restated.

---

## `cmd/server/main.go` — the composition root

**Belongs here:** `main()`; config load; construction calls (`New*` constructors from every layer); wiring the pool, router, and `http.Server`; signal handling and graceful shutdown orchestration (see `go-service-skeleton`). If the wiring grows past a single readable `main()`, split flag/env parsing into `main.go` and dependency construction into a sibling `wire.go` — never more granular than that two-file split.

**Must never appear here:** any conditional business logic — an `if` that decides something about the domain, not just about whether a dependency is present. Robert C. Martin's framing (Clean Architecture, Ch. 28): `main` is not a ring of the architecture at all, it is a *plugin to* the architecture — the outermost, dirtiest detail, responsible only for instantiating and wiring dependencies before handing control to the layer it constructed. High-level policy has no knowledge `main` exists.

**Naming:** package `main`. No package doc comment convention applies (Go doesn't render one for `main`).

---

## `internal/domain/*.go` — the centre

**Belongs here:** one file per Aggregate/Value Object/domain concept, named after the *concept*, not the pattern — `dataasset.go`, `sensitivity.go`, never `models.go`/`types.go`/`entities.go`. Domain Events (`events.go`), sentinel errors (`errors.go` — see "Where Package-Level Errors Live" below), and consumer-defined ports (`ports.go`) are the three conventional non-concept files every domain package carries. Full content of each: `go-domain-model`.

**Must never appear here:**
- Any import outside stdlib, `github.com/google/uuid`, and `time` — no `pgx`, `chi`, `kgo`, OpenTelemetry, or any other layer's package. This is the Dependency Rule's tightest boundary and the one the fitness function checks first (see `references/architecture-fitness-functions.md`).
- Persistence or transport struct tags (`json:"..."`, `db:"..."`) on a domain type. A domain type that carries a `json` tag has quietly become a DTO; the mapping to/from a wire or storage shape belongs to the layer that owns that concern (`go-repository-pattern`'s Reconstitute mapping, `go-chi-handler`'s request/response DTOs).
- An HTTP status code, a SQL fragment, or a topic name, anywhere.

---

## `internal/application/{commands,queries}/*.go`

**Belongs here:** one file per Command or Query handler, named after the use case — `classify_data_asset.go`, not `handler.go`. Use-case orchestration: validate against domain rules, call the Aggregate, call consumer-defined ports. An `errors.go` per subpackage *only when* the subpackage has a genuine application-level failure condition not owned by any single Aggregate (most don't — see "Where Package-Level Errors Live").

**Must never appear here:** a concrete infrastructure type as a struct field (`*pgxpool.Pool`, `*kgo.Client`) — constructors accept the domain port, never the concrete implementation. No `net/http` type (`*http.Request`, `http.ResponseWriter`) reaches this layer; the boundary-crossing data is a plain Command/Query struct (Clean Architecture Ch. 22's boundary-crossing-DTO rule — see `go-service-layer`).

---

## `internal/infrastructure/{postgres,messaging,telemetry,secrets}/*.go`

**Belongs here:** one subpackage per external system, named after the *system*, not the pattern — `postgres`, never `db` or `repo`. Port implementations (repositories, publishers, the telemetry/secrets adapters), each carrying the compile-time `var _ domain.X = (*Y)(nil)` assertion next to its struct definition. Infra-to-domain error translation happens inline, in the same method that produced the error — not in a separate file (see "Where Package-Level Errors Live").

**Must never appear here:** business rules — any `if` that decides something about the domain rather than about how to talk to Postgres/Kafka belongs one layer in. No `handlers` package ever imports `infrastructure` directly; the only place a concrete infrastructure type is named is `cmd/server/main.go`'s wiring.

---

## `internal/handlers/{http,events}/*.go`

**Belongs here:** one file per route group or event type; `router.go` for route registration; `errors.go` for the response-mapping switch (`writeDomainError`) **and** the transport-layer structural-validation error type (see below); request/response DTOs, distinct from domain types. Full content: `go-chi-handler`.

**Must never appear here:** an infrastructure internal (no `*pgxpool.Pool` field on a handler struct — everything the handler needs is wired through the application layer it calls); business rules (structural/shape validation only — see `go-chi-handler`'s "Structural Validation at the Boundary").

---

## `internal/pkg/<name>/` — data-agnostic shared plumbing

A narrow, deliberate exception to "no shared `pkg/`": reserved for genuinely **data-agnostic** code with zero domain knowledge — a generic worker pool (`internal/pkg/concurrency/pool.go`, see `go-concurrency-patterns`), a fan-in helper, `Page[T]`/`Result[T]` wrappers (see `references/composition-and-generics.md`). The test that separates this from the forbidden "fat `pkg/` of shared code between services" anti-pattern: `internal/pkg/` never crosses a *service* boundary — `internal/` itself is unimportable outside the module by Go toolchain enforcement, and nothing placed here ever knows what a `DataAsset` is. A `Page[T]` is exactly as reusable inside this service as it would be in any other; a shared `DataAsset` struct would not be. If a file under `internal/pkg/` ever imports `internal/domain`, it no longer belongs there — move it into the layer that actually owns that domain knowledge.

---

## `migrations/` and `api/`

Owned by `go-migration` and `api-contract-design`/`go-openapi-codegen` respectively — not restated here. This skill's only concern with them is their position in the tree (siblings of `internal/`, not nested under it) and that `api/openapi.yaml` is the input `go-openapi-codegen` generates from, never an output.

---

## The Generated-vs-Hand-Written Boundary

Every generator this plugin's Go skills use follows the same three rules, so a reader can identify generated code on sight without checking a manifest:

1. **Naming.** A generated file's name identifies its generator: `openapi_gen.go` (oapi-codegen output — `go-openapi-codegen`), `<iface>_moq.go` (moq-generated test doubles — `mock-generation`). The `//go:generate` directive that produces a generated file lives in a small, hand-written sibling file (`gen.go`) — never inside the generated file itself, since that file is about to be overwritten.
2. **Co-location, not segregation.** A generated file lives in the same package as the hand-written code that consumes it — `internal/handlers/http/openapi_gen.go` sits beside `internal/handlers/http/router.go`. There is no top-level `generated/` directory anywhere in the tree; segregating generated code by directory instead of by filename makes it easy to `.gitignore` by accident (an anti-pattern `go-openapi-codegen` already names explicitly) and breaks the "read the package, see everything it depends on" property the layout otherwise gives a reviewer.
3. **Never hand-edited, and mechanically enforced.** Every generated file carries a `DO NOT EDIT` header. The actual enforcement is CI, not the header text or a manual review step: `make ci` runs `go generate ./...` followed by `git diff --exit-code` (`go-makefile`) — a generated file that is stale relative to its source (the OpenAPI spec, the interface it mocks) fails the build. A hand-edit that happens to still match the current spec/interface will *not* be caught by this check (see `references/architecture-fitness-functions.md`'s honest-limitations discussion for the same class of gap) — the header and the review discipline it signals are the second line of defence, not the first.

---

## Package-Level Doc Comments

Every package gets a doc comment beginning `// Package <name> ...` — a complete sentence, the package's front door for `go doc` and pkg.go.dev-style discovery (Donovan & Kernighan, *The Go Programming Language*, Ch. 10). For a multi-file package, the comment lives in a dedicated `doc.go` containing nothing but the `package` clause and the comment above it; for a single-file package, it sits directly above that file's `package` line.

```go
// Package domain contains the DataAsset aggregate, its value objects, domain
// events, and the ports the application layer depends on. It imports nothing
// outside the standard library, uuid, and time.
package domain
```

The import-constraint sentence is not decorative. Stating it in the comment gives a human reviewer the same signal the fitness function checks mechanically — a `domain` package doc comment that no longer says this after someone adds an import is itself a code-review smell, independent of whether `make arch` has been run yet.

---

## Where Package-Level Errors Live

**Scope note:** this section states *where* each kind of error is declared, per layer — never *how* it is constructed, wrapped, chained, or inspected. Wrapping with `%w`, `errors.Is`/`errors.As`, the sentinel-vs-typed-error selection criteria, validation-error aggregation, and the panic/recover boundary are all `go-error-handling`'s standard, cited here only at the hand-off point.

| Error kind | Lives in | Why here, not elsewhere |
|---|---|---|
| Domain sentinel errors (`ErrNotFound`, `ErrForbidden`, `ErrConcurrentModification`, …) | `internal/domain/errors.go`, package `domain`, one `var (...)` block | One file per domain package — not one file per Aggregate — so a reader sees that package's entire failure vocabulary in a single place. These are business-rule conditions; they belong where the business rules live. |
| Application-level sentinels (a condition not owned by any single Aggregate — e.g. an idempotency-key conflict spanning a use case) | `internal/application/commands/errors.go` / `.../queries/errors.go`, only when a genuine such condition exists | Most application subpackages need none of these — most failure conditions are already domain conditions. A near-empty or absent `errors.go` here is expected, not a gap. |
| Infrastructure error translation (`pgx.ErrNoRows` → `domain.ErrNotFound`, a broker publish failure → a domain-vocabulary error) | Inline, at the exact call site that produced the error — no dedicated `errors.go` in any `infrastructure/*` subpackage | Infrastructure does not own a failure vocabulary of its own; it only ever translates into the vocabulary the domain already declared. A dedicated infrastructure `errors.go` would wrongly imply otherwise. See `go-repository-pattern`'s `FindByID` for the worked translation. |
| Transport-layer structural error types (`ValidationError{Field, Message}` — request-shape validation detail) | `internal/handlers/http/errors.go`, alongside `writeError`/`writeDomainError` | This type's only reason to exist is serializing into `ErrorResponse.Error.Fields` on the wire — a transport concern. It must never be imported by `internal/domain` or `internal/application`; a domain or application package importing a `handlers/http` type is itself a Dependency Rule violation running the wrong direction. |

---

## Reviewer Checklist for This Standard

A file placed anywhere in the tree above should answer three questions before it is considered correctly located:

1. **What does its import list say?** If it imports something the table in `SKILL.md`'s "The Four Layers" forbids for that directory, it is in the wrong place regardless of what the file is named.
2. **Does its name describe a domain concept or a generic pattern?** `dataasset.go` passes; `models.go`, `helpers.go`, `utils.go`, `common.go` all fail — see `SKILL.md`'s "No junk packages" anti-pattern.
3. **If it is generated, does it carry the naming suffix and the DO-NOT-EDIT header, and is it committed (not gitignored)?** All three, or it is not following this standard.
