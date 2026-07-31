---
name: opentofu-module
description: >
  Teaches the OpenTofu Module standards for Infrastructure as Code — one module
  per infrastructure concern, explicit variable and output contracts, remote
  state with locking, plan-before-apply in CI gated by OPA compliance checks,
  provider and module version pinning, the no-console-changes rule (drift is an
  incident), and the workspaces-versus-directories decision for per-tenant
  stamping with a worked tenant-stamp module. Used by the platform-engineer
  during Deploy.
version: 1.1.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, iac, opentofu, modules, tenant-stamp, opa, remote-state, drift, golden-path, self-service]
---

# OpenTofu Module

## Purpose

All infrastructure on this platform is Infrastructure as Code (IaC), expressed as **OpenTofu Modules** — versioned, reviewed, planned before applied. OpenTofu is the open-source Terraform fork; it keeps the frugal posture (no licence exposure) with the same HCL and provider ecosystem. Modules are to infrastructure what packages are to code: single-purpose, contract-fronted, composed — the SOLID rule applied to clusters and databases.

The physical multi-tenancy model (`multi-tenancy-design`) makes this existential: every tenant environment is **stamped from the same modules with different variables**. If tenant infrastructure cannot be recreated from Git, the isolation model collapses into forty hand-grown environments nobody can upgrade.

Full HCL patterns, worked examples, and an OPA policy sample: `references/hcl-patterns-and-examples.md`.

---

## One Module Per Concern

| Module | Provisions | Consumed by |
|---|---|---|
| `modules/network` | VPC/subnets, NAT, DNS zones, firewall baseline | cluster, tenant-stamp |
| `modules/cluster` | Kubernetes cluster, node pools, Linkerd + Flux bootstrap | tenant-stamp, control plane |
| `modules/postgres` | PostgreSQL instance (+ Apache AGE extension), backups, credentials into Vault | tenant-stamp |
| `modules/redpanda` | Redpanda cluster/namespace, topic baseline, Dead Letter Queue (DLQ) topics | tenant-stamp |
| `modules/tenant-stamp` | **Composition**: one tenant's complete isolated data plane | per-tenant root configs |
| `modules/observability` | Prometheus/Grafana/Tempo/Alertmanager install per cluster | cluster |

Rules of decomposition:
- A module owns one concern completely; it never reaches into another's resources.
- Composition happens in *root configurations* and in explicit composition modules like `tenant-stamp` — never by one leaf module instantiating another leaf sideways.
- No god-module. If a module's variables file needs section headers, it is two modules.

---

## Variables and Outputs Are Contracts

A module's `variables.tf` and `outputs.tf` are its public API — typed, constrained, documented:

- **Validations encode the rules** — an invalid tenant id fails at plan, not at 2 a.m.
- **Tiers, not machine types** — sizing decisions are the module's; callers express intent (`small`), keeping fleet-wide resizing a one-module change.
- **Outputs never emit secrets** — credentials land in Vault; outputs carry *paths* to them.

See `references/hcl-patterns-and-examples.md` §Variables for annotated HCL with validation blocks and tier-to-machine-type mapping.

---

## Remote State and Locking

State is the map between HCL and reality; losing or forking it orphans infrastructure:

- **One state file per root config** — each tenant stamp has its own state, so one tenant's apply can never corrupt another's. Blast radius equals state-file scope; keep both small.
- **Locking always on** — two concurrent applies against one state is state corruption.
- **State is sensitive** — it contains resource attributes; encrypted at rest, access as tightly controlled as production credentials, never committed to Git.

Backend config (S3 + DynamoDB lock): `references/hcl-patterns-and-examples.md` §Remote State.

---

## Plan-Before-Apply in CI, Gated by OPA

No human runs `tofu apply` from a laptop:

```
PR opened      → tofu fmt -check → tofu validate → tofu plan -out=tfplan
               → tofu show -json tfplan | conftest test -p policy/   ← OPA gate
               → plan posted to the PR as a comment (the reviewable diff)
PR merged      → tofu apply tfplan            (the exact reviewed plan, not a fresh one)
Nightly        → tofu plan -detailed-exitcode  (drift detection; exit 2 ⇒ drift ⇒ incident)
```

The **OPA compliance check** runs the security-engineer's policies against planned changes — public ingress on a tenant database, missing encryption flags, cross-tenant network paths, untagged resources — and fails the PR before anything exists. Applying the *saved plan file* matters: a changed world invalidates the plan and forces a re-review.

---

## No Console Changes — Drift Is an Incident

The console is read-only. Any resource changed outside OpenTofu is **drift**, and the nightly `plan -detailed-exitcode` treats a non-empty plan against unchanged HCL as an incident:

1. Alert fires with the drifted resources from the plan diff.
2. Triage: unauthorised change (security incident) or emergency fix under pressure (process incident — backport into HCL *now*).
3. Resolution is always convergence: HCL updated to adopt a legitimate change, or `apply` reverts the drift. Drift is never left standing.

---

## Per-Tenant Stamping: Workspaces vs Directories

| Concern | Workspaces (one config, N states) | Directory-per-tenant (N thin root configs) |
|---|---|---|
| Isolation visibility | Implicit — active workspace is CLI session state | **Explicit — tenant is the directory path in every plan, PR, and log** |
| Wrong-tenant apply risk | High — forget `workspace select` and apply hits the wrong tenant | Low — you are where you `cd`; CI maps directory → state key mechanically |
| Per-tenant variation | Awkward — `var-file` juggling keyed by workspace name | Natural — each directory holds that tenant's `.tfvars` |
| Version skew (upgrade waves) | Hard — one config pins one module version for all | **Easy — each directory pins its module version; waves = PRs per directory** |
| Auditability per tenant | Shared plan history | Per-directory history: `git log deploy/tenants/acme/` |

**Recommendation: directory-per-tenant with shared modules.** For a *physical-isolation* product, explicitness is the point — every plan names its tenant in its path, wrong-tenant applies are structurally hard, and upgrade waves with bounded version skew fall out of per-directory module pins.

Full tenant-stamp worked example (HCL): `references/hcl-patterns-and-examples.md` §Worked Example.

---

## Self-Service Infrastructure Request (Developer-Facing Golden Path)

A developer who needs a new PostgreSQL database **does not write OpenTofu HCL**. They fill in a YAML request template — the golden path — and open a PR to the environment repo. The platform's CI automation validates the request, generates the corresponding module call, plans it, and applies it. The developer never authors HCL.

This separates *expressing intent* (the developer's job) from *implementing infrastructure* (the platform's job) — the same boundary that `modules/postgres`'s sizing tiers enforce inside HCL.

### Infrastructure Request YAML (Developer-Facing)

```yaml
# Fill in assets/infrastructure-request-template.yaml and open a PR.
kind: InfrastructureRequest
service: <service-name>
resource: postgresql
config:
  name: <db-name>
  size: small | medium | large      # maps to modules/postgres instance_size
  environment: dev | staging | production
  tenant: <tenant-id>               # for per-tenant stamp isolation
owner: <team-or-engineer>
```

The CI automation (`scripts/infra-request-apply.sh` in the environment repo):
1. Validates the YAML against a JSON Schema (resource type, size enum, tenant format).
2. Generates the corresponding OpenTofu root config in `deploy/tenants/<tenant>/services/<service>/`.
3. Runs the OPA-gated plan and posts it as a PR comment.
4. On merge, applies the saved plan — the developer receives the Vault credential path as a PR output.

Developers never see `tofu apply` error messages; they see actionable feedback from the YAML schema validator. Any YAML that passes schema validation must produce a valid plan — the platform engineer's contract with the developer.

### DX NFR — Environment-Provisioning SLO

The golden path carries a non-functional requirement: a developer submitting a valid `InfrastructureRequest` must have it provisioned within the environment-provisioning SLO:

| Environment | Provisioning SLO |
|---|---|
| dev | ≤ 5 minutes from PR merge to resource available |
| staging | ≤ 15 minutes |
| production | ≤ 30 minutes |

These are the platform's own SLOs, tracked in the platform dashboard alongside service-level SLOs (`slo-definition`). Breaches are platform incidents, not product incidents. Rising breach rates signal that the YAML-to-HCL pipeline needs automation investment, not that developers are submitting too many requests.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Module granularity | One concern per module; composition in roots/`tenant-stamp` | God-module, or leaf modules entangled sideways |
| Contracts typed | Variables validated, tiers not machine types, outputs secret-free | Untyped variables; secrets in outputs |
| State discipline | Remote, encrypted, locked, one state per root | Local state, shared state across tenants, no locking |
| Plan gated | CI plan + OPA pass required; saved plan applied | Laptop applies; plan and apply diverge |
| Versions pinned | Providers and module refs pinned; bumps are PRs | Floating `ref=main` or unpinned providers |
| Drift detected | Nightly plan; non-empty ⇒ incident | Drift found only when something breaks |
| Tenant stamping | Directory-per-tenant from shared pinned modules | Workspaces juggling, or hand-grown tenants |
| Self-service path | InfrastructureRequest YAML → auto-generated HCL → OPA-gated apply | Developer writing HCL; no YAML golden path |
| Provisioning SLO | dev ≤5 min, staging ≤15 min, production ≤30 min | No SLO; breaches not tracked as platform incidents |

---

## Anti-Patterns

- **The console "quick fix"** — one hand-resized database and state no longer describes reality; the next apply may revert or destroy it. Emergencies go through an expedited PR, not around it.
- **`ref=main` module sources** — every tenant silently gets whatever merged last; upgrade waves become impossible because nothing is pinned to wave from.
- **One state file for the fleet** — a single corrupt state or bad apply now has fleet-wide blast radius, precisely what physical isolation exists to prevent.
- **Secrets through outputs** — an output marked `sensitive` still lands in state and CI logs' plan JSON. Credentials go to Vault inside the module; outputs carry paths.
- **OpenTofu deploying workloads** — `kubernetes_manifest` resources for Deployments duplicate the GitOps path and fight the reconciler. IaC provisions platforms; `cd-pipeline` delivers workloads onto them.
- **Plan as a formality** — merging on green plan without reading it approves changes nobody saw. The plan comment *is* the review artifact; a `destroy` line in it is the whole point of the ritual.
- **Copy-pasting a module per tenant** — "acme needed one tweak" forks the module and that tenant exits the fleet. Tweaks become variables (with validation) on the shared module, or an ADR-reviewed new tier.
- **Forcing developers to write HCL** — skipping the YAML golden path imposes platform-level cognitive load on product engineers; it means the self-service layer has not been built.

---

## Output Format

Produces modules, per-tenant root configurations, and self-service request automation:

```markdown
---
name: opentofu-module-[concern]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [date]
---

# OpenTofu Module — [concern]

## Files
modules/[concern]/{main,variables,outputs,versions}.tf
deploy/tenants/[tenant-id]/{main.tf,backend.tf,terraform.tfvars}   (per-tenant roots)
policy/[concern]/*.rego                                            (OPA gate rules)
assets/infrastructure-request-template.yaml                        (developer-facing)
scripts/infra-request-apply.sh                                     (YAML → HCL automation)

## Contract
[Table: variable → type → validation → description; output → description]

## State Layout
[Backend, key scheme (one per root), lock table]

## Stamping Decision
[Workspaces vs directories table outcome + ADR reference]

## Self-Service SLO
[Environment → provisioning SLO targets; breach tracking location]

## Traceability
[Multi-Tenancy Design section implemented; NFR IDs (residency, isolation, RTO, DX provisioning SLO)]
```
