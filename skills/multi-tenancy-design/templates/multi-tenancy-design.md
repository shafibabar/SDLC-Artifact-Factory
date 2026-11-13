---
name: multi-tenancy-design
product: [product slug]
version: 1.0.0
phase: design
owner: enterprise-architect
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: the tenancy model per resource, the tiers, and how isolation is enforced]
tenancy-model: [pool | bridge | silo | mixed]
traces-to: [ideate/nfr-specification.md, design/context-map.md, (data classification, compliance design, contracts)]
---

# Multi-Tenancy Design for [Product]

<!-- Path: artifacts/<product>/design/architecture/multi-tenancy-design.md. Only for a multi-tenant product.
     Decided before the container diagram's deployment view. No default model: every row names its forces.
     Lean: the Model table, Isolation table and Lifecycle can each be a few lines. -->

**Readers:** [enterprise-architect, security-architect, data-architect, platform-engineer, the product owner]
**Question it answers:** for each resource, is it shared or dedicated, what stops one tenant reaching another's, and how does a tenant join, change tier and leave?

## Inputs

- **Profile:** [lean | standard | enterprise]
- **Tenants:** [count now, expected growth, size spread]
- **Data classification:** [highest class held per tenant]
- **Residency and obligations:** [regions required; laws; contract clauses]
- **Tiers:** [none | tier names]

## Model

- **Overall:** [pool | bridge | silo | mixed], [one line on why]

| Resource | Model | Forces | Isolation mechanism |
|---|---|---|---|
| [compute / each data store / broker / cache / search / object storage / telemetry] | [pool / bridge / silo] | [the forces that decided it] | [what enforces it] |

## Compliance Basis

| Push | Source | Effect |
|---|---|---|
| [what is required] | [law: … / contract: <customer>, <clause> / tier: <tier> / risk: … / framework: none] | [region / silo for <resource> / none] |

## Tiers and Noisy Neighbour

| Tier | Promises | Resources | Noisy-neighbour controls |
|---|---|---|---|
| [tier, or "all tenants"] | [what the price point promises] | [pooled / which are siloed] | [rate limits, quotas, separate queues] |

## Isolation Enforcement

| Layer | Mechanism |
|---|---|
| Tenant context | [from the verified token's tenant claim; never client-supplied; no tenant → refuse] |
| Database | [forced RLS, non-owner role, SET LOCAL / schema + role / own database] |
| Broker | [principals + ACLs, tenant on events / own namespace] |
| Network | [zero trust / default-deny between tenant namespaces] |
| Telemetry | [tenant attributes; bounded per-tenant metrics] |

- **Cross-tenant test (release gate):** [tenant A's token against tenant B's resources at the API and data layer, expecting refusal]

## Control Plane

- **Holds:** [registry, onboarding, identity set-up, metering, admin]
- **Never reads tenant data:** [how that is enforced]

## Lifecycle

- **Onboarding:** [per tier: what is created]
- **Tier change:** [pool → silo and back: copy, cut-over, routing]
- **Suspension:** [what stops, what is kept]
- **Offboarding:** [export; deletion everywhere: tables, indexes, caches, object storage, event logs, backups, or per-tenant key destruction]

## Metering and Cost per Tenant

- **Metering:** [usage recorded for billing]
- **Cost per tenant:** [silo: resource tags / pool: per-tenant consumption apportioned]

## For the Deployment View

[What `container-diagram`'s deployment view draws: regions, pools or pods, silo stamps only for the tenants or tiers above.]

## Related ADRs

- [ADR-nnn: tenancy model]

## Open Questions

- [an assumption or missing input — who answers it | none]
