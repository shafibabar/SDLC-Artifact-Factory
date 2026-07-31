---
name: multi-tenancy-design
description: >
  Teaches the enterprise-architect to design tenant isolation for a
  multi-tenant system — selecting among the three isolation models
  (shared-everything with a tenant_id column, shared-schema-per-tenant, and
  physically-isolated stamp-per-tenant), and enforcing the chosen model
  consistently across every layer (infrastructure/cluster, database, message
  broker/event, and API). Covers the model decision table with its compliance
  and cost tradeoffs, the per-layer enforcement rules, and the per-tenant
  provisioning/stamp model — grounded in this repo's SOC 2 physical-isolation
  product context. Used during Design for any tenant-facing system.
version: 2.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, multi-tenancy, tenant-isolation, data-isolation, physical-isolation, soc2, provisioning]
related:
  - data-model-design
  - data-pipeline-design
  - opentofu-module
  - gitops-workflow
  - environment-config
  - event-driven-patterns
  - zero-trust-architecture
---

# Multi-Tenancy Design

Multi-tenancy design defines how a single product serves multiple customers (tenants) while keeping their data, processing, and infrastructure separate. **The isolation model is a security and compliance decision first, and an architecture decision second** — you pick the model the tenants' data classification and the compliance framework demand, then pay the cost that model implies, not the other way around.

This skill provides the criteria for that decision and the rules for enforcing it. Applying the criteria to a specific product — reading its NFRs, its compliance obligations, its expected tenant count — is the enterprise-architect's reasoning, not stored here.

---

## The Three Isolation Models

Pick one primary criterion and let it drive: **blast radius** (what a breach or bug in one tenant's boundary can reach), **compliance requirement** (does the framework mandate physical separation or accept logical?), **cost per tenant** (does the footprint multiply by tenant count?), and **noisy-neighbor tolerance** (can one tenant's load degrade another's?).

| Model | One-line description | Primary criterion it wins on |
|---|---|---|
| **Shared-everything** | All tenants share infra, database, and app instances; isolation is a `tenant_id` discriminator column on every table, ideally backed by Row-Level Security. | Lowest cost per tenant; acceptable only when data is non-sensitive and no framework mandates separation. |
| **Shared-schema-per-tenant** | One database instance, a separate schema per tenant; the app routes each connection to the tenant's schema. | Middle ground — cheaper than physical, stronger accidental-query isolation than a shared column, but a shared DB process. |
| **Physical isolation (stamp)** | A dedicated, complete per-tenant instance of the platform: own cluster/namespace, own database, own broker, own service instances. | Smallest blast radius; the only model that satisfies SOC 2 physical-isolation controls and data-residency requirements. |

**This repo's default is physical isolation (the stamp model).** The first product (Data Estate Mapping & Compliance Intelligence) processes customers' most sensitive data under a SOC 2 physical-isolation commitment, so no tenant data may be commingled even at the infrastructure level. But **teach the decision, not the default** — a lower-sensitivity product with hundreds of small tenants and a cost ceiling may correctly choose shared-schema, and the decision table in `references/tenancy-models.md` is how you defend that choice with NFR and compliance evidence, not house style.

Full decision table — isolation strength, blast radius, cost curve, operational complexity, compliance fit (SOC 2 / data residency), and noisy-neighbor behaviour for each model, with Kleppmann's partitioning framing and Ford's *Hard Parts* granularity-disintegrator argument for why security and fault-tolerance forces push toward the stamp: **`references/tenancy-models.md`**.

---

## The Cross-Layer Consistency Principle

**The isolation model must be enforced at every layer — infrastructure, database, event/broker, and API. A single leaky layer breaks the guarantee for the whole system.**

Physical deployments with a shared "reporting" database is isolation theatre: the strongest boundary is only as strong as its weakest side channel. Choosing the stamp model at the infrastructure layer but running one shared Redpanda cluster "just for efficiency" reintroduces the exact cross-tenant path you paid to remove. The model is a property of the whole system, not of any one tier.

| Layer | Enforcement in the stamp model | The leaky-layer failure mode |
|---|---|---|
| **Infrastructure** | Namespace or cluster per tenant; a default-deny NetworkPolicy so no network path exists between tenants. | Shared ingress or a flat network lets one tenant's pod reach another's. |
| **Database** | Separate PostgreSQL instance per tenant; separate credentials and connection pool; the connection is routed by tenant, never a shared pool filtered by `tenant_id`. | A shared instance means one DB-level breach or one missing `WHERE` clause exposes every tenant. |
| **Event / Broker** | Dedicated Redpanda namespace or cluster per tenant; tenant context travels on every event for audit, never as the isolation mechanism. | Tenant-prefixed topics on one shared cluster: one ACL misconfiguration or compromised consumer crosses the boundary. |
| **API** | Tenant resolved from the authenticated request context (routing + JWT claim), **never** from a client-supplied parameter; a tenant-scoping middleware rejects any mismatch. | Trusting a `?tenant=` query param or request-body field is a direct cross-tenant read primitive. |

Per-layer enforcement rules, the exact tenant-resolution rule, the connection-routing mechanism, `chi` middleware and `pgx` examples, and the specific leaky-layer failure mode for each layer: **`references/enforcement-layers.md`**.

---

## Provisioning and the Stamp Model

For physical isolation, "add a tenant" means "stamp a new complete instance of the platform." A tenant is provisioned by rendering the same versioned OpenTofu Module and Helm Chart against a per-tenant values file, wired up under a per-tenant GitOps App-of-Apps root — never by hand-editing a live environment. **Provisioning is code, not a runbook**, so it is idempotent, versioned, and auditable; a model that can only *create* tenants fails its first churn event and its first GDPR erasure request, so the lifecycle (provision → suspend → deprovision → data export) is designed up front.

Key defaults that live in the body: one GitOps agent per tenant (so a reconciliation fault has a one-tenant blast radius); one canary tenant then waves for fleet upgrades (never big-bang); bounded version skew (N and N−1) because event schemas must stay compatible across the skew window; and a Control Plane that manages tenants but **never reads tenant data** (a Delegate-pattern boundary).

The full stamp anatomy, the step-by-step provisioning flow, the tenant lifecycle state machine, the one-agent-per-tenant blast-radius argument, drift/upgrade-wave fleet operations, and the ties to `opentofu-module`, `gitops-workflow`, and `environment-config`: **`references/provisioning-and-stamps.md`**.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Isolation model documented | Model stated with NFR/compliance justification, not assumed | Isolation implied without a decision record |
| Model enforced at every layer | Infra, DB, event, and API all enforce the same model | Any one layer leaks (shared broker, shared reporting DB, client-supplied tenant id) |
| No cross-tenant network path | Default-deny NetworkPolicy; per-tenant ingress | Shared load balancer or flat network across tenants |
| Tenant resolved server-side | Tenant from auth/routing context; middleware rejects mismatch | Tenant read from a client-supplied parameter |
| Provisioning automated | OpenTofu Module + Helm release, idempotent and versioned | Manual provisioning steps |
| Lifecycle designed | Provision, suspend, deprovision, and data export all defined | Create-only tenancy with no offboarding or erasure path |
| Control/data plane separated | Control Plane cannot read tenant data | Operator tooling can query tenant databases |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Isolation theatre** — physical stamps but a shared reporting database aggregating tenant data | One shared store voids the model; the weakest side channel defines the boundary | Cross-tenant analytics use anonymised, contractually-permitted metadata in the Control Plane, never raw tenant data |
| **`tenant_id` filtering sold as isolation for sensitive data** | One missing `WHERE` clause is a cross-tenant breach; app discipline is not a boundary | For sensitive data, enforce isolation in infrastructure; keep `tenant_id` for audit only |
| **Client-supplied tenant identity** | A `?tenant=` param the server trusts is a direct cross-tenant read primitive | Resolve tenant from routing + JWT; middleware rejects any claim/route mismatch |
| **Shared broker "just for efficiency"** for a physical-isolation product | Broker bugs or a bad ACL cross the tenant boundary | Dedicated Redpanda namespace or cluster per tenant, matching the declared model |
| **Snowflake tenants** — per-tenant manual production tweaks | The fleet fragments; nobody can upgrade confidently | All variation lives in the per-tenant values file, rendered from shared chart/module versions |
| **Big-bang fleet upgrades** | A bad release becomes an every-customer incident | Canary tenant → waves; per-tenant rollback; bounded version skew |
| **Provisioning as a runbook** | Manual steps drift, get skipped, cannot be audited | Provisioning and deprovisioning are OpenTofu Modules invoked by the Control Plane |

---

## Output Format

```markdown
---
name: multi-tenancy-design
product: [product name]
tenancy-model: [physical | shared-schema | shared-everything]
version: 1.0.0
phase: design
created: [date]
owner: enterprise-architect
---

# Multi-Tenancy Design

## Isolation Model
[Model selected and justification — reference the NFR IDs and compliance
framework controls that drove the decision]

## Deployment Topology
[Diagram showing per-tenant isolation and the absence of cross-tenant paths]

## Isolation Enforcement
| Layer | Mechanism | Configuration location |
|---|---|---|

## Tenant Provisioning
[Provisioning flow with OpenTofu Module / Helm / GitOps references]

## Tenant Lifecycle
[Provision, suspend, deprovision, data-export states]

## Control Plane vs Data Plane Boundary
[What the Control Plane can and cannot access]

## Tenant Context Propagation
[How tenant identity flows through routing, JWT, events, logs, audit]

## Related ADRs
[ADR IDs for decisions made during multi-tenancy design]
```
