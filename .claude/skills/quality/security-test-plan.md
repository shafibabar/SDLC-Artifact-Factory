# Skill: quality/security-test-plan

## Purpose
Produce the Security Test Plan — the specification of automated and manual security tests across OWASP Top 10, authentication/authorisation, tenant isolation, secrets handling, and compliance-mandated security checks. Security tests run in CI and on a schedule. A security gate blocks release when failures are found.

## Inputs
- `artifacts/design/security/threat-model.md`
- `artifacts/design/security/access-control-model.md`
- `artifacts/design/security/security-architecture.md`
- `artifacts/design/security/privacy-design.md`
- `sdlc-config.json` (compliance_frameworks)

## Output
**File:** `artifacts/quality/security-test-plan.md`
**Registers in manifest:** yes

## Security Test Rules (enforced)
- Every threat in the threat model maps to at least one security test.
- OWASP Top 10 is covered test-by-test — not asserted by a blanket statement.
- Tenant isolation tests are in the E2E suite, not just the unit suite — real API calls.
- Secret scanning (`gitleaks`) is a hard CI gate on every commit.
- DAST runs on a schedule against staging (not just on release).

## Artifact Template

```markdown
# Security Test Plan

**Product:** {product_name}
**Phase:** Quality
**Artifact:** Security Test Plan
**Standards:** OWASP Top 10 (2021), CWE/SANS Top 25
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Security Test Layers

| Layer | Tool | Runs | Gate |
|-------|------|------|------|
| Secret scanning | gitleaks | CI — every commit (pre-merge) | Hard block |
| Static analysis (SAST) | gosec v2 | CI — every commit | Hard block (HIGH+) |
| Dependency vulnerability | govulncheck | CI — every commit | Hard block (CRITICAL) |
| Container image scan | trivy | CI — on image build | Hard block (CRITICAL) |
| Infrastructure scan | trivy (IaC mode) | CI — on OpenTofu change | Hard block (HIGH+) |
| Dynamic analysis (DAST) | OWASP ZAP | Weekly — against staging | Hard block on MEDIUM+ |
| Manual penetration test | External firm | Annually | — |
| Compliance scan | OPA policies | CI — every commit | Hard block |

---

## OWASP Top 10 Coverage

### A01: Broken Access Control
| Test | Mechanism | Tool |
|------|-----------|------|
| ST-A01-01: Cross-tenant API read | Authenticated as Tenant A, attempt GET /api/v1/storage-locations/{tenant-B-id} | E2E test (godog) |
| ST-A01-02: Cross-tenant write | Authenticated as Tenant A, attempt DELETE /api/v1/findings/{tenant-B-finding-id} | E2E test |
| ST-A01-03: Role escalation | viewer-role user attempts compliance_officer action | Integration test |
| ST-A01-04: Missing auth header | API call with no Authorization header | Unit test (handler) |
| ST-A01-05: Expired JWT | API call with expired token | Unit test |

**Pass criterion:** All cross-tenant operations return 403 (not 404, not 500, not the data).

---

### A02: Cryptographic Failures
| Test | Mechanism | Tool |
|------|-----------|------|
| ST-A02-01: TLS minimum version | Attempt TLS 1.1 connection to API gateway | ZAP active scan |
| ST-A02-02: Cipher suite | Verify only strong cipher suites accepted | testssl.sh (manual) |
| ST-A02-03: C4 field encryption | Verify `value_encrypted` column is not plaintext in PG | Integration test (direct DB read) |
| ST-A02-04: Secrets in logs | Send request with sensitive payload; verify logs do not contain raw values | Integration test (log capture) |

---

### A03: Injection
| Test | Mechanism | Tool |
|------|-----------|------|
| ST-A03-01: SQL injection via path param | `GET /api/v1/storage-locations/' OR '1'='1` | ZAP + unit test |
| ST-A03-02: SQL injection via body | POST body with SQL fragments in string fields | ZAP + unit test |
| ST-A03-03: NoSQL injection (ES) | JSON injection in search query parameters | Unit test |
| ST-A03-04: Template injection | String fields with `{{.Payload}}` content | ZAP |

**Pass criterion:** No injection succeeds. All injection inputs return 400 (validation rejection) or 422.

---

### A04: Insecure Design
| Test | Mechanism | Tool |
|------|-----------|------|
| ST-A04-01: Rate limiting enforced | Exceed 100 req/min on POST endpoints; expect 429 | E2E test |
| ST-A04-02: Pagination required | Request without page size; verify default cap applied | Unit test |
| ST-A04-03: Credential reference only | POST body with a raw credential value; verify rejection | Unit test |

---

### A05: Security Misconfiguration
| Test | Mechanism | Tool |
|------|-----------|------|
| ST-A05-01: Debug endpoints disabled | `GET /debug/vars`, `/metrics` not exposed on public port | E2E test |
| ST-A05-02: CORS restrictive | Attempt cross-origin request from non-allowlisted origin | ZAP |
| ST-A05-03: Security headers present | X-Content-Type-Options, X-Frame-Options, HSTS | ZAP passive scan |
| ST-A05-04: Default credentials changed | No default passwords on any service | Manual check at provisioning |

---

### A06: Vulnerable Components
| Test | Mechanism | Tool |
|------|-----------|------|
| ST-A06-01: Go module CVEs | `govulncheck ./...` | CI — every commit |
| ST-A06-02: Container base image CVEs | `trivy image {image}` | CI — on image build |
| ST-A06-03: Third-party API dependencies | Manual review of all external API SDKs | Quarterly |

---

### A07: Identification and Authentication Failures
| Test | Mechanism | Tool |
|------|-----------|------|
| ST-A07-01: JWT signature verification | Submit JWT with modified payload (signature invalid) | Unit test |
| ST-A07-02: JWT algorithm confusion | Submit JWT with alg=none | Unit test |
| ST-A07-03: Refresh token rotation | Verify old refresh token rejected after rotation | Integration test |
| ST-A07-04: mTLS enforcement | Service-to-service call without mTLS cert; verify rejection by Linkerd | E2E test |

---

### A08: Software and Data Integrity Failures
| Test | Mechanism | Tool |
|------|-----------|------|
| ST-A08-01: Secret scanning | `gitleaks detect --source .` | CI — hard gate |
| ST-A08-02: Image signing | Verify container images are signed before deployment | CD pipeline check |
| ST-A08-03: Dependency integrity | `go mod verify` | CI |

---

### A09: Logging and Monitoring Failures
| Test | Mechanism | Tool |
|------|-----------|------|
| ST-A09-01: Authentication failure logged | Invalid JWT → verify WARN log emitted with trace ID | Integration test |
| ST-A09-02: ABAC denial logged | Cross-tenant attempt → verify WARN log with user_id and resource | Integration test |
| ST-A09-03: PII not in logs | Request containing PII fields → verify logs do not contain PII values | Integration test (log scan) |
| ST-A09-04: Alert fires on breach | Inject 10 failed auth attempts → verify PrometheusAlert fires | Staging test |

---

### A10: Server-Side Request Forgery (SSRF)
| Test | Mechanism | Tool |
|------|-----------|------|
| ST-A10-01: Credential ref SSRF | POST credential_ref with internal service URL (`http://169.254.169.254/`) | Unit test + ZAP |
| ST-A10-02: File path traversal | storage_path with `../../etc/passwd` | Unit test |

---

## Tenant Isolation Security Tests

These are distinct from OWASP coverage — they target the specific multi-tenancy threat model.

| Test ID | Scenario | Expected result |
|---------|---------|----------------|
| ST-ISO-01 | API: Tenant A reads Tenant B resource by guessing UUID | 403 |
| ST-ISO-02 | API: Tenant A writes to Tenant B resource | 403 |
| ST-ISO-03 | DB: RLS policy prevents cross-tenant query | 0 rows returned |
| ST-ISO-04 | Event: Tenant A event does not appear in Tenant B consumer | Verified via consumer group assertion |
| ST-ISO-05 | Graph: Tenant A node is not traversable from Tenant B's graph queries | 0 results |

---

## Security Gate Definition

A release is blocked if:
- Any gitleaks finding (no exceptions — FAIL immediately)
- Any gosec HIGH or CRITICAL finding not acknowledged in `.gosec-ignore`
- Any govulncheck CRITICAL finding
- Any ZAP MEDIUM+ active scan finding (weekly DAST run)
- Any ST-A01 or ST-ISO test failing
```

## Quality Checks
- [ ] Every OWASP Top 10 category has at least one concrete test
- [ ] Tenant isolation tests are E2E (real API calls, not mocked)
- [ ] Secret scanning is a CI hard gate (not advisory)
- [ ] Cross-tenant tests assert 403 (not 404 — leaking existence is also a defect)
- [ ] PII-in-logs test is present
- [ ] Security gate definition is explicit about blocking conditions
