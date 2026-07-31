# Argo Rollouts Canary Reference

**Companion to `canary-deployment` SKILL.md**

This document is self-contained: all YAML and explanations here can be read without the parent SKILL.md in context. It covers the concrete `Rollout` CRD + `AnalysisTemplate` CRD implementation of a GitOps-native canary rollout on this platform.

---

## Why Rollout CRD Instead of Deployment

A plain Kubernetes `Deployment` with `RollingUpdate` strategy does not understand "shift 5% of traffic to a new version, hold, gate, then advance." It updates all replicas gradually without traffic-weighted gates. Separating canary traffic from rollout progress requires either an external pipeline managing weights manually (a CI step — bypassable, not GitOps-native) or a controller that understands progressive delivery.

Argo Rollouts' `Rollout` CRD is a drop-in replacement for `Deployment` that adds:
- Explicit canary `steps` (setWeight + pause + analyses)
- `AnalysisTemplate` attachment per step — gate criteria live in Git
- Integration with Linkerd `HTTPRoute` weight patching
- Automatic revert to 0% on `AnalysisRun` failure

The `Rollout` spec looks identical to a `Deployment` spec except for the `strategy` block. Existing Helm templates, `Service` resources, `HPA`, `PDB`, and `NetworkPolicy` resources need no change — only the `Deployment` manifest is replaced.

**Decision rule** (from `kubernetes-workload-patterns`): use `Rollout` for any service that receives canary or blue-green traffic strategies. Use `Deployment` for stateless services with standard RollingUpdate. Never use `Deployment` + manual traffic scripts for a service that has an Argo Rollouts strategy defined — the two conflict.

---

## AnalysisTemplate CRD

An `AnalysisTemplate` defines a Prometheus query, the interval to run it, and the pass/fail criteria. One template per gate type, reused across services:

```yaml
# gitops/analysis-templates/slo-fast-burn-gate.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: slo-fast-burn-gate
  namespace: estate-scanner  # one per namespace; or ClusterAnalysisTemplate for cross-namespace reuse
spec:
  args:
    - name: service
    - name: error-budget-fraction   # e.g. 0.005 for 99.5% SLO
  metrics:
    - name: fast-burn-rate
      interval: 2m
      count: 5           # run 5 times during the step's hold period
      failureLimit: 1    # first failure triggers rollback — no grace
      successCondition: result[0] <= (14.4 * {{args.error-budget-fraction}})
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          query: |
            service:http_request_errors:ratio_rate5m{
              service="{{args.service}}",
              slot="canary"
            }
```

```yaml
# gitops/analysis-templates/latency-regression-gate.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: latency-regression-gate
  namespace: estate-scanner
spec:
  args:
    - name: service
  metrics:
    - name: p99-ratio
      interval: 5m
      count: 3
      failureLimit: 1
      successCondition: result[0] <= 1.2
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          query: |
            (
              histogram_quantile(0.99,
                sum by (le) (rate(http_request_duration_seconds_bucket{
                  service="{{args.service}}", slot="canary"}[10m]))
              )
              /
              histogram_quantile(0.99,
                sum by (le) (rate(http_request_duration_seconds_bucket{
                  service="{{args.service}}", slot="stable"}[10m]))
              )
            )
```

```yaml
# gitops/analysis-templates/error-rate-baseline-gate.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: error-rate-baseline-gate
  namespace: estate-scanner
spec:
  args:
    - name: service
  metrics:
    - name: error-ratio-vs-stable
      interval: 5m
      count: 3
      failureLimit: 1
      successCondition: result[0] <= 1.5
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          query: |
            (
              sum(rate(http_requests_total{service="{{args.service}}", slot="canary", status=~"5.."}[5m]))
              /
              sum(rate(http_requests_total{service="{{args.service}}", slot="canary"}[5m]))
            )
            /
            (
              sum(rate(http_requests_total{service="{{args.service}}", slot="stable", status=~"5.."}[5m]))
              /
              sum(rate(http_requests_total{service="{{args.service}}", slot="stable"}[5m]))
            )
```

**`ClusterAnalysisTemplate` vs `AnalysisTemplate`**: if gate logic is identical across tenant namespaces (same SLO fraction, same Prometheus address), use `ClusterAnalysisTemplate` — one resource at cluster scope, referenced by `Rollout` resources in any namespace. Per-tenant SLO differences warrant per-namespace `AnalysisTemplate` resources with namespace-specific `error-budget-fraction` arg values.

---

## Rollout CRD — Full Canary Spec

```yaml
# charts/estate-scanner/templates/rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: estate-scanner
  namespace: tenant-canary
spec:
  replicas: 3
  selector:
    matchLabels:
      app: estate-scanner
  template:
    metadata:
      labels:
        app: estate-scanner
    spec:
      containers:
        - name: estate-scanner
          image: ghcr.io/org/estate-scanner:{{ .Values.image.tag }}
          ports:
            - containerPort: 8080
          resources:
            requests: { cpu: "250m", memory: "256Mi" }
            limits:   { cpu: "500m", memory: "512Mi" }
          readinessProbe:
            httpGet: { path: /healthz/ready, port: 8080 }
            initialDelaySeconds: 5
            periodSeconds: 5
  strategy:
    canary:
      # Linkerd integration — Argo Rollouts patches HTTPRoute weights at each step
      trafficRouting:
        linkerd:
          stableService: estate-scanner-stable
          canaryService: estate-scanner-canary
      # Canary steps: the 5→25→50→100 progression from the SKILL.md stage table
      steps:
        # Stage 1: 5% canary, 15 min hold with fast-burn gate
        - setWeight: 5
        - analysis:
            templates:
              - templateName: slo-fast-burn-gate
              - templateName: error-rate-baseline-gate
              - templateName: latency-regression-gate
            args:
              - name: service
                value: estate-scanner
              - name: error-budget-fraction
                value: "0.005"   # 99.5% SLO → 0.5% error budget
        - pause: { duration: 15m }
        # Stage 2: 25% canary, 30 min hold
        - setWeight: 25
        - analysis:
            templates:
              - templateName: slo-fast-burn-gate
              - templateName: error-rate-baseline-gate
              - templateName: latency-regression-gate
            args:
              - name: service
                value: estate-scanner
              - name: error-budget-fraction
                value: "0.005"
        - pause: { duration: 30m }
        # Stage 3: 50% canary, 30 min hold
        - setWeight: 50
        - analysis:
            templates:
              - templateName: slo-fast-burn-gate
              - templateName: error-rate-baseline-gate
              - templateName: latency-regression-gate
            args:
              - name: service
                value: estate-scanner
              - name: error-budget-fraction
                value: "0.005"
        - pause: { duration: 30m }
        # Stage 4: terminal — no analysis needed; prior stages gave sufficient signal
        - setWeight: 100
      # Retain the previous stable ReplicaSet for instant rollback via weight revert
      stableMetadata:
        labels:
          slot: stable
      canaryMetadata:
        labels:
          slot: canary
```

**Key fields explained**:
- `trafficRouting.linkerd`: tells Argo Rollouts to patch the `HTTPRoute` resources (identified by `stableService` and `canaryService`) rather than adjusting replica counts. The `estate-scanner-stable` and `estate-scanner-canary` `Service` resources must both exist and point to the same `Rollout`'s pods (differentiated by the `slot` label injected by `stableMetadata`/`canaryMetadata`).
- `analysis` step before `pause`: the `AnalysisRun` starts when the `setWeight` step completes and runs for the full `pause` duration. If the `AnalysisRun` fails before the pause expires, the `Rollout` immediately reverts to 0% — the pause does not block rollback.
- `stableMetadata` / `canaryMetadata`: Argo Rollouts injects these labels into pods automatically, which is what makes the `slot="canary"` and `slot="stable"` labels in the gate Prometheus queries work without manual pod-label management.

---

## AnalysisRun Lifecycle and Rollback Mechanics

An `AnalysisRun` is a namespaced resource created by Argo Rollouts at each `analysis` step. Its lifecycle:

```
Pending → Running → Successful (→ next step)
                 → Failed    (→ Rollout aborted, weight → 0%)
                 → Inconclusive (→ treated as failed if failureLimit exhausted)
                 → Error     (→ Prometheus unreachable; treated as failure if failureLimit exhausted)
```

**Observing a running analysis**:
```bash
kubectl get analysisrun -n tenant-canary
kubectl describe analysisrun estate-scanner-abc123-slo-fast-burn-gate -n tenant-canary
```

**Triggering manual rollback** (when not automated or in manual-via-PR mode):
```bash
kubectl argo rollouts abort estate-scanner -n tenant-canary
# Argo Rollouts sets weight → 0%, stable ReplicaSet retains all traffic
# The Rollout enters Degraded state; a new release attempt requires a new image update
```

**Promoting past a gate** (operator override — must be recorded as an incident):
```bash
kubectl argo rollouts promote estate-scanner -n tenant-canary --full
# Skips all remaining steps and analyses — use only for emergency unblocking, not routine
```

**Auto-rollback event flow**:
1. `AnalysisRun` metric evaluation: Prometheus returns `> 14.4 × 0.005 = 0.072` error rate for the canary slot.
2. `AnalysisRun` phase transitions to `Failed`.
3. Argo Rollouts controller sees the `Failed` `AnalysisRun` for the active step.
4. Rollout phase transitions to `Degraded`; Argo Rollouts patches the `HTTPRoute` to `weight: 0` for canary, `weight: 100` for stable.
5. Event is recorded in the `Rollout` status; visible via `kubectl argo rollouts get rollout estate-scanner -n tenant-canary`.
6. A `RolloutAborted` Kubernetes event is emitted — this is the `alerting-rules-design` hook point for a Slack/PagerDuty notification.

---

## Linkerd HTTPRoute Integration — What Argo Rollouts Manages

When `trafficRouting.linkerd` is configured, Argo Rollouts creates and manages the `HTTPRoute` resource automatically — the platform-engineer does **not** manage the `HTTPRoute` weights manually or via PRs while a `Rollout` is active. The `estate-scanner-stable` and `estate-scanner-canary` `Service` resources must be pre-declared (they reference the same `Rollout`'s pods via the `slot` label):

```yaml
# charts/estate-scanner/templates/services.yaml
---
apiVersion: v1
kind: Service
metadata:
  name: estate-scanner-stable
  namespace: tenant-canary
spec:
  selector:
    app: estate-scanner
    # Argo Rollouts injects slot: stable into the stable ReplicaSet's pods
  ports: [{ port: 8080, targetPort: 8080 }]
---
apiVersion: v1
kind: Service
metadata:
  name: estate-scanner-canary
  namespace: tenant-canary
spec:
  selector:
    app: estate-scanner
    # Argo Rollouts injects slot: canary into the canary ReplicaSet's pods
  ports: [{ port: 8080, targetPort: 8080 }]
```

The Argo Rollouts controller owns the `HTTPRoute` for the duration of the rollout. On completion (100% or abort to 0%), the `HTTPRoute` is left at the terminal state and the `canary` `Service` receives 0% (or the stable `Service` receives 100%).

---

## Worked Example — estate-scanner Document Fingerprinting Release

Rolling out a change to `estate-scanner`'s document-fingerprinting logic (affects the `DocumentDiscovered` event payload's `content_hash` field — additive change, no schema exception applies):

**Pre-flight checks** (before updating the image tag in the `Rollout`):
1. `content_hash` field is already present in the schema (expand/contract satisfied — additive only).
2. `slo-definition` for estate-scanner confirms the SLO is 99.5% availability → error budget fraction = 0.005.
3. `AnalysisTemplate` resources (`slo-fast-burn-gate`, `error-rate-baseline-gate`, `latency-regression-gate`) are already deployed in `tenant-canary` namespace.
4. Prometheus recording rule `service:http_request_errors:ratio_rate5m{slot="canary"}` is active (verified via `prometheus-metrics-design`'s recording rule file).

**Release**: update `image.tag` in the `Rollout`'s Helm values. Argo CD detects the Git change and syncs the `Rollout` resource. Argo Rollouts controller starts the canary step sequence.

**Gate rule for the content_hash-specific signal** (in addition to the generic templates above):
```yaml
# gitops/analysis-templates/content-hash-consistency-gate.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: content-hash-consistency-gate
  namespace: tenant-canary
spec:
  metrics:
    - name: hash-mismatch
      interval: 5m
      count: 3
      failureLimit: 0   # zero tolerance — any mismatch is a hard stop
      successCondition: result[0] == 0
      provider:
        prometheus:
          address: http://prometheus.monitoring.svc.cluster.local:9090
          query: |
            increase(estate_scanner_content_hash_mismatch_total{slot="canary"}[15m])
```

Add `content-hash-consistency-gate` to the `analysis` step in the `Rollout` spec for this release (or add it to all stages by default once the metric is validated):
```yaml
        - analysis:
            templates:
              - templateName: slo-fast-burn-gate
              - templateName: error-rate-baseline-gate
              - templateName: latency-regression-gate
              - templateName: content-hash-consistency-gate  # release-specific gate
```

**Promotion sequence**:
- Stage 1 (5%, 15 min hold): all four `AnalysisRun` instances complete `Successful` → Argo Rollouts advances to stage 2.
- Stage 2 (25%, 30 min hold): all `AnalysisRun` instances complete `Successful` → advances to stage 3.
- Stage 3 (50%, 30 min hold): all `AnalysisRun` instances complete `Successful` → advances to stage 4.
- Stage 4 (100%): terminal. Argo Rollouts sets the canary `ReplicaSet` as the new stable, scales down the old stable `ReplicaSet`. The `Rollout` phase becomes `Healthy`.

**Fleet wave gate**: `cd-pipeline`'s fleet-wave PR to `tenant-acme` and `tenant-globex` is opened only after the `tenant-canary` `Rollout` status reads `Healthy` at 100% and has baked for the configured stabilization window. Each fleet tenant's own `Rollout` runs the same four-stage sequence against that tenant's traffic.

---

## Prometheus Recording Rules Required

The gate queries above depend on recording rules that must already be deployed by `prometheus-metrics-design` and `alerting-rules-design`:

```yaml
# prometheus/rules/canary-recording-rules.yaml
groups:
  - name: canary-slot-recording
    rules:
      - record: service:http_request_errors:ratio_rate5m
        expr: |
          sum by (service, slot) (rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum by (service, slot) (rate(http_requests_total[5m]))
        labels: {}
```

The `slot` label is injected by Argo Rollouts via `stableMetadata`/`canaryMetadata` into pod labels, which propagate to Prometheus via the standard pod scrape. Verify the label is present on canary pods before starting a rollout:
```bash
kubectl get pods -n tenant-canary -l app=estate-scanner --show-labels | grep slot
```

---

## Multi-Tenant Considerations

| Consideration | Recommendation |
|---|---|
| `ClusterAnalysisTemplate` scope | Use for SLO-agnostic gate templates (latency ratio, error ratio) shared across all tenant namespaces. Use per-namespace `AnalysisTemplate` for SLO-specific gates where the budget fraction differs. |
| Per-tenant SLO fractions | Pass `error-budget-fraction` as an arg on each `Rollout`'s `analysis` step — the `ClusterAnalysisTemplate` body is generic; the fraction is tenant-specific configuration. |
| Rollout ordering | `tenant-canary` completes and stabilizes → fleet-wave PR opens → each fleet tenant's `Rollout` runs independently. Do not start a fleet tenant's rollout until the preceding tenant's `Rollout` is `Healthy` at 100% — parallel promotions across tenants reduce the blast radius benefit of per-tenant physical isolation. |
| Argo CD sync ordering | Use Argo CD `Application` sync waves (`argocd.argoproj.io/sync-wave` annotation) to enforce the canary tenant → fleet tenant ordering within the App-of-Apps pattern. |
