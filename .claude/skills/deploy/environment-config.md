# Skill: deploy/environment-config

## Purpose
Produce an Environment Configuration document for one deployment environment — the complete specification of how that environment differs from others in terms of infrastructure sizing, feature flags, SLOs, data shape, and access control. Environments are cattle, not pets: this document is the authoritative definition.

## Inputs
- `artifacts/design/platform/deployment-architecture.md`
- `artifacts/design/platform/multi-tenancy-design.md`
- `sdlc-config.json` (deployment_targets)
- **Argument required:** environment name (`dev`, `staging`, `production`)

## Output
**File:** `artifacts/deploy/envs/{env-name}.md`
**Registers in manifest:** yes

## Environment Config Rules (enforced)
- Every configuration difference from the default must be documented with a justification.
- No environment has manual configuration that is not captured here.
- Secrets are referenced by Vault path — never by value.
- Production always has: deletion protection, backup, PDB, HPA, mTLS enforced.

## Artifact Template

```markdown
# Environment Configuration: {env-name}

**Product:** {product_name}
**Phase:** Deploy
**Artifact:** Environment Configuration
**Environment:** {dev | staging | production}
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Infrastructure

| Component | dev (kind) | staging (k3s) | production (EKS/GKE/AKS) |
|-----------|-----------|--------------|--------------------------|
| Kubernetes | kind (local) | k3s (single node or 3-node HA) | Managed K8s (3+ nodes) |
| PostgreSQL | Docker container (no HA) | RDS t4g.micro | RDS t4g.medium + read replica |
| Redpanda | Docker container | Single broker | 3-broker cluster |
| Elasticsearch | Docker container | Single node | 3-node cluster |
| Replicas per service | 1 | 2 | 3 minimum |
| HPA | Disabled | Enabled | Enabled |
| PDB | Disabled | Enabled (minAvailable 1) | Enabled (minAvailable 2) |

---

## Service Configuration

### dev
```yaml
# Helm values-dev.yaml (overrides)
replicaCount: 1
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "256Mi"
    cpu: "200m"
autoscaling:
  enabled: false
podDisruptionBudget:
  enabled: false
env:
  LOG_LEVEL: debug
  OTEL_TRACE_SAMPLE_RATE: "1.0"   # 100% sampling in dev
```

### staging
```yaml
# Helm values-staging.yaml
replicaCount: 2
env:
  LOG_LEVEL: info
  OTEL_TRACE_SAMPLE_RATE: "0.1"   # 10% sampling
```

### production
```yaml
# Helm values-production.yaml
replicaCount: 3
resources:
  requests:
    memory: "256Mi"
    cpu: "200m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
autoscaling:
  minReplicas: 3
  maxReplicas: 20
env:
  LOG_LEVEL: warn
  OTEL_TRACE_SAMPLE_RATE: "0.01"  # 1% sampling (cost control)
```

---

## Secret References

| Secret | dev | staging | production |
|--------|-----|---------|-----------|
| DB connection | `vault://dev/{svc}/db` | `vault://staging/{svc}/db` | `vault://production/{svc}/db` |
| JWT signing key | `vault://dev/platform/jwt` | `vault://staging/platform/jwt` | `vault://production/platform/jwt` |

---

## Feature Flags

| Flag | dev | staging | production |
|------|-----|---------|-----------|
| `enable_chaos_endpoints` | true | true | false |
| `enable_debug_endpoints` | true | false | false |
| `enable_slow_consumer_simulation` | configurable | configurable | false |

---

## Access

| Access type | dev | staging | production |
|------------|-----|---------|-----------|
| Direct kubectl | Developer laptops | CI service account only | Platform team only, MFA |
| Database direct access | Allowed (local) | Via bastion, 1h session | Via bastion, 1h session, 4-eye |
| Log access | Local terminal | Kibana (team) | Kibana (auditors only) |
| ArgoCD UI | Local | Team | Platform team only |
```

## Quality Checks
- [ ] All three environments documented (dev, staging, production)
- [ ] Infrastructure sizing specified per environment
- [ ] Secrets referenced by Vault path (not values)
- [ ] Feature flags table specifies per-environment state
- [ ] Access controls specified per environment
- [ ] Production always has HA, PDB, HPA, deletion protection
