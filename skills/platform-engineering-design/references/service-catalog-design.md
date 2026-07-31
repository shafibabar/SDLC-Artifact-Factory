# Service Catalog Design

A service catalog is the platform's primary discoverability surface: every service in the organisation, its owner, its dependencies, its SLO status, its documentation, and its deployment pipeline — queryable in one place. It is also the gateway to the golden path: the service catalog is where a developer goes to create a new service using the platform's standard template.

This guide covers what to include in each service record, when to graduate from a lightweight alternative to Backstage, and how the catalog relates to `sdlc-config.json`.

---

## When to Introduce a Service Catalog

**Rule:** Introduce a service catalog when service count exceeds 20.

| Service Count | Appropriate Catalog |
|---|---|
| < 10 | A section of the main `README.md` |
| 10–20 | A dedicated `services.md` or shared wiki page; a Google Sheet is acceptable |
| 20–50 | A structured catalog (YAML files in a `catalog/` directory in the monorepo, or a lightweight tool) |
| > 50 | Backstage or equivalent; the lack of a catalog creates real coordination failures at this scale |

At fewer than 20 services, a spreadsheet with the right columns is a viable TVP for the service catalog. Do not introduce Backstage before you need it — running Backstage requires a Node.js server, a PostgreSQL database, and active curation. That overhead is not worthwhile until the service count makes it necessary.

---

## Service Record Schema

Every service in the catalog has a record with these fields. Fields marked (required) must be present for a service to be listed; others are populated progressively.

```yaml
# catalog/services/invoice-processor.yaml

# Identity
name: invoice-processor                         # (required) matches repository name
display_name: Invoice Processor                 # (required) human-readable name
description: >                                  # (required) one paragraph, plain English
  Processes incoming invoice events from the billing domain, validates them
  against the invoice schema, and emits InvoiceValidated or InvoiceRejected
  domain events to Redpanda.
owner: billing-team                             # (required) team Slack handle or GitHub team name

# Codebase
repository: https://github.com/org/invoice-processor  # (required)
language: go                                    # (required)
framework: net/http + chi
tech_stack: ["postgresql", "redpanda", "opentelemetry"]

# Lifecycle
phase: implement                                # current SDLC phase
created: 2026-03-15
last_deploy: 2026-07-30                         # auto-populated by CD pipeline

# Operations
runbook: https://wiki.org/runbooks/invoice-processor
on_call_rotation: billing-team-oncall           # PagerDuty or equivalent
escalation_policy: platform-team               # who to page if on-call cannot resolve

# SLOs — mirrors sdlc-config.json service SLOs
slos:
  availability:
    target: 99.9%
    current: 99.95%                             # auto-populated from Prometheus
    error_budget_remaining: 87%                 # auto-populated
  latency:
    p95_target_ms: 200
    p95_current_ms: 145                         # auto-populated from Prometheus

# Dependencies
depends_on:                                     # services this service calls
  - name: billing-domain
    interaction: event-driven                   # event-driven | synchronous-http | grpc
    protocol: redpanda
  - name: invoice-schema-registry
    interaction: synchronous-http
    criticality: required                       # required | optional | fallback
    circuit_breaker: enabled

consumed_by:                                    # services that call this service
  - billing-api
  - reporting-service

# Platform integration
ci_pipeline: https://github.com/org/invoice-processor/actions
cd_pipeline_staging: https://github.com/org/environments/actions/workflows/deploy-staging.yaml
cd_pipeline_production: https://github.com/org/environments/actions/workflows/deploy-production.yaml
helm_chart: helm/invoice-processor
opentofu_module: environments/modules/invoice-processor
observability_dashboard: https://grafana.org/d/invoice-processor

# Catalog gateway — the link to use the golden path to create a new service
golden_path_create: "make new-service NAME=<name> TEAM=billing-team"
```

---

## Required vs. Progressive Fields

Not every field needs to be populated at service creation time. Use this progression:

| Service Age | Required Fields | Progressive Fields |
|---|---|---|
| Created (day 0) | name, display_name, description, owner, repository, language, phase | Everything else |
| First deploy (week 1) | + ci_pipeline, cd_pipeline_staging, helm_chart | slos, observability_dashboard |
| Production deploy | + cd_pipeline_production, runbook, on_call_rotation | depends_on, consumed_by |
| Steady state | All required fields | Kept current by automation |

The CD pipeline auto-updates `last_deploy` on every deployment. The Prometheus integration auto-updates `slos.*.current` daily. Fields that require manual maintenance are flagged in the catalog's validation script.

---

## Catalog Validation

A catalog entry is valid if:

1. All (required) fields are present and non-empty
2. `owner` resolves to a valid GitHub team or Slack handle
3. `repository` URL returns a 200 (checked nightly)
4. `runbook` URL returns a 200 (checked nightly)
5. `slos` targets are consistent with values in `sdlc-config.json` for the same service
6. `depends_on` services all exist in the catalog (no references to unlisted services)

Run validation with:

```bash
scripts/validate-service-catalog.sh
```

This script is also run in CI for the `catalog/` directory — a PR that adds or modifies a service record fails if validation does not pass.

---

## Backstage vs. Lightweight Alternatives

### Lightweight alternatives (< 20 services)

**Option 1: YAML files in `catalog/` directory**

- Structure: `catalog/services/<name>.yaml` using the schema above
- Search: `grep -r "owner: billing-team" catalog/services/`
- Rendering: A simple static site generator (mkdocs, docusaurus) renders the YAML as HTML
- Pros: No additional infrastructure, version-controlled, CI-validated
- Cons: No GUI for non-technical stakeholders, search is manual

**Option 2: Shared wiki (Notion, Confluence, GitHub Wiki)**

- A single table with the required fields as columns
- Link to the full service record for each row
- Pros: Non-technical stakeholders can update it; familiar tooling
- Cons: Validation is manual, can drift from reality, no automation integration

**TVP recommendation:** Start with YAML files in `catalog/services/`. They are version-controlled, diff-able, CI-validated, and machine-readable. A static site generator can render them into a searchable HTML page without additional server infrastructure.

### Backstage (> 20–50 services)

Backstage is the dominant open-source service catalog implementation. It provides:

- A plugin ecosystem (GitHub, PagerDuty, Grafana, Argo CD integrations are maintained by the ecosystem)
- Software templates (TechDocs integration turns Markdown into rendered documentation)
- An API catalog (OpenAPI/Async API specs discoverable alongside services)
- A search index across all catalog entities

**Infrastructure requirements:**

| Component | Resource |
|---|---|
| Backstage app server | 1 Node.js server (1–2 CPU, 2–4 GB RAM) |
| PostgreSQL | 1 database (the YAML-file catalog is persisted here) |
| GitHub integration | GitHub OAuth app + GitHub Actions integration |
| Maintenance | 2–4 hours/week of active curation |

**When to make the Backstage decision:** When two conditions are both true: (a) service count > 20 AND (b) engineers are regularly failing to find services or documentation. If service count is > 50, introduce Backstage regardless of condition (b) — coordination failures at that scale are inevitable.

**Backstage entity format** (compatible with the YAML schema above, with slight renaming):

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: invoice-processor
  description: >
    Processes incoming invoice events...
  annotations:
    github.com/project-slug: org/invoice-processor
    grafana/dashboard-selector: "tag=invoice-processor"
    pagerduty.com/integration-key: "key-here"
spec:
  type: service
  lifecycle: production
  owner: billing-team
  dependsOn:
    - component:billing-domain
    - component:invoice-schema-registry
  system: billing-platform
```

Backstage's `catalog-info.yaml` lives in each service's repository (not in a central `catalog/` directory). This makes it self-service: a new service's first PR includes its `catalog-info.yaml`, and Backstage discovers it automatically via GitHub integration.

---

## Relationship to sdlc-config.json

The service catalog and `sdlc-config.json` share some fields. They serve different purposes:

| Field | sdlc-config.json | Service Catalog |
|---|---|---|
| SLO targets | Source of truth — defines the targets | Consumer — displays current vs. target |
| Owner | Defined here for the product being built | Synced to catalog at service creation |
| Tech stack | Defined here as defaults | Reflected in each service record |
| Phase | Tracks current SDLC phase | Reflected in service lifecycle |

**Sync rule:** When a new service is created via `make new-service`, the script reads `sdlc-config.json` to populate the service's catalog entry (owner, SLO targets, tech stack). The catalog entry is created as part of the golden path — it is not a separate manual step.

**Drift prevention:** A nightly CI job compares SLO targets in `sdlc-config.json` against values in `catalog/services/*.yaml`. Any drift is flagged as a CI warning and added to the platform team's next-sprint backlog.

---

## Service Catalog as Golden Path Gateway

The service catalog is the entry point for creating a new service. The catalog's front page (README or Backstage home) includes:

```
## Create a new service

Run this command to create a new service using the platform's golden path:

    make new-service NAME=<service-name> TEAM=<your-team>

This will:
  - Create a GitHub repository from the standard Go service template
  - Configure CI/CD (GitHub Actions + Helm + OpenTofu)
  - Provision a staging environment
  - Create a catalog entry for the new service
  - Create a Grafana dashboard

Time to first working service: < 15 minutes.
```

This placement ensures that every engineer who opens the service catalog — even if they are just looking for an existing service — sees the golden path for creating a new one. It is the platform's primary marketing surface.
