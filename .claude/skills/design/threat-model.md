# Skill: design/threat-model

## Purpose
Produce a STRIDE Threat Model — a systematic analysis of threats against the system using the STRIDE framework (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege). For each threat: identify, rate risk, assign mitigation, and track status.

## Inputs
- `artifacts/design/security/security-architecture.md`
- `artifacts/design/architecture/c4-container.md`
- `artifacts/design/data/data-classification.md`
- `sdlc-config.json`

## Output
**File:** `artifacts/design/security/threat-model.md`
**Registers in manifest:** yes

## STRIDE Methodology

| Letter | Threat type | Violates | Examples |
|--------|------------|---------|---------|
| S | Spoofing | Authentication | Fake JWT, impersonating a WorkerNode |
| T | Tampering | Integrity | Modifying a finding, altering an audit entry |
| R | Repudiation | Non-repudiation | Claiming a finding was not acknowledged |
| I | Information Disclosure | Confidentiality | PII leaking via error messages, cross-tenant data |
| D | Denial of Service | Availability | Scan flood, DLQ explosion |
| E | Elevation of Privilege | Authorisation | viewer accessing admin endpoints |

## Risk Rating (DREAD-lite)
Each threat is rated: **Critical / High / Medium / Low**
- **Critical:** Easy to exploit; high impact; no current mitigation
- **High:** Feasible to exploit; significant impact; partial mitigation
- **Medium:** Difficult to exploit OR limited impact
- **Low:** Hard to exploit AND limited impact

## Artifact Template

```markdown
# STRIDE Threat Model

**Product:** {product_name}
**Phase:** Design
**Artifact:** Threat Model
**Version:** 1.0
**Date:** {date}
**Scope:** Full product system (per c4-container.md)
**Status:** Draft

---

## Threat Summary

| ID | STRIDE type | Component | Threat | Risk | Mitigation status |
|----|------------|---------|--------|------|-----------------|
| T-S-01 | Spoofing | API Gateway | Forged JWT token | High | Mitigated |
| T-S-02 | Spoofing | Internal mesh | Compromised WorkerNode impersonating product service | High | Mitigated |
| T-T-01 | Tampering | Audit Domain | Modification of audit trail entries | Critical | Mitigated |
| T-T-02 | Tampering | Redpanda | Injecting malicious events into event stream | High | Mitigated |
| T-R-01 | Repudiation | Compliance Domain | User denies acknowledging a finding | Medium | Mitigated |
| T-I-01 | Information Disclosure | Entity Domain | PII exposed in API error responses | Critical | Mitigated |
| T-I-02 | Information Disclosure | Cross-tenant | Tenant A accessing Tenant B's findings | Critical | Mitigated |
| T-I-03 | Information Disclosure | Logs | PII appearing in application log entries | High | Mitigated |
| T-D-01 | Denial of Service | File Domain | Scan flood — registering thousands of locations | High | Mitigated |
| T-D-02 | Denial of Service | Redpanda | DLQ flood — poison message causing consumer restart loop | Medium | Mitigated |
| T-E-01 | Elevation of Privilege | API Gateway | viewer role accessing admin-only endpoints | High | Mitigated |
| T-E-02 | Elevation of Privilege | Worker Node | Worker Node calling unauthorised control plane APIs | High | Mitigated |

---

## Threat Details

### T-S-01 — Forged JWT Token
**Threat:** An attacker forges a JWT to authenticate as another user or tenant.

**Attack vector:** Attacker obtains or generates a JWT with a modified `tenant_id` or `roles[]` claim.

**Mitigation:**
- JWTs are signed RS256 with the Identity Domain's private key (stored in Kubernetes Secret)
- API Gateway validates signature on every request using the public key
- `alg: none` JWTs are rejected (algorithm enforcement)
- JWT `exp` claim enforced: max 1 hour lifetime

**Residual risk:** Low — requires compromise of the RS256 signing key.

---

### T-T-01 — Audit Trail Tampering
**Threat:** An attacker (or insider) modifies or deletes audit trail entries to cover their tracks.

**Attack vector:** Direct database access; compromised service account; SQL injection via audit service.

**Mitigation:**
- Audit table uses `INSERT ONLY` grant at PostgreSQL level — no UPDATE or DELETE privileges for the audit service user
- Audit entries include a chained hash: `entry_hash = SHA256(previous_hash + entry_content)` — tampering is detectable
- Audit database is on a separate schema with separate credentials from other services
- PostgreSQL role for audit service: `GRANT INSERT ON audit_entries TO audit_svc_role` only

**Residual risk:** Low — requires database administrator level access AND hash chain compromise.

---

### T-I-01 — PII in API Error Responses
**Threat:** PII values extracted from customer files appear in API error messages, logs, or stack traces.

**Attack vector:** Processing pipeline error includes entity value in error message; error propagates to API response.

**Mitigation:**
- Entity values are never included in log messages — logs reference entity by `entity_id` only
- API error responses use RFC 7807 Problem Details — no internal state or entity values in `detail` field
- Integration tests verify that error responses do not contain known PII patterns (regex scan in CI)
- Structured logging library (`slog`) is configured to redact C4-classified field names

**Residual risk:** Medium — developer error could introduce PII in new log statements. Mitigated by CI regression test.

---

### T-I-02 — Cross-Tenant Data Access
**Threat:** Tenant A's user accesses Tenant B's data via API or database.

**Attack vector:** Missing `tenant_id` filter in a query; JWT manipulation; misconfigured ABAC rule.

**Mitigation:**
- JWT `tenant_id` claim is the authoritative tenant scope — all repository queries include `WHERE tenant_id = $1`
- ABAC policy engine checks `resource.tenant_id == subject.tenant_id` for every resource access
- Physical multi-tenancy: each tenant has a dedicated PostgreSQL cluster — cross-cluster queries are architecturally impossible
- Integration tests assert that resources from Tenant A are not visible with Tenant B's JWT

**Residual risk:** Low (physical isolation) — cross-tenant contamination requires cluster-level breach.

---

### T-D-01 — Scan Flood
**Threat:** A user registers thousands of storage locations rapidly, overwhelming scan queue and compute.

**Attack vector:** Authenticated user with admin role calls `POST /storage-locations` in a loop.

**Mitigation:**
- Rate limiting: 60 write requests/minute per tenant (API Gateway)
- Concurrent scan limit: configurable max concurrent scans per tenant
- Resource cap enforcement: `resource_cap_percent` in ScanConfiguration limits per-scan CPU usage
- Alert: Prometheus alert on scan queue depth > threshold

**Residual risk:** Low — rate limiting and resource caps contain blast radius.

---

### T-E-02 — Worker Node Privilege Escalation
**Threat:** A compromised Worker Node calls control plane APIs it should not have access to (e.g., listing all tenants, reading compliance findings).

**Attack vector:** Compromised Worker Node uses its mTLS certificate to call any product API.

**Mitigation:**
- Worker Node mTLS certificate identifies the workload identity as `worker-node-{tenant_id}`
- ABAC policy: `worker-node` identity may only call: `POST /internal/scan-results` and `GET /internal/scan-config/{location_id}` — scoped to its own tenant
- All other API calls from a worker-node identity are rejected with 403 and logged as a security event

**Residual risk:** Low — Worker Node access is scoped to its own tenant and two endpoints only.

---

## Open Threats (unmitigated or partially mitigated)

| ID | Threat | Gap | Target resolution |
|----|--------|-----|------------------|
| T-I-04 | Side-channel timing attack on ABAC decisions | Theoretical risk; no practical exploit identified | Monitor and assess in security review |

---

## Threat Model Review Schedule

| Review trigger | Action |
|---------------|--------|
| New bounded context added | Re-run STRIDE analysis for new context |
| New external integration | Add threats for new integration point |
| Security incident | Retrospective: was this threat modelled? Update model. |
| Annually (minimum) | Full model review |
```

## Quality Checks
- [ ] All six STRIDE categories have at least one threat per major component
- [ ] Every High/Critical threat has a concrete mitigation (not "to be decided")
- [ ] Cross-tenant data access is explicitly addressed (T-I-02 equivalent)
- [ ] Audit trail tampering is explicitly addressed (T-T-01 equivalent)
- [ ] PII disclosure via logs or error messages is explicitly addressed
- [ ] Open/unmitigated threats are tracked separately
- [ ] Review schedule is documented
