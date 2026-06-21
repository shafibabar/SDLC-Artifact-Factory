# Skill: deploy/canary-deployment-plan

## Purpose
Produce the Canary Deployment Plan — the specification of how new service versions are rolled out to a small percentage of live traffic first, with automatic promotion or rollback based on observable metrics. Every production release uses canary unless an emergency fix requires direct deployment.

## Inputs
- `artifacts/design/platform/observability-design.md` (SLOs — thresholds for rollback)
- `artifacts/design/platform/deployment-architecture.md`
- `artifacts/quality/performance-test-plan.md` (baseline metrics)

## Output
**File:** `artifacts/deploy/canary-plan.md`
**Registers in manifest:** yes

## Canary Rules (enforced)
- Canary deployment is the default for all production releases.
- Canary traffic starts at 5% maximum.
- Automatic promotion criteria are metric-based — not time-based alone.
- Automatic rollback triggers fire within 5 minutes of SLO breach.
- Canary weight is managed by the service mesh (Linkerd) — not by load balancer config.

## Artifact Template

```markdown
# Canary Deployment Plan
**Product:** {product_name}
**Phase:** Deploy
**Artifact:** Canary Deployment Plan
**Tool:** Linkerd (traffic split) + ArgoCD Rollouts
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Canary Strategy

### Traffic Split Configuration

```yaml
# Managed by ArgoCD Rollouts (rollout.yaml in Helm chart)
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: {service-name}
spec:
  strategy:
    canary:
      steps:
        - setWeight: 5      # 5% canary traffic for 10 minutes
        - pause: {duration: 10m}
        - setWeight: 25     # 25% if metrics clean
        - pause: {duration: 10m}
        - setWeight: 50     # 50% if metrics clean
        - pause: {duration: 10m}
        - setWeight: 100    # Full rollout
      analysis:
        templates:
          - templateName: {service-name}-canary-analysis
        startingStep: 1
        args:
          - name: service-name
            value: {service-name}
```

---

## Automatic Rollback Triggers

If any metric breaches threshold during any canary step, ArgoCD Rollouts automatically rolls back to the stable version:

| Metric | Threshold | Window | Action |
|--------|-----------|--------|--------|
| HTTP error rate (5xx) | > 1% | 5 minutes | ROLLBACK |
| p(99) latency | > {SLO from observability-design.md + 20%} | 5 minutes | ROLLBACK |
| Consumer lag | > 1000 messages (above baseline) | 5 minutes | ROLLBACK |
| Crash restarts | > 0 (any pod crash) | 1 minute | ROLLBACK |

---

## Analysis Template

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: {service-name}-canary-analysis
spec:
  args:
    - name: service-name
  metrics:
    - name: error-rate
      interval: 1m
      failureLimit: 1
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{service="{{args.service-name}}",status=~"5.."}[5m]))
            /
            sum(rate(http_requests_total{service="{{args.service-name}}"}[5m]))
      successCondition: result[0] < 0.01  # < 1% error rate
    - name: p99-latency
      interval: 1m
      failureLimit: 1
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            histogram_quantile(0.99, 
              sum(rate(http_request_duration_seconds_bucket{service="{{args.service-name}}"}[5m]))
              by (le))
      successCondition: result[0] < 0.5  # < 500ms p99
```

---

## Manual Promotion / Rollback

```bash
# Promote to next step manually
kubectl argo rollouts promote {service-name} -n {namespace}

# Abort and rollback
kubectl argo rollouts abort {service-name} -n {namespace}

# Check status
kubectl argo rollouts get rollout {service-name} -n {namespace} --watch
```

---

## Post-Deployment Validation

After 100% traffic reaches new version:
1. Run smoke tests: `make smoke-test-production`
2. Verify Grafana dashboards show no SLO breaches
3. Check DLQ: no messages from the release window
4. Notify stakeholders: post in #deployments Slack channel

---

## Emergency Direct Deploy

If a critical security fix must bypass canary (e.g. active exploit):
1. Requires 2-person approval (tech lead + PM)
2. Deploy directly to 100% (skip canary steps)
3. Monitor for 30 minutes actively
4. Document justification in release notes
5. Run full E2E suite within 2 hours of deploy
```

## Quality Checks
- [ ] Initial canary weight is ≤ 10%
- [ ] Rollback triggers are metric-based with specific thresholds
- [ ] Analysis template queries Prometheus (not time-based only)
- [ ] Manual promote/rollback commands are documented
- [ ] Emergency bypass procedure is defined and requires 2-person approval
- [ ] Post-deployment validation steps are specified
