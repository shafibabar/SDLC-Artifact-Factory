# NFR Anti-Patterns and Output Format Template

Self-contained reference for the `nfr-specification` skill. Use this document when:
- Writing or reviewing an NFR document for anti-pattern violations
- Filling in the output format template for a new NFR artifact
- Calibrating Delivery (DORA) or Platform DX NFR entries against worked examples

---

## Anti-Patterns

### 1. Wish NFRs

"The system should be fast / secure / reliable."

These are moods, not requirements. Every one must be converted to metric + target + verification, or moved to open questions until it can be. A wish NFR produces no test, imposes no architecture decision, and provides no signal when the system fails to meet it. The symptom: a wish NFR will be "met" in every demo because it has no falsifying condition.

**Fix:** Force a number. "Fast" → "P95 API response < 200ms at 100 concurrent users, verified by a k6 load test." If no number can be agreed upon, the NFR is an open question, not a requirement.

---

### 2. Copy-Paste SLOs

Adopting "99.99% uptime" because that is what serious products claim.

Each additional nine multiplies architecture and operations cost — 99.9% allows 8.7 hours of downtime per year; 99.99% allows 52 minutes; 99.999% allows 5 minutes. For a single-tenant private deployment used during business hours, 99.5% is a defensible, honest target that costs a fraction of a 99.99% design. Every nine must be justified by a business driver (a contractual SLA commitment, a regulatory obligation, a competitive table-stakes analysis), not by habit.

**Fix:** Back-calculate from the business driver. "Our enterprise customers have SLA commitments of 99.5% monthly uptime to their own regulators — therefore our uptime SLO must be 99.5% or better." Then design to that number, not to the highest number the team can imagine.

---

### 3. Targets Without Load Context

"P95 < 200ms" is unfalsifiable until the conditions are stated.

At what concurrency? Against what data volume? On what reference hardware? In which environment (local, staging, production)? A performance NFR without its load profile will be "met" in every demo (1 user, empty database) and missed in every real workload (100 concurrent users, 10M-file estate). The latency target is only half the specification; the load profile is the other half.

**Fix:** Write every performance NFR in the form: "[metric] < [target] at [concurrency] concurrent users against a [data volume] data set, verified by a [tool] load test run in [environment]."

Example: "P95 API response time < 200ms at 100 concurrent users against a 10M-file estate in the staging environment, verified by a k6 load test that runs on every weekly release candidate."

---

### 4. Compliance Hand-Waving

"The system must be SOC 2 compliant."

SOC 2 is a report on controls, not a property a system has. A SOC 2 Type II report is the output of an audit that checks whether the organisation's controls operated effectively over a period of time. The system does not "become SOC 2 compliant" — the organisation passes or fails an audit that includes the system. Each applicable control must be individually addressed:

- Name the trust service criteria (CC6.1, CC7.2, A1.2, etc.)
- State the obligation it imposes on this specific system (logging, access control, encryption)
- State the automated check that verifies the control operates (a policy-as-code rule, a test that queries the audit log, a scan that checks encryption at rest)

**Fix:** For each regulatory framework, map it control-by-control to the system's implementation. "SOC 2 CC6.1 — all access to production systems is controlled and logged — verified by: automated test that confirms no production access without MFA; audit log completeness check run nightly."

---

### 5. Specified-Then-Orphaned NFRs

NFRs written in the Ideate phase that never become tests.

If an NFR ID does not appear in the Quality phase test plan, it was never a requirement — it was documentation theatre. The NFR ID (`NFR-PERF-001`, `NFR-DLVR-002`) is the traceability key; carry it through every artifact: from the NFR document to the test plan to the test case to the CI/CD gate that enforces it. An NFR without a corresponding test case is equivalent to a User Story with no acceptance criteria — it exists only to give the impression of rigour.

**Fix:** As part of the Quality phase kickoff, run a traceability audit: for each NFR ID in the NFR document, confirm a test (or measurement) exists in the test plan that references that ID. Any NFR without a test case is either missing its test (defect) or was never a real requirement (remove it).

---

### 6. Averages as Targets

"Average response time under 200ms" hides the tail where users actually suffer.

A system can meet a 200ms average while its P99 is 8 seconds. The users experiencing 8-second responses are invisible in the average — until they churn. Averages are appropriate for throughput metrics (average files classified per second) where individual variance does not matter. They are wrong for latency, because individual user experience is determined by their individual request time, not the mean of everyone else's.

**Fix:** Specify percentiles (P95, P99), never means, for any latency NFR. If the business case requires a "typical user" target, express it as P50 or P75 alongside a tail target (P99). "P50 < 100ms, P95 < 200ms, P99 < 1s" is a complete specification. "Average < 200ms" is not.

---

### 7. Delivery NFR Anti-Patterns (DORA-Specific)

**Gaming Deployment Frequency:** Deploying empty or trivial commits to hit a frequency target. The metric is deploys of real changes to production; a CI/CD pipeline that auto-deploys documentation-only changes to satisfy a frequency NFR is gaming the metric. Measure meaningful deployments (changes that affect at least one production binary or configuration file).

**Lead Time Without an Automated Pipeline:** Writing a Lead Time NFR of "< 1 hour" when the current deployment process requires a manual approval step, a change management ticket, or a scheduled release window. An NFR that the architecture cannot satisfy is not a requirement — it is a gap that must be closed first. Lead Time < 1 hour is only achievable with a fully automated CD pipeline; if one does not exist, the first NFR is "build the automated pipeline."

**MTTR Without Rollback Capability:** Specifying MTTR < 1 hour without specifying the rollback mechanism. MTTR is reduced by: (1) fast detection (alert within seconds), (2) fast diagnosis (distributed tracing, structured logs), and (3) fast remediation (automated rollback, feature flags, canary traffic shifting). An MTTR NFR must reference all three.

**Change Failure Rate Without a Definition of Failure:** "< 15% of deployments cause a failure" is incomplete without defining "failure." A failure is a deployment that requires a rollback, a hotfix deploy, or an emergency patch within the measurement window (commonly 7 days post-deploy). Cosmetic bugs that are fixed in the next scheduled release cycle are not failures by this definition.

---

## Output Format Template

Copy this template for every NFR artifact. Remove sections that genuinely have no requirements and replace with "No requirements in this category identified at this phase — revisit at Design phase." Do not leave sections empty.

```markdown
---
name: nfr-specification
product: [product name]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
architecture-handoff: [list of NFR IDs with architecture implications]
---

# Non-Functional Requirements Specification

## Performance
| ID | Requirement | Target | Load Context | Test Type |
|---|---|---|---|---|
| NFR-PERF-001 | API response time | P95 < 200ms | 100 concurrent users, 10M-file estate, staging env | k6 load test, weekly on release candidate |
| NFR-PERF-002 | File classification throughput | ≥ 1,000 files/min per worker | Sustained 30-minute load test | k6 scenario, weekly |

## Scalability
| ID | Requirement | Target | Test Type |
|---|---|---|---|
| NFR-SCAL-001 | Horizontal scaling linearity | Each worker adds 1,000 files/min capacity | Load test at 1, 2, 4, 8 worker nodes |

## Availability
| ID | Requirement | Target | Test Type |
|---|---|---|---|
| NFR-AVAIL-001 | Uptime SLO | 99.5% monthly | Measured via uptime monitor; reported in SLO dashboard |
| NFR-AVAIL-002 | RTO | < 4 hours | Verified by disaster-recovery drill, quarterly |
| NFR-AVAIL-003 | RPO | < 1 hour | Verified by backup-restoration test, monthly |

## Security
| ID | Requirement | Target | Test Type |
|---|---|---|---|
| NFR-SEC-001 | Authentication | JWT, 1-hour expiry | Automated integration test: expired token returns 401 |
| NFR-SEC-002 | Encryption in transit | mTLS on all service-to-service calls | Linkerd mesh verification test in CI |
| NFR-SEC-003 | Vulnerability management | No HIGH/CRITICAL CVEs in production images | Trivy scan gate in CI/CD pipeline |

## Compliance
| ID | Requirement | Control Reference | Verification |
|---|---|---|---|
| NFR-COMP-001 | Access control and logging | SOC 2 CC6.1 | Policy-as-code test: no production access without MFA; audit log completeness check nightly |
| NFR-COMP-002 | Data processing register | GDPR Article 30 | Automated register generation test: register contains all active processing activities |

## Usability
| ID | Requirement | Target | Test Type |
|---|---|---|---|
| NFR-USE-001 | Time to first value | New user reaches first compliance gap discovery within 30 minutes | Usability test with representative user panel |
| NFR-USE-002 | Accessibility | WCAG 2.1 Level AA | axe-core automated scan + manual screen reader audit |

## Maintainability
| ID | Requirement | Target | Test Type |
|---|---|---|---|
| NFR-MAINT-001 | Unit test coverage | ≥ 80% overall; 100% on domain logic packages | go test -cover in CI, coverage report gated |
| NFR-MAINT-002 | CI pipeline duration | < 10 minutes for full pipeline | GitHub Actions workflow duration measurement |
| NFR-MAINT-003 | Mean Time to Diagnose | Any production incident diagnosable within 30 minutes | Verified by incident post-mortem TTD metric |

## Data
| ID | Requirement | Target | Test Type |
|---|---|---|---|
| NFR-DATA-001 | Data residency | All customer data processed and stored within customer's declared infrastructure boundary | Architecture review; IaC deployment boundary test |
| NFR-DATA-002 | Audit log retention | 7 years; append-only; tamper-evident | Retention policy test; write-attempt-rejection test |
| NFR-DATA-003 | Backup | Daily encrypted backups; restoration tested monthly | Automated backup job; monthly restoration drill |

## Delivery (DORA Metrics)
*Applies to all services. Verified by measuring the CI/CD pipeline's actual behaviour.*

| ID | Requirement | DORA Target | Measurement Source |
|---|---|---|---|
| NFR-DLVR-001 | Deployment Frequency | On demand — deployable multiple times per day; no manual release window | GitHub Actions workflow run events on main; frequency counter in deployment dashboard |
| NFR-DLVR-002 | Lead Time for Changes | < 1 hour from commit merge to production running | Delta: commit timestamp (GitHub event) to deploy-complete timestamp (CD pipeline) |
| NFR-DLVR-003 | MTTR | < 1 hour to restore service after a production incident | Delta: alert-open timestamp (Alertmanager) to alert-closed timestamp; logged per incident |
| NFR-DLVR-004 | Change Failure Rate | < 15% of deployments require a rollback, hotfix, or emergency patch (rolling 30-day window) | Rollback event count / total deployment count in Deployment Frequency counter |

**Architecture implication:** NFR-DLVR-001 and NFR-DLVR-002 require a fully automated CD pipeline with no manual release steps. Flag for `enterprise-architect`.

## Platform DX (Developer Experience)
*Include only when this artifact specifies a platform capability, not a product feature.*

| ID | Requirement | Target | Verification |
|---|---|---|---|
| NFR-PDX-001 | Time-to-First-Deploy | A new engineer deploys to local environment within 1 business day using only the golden path documentation, without help from the platform team | Timed during onboarding; stopwatch starts day one, stops on confirmed successful local deploy |
| NFR-PDX-002 | Self-Service Coverage | ≥ 90% of common platform operations (create service, provision database, create environment, rotate secret, view logs, roll back deployment) achievable without a support ticket | Enumerated checklist audit: count self-service operations / total enumerated operations |
| NFR-PDX-003 | Exception Rate | Out-of-band deviation requests trend downward after quarter of initial platform adoption | Deviation log reviewed quarterly by platform team; rising rate triggers golden path gap analysis |

## Architecture Handoff
[NFR IDs that impose significant architecture constraints, with a one-line note on the implication]

| NFR ID | Constraint | Implication |
|---|---|---|
| NFR-DATA-001 | Physical data residency | Customer-controlled infrastructure boundary constrains deployment topology; multi-region hosting on shared cloud is excluded |
| NFR-SEC-002 | mTLS | Mandates Linkerd service mesh across all service-to-service paths |
| NFR-AVAIL-002 | RTO < 4 hours | Mandates automated failover; manual DR runbook cannot meet this target |
| NFR-SCAL-001 | Horizontal scaling | Mandates stateless service design; no server-side session state |
| NFR-DLVR-001 | Deployment Frequency | Mandates fully automated CD pipeline; release windows are excluded |
| NFR-DLVR-002 | Lead Time < 1 hour | Mandates automated pipeline from commit to production; any manual approval gate makes this NFR unachievable |
```

---

## Worked Examples: Delivery NFRs by DORA Performance Band

Use these to calibrate how ambitious to set Delivery NFRs for different service types.

### High-Performer Targets (Reference: *Accelerate*, Forsgren, Humble, Kim, Ch. 3)

Appropriate for: greenfield microservices with full CD pipeline automation, trunk-based development, comprehensive test automation.

| Metric | High Performer Target |
|---|---|
| Deployment Frequency | On demand, multiple times per day |
| Lead Time for Changes | < 1 hour |
| MTTR | < 1 hour |
| Change Failure Rate | 0–15% |

### Medium-Performer Targets

Appropriate for: services with partial automation, some manual approval gates, or a legacy dependency.

| Metric | Medium Performer Target |
|---|---|
| Deployment Frequency | Once per week to once per month |
| Lead Time for Changes | 1 day to 1 week |
| MTTR | < 1 day |
| Change Failure Rate | 0–15% |

### Calibration Note

The DORA research shows that high and medium performers share the same Change Failure Rate band (0–15%). A low change failure rate is achievable at any deployment frequency — high performers do not sacrifice stability for speed; they achieve both simultaneously through test automation and trunk-based development. Do not set a higher Change Failure Rate ceiling because the service deploys frequently; instead, invest in the technical practices that keep change failure rate low even at high frequency.

---

## Worked Examples: Platform DX NFRs

### Example: Internal Developer Platform — Local Environment Golden Path

**NFR-PDX-001 (Time-to-First-Deploy):**
- Requirement: A new engineer, given only the `README.md` and `make local-up`, can have the full local Kubernetes environment running with all services deployed within 1 business day of their first day.
- Verification: During every engineer onboarding, a platform team member (or buddy) times the process from `git clone` to confirmed running deployment. The stopwatch stops when `kubectl get pods` shows all services in Running state. Time is logged in the onboarding metrics spreadsheet.
- Anti-pattern to avoid: Measuring "setup time" as time to install dependencies, not time to first running deployment. The NFR is about a working deployed service, not a working development environment.

**NFR-PDX-002 (Self-Service Coverage):**
- Common operations to enumerate (per platform team review of the last 90 days of support tickets):
  1. Create a new service repository from the standard template
  2. Provision a new PostgreSQL database for a service
  3. Create a new Kubernetes namespace for a staging environment
  4. Rotate a service secret without redeploying
  5. Access structured logs for a service in the last 24 hours
  6. Roll back a deployment to the previous version
  7. Add a new Redpanda topic
  8. View the current SLO burn rate for a service
  9. Run a canary deployment for a new service version
  10. Add a new environment variable to a running service
- Self-service coverage = 9/10 = 90% (meets the ≥ 90% target if 9 of these are achievable via golden path CLI/UI without opening a ticket).

### Example: CI/CD Pipeline as Platform Capability

When the `ci-pipeline` or `cd-pipeline` skills' outputs are specified as platform capabilities (consumed by product teams), Platform DX NFRs apply:

**NFR-PDX-001 (Time-to-First-Deploy):** A new product service team can integrate their service into the CI/CD pipeline within 1 business day using only the pipeline documentation and the standard pipeline template. Verified by timing the integration during a new team's first sprint.

**NFR-PDX-002 (Self-Service Coverage):** Operations covered by the pipeline golden path include: add a test stage, change a deployment target, add a build argument, view pipeline logs, rerun a failed job, configure a deployment approval gate. If ≥ 90% of these are achievable without raising a platform support ticket, the coverage target is met.
