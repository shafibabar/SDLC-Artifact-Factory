# Example 3 — Enterprise: a multi-tenant, two-region platform with a utility tree, Must / Plan / Stretch per service tier, and residency vs failover (hardest case)

Self-contained. **Permitry** is a multi-tenant SaaS platform on which local councils receive and decide building and planning permit applications. Each council is a tenant; three pilot councils go live first, about 40 within two years. Councils are public bodies, applicants have statutory deadlines, and the platform must stay up in office hours. The **enterprise** profile requires a full utility tree, all six parts on every kept scenario, Must / Plan / Stretch per service tier, trade-off points flagged for a lightweight architecture evaluation at Design, and process targets per service tier set by the user.

## Input

> **FRD (ideate/requirements.md, approved) — Quality-Attribute Hand-off:** QA-1 availability during each council's office hours (all URs; statutory deadlines); QA-2 tenant isolation and access control (FR-1.2, FR-2.2; BR-6; disfavoured user classes: staff of another council, another applicant, the public beyond the register); QA-3 responsiveness of checklist generation on a slow GIS (FR-1.1; IF-1 is outside our control); QA-4 data residency and retention, verifiable (DR-1; BR-4, BR-5).
>
> **FRD Business Rules (cited):** BR-4 decided case records kept 15 years after decision; BR-5 applicant personal data processed and stored only in the UK; BR-6 each council's data and configuration belong to that council alone. **Transition:** TR-1 per-council migration of open cases from the legacy system.
>
> **Drivers:** KR-1.2 first-submission validity 41% → 70%. Councils' contracts ask for 99.9% availability in office hours (08:00–18:00, Mon–Fri). The cloud provider has two UK regions. Monday 09:00 is the submission peak (about 300 applicants at once across tenants).
>
> **Service tiers (user, 2026-11-13):** tier 1 applicant submission and checklist; tier 2 officer back office and validation report; tier 3 reporting and exports.

## Working it

- **Every QA-n consumed.** QA-1 → reliability scenarios per failure (zone, region, GIS). QA-2 → security scenarios from the disfavoured classes. QA-3 → a latency scenario with the GIS's own latency as environment, plus a degraded-mode scenario. QA-4 → obligation rows citing BR-4 and BR-5; no second residency rule.
- **A missing rule goes back to the FRD.** The householder journey must meet public-sector accessibility regulations, but the FRD has no BR for it. The NFR does not invent the rule: change request CR-3 adds BR-7, and NFR-USE-01 cites it.
- **Noisy neighbours.** One council's migration import (TR-1) must not slow the others: a performance scenario on resource isolation.
- **Targets per tier.** Tier 1 gets the tightest; tier 3 may degrade first.
- **Conflicts.** Region failover vs UK-only processing; per-request tenant authorisation and audit vs latency; database-per-council isolation vs onboarding time.
- **Process targets per tier**, values the user chose, calibrated against `dora-metrics`; the cluster table is not copied here.

## Output — `ideate/nfr-specification.md` (abridged: tier 1 in full; tiers 2–3 noted where they differ)

````markdown
---
name: nfr-specification
product: permitry
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: 2026-11-14
summary: Permitry's utility tree: office-hours availability across two UK regions, tenant isolation, GIS-tolerant checklists, BR-4/BR-5 obligations, per-tier Must/Plan/Stretch and three trade-off points.
profile: enterprise
status: draft
linked-frd: ideate/requirements.md
traces_to: ideate/requirements.md (QA-1…QA-4, BR-4, BR-5, BR-6, IF-1, TR-1, CR-3); strategy/okrs.md (KR-1.2)
architecture-handoff: [NFR-REL-01, NFR-REL-02, NFR-REL-03, NFR-SEC-01, NFR-PERF-02, NFR-FLEX-01, NFR-DEPLOY-01]
---

# Non-Functional Requirements — Permitry

**Translation.** The FRD's hand-off (QA-1 to QA-4), BR-4 to BR-7 and the councils' contractual availability become a rated utility tree for `enterprise-architect` (with a lightweight architecture evaluation at Design), `security-architect`, `domain-modeler`, `slo-definition` and the Quality phase.

Targets use Planguage: **Must** the minimum acceptable, **Plan** the target, **Stretch** the ambition (never a release gate). Planguage *Must* is not a MoSCoW priority. Targets are for tier 1 unless a row names another tier. Ratings were drafted by the requirements-analyst and are confirmed by the user at the gate; this is a self-check, not a stakeholder workshop.

## Inputs Consumed

| Input | Says (cited, not restated) | Became |
|---|---|---|
| QA-1 | Availability in office hours | NFR-REL-01, NFR-REL-02, NFR-REL-03 |
| QA-2 | Tenant isolation and access control | NFR-SEC-01, NFR-SEC-02, NFR-PERF-02 |
| QA-3 | Checklist responsiveness on a slow GIS | NFR-PERF-01, NFR-REL-03 |
| QA-4 | Residency and retention, verifiable | NFR-OBL-01, NFR-OBL-02 |
| BR-4, BR-5 | Retention; UK-only processing | NFR-OBL-01, NFR-OBL-02 |
| BR-6 | Tenant ownership | NFR-SEC-01 |
| BR-7 (added by CR-3) | Public-sector accessibility | NFR-USE-01 |
| TR-1 | Per-council migration | Environment of NFR-PERF-02 |

## Characteristics Considered

| Characteristic | Decision |
|---|---|
| Functional suitability | Declined: the FRD's fit criteria own it |
| Performance efficiency | Kept: NFR-PERF-01 (time behaviour), NFR-PERF-02 (resource utilisation between tenants) |
| Compatibility | Kept through NFR-REL-03 (GIS dependency); the national portal (IF-3) has its own retry contract, declined for now |
| Interaction capability | Kept: NFR-USE-01 (accessibility, BR-7) |
| Reliability | Kept: NFR-REL-01, NFR-REL-02, NFR-REL-03 |
| Security | Kept: NFR-SEC-01 (confidentiality), NFR-SEC-02 (non-repudiation) |
| Maintainability | Kept indirectly: per-council rules are configuration (NFR-FLEX-01); no separate scenario |
| Flexibility | Kept: NFR-FLEX-01 (onboarding a council: adaptability, scalability) |
| Safety | Declined: decisions on permits do not directly endanger people; building-safety judgement stays with officers |
| Deployability | Kept: NFR-DEPLOY-01 |

## Utility Tree

```
Utility
├── Reliability
│   ├── Availability
│   │   └── NFR-REL-01  zone lost in office hours → fail over in-region, RTO ≤ 5 min  (H, H)
│   ├── Recoverability
│   │   └── NFR-REL-02  UK region lost → recover in the second UK region, RPO ≤ 15 min  (H, H)
│   └── Fault tolerance
│       └── NFR-REL-03  council GIS down → submission continues, designations marked unconfirmed  (H, H)
├── Security
│   ├── Confidentiality
│   │   └── NFR-SEC-01  officer of council B requests council A's case → refused, logged  (H, H)
│   └── Non-repudiation
│       └── NFR-SEC-02  validation decision disputed → officer and time provable  (M, M)
├── Performance efficiency
│   ├── Time behaviour
│   │   └── NFR-PERF-01  Monday 09:00 peak, GIS at its P95 → checklist P95 ≤ 6 s  (H, M)
│   └── Resource utilisation
│       └── NFR-PERF-02  one council's migration import → others' latency within 20%  (H, H)
├── Flexibility
│   └── Adaptability
│       └── NFR-FLEX-01  a new council signs → live in ≤ 10 working days, no code change  (M, H)
├── Interaction capability
│   └── Accessibility
│       └── NFR-USE-01  householder on a screen reader → submits unaided  (H, L)
└── Deployability
    └── NFR-DEPLOY-01  tier-1 fix in office hours → no failed submissions, rollback ≤ 10 min  (M, H)
```

| Rank | NFR | Business value | Architectural impact | Why |
|---|---|---|---|---|
| 1 | NFR-REL-01 | H | H | Contractual 99.9% in office hours; statutory deadlines |
| 2 | NFR-SEC-01 | H | H | BR-6; a cross-council leak ends the contract |
| 3 | NFR-REL-02 | H | H | Region loss with BR-5 shapes topology |
| 4 | NFR-PERF-02 | H | H | Shared infrastructure across councils |
| 5 | NFR-REL-03 | H | H | IF-1 is outside our control |
| 6 | NFR-PERF-01 | H | M | KR-1.2 depends on applicants finishing the checklist |
| 7 | NFR-FLEX-01 | M | H | 3 → 40 councils; tenancy model |
| 8 | NFR-DEPLOY-01 | M | H | Releases must not interrupt office hours |
| 9 | NFR-USE-01 | H | L | BR-7; met by design discipline, not structure |
| 10 | NFR-SEC-02 | M | M | Disputes are rare but must be answerable |

## Quality-Attribute Scenarios

| ID | Characteristic (sub) | Source | Stimulus | Environment | Affected part | Response | Response measure | Traces to | Verification |
|---|---|---|---|---|---|---|---|---|---|
| NFR-REL-01 | Reliability (availability) | Cloud zone | Fails | Office hours, Monday peak | Tier 1 and 2 services and database | Detects, fails over within the UK region, resumes | RTO ≤ 5 min (Must), ≤ 2 min (Plan), ≤ 30 s (Stretch); RPO 0; office-hours availability per council per month ≥ 99.9% (Must), 99.95% (Plan), 99.99% (Stretch). Tier 3: RTO ≤ 4 h (Must) | QA-1; councils' contracts | Quarterly zone-failover drill under peak load; monthly availability report (SLO via `slo-definition`) |
| NFR-REL-02 | Reliability (recoverability) | Cloud region | Is lost | Any time | Whole platform | Recovers in the second UK region from replicated data | RTO ≤ 4 h (Must), ≤ 1 h (Plan), ≤ 15 min (Stretch); RPO ≤ 15 min (Must), ≤ 5 min (Plan), ≤ 1 min (Stretch) | QA-1; BR-5 (via NFR-OBL-02) | Twice-yearly region recovery rehearsal |
| NFR-REL-03 | Reliability (fault tolerance) | A council's GIS (IF-1) | Times out or errors | Office hours | Checklist generation | Generates the checklist without designations, marks them "to be confirmed by the officer", lets the applicant submit | Submissions blocked by GIS failure: 0 (Must = Plan = Stretch); degraded checklist shown P95 ≤ 8 s (Must), ≤ 4 s (Plan), ≤ 2 s (Stretch) | QA-3; FR-1.1 | Fault-injection test with the GIS stub failing |
| NFR-SEC-01 | Security (confidentiality) | Officer of another council; another applicant; the public (disfavoured classes) | Requests a case, report or document by ID or search | Normal operation; after a credential leak | All tenant data APIs and exports | Refuses, logs, alerts | Disclosed: 0 of 500 scripted attempts (Must = Plan = Stretch); 5+ refused attempts in 10 min alerted ≤ 5 min (Must), ≤ 1 min (Plan), ≤ 15 s (Stretch) | QA-2; BR-6; FR-1.2, FR-2.2 | Automated cross-tenant suite per release; annual external penetration test |
| NFR-SEC-02 | Security (non-repudiation) | An applicant | Disputes a validation decision | Up to 15 years after decision (BR-4) | Validation report and audit trail | Shows which officer decided, when, under which rule; tamper-evident | 100% of decisions attributable (Must = Plan); audit tampering detected on verification (Must); answer produced ≤ 1 working day (Must), ≤ 1 h (Plan), ≤ 5 min (Stretch) | QA-2; FR-2.1 | Audit verification job monthly; sample dispute drill |
| NFR-PERF-01 | Performance efficiency (time behaviour) | 300 applicants across tenants | Start an application and request the checklist | Monday 09:00–10:00, each GIS answering at its own P95 (about 3 s) | Checklist generation | Returns the checklist | P95 ≤ 6 s (Must), ≤ 4 s (Plan), ≤ 3.2 s (Stretch); P99 ≤ 10 s (Must) | QA-3; FR-1.1; KR-1.2 | Load test with GIS stubs at measured latency, each release candidate |
| NFR-PERF-02 | Performance efficiency (resource utilisation) | One council | Runs its TR-1 migration import (100,000 cases) or its own peak | Office hours, other councils at normal load | Shared compute and database | Other councils' work is unaffected | Other councils' P95 within 20% of baseline (Must), 10% (Plan), 5% (Stretch) | QA-2; TR-1; BR-6 | Load test running a migration import beside the NFR-PERF-01 load |
| NFR-FLEX-01 | Flexibility (adaptability) | A new council | Signs a contract | Business as usual | Tenant provisioning and rule configuration | Provisioned and configured (validation list, GIS link) without code change | Contract to live ≤ 10 working days (Must), ≤ 5 (Plan), ≤ 2 (Stretch); code changes: 0 (Must) | Growth to 40 councils | Timed onboarding of councils 2 and 3 |
| NFR-USE-01 | Interaction capability (accessibility) | A householder using a screen reader or keyboard only | Completes an application | Home, unaided | Applicant web journey | Completes it | WCAG 2.2 AA with no open failures (Must); 4 of 5 assistive-technology users complete unaided (Plan), 5 of 5 (Stretch) | BR-7 (CR-3) | Automated accessibility scan per release; annual audit with assistive-technology users |
| NFR-DEPLOY-01 | Deployability | Developer, through the pipeline | A tier-1 fix is ready | Office hours, at peak | One tier-1 service | Deployed gradually with no manual step; rolled back automatically on failed health checks; other services untouched | Failed submissions during deploy: 0 (Must); rollback ≤ 10 min (Must), ≤ 5 min (Plan), ≤ 2 min (Stretch); per-council configuration changes need no deploy (Must) | Product property | Release rehearsal under NFR-PERF-01 load |

## Obligations from Business Rules

| ID | Business rule | Measurable obligation on this system | Verification |
|---|---|---|---|
| NFR-OBL-01 | BR-4 | Every decided case, its documents and audit trail are retrievable for 15 years after decision, then deleted within 30 days | Retention policy test in CI; yearly retrieval sample of 50 oldest cases |
| NFR-OBL-02 | BR-5 | Every store, replica, backup, log sink and sub-processor holding applicant personal data is in a UK region | Policy-as-code check on every infrastructure plan fails on a non-UK location; quarterly sub-processor review |

## Candidate Trade-off Points

| ID | Scenarios | Why they pull apart | Options open (not chosen) | Decided by |
|---|---|---|---|---|
| TP-1 | NFR-REL-02 × NFR-OBL-02 | Region recovery needs a second region, and BR-5 allows only UK ones; if a managed service the design needs exists in one UK region only, the RPO/RTO Plan cannot be met | Second UK region for everything (cost); UK-only backups with RTO at the Must; a different service in the second region | `enterprise-architect` (ADR); the user if the RTO must relax |
| TP-2 | NFR-SEC-01 × NFR-PERF-01 | Tenant authorisation and audit on every request add time on the checklist's hot path | Authorise at the gateway and cache decisions per session; authorise in each service | `enterprise-architect` |
| TP-3 | NFR-PERF-02 / NFR-SEC-01 × NFR-FLEX-01 | A database per council isolates best but slows onboarding and raises cost; a shared database onboards fast but isolates by row | Database per council; shared database with row-level isolation and per-tenant quotas; pooled with a dedicated option for large councils | `enterprise-architect` (ADR), the user for pricing |

Flag TP-1 to TP-3 and the (H, H) leaves for the lightweight architecture evaluation after the first container diagram.

## Derived Requirements

| From | Functional requirement sent to the FRD | Status |
|---|---|---|
| NFR-REL-03 | Officers see which designations are "to be confirmed" on the validation report | CR-4 raised |
| NFR-SEC-01 | Councils' admins can see refused cross-tenant attempts against their data | CR-5 raised |
| NFR-USE-01 | Missing accessibility rule | CR-3 raised: adds BR-7 to the FRD |

## Process Targets

| ID | Target | Scope | Value (chosen by the user) | Calibration | Measured by |
|---|---|---|---|---|---|
| PT-1 | Deployment frequency | Tier 1 services | At least weekly | `dora-metrics` | Successful production deploys per service |
| PT-2 | Change failure rate | Tier 1 services | ≤ 15% over 30 days | `dora-metrics` | Rollbacks and hotfixes over deploys |
| PT-3 | Deployment frequency | Tier 3 services | At least monthly | `dora-metrics` | As PT-1 |

## Architecture Handoff

| NFR | Rating (value, impact) | Trade-off points | Tactic families (pointers only) |
|---|---|---|---|
| NFR-REL-01 | (H, H) | — | Active redundancy; heartbeat; health monitoring |
| NFR-REL-02 | (H, H) | TP-1 | Passive redundancy; state resynchronisation |
| NFR-REL-03 | (H, H) | — | Timeout; graceful degradation |
| NFR-SEC-01 | (H, H) | TP-2, TP-3 | Authorise actors; separate entities; detect attacks |
| NFR-PERF-02 | (H, H) | TP-3 | Bound queue sizes; schedule resources; per-tenant quotas |
| NFR-FLEX-01 | (M, H) | TP-3 | Defer binding: configuration per tenant |
| NFR-DEPLOY-01 | (M, H) | — | Gradual rollout; rollback; feature toggles |

## Open Questions

| ID | Question | Blocks | Who can answer | Resolve by |
|---|---|---|---|---|
| TBD-1 | Are all managed services the design may need available in both UK regions? | TP-1 | `enterprise-architect` | First container diagram |
| TBD-2 | Approval of CR-3 (BR-7) | NFR-USE-01 | the product owner | Before the Design phase gate |
````

## Why this is right at enterprise

| Choice | Reason |
|---|---|
| A utility tree, then a ranked table | The tree shows coverage by characteristic; the table orders the work |
| Six parts and Must / Plan / Stretch on every row, tiers named | Enterprise targets differ by tier; Stretch is ambition, never a gate |
| Residency and retention as cited obligations | BR-4 and BR-5 have one home; here only what the system must prove |
| A missing rule sent back as CR-3 | The NFR never invents a rule |
| Noisy-neighbour scenario from TR-1 | Multi-tenancy turns one council's migration into everyone's latency |
| Three trade-off points, none chosen | Residency vs failover, security vs latency, isolation vs onboarding go to the architect and the user |
| Process targets per tier with the user's values | `dora-metrics` calibrates; nothing is defaulted to the high-performer cluster |
