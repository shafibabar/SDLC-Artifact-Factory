# Skill: ideate/nfr-specification

## Purpose
Produce a Non-Functional Requirements (NFR) specification with measurable targets per quality attribute. NFRs constrain HOW the system behaves, not WHAT it does. They directly drive architecture decisions, SLO definitions, and test acceptance criteria.

## Inputs
Read before generating:
- `artifacts/ideate/requirements/functional.md` — must exist
- `sdlc-config.json` — compliance_frameworks, tenancy_model, deployment_target, sensitive_data_types
- `artifacts/strategy/roadmap.md` — for scale expectations

## Output
**File:** `artifacts/ideate/requirements/nfrs.md`
**Registers in manifest:** yes

## NFR Categories to Cover (all mandatory)
Performance, Scalability, Availability, Reliability, Security, Privacy, Compliance, Data Integrity, Maintainability, Portability, Observability, Usability

## Process
1. Read functional requirements, config, and roadmap.
2. For each NFR category, derive measurable targets appropriate to the product's scale and compliance posture.
3. For each target: state the metric, the measurement method, and the consequence of violation.
4. Tag NFRs that are driven by compliance frameworks.
5. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# Non-Functional Requirements Specification

**Product:** {product_name}
**Phase:** Ideate
**Artifact:** NFR Specification
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## NFR-01: Performance

| ID | Requirement | Target | Measurement method | Compliance tag |
|----|-------------|--------|--------------------|----------------|
| NFR-01.1 | API response time (p99) | ≤ 500ms under normal load | Prometheus histogram, p99 latency metric | |
| NFR-01.2 | Time from file event detected to finding surfaced | ≤ 30 seconds | Distributed trace: event timestamp to finding_created event timestamp | |
| NFR-01.3 | Initial full scan throughput | ≥ {N} files/minute per worker node | Crawl completion time / file count | |

## NFR-02: Scalability

| ID | Requirement | Target | Measurement method | Notes |
|----|-------------|--------|--------------------|-------|
| NFR-02.1 | Horizontal scaling of processing services | Each service scales independently without downtime | Kubernetes HPA, load test validation | |
| NFR-02.2 | Maximum tenant data volume supported (MVP) | {N} GB indexed per tenant | Load test with synthetic data | |
| NFR-02.3 | Maximum concurrent users per tenant (MVP) | {N} concurrent active sessions | Load test | |

## NFR-03: Availability

| ID | Requirement | Target | Measurement method | Compliance tag |
|----|-------------|--------|--------------------|----------------|
| NFR-03.1 | Service availability SLO | 99.9% monthly uptime | Prometheus uptime metric, SLO dashboard | [COMPLIANCE: SOC2-A1] |
| NFR-03.2 | Planned maintenance window | Zero downtime deployments only | Blue-green / canary deployment validation | |
| NFR-03.3 | Recovery Time Objective (RTO) | ≤ {N} hours from catastrophic failure | DR drill results | [COMPLIANCE: SOC2-A1] |
| NFR-03.4 | Recovery Point Objective (RPO) | ≤ {N} hours data loss | Backup frequency validation | [COMPLIANCE: SOC2-A1] |

## NFR-04: Reliability

| ID | Requirement | Target | Measurement method |
|----|-------------|--------|--------------------|
| NFR-04.1 | Message delivery guarantee | At-least-once delivery for all domain events | DLQ monitoring; zero silent drops |
| NFR-04.2 | Idempotency of all event handlers | Processing the same event N times = processing it once | Contract test: replay events, verify no duplicate state |
| NFR-04.3 | Circuit breaker activation time | Trips within {N} consecutive failures or {N}% error rate in {window} | Circuit breaker state metric |

## NFR-05: Security

| ID | Requirement | Target | Measurement method | Compliance tag |
|----|-------------|--------|--------------------|----------------|
| NFR-05.1 | All data in transit | Encrypted via TLS 1.2+ (external) and mTLS (internal) | Linkerd mesh config, TLS scan | [COMPLIANCE: SOC2-CC6] |
| NFR-05.2 | All data at rest | Encrypted using AES-256 or equivalent | Storage config audit | [COMPLIANCE: SOC2-CC6] |
| NFR-05.3 | Authentication token lifetime | Access token ≤ 15 minutes; refresh token ≤ 24 hours | JWT expiry validation in security test suite | [COMPLIANCE: SOC2-CC6] |
| NFR-05.4 | Vulnerability scanning | Zero critical CVEs in production; high CVEs remediated within 7 days | Dependency scanning in CI | |
| NFR-05.5 | Penetration test | Annual external pen test; no critical findings unresolved | Pen test report | [COMPLIANCE: SOC2-CC7] |

## NFR-06: Privacy

| ID | Requirement | Target | Measurement method | Compliance tag |
|----|-------------|--------|--------------------|----------------|
| NFR-06.1 | Data minimisation | No customer data stored beyond what is required for the stated purpose | Data flow audit | [COMPLIANCE: GDPR-Art5] |
| NFR-06.2 | Data subject request fulfillment | Respond to erasure request within 30 days | Process + audit log review | [COMPLIANCE: GDPR-Art17] |
| NFR-06.3 | Customer data residency | Customer data never transits to shared vendor infrastructure | Architecture review + network policy audit | |

## NFR-07: Compliance

| ID | Requirement | Target | Measurement method | Framework |
|----|-------------|--------|--------------------|-----------|
| NFR-07.1 | Audit log retention | Minimum {N} years of immutable audit log | Storage policy + read-back verification | SOC2, GDPR |
| NFR-07.2 | Audit log tamper evidence | Any modification to historical records is detectable | Hash chain verification test | SOC2-CC7 |
| NFR-07.3 | Access control review | Quarterly access review for all privileged roles | Review records in audit log | SOC2-CC6 |

## NFR-08: Data Integrity

| ID | Requirement | Target | Measurement method |
|----|-------------|--------|--------------------|
| NFR-08.1 | Database write durability | ACID compliance for all transactional writes | PostgreSQL configuration; integration test with failure injection |
| NFR-08.2 | Event immutability | No update or delete operations permitted on domain events | Database policy; application layer prohibition enforced in contract tests |
| NFR-08.3 | File content integrity | Checksum stored at extraction time; re-processing validated against checksum | Extraction pipeline contract test |

## NFR-09: Maintainability

| ID | Requirement | Target | Measurement method |
|----|-------------|--------|--------------------|
| NFR-09.1 | Code test coverage | ≥ 80% unit test coverage per service | Go coverage report in CI |
| NFR-09.2 | Time to onboard a new engineer | ≤ 1 day to run locally and pass all tests | Onboarding exercise with first contractor |
| NFR-09.3 | Mean time to deploy a bug fix | ≤ 4 hours from merge to production | CI/CD pipeline metrics |

## NFR-10: Observability

| ID | Requirement | Target | Measurement method |
|----|-------------|--------|--------------------|
| NFR-10.1 | Distributed tracing coverage | All inter-service calls traced end-to-end | Tempo trace completeness check |
| NFR-10.2 | Log correlation | All logs include trace ID for request correlation | Log field validation in CI |
| NFR-10.3 | SLO dashboards | Grafana SLO dashboard available for each service from Day 1 of production | Dashboard existence check in deploy runbook |

## NFR Summary

| Category | Requirements count | Compliance-tagged count |
|----------|--------------------|------------------------|
| Performance | {n} | {n} |
| Scalability | {n} | {n} |
| Availability | {n} | {n} |
| Reliability | {n} | {n} |
| Security | {n} | {n} |
| Privacy | {n} | {n} |
| Compliance | {n} | {n} |
| Data Integrity | {n} | {n} |
| Maintainability | {n} | {n} |
| Observability | {n} | {n} |
```

## Quality Checks
Before writing:
- [ ] Every NFR has a numeric or binary-pass/fail target — no vague targets ("fast", "secure")
- [ ] Every NFR has a defined measurement method
- [ ] All compliance-tagged NFRs reference a specific framework clause
- [ ] NFRs in the Security, Privacy, and Compliance categories are present regardless of config — these are never optional
- [ ] No undefined ubiquitous language terms
