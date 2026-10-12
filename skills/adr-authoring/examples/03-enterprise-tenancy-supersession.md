# Example 3 — Enterprise: a multi-tenant isolation decision and its superseding ADR

Self-contained. This is the hardest common case. A SaaS platform's tenancy model was decided early for a small-business market. Two years later, enterprise tenants arrive with data-residency, isolation and availability demands. The example shows both ADRs:

- **ADR-006**, the original pooled-tenancy decision, now marked superseded;
- **ADR-031**, which supersedes it.

Together they demonstrate the superseding mechanics: bidirectional links, superseding the *whole* decision, restating the parts that are kept, and a Context that names what changed. Both ADRs pass `../scripts/validate-adr.sh`.

## The original decision, after supersession

Only the frontmatter and Status change. Everything else in an Accepted ADR stays as written (Context, Options, Rationale), so "why did we believe this in 2026?" can still be answered.

```markdown
---
name: adr-006-pooled-multi-tenancy-with-row-level-security
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-03-02
summary: All tenants share one PostgreSQL cluster isolated by row-level security on tenant_id; trades isolation strength for cost and operational simplicity.
adr-id: ADR-006
title: Pooled Multi-Tenancy with Row-Level Security
status: Superseded by ADR-031
deciders: enterprise-architect, security-architect
---

# ADR-006: Pooled Multi-Tenancy with Row-Level Security

## Status
Superseded by ADR-031

## Context
350 SMB tenants, all in one region, none larger than 50 GB. No tenant has contractual isolation or residency terms. One platform engineer operates the database tier.

## Decision
We will store all tenants in one PostgreSQL cluster, isolated by row-level security policies keyed on `tenant_id`, with the tenant set per connection from the authenticated session.

## Options Considered
### Option A: Pooled, row-level security (chosen)
**Pros:** lowest cost; one schema to migrate. **Cons:** a policy bug is a cross-tenant leak; noisy neighbours share capacity.
### Option B: Database-per-tenant (silo)
**Pros:** strongest isolation. **Cons:** 350 databases to migrate and monitor with one engineer.

## Rationale
**Trade-off:** cost and operational simplicity over isolation strength. At this scale and team size, silo operations would dominate engineering time, and no tenant contract requires physical isolation.

## Consequences
### Positive
- One migration path, one backup policy.
### Negative / Trade-offs
- Isolation depends on every query path honouring RLS.
### Risks
- RLS bypass via a superuser connection. Mitigated by a lint rule plus an integration test per repository.

## Related ADRs
- Superseded by: ADR-031
```

## The superseding decision

```markdown
---
name: adr-031-bridge-tenancy-silo-for-enterprise-pool-for-smb
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2028-04-14
summary: Enterprise tenants get a dedicated database in their residency region; SMB tenants stay pooled with RLS. Trades operational simplicity for isolation, residency and per-tenant availability.
adr-id: ADR-031
title: Bridge Tenancy — Silo for Enterprise, Pool for SMB
status: Accepted
deciders: enterprise-architect, security-architect, platform-engineer
traces_to: NFR-SEC-07 (contractual tenant isolation), NFR-AV-02 (99.95% per enterprise tenant), NFR-RES-01 (EU data residency)
---

# ADR-031: Bridge Tenancy — Silo for Enterprise, Pool for SMB

## Status
Accepted

## Context
This supersedes ADR-006 (pooled multi-tenancy with RLS). Three things changed since ADR-006:
- 40 enterprise tenants signed contracts requiring isolation that does not rest on application logic (NFR-SEC-07).
- 12 of them require EU-only data residency (NFR-RES-01).
- Each enterprise tenant now has an individual 99.95% availability commitment (NFR-AV-02). A noisy SMB neighbour exhausting shared connections has caused two enterprise-visible incidents.

ADR-006's rationale (no tenant needed physical isolation; one engineer ran the database tier) no longer holds: both premises are false today. 3,800 SMB tenants remain, with none of these terms. The platform team is now four engineers.

## Decision
We will run a bridge model:
- Each enterprise tenant gets a dedicated PostgreSQL database in the region its contract names, with its own connection pool and failover replica.
- SMB tenants remain pooled with row-level security, exactly as ADR-006 decided. **That part is kept and restated here, so ADR-006 can be superseded whole.**

Tenant placement is a field on the tenant record, read by the connection router.

## Options Considered
### Option A: Bridge — silo enterprise, pool SMB (chosen)
**Pros:** meets isolation, residency and per-tenant availability where contracts demand them; SMB cost stays low.
**Cons:** two tenancy paths to migrate, test and operate.
### Option B: Silo every tenant
**Pros:** one model, strongest isolation for all.
**Cons:** about 3,840 databases. SMB unit economics break, and migration fan-out multiplies every schema change.
### Option C: Keep the pool; add separate regional pooled clusters
**Pros:** meets residency.
**Cons:** isolation still rests on RLS (fails NFR-SEC-07), and noisy neighbours remain within each region.

### Trade-off matrix
| Characteristic | A: Bridge | B: Silo all | C: Regional pools |
|---|---|---|---|
| Isolation strength (enterprise) | High | High | Medium |
| Data residency | Yes | Yes | Yes |
| Per-tenant availability | High (enterprise) | High | Medium |
| Operational cost | Medium | High | Low |
| Migration complexity | Medium (2 paths) | High (fan-out) | Low |

## Rationale
**Trade-off:** isolation, residency and per-tenant availability over operational simplicity. Option A is the only one that meets all three contractual NFRs without breaking SMB economics. Option C was the cheapest, but it leaves enterprise isolation resting on application logic, which is exactly what the contracts exclude.

## Consequences
### Positive
- Enterprise isolation and residency are physical and auditable.
- A noisy SMB tenant can no longer exhaust an enterprise tenant's connections.
### Negative / Trade-offs
- Every schema migration must run on the pool and on N enterprise databases. The migration runner gains a fan-out mode with per-database status.
- Two code paths for tenant routing.
### Risks
- Fan-out migrations can leave enterprise databases at mixed schema versions. Mitigated by expand/contract-only migrations and a version gate in the router.
- Promotion (an SMB tenant becoming enterprise) needs a data move. That gets its own ADR when first needed. It is not decided here.

## Related ADRs
- Supersedes: ADR-006
- Related: ADR-012 (connection routing), ADR-019 (regional deployment topology)
```

## What to notice

- **Bidirectional links.** ADR-031 says `Supersedes: ADR-006`, and ADR-006's status and Related ADRs say `Superseded by ADR-031`. Updating ADR-006 is part of accepting ADR-031.
- **Whole-decision supersession.** The SMB half of ADR-006 is *kept*, but it is restated in ADR-031, so ADR-006 is fully retired instead of left "half active".
- **Context names what changed.** It gives the new NFRs and the false premises. Without new information, this would be re-litigation rather than evolution.
- **Scope discipline.** Tenant promotion is explicitly *not* decided here. Folding it in would create a mega-ADR with two lifecycles.
