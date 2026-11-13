---
name: multi-tenancy-design
description: >
  Decide how a multi-tenant product keeps tenants apart, per resource: silo
  (dedicated to one tenant; a full-stack silo is a stamp), pool (shared, with
  isolation enforced at run time), bridge (a schema per tenant in a shared
  database) or a mixed or tiered combination (pooled standard tenants, siloed
  regulated or contract-bound ones), chosen from the product's NFRs, data
  classification, compliance and residency obligations, tiers, noisy-neighbour
  risk and cost to serve. There is no default model, and SOC 2 does not
  require physical or per-tenant database isolation. Covers the isolation
  mechanism at every layer (tenant context from the token, forced row-level
  security, broker principals and ACLs, network policy for silos, a
  cross-tenant test as a gate), the control plane versus application plane,
  onboarding, tier changes and offboarding including pooled deletion, and
  metering and cost per tenant. Decided before the container diagram's
  deployment view. Use when choosing, reviewing or changing a tenancy model,
  answering whether a framework or customer requires dedicated
  infrastructure, or planning tenant onboarding and offboarding. Used by
  enterprise-architect.
version: 3.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, multi-tenancy, tenant-isolation, saas, silo, pool, tiering, data-partitioning]
produces: multi-tenancy-design
domain: architecture
status: stable
related: [container-diagram, nfr-specification, event-schema-design, data-classification, compliance-design, access-control-model, zero-trust-design, data-model-design, data-pipeline-design, event-driven-patterns, opentofu-module, gitops-workflow, environment-config, canary-deployment, secrets-management, opentelemetry-instrumentation, api-gateway-design, adr-authoring, glossary-management, methodology-review]
sources:
  - research/software-architecture/building-multi-tenant-saas-golding.md
  - research/software-architecture/software-architecture-hard-parts-ford.md
  - research/software-architecture/designing-data-intensive-applications-kleppmann.md
  - research/software-architecture/system-design-interview-xu.md
---

# Multi-Tenancy Design

## Purpose

How one product serves many customers (tenants) and keeps each one's data, load and failures from reaching the others. **Readers:** enterprise-architect, security-architect (threat model), data-architect (partitioning), platform-engineer (what to provision), the product owner (cost to serve and what each tier promises). **Question:** for each resource, is it shared or dedicated, what stops one tenant reaching another's, and how does a tenant join, change tier and leave?

Only for a multi-tenant product: `design/architecture/multi-tenancy-design.md` (`./templates/multi-tenancy-design.md`). A single-tenant product records "single tenant" in the container diagram's deployment view and skips this. Decided **before the deployment view** of `container-diagram`, because the model decides the deployment topology (D047-7).

**There is no plugin default.** The model comes from this product's NFRs and compliance input (D047-7). A stamp per tenant is one possible outcome, not the house style; for many small tenants it overbuilds badly.

| Profile | Usual shape (the inputs decide, not the profile) |
|---|---|
| Lean | A pool: shared app and database, tenant key on every table, forced row-level security. A short artifact: model table, mechanism, lifecycle in a few lines |
| Standard | A pool or bridge; a silo only for a resource or tenant with a named reason |
| Enterprise | Often mixed or tiered: pooled standard tier, silo for regulated or contract-bound tenants; regions where residency requires them |

What this skill does **not** hold: the deployment drawing (`container-diagram`); the tables and keys (`data-model-design`); authorization rules (`access-control-model`); what each framework's controls are (`compliance-design`); the modules and values that provision a silo (`opentofu-module`, `environment-config`, `gitops-workflow`).

## 1. Deployment Model and Isolation Are Two Decisions

Golding's central distinction (`building-multi-tenant-saas-golding.md`):
- **Deployment model:** where each tenant's resources sit. **Silo** (dedicated), **pool** (shared), **bridge** (a schema per tenant in one database instance). The repo's old names map across: shared-everything = pool, shared-schema = bridge, stamp = full-stack silo.
- **Isolation:** the controls that stop one tenant reaching another's resources. A silo makes isolation easier but does not enforce it (a flat network or a shared credential still crosses it). A pool needs isolation **enforced by a mechanism**, never by developers remembering a `WHERE` clause.

**Choose per resource, not once for the system.** Compute, each data store, the broker, caches, search indexes and object storage each get silo, pool or bridge. Mixed is normal: pooled compute with one tenant's database siloed; or tiers, basic pooled and premium siloed.

## 2. The Forces

Weigh all of them and record which decided each resource (Golding):

| Force | Pushes toward |
|---|---|
| Tiering (what each price point promises) | Silo for a tier that sells dedicated resources |
| Compliance, residency, contracts | Silo or a region only where a named law, contract or tier requires it (§ 3) |
| Noisy neighbour | Pool with per-tenant throttling and quotas; silo for a tenant whose load can't be contained |
| Cost to serve | Pool: a silo multiplies baseline cost by tenant count and leaves capacity idle |
| Operations and agility | Pool: every silo is one more thing to deploy, upgrade and watch; a fleet of hand-managed copies is managed hosting, not SaaS |
| Blast radius and fault tolerance | Silo (Hard Parts' security and fault-tolerance disintegrators, `software-architecture-hard-parts-ford.md`) |
| Onboarding speed | Pool: a new tenant is rows, not infrastructure |

A pooled data store needs a **tenant-leading partition key** so one tenant's data can be found, moved, exported and deleted, and so a large tenant shows up as a hot key before it degrades the rest (Kleppmann, `designing-data-intensive-applications-kleppmann.md`). Inside a silo, ordinary scaling (replicas, caches, sharding) still applies within that tenant (Xu, `system-design-interview-xu.md`).

Models, partitioning per store type, the tiered pattern: `./references/deployment-models.md`.

## 3. Compliance: Name the Source of Every Push

- **SOC 2 does not require physical isolation or a database per tenant.** It is an attestation against outcome criteria (access restricted, changes controlled); a pool with enforced, tested logical isolation can pass. "Physical isolation" is a commitment some providers make to customers, not a SOC 2 control.
- Pushes toward a silo or a region come from **a law** (a data-localisation law), **a contract** (a customer's isolation or key-ownership clause), or **a tier** (premium sells dedicated resources). Record each with its source; never "compliance requires it".
- Data residency is met by **regions**, not by a stamp per tenant: a pool per region keeps EU data in the EU.

Before handing off, cross-check the compliance basis against `./resources/compliance-basis.md`. Framework controls themselves: `compliance-design`.

## 4. Enforce the Model at Every Layer

**The chosen model must hold at every layer; the weakest layer is the system's isolation.** A leak is a layer enforcing *less* than the declared model: a silo with a flat network, a pooled table without row-level security, a client-supplied tenant id. A shared broker is a leak only when the declared model silos the broker.

| Layer | Pool | Silo |
|---|---|---|
| Tenant context | From the verified token's tenant claim, set once per request; never from a query parameter, body field or unverified header | Same, also checked against the routing host |
| Database | Tenant key on every row; row-level security **forced** (the owner bypasses it otherwise); the app connects as a non-owner role; tenant set per transaction | A database or instance per tenant, own credentials; connection chosen by tenant, fail closed |
| Broker | Per-tenant or per-service principals with topic ACLs; tenant on every event | A broker namespace or cluster per tenant |
| Network | One network; isolation is above it | Default-deny between tenant namespaces; own ingress where the contract asks |
| Telemetry | Tenant and tier as attributes on spans and logs; bounded tenant labels on metrics | Scoped per silo |

**A cross-tenant test is a release gate:** tenant A's token against tenant B's resource, at the API and the data layer, expecting a refusal. Rules and snippets per layer: `./references/isolation-enforcement.md`.

## 5. Control Plane, Lifecycle, Metering

- **Control plane** (onboarding, tenant registry, tiers, identity set-up, metering, admin) is global; the **application plane** is the product, in whatever silo and pool mix the model chose. The control plane manages tenants and never reads tenant data.
- **Onboarding** is one automated flow for every model: a pooled tenant is a registry entry, identity and rows; a siloed one also gets its provisioned resources from versioned modules, never by hand.
- **Tier change** (pool to silo and back) is designed with onboarding: copy, cut over, re-route.
- **Offboarding:** export, then delete. A silo is destroyed; a pooled tenant's data is removed from every shared store, index, cache, event log and backup, or made unreadable by destroying its per-tenant key.
- **Metering** (usage for billing), **metrics** and **cost per tenant** are distinct. In a silo, cost comes from resource tags; in a pool, from per-tenant consumption the services record.
- **Fleet of silos:** one version source, per-tenant values only, canary tenant then waves, bounded version skew.

Detail: `./references/control-plane-and-lifecycle.md`.

## Procedure

1. **Read** the NFR specification (tenant count and growth, residency, noisy-neighbour and availability targets), `data-classification`, `compliance-design` output and any customer contract terms, the tiers, `sdlc-config.json`, the context map. Missing input: carry on, mark the assumption, list it under *Open questions*.
2. **List the resources** that hold or process tenant data: compute, each data store, broker, caches, search, object storage, telemetry.
3. **Choose per resource** silo, pool or bridge (§ 1), naming the forces that decided it (§ 2) and the source of every compliance or contract push (§ 3). State the overall model: pool, bridge, silo or mixed, and the tiers.
4. **Name the isolation mechanism** for every resource and layer (§ 4), and the cross-tenant test.
5. **Design the lifecycle and metering** (§ 5): onboarding, tier change, offboarding and pooled deletion, cost per tenant.
6. **Validate, then loop.** Run `./scripts/validate-multi-tenancy-design.sh design/architecture/multi-tenancy-design.md`, fix every FAIL, re-run until clean; then `./resources/checklist.md`.
7. **Present** for approval, with the reason for every request declined (§ Gotchas). Hand on: the deployment view (`container-diagram`), partitioning (`data-model-design`), threat model (security-architect), provisioning (platform-engineer). An ADR for the model (`adr-authoring`). Answering in a reply rather than a file: the declined requests and their reasons once, then the artifact once.

Examples: `./examples/01-lean-pooled-rls.md` (a bookkeeping tool for small trades businesses: hundreds of tenants, one pool, forced row-level security), `./examples/02-standard-bridge.md` (a mid-market HR onboarding product: a schema per tenant, pooled compute and broker), `./examples/03-enterprise-tiered.md` (a pharmacy-chain inventory platform: pooled standard tier per region, silo stamps for two contract-bound chains, a tier change and deletion designed).

## Gotchas

Each trap comes with the reason to give in full.

- **"SOC 2 requires a separate database (or physical isolation) per tenant."** *Reason:* SOC 2 attests outcome criteria and prescribes no deployment model; physical isolation is a customer commitment some providers make, not a SOC 2 control. *Instead:* enforced, tested logical isolation; a silo only where a named law, contract or tier asks for it, recorded with that source.
- **"Use the standard model: a stamp per tenant."** *Reason:* there is no default (D047-7); for many small tenants a stamp each multiplies cost and turns one product into a fleet. *Instead:* choose per resource from the forces.
- **"Residency means a stamp per tenant."** *Reason:* residency is about where data sits, which a region satisfies. *Instead:* a pool per region; silo only for a tenant with its own reason.
- **"Every table has `tenant_id`, so tenants are isolated."** *Reason:* a column is not a mechanism; one missing filter leaks every tenant. *Instead:* forced row-level security, a non-owner role, the tenant set per transaction.
- **"Row-level security is on."** *Reason:* the table owner bypasses it unless it is forced, and a pooled connection can carry a tenant setting into the next request. *Instead:* `FORCE ROW LEVEL SECURITY`, connect as a non-owner, set the tenant with `SET LOCAL` inside each transaction.
- **"Read the tenant from the `tenant` parameter."** *Reason:* any authenticated user can name another tenant (a cross-tenant IDOR). *Instead:* the tenant from the verified token; a mismatch is refused.
- **"A shared broker breaks isolation."** *Reason:* only if the declared model silos the broker; a pooled broker with per-tenant principals and ACLs matches a pooled model. *Instead:* the broker follows the model chosen for it.
- **"One model for the whole system."** *Reason:* resources face different forces. *Instead:* a model per resource; mixed and tiered are normal.
- **"Offboarding is deleting the tenant's rows."** *Reason:* copies live in indexes, caches, event logs and backups. *Instead:* find and delete everywhere, or destroy the tenant's key.
- **"The deployment view is finished; write the tenancy design to match it."** *Reason:* the tenancy model decides the deployment topology, so it comes first (D047-7). *Instead:* decide the model, then revise the deployment view to follow it; per-tenant namespaces appear only where the model siloes compute.
- **"Support can move a tenant to a dedicated setup by hand."** *Reason:* manual moves drift and don't scale; tier change is part of the lifecycle (Golding). *Instead:* the control plane automates it: copy, cut over, re-route.
- **"Read cost per tenant off the cloud bill tags."** *Reason:* tags only see dedicated resources. *Instead:* tags for silos; for the pool, apportion from per-tenant consumption the services record.
- **"Put the tenant id on every metric."** *Reason:* thousands of tenants explode metric cardinality. *Instead:* tenant on spans and logs; per-tenant metrics bounded (top tenants, tiers) and usage events for metering.

## References

| Question | File |
|---|---|
| Silo, pool, bridge, mixed, tiered; partitioning per store type; the forces in depth | `./references/deployment-models.md` |
| Enforcement at each layer for each model; the cross-tenant test | `./references/isolation-enforcement.md` |
| Control plane, onboarding, tier change, offboarding, metering, fleet operations | `./references/control-plane-and-lifecycle.md` |
| What each framework does and does not require | `./resources/compliance-basis.md` |
| The artifact skeleton | `./templates/multi-tenancy-design.md` |
| Checking before hand-off | `./resources/checklist.md` |
