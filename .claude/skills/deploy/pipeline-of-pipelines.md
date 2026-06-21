# Skill: deploy/pipeline-of-pipelines

## Purpose
Produce the Pipeline Orchestration document — the specification of how individual service CI/CD pipelines are coordinated for a full-platform release. Defines the dependency order between services, the cross-service release gate, and the rollout sequence for a multi-BC product.

## Inputs
- `artifacts/design/bounded-contexts.md` (dependency relationships)
- `artifacts/design/architecture/integration-design.md` (event dependencies)
- `artifacts/deploy/ci/` (all service CI pipelines)
- `artifacts/deploy/cd/` (all service CD pipelines)

## Output
**File:** `artifacts/deploy/orchestration.md`
**Registers in manifest:** yes

## Orchestration Rules (enforced)
- Services with event dependencies have deployment order constraints (producer before consumer for schema changes).
- Platform infrastructure (Redpanda, PostgreSQL cluster, Elasticsearch) deploys before application services.
- Shared Kernel (event schemas) deploys before any service that consumes those schemas.
- A failing service deployment blocks downstream dependents.

## Artifact Template

```markdown
# Pipeline Orchestration
**Product:** {product_name}
**Phase:** Deploy
**Artifact:** Pipeline Orchestration
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Deployment Order

Services must deploy in this sequence. A failure at any stage blocks subsequent stages.

### Stage 0: Infrastructure (automated via OpenTofu + ArgoCD)
- PostgreSQL clusters (per tenant — provisioned by tenant onboarding automation, not release pipeline)
- Redpanda cluster
- Elasticsearch cluster
- Kubernetes namespaces and NetworkPolicies
- External Secrets Operator + Vault connection

**How:** OpenTofu apply via platform IaC; ArgoCD syncs Kubernetes resources
**Gate:** All infrastructure health checks pass

---

### Stage 1: Shared Kernel (event schemas)
- Repo: `{product-codename}-shared-kernel`
- Contents: Event schema JSON files, shared Go types (contracts repo)
- Deployment: Published as GitHub Package / versioned file release

**Gate:** All consumer contract tests pass against new schemas in CI

---

### Stage 2: Core Services (no incoming domain events)
Parallel deployment (no dependency on each other):
- `{product-codename}-audit-domain` — no event consumers; pure sink
- `{product-codename}-identity-domain` — authentication service; others depend on it

**Gate:** Readiness probes healthy; smoke test passes

---

### Stage 3: Domain Services (event producers)
Parallel deployment after Stage 2:
- `{product-codename}-file-domain` — produces FileProcessed, ScanCompleted events
- `{product-codename}-compliance-domain` — produces FindingRaised events

**Gate:** Readiness probes healthy; events flowing to Redpanda topics (Redpanda consumer lag = 0 baseline)

---

### Stage 4: Domain Services (event consumers)
After Stage 3 producers are healthy:
- `{product-codename}-entity-domain` — consumes FileProcessed; produces EntitiesExtracted
- `{product-codename}-graph-domain` — consumes EntitiesExtracted; updates lineage graph

**Gate:** Consumer groups caught up (lag = 0); readiness probes healthy

---

### Stage 5: API Gateway / BFF
After all domain services are healthy:
- `{product-codename}-api-gateway`

**Gate:** E2E smoke test passes (register storage location → scan initiation → response 201)

---

## Cross-Service Release Gate

Before any Stage 3+ service can deploy to production, the following must be verified:

```
☐ All Stage 1 and Stage 2 services are healthy in production
☐ Shared Kernel schemas deployed and no consumer contract test failures
☐ Security gate passed (security-gate hook)
☐ Compliance gate passed (compliance-gate hook)
☐ Canary or blue-green plan active for this release (see canary-plan.md)
```

---

## Rollback Order

Rollback is the reverse of deployment order:
1. API Gateway → rollback (revert values.yaml commit)
2. Consumer services → rollback
3. Producer services → rollback
4. Core services → rollback (only if producer rollback insufficient)
5. Shared Kernel → rollback (only if schema change was the cause)
6. Infrastructure → NOT rolled back automatically; requires platform engineering decision

---

## Pipeline Coordination Tool

GitHub Actions `workflow_dispatch` with `platform-release` workflow in `{product-codename}-platform` repo:
```yaml
# .github/workflows/platform-release.yml
# Orchestrates cross-service release
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version (e.g. v1.2.0)'
        required: true
jobs:
  release:
    uses: ./.github/workflows/pipeline-of-pipelines.yml
    with:
      version: ${{ inputs.version }}
    secrets: inherit
```
```

## Quality Checks
- [ ] Infrastructure deploys before application services
- [ ] Shared Kernel deploys before consumer services
- [ ] Event producers deploy before event consumers
- [ ] Each stage has a gate (health check or contract test)
- [ ] Rollback order is the reverse of deployment order
- [ ] Cross-service release gate checklist is defined
