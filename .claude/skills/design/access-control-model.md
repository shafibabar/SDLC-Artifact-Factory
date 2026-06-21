# Skill: design/access-control-model

## Purpose
Produce the Access Control Model — the complete ABAC (Attribute-Based Access Control) policy specification. Defines all roles, permissions, resource attributes, and policy evaluation rules. This document is the reference the Identity Domain Service implements.

## Inputs
- `artifacts/design/security/security-architecture.md`
- `artifacts/ideate/personas/` (all persona files)
- `artifacts/design/bounded-contexts.md`
- `sdlc-config.json`

## Output
**File:** `artifacts/design/security/access-control-model.md`
**Registers in manifest:** yes

## ABAC Rules (enforced)
- ABAC evaluates: Subject attributes + Resource attributes + Action + Environment
- Default deny: if no policy explicitly permits an action, it is denied
- Tenant isolation is the highest-priority constraint — it supersedes all other permissions
- Role definitions are additive — a user with `compliance_officer` does not inherit `tenant_admin` permissions
- Service accounts (machine identities) follow the same ABAC model as human users
- Every permission that touches C4 data generates an audit log entry (enforced at policy evaluation time)

## Artifact Template

```markdown
# Access Control Model (ABAC)

**Product:** {product_name}
**Phase:** Design
**Artifact:** Access Control Model
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## ABAC Policy Structure

Every access decision evaluates:

```
PERMIT if:
  subject.tenant_id == resource.tenant_id    ← Mandatory; evaluated first
  AND action ∈ subject.permitted_actions(resource.type)
  AND (resource.classification < C4 OR action.is_audited == true)
DENY otherwise (default)
```

---

## Subject Roles

### tenant_admin
**Description:** Full administrative control within a tenant. Typically IT administrator or compliance programme owner.

**Permitted actions:**

| Resource type | Actions | Conditions |
|--------------|---------|-----------|
| `StorageLocation` | create, read, update, delete | Own tenant only |
| `ScanConfiguration` | create, read, update, delete | Own tenant only |
| `User` | create, read, update, deactivate | Own tenant only; cannot elevate own role |
| `ComplianceRule` | read (not write — rules managed by product) | Own tenant only |
| `Finding` | read, acknowledge, resolve, create_exception | Own tenant only |
| `AuditTrail` | read | Own tenant only |
| `AlertChannel` | create, read, update, delete | Own tenant only |
| `DataExport` | initiate | Own tenant only |

---

### compliance_officer
**Description:** Manages the compliance programme. Reviews findings, manages exceptions, produces audit evidence.

| Resource type | Actions | Conditions |
|--------------|---------|-----------|
| `Finding` | read, acknowledge, resolve, create_exception | Own tenant only |
| `ComplianceRule` | read | Own tenant only |
| `AuditTrail` | read | Own tenant only |
| `DataExport` | initiate (compliance evidence export only) | Own tenant only |
| `StorageLocation` | read | Own tenant only |
| `Entity` | read (metadata only — no C4 values in API response) | Own tenant only; **audited** |

---

### viewer
**Description:** Read-only access to dashboards and findings. For team members who need visibility without operational access.

| Resource type | Actions | Conditions |
|--------------|---------|-----------|
| `Finding` | read | Own tenant only |
| `ComplianceRule` | read | Own tenant only |
| `StorageLocation` | read (no credential_ref) | Own tenant only |

---

### auditor
**Description:** External or internal auditor. Read-only access to audit trail and compliance posture evidence. No operational access.

| Resource type | Actions | Conditions |
|--------------|---------|-----------|
| `AuditTrail` | read | Own tenant only; **audited** |
| `CompliancePosture` (read model) | read | Own tenant only |
| `Finding` | read | Own tenant only |

---

### worker_node (machine identity)
**Description:** The Worker Node deployed in customer infrastructure. Extremely restricted.

| Resource type | Actions | Conditions |
|--------------|---------|-----------|
| `ScanResult` (internal) | create | Own tenant only; restricted endpoint only |
| `ScanConfig` (internal) | read | Own tenant only; own location only |

---

## Resource Attributes

| Resource | Attributes used in policy | C4 flag |
|----------|--------------------------|---------|
| `StorageLocation` | `tenant_id`, `status` | No (path is C3) |
| `Finding` | `tenant_id`, `severity`, `status` | No (finding description may reference C4) |
| `Entity` | `tenant_id`, `classification` | Yes — `entity_value` field is C4 |
| `AuditTrail` | `tenant_id` | Yes — may contain C4 references |
| `User` | `tenant_id`, `role` | C3 |
| `DataExport` | `tenant_id`, `export_type` | Depends on export_type |

---

## C4 Data Access Policy

Any action that returns or modifies a C4 field:
1. Subject must be `tenant_admin` or `compliance_officer`
2. Action is logged with: `subject_id`, `tenant_id`, `resource_id`, `action`, `timestamp`, `ip_address`
3. C4 field values are **not returned in list endpoints** — only in single-resource detail endpoints
4. C4 field values are **masked in logs**: `"entity_value": "[REDACTED:C4]"`

---

## Forbidden Actions (Explicit Denials)

| Subject | Action | Resource | Reason |
|---------|--------|---------|--------|
| Any | read | Any resource with `tenant_id != subject.tenant_id` | Tenant isolation — highest priority rule |
| `viewer` | write, delete, admin | Any | Read-only role |
| `auditor` | write, delete, admin | Any | Read-only role |
| `worker_node` | Any except create `ScanResult`, read `ScanConfig` | Any | Principle of least privilege |
| `compliance_officer` | create, update, delete `User` | `User` | User management is tenant_admin only |
| Any | read `credential_ref` value | `StorageLocation` | Credentials are references only; the value is never returned by the API |

---

## Policy Evaluation Implementation Notes

- ABAC engine lives in the Identity Domain Service
- All other services call the Identity Domain via mTLS gRPC for permission checks (or validate a pre-signed capability token)
- ABAC evaluation result is cached per request (not across requests) — no stale cache risk
- ABAC `DENY` decisions are logged with reason code
- OPA (Open Policy Agent) is the recommended policy engine: policies as code, testable
```

## Quality Checks
- [ ] All roles from `artifacts/ideate/personas/` have a corresponding ABAC role (or are intentionally excluded)
- [ ] Default deny is stated
- [ ] Tenant isolation rule is the highest-priority check
- [ ] C4 data access policy is explicit about logging and masking
- [ ] Worker Node machine identity is defined with minimal permissions
- [ ] Forbidden actions table prevents privilege escalation vectors
- [ ] Policy engine implementation technology is named
