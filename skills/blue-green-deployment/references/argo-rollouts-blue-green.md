# Argo Rollouts — Blue-Green Strategy Reference

This reference covers complete YAML for blue-green delivery using Argo Rollouts, the full
two-Deployment + Service manifest pair used by the manual selector-flip approach, the
AnalysisTemplate Prometheus configuration, per-tenant GitOps environment-repo patterns,
and the worked cutover sequence for `compliance-engine`. Load this file when the skill
body directs you to it — it extends, not replaces, the decision-shaping guidance in
`SKILL.md`.

---

## 1. Manual Approach — Two Deployments + One Service

The foundational pattern requires no custom CRDs. The full chart template creates both
Deployments in advance and controls which receives traffic via the Service selector alone.

```yaml
# charts/compliance-engine/templates/blue-green-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: compliance-engine-blue
  namespace: "{{ .Values.namespace }}"
  labels:
    app: compliance-engine
    slot: blue
    version: "{{ .Values.blue.image.tag }}"
spec:
  replicas: "{{ .Values.replicas }}"
  selector:
    matchLabels:
      app: compliance-engine
      slot: blue
  template:
    metadata:
      labels:
        app: compliance-engine
        slot: blue
        version: "{{ .Values.blue.image.tag }}"
    spec:
      serviceAccountName: compliance-engine
      containers:
        - name: compliance-engine
          image: "ghcr.io/acme/data-estate/compliance-engine@{{ .Values.blue.image.digest }}"
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet: { path: /readyz, port: http }
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet: { path: /healthz, port: http }
            initialDelaySeconds: 15
            periodSeconds: 20
          env:
            - name: CONSUMER_PAUSED
              value: "{{ .Values.blue.consumerPaused }}"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: compliance-engine-green
  namespace: "{{ .Values.namespace }}"
  labels:
    app: compliance-engine
    slot: green
    version: "{{ .Values.green.image.tag }}"
spec:
  replicas: "{{ .Values.replicas }}"
  selector:
    matchLabels:
      app: compliance-engine
      slot: green
  template:
    metadata:
      labels:
        app: compliance-engine
        slot: green
        version: "{{ .Values.green.image.tag }}"
    spec:
      serviceAccountName: compliance-engine
      containers:
        - name: compliance-engine
          image: "ghcr.io/acme/data-estate/compliance-engine@{{ .Values.green.image.digest }}"
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet: { path: /readyz, port: http }
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet: { path: /healthz, port: http }
            initialDelaySeconds: 15
            periodSeconds: 20
          env:
            - name: CONSUMER_PAUSED
              value: "{{ .Values.green.consumerPaused }}"
---
apiVersion: v1
kind: Service
metadata:
  name: compliance-engine
  namespace: "{{ .Values.namespace }}"
spec:
  selector:
    app: compliance-engine
    slot: "{{ .Values.activeSlot }}"   # THE cutover: change this value in the env repo
  ports:
    - name: http
      port: 8080
      targetPort: http
```

**Corresponding `values.yaml` structure:**

```yaml
namespace: tenant-acme
replicas: 3
activeSlot: blue   # change to "green" in the cutover PR

blue:
  image:
    tag: "v1.4.2"
    digest: "sha256:aaa1bbb2ccc3..."
  consumerPaused: "false"   # currently live; pause at cutover

green:
  image:
    tag: "v1.5.0"
    digest: "sha256:ddd4eee5fff6..."
  consumerPaused: "true"    # paused until cutover
```

The cutover PR changes exactly two values: `activeSlot: blue → green`, plus the consumer
pause flags for both slots.

---

## 2. Per-Tenant GitOps Environment-Repo Diff

Under the per-tenant fleet model, each tenant's desired state is a separate directory in
the environment repository. The cutover PR is scoped to one tenant at a time:

```diff
# deploy/clusters/tenants/tenant-acme/compliance-engine-values.yaml
 activeSlot: blue
+activeSlot: green

 blue:
   consumerPaused: "false"
+  consumerPaused: "true"

 green:
   consumerPaused: "true"
+  consumerPaused: "false"
```

That three-line diff is the entire production cutover for `tenant-acme`. It is reviewable
without any tooling, revertible by a second PR (`git revert`), and auditable in `git log`
as a first-class production change — satisfying `cd-pipeline`'s GitOps audit requirement.

**Multi-tenant rollout strategy:** cut over one tenant at a time rather than updating all
tenant directories in a single commit. The environment repo's directory-per-tenant
structure makes staged rollouts across the fleet a Git operation — start with a
non-production tenant, observe for the bake period, then open individual PRs for each
subsequent tenant. This gives blue-green's instant rollback guarantee at the tenant level,
not just the service level.

---

## 3. Argo Rollouts — Rollout CRD with blueGreen Strategy

The `Rollout` CRD replaces `Deployment` for services where the promotion decision should
be automated by metric analysis rather than a manual PR review. It requires Argo Rollouts
installed in the cluster.

```yaml
# charts/compliance-engine/templates/rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: compliance-engine
  namespace: "{{ .Values.namespace }}"
spec:
  replicas: "{{ .Values.replicas }}"
  selector:
    matchLabels:
      app: compliance-engine
  template:
    metadata:
      labels:
        app: compliance-engine
    spec:
      serviceAccountName: compliance-engine
      containers:
        - name: compliance-engine
          image: "ghcr.io/acme/data-estate/compliance-engine:{{ .Values.image.tag }}"
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet: { path: /readyz, port: http }
            initialDelaySeconds: 5
            periodSeconds: 10
  strategy:
    blueGreen:
      # activeService: the stable Service; Argo Rollouts flips its selector at promotion
      activeService: compliance-engine-active
      # previewService: candidate receives no production traffic until promotion
      previewService: compliance-engine-preview
      # autoPromotionEnabled: false requires manual promotion approval (kubectl argo rollouts promote)
      # Set true only if prePromotionAnalysis alone is the gate
      autoPromotionEnabled: false
      prePromotionAnalysis:
        templates:
          - templateName: success-rate-check
        args:
          - name: service-name
            value: compliance-engine-preview
          - name: window
            value: "5m"
          - name: threshold
            value: "0.995"
      postPromotionAnalysis:
        templates:
          - templateName: success-rate-check
        args:
          - name: service-name
            value: compliance-engine-active
          - name: window
            value: "10m"
          - name: threshold
            value: "0.995"
      # scaleDownDelaySeconds: how long to keep the old (blue) ReplicaSet alive after promotion
      # This is the automated equivalent of the manual bake window's scale-down step
      scaleDownDelaySeconds: 86400   # 24 hours; adjust per release risk
```

**The two companion Services (`activeService` and `previewService`):**

```yaml
# charts/compliance-engine/templates/services.yaml
apiVersion: v1
kind: Service
metadata:
  name: compliance-engine-active
  namespace: "{{ .Values.namespace }}"
spec:
  selector:
    app: compliance-engine
  ports:
    - name: http
      port: 8080
      targetPort: http
---
apiVersion: v1
kind: Service
metadata:
  name: compliance-engine-preview
  namespace: "{{ .Values.namespace }}"
spec:
  selector:
    app: compliance-engine
  ports:
    - name: http
      port: 8080
      targetPort: http
```

Argo Rollouts manages the `selector` on both Services automatically — the platform
engineer does not edit these Services directly. The active Service's selector always points
at the current stable ReplicaSet; the preview Service's selector points at the candidate.

---

## 4. AnalysisTemplate — Prometheus Success Rate Gate

The same `AnalysisTemplate` serves both `prePromotionAnalysis` and `postPromotionAnalysis`.
It queries Prometheus for the HTTP success rate of the target service over the specified
window, using the same request-success expressions that `alerting-rules-design` defines
for SLO burn-rate alerts.

```yaml
# charts/compliance-engine/templates/analysis-template.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate-check
  namespace: "{{ .Values.namespace }}"
spec:
  args:
    - name: service-name
    - name: window
      default: "5m"
    - name: threshold
      default: "0.995"
  metrics:
    - name: success-rate
      interval: 1m
      count: 5          # run 5 measurements; all must pass
      successCondition: result[0] >= float64(args.threshold)
      failureLimit: 1   # one failed measurement aborts the analysis
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          query: |
            sum(
              rate(
                http_server_requests_total{
                  service="{{ args.service-name }}",
                  status!~"5.."
                }[{{ args.window }}]
              )
            )
            /
            sum(
              rate(
                http_server_requests_total{
                  service="{{ args.service-name }}"
                }[{{ args.window }}]
              )
            )
    - name: p99-latency
      interval: 1m
      count: 5
      successCondition: result[0] <= 0.5     # 500ms p99 threshold
      failureLimit: 1
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          query: |
            histogram_quantile(
              0.99,
              sum(
                rate(
                  http_server_request_duration_seconds_bucket{
                    service="{{ args.service-name }}"
                  }[{{ args.window }}]
                )
              ) by (le)
            )
```

**Pass/fail semantics:**

| Outcome | prePromotionAnalysis | postPromotionAnalysis |
|---|---|---|
| All metrics pass all `count` measurements | Promotion proceeds (or awaits manual approval if `autoPromotionEnabled: false`) | Stable; old ReplicaSet scales down after `scaleDownDelaySeconds` |
| Any metric exceeds `failureLimit` | Rollout aborted; active Service unchanged; candidate ReplicaSet scaled to zero | Automatic rollback; Argo Rollouts flips `activeService` selector back to the old ReplicaSet |

**Relationship to `alerting-rules-design`:** The Prometheus queries above mirror the
request-success burn-rate expressions that `alerting-rules-design` defines for page-level
SLO alerts. Using the same metric names and label selectors ensures that a service that
would page on-call under steady-state operation will also fail its `AnalysisTemplate` gate
during a blue-green promotion — the promotion gate and the production alert are calibrated
to the same SLO budget.

---

## 5. Worked Cutover Sequence — compliance-engine (Manual Selector Approach)

This example cuts over `compliance-engine` to a release that expands the
`classification_findings` table with a new `evidence_ref` column (SIEM-export capability)
and changes the `ClassifyDataAsset` command handler.

**Step 1 — Expand migration (ships independently, before green is created)**

```sql
-- migration: 20260801_001_expand_evidence_ref.sql
ALTER TABLE classification_findings
  ADD COLUMN evidence_ref TEXT NULL;

-- No data backfill yet; blue (old code) ignores this column entirely.
-- Green (new code) writes it. Both can coexist on this schema.
```

**Step 2 — Create green Deployment (PR: "deploy: compliance-engine green v1.5.0")**

```yaml
# deploy/clusters/tenants/tenant-acme/compliance-engine-values.yaml
green:
  image:
    tag: "v1.5.0"
    digest: "sha256:ddd4eee5fff6..."
  consumerPaused: "true"   # consumer paused — green is running but not consuming
```

**Step 3 — Verification gate (run before opening the cutover PR)**

```bash
# 1. Health — /readyz sustained green for 10 minutes
kubectl rollout status deployment/compliance-engine-green -n tenant-acme
watch -n 10 kubectl get pods -n tenant-acme -l slot=green

# 2. Smoke — hit green's debug Service directly (never the live selector)
kubectl port-forward svc/compliance-engine-debug 18080:8080 -n tenant-acme &
curl -X PATCH http://localhost:18080/v1/data-assets/fixture-001/classification \
     -H "X-Tenant: acme-fixture" \
     -d '{"classification":"PII","confidence":0.97}' | jq '.evidence_ref'
# Expected: non-null string

# 3. Linkerd identity
linkerd viz stat deploy/compliance-engine-green -n tenant-acme

# 4. Schema compatibility — both blue and green pods are writing without error
kubectl logs -l slot=blue -n tenant-acme --tail=50 | grep -i "error\|panic"
kubectl logs -l slot=green -n tenant-acme --tail=50 | grep -i "error\|panic"
```

**Step 4 — Cutover PR (the entire production change is this diff)**

```diff
# deploy/clusters/tenants/tenant-acme/compliance-engine-values.yaml
-activeSlot: blue
+activeSlot: green

 blue:
-  consumerPaused: "false"
+  consumerPaused: "true"

 green:
-  consumerPaused: "true"
+  consumerPaused: "false"
```

The reconciler (Argo CD or Flux) applies all three changes within one reconciliation
interval — there is no window where both colours actively consume from the same
Redpanda partitions.

**Step 5 — Bake window (24 hours for this release tier)**

Monitor via `alerting-rules-design`'s burn-rate alerts:
- Fast-burn page (>14× error budget consumption in 1 hour) → immediate selector revert, no
  new deploy required.
- Slow-burn warning (>1× consumption in 6 hours) → evaluate before bake window closes.
- Correctness SLI (`evidence_ref` populated in >99.5% of `ClassifyDataAsset` commands
  processed by green) → checked at 4 hours and 24 hours.

**Step 6 — Contract migration (after bake window closes cleanly)**

Scale blue to zero; open a separately-reviewed migration PR. In this case `evidence_ref` is
purely additive so no contract step removes anything — but the pattern for a destructive
contract is:

```sql
-- migration: 20260803_001_contract_old_column.sql
-- Runs ONLY after blue is scaled to zero and green has been stable for the full bake period.
ALTER TABLE classification_findings DROP COLUMN old_field_name;
```

---

## 6. Argo Rollouts Cutover Sequence (Automated Gate Approach)

When using the `Rollout` CRD with `prePromotionAnalysis`, the promotion sequence is:

```
git push new image digest → Argo CD/Flux syncs Rollout →
  Argo Rollouts creates green ReplicaSet under previewService →
  prePromotionAnalysis AnalysisRun starts (5 measurements × 1min interval) →
    PASS: (if autoPromotionEnabled: false) await: kubectl argo rollouts promote compliance-engine -n tenant-acme
          (if autoPromotionEnabled: true)  active Service selector flips automatically
    FAIL: AnalysisRun marks Rollout as Degraded; green ReplicaSet scales to zero; no manual action needed →
  postPromotionAnalysis AnalysisRun starts →
    PASS: old ReplicaSet scales down after scaleDownDelaySeconds (24h)
    FAIL: Argo Rollouts reverts activeService selector to old ReplicaSet; Rollout marked Degraded
```

**Observing rollout status:**

```bash
kubectl argo rollouts get rollout compliance-engine -n tenant-acme --watch
# or via Argo Rollouts Dashboard (port-forward to the argo-rollouts-dashboard Service)
```

**Manual promotion (when `autoPromotionEnabled: false`):**

```bash
# Run only after reviewing prePromotionAnalysis results in the dashboard
kubectl argo rollouts promote compliance-engine -n tenant-acme
```

**Manual abort:**

```bash
# Aborts the rollout at any stage — equivalent to selector revert in the manual approach
kubectl argo rollouts abort compliance-engine -n tenant-acme
```

---

## 7. Choosing Manual vs Argo Rollouts for Blue-Green

| Factor | Manual Selector Flip | Argo Rollouts blueGreen |
|---|---|---|
| GitOps gate | Human PR review | Versioned AnalysisRun in cluster state |
| Promotion decision | Platform engineer + reviewer | Automated (metric-gated); optional manual approval step |
| Rollback trigger | Git revert PR | Automatic on postPromotionAnalysis failure |
| Dependency | None beyond Kubernetes | Argo Rollouts CRD installed in cluster |
| Audit trail | Git history (PR merge) | Git history + AnalysisRun objects in cluster |
| When to choose | Compliance-sensitive cutovers where human sign-off is required; services not yet on Argo Rollouts | Services already using progressive delivery machinery; rollout frequency warrants automated gating |

Both approaches satisfy `cd-pipeline`'s GitOps requirement — the difference is whether
the promotion gate is a human reviewing a diff or Prometheus metrics passing an
AnalysisTemplate. For this platform's per-tenant isolation model, neither approach requires
changes to other tenants' state.
