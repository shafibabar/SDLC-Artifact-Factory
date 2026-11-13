# Example 2 — Standard: A Schema per Tenant, Pooled Compute and Broker

Self-contained. **Onboardly** handles new-starter onboarding for mid-sized companies: offer letters, right-to-work checks, equipment requests, first-week schedules. **80 customers** (200 to 3,000 staff each), growing by about 20 a year. **Standard** profile, three teams. The data includes passport scans and bank details (*restricted*). Customers in the UK and the EU. Two plans, Core and Plus, differing in features. Several customers' procurement teams ask for per-customer restore ("roll back our data to last Tuesday") and a full export on request. Default stack.

## Input

> **User:** "Security wants each customer's Redpanda topics on a separate cluster, because a shared broker is a cross-tenant leak. And GDPR means our EU customers each need their own stamp."

## Working it

- **Forces.** 80 customers is too many for a stamp each (80 copies to upgrade and pay for), and few enough for a schema each inside one PostgreSQL instance per region. Per-customer restore and export are a real need that a bridge serves well: one schema is one restorable, exportable unit. Restricted data: enforced isolation at the data layer.
- **Declined:** a broker cluster per customer. The broker is pooled, so a shared cluster matches the model; it would be a leak only if the model had siloed the broker. Isolation is per-service principals with topic ACLs and the tenant on every event.
- **Declined:** a stamp per EU customer. GDPR restricts transfers out of the EEA; it doesn't require dedicated infrastructure. EU customers' data stays in an EU region, served by that region's pool.
- **Model:** mixed: bridge for PostgreSQL, pool for compute, broker, documents and search; one deployment per region.

## Output: `artifacts/onboardly/design/architecture/multi-tenancy-design.md`

````markdown
---
name: multi-tenancy-design
product: onboardly
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-06-11
summary: Onboardly gives each customer its own PostgreSQL schema in a per-region instance, pools compute, broker, documents and search, and keeps EU data in the EU region.
tenancy-model: mixed
traces-to: [ideate/nfr-specification.md, design/context-map.md, design/data-classification.md, design/compliance-design.md]
---

# Multi-Tenancy Design for Onboardly

**Readers:** enterprise-architect, security-architect, data-architect, platform-engineer, the product owner
**Question it answers:** for each resource, is it shared or dedicated, what stops one customer reaching another's, and how does a customer join, change plan and leave?

## Inputs

- **Profile:** standard
- **Tenants:** 80 companies, 200–3,000 staff; +20 a year
- **Data classification:** restricted (passport scans, bank details)
- **Residency and obligations:** EU customers' data in the EU; customers ask for per-customer restore and export
- **Tiers:** Core and Plus (features only)

## Model

- **Overall:** mixed: a bridge for relational data, pool for everything else, one deployment per region (UK, EU)

| Resource | Model | Forces | Isolation mechanism |
|---|---|---|---|
| App services | pool | cost, operations, one release for all | tenant context from the token |
| PostgreSQL (one instance per region) | bridge | per-customer restore and export; restricted data; 80 schemas fit one instance | a schema per customer, per-customer role with grants only on its schema, `search_path` set per connection checkout |
| Redpanda (one cluster per region) | pool | cost; no contract asks for separate streams | per-service principals, topic ACLs, `tenantid` on every event |
| Documents (object storage) | pool | cost | tenant prefix, prefix-scoped presigned URLs |
| Search index | pool | cost | tenant filter added by the query layer from tenant context; a tenant id on every document |
| Telemetry | pool | operations | tenant attribute on spans and logs |

## Compliance Basis

| Push | Source | Effect |
|---|---|---|
| EU customers' data stays in the EU | law: GDPR transfer rules, met by policy; contract: EU customers' terms | EU region deployment; no per-customer stamp |
| Per-customer restore and export | contract: procurement requirement of several customers | bridge for PostgreSQL |
| SOC 2 report | framework: SOC 2 attests access controls; no deployment model | none beyond the mechanisms here |

## Tiers and Noisy Neighbour

| Tier | Promises | Resources | Noisy-neighbour controls |
|---|---|---|---|
| Core | features | pooled; own schema | per-tenant rate limits at the gateway |
| Plus | more features, bulk imports | pooled; own schema | bulk imports on a separate worker pool with a per-tenant concurrency cap |

- **Partition key and hot tenant:** PostgreSQL is split by schema, so a large customer is one large schema, not a hot range in shared tables; Redpanda topics are keyed by `tenantid` + employee id so one customer's January hiring burst spreads across partitions instead of filling one. The largest customer (3,000 staff) is about 15× the smallest; its bulk imports are capped per tenant. A customer that saturates the regional instance moves to its own instance (a silo for that store) by the tier-change path

## Isolation Enforcement

| Layer | Mechanism |
|---|---|
| Tenant context | from the verified token's tenant claim; never client-supplied; no tenant → refuse |
| Database | schema per customer; the connection takes the customer's role and `search_path` from tenant context; unknown tenant fails closed |
| Broker | shared cluster per region; per-service principals with topic ACLs; consumers set tenant context from `tenantid` before touching data |
| Network | zero trust; no tenant boundary at the network |
| Telemetry | tenant attribute; per-plan metrics |

- **Cross-tenant test (release gate):** customer A's token against B's employee, document and search ids expects 404; A's database role cannot select from B's schema; an event with B's `tenantid` processed in A's context is rejected.

## Control Plane

- **Holds:** tenant registry (id, plan, region, schema, state), onboarding, usage records
- **Never reads tenant data:** its role has no grants on customer schemas

## Lifecycle

- **Onboarding:** registry entry in the customer's region, identity set-up with tenant claim, schema and role created, migrations run for that schema
- **Tier change:** Core ↔ Plus is a registry and claim change; no data moves
- **Suspension:** sign-in blocked, schema kept
- **Offboarding:** export (schema dump and documents), then drop the schema and role, delete the document prefix and search documents, compact the tenant's events; backups expire after 30 days, or earlier by destroying the customer's backup encryption key

## Metering and Cost per Tenant

- **Metering:** active employees onboarded per month (the billing unit)
- **Cost per tenant:** apportioned from per-tenant request counts, schema size and document storage

## For the Deployment View

One deployment per region (UK, EU): pooled services, one PostgreSQL instance holding the region's schemas, one Redpanda cluster. No per-customer stamps.

## Related ADRs

- ADR-005: Schema per customer for relational data

## Open Questions

- Whether any EU customer's contract asks for more than in-region storage (sales to confirm with the two who raised it)
````

## Why this is right

- The bridge is chosen for a stated reason (restore and export per customer), and only for the store where that reason applies.
- The shared broker was kept, with the reason: it is pooled by design and enforced by ACLs.
- Residency was met by a region, and the remaining doubt is an open question with an owner, not a stamp built on assumption.
- `validate-multi-tenancy-design.sh` exits clean on the artifact.
