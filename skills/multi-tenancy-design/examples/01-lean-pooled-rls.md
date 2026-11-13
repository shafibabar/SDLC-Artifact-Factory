# Example 1 — Lean: One Pool, Forced Row-Level Security

Self-contained. **TradeBooks** is bookkeeping for small trades businesses (plumbers, electricians, decorators): invoices, expenses, VAT returns. About **600 businesses** today, each with one to five users, aiming for 3,000. **Lean** profile, three developers, one price plan. The data is business financial records (classified *confidential* by `data-classification`), no card numbers (a hosted payment page). No customer contract asks for anything dedicated. Default stack.

## Input

> **User:** "Our accountant says SOC 2 is coming eventually, so give each business its own database to be safe. And the mobile app already sends the business id in a header, so just use that."

## Working it

- **Forces.** 600 to 3,000 small tenants: a database each multiplies cost and turns three developers into a fleet team. No contract, law or tier asks for dedicated resources. Confidential data needs *enforced* isolation, which a pool provides with forced row-level security.
- **Declined:** a database per business. SOC 2 attests that access controls work; it prescribes no deployment model. Enforced, tested logical isolation is what an auditor examines.
- **Declined:** the business id from a header. Any signed-in user could send another business's id. The tenant comes from the token.
- **Model:** pool everywhere. Tenant key leads every primary key and index.

## Output: `artifacts/tradebooks/design/architecture/multi-tenancy-design.md`

````markdown
---
name: multi-tenancy-design
product: tradebooks
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-05-02
summary: TradeBooks pools every resource across its 600 small-business tenants, isolated by forced row-level security, tenant from the token, and a cross-tenant release gate.
tenancy-model: pool
traces-to: [ideate/nfr-specification.md, design/context-map.md, design/data-classification.md]
---

# Multi-Tenancy Design for TradeBooks

**Readers:** enterprise-architect, security-architect, data-architect, platform-engineer, the product owner
**Question it answers:** for each resource, is it shared or dedicated, what stops one business reaching another's, and how does a business join and leave?

## Inputs

- **Profile:** lean
- **Tenants:** 600 businesses, 1–5 users each; 3,000 expected in two years; the largest is about 20× the smallest
- **Data classification:** confidential (financial records)
- **Residency and obligations:** UK businesses only, UK region; no contract terms on infrastructure
- **Tiers:** none (one plan)

## Model

- **Overall:** pool, because many small tenants, no dedicated-resource push, and cost and operations dominate

| Resource | Model | Forces | Isolation mechanism |
|---|---|---|---|
| App compute (one modular monolith) | pool | cost to serve, three-person operations, onboarding speed | tenant context from the token; per-tenant rate limits |
| PostgreSQL | pool | cost; confidential data protected by an enforced mechanism | forced row-level security, non-owner role, `SET LOCAL` per transaction |
| Receipt images (object storage) | pool | cost | tenant prefix, prefix-scoped access issued by the app |
| Telemetry | pool | operations | tenant id on spans and logs; metrics per plan, not per tenant |

## Compliance Basis

| Push | Source | Effect |
|---|---|---|
| SOC 2 report expected by customers later | framework: SOC 2 attests access controls; no deployment model required | none: enforced logical isolation plus the cross-tenant test as evidence |
| UK data stays in the UK | contract: standard terms of service | UK region |

## Tiers and Noisy Neighbour

| Tier | Promises | Resources | Noisy-neighbour controls |
|---|---|---|---|
| all tenants | one plan | pooled | per-tenant rate limit at the ingress; VAT-return generation on a queue with a per-tenant concurrency cap |

## Isolation Enforcement

| Layer | Mechanism |
|---|---|
| Tenant context | from the verified token's `tenant_id` claim; never from the `X-Business-Id` header or any client-supplied value; no tenant → refuse |
| Database | every tenant table has `tenant_id` leading its key; RLS enabled and forced; app connects as non-owner `tradebooks_app`; `SET LOCAL app.tenant_id` in each transaction |
| Broker | none (in-process events in the monolith) |
| Network | zero trust; the network is not the tenant boundary |
| Telemetry | tenant attribute on spans and logs; no per-tenant metric labels |

- **Cross-tenant test (release gate):** business A's token against business B's invoice, expense and receipt ids at every endpoint expects 404; with A set, a query returns none of B's rows and an insert with B's id fails.

## Control Plane

- **Holds:** a tenant table (id, plan, state), sign-up flow, usage counts for billing
- **Never reads tenant data:** the admin console reads only the tenant table and usage counts; it connects with a role that has no grants on tenant tables

## Lifecycle

- **Onboarding:** sign-up creates the tenant row, the first user with the tenant claim, default VAT settings
- **Tier change:** none (one plan)
- **Suspension:** sign-in blocked, data kept 90 days
- **Offboarding:** export (CSV and PDF), then delete rows by `tenant_id`, receipts by prefix; backups expire after 35 days, and the deletion record states that date

## Metering and Cost per Tenant

- **Metering:** active users and invoices per month (billing is flat today; recorded for future plans)
- **Cost per tenant:** apportioned from per-tenant request counts and storage, against the monthly bill

## For the Deployment View

One pooled deployment in the UK region; no tenant dimension drawn.

## Related ADRs

- ADR-003: Pooled tenancy with forced row-level security

## Open Questions

- none
````

## Why this is right

- The model came from the forces, not a default: 600 small tenants with no contract push.
- SOC 2 was answered with what it actually attests, not with infrastructure.
- Isolation is enforced by the database (forced RLS, non-owner role, `SET LOCAL`) and tested at release.
- The header was declined: tenant from the token.
- `validate-multi-tenancy-design.sh` exits clean on the artifact.
