# Skill: implement/multi-repo-structure

## Purpose
Produce the Multi-Repo Structure document — the per-repository layout standards that every bounded context repository must follow. Complements the bounded context map by specifying what goes where inside each repo, ensuring every engineer can navigate any repo without a guide.

## Inputs
- `artifacts/design/bounded-contexts.md`
- `artifacts/design/multi-repo-map.md`
- `artifacts/implement/standards/coding-standards.md`
- `sdlc-config.json`

## Output
**File:** `artifacts/implement/standards/repo-structure.md`
**Registers in manifest:** yes

## Artifact Template

```markdown
# Multi-Repo Structure

**Product:** {product_name}
**Phase:** Implement
**Artifact:** Multi-Repo Structure
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Repository Taxonomy

| Repo type | Naming pattern | Contents |
|-----------|---------------|---------|
| Domain service | `{product}-{bc-name}` | Go service; domain model; API; migrations; Helm chart |
| Platform | `{product}-platform` | OpenTofu IaC; Helm chart templates; ArgoCD apps; runbooks |
| Contracts | `{product}-contracts` | Event schemas (JSON Schema); OpenAPI specs; changelog |
| Docs | `{product}-docs` | ADRs; architecture diagrams; onboarding guides |

---

## Domain Service Repository Layout

```
{product}-{bc-name}/
├── .github/
│   └── workflows/
│       ├── ci.yml                  # Build + test + lint + scan
│       └── release.yml             # Tag → image push → Helm values bump
├── cmd/
│   └── server/
│       └── main.go                 # Wire-up only
├── internal/
│   ├── api/
│   │   ├── handlers/
│   │   │   ├── {resource}_handler.go
│   │   │   └── {resource}_handler_test.go
│   │   ├── middleware/
│   │   │   ├── auth.go             # JWT validation
│   │   │   ├── tenancy.go          # tenant_id extraction and enforcement
│   │   │   ├── tracing.go          # OpenTelemetry span injection
│   │   │   └── logging.go          # Request/response structured logging
│   │   └── router.go               # chi route registration
│   ├── application/
│   │   ├── commands/
│   │   │   └── {command_name}.go   # One file per command handler
│   │   ├── queries/
│   │   │   └── {query_name}.go     # One file per query handler
│   │   └── eventhandlers/
│   │       └── {event_name}.go     # One file per event handler
│   ├── domain/
│   │   ├── aggregates/
│   │   │   └── {aggregate}.go      # Aggregate struct + methods + invariant enforcement
│   │   ├── valueobjects/
│   │   │   └── {value_object}.go   # Immutable value types
│   │   ├── events/
│   │   │   └── {event_name}.go     # Domain event types (structs)
│   │   ├── services/
│   │   │   └── {service}.go        # Domain service interfaces + implementations
│   │   └── errors.go               # Sentinel domain errors
│   └── infrastructure/
│       ├── persistence/
│       │   ├── {aggregate}_repo.go # Repository implementation
│       │   └── outbox/
│       │       └── outbox_repo.go  # Outbox table write
│       ├── readmodels/
│       │   └── {model}_repo.go     # Read model repository
│       └── messaging/
│           ├── consumer/
│           │   └── consumer.go     # Redpanda consumer setup
│           └── publisher/
│               └── outbox_relay.go # Polls outbox; publishes to Redpanda
├── migrations/
│   ├── 000001_create_schema.up.sql
│   ├── 000001_create_schema.down.sql
│   └── ...                         # Numbered; sequential; never edited after merge
├── contracts/                      # Pinned copy of consumed event schemas (from contracts repo)
│   └── {EventName}.v1.schema.json
├── helm/
│   ├── Chart.yaml
│   ├── values.yaml                 # Default values
│   ├── values-dev.yaml
│   ├── values-staging.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── serviceaccount.yaml
│       ├── configmap.yaml
│       ├── externalsecret.yaml
│       ├── hpa.yaml
│       └── networkpolicy.yaml
├── CLAUDE.md                       # BC-specific standards extending factory CLAUDE.md
├── Makefile                        # Targets: build, test, lint, migrate, run
├── go.mod
├── go.sum
└── .golangci.yml                   # Linting configuration
```

---

## Platform Repository Layout

```
{product}-platform/
├── infra/
│   ├── modules/
│   │   ├── kubernetes/             # K8s cluster (EKS/GKE/AKS or k3s)
│   │   ├── postgresql/             # PostgreSQL per-tenant provisioning
│   │   ├── redpanda/               # Redpanda cluster
│   │   └── elasticsearch/          # Elasticsearch cluster
│   ├── tenants/
│   │   └── {tenant-id}/
│   │       └── main.tf             # Per-tenant infrastructure instantiation
│   └── shared/
│       └── main.tf                 # Shared infra (observability, networking)
├── helm/
│   ├── argocd-apps/                # ArgoCD Application manifests
│   └── base-values/                # Shared Helm value defaults
├── grafana/
│   └── dashboards/                 # Dashboard JSON files (as code)
├── runbooks/                       # Operational runbooks (Markdown)
├── scripts/
│   └── tenant-provision.sh         # Tenant provisioning automation
└── .github/
    └── workflows/
        └── infra-plan.yml          # terraform plan on PR; apply on main merge
```

---

## Contracts Repository Layout

```
{product}-contracts/
├── events/
│   ├── FileProcessed.v1.schema.json
│   ├── EntitiesExtracted.v1.schema.json
│   └── ...
├── api/
│   ├── file-domain-api.v1.yaml     # OpenAPI 3.1 specs
│   └── ...
├── CHANGELOG.md                    # Schema version history
└── .github/
    └── workflows/
        └── validate-schemas.yml    # JSON Schema validation on PR
```

---

## Per-Repo CLAUDE.md Convention

Every domain service repository contains a `CLAUDE.md` that:
1. Imports the factory CLAUDE.md by reference: `# Extends: {factory-root}/CLAUDE.md`
2. Adds the bounded context's ubiquitous language (from `artifacts/design/language/{bc-name}.md`)
3. Names the BC's aggregates, events, and commands for quick reference
4. Notes any BC-specific coding deviations (approved exceptions to factory standards)

---

## Migration Conventions

- Files: `{NNNNNN}_{description}.up.sql` and `{NNNNNN}_{description}.down.sql`
- Sequential 6-digit numbering: `000001`, `000002`
- **Never edit a migration that has been merged to main** — write a new migration instead
- Every `up` migration has a `down` counterpart for rollback
- Tool: `golang-migrate/migrate`

---

## Makefile Targets (required in all domain services)

| Target | Action |
|--------|--------|
| `make build` | `go build ./...` |
| `make test` | `go test -race ./...` |
| `make test-integration` | Run integration tests (requires Docker for testcontainers) |
| `make lint` | `golangci-lint run` |
| `make migrate-up` | Apply pending migrations (requires DB_URL env var) |
| `make migrate-down` | Roll back last migration |
| `make run` | Start the service locally (requires local config) |
| `make generate` | Run `go generate ./...` (mocks, OpenAPI client code if any) |
```

## Quality Checks
- [ ] Domain service layout matches hexagonal architecture from coding-standards.md
- [ ] Platform repo layout covers infra, Helm, runbooks, and dashboards-as-code
- [ ] Contracts repo is distinct — no implementation code
- [ ] Migration conventions include the "never edit merged migration" rule
- [ ] Per-repo CLAUDE.md convention is specified
- [ ] Makefile targets are standardised across all service repos
