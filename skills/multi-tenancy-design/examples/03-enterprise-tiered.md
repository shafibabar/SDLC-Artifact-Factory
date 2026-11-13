# Example 3 — Enterprise: A Tiered Model with Silo Stamps for Contract-Bound Tenants

Self-contained. **ShelfSync** runs stock, ordering and controlled-drug registers for pharmacy chains. **350 chains** on the Standard plan (5 to 60 branches), and **two national chains** whose contracts require dedicated infrastructure and customer-managed encryption keys. Customers in the UK and the EU. **Enterprise** profile, five teams. Data includes controlled-drug registers (*restricted*). Default stack.

## Input

> **User:** "The two national chains need their own stamps, so let's give everyone a stamp and run one model. When a chain leaves, delete its namespace. And finance will read cost per customer off the cloud bill tags."

## Working it

- **Forces.** 352 stamps would multiply baseline cost and idle capacity by 350 and make every release a 352-target rollout. Only two tenants have a source pushing them to a silo: their contracts. So the model is **tiered**: pooled Standard tier per region, full-stack silo stamps for the two contract-bound chains.
- **Declined:** a stamp for everyone (the forces above; the two contracts don't apply to the other 350).
- **Declined:** "delete the namespace" as offboarding. A Standard chain has no namespace; its data is in shared tables, indexes, topics and backups. Offboarding finds it by the tenant-leading key, deletes it everywhere, and destroys the chain's data key so backup copies become unreadable.
- **Declined:** cost from tags alone. Tags show the two stamps' cost; for the pool, cost per chain is apportioned from per-tenant consumption the services record.
- **Tier change** designed now: a chain can move from the pool to its own stamp.

## Output: `artifacts/shelfsync/design/architecture/multi-tenancy-design.md`

````markdown
---
name: multi-tenancy-design
product: shelfsync
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-07-20
summary: ShelfSync pools its 350 Standard chains per region and gives two contract-bound national chains full-stack silo stamps with their own keys; tier change and pooled deletion are automated.
tenancy-model: mixed
traces-to: [ideate/nfr-specification.md, design/context-map.md, design/data-classification.md, design/compliance-design.md, contracts/national-chains-schedule-4.md]
---

# Multi-Tenancy Design for ShelfSync

**Readers:** enterprise-architect, security-architect, data-architect, platform-engineer, the product owner
**Question it answers:** for each resource and tier, is it shared or dedicated, what stops one chain reaching another's, and how does a chain join, change tier and leave?

## Inputs

- **Profile:** enterprise
- **Tenants:** 350 Standard chains (5–60 branches); 2 national chains (900+ branches each)
- **Data classification:** restricted (controlled-drug registers)
- **Residency and obligations:** EU chains' data in the EU; the two national chains' contracts (schedule 4) require dedicated infrastructure and customer-managed keys
- **Tiers:** Standard (pooled); Dedicated (two named chains, by contract)

## Model

- **Overall:** mixed (tiered): Standard pooled per region; Dedicated as full-stack silo stamps

| Resource | Model | Forces | Isolation mechanism |
|---|---|---|---|
| App services, Standard | pool | cost to serve, one release, onboarding speed | tenant context from the token; per-tenant rate limits |
| PostgreSQL, Standard (per region) | pool | cost; restricted data under an enforced mechanism | forced row-level security, non-owner role, `SET LOCAL`; a data key per chain for backup crypto-shredding |
| Redpanda, Standard (per region) | pool | cost; no contract push | per-service principals, topic ACLs, `tenantid` on every event |
| Search index, Standard | pool | cost | tenant filter from tenant context; tenant id on every document |
| Object storage, Standard | pool | cost | tenant prefix, prefix-scoped policies |
| Full stack, Dedicated (2 chains) | silo | contract: schedule 4 (dedicated infrastructure, customer-managed keys) | own namespace with default-deny, own PostgreSQL, Redpanda, index and bucket; keys held in the customer's key service |
| Telemetry | pool, silo for Dedicated | operations; Dedicated contract excludes shared processing | tenant attribute; Dedicated telemetry stays in its stamp |

## Compliance Basis

| Push | Source | Effect |
|---|---|---|
| Dedicated infrastructure and customer-managed keys | contract: national chains, schedule 4 | silo stamp for those two chains only |
| EU chains' data stays in the EU | law: GDPR transfer rules, met by policy; contract: EU terms | EU region pool |
| Restricted classification | risk: controlled-drug register exposure | enforced isolation and the cross-tenant gate on the pool |
| SOC 2 report | framework: SOC 2 attests access controls; no deployment model | none beyond the mechanisms here |

## Tiers and Noisy Neighbour

| Tier | Promises | Resources | Noisy-neighbour controls |
|---|---|---|---|
| Standard | shared service, 99.9% | pooled per region | per-tenant rate limits; month-end stock reports on a queue with per-tenant concurrency caps; tenant-leading keys checked for hot chains |
| Dedicated | dedicated infrastructure, own keys, 99.95% | full-stack silo | none needed between tenants; ordinary scaling inside the stamp |

## Isolation Enforcement

| Layer | Mechanism |
|---|---|
| Tenant context | from the verified token's tenant claim; for Dedicated also checked against the routed stamp; never client-supplied; no tenant → refuse |
| Database | Standard: forced RLS, non-owner role, `SET LOCAL`; Dedicated: own instance and credentials, connection chosen by tenant, fail closed |
| Broker | Standard: shared per region with principals and ACLs; Dedicated: own cluster in the stamp. The shared cluster is not a leak: the Standard broker is pooled by design |
| Network | Standard: zero trust; Dedicated: default-deny between the stamp's namespace and everything else |
| Telemetry | tenant and tier attributes; per-tenant metrics only for the two stamps |

- **Cross-tenant test (release gate):** at every release, Standard chain A's token against chain B's ids at the API and data layer; a pod in each stamp cannot reach the pool's database or the other stamp.

## Control Plane

- **Holds:** tenant registry (tier, region, state, where each tenant's resources live), onboarding and tier-change workflows, usage records, stamp versions
- **Never reads tenant data:** it acts through provisioning and registry changes; its roles have no grants on tenant tables or stamp databases

## Lifecycle

- **Onboarding:** Standard: registry entry, identity with tenant and tier claims, seed rows, quotas. Dedicated: also apply the versioned module and chart with the chain's values, keys from the customer's key service, health check
- **Tier change:** pool → stamp: provision the stamp; copy the chain's rows by tenant key; pause writes for the cut-over window; switch the registry entry so routing sends the chain to the stamp; verify; delete from the pool. Stamp → pool is the reverse. Automated by the control plane, not by ticket
- **Suspension:** sign-in blocked, data kept; a stamp scales to zero
- **Offboarding:** Standard: export, then delete by tenant key from tables, search, object storage, caches and topics, and destroy the chain's data key so backup copies are unreadable. Dedicated: export, destroy the stamp with the module in reverse, revoke access to the customer's keys. Deletion record issued

## Metering and Cost per Tenant

- **Metering:** active branches per month (billing unit), stored per tenant by the control plane
- **Cost per tenant:** Dedicated: resource tags on each stamp. Standard: apportioned from per-tenant request counts, storage and report runs, against the regional pool's bill

## For the Deployment View

Per region (UK, EU): one pooled Standard deployment. Two Dedicated stamps (one UK, one EU), each drawn once with "same shape as the pool" plus its own data stores. Fleet: two stamps upgraded after the pool, one at a time.

## Related ADRs

- ADR-007: Tiered tenancy, pooled Standard, silo stamps for contract-bound chains

## Open Questions

- Cut-over window for a pool → stamp move: the product owner to agree an acceptable pause with each chain
````

## Why this is right

- Two contracts pushed two tenants to a silo; the other 350 stay pooled for stated forces. The push is recorded as a contract, not "compliance".
- The shared broker is explained, not removed: it matches the pooled Standard tier.
- Pooled offboarding reaches backups (key destruction), tier change is designed and automated, and pooled cost comes from consumption.
- The deployment view is told exactly what to draw, which is the order D047-7 requires.
- `validate-multi-tenancy-design.sh` exits clean on the artifact.
