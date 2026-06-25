---
name: multi-tenancy-design
description: >
  Teaches how to design physical multi-tenancy for a private-deployment SaaS
  product — covering the three tenancy models (shared, schema-per-tenant,
  database-per-tenant / infrastructure-per-tenant), when to use each, how
  physical isolation is enforced at the infrastructure, database, event stream,
  and API levels, and how tenant context is propagated across service boundaries.
  Physical multi-tenancy is the default model for this plugin's first product.
  Used by the enterprise-architect agent during the Design phase.
version: 1.0.0
phase: design
owner: enterprise-architect
tags: [design, architecture, multi-tenancy, isolation, security, compliance]
---

# Multi-Tenancy Design

## Purpose

Multi-tenancy design defines how a single product deployment serves multiple customers (tenants) while keeping their data, processing, and infrastructure separate. The isolation model is a security and compliance decision first, and an architecture decision second.

For the first product (Data Estate Mapping & Compliance Intelligence), physical multi-tenancy is mandatory — the product processes customers' most sensitive data, and no tenant data may ever be accessible to or commingled with another tenant's data, even at the infrastructure level.

---

## The Three Tenancy Models

### Model 1: Shared Everything (Logical Multi-Tenancy)

All tenants share the same infrastructure, database, and application instances. Tenant isolation is enforced only by application-level filtering (a `tenant_id` column on every table).

| | |
|---|---|
| **Isolation level** | Logical — enforced by application code |
| **Cost** | Lowest — single infrastructure footprint |
| **Risk** | Highest — a query missing a `tenant_id` filter leaks data across tenants; a bug in application code breaks isolation |
| **Compliance fit** | Unsuitable for SOC 2, GDPR, or any compliance framework requiring physical isolation |
| **Use when** | Non-sensitive data; commodity SaaS; cost is the primary constraint |

**Not suitable for this plugin's first product.**

---

### Model 2: Schema-Per-Tenant (Logical Isolation, Single Database)

All tenants share the same database instance but have separate schemas. Application code connects to the tenant's schema. No `tenant_id` column needed — schema separation provides the isolation.

| | |
|---|---|
| **Isolation level** | Schema-level — enforced by database schema separation |
| **Cost** | Low-medium — single database instance; separate schemas |
| **Risk** | Medium — schema separation prevents accidental cross-tenant queries; but the database process is shared, and a database-level breach affects all tenants |
| **Compliance fit** | Acceptable for some compliance frameworks; not for frameworks requiring physical infrastructure isolation |
| **Use when** | Moderate isolation requirements; regulatory frameworks that accept schema-level separation |

---

### Model 3: Infrastructure-Per-Tenant (Physical Multi-Tenancy)

Each tenant has dedicated infrastructure: their own Kubernetes namespace (or cluster), their own database instance, their own message broker topics (or cluster), and their own service instances.

| | |
|---|---|
| **Isolation level** | Physical — separate processes, separate storage, separate network |
| **Cost** | Highest — infrastructure footprint multiplies by tenant count |
| **Risk** | Lowest — a breach in one tenant's infrastructure does not affect others |
| **Compliance fit** | Required for SOC 2 physical isolation controls, GDPR data residency, financial services, healthcare |
| **Use when** | Sensitive data; regulated industries; customer-controlled deployment; Zero Trust architecture |

**This is the required model for this plugin's first product.**

---

## Physical Multi-Tenancy Architecture

### Deployment Topology

Each tenant gets a dedicated deployment:

```
Customer A                           Customer B
┌─────────────────────────┐         ┌─────────────────────────┐
│ Kubernetes Namespace:   │         │ Kubernetes Namespace:   │
│ tenant-customer-a       │         │ tenant-customer-b       │
│                         │         │                         │
│  [All services]         │         │  [All services]         │
│  [PostgreSQL instance]  │         │  [PostgreSQL instance]  │
│  [Redpanda namespace]   │         │  [Redpanda namespace]   │
│                         │         │                         │
│  Customer A's own VPC   │         │  Customer B's own VPC   │
│  or dedicated cloud     │         │  or dedicated cloud     │
│  account                │         │  account                │
└─────────────────────────┘         └─────────────────────────┘
         │                                    │
         │ No network path between tenants    │
         └──────────────── ✗ ────────────────┘
```

### Tenant Context Propagation

In physical multi-tenancy, the `tenant_id` is not needed on every database row — the database instance itself is tenant-scoped. However, `tenant_id` is still included in:
- All Domain Events (for audit and replay purposes)
- All JWT claims (for identity continuity)
- All audit log entries
- All API request logs

The `tenant_id` in these contexts is not for filtering — it is for traceability and audit.

### Database Isolation

| Layer | Isolation mechanism |
|---|---|
| Database instance | Separate PostgreSQL instance per tenant |
| Database credentials | Separate service account per tenant database |
| Connection pooling | Separate connection pool per tenant |
| Backup | Separate backup schedule and encryption key per tenant |
| Encryption keys | Tenant-managed keys (BYOK) where required |

### Network Isolation

- No network path between tenant namespaces
- Linkerd service mesh enforces mTLS within the tenant namespace
- No shared load balancer across tenants — each tenant has a dedicated ingress
- Tenant-specific subdomain routing: `[tenant-id].app.example.com` or customer-controlled domain

### Event Stream Isolation

- Separate Redpanda namespace (or cluster) per tenant — no shared topics
- Topic names include tenant prefix: `[tenant-id].[bounded-context].[event-name]`
- Consumer groups are tenant-scoped: `[tenant-id].[service].[consumer-group]`

---

## Tenant Provisioning

New tenant provisioning is automated via Infrastructure as Code (OpenTofu):

```
Tenant onboarding request
        ↓
OpenTofu module: create-tenant
  1. Create Kubernetes namespace: tenant-[id]
  2. Apply Helm chart: all services with tenant-specific values.yaml
  3. Create PostgreSQL instance: run migrations
  4. Create Redpanda namespace: create topics
  5. Create service accounts and credentials (stored in secrets manager)
  6. Configure Linkerd policies for namespace
  7. Create ingress with tenant subdomain
  8. Register tenant in tenant registry service
        ↓
Health check: confirm all services ready
        ↓
Notify: tenant ready for onboarding
```

---

## Control Plane vs Data Plane

Physical multi-tenancy requires a separation between the control plane (manages tenants) and the data plane (processes tenant data):

| Plane | Responsibility | Isolation |
|---|---|---|
| **Control Plane** | Tenant provisioning, billing, auth federation, global config | Shared — this is the operator's infrastructure |
| **Data Plane** | All tenant data processing, storage, event streaming | Physically isolated per tenant |

The Control Plane never has access to tenant data. It only manages metadata: which tenants exist, their configuration, their subscription status. The data plane is entirely within the tenant's infrastructure boundary.

---

## Tenant-Aware API Design

For physical multi-tenancy with dedicated deployments, the tenant context is resolved at the routing layer, not the application layer:

```
[tenant-id].api.example.com → Ingress → correct tenant's services
```

The services themselves do not need to resolve "which tenant is this?" — the routing guarantees they are always talking to their own tenant's infrastructure.

The JWT still carries tenant context for audit purposes. Services validate that the JWT `tenant_id` claim matches the expected tenant (a defence-in-depth check).

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Isolation level documented | Isolation model (physical/schema/shared) is explicitly stated with justification | Isolation assumed without documentation |
| No cross-tenant network paths | Architecture diagram shows no network path between tenant namespaces | Shared load balancers, shared databases, or shared message broker topics |
| Tenant provisioning automated | IaC module defined for tenant provisioning | Manual provisioning steps |
| Control/data plane separated | Control plane cannot access tenant data | Control plane has read access to tenant databases |
| Encryption per tenant | Separate encryption keys per tenant documented | Shared encryption keys |
| Tenant ID in events and logs | All events and audit logs carry `tenant_id` | Events or logs with no tenant attribution |

---

## Output Format

```markdown
---
artifact: multi-tenancy-design
product: [product name]
tenancy-model: [physical | schema | shared]
version: 1.0.0
phase: design
created: [date]
owner: enterprise-architect
---

# Multi-Tenancy Design

## Tenancy Model
[Model selected and justification — reference NFR IDs that drove the decision]

## Deployment Topology
[ASCII diagram showing per-tenant isolation]

## Isolation Enforcement
| Layer | Mechanism | Configuration location |
|---|---|---|

## Tenant Provisioning
[Step-by-step provisioning flow with IaC references]

## Control Plane vs Data Plane Boundary
[What the control plane can and cannot access]

## Tenant Context Propagation
[How tenant_id flows through JWT, events, logs, and audit records]

## Related ADRs
[ADR IDs for decisions made during multi-tenancy design]
```
