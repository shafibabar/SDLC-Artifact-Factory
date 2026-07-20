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
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, iac, opentofu, modules, tenant-stamp, opa, remote-state, drift]
---

# OpenTofu Module

## Purpose

All infrastructure on this platform is Infrastructure as Code (IaC), expressed as **OpenTofu Modules** — versioned, reviewed, planned before applied. OpenTofu is the open-source Terraform fork; it keeps the frugal posture (no licence exposure) with the same HCL and provider ecosystem. Modules are to infrastructure what packages are to code: single-purpose, contract-fronted, composed — the SOLID rule applied to clusters and databases. Snowflake infrastructure, built by hand in a console, is the anti-product of this skill: unreviewable, unrepeatable, and fatal to a per-tenant fleet.

The physical multi-tenancy model (`multi-tenancy-design`) makes this existential: every tenant environment is **stamped from the same modules with different variables**. If tenant infrastructure cannot be recreated from Git, the isolation model collapses into forty hand-grown environments nobody can upgrade.

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
- Composition happens in *root configurations* (the per-environment/per-tenant directories) and in explicit composition modules like `tenant-stamp` — never by one leaf module instantiating another leaf sideways.
- No god-module. If a module's variables file needs section headers, it is two modules.

---

## Variables and Outputs Are Contracts

A module's `variables.tf` and `outputs.tf` are its public API — typed, constrained, documented. Everything else is private:

```hcl
# modules/postgres/variables.tf
variable "tenant_id" {
  type        = string
  description = "Tenant this instance belongs to; propagated to tags and backup naming."
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,30}[a-z0-9])$", var.tenant_id))
    error_message = "tenant_id must be lowercase alphanumeric-with-dashes, 3-32 chars."
  }
}

variable "instance_size" {
  type        = string
  description = "Sizing tier; the module maps tiers to machine types — callers never pick machines."
  default     = "small"
  validation {
    condition     = contains(["small", "medium", "large"], var.instance_size)
    error_message = "instance_size must be small, medium, or large."
  }
}
```

```hcl
# modules/postgres/outputs.tf
output "endpoint"        { value = postgresql_instance.this.endpoint }
output "vault_cred_path" { value = vault_database_secret_backend_role.app.path }  # path, never the secret
```

- **Validations encode the rules** — an invalid tenant id fails at plan, not at 2 a.m.
- **Tiers, not machine types** — sizing decisions are the module's; callers express intent (`small`), keeping fleet-wide resizing a one-module change.
- **Outputs never emit secrets** — credentials land in Vault (the security-engineer's `secrets-management` boundary); outputs carry *paths* to them.

---

## Remote State and Locking

State is the map between HCL and reality; losing or forking it orphans infrastructure:

```hcl
terraform {
  backend "s3" {
    bucket         = "acme-tofu-state"
    key            = "tenants/acme/terraform.tfstate"   # one state per root config
    region         = "eu-west-1"
    dynamodb_table = "tofu-locks"                        # locking: concurrent applies blocked
    encrypt        = true
  }
}
```

- **One state file per root config** — each tenant stamp has its own state, so one tenant's apply can never corrupt another's. Blast radius equals state-file scope; keep both small.
- **Locking always on** — two concurrent applies against one state is state corruption.
- **State is sensitive** — it contains resource attributes; encrypted at rest, access as tightly controlled as production credentials, never committed to Git.

---

## Plan-Before-Apply in CI, Gated by OPA

No human runs `tofu apply` from a laptop. The pipeline (a sibling of `ci-pipeline`, same one-path principle):

```
PR opened      → tofu fmt -check → tofu validate → tofu plan -out=tfplan
               → tofu show -json tfplan | conftest test -p policy/   ← OPA gate
               → plan posted to the PR as a comment (the reviewable diff)
PR merged      → tofu apply tfplan            (the exact reviewed plan, not a fresh one)
Nightly        → tofu plan -detailed-exitcode  (drift detection; exit 2 ⇒ drift ⇒ incident)
```

The **OPA compliance check** runs the security-engineer's policies against the planned changes — public ingress on a tenant database, missing encryption flags, cross-tenant network paths, untagged resources — and fails the PR before anything exists. Compliance is verified at plan time, when correction is a code review comment, not a migration.

Applying the *saved plan file* matters: it guarantees what reviewers approved is what executes, even if the world moved between review and merge (a changed world invalidates the plan and forces a re-review).

---

## No Console Changes — Drift Is an Incident

The console is read-only. Any resource changed outside OpenTofu is **drift**, and the nightly `plan -detailed-exitcode` treats a non-empty plan against unchanged HCL as an incident (same contract as `cd-pipeline`'s cluster-side drift rule):

1. Alert fires with the drifted resources from the plan diff.
2. Triage: unauthorised change (security incident — who had write access and why?) or emergency fix under pressure (process incident — backport it into HCL *now*).
3. Resolution is always convergence: either the HCL is updated to adopt a legitimate change, or `apply` reverts the drift. Drift is never left standing.

---

## Per-Tenant Stamping: Workspaces vs Directories

Two mechanisms can stamp N tenants from one module set. The decision, recorded here as a table (an ADR captures the product-specific choice):

| Concern | Workspaces (one config, N states) | Directory-per-tenant (N thin root configs) |
|---|---|---|
| Isolation visibility | Implicit — active workspace is CLI session state | **Explicit — the tenant is the directory path in every plan, PR, and log** |
| Wrong-tenant apply risk | High — forget `workspace select` and apply hits the wrong tenant | Low — you are where you `cd`; CI maps directory → state key mechanically |
| Per-tenant variation | Awkward — `var-file` juggling keyed by workspace name | Natural — each directory holds that tenant's `.tfvars` |
| Version skew (upgrade waves) | Hard — one config pins one module version for all | **Easy — each directory pins its module version; waves = PRs per directory** |
| Fleet-wide change | One edit (strength) | Scripted PR across directories (mild cost, fully reviewable) |
| Auditability per tenant | Shared plan history | Per-directory history: `git log deploy/tenants/acme/` |

**Recommendation: directory-per-tenant with shared modules.** For a *physical-isolation* product, the explicitness is the point — every plan names its tenant in its path, wrong-tenant applies are structurally hard, and upgrade waves with bounded version skew (`multi-tenancy-design`'s fleet rule) fall out of per-directory module pins. Workspaces optimise for identical environments; tenant fleets are deliberately *not* identical in version during a rollout.

---

## Worked Example — The tenant-stamp Module

Onboarding tenant `acme` to the compliance platform is one directory and one PR:

```hcl
# deploy/tenants/acme/main.tf
module "tenant" {
  source  = "git::https://github.com/acme/platform-modules.git//modules/tenant-stamp?ref=v1.4.0"

  tenant_id     = "acme"
  region        = "eu-west-1"          # tenant's data-residency requirement
  sizing        = "medium"             # tier: maps to node pool, PG, Redpanda sizes
  ingress_host  = "acme.app.example.com"
}
```

```hcl
# modules/tenant-stamp/main.tf — composition of the leaf modules
module "network"  { source = "../network"   tenant_id = var.tenant_id  region = var.region }
module "cluster"  { source = "../cluster"   tenant_id = var.tenant_id  network = module.network.id  sizing = var.sizing }
module "postgres" { source = "../postgres"  tenant_id = var.tenant_id  network = module.network.id  instance_size = var.sizing }
module "redpanda" { source = "../redpanda"  tenant_id = var.tenant_id  network = module.network.id  sizing = var.sizing }
# cluster bootstrap installs Flux pointed at deploy/clusters/tenants/acme/ —
# from here, workloads arrive via GitOps (cd-pipeline), not via OpenTofu.
```

The stamp provisions the tenant's isolated network, cluster, PostgreSQL (with Apache AGE for the estate graph), and Redpanda — then hands over to the CD reconciler for workloads. Offboarding is `tofu destroy` in that directory plus the backup-handover attestation the data-architect's retention contract requires. Version pins are explicit: `?ref=v1.4.0` — the canary tenant's directory moves to `v1.5.0` first, waves follow.

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
| Handover boundary | OpenTofu stops at cluster+Flux; workloads via GitOps | Modules deploying application workloads |

---

## Anti-Patterns

- **The console "quick fix"** — one hand-resized database and state no longer describes reality; the next apply may revert or destroy it. Read-only consoles; emergencies go through an expedited PR, not around it.
- **`ref=main` module sources** — every tenant silently gets whatever merged last; upgrade waves become impossible because nothing is pinned to wave from.
- **One state file for the fleet** — a single corrupt state or bad apply now has fleet-wide blast radius, precisely what physical isolation exists to prevent.
- **Secrets through outputs** — an output marked `sensitive` still lands in state and CI logs' plan JSON. Credentials go to Vault inside the module; outputs carry paths.
- **OpenTofu deploying workloads** — `kubernetes_manifest` resources for Deployments duplicate the GitOps path and fight the reconciler. IaC provisions platforms; `cd-pipeline` delivers workloads onto them.
- **Plan as a formality** — merging on green plan without reading it approves changes nobody saw. The plan comment *is* the review artifact; a `destroy` line in it is the whole point of the ritual.
- **Copy-pasting a module per tenant** — "acme needed one tweak" forks the module and that tenant exits the fleet. Tweaks become variables (with validation) on the shared module, or an ADR-reviewed new tier.

---

## Output Format

Produces modules and per-tenant root configurations:

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

## Contract
[Table: variable → type → validation → description; output → description]

## State Layout
[Backend, key scheme (one per root), lock table]

## Stamping Decision
[Workspaces vs directories table outcome + ADR reference]

## Traceability
[Multi-Tenancy Design section implemented; NFR IDs (residency, isolation, RTO)]
```
