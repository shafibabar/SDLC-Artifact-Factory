# CI Pipeline — Gate Specifications Reference

This file is the companion to `skills/ci-pipeline/SKILL.md`. It contains the
full workflow YAML, caller workflow pattern, React variant, caching mechanics,
and the worked compliance-platform example. Load this file when producing or
reviewing actual workflow files; the SKILL.md body carries decision-shaping
guidance, this file carries the implementation templates.

---

## Caller Workflow Pattern

Every service owns exactly one caller workflow. It is deliberately boring — it
names the service and delegates everything to the reusable workflow:

```yaml
# .github/workflows/estate-scanner-ci.yml
name: estate-scanner CI
on:
  pull_request:
    paths: ["services/estate-scanner/**"]
  push:
    branches: [main]
    paths: ["services/estate-scanner/**"]

jobs:
  ci:
    uses: ./.github/workflows/reusable-go-ci.yml
    with:
      service: estate-scanner
      working-directory: services/estate-scanner
    permissions:
      contents: read
      packages: write
      id-token: write   # Cosign keyless signing via GitHub OIDC
```

Path filters scope each service's pipeline to its own Bounded Context. A PR
touching only `services/entity-extractor/**` does not trigger `estate-scanner`'s
gates.

---

## Reusable Go Workflow — Full YAML

```yaml
# .github/workflows/reusable-go-ci.yml
name: reusable-go-ci
on:
  workflow_call:
    inputs:
      service:            { required: true, type: string }
      working-directory:  { required: true, type: string }

concurrency:
  group: ci-${{ inputs.service }}-${{ github.ref }}
  cancel-in-progress: true          # a newer push supersedes the running build

permissions: {}                     # default deny; jobs opt in below

jobs:
  gates:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    defaults:
      run: { working-directory: ${{ inputs.working-directory }} }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: ${{ inputs.working-directory }}/go.mod
          cache: true               # caches Go modules + build cache keyed on go.sum
      - name: Install gate tooling
        run: |
          go install golang.org/x/vuln/cmd/govulncheck@latest
          go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.61.0
      - name: Run all engineer gates
        run: make ci                # tidy, generate, vet, lint, arch, vuln, cover — one command

  image:
    needs: gates
    if: github.ref == 'refs/heads/main'   # PRs stop at gates; only main publishes
    runs-on: ubuntu-latest
    permissions:
      contents: write              # for github-script release creation (deploy-freq)
      packages: write              # push to ghcr.io
      id-token: write              # OIDC token for Cosign keyless
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Build and push by digest
        id: push
        uses: docker/build-push-action@v6
        with:
          context: ${{ inputs.working-directory }}
          push: true
          tags: ghcr.io/${{ github.repository }}/${{ inputs.service }}:${{ github.sha }}
          labels: |
            org.opencontainers.image.source=${{ github.server_url }}/${{ github.repository }}
            org.opencontainers.image.revision=${{ github.sha }}
      - name: Trivy scan (fail on HIGH/CRITICAL)
        uses: aquasecurity/trivy-action@0.28.0
        with:
          image-ref: ghcr.io/${{ github.repository }}/${{ inputs.service }}@${{ steps.push.outputs.digest }}
          severity: HIGH,CRITICAL
          exit-code: "1"
      - name: Cosign sign (keyless)
        run: cosign sign --yes ghcr.io/${{ github.repository }}/${{ inputs.service }}@${{ steps.push.outputs.digest }}
      - name: Emit deployment-frequency event
        if: success()
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.repos.createRelease({
              owner: context.repo.owner,
              repo: context.repo.repo,
              tag_name: `deploy-freq-${{ inputs.service }}-${Date.now()}`,
              name: `[deploy-freq] ${{ inputs.service }} @ ${context.sha.substring(0,7)}`,
              body: `service=${{ inputs.service }} sha=${context.sha} ts=${new Date().toISOString()}`,
              draft: false,
              prerelease: true
            });
```

---

## Reusable React Workflow — Full YAML

The React workflow is the same shape: `actions/setup-node` with `cache: npm`,
`npm ci && npm run ci`, then the identical image/scan/sign/push/deploy-freq tail.

```yaml
# .github/workflows/reusable-react-ci.yml
name: reusable-react-ci
on:
  workflow_call:
    inputs:
      service:            { required: true, type: string }
      working-directory:  { required: true, type: string }

concurrency:
  group: ci-${{ inputs.service }}-${{ github.ref }}
  cancel-in-progress: true

permissions: {}

jobs:
  gates:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    defaults:
      run: { working-directory: ${{ inputs.working-directory }} }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: ${{ inputs.working-directory }}/.nvmrc
          cache: npm
          cache-dependency-path: ${{ inputs.working-directory }}/package-lock.json
      - name: Install dependencies
        run: npm ci                 # never npm install — lockfile must be honoured
      - name: Run all engineer gates
        run: npm run ci             # lint, type-check, unit tests, coverage, audit

  image:
    needs: gates
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Build and push by digest
        id: push
        uses: docker/build-push-action@v6
        with:
          context: ${{ inputs.working-directory }}
          push: true
          tags: ghcr.io/${{ github.repository }}/${{ inputs.service }}:${{ github.sha }}
          labels: |
            org.opencontainers.image.source=${{ github.server_url }}/${{ github.repository }}
            org.opencontainers.image.revision=${{ github.sha }}
      - name: Trivy scan (fail on HIGH/CRITICAL)
        uses: aquasecurity/trivy-action@0.28.0
        with:
          image-ref: ghcr.io/${{ github.repository }}/${{ inputs.service }}@${{ steps.push.outputs.digest }}
          severity: HIGH,CRITICAL
          exit-code: "1"
      - name: Cosign sign (keyless)
        run: cosign sign --yes ghcr.io/${{ github.repository }}/${{ inputs.service }}@${{ steps.push.outputs.digest }}
      - name: Emit deployment-frequency event
        if: success()
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.repos.createRelease({
              owner: context.repo.owner,
              repo: context.repo.repo,
              tag_name: `deploy-freq-${{ inputs.service }}-${Date.now()}`,
              name: `[deploy-freq] ${{ inputs.service }} @ ${context.sha.substring(0,7)}`,
              body: `service=${{ inputs.service }} sha=${context.sha} ts=${new Date().toISOString()}`,
              draft: false,
              prerelease: true
            });
```

---

## Nightly Suites Workflow

```yaml
# .github/workflows/nightly-suites.yml
name: nightly-suites
on:
  schedule:
    - cron: '0 2 * * *'    # 02:00 UTC nightly

jobs:
  e2e:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4
      - name: Start kind cluster
        uses: helm/kind-action@v1
      - name: Install all service charts
        run: |
          for svc in estate-scanner entity-extractor compliance-engine compliance-dashboard; do
            helm upgrade --install "$svc" charts/"$svc" \
              --set image.digest="$(cat digests/$svc.txt)"
          done
      - name: Run e2e suite
        run: make e2e
      - name: Open issue on failure
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `[nightly] e2e failure ${new Date().toISOString().slice(0,10)}`,
              body: `Nightly e2e suite failed. See run: ${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`,
              labels: ['nightly-failure', 'blocks-promotion']
            });
```

Nightly failures open a GitHub issue with `blocks-promotion` label — the `cd-pipeline`'s promotion check reads this label before advancing to the next environment.

---

## Caching Mechanics

| Language | Cache mechanism | Key | Warm build time |
|---|---|---|---|
| Go | `actions/setup-go@v5` `cache: true` | `go.sum` hash | ≤ 90 seconds for a typical microservice |
| npm | `actions/setup-node@v4` `cache: npm` | `package-lock.json` hash | ≤ 60 seconds for a typical React app |
| Docker layers | BuildKit cache mounts in Dockerfile | Layer order (base → deps → code) | Builder step is the expensive part; order layers with least-changing last |

**Concurrency groups** cancel superseded runs — no paying for a build of a commit that was already force-pushed over. The group key `ci-<service>-<ref>` means two simultaneous PRs to the same service each get their own group and do not cancel each other.

**Frugality note:** All tooling is open-source (Trivy, Cosign, golangci-lint, govulncheck) running on the GitHub Actions free tier. No paid CI products.

---

## Worked Example — Compliance Platform

The product's three Go services (estate-scanner, entity-extractor, compliance-engine) plus the React compliance dashboard each get a five-line caller workflow pointing at the shared reusable workflow.

**Caller count:** 4 files (one per service/frontend)
**Reusable workflow count:** 2 files (reusable-go-ci.yml, reusable-react-ci.yml)
**Nightly:** 1 file (nightly-suites.yml)
**Total:** 7 workflow files serve the entire product

**Path-filtered gate behaviour:**
- PR touching only `services/entity-extractor/**` → only entity-extractor gates run
- PR touching `services/estate-scanner/**` AND `services/compliance-engine/**` → both gates run in parallel (independent concurrency groups)
- Merge to `main` touching any service → that service's gates + image/scan/sign/push + deploy-freq event

**Promotion chain:** The signed digests — never tags — produced here are what `cd-pipeline` promotes through dev → staging → per-tenant production. The deploy-freq release events produced here are what `dora-metrics` counts as Deployment Frequency events.

---

## Deployment Frequency Query

The GitHub Releases API surfaces deploy-freq events for DORA computation:

```bash
# Count deploy-freq events for estate-scanner in the last 30 days
gh api repos/:owner/:repo/releases --paginate \
  --jq '[.[] | select(.name | startswith("[deploy-freq] estate-scanner")) |
         select(.created_at > (now - 2592000 | todate))] | length'
```

The `dora-metrics` skill queries this endpoint per service and aggregates across the fleet. No external counter service required — GitHub Releases is the source of truth.

---

## Concourse CI Alternative — Pipeline Structure

When `sdlc-config.json` sets `ci_cd: concourse`, the platform-engineer maps the
same gate sequence to Concourse primitives:

```yaml
# ci/pipeline.yml (applied via: fly -t <target> set-pipeline -p estate-scanner -c ci/pipeline.yml)
resources:
  - name: source
    type: git
    source:
      uri: https://github.com/org/repo.git
      branch: main
      paths: [services/estate-scanner]

  - name: image
    type: registry-image
    source:
      repository: ghcr.io/org/estate-scanner
      username: ((github-actor))
      password: ((github-token))

jobs:
  - name: unit-tests
    plan:
      - get: source
        trigger: true
      - task: make-ci
        config:
          platform: linux
          image_resource:
            type: registry-image
            source: { repository: golang, tag: "1.23" }
          inputs:  [{ name: source }]
          run:
            path: sh
            args: ["-c", "cd source/services/estate-scanner && make ci"]

  - name: build-and-scan
    plan:
      - get: source
        passed: [unit-tests]
        trigger: true
      - task: trivy-scan
        # ... image build, trivy, cosign, push steps
      - put: image
        params:
          image: built-image/image.tar
```

The `passed: [unit-tests]` constraint on the `build-and-scan` job implements the same gate ordering as GitHub Actions' `needs: gates` — without any explicit trigger in the upstream job. The Andon Cord, trunk-based development policy, commit-stage time budget, and deployment-frequency counter requirements are unchanged; only the YAML format and execution model differ.
