---
name: nfr-specification
description: >
  Teaches how to identify, categorise, and write measurable Non-Functional
  Requirements (NFRs) across performance, scalability, availability, security,
  compliance, usability, maintainability, and data domains. NFRs directly
  constrain architecture decisions in the Design phase and become the
  acceptance criteria for Quality phase testing. Used by the requirements-analyst
  agent during the Ideate phase, immediately after functional requirements.
version: 1.0.0
phase: ideate
owner: requirements-analyst
tags: [ideate, nfr, performance, scalability, security, compliance, architecture-input]
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

## Step-by-Step Production

1. For each NFR category, extract obligations from: the FRD constraints, the GTM strategy (SLA expectations for the target market), the competitive analysis (table-stakes quality expectations), and explicit regulatory requirements identified in the stakeholder map.
2. Write each NFR using the format: **what** the requirement is + **the measurable target** + **the test type that will verify it**.
3. Assign each NFR a unique ID (NFR-[category prefix]-[number], e.g. `NFR-PERF-001`, `NFR-SEC-003`).
4. For every NFR, ask: "How will this be tested in the Quality phase?" If it cannot be tested, it cannot be verified — refine it until it can.
5. Flag NFRs that impose significant architecture constraints for explicit handoff to the `enterprise-architect` agent.

---

## Architecture Handoff

These NFR types impose the strongest architecture constraints and must be explicitly flagged in the NFR document for the `enterprise-architect`:

- Physical data residency requirements → constrain deployment topology
- mTLS and Zero Trust requirements → mandate service mesh
- Tenant isolation at infrastructure level → constrain database and network architecture
- RTO/RPO targets → mandate backup, replication, and failover architecture
- Horizontal scaling requirements → mandate stateless service design

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Measurability | Every NFR has a numeric target or binary pass/fail condition | Any NFR containing "should be", "reasonable", "fast", "secure" without a metric |
| Testability | Every NFR references a test type (performance test, security scan, compliance check) | NFR with no stated verification approach |
| Category coverage | All 8 categories addressed, even if only to document "no requirement in this category" | Missing categories with unexamined assumptions |
| Architecture flags | NFRs with architecture implications are marked | Architecture-constraining NFRs buried without flagging |
| Compliance traceability | Compliance NFRs reference the specific control or article | Generic compliance claims with no control reference |

---

## Output Format

```markdown
---
artifact: nfr-specification
product: [product name]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
architecture-handoff: [list of NFR IDs with architecture implications]
---

# Non-Functional Requirements Specification

## Performance
| ID | Requirement | Target | Test Type |
|---|---|---|---|

## Scalability
[Repeat table]

## Availability
[Repeat table]

## Security
[Repeat table]

## Compliance
| ID | Requirement | Control Reference | Verification |
|---|---|---|---|

## Usability
[Repeat table]

## Maintainability
[Repeat table]

## Data
[Repeat table]

## Architecture Handoff
[NFR IDs that impose significant architecture constraints, with a one-line note on the implication]
```
