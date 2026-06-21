# Skill: design/multi-tenancy-design

## Purpose
Produce the Multi-Tenancy Design document — the complete specification of how tenant isolation is enforced at every layer: network, compute, database, application, and API. This document answers "how does Tenant A's data stay completely separated from Tenant B's data?"

## Inputs
- `sdlc-config.json` (tenancy_model)
- `artifacts/design/platform/deployment-architecture.md`
- `artifacts/design/security/security-architecture.md`
- `artifacts/design/data/data-architecture.md`

## Output
**File:** `artifacts/design/platform/multi-tenancy-design.md`
**Registers in manifest:** yes

## Multi-Tenancy Rules (enforced)
- Physical multi-tenancy: dedicated infrastructure per tenant. No shared databases, no shared queues, no shared compute namespaces.
- The `tenant_id` from the JWT is the immutable source of truth for all tenant-scoped operations.
- Tenant provisioning and deprovisioning are automated — no manual steps.
- Cross-tenant data access generates a security event and is denied.

## Artifact Template

```markdown
# Multi-Tenancy Design

**Product:** {product_name}
**Phase:** Design
**Artifact:** Multi-Tenancy Design
**Version:** 1.0
**Date:** {date}
**Model:** Physical multi-tenancy
**Status:** Draft

---

## Isolation Layers

| Layer | Isolation mechanism | Shared between tenants? |
|-------|-------------------|------------------------|
| Kubernetes namespace | Dedicated namespace per tenant | No |
| NetworkPolicy | Ingress/egress restricted to own namespace | No |
| Linkerd AuthorizationPolicy | mTLS + allow-list per namespace | No |
| PostgreSQL | Dedicated cluster per tenant | No |
| Redpanda | Dedicated broker (or dedicated topic namespace per tenant on shared broker) | No (dedicated topics) |
| Elasticsearch | Dedicated index per tenant (`{index}-{tenant_id}`) | Index only; same cluster |
| Object storage (backups) | Dedicated bucket prefix per tenant | Prefix-isolated |
| Kubernetes Secrets | Scoped to tenant namespace | No |
| JWT `tenant_id` claim | API Gateway enforces tenant scope on all requests | N/A |
| ABAC engine | `resource.tenant_id == subject.tenant_id` rule | N/A |

---

## Tenant Lifecycle

### Tenant Provisioning

Triggered by: new customer contract signed; Customer Success team initiates provisioning.

**Automated steps:**
1. OpenTofu creates dedicated PostgreSQL cluster for tenant (or isolated schema set on shared cluster for standard tier)
2. OpenTofu creates dedicated Redpanda topic namespace
3. Helm deploys all domain services to dedicated Kubernetes namespace
4. Identity Domain provisioned with tenant configuration
5. Admin user created; onboarding email sent
6. Worker Node configuration package generated

**Duration:** Target < 30 minutes for standard tier; < 2 hours for enterprise cluster tier.

---

### Tenant Deprovisioning

Triggered by: contract end; customer initiated termination.

**Steps:**
1. Tenant marked as `DEPROVISIONING` — no new logins accepted
2. In-progress scans are gracefully terminated
3. Data export package generated and delivered to customer (if requested)
4. Data deletion executed per Data Retention Policy (C4 field-level key destruction + hard delete)
5. Kubernetes namespace removed
6. PostgreSQL cluster stopped and data deleted after 30-day confirmation window
7. Redpanda topics purged
8. Elasticsearch indices deleted
9. Customer object storage credentials removed from product systems
10. Tenant deletion audit entry written (immutable record that tenant existed and was deprovisioned)

---

## Cross-Tenant Access Prevention

### Defense Layers

1. **Network isolation:** Kubernetes NetworkPolicy blocks all cross-namespace pod communication
2. **mTLS identity:** Linkerd AuthorizationPolicy only allows traffic from the same namespace
3. **JWT enforcement:** API Gateway validates `tenant_id` in JWT against requested resource on every request
4. **ABAC policy:** `resource.tenant_id != subject.tenant_id` → DENY + security event logged
5. **Database isolation:** Physical cluster separation means SQL injection in one tenant cannot read another tenant's data
6. **Application layer:** All repository queries include `WHERE tenant_id = $1` — parameterised

### Breach Detection

Any of these conditions triggers a security alert:
- ABAC DENY on `tenant_id` mismatch (should never occur — indicates bug or attack)
- Attempt to access another tenant's Kubernetes namespace (NetworkPolicy violation log)
- JWT with a `tenant_id` that does not match a provisioned tenant

---

## Tenant Data Residency

For tenants with data residency requirements:
- The PostgreSQL cluster and Kubernetes nodes for the tenant are provisioned in the customer's required region
- `deployment_region` is captured at onboarding and drives OpenTofu `provider.region`
- Data NEVER leaves the provisioned region — Redpanda topics and ES indices are within the same region
- Backups are stored in the same region as the primary data

---

## Shared Infrastructure (Acceptable)

The following components are shared across tenants:
- **Kubernetes control plane** (standard tier) — not a data plane; no tenant data processed here
- **Grafana / Prometheus / Tempo** — observability only; metrics and traces are tagged by `tenant_id` and scoped in Grafana dashboards; no cross-tenant visibility in UI
- **Linkerd control plane** — certificate authority and policy controller; tenant data planes are isolated

**Note:** Elasticsearch is shared cluster but isolated at index level. A SOC2 auditor or enterprise customer may request dedicated ES cluster — this is an upgrade path, not default.
```

## Quality Checks
- [ ] Isolation is documented at every layer (network, compute, DB, application, API)
- [ ] Tenant provisioning is automated with target duration specified
- [ ] Tenant deprovisioning includes data deletion procedure
- [ ] Cross-tenant access has at least 3 defence layers documented
- [ ] Data residency handling is addressed
- [ ] Shared infrastructure items are explicitly identified and justified
