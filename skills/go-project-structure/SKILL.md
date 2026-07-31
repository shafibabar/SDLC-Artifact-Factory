---
name: go-project-structure
description: >
  Teaches the canonical Go service project layout for this plugin — the four-layer
  Clean/Hexagonal architecture (handlers, application, domain, infrastructure)
  mapped explicitly onto Clean Architecture's Dependency Rule and its four rings
  (Entities, Use Cases, Interface Adapters, Frameworks & Drivers), inward-only
  dependencies verified by a fitness function, why the generic per-service
  skeleton satisfies Screaming Architecture one level up, idiomatic package
  naming and package doc comments, the minimalist-interface principle
  (interfaces defined by the consumer, not the producer, with compile-time
  var _ Interface = (*T)(nil) satisfaction checks), composition over
  inheritance, where generics belong, the generated-vs-hand-written code
  boundary, and where package-level sentinel/typed errors are declared per
  layer. This is the skeleton every Go service is generated into. The full
  per-package standard is in references/package-layout-standard.md, the
  fitness-function mechanics in references/architecture-fitness-functions.md,
  and composition/generics worked examples in
  references/composition-and-generics.md. Used by the backend-engineer during
  Implement.
version: 2.2.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, project-structure, clean-architecture, solid, interfaces, generics]
related: [go-error-handling, go-concurrency-patterns, go-unit-test, go-makefile, go-openapi-codegen, mock-generation, go-domain-model, go-repository-pattern, go-service-layer, go-chi-handler, component-diagram]
---

# Go Project Structure

## Purpose

Every Go service in this plugin uses the same layered layout so any service is navigable by anyone who has seen one. The layout enforces the Dependency Rule: **dependencies point inward only.** The domain layer at the centre knows nothing of HTTP, SQL, or Kafka — this is what makes the domain testable in isolation and the infrastructure swappable.

This skill produces the directory skeleton, the package conventions, and the standard each generated file must meet. It does not implement the layers' contents — `go-domain-model`, `go-repository-pattern`, `go-service-layer`, and `go-chi-handler` do that, against the standard this skill sets.

---

## The Four Layers and the Dependency Rule

| Layer | May import | Must NOT import |
|---|---|---|
| `domain` | stdlib, `uuid`, `time` only | Any other layer; any framework; pgx; chi; OTel |
| `application` | `domain` | `handlers`; concrete `infrastructure` (only domain ports) |
| `infrastructure` | `domain` (to implement its ports) | `handlers`; `application` |
| `handlers` | `application`, `domain` (types) | `infrastructure` internals (wired in `main`) |

This is Robert C. Martin's **Dependency Rule** (Clean Architecture, Ch. 22): source code dependencies point only inward, toward higher-level policy. It is broader than the Dependency Inversion Principle alone — DIP (a consumer-defined port an implementation satisfies structurally) is the *mechanism* this plugin uses at the domain/infrastructure crossing; the Rule is the architecture-wide invariant governing every crossing, including things DIP alone doesn't reach (data formats never leaking outward-to-inward, `main` sitting outside every ring as a plugin *to* the architecture — see `references/package-layout-standard.md`'s composition-root section).

The four layers map onto Clean Architecture's four rings: `domain` = Entities, `application` = Use Cases, `infrastructure` + `handlers` = Interface Adapters merged with Frameworks & Drivers (this plugin deliberately collapses those last two rings into one Go package per external system — a reasonable simplification per Martin's own note that the split is often collapsed in practice, not a missed ring).

**Enforced mechanically, not just by review.** `go-makefile`'s `arch` target runs a fitness function — an automated check guarding this table, not reviewer vigilance — paired with the `pre-phase-advance`/`methodology-review` governance hook for defence in depth. Full mechanics, exact script, and its honest limitations (what it catches, what it doesn't): `references/architecture-fitness-functions.md`.

---

## Canonical Directory Layout

```
classification-service/
├── cmd/server/main.go                      # composition root: wires everything, owns lifecycle
├── internal/
│   ├── domain/            # dataasset.go, sensitivity.go, events.go, errors.go, ports.go
│   ├── application/{commands,queries}/     # one file per Command/Query handler
│   ├── infrastructure/{postgres,messaging,telemetry,secrets}/
│   ├── handlers/{http,events}/
│   └── pkg/<name>/        # data-agnostic generic plumbing only — see references/
├── migrations/             # SQL migrations (go-migration)
├── api/openapi.yaml        # the contract (go-openapi-codegen)
├── Dockerfile · Makefile · go.mod · go.sum
```

`internal/` prevents any code outside this module from importing the service's guts — enforced by the Go toolchain, not convention. **Full per-directory standard — precisely what belongs in each package, what must never appear there, and the generated-vs-hand-written boundary: `references/package-layout-standard.md`.**

**Why this generic skeleton is correct, not a Screaming Architecture violation.** Martin's Screaming Architecture (Ch. 21) argues a codebase's top-level structure should announce its business domain, not its framework. This identical `cmd/`+`internal/{domain,application,infrastructure,handlers}` tree for every service can look like the opposite — it isn't: the domain screams one level up, at the service name chosen in `container-diagram` (`classification-service`, not `generic-crud-service`), and one level down, in the file names inside `domain/` itself (`dataasset.go`, not `entity.go`). This skeleton is architecture's plumbing; it is supposed to be boringly identical everywhere, precisely so the domain names are free to differ everywhere.

---

## Package Naming

| Rule | Good | Bad |
|---|---|---|
| Short, lower-case, no underscores | `postgres`, `messaging` | `postgres_repo`, `messagingUtils` |
| Name the thing, not the pattern | `domain`, `commands` | `models`, `helpers`, `utils`, `common` |
| Package name = directory name | `package postgres` in `postgres/` | mismatched names |
| No stutter | `domain.DataAsset` | `dataasset.DataAssetModel` |

There is no `utils` or `common` package — a "utilities" package signals something lacks a home. Every package additionally carries a `// Package <name> ...` doc comment (Donovan & Kernighan, Ch. 10) — the front door for `go doc`/pkg.go.dev discovery; full convention and worked example: `references/package-layout-standard.md`.

---

## Minimalist Interfaces (consumer-defined)

The Go proverb governs every interface: **"the bigger the interface, the weaker the abstraction."** Interfaces are small (≤3 methods) and **defined where they are consumed, not where they are implemented** — this is interface pollution's exact inverse (Harsanyi, *100 Go Mistakes*, Ch. 2), and the reason `internal/domain/ports.go` declares the port the `infrastructure` layer must satisfy, never the other way round:

```go
// internal/domain/ports.go — defined by the CONSUMER
type DataAssetRepository interface {
    FindByID(ctx context.Context, id uuid.UUID) (*DataAsset, error)
    Save(ctx context.Context, a *DataAsset) error
}
```

```go
// internal/infrastructure/postgres/dataasset_repo.go — the IMPLEMENTATION
// Does NOT declare the interface; satisfies it structurally (Go's implicit,
// structural typing — Donovan & Kernighan, Ch. 7).
type DataAssetRepo struct{ pool *pgxpool.Pool }

// Compile-time assertion: a renamed/re-typed method fails to compile HERE,
// not at some unrelated call site elsewhere in the application layer.
var _ domain.DataAssetRepository = (*DataAssetRepo)(nil)
```

The `var _ Interface = (*T)(nil)` line is zero-cost (the blank identifier discards the value) — add it next to every port implementation in the roster, not just this one.

---

## Composition, Generics, and Where the Code Lives

Go has no inheritance; reuse is by **embedding** and small focused types (decorator-via-embedded-interface is the canonical shape). Generics (`[T any]`) belong in data-agnostic containers/transformations (`Page[T]`, a generic worker pool) — never to make the domain abstract; a `Repository[T any]` god-interface recreates the wide abstraction the minimalist-interface rule forbids. Both, plus exactly which package this code lives in (`internal/pkg/<name>/`, never `internal/domain`): full worked examples in `references/composition-and-generics.md`.

---

## Where Package-Level Errors Live

This skill states only **where** each kind of error is declared per layer — never how it is constructed, wrapped, or inspected (`go-error-handling` owns that). Domain sentinel errors live in `internal/domain/errors.go`; application-level sentinels (rare) in `internal/application/{commands,queries}/errors.go`; infrastructure translation happens inline at the call site, never in its own file; transport-layer structural validation types (`ValidationError{Field, Message}`) live in `internal/handlers/http/errors.go`. Full table with rationale per row: `references/package-layout-standard.md`.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Domain purity | `domain` imports only stdlib/uuid/time | Any framework/infra/other-layer import | `make arch` (`references/architecture-fitness-functions.md`) — green |
| Application boundary | `application` imports `domain` only | Concrete infra or `handlers` import | `make arch` |
| Infrastructure boundary | `infrastructure` never imports `handlers` | Upward import present | `make arch` |
| Composition root purity | `main.go` only wires; no business decisions | An `if` deciding something about the domain | Read `cmd/server/main.go`; every branch should be about a dependency being present, never about business state |
| Interface ownership | Ports declared in `domain`/`application` | Interface declared beside its implementation | Grep the `interface` keyword's package location against `SKILL.md`'s layer table |
| Small interfaces | ≤3 methods, single-responsibility | Wide "manager"/"service" interfaces | Read `ports.go`; count methods per interface |
| Compile-time assertions present | `var _ domain.X = (*Y)(nil)` beside every port implementation | A port implementation with no assertion | `grep -rn "var _ domain\." internal/infrastructure` — one hit per implementation |
| No junk packages | No `utils`/`common`/`helpers`/`models` | A grab-bag directory | `find internal -type d \( -name utils -o -name common -o -name helpers \)` — empty |
| No stutter | `domain.DataAsset` | `dataasset.DataAssetModel` | Read exported identifiers against their package name |
| Package doc comments | Every package has `// Package <name> ...` | Missing or absent doc comment | `go doc ./...` for each package resolves to a real sentence, not empty |
| Generated/hand-written separation | Generator-suffixed name (`_gen.go`/`_moq.go`), DO-NOT-EDIT header, committed | Hand-edited generated file, or generated code `.gitignore`d | `make ci` (`go generate ./... && git diff --exit-code`) is green |
| Error placement | Sentinels/typed errors located per `references/package-layout-standard.md`'s table | A transport error type imported by `domain`/`application` | `go list -deps ./internal/domain/... ./internal/application/...` excludes `internal/handlers` |
| Generics used correctly | Data-agnostic plumbing only, in `internal/pkg/` | `Repository[T any]` god-interface, or `internal/pkg/` importing `internal/domain` | Read `internal/pkg/*` imports; read repository port count (one per Aggregate, not one generic) |
| `internal/` boundary held | No code outside the module imports service internals | N/A — enforced by the Go toolchain itself | Attempting the import fails to compile from outside the module |

---

## Anti-Patterns

- **Layer-skipping imports** — a handler reaching into `infrastructure/postgres` directly. No exceptions; wiring happens only in the composition root.
- **Producer-defined interfaces** — `postgres` declaring `DataAssetRepository` next to its implementation inverts ownership; the abstraction ends up shaped by the database, not the use case.
- **`utils`/`common`/`helpers` packages** — a landfill every package imports and no one owns.
- **Package-by-pattern** — `models/`, `interfaces/`, `impl/` scatter one concept across the tree. Package by layer and domain concept.
- **A fat cross-service `pkg/`** — sharing domain types across services couples Bounded Contexts at the source level; share contracts, not structs. (`internal/pkg/` inside one service is a different, permitted thing — see above.)
- **Business logic in `main.go`** — the composition root wires and starts; the moment it decides anything, that decision is untestable without booting the process.
- **Editing a generated file "just this once"** — invisible after the next regeneration; `make ci`'s freshness check will not catch a hand-edit that still matches the current spec, only a drifted one.
- **A dedicated `infrastructure/errors.go`** — implies infrastructure owns a failure vocabulary; it only ever translates into the domain's.

---

## 12-Factor Kubernetes Scheduling Contract

A Go service written against the layout in this skill is correct only if it also complies with the five 12-factor principles that map directly to Kubernetes scheduling primitives. A developer can follow every rule above and still produce a service that is non-compliant with the platform. Verify each item before the Implement phase gate:

| # | Requirement | Kubernetes Primitive | Violation Example |
|---|---|---|---|
| 1 | **Config from env vars only** — no config files baked into the image; all addresses, URLs, feature flags, and tuneable parameters injected at deploy time | `ConfigMap`/`Secret` env-var projection | Reading a `config.yaml` at startup from inside the image |
| 2 | **Backing services as attached resources** — database URL, broker address, cache address are env vars; swapping dev-postgres for prod-postgres is a config change, not a code change | Kubernetes `Service` DNS (`<svc>.<ns>.svc.cluster.local`) as the URL source | Hardcoded `postgres://db.internal:5432/mydb` in source |
| 3 | **Logs as streams** — write ALL logs to `stdout`; write NOTHING to files; the Kubernetes logging pipeline captures `stdout` automatically via the kubelet | kubelet log capture → DaemonSet agent (Fluent Bit) → Loki | Writing to `/var/log/app.log` or any named file path |
| 4 | **No local disk state** — the pod's local filesystem is ephemeral and is lost on eviction, crash, or reschedule; data that must survive a pod restart goes to PostgreSQL, Redpanda, or a mounted `PersistentVolume` | `PersistentVolumeClaim` for durable storage; PostgreSQL/Redpanda for structured/event data | Storing uploaded files, session tokens, or computed results in a local directory path |
| 5 | **Stateless processes** — N replicas can run in parallel; any replica handles any request; no per-process in-memory state is shared between replicas | `Deployment` with `replicas: N`; Horizontal Pod Autoscaler | Keeping session tokens, computed state, or in-process caches that are not in an external store |

**Mechanical verification:**

```bash
# Rule 1 — no config-file reads at startup inside the image
grep -rn "os\.ReadFile\|ioutil\.ReadFile\|os\.Open" cmd/ internal/ | grep -v "_test.go"
# Every hit that reads a config file at startup is a violation; reading migration SQL is permitted.

# Rule 3 — no log file writers
grep -rn 'log\.SetOutput\|os\.Create\|os\.OpenFile\|bufio\.NewWriter' internal/ | grep -v "_test.go"
# Any hit that opens a file path for log output is a violation.

# Rule 1 cross-check — all config values come from env
grep -rn 'os\.Getenv\|envconfig\|env\.Parse' cmd/server/main.go
# Every external address, URL, and flag should trace to one of these in main.go.
```

Full rationale per rule, compliant Go patterns for each, detection recipes, and the ConfigMap/Secret injection examples that wire these at deploy time: `references/twelve-factor-kubernetes.md`.

---

## Output Format

Directory skeleton and `go.mod`, produced against the standard in `references/package-layout-standard.md`:

```
cmd/server/main.go
internal/domain/ports.go
internal/{domain,application,infrastructure,handlers}/  (package dirs, each with a doc comment)
go.mod
```

Full per-package standard: `references/package-layout-standard.md`. Fitness-function mechanics: `references/architecture-fitness-functions.md`. Composition/generics worked examples: `references/composition-and-generics.md`.
