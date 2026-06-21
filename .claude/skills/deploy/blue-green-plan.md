# Skill: deploy/blue-green-plan

## Purpose
Produce the Blue-Green Deployment Plan — the specification for zero-downtime deployments using two identical environments with atomic traffic switching. Used when canary is insufficient (e.g. stateful migrations, breaking API changes, major infrastructure updates).

## Inputs
- `artifacts/deploy/canary-plan.md`
- `artifacts/design/platform/deployment-architecture.md`
- `artifacts/quality/test-plan.md` (smoke test suite)

## Output
**File:** `artifacts/deploy/blue-green-plan.md`
**Registers in manifest:** yes

## Blue-Green Rules (enforced)
- Blue = current production (live traffic). Green = new version (not serving traffic yet).
- Traffic switch is atomic — no gradual shift (that is canary's job).
- Green is fully validated before traffic switch: smoke tests, integration tests, readiness probes.
- Database migrations run before the traffic switch — they must be backward compatible with both blue and green.
- Rollback = switch traffic back to blue — blue is kept warm for 30 minutes post-switch.

## Artifact Template

```markdown
# Blue-Green Deployment Plan
**Product:** {product_name}
**Phase:** Deploy
**Artifact:** Blue-Green Deployment Plan
**Tool:** Kubernetes Service selector update (via ArgoCD)
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## When to Use Blue-Green (not Canary)

| Scenario | Use blue-green because |
|---------|----------------------|
| Database schema migration (additive) | Green must be stable before any traffic reaches it; blue handles rollback if migration fails |
| Breaking API version change (v1 → v2) | Cannot serve mixed versions simultaneously |
| Major Kubernetes version upgrade | Validate full cluster before switching |
| Emergency critical patch | Need instant rollback capability |

---

## Blue-Green Steps

### 1. Pre-deployment
```
✓ Current state: Blue = serving 100% traffic
✓ Prerequisite: Blue is healthy (all SLOs met for 30 minutes)
✓ Prerequisite: Database migration (if any) passes backward compatibility test
```

### 2. Database Migration (if required)
```
Run migration on the shared database:
  kubectl run db-migration --image={image}:{sha} --rm -it -- migrate up
  
Migration must be backward compatible with the blue version.
If migration cannot be backward compatible → major version release required.

Rollback: Run `migrate down` (migration must be reversible — enforced in coding standards).
```

### 3. Deploy Green Environment
```
Apply green Helm release (separate deployment name: {service-name}-green):
  helm upgrade --install {service-name}-green ./helm/{service-name} \
    --namespace {namespace} \
    --values helm/{service-name}/values-production.yaml \
    --set image.tag={new-sha} \
    --set nameOverride={service-name}-green

Wait for green pods to be ready:
  kubectl rollout status deployment/{service-name}-green -n {namespace} --timeout=120s
```

### 4. Validate Green
```
Smoke tests against green (not receiving live traffic yet):
  # Point test client at green service directly
  SMOKE_TARGET=http://{service-name}-green:8080 make smoke-test

Integration tests against green:
  go test -tags=integration ./... -service-url=http://{service-name}-green:8080

Security check: readiness probe healthy
Security check: no NEW secrets in green deployment (green must not have different secret references)
```

### 5. Traffic Switch (atomic)
```
Update Kubernetes Service selector from blue to green:
  kubectl patch service {service-name} \
    --patch '{"spec":{"selector":{"version":"green"}}}'
    
This is atomic — no traffic in-flight at the moment of switch.
Monitor for 5 minutes before considering rollout complete.
```

### 6. Post-Switch Monitoring
```
Watch for 30 minutes:
  - Error rate < 0.1% (Grafana alert: {service-name} canary panel)
  - p(99) latency within SLO
  - Consumer lag baseline unchanged

Blue pods kept alive for 30 minutes (instant rollback available):
  kubectl scale deployment/{service-name}-blue --replicas=2
```

### 7. Teardown Blue
```
After 30-minute monitoring window with no incidents:
  helm uninstall {service-name}-blue -n {namespace}
  kubectl patch service {service-name} --patch '{"spec":{"selector":{"version":"green"}}}'
  # Green becomes the new "blue" for the next release
```

---

## Rollback (within 30-minute window)

```bash
# Atomic traffic switch back to blue
kubectl patch service {service-name} \
  --patch '{"spec":{"selector":{"version":"blue"}}}'

# Verify
kubectl get endpoints {service-name} -n {namespace}

# Database rollback (if migration was run)
kubectl run db-rollback --image={image}:{current-sha} --rm -it -- migrate down 1
```

---

## Blue-Green for Database Migrations (Advanced)

When a breaking schema change is unavoidable:
1. Phase 1: Expand — add new columns/tables; code handles both old and new schema (deploy as canary first)
2. Phase 2: Migrate — back-fill data; update application to use new schema only
3. Phase 3: Contract — remove old columns/tables (after all consumers updated)
```

## Quality Checks
- [ ] Clear criteria for when to use blue-green vs canary
- [ ] Database migration runs before traffic switch (backward compatibility required)
- [ ] Green is validated with smoke tests before traffic switch
- [ ] Traffic switch is a single atomic kubectl patch
- [ ] Blue is kept warm for 30 minutes post-switch
- [ ] Rollback is defined (< 60 seconds to execute)
- [ ] Expand-migrate-contract pattern for breaking schema changes
