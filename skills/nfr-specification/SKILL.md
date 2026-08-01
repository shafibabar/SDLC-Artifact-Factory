---
name: nfr-specification
description: >
  Teaches how to identify, categorise, and write measurable Non-Functional
  Requirements (NFRs) across performance, scalability, availability, security,
  compliance, usability, maintainability, data, delivery (DORA metrics), and
  platform developer-experience domains. NFRs directly constrain architecture
  decisions in the Design phase and become the acceptance criteria for Quality
  phase testing. Used by the requirements-analyst agent during the Ideate phase,
  immediately after functional requirements.
version: 2.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, nfr, performance, scalability, security, compliance, architecture-input, dora, delivery, platform-dx]
produces: nfr-specification
domain: discovery
status: stable
related: [dora-metrics, slo-definition, platform-engineering-design]
---

# NFR Specification

## Purpose

Non-Functional Requirements (NFRs) define the qualities the system must have — not what it does, but how well it does it and under what constraints it operates. They are the primary input to architecture decisions: a system designed without NFRs is designed for an unknown context and will fail under real conditions.

Every NFR must be:
- **Measurable** — expressed as a metric with a specific target value
- **Testable** — verifiable by a defined test type (performance test, security audit, compliance check)
- **Traceable** — linked to a business driver (user expectation, regulatory obligation, operational constraint)

Vague NFRs ("the system should be fast") are not NFRs — they are wishes. They must be made specific or removed.

---

## NFR Categories

### 1. Performance

Response time, throughput, and resource consumption under defined load conditions.

| Attribute | Format | Example |
|---|---|---|
| Response time | P50/P95/P99 latency at defined RPS | "API responses: P95 < 200ms at 100 concurrent users" |
| Throughput | Requests or operations per second | "File classification: minimum 1,000 files/minute per worker node" |
| Resource consumption | CPU/memory at defined load | "Worker node: < 2 CPU cores, < 1GB RAM at peak scanning load" |

---

### 2. Scalability

How the system behaves as load and data volume increase.

| Attribute | Format | Example |
|---|---|---|
| Horizontal scaling | How additional nodes change capacity | "Each additional worker node adds 1,000 files/minute scanning capacity linearly" |
| Data volume | Maximum supported dataset size | "Must support estates of up to 10 million files without performance degradation" |
| Tenant scaling | Isolation under multi-tenant load | "One tenant's peak load must not affect another tenant's response times" |

---

### 3. Availability

Uptime commitments and recovery targets.

| Attribute | Definition | Example |
|---|---|---|
| Uptime SLO | Percentage of time the system is operational | "99.5% monthly uptime for the compliance dashboard" |
| RTO (Recovery Time Objective) | Maximum time to restore service after failure | "RTO: 4 hours for complete infrastructure failure" |
| RPO (Recovery Point Objective) | Maximum data loss acceptable after failure | "RPO: 1 hour — no more than 1 hour of scan results lost" |
| Planned downtime | Maintenance window | "Maximum 2 hours planned downtime per month, announced 48 hours in advance" |

---

### 4. Security

Technical security requirements that constrain implementation and architecture.

| Attribute | Example |
|---|---|
| Authentication | "All API endpoints require JWT authentication; tokens expire after 1 hour" |
| Authorisation | "ABAC: every resource access evaluated against user attributes, resource classification, and environment context" |
| Encryption in transit | "All service-to-service communication encrypted with mTLS via Linkerd" |
| Encryption at rest | "All data at rest encrypted with AES-256; keys managed per-tenant in customer-controlled key store" |
| Secrets management | "No secrets in source control, environment variables, or container images; injected at runtime via secrets manager" |
| Vulnerability management | "Container images scanned on every build; no HIGH or CRITICAL CVEs in production images" |
| Penetration testing | "Annual third-party penetration test; critical and high findings remediated within 30 days" |

---

### 5. Compliance

Regulatory and standards requirements that impose verifiable obligations.

| Framework | Requirement format |
|---|---|
| SOC 2 Type II | "CC6.1: All access to production systems is controlled and logged" |
| GDPR | "Article 30: Data processing register auto-generated and kept current" |
| ISO 27001 | "A.12.4.1: Event logs produced and retained for 12 months" |

Each compliance NFR must reference the specific control or article and state how it will be verified (Compliance as Code — automated test that checks the control).

---

### 6. Usability

How easily the target user can achieve their goal.

| Attribute | Example |
|---|---|
| Time to first value (TTFV) | "A new user must reach their first compliance gap discovery within 30 minutes of connecting their first storage source, without contacting support" |
| Error recovery | "All user-facing errors include a plain-language description and a remediation step" |
| Accessibility | "UI meets WCAG 2.1 Level AA" |
| Onboarding completion rate | "80% of trial users complete setup without abandoning" |

---

### 7. Maintainability

How easily the system can be changed, debugged, and extended.

| Attribute | Example |
|---|---|
| Test coverage | "Minimum 80% unit test coverage on all service packages; 100% on domain logic" |
| Build time | "Full CI pipeline completes in under 10 minutes" |
| Mean Time to Diagnose (MTTD) | "Any production incident diagnosable to a root cause within 30 minutes using distributed tracing and structured logs" |
| Dependency currency | "No dependency older than 12 months without documented reason; no known CVEs in dependencies" |
| Code review gate | "No code merged without passing automated tests, lint, and at least one review" |

---

### 8. Data

Requirements governing how data is stored, retained, and governed.

| Attribute | Example |
|---|---|
| Data residency | "All customer data — files, metadata, entity extractions — processed and stored exclusively within the customer's declared infrastructure boundary" |
| Data retention | "Scan results retained for 90 days by default; configurable per tenant to 12 months" |
| Audit log retention | "Audit logs retained for 7 years; append-only; tamper-evident" |
| Data classification | "Every data asset assigned a sensitivity classification (Public / Internal / Confidential / Restricted) within 24 hours of discovery" |
| Backup | "Daily encrypted backups; backup restoration tested monthly" |

---

### 9. Delivery (DORA Metrics)

**Applies to every service.** Delivery NFRs define how rapidly and reliably a service can be changed and shipped to production. They are process constraints verified by measuring the CI/CD pipeline's actual behaviour — not performance tests, not security audits. Based on the DORA research programme (Forsgren, Humble, Kim — *Accelerate*), high-performing delivery organisations achieve all four targets simultaneously; tempo and stability reinforce each other, not trade off.

| Attribute | DORA High Performer Target | Format |
|---|---|---|
| Deployment Frequency | On demand — multiple times per day | "This service must be deployable to production on demand; releases are not batched or gated by a release window" |
| Lead Time for Changes | < 1 hour from commit to production | "From the moment a commit merges to main, it must be running in production within 1 hour via the automated CD pipeline" |
| MTTR (Mean Time to Restore) | < 1 hour to restore after a production incident | "Any production incident affecting this service must be resolved — via rollback, hotfix, or feature flag — within 1 hour of detection" |
| Change Failure Rate | < 15% of deployments cause an incident | "No more than 15% of deployments to production may require a rollback, hotfix, or immediate patch; measured over a rolling 30-day window" |

**Testing approach:** Delivery NFRs are verified by measuring the pipeline. Deployment Frequency is counted from GitHub Actions workflow run events on main. Lead Time is the delta between commit timestamp and deploy-complete timestamp. MTTR is measured from alert-open to alert-closed in Alertmanager. Change Failure Rate is rollback events divided by total deployments in the window. A service that cannot be deployed without a manual release window fails the Deployment Frequency NFR by construction.

**DORA cluster thresholds for calibration (from *Accelerate* Ch. 3):**
- High performers: deploy on demand, lead time < 1 hour, MTTR < 1 hour, change failure rate 0–15%
- Medium performers: deploy weekly–monthly, lead time 1 day–1 week, MTTR < 1 day, change failure rate 0–15%
- Low performers: deploy monthly or quarterly, lead time 1–6 months, MTTR 1 week to 1 month, change failure rate 46–60%

---

### 10. Platform DX (Developer Experience)

**Applies when the artifact being specified is a platform capability, not a product feature.** Platform DX NFRs define how effectively the platform reduces cognitive load for the engineers who build on it. Based on Fournier and Nowland's *Platform Engineering*: a platform that is technically correct but imposes high cognitive load has failed its customers. These NFRs are measurable, testable, and tracked via the `platform-engineering-design` skill's DX measurement cadence.

| Attribute | Target | Verification |
|---|---|---|
| Time-to-First-Deploy | A new engineer can deploy to the local environment within 1 business day using only the golden path and its documentation, without requiring help from a platform team member | Timed during engineer onboarding; the stopwatch starts on day one and stops when a successful deployment is confirmed in the local environment |
| Self-Service Coverage | ≥ 90% of common platform operations (create service, provision database, create environment, rotate secret, view logs, roll back deployment) are achievable without opening a support ticket | Enumerated as a percentage: count of operations achievable via golden path CLI or UI / total enumerated common operations |
| Exception Rate | The number of out-of-band deviations from the golden path requested per quarter must trend downward after initial platform adoption | Tracked as an inverse-adoption metric; a rising exception rate signals the golden path does not cover real developer needs |

**Testing approach:** Time-to-First-Deploy is verified by observing (and timing) actual onboarding sessions. Self-Service Coverage is verified by enumerating the ten most common platform operations identified from support ticket history and checking each against the golden path. Exception Rate is a quarterly review metric from the platform team's deviation log.

---

## Step-by-Step Production

1. For each NFR category, extract obligations from: the FRD constraints, the GTM strategy (SLA expectations for the target market), the competitive analysis (table-stakes quality expectations), and explicit regulatory requirements identified in the stakeholder map.
2. Write each NFR using the format: **what** the requirement is + **the measurable target** + **the test type that will verify it**.
3. Assign each NFR a unique ID (`NFR-[category prefix]-[number]`, e.g. `NFR-PERF-001`, `NFR-DLVR-002`, `NFR-PDX-001`). Category prefixes: PERF, SCAL, AVAIL, SEC, COMP, USE, MAINT, DATA, DLVR, PDX.
4. For every NFR, ask: "How will this be tested in the Quality phase?" If it cannot be tested, it cannot be verified — refine it until it can.
5. Flag NFRs that impose significant architecture constraints for explicit handoff to the `enterprise-architect` agent.
6. For Delivery NFRs: verify the CI/CD pipeline is instrumented to emit the four DORA metric events; an NFR-DLVR entry without a measurement source is unverifiable.
7. For Platform DX NFRs: confirm that onboarding documentation and a golden path CLI/UI exist before declaring them testable.

---

## Architecture Handoff

These NFR types impose the strongest architecture constraints and must be explicitly flagged in the NFR document for the `enterprise-architect`:

- Physical data residency requirements → constrain deployment topology
- mTLS and Zero Trust requirements → mandate service mesh
- Tenant isolation at infrastructure level → constrain database and network architecture
- RTO/RPO targets → mandate backup, replication, and failover architecture
- Horizontal scaling requirements → mandate stateless service design
- Deployment Frequency + Lead Time NFRs (DLVR) → mandate a fully automated CD pipeline with no manual release steps; any manual gate in the pipeline makes the Lead Time NFR unachievable

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Measurability | Every NFR has a numeric target or binary pass/fail condition | Any NFR containing "should be", "reasonable", "fast", "secure" without a metric |
| Testability | Every NFR references a test type or measurement source | NFR with no stated verification approach |
| Category coverage | All 10 categories addressed, even if only to document "no requirement in this category" | Missing categories with unexamined assumptions |
| Architecture flags | NFRs with architecture implications are marked | Architecture-constraining NFRs buried without flagging |
| Compliance traceability | Compliance NFRs reference the specific control or article | Generic compliance claims with no control reference |
| Delivery instrumentation | Each DLVR NFR names its measurement source (pipeline event, alert timestamp, deploy count) | Delivery NFR with no identified data source |
| Platform DX scope | PDX NFRs included only when the artifact is a platform capability, not a product feature | Platform DX NFRs on a product feature (wrong applicability) |

---

## Anti-Patterns and Output Format Template

See `references/nfr-antipatterns-and-output.md` for:
- The six named anti-patterns (wish NFRs, copy-paste SLOs, targets without load context, compliance hand-waving, specified-then-orphaned NFRs, averages as targets)
- The full output format template, updated to include Delivery and Platform DX sections
- Worked examples for DLVR and PDX NFRs
