# Skill: deploy/ci-pipeline

## Purpose
Produce a CI Pipeline Definition for one service (bounded context repository). The complete GitHub Actions workflow that runs on every pull request and merge to main — gates that must pass before any code reaches the shared branch or is built into a deployable image.

## Inputs
- `artifacts/implement/standards/coding-standards.md`
- `artifacts/quality/test-plan.md`
- `artifacts/quality/security-test-plan.md`
- `sdlc-config.json` (product_codename, tech_stack)
- **Argument required:** service name (e.g. `file-domain`)

## Output
**File:** `artifacts/deploy/ci/{service-name}.yml`
**Registers in manifest:** yes

## CI Pipeline Rules (enforced)
- Secret scanning is the first job — nothing else runs until it passes.
- All gate jobs run in parallel where possible (linting, unit tests, vulnerability scan).
- Integration and contract tests run after unit tests pass (they are slower).
- Image is built and pushed only after ALL tests pass.
- Image tag is always the commit SHA — never `latest`.
- No secrets are hardcoded in the workflow file; all use `${{ secrets.NAME }}`.

## Artifact Template

```yaml
# artifacts/deploy/ci/{service-name}.yml
# CI Pipeline: {service-name}
# Runs on: every PR + merge to main

name: CI — {service-name}

on:
  pull_request:
    branches: [main]
    paths:
      - '{service-name}/**'
      - '.github/workflows/ci-{service-name}.yml'
  push:
    branches: [main]
    paths:
      - '{service-name}/**'

env:
  GO_VERSION: '1.23'
  SERVICE_NAME: {service-name}
  IMAGE_REGISTRY: ghcr.io/${{ github.repository_owner }}
  IMAGE_NAME: {product-codename}-{service-name}

jobs:
  # ── Gate 1: Secret scanning (HARD BLOCK — runs first, nothing else starts until this passes) ──
  secret-scan:
    name: Secret Scan (gitleaks)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # full history for gitleaks
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  # ── Gate 2: Static analysis (parallel with vuln-check and unit-tests) ──
  lint:
    name: Lint (golangci-lint)
    runs-on: ubuntu-latest
    needs: [secret-scan]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
          cache: true
      - uses: golangci/golangci-lint-action@v6
        with:
          version: v1.60
          working-directory: ${{ env.SERVICE_NAME }}
          args: --timeout=5m

  sast:
    name: SAST (gosec)
    runs-on: ubuntu-latest
    needs: [secret-scan]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
      - run: go install github.com/securego/gosec/v2/cmd/gosec@latest
      - run: gosec -severity HIGH -confidence HIGH ./...
        working-directory: ${{ env.SERVICE_NAME }}

  vuln-check:
    name: Vulnerability Check (govulncheck)
    runs-on: ubuntu-latest
    needs: [secret-scan]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
      - run: go install golang.org/x/vuln/cmd/govulncheck@latest
      - run: govulncheck ./...
        working-directory: ${{ env.SERVICE_NAME }}

  architecture-check:
    name: Architecture Layers (go-cleanarch)
    runs-on: ubuntu-latest
    needs: [secret-scan]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
      - run: go install github.com/roblaszczak/go-cleanarch@latest
      - run: go-cleanarch
        working-directory: ${{ env.SERVICE_NAME }}

  # ── Gate 3: Unit tests (with race detector) ──
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    needs: [lint, sast, vuln-check, architecture-check]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
          cache: true
      - name: Run unit tests with race detector
        run: go test -race -cover -coverprofile=coverage.out ./...
        working-directory: ${{ env.SERVICE_NAME }}
      - name: Check coverage thresholds
        run: |
          COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | tr -d '%')
          # Domain package must be ≥ 90%
          DOMAIN_COV=$(go test -cover ./internal/domain/... | grep coverage | awk '{print $2}' | tr -d '%')
          echo "Total coverage: ${COVERAGE}%"
          if (( $(echo "$DOMAIN_COV < 90" | bc -l) )); then
            echo "FAIL: domain coverage ${DOMAIN_COV}% < 90% threshold"
            exit 1
          fi
        working-directory: ${{ env.SERVICE_NAME }}

  # ── Gate 4: Integration tests (real infrastructure via testcontainers) ──
  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    needs: [unit-tests]
    services:
      docker:
        image: docker:dind
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
          cache: true
      - name: Run integration tests (real PostgreSQL + Redpanda via testcontainers)
        run: go test -tags=integration -v -timeout=10m ./...
        working-directory: ${{ env.SERVICE_NAME }}
        env:
          TESTCONTAINERS_RYUK_DISABLED: true  # Faster CI; containers cleaned up by GH Actions

  # ── Gate 5: Contract tests ──
  contract-tests:
    name: Contract Tests
    runs-on: ubuntu-latest
    needs: [unit-tests]
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive  # pulls shared-kernel schemas
      - uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
      - run: go test -tags=contract ./...
        working-directory: ${{ env.SERVICE_NAME }}

  # ── Gate 6: Build and image scan (only after all tests pass) ──
  build:
    name: Build and Image Scan
    runs-on: ubuntu-latest
    needs: [integration-tests, contract-tests]
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: |
          docker build \
            --tag ${{ env.IMAGE_REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
            --tag ${{ env.IMAGE_REGISTRY }}/${{ env.IMAGE_NAME }}:latest-dev \
            --file ${{ env.SERVICE_NAME }}/Dockerfile \
            ${{ env.SERVICE_NAME }}/
      - name: Scan image for vulnerabilities (trivy)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.IMAGE_REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: table
          exit-code: '1'
          severity: CRITICAL
      - name: Push image (merge to main only)
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
          docker push ${{ env.IMAGE_REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}

  # ── Gate 7: OPA compliance policies ──
  compliance-policies:
    name: Compliance Policy Check (OPA)
    runs-on: ubuntu-latest
    needs: [secret-scan]
    steps:
      - uses: actions/checkout@v4
      - uses: open-policy-agent/setup-opa@v2
        with:
          version: latest
      - run: opa eval --fail-defined 'data.gdpr.data_minimisation.deny' --data policies/ --input artifacts/
        working-directory: ${{ env.SERVICE_NAME }}
```

## Quality Checks
- [ ] `secret-scan` is the first job and all other jobs depend on it
- [ ] Unit, lint, SAST, vulncheck, and architecture-check run in parallel (after secret-scan)
- [ ] Integration tests use `tags=integration` build tag
- [ ] Contract tests use `tags=contract` build tag
- [ ] Image is pushed only on merge to main (not on PR)
- [ ] Image tag is `${{ github.sha }}` — not `latest`
- [ ] trivy scan fails on CRITICAL severity
- [ ] No secrets hardcoded — all use `${{ secrets.NAME }}`
