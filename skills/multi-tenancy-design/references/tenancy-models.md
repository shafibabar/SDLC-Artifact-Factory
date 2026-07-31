# Tenancy Models — Full Decision Table

Reference for `multi-tenancy-design`. Self-contained: the three isolation models,
their trade-offs across every axis that matters to the decision, and the research
that grounds each claim. Read this when you must **defend** a model choice with
NFR and compliance evidence rather than adopt a house default.

The isolation model is a security and compliance decision first, an architecture
decision second. You do not pick the cheapest model and hope compliance accepts
it; you find the weakest model the data classification and the compliance
framework permit, then pay its cost. The four criteria that decide it:

- **Blast radius** — what a breach, a bug, or a misconfiguration in one tenant's
  boundary can reach. This is the security lens.
- **Compliance fit** — does the applicable framework (SOC 2, GDPR data residency,
  HIPAA, PCI) mandate physical separation, or accept logical separation?
- **Cost per tenant** — does the infrastructure footprint multiply by tenant
  count, or is it amortised across all tenants?
- **Noisy-neighbour behaviour** — can one tenant's load (a huge scan, a runaway
  ingest) degrade another tenant's latency or availability?

---

## Model 1 — Shared-Everything (logical, discriminator column)

All tenants share the same infrastructure, database instance, and application
processes. Every row of every table carries a `tenant_id` discriminator column,
and every query must filter on it. The disciplined version of this model backs
the column with PostgreSQL **Row-Level Security (RLS)** so the filter is enforced
by the database, not by remembering to write `WHERE tenant_id = $1`.

```sql
-- Defence-in-depth for shared-everything: RLS makes the filter non-optional.
ALTER TABLE data_asset ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON data_asset
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
-- The app sets the GUC per connection/transaction:
--   SET LOCAL app.tenant_id = '...';
```

| Axis | Assessment |
|---|---|
| Isolation strength | Weakest. Logical only — enforced by app code and (if used) RLS. |
| Blast radius | Whole fleet. One missing filter, one RLS bypass, one `SECURITY DEFINER` function, or one superuser query exposes every tenant. |
| Cost per tenant | Lowest. A single footprint amortised across all tenants; adding a tenant is a row, not infrastructure. |
| Operational complexity | Lowest to run, highest to get *correct* — every code path is a potential leak, so it needs relentless query review and RLS coverage. |
| Compliance fit | Unsuitable for SOC 2 physical-isolation controls, GDPR data residency, or any framework requiring infrastructure separation. Acceptable for non-sensitive commodity SaaS. |
| Noisy-neighbour | Severe and unmitigated by default — all tenants share one query planner, one buffer cache, one connection limit. |

**Use when:** data is non-sensitive; the tenant count is large and each tenant is
small; cost is the binding constraint; no framework mandates separation.

**Kleppmann connection:** the `tenant_id` column is a partitioning key. Ch. 6's
hot-key/skew failure mode applies directly — one large tenant becomes a hot
partition that degrades everyone, and the model has no isolation boundary to
contain it. That is the noisy-neighbour row above, in Kleppmann's vocabulary.

---

## Model 2 — Shared-Schema-Per-Tenant (logical, one instance)

One database instance (and often one Kubernetes namespace and one broker), but a
**separate schema per tenant**. The application resolves the tenant, then routes
the connection to that tenant's schema (`SET search_path` or a schema-qualified
connection). No `tenant_id` column is needed for isolation — schema separation
prevents accidental cross-tenant queries because a query in `tenant_acme`'s
schema simply cannot name `tenant_globex`'s tables without qualifying across
schemas.

| Axis | Assessment |
|---|---|
| Isolation strength | Middle. Schema separation stops accidental cross-tenant reads, but the DB *process*, host, buffer cache, and superuser are shared. |
| Blast radius | The shared database instance. A DB-engine breach, a compromised superuser, or a backup mix-up affects all tenants in that instance; app-layer bugs are contained to one schema. |
| Cost per tenant | Low-to-medium. One instance's fixed cost amortised, plus a per-schema increment (migrations run N times, connection routing overhead). |
| Operational complexity | Medium. Schema-per-tenant migrations, per-schema connection routing, and a ceiling on schemas-per-instance before you must shard tenants across instances. |
| Compliance fit | Acceptable for frameworks that accept logical separation; **not** for those mandating physical infrastructure isolation. A common "good enough" tier for mid-sensitivity B2B SaaS. |
| Noisy-neighbour | Present but bounded — still one query planner and one connection pool, though per-schema resource governance is possible. |

**Use when:** moderate isolation requirements; a framework that accepts
schema-level separation; a tenant count high enough that a full stamp per tenant
is uneconomic but low enough to fit within an instance's schema ceiling.

**Ford *Hard Parts* connection:** this is the granularity middle ground — the
security disintegrator force is present but not strong enough to justify full
physical separation, so you separate the schema (the data model) without
separating the deployment quantum.

---

## Model 3 — Physical Isolation, the Stamp (dedicated per tenant)

Each tenant gets a **stamp**: a complete, dedicated instance of the platform —
own Kubernetes namespace or cluster, own PostgreSQL instance, own Redpanda
namespace or cluster, own service instances, own ingress, own credentials and
encryption keys. There is no shared data-plane component. This is the repo
default for the Data Estate Mapping & Compliance Intelligence product.

```
Tenant: acme                          Tenant: globex
┌───────────────────────────┐         ┌───────────────────────────┐
│ ns/cluster: tenant-acme   │         │ ns/cluster: tenant-globex │
│  DataAsset / Compliance / │         │  DataAsset / Compliance / │
│  Reporting services       │         │  Reporting services       │
│  PostgreSQL (own instance)│         │  PostgreSQL (own instance)│
│  Redpanda (own namespace) │         │  Redpanda (own namespace) │
│  own ingress + keys       │         │  own ingress + keys       │
└───────────────────────────┘         └───────────────────────────┘
        │  default-deny NetworkPolicy — no path between  │
        └──────────────────── ✗ ─────────────────────────┘
```

| Axis | Assessment |
|---|---|
| Isolation strength | Strongest. Separate processes, storage, network, and keys. |
| Blast radius | One tenant. A breach, a bad migration, or a runaway job is contained to a single stamp; nothing crosses to the fleet. |
| Cost per tenant | Highest. The footprint multiplies by tenant count — every tenant carries its own database, broker, and baseline compute. |
| Operational complexity | Highest — one deployment becomes a fleet (see `references/provisioning-and-stamps.md`): drift control, upgrade waves, per-tenant rollback, and lifecycle automation are mandatory, not optional. |
| Compliance fit | Required for SOC 2 physical-isolation controls, GDPR data residency (a stamp can be pinned to a region), financial services, healthcare, and customer-controlled deployment. |
| Noisy-neighbour | Eliminated by construction — each tenant has its own resources; one tenant's load cannot touch another. |

**Use when:** sensitive data; regulated industries; a physical-isolation or
data-residency commitment; a Zero Trust posture; customer-controlled or
customer-account deployment.

**Ford *Hard Parts* connection (the sharper justification):** the choice of
physical isolation is a **granularity-disintegrator** argument. Two disintegrator
forces dominate — **security** (tenant data requires stricter isolation than a
shared boundary can give) and **fault tolerance** (one tenant's failure must not
take down its neighbours). Naming them this way turns "we always do physical" into
a defensible trade-off record. The Control-Plane-never-touches-tenant-data rule
is structurally a **Single-Owner + Delegate** data-ownership pattern: the tenant's
stamp owns its data; the Control Plane delegates rather than caching or reading it.

**Kleppmann connection:** physical multi-tenancy pre-solves Ch. 6's node-level
sharding problem at the tenant boundary — each tenant is its own single-leader
PostgreSQL instance, so intra-database partitioning is only a concern if a
*single* tenant outgrows one instance. Per-tenant HA (leader-follower replication,
sync vs. async, replication lag) is a deferred, explicitly-named decision handed
to `platform-engineer`, not a silent gap.

---

## The Decision, Summarised

| | Shared-everything | Shared-schema | Physical (stamp) |
|---|---|---|---|
| Isolation | Logical (column + RLS) | Schema | Physical |
| Blast radius | Whole fleet | Shared instance | One tenant |
| Cost/tenant | Lowest | Low–medium | Highest |
| Ops complexity | Low run / high correctness | Medium | Highest (fleet) |
| SOC 2 physical | ✗ | ✗ | ✓ |
| Data residency | Hard | Hard | Per-stamp region pin |
| Noisy-neighbour | Severe | Bounded | Eliminated |
| Repo default? | — | — | ✓ (sensitive data) |

The model is chosen once, per product, from NFRs and compliance obligations —
and then, per the cross-layer consistency principle, it must be enforced
identically at the infrastructure, database, event, and API layers. A model
chosen here but leaked at one layer (see `references/enforcement-layers.md`) is
no isolation at all.
