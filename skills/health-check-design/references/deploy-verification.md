# Deploy-then-Verify Reference

Post-deploy verification pattern for services whose health endpoints are defined by
`health-check-design`. This file is self-contained — it can be read without
`SKILL.md` in context.

**Pattern source:** *Cloud Native DevOps with Kubernetes* (Arundel & Domingus, Ch. 14).

---

## Why helm upgrade Alone Is Insufficient

`helm upgrade` exits 0 when the Kubernetes API server accepts the new spec and the
deployment controller begins rolling out. It does **not** wait for the new pods to
become healthy. This means:

- A container that crashes on startup (OOMKill, config error, missing env var) does
  not fail `helm upgrade` if the rollout strategy has not yet exceeded
  `maxUnavailable`.
- A readiness probe that fails for the new version still allows `helm upgrade` to
  complete if the rollout is not yet complete at the time the command exits.
- `--wait` (the Helm flag that waits for readiness) does wait, but it uses Helm's
  own timeout and does not run your application-level smoke test.

The Deploy-then-Verify pattern adds an explicit, scripted gate after every deploy.

---

## Pattern: Push-Model CI (GitHub Actions / helm upgrade)

### Script: scripts/post-deploy-verify.sh

Place in the repository root alongside other CI scripts, or inline in the pipeline
step.

```bash
#!/bin/bash
# post-deploy-verify.sh
# Usage: ./scripts/post-deploy-verify.sh <deployment-name> <service-url>
# Exit 0 = healthy; exit 1 = failed (caller must rollback).
set -euo pipefail

DEPLOYMENT="${1:?deployment name required}"
SERVICE_URL="${2:?service URL required}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-120s}"
READYZ_RETRIES="${READYZ_RETRIES:-5}"
READYZ_SLEEP="${READYZ_SLEEP:-3}"

echo "[post-deploy] waiting for rollout: $DEPLOYMENT"
kubectl rollout status "deployment/$DEPLOYMENT" --timeout="$ROLLOUT_TIMEOUT"

echo "[post-deploy] probing /readyz: $SERVICE_URL/healthz/ready"
for i in $(seq 1 "$READYZ_RETRIES"); do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL/healthz/ready")
    if [[ "$HTTP_CODE" == "200" ]]; then
        echo "[post-deploy] OK ($HTTP_CODE)"
        exit 0
    fi
    echo "[post-deploy] attempt $i/$READYZ_RETRIES: got $HTTP_CODE, retrying in ${READYZ_SLEEP}s"
    sleep "$READYZ_SLEEP"
done

echo "[post-deploy] FAILED after $READYZ_RETRIES attempts"
exit 1
```

### GitHub Actions Step

```yaml
# .github/workflows/deploy.yml

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Helm upgrade
        run: |
          helm upgrade --install ${{ env.SERVICE_NAME }} ./charts/${{ env.SERVICE_NAME }} \
            --namespace ${{ env.NAMESPACE }} \
            --set image.tag=${{ github.sha }} \
            --timeout 5m \
            --atomic        # rolls back automatically on failure; does NOT run /readyz

      - name: Post-deploy verification
        run: |
          ./scripts/post-deploy-verify.sh \
            "${{ env.SERVICE_NAME }}" \
            "http://${{ env.SERVICE_NAME }}.${{ env.NAMESPACE }}.svc.cluster.local"
        env:
          ROLLOUT_TIMEOUT: "120s"
          READYZ_RETRIES: "5"
          READYZ_SLEEP: "3"

      - name: Rollback on verification failure
        if: failure()
        run: |
          echo "[ci] post-deploy verification failed — rolling back"
          helm rollback ${{ env.SERVICE_NAME }} --namespace ${{ env.NAMESPACE }}
          exit 1
```

**Note on `--atomic`:** Helm's `--atomic` flag does roll back automatically, but it
uses Helm's internal readiness check (pod Ready condition), not your application's
`/readyz` endpoint. Use both: `--atomic` for Helm-level pod readiness, plus the
explicit `post-deploy-verify.sh` for application-level readiness.

---

## Pattern: Pull-Model GitOps (Flux)

With Flux, the platform agent reconciles a `HelmRelease` or a `Kustomization`. The
deploy-then-verify gate runs as a `health check` notification or as a post-reconcile
job.

### Option A: Flux Health Checks on HelmRelease

Flux natively waits for workload readiness when `spec.test.enable: true` is set on a
`HelmRelease`, or when health checks are configured:

```yaml
# clusters/production/services/my-service.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: my-service
  namespace: my-namespace
spec:
  interval: 5m
  chart:
    spec:
      chart: ./charts/my-service
      sourceRef:
        kind: GitRepository
        name: my-repo
  values:
    image:
      tag: "abc123"
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: my-service
      namespace: my-namespace
  timeout: 3m
  # On failure, Flux marks the HelmRelease as failed and retries on next interval.
  # Wire an alert to your on-call channel via Flux's Alert/Provider objects.
```

### Option B: Post-Reconcile Kubernetes Job

A `Job` triggered by a Flux `Receiver` webhook after reconciliation runs the same
verification script:

```yaml
# In the Flux post-reconcile pipeline, or as a CronJob polling for new revisions:
apiVersion: batch/v1
kind: Job
metadata:
  name: post-deploy-verify-my-service
  namespace: my-namespace
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: verify
          image: bitnami/kubectl:latest
          command:
            - /bin/sh
            - -c
            - |
              kubectl rollout status deployment/my-service --timeout=120s \
                && curl -f http://my-service.my-namespace.svc.cluster.local/healthz/ready
```

---

## Health Endpoint URL Conventions

| Environment | Internal URL (within cluster) | External URL (for CI runners outside the cluster) |
|---|---|---|
| kind-local | `http://my-service.default.svc.cluster.local` | `http://localhost:<NodePort>` (via `kubectl port-forward`) |
| staging | `http://my-service.staging.svc.cluster.local` | Via Ingress: `https://my-service.staging.example.com` |
| production | `http://my-service.production.svc.cluster.local` | Via Ingress: `https://my-service.example.com` |

For CI runners that run outside the cluster (GitHub-hosted runners), use
`kubectl port-forward svc/my-service 8080:80 &` in the pipeline step, then probe
`http://localhost:8080/healthz/ready`.

---

## Extending to SLO Burn Rate

Once SLO alerting is configured (Prometheus + recording rules), add a burn rate
check to the post-deploy gate:

```bash
# After the /readyz probe passes, check that the error rate for the new revision
# has not spiked above the 5m burn rate budget for the 1h SLO window.
BURN_RATE=$(curl -s "http://prometheus.monitoring.svc.cluster.local:9090/api/v1/query" \
  --data-urlencode 'query=job:request_error_rate5m:ratio{job="my-service"}' \
  | jq -r '.data.result[0].value[1]')

if (( $(echo "$BURN_RATE > 0.01" | bc -l) )); then
    echo "[post-deploy] error rate $BURN_RATE exceeds 1% threshold — rolling back"
    helm rollback my-service --namespace my-namespace
    exit 1
fi
```

This check requires the `job:request_error_rate5m:ratio` recording rule to be
defined in the Prometheus configuration (see `prometheus-metrics-design`).

---

## Integration with cd-pipeline Skill

The `cd-pipeline` skill defines the deploy stage structure. The deploy-then-verify
gate belongs in the `post-deploy` job of that stage:

```
deploy-stage/
  pre-deploy:   helm diff (dry-run preview)
  deploy:       helm upgrade --atomic
  post-deploy:  post-deploy-verify.sh   ← this pattern
  on-failure:   helm rollback + alert
```

The `/readyz` endpoint used here is the same endpoint wired to Kubernetes
`readinessProbe` — no separate smoke-test endpoint is needed. A service that is
ready to serve Kubernetes traffic is ready to serve post-deploy verification.

---

## Decision Table: Which Rollback Mechanism to Use

| Model | Trigger | Rollback mechanism |
|---|---|---|
| Push CI (GitHub Actions) | `post-deploy-verify.sh` exits 1 | `helm rollback <name>` in the `on-failure` step |
| Push CI with `--atomic` | Pod never becomes Ready within Helm timeout | Helm rolls back automatically |
| GitOps Flux HelmRelease | Health check fails during reconciliation | Flux suspends and alerts; manual `flux reconcile` after fix |
| GitOps Argo CD | Health assessment fails post-sync | Argo CD marks app Degraded; auto-rollback if enabled in sync policy |

Use `helm rollback` only for push-model CI. GitOps systems own their own rollback
mechanisms — a manual `helm rollback` in a GitOps repo bypasses the Git source of
truth and creates state drift.

---

## Checklist: Adding Deploy-then-Verify to a New Service

1. Confirm `/readyz` returns 200 when all critical dependencies are healthy (unit
   tested in `health_test.go`).
2. Add `post-deploy-verify.sh` to `scripts/` (or inline in the pipeline YAML for
   small repos).
3. Wire the script as the `post-deploy` step in the CI/CD pipeline.
4. Add a `on-failure: helm rollback` step (push model) or configure Flux/Argo CD
   alert routing (pull model).
5. Set `ROLLOUT_TIMEOUT` to at least `terminationGracePeriodSeconds × 2` — give
   the rollout time to terminate old pods and start new ones.
6. Confirm the CI runner has `kubectl` access to the target namespace (service
   account with `get/watch deployments` and `get pods` verbs minimum).
