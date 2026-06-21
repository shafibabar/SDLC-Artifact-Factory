# Skill: deploy/cd-pipeline

## Purpose
Produce a CD Pipeline Definition for one service — the GitHub Actions workflow that takes a merged commit, promotes it through environments, and triggers ArgoCD to deploy it. Implements Continuous Delivery (not Deployment) for production: automated for staging, manual approval gate for production.

## Inputs
- `artifacts/deploy/ci/{service-name}.yml` (CI pipeline — CD depends on CI passing)
- `artifacts/design/platform/deployment-architecture.md`
- `sdlc-config.json` (deployment_targets, product_codename)
- **Argument required:** service name

## Output
**File:** `artifacts/deploy/cd/{service-name}.yml`
**Registers in manifest:** yes

## CD Pipeline Rules (enforced)
- CD is triggered only on merge to `main` (never on feature branches).
- Staging deploy is automatic after CI passes.
- Production deploy requires manual approval (environment protection rules in GitHub).
- Deployment = committing a values.yaml change (new image tag) to the GitOps repo; ArgoCD syncs.
- No `kubectl apply` or `helm upgrade` in the CD pipeline.
- Rollback = reverting the values.yaml commit.

## Artifact Template

```yaml
# artifacts/deploy/cd/{service-name}.yml
# CD Pipeline: {service-name}
# Implements Continuous Delivery (human gate before production)

name: CD — {service-name}

on:
  workflow_run:
    workflows: ["CI — {service-name}"]
    types: [completed]
    branches: [main]

jobs:
  # Only proceed if CI passed
  check-ci:
    name: Verify CI Passed
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    outputs:
      sha: ${{ github.event.workflow_run.head_sha }}
    steps:
      - run: echo "CI passed for ${{ github.event.workflow_run.head_sha }}"

  # ── Stage 1: Deploy to Staging (automatic) ──
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: [check-ci]
    environment:
      name: staging
      url: https://{product-codename}-staging.internal
    steps:
      - uses: actions/checkout@v4
        with:
          repository: {org}/{product-codename}-platform
          token: ${{ secrets.GITOPS_PAT }}
          ref: main
      - name: Bump image tag in staging values
        run: |
          sed -i "s|tag: .*|tag: ${{ needs.check-ci.outputs.sha }}|g" \
            helm/{service-name}/values-staging.yaml
          git config user.email "ci@{product-codename}.io"
          git config user.name "CD Pipeline"
          git add helm/{service-name}/values-staging.yaml
          git commit -m "deploy({service-name}): staging → ${{ needs.check-ci.outputs.sha }}"
          git push
      - name: Wait for ArgoCD sync (staging)
        run: |
          # ArgoCD CLI waits for the application to sync and become healthy
          argocd app wait {product-codename}-{service-name}-staging \
            --timeout 300 \
            --server ${{ secrets.ARGOCD_SERVER }} \
            --auth-token ${{ secrets.ARGOCD_TOKEN }}
      - name: Smoke test staging
        run: |
          curl --fail https://{product-codename}-staging.internal/api/v1/health/ready || exit 1

  # ── Stage 2: Deploy to Production (manual approval required) ──
  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [deploy-staging]
    environment:
      name: production
      url: https://{product-codename}.io
      # GitHub environment protection rules enforce:
      #   - Manual approval from 1 of: [tech-lead, platform-engineer]
      #   - No deploy outside business hours (08:00–18:00 UTC Mon–Fri)
    steps:
      - uses: actions/checkout@v4
        with:
          repository: {org}/{product-codename}-platform
          token: ${{ secrets.GITOPS_PAT }}
          ref: main
      - name: Bump image tag in production values
        run: |
          sed -i "s|tag: .*|tag: ${{ needs.check-ci.outputs.sha }}|g" \
            helm/{service-name}/values-production.yaml
          git config user.email "ci@{product-codename}.io"
          git config user.name "CD Pipeline"
          git add helm/{service-name}/values-production.yaml
          git commit -m "deploy({service-name}): production → ${{ needs.check-ci.outputs.sha }}"
          git push
      - name: Wait for ArgoCD sync (production)
        run: |
          argocd app wait {product-codename}-{service-name}-production \
            --timeout 600 \
            --server ${{ secrets.ARGOCD_SERVER }} \
            --auth-token ${{ secrets.ARGOCD_TOKEN }}
      - name: Production health check
        run: |
          curl --fail https://{product-codename}.io/api/v1/health/ready || exit 1
      - name: Notify Slack on successful deploy
        if: success()
        uses: slackapi/slack-github-action@v1
        with:
          channel-id: '#deployments'
          slack-message: "✅ {service-name} deployed to production — ${{ needs.check-ci.outputs.sha }}"
        env:
          SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}

  # ── Automatic rollback on health check failure ──
  rollback:
    name: Rollback on Failure
    runs-on: ubuntu-latest
    needs: [deploy-production]
    if: failure()
    steps:
      - uses: actions/checkout@v4
        with:
          repository: {org}/{product-codename}-platform
          token: ${{ secrets.GITOPS_PAT }}
      - name: Revert last values commit
        run: |
          git revert HEAD --no-edit
          git push
      - name: Notify on rollback
        uses: slackapi/slack-github-action@v1
        with:
          channel-id: '#deployments'
          slack-message: "🔴 ROLLBACK: {service-name} production deploy failed — rolling back to previous version"
        env:
          SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
```

## Quality Checks
- [ ] CD triggers on `workflow_run` of CI (not on push directly)
- [ ] Production deploy uses GitHub `environment` with protection rules
- [ ] Deployment mechanism is `git commit + push values.yaml` (not kubectl/helm)
- [ ] ArgoCD sync wait is present for both staging and production
- [ ] Health check runs after ArgoCD sync
- [ ] Automatic rollback is defined for production failure
- [ ] Slack notifications on success and failure
