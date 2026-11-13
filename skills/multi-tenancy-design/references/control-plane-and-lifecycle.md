# Control Plane and Tenant Lifecycle

Reference for `multi-tenancy-design`. Self-contained: the control plane and application plane, onboarding for every model, tier changes, offboarding and deletion, metering and cost per tenant, and running a fleet of silos. Grounded in Golding (`research/software-architecture/building-multi-tenant-saas-golding.md`); provisioning mechanics are platform-engineer's (`opentofu-module`, `gitops-workflow`, `environment-config`).

## 1. Two Planes

| Plane | Holds | Tenancy |
|---|---|---|
| **Control plane** | Onboarding, the tenant registry (each tenant's tier, state, region, where its resources live), identity set-up, metering and billing feed, tenant-aware operations, the admin console | One, global; not itself multi-tenant |
| **Application plane** | The product's services and stores | Whatever silo, bridge and pool mix the model chose |

**The control plane manages tenants and never reads tenant data.** It holds metadata (registry, usage records), and acts on the application plane through provisioning and configuration. In Hard Parts terms the application plane is the single owner of tenant data and the control plane delegates (`software-architecture-hard-parts-ford.md`). Operator tools that query tenant databases directly break this.

SaaS is an operating model (Golding): the provider onboards, upgrades, observes and prices the whole fleet as one system. Separately hand-managed copies per customer are managed hosting.

## 2. Onboarding (Every Model)

One automated flow, owned by the control plane, the same shape for every tier:

```
Onboarding request
  1. Create the tenant record in the registry (id, tier, region, state = provisioning)
  2. Identity: create the tenant in the identity provider; tenant id and tier become token claims
  3. Provision what the tier needs:
       pool   → seed rows (settings, first admin), quotas and rate limits for the tier
       bridge → create the schema and its role, run migrations for that schema
       silo   → apply the versioned module and chart with this tenant's values
                (namespace with default-deny, database, key, broker, ingress if contracted)
  4. Apply the tier's policies (throttling, features, retention)
  5. Health check, then state = active
```

Idempotent and versioned: re-running it changes nothing when the tenant already matches. Never a runbook of manual steps.

## 3. States

```
provisioning ─▶ active ─▶ suspended ─▶ active
                  │           │
                  ├─▶ changing tier ─▶ active
                  │           │
                  └───────────┴─▶ offboarding ─▶ deleted
```

| State | What happens |
|---|---|
| provisioning | Onboarding flow running |
| active | Serving; included in upgrades |
| suspended | Sign-in blocked, data kept (non-payment, security hold); silo workloads scaled to zero |
| changing tier | Moving between pool and silo (§ 4) |
| offboarding | Export, then deletion (§ 5) |
| deleted | A deletion record for the customer and the audit trail |

## 4. Tier Change

Designed with onboarding, not after the first customer asks:
- **Pool → silo:** provision the silo; copy the tenant's data (the tenant-leading key makes it findable); dual-write or pause writes briefly; switch the registry entry so routing sends the tenant to the silo; verify; delete the tenant's data from the pool (§ 5).
- **Silo → pool:** the reverse; check the pool's capacity and the tenant's load first.
- The token's tier claim changes at the switch; caches keyed by tenant are flushed.

## 5. Offboarding and Deletion

1. **Export** in the agreed format (contract handover, or a data subject request).
2. **Delete:**
   - **Silo:** destroy the resources with the same module in reverse; expire or hand over backups per contract; revoke credentials and keys.
   - **Pool or bridge:** remove the tenant's data from every place it lives: tables (or the schema), search indexes, caches, object storage prefixes, event logs and topics (compaction or retention), analytics copies, backups. Backups are the hard part: either restore-and-purge procedures, or **per-tenant encryption keys** whose destruction makes every remaining copy unreadable (crypto-shredding, general practice).
3. Record the deletion: what was deleted where, and when.

## 6. Metering, Metrics, Cost per Tenant

Three different things (Golding):
- **Metrics:** operational and business insight, sliced by tenant and tier (who is affected, who causes load).
- **Metering:** usage records that feed billing (API calls, storage, seats).
- **Cost per tenant:** what a tenant costs to serve. In a silo, from resource tags. In a pool, estimated from per-tenant consumption the services record (requests, storage, compute time), apportioned against the pool's bill.

Without cost per tenant the business can't tell whether a tier makes money, or spot a tenant whose usage spikes.

## 7. Noisy Neighbour and Tiers

Layered (Golding): per-tenant and per-tier rate limits and quotas at the entry point; separate queues or worker pools for higher tiers; scaling that accounts for tenant load; and, for a tenant that can't be contained, a move to a silo (§ 4). Tiers are a product decision; the architecture enforces what each promises.

## 8. Running a Fleet of Silos

Only when the model siloes something per tenant:
- **One source of desired state:** every silo renders from the same module and chart versions; per-tenant values are the only variation (`environment-config`). A hand-edited tenant is drift, treated as an incident.
- **Upgrades in waves:** a canary tenant, a small wave, then the fleet (`canary-deployment`); never all at once. The registry records each tenant's version.
- **Bounded version skew** (N and N−1): event schemas and APIs stay compatible across the window (`event-driven-patterns`), which also makes per-tenant rollback safe.
- **Delivery blast radius:** a reconciliation agent (or root application) per tenant or per pod, so a bad sync reaches one tenant, not the fleet (`gitops-workflow`).
- **Cost tags** on every silo from day one.
