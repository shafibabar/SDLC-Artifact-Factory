# Example 3 — Enterprise: Residency against Failover, a Risk Theme and the Product Owner's Confirmation

Self-contained. **Permitry** is a multi-tenant platform on which local councils decide permit applications, at the **enterprise** profile, in two UK regions. Its NFR Architecture Handoff lists seven scenarios; this excerpt of the record shows five that carry the findings (**NFR-REL-01** zone failure, RTO at most 5 minutes; **NFR-REL-02** region loss, RTO at most 4 hours and RPO at most 15 minutes; **NFR-REL-03** the council's GIS failing; **NFR-SEC-01** no disclosure across councils in 500 scripted attempts; **NFR-PERF-02** one council's 100,000-case migration must not move other councils' P95 by more than 20%). The handoff carries three trade-off points: **TP-1** (region recovery against UK-only processing, BR-5), **TP-2** (authorisation and audit on the hot path against checklist speed) and **TP-3** (a database per council against a shared database). The design uses a shared database with row-level isolation and per-council quotas (ADR-0006), a managed message broker that exists in one UK region only, asynchronous replication to the second region (ADR-0007), and authorisation decisions cached per session.

## Input

> **User:** "Call the residency problem a non-risk and move on, we are out of time before the Design gate."

## Working it

- **Declined.** The broker exists in one UK region, BR-5 allows only UK regions, and the region-recovery scenario needs a second region: a property that raises compliance and lowers recoverability is a **trade-off point** (carried from TP-1), not a non-risk. Hiding it removes a decision the design has to make. It is recorded, and routed to the user because it changes cost: a broker in the second region costs money, or the RPO Must relaxes.
- **Sensitivity point versus trade-off point.** The broker's single-region placement is a **sensitivity point** for the region-recovery RPO; it becomes a **trade-off point** because the same property raises BR-5 compliance while lowering recoverability.
- **Findings.**
  - **R-1 (NFR-REL-02):** with the broker in one region, queued work cannot meet the 15-minute RPO after a region loss.
  - **R-2 (NFR-SEC-01):** isolation by row depends on every query carrying the council filter; one missing filter discloses another council's data.
  - **R-3 (NFR-PERF-02):** per-council quotas are enforced in the application, not by the database, so a runaway migration could still starve others.
  - **Risk theme RT-1:** R-2 and R-3 share a cause, isolation between councils depends on application discipline rather than the platform; it threatens the councils' contractual trust, the business driver.
  - **N-1 (NFR-REL-01):** active redundancy within the region with health monitoring; **N-2 (NFR-REL-03):** timeout and graceful degradation of the checklist, which are in the design.
- **Trade-off points resolved.** T-1 goes to the user (the cost of a second-region broker against relaxing the RPO), with ADR-0008 to follow; T-2 resolves as ADR-0009 (decisions cached per session, with a 5-minute revocation delay accepted); T-3 was resolved earlier in ADR-0006.
- **Fitness functions:** a policy-as-code check that fails an infrastructure plan with a non-UK location (the NFR's own measure for BR-5), the cross-council access suite per release, a load test that runs a migration beside the peak load, a quarterly zone-failover drill, and a proposed query check that fails the build when a query on a tenant table lacks the council filter.
- **Confirmation.** The product owner confirms the risks and the trade-off points at the Design gate.

## Output: `artifacts/permitry/design/architecture/architecture-evaluation.md` (frontmatter omitted in a reply)

````markdown
---
name: architecture-evaluation
product: permitry
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-11-20
summary: Self-check of Permitry's scenarios: three risks, one risk theme on council isolation, and three trade-off points, one awaiting the user's cost decision.
traces-to: [ideate/nfr-specification.md, design/architecture/container-diagram.md, ADR-0006, ADR-0007]
self-check: true
---

# Architecture Evaluation for Permitry

**Readers:** enterprise-architect, the product owner, backend-engineer, platform-engineer
**Question it answers:** does the design, as it stands, meet its highest-impact scenarios, and where does it not, or only at a cost?

- **Profile:** enterprise
- **Self-check:** This is a self-check by the agent that designed the architecture: not independent, and not an ATAM (a full ATAM needs many stakeholders, an outside team and several days).

## Scenarios Evaluated

| Scenario | Rating (value, impact) | Response measure | Approaches that serve it |
|---|---|---|---|
| NFR-REL-01 | (H, H) | RTO at most 5 min after a zone failure | active redundancy within the region, health monitoring |
| NFR-REL-02 | (H, H) | RTO at most 4 h; RPO at most 15 min after a region loss | asynchronous replication to the second UK region (ADR-0007) |
| NFR-REL-03 | (H, H) | submissions blocked by a GIS failure: 0 | timeout and a degraded checklist |
| NFR-SEC-01 | (H, H) | disclosed: 0 of 500 scripted attempts | shared database with row-level isolation (ADR-0006), authorisation per request |
| NFR-PERF-02 | (H, H) | other councils' P95 within 20% during a migration | per-council quotas in the application |

## Tactics Questionnaire

| Scenario | Tactic family | Question | Answer | Where in the design |
|---|---|---|---|---|
| NFR-REL-01 | detect faults | is a failed zone detected and traffic moved? | yes | health monitoring and active redundancy |
| NFR-REL-02 | recover from faults | is state resynchronised to a second region, including queued work? | partial | database replication yes; the broker exists in one region only |
| NFR-REL-03 | recover from faults | does the checklist degrade when the GIS fails? | yes | timeout and a degraded checklist |
| NFR-SEC-01 | resist attacks | is every access authorised and tenant data separated? | partial | row-level isolation depends on every query carrying the council filter |
| NFR-PERF-02 | manage resources | is one tenant's demand bounded? | partial | quotas in the application, not enforced by the database |

## Risks

| ID | Scenario | Decision | Why it may fail | Action |
|---|---|---|---|---|
| R-1 | NFR-REL-02 | the message broker exists in one UK region only | queued work cannot be recovered within the 15-minute RPO after a region loss | decide the broker's second-region placement (T-1) |
| R-2 | NFR-SEC-01 | row-level isolation relies on every query carrying the council filter | one missing filter discloses another council's data | add a query check and keep the cross-council suite per release |
| R-3 | NFR-PERF-02 | per-council quotas are enforced in the application | a runaway migration could still starve other councils at the database | enforce the quota at the database layer |

## Non-Risks

| ID | Scenario | Decision | Reason it is safe |
|---|---|---|---|
| N-1 | NFR-REL-01 | active redundancy within the region with health monitoring | a failed zone is detected and traffic moves without data loss, which the quarterly drill proves |
| N-2 | NFR-REL-03 | a timeout and a degraded checklist | the applicant can still submit, so a GIS failure blocks no submission |

## Sensitivity Points

| ID | Property | Response it governs | Value or limit that matters |
|---|---|---|---|
| S-1 | the broker's single-region placement | the region-recovery RPO | a region loss loses queued work not yet replicated |

## Trade-off Points

Each ADR's Trade-off line names the characteristics traded (for example, security traded against latency).

| ID | Property | Raises | Lowers | Carried from | Resolution |
|---|---|---|---|---|---|
| T-1 | the broker exists in one UK region only | UK-only data residency (BR-5) | recoverability after a region loss | TP-1 | the user decides: the cost of a second-region broker against relaxing the 15-minute RPO; ADR-0008 follows |
| T-2 | authorisation decisions cached per session | checklist speed | the freshness of a revoked permission | TP-2 | ADR-0009 |
| T-3 | a shared database with row-level isolation | onboarding speed and low cost | isolation strength between councils | TP-3 | ADR-0006 |

## Risk Themes

| ID | Risks | Systemic weakness | Business driver threatened |
|---|---|---|---|
| RT-1 | R-2, R-3 | isolation between councils depends on application discipline, not on the platform | the councils' contractual trust in tenant separation |

## Fitness Functions

These fitness functions are objective automated checks that run continuously and keep each rule true as the system changes; they complement this one-time evaluation and do not replace it.

| Characteristic | Rule that must stay true | Check | Where it runs | Owner |
|---|---|---|---|---|
| data residency | every store holding applicant data is in a UK region | a policy-as-code check on every infrastructure plan | the infrastructure pipeline | platform-engineer |
| isolation | no council can read another council's data | the cross-council access suite | every release build | backend-engineer |
| isolation | every query on a tenant table carries the council filter | a query check that fails the build | every build | backend-engineer |
| performance isolation | other councils' P95 stays within 20% during a migration | a load test running a migration beside the peak load | every release candidate | platform-engineer |
| availability | a zone failure recovers within 5 minutes | the zone-failover drill | every quarter, scheduled | platform-engineer |

## Actions

- The user decides T-1 (cost of a second-region broker against relaxing the RPO) before the Design gate; ADR-0008 records the answer and reopens the container diagram if the broker moves.
- Add the query check and the database-level quota; owner: backend-engineer; reopens the isolation design for re-approval.

## Confirmation

- **Product owner confirmation:** the product owner confirmed R-1 to R-3, RT-1 and T-1 to T-3 at the Design gate walk on 2026-11-20.

## Open Questions

- Whether councils accept a 5-minute delay in revoking a cached permission; owner: product owner, with the councils' administrators.
````

> **Reply summary:** the request to call the residency problem a non-risk is declined: it is a trade-off point (UK-only residency up, recoverability down), distinct from the broker's sensitivity point, routed to the user because it changes cost, with ADR-0008 to follow; three risks, one risk theme tied to the councils' trust, five fitness functions; this is a self-check by the designing agent, not independent and not an ATAM, and changes it drives reopen approved artifacts; no implementation code.
