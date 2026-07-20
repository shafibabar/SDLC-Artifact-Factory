---
name: ci-pipeline
description: >
  Teaches the one path to production for continuous integration — a reusable
  GitHub Actions workflow per service that calls the engineers' `make ci` /
  `npm run ci`, the mandatory gate sequence (build, vet/lint, race tests,
  coverage, govulncheck, Trivy image scan, Cosign signing, push by digest),
  the Pipeline of Pipelines composition, dependency caching, PR/main/nightly
  trigger split, concurrency groups, and least-privilege GITHUB_TOKEN
  permissions. Used by the platform-engineer during Deploy.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, ci, github-actions, pipeline-of-pipelines, trivy, cosign, gates]
---

# CI Pipeline

## Purpose

There is exactly **one path to production**: every service — Go or React — ships through the same automated gate sequence, and no gate has a bypass lane. The CI pipeline does not re-invent what the engineers built; it *invokes* it. The backend-engineer's `go-makefile` defines `make ci`, the frontend-engineer defines `npm run ci` — CI calls those single entry points, then adds the platform-owned gates the engineers cannot run alone: container image scan, signing, and publication by immutable digest.

If CI is green, the change satisfies every standard this plugin holds. If a step is skipped, the pipeline is broken — not the rule.

---

## The Gate Sequence

Every merge to `main` passes these gates, in order. The first six run inside `make ci` / `npm run ci` (owned by the engineers); the last four are platform-owned:

| # | Gate | Owner | Fails the build when |
|---|---|---|---|
| 1 | Build | engineer (`make build`) | Code does not compile |
| 2 | Vet / lint | engineer (`make ci`) | `go vet` or `golangci-lint` / eslint findings |
| 3 | Race tests | engineer (`make ci`) | Any test failure or data race (`-race` always on) |
| 4 | Coverage | engineer (`make ci`) | Coverage below the enforced threshold (≥80%) |
| 5 | `govulncheck` / `npm audit` | engineer (`make ci`) | Known-vulnerable dependency in the call graph |
| 6 | Freshness | engineer (`make ci`) | Generated code or lockfile drift uncommitted |
| 7 | Image build | platform | Dockerfile violates `dockerfile-patterns` conformance |
| 8 | Trivy scan | platform | HIGH/CRITICAL CVE in the built image |
| 9 | Cosign sign | platform | Signing fails (keyless, via GitHub OIDC) |
| 10 | Push by digest | platform | — output is the immutable digest CD promotes |

The image is pushed **once**, identified by digest (`sha256:…`), and never rebuilt per environment — promotion of that digest is the `cd-pipeline` and `environment-config` skills' domain.

---

## Pipeline of Pipelines

Each service owns a thin caller workflow; the gates live in **one reusable workflow** per language. This is the Pipeline of Pipelines: per-service pipelines composed from shared, versioned building blocks — change the gate once, every service gets it.

```
.github/workflows/
├── reusable-go-ci.yml          # the gates, Go services (workflow_call)
├── reusable-react-ci.yml       # the gates, React frontends (workflow_call)
├── estate-scanner-ci.yml       # caller: path-filtered to services/estate-scanner
├── entity-extractor-ci.yml     # caller: path-filtered to services/entity-extractor
├── compliance-engine-ci.yml    # caller: path-filtered to services/compliance-engine
└── nightly-suites.yml          # e2e / load / chaos on a schedule
```

A caller is deliberately boring — it names the service and delegates:

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

---

## The Reusable Go Workflow

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
      contents: read
      packages: write               # push to ghcr.io
      id-token: write               # OIDC token for Cosign keyless
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
```

The React reusable workflow is the same shape: `actions/setup-node` with `cache: npm`, `npm ci && npm run ci`, then the identical image/scan/sign/push tail. One shape, two languages.

---

## Trigger Split — What Runs When

The test-strategist's suite split (`test-pyramid`) maps to triggers; CI runs the suites, it does not author them:

| Trigger | Runs | Why |
|---|---|---|
| **Pull request** | `make ci` (unit + integration, race, coverage, vuln, lint) | Fast, hermetic feedback — minutes, not hours |
| **Push to main** | Everything on PR + image build, Trivy, Cosign, push by digest | Only merged code produces a deployable artifact |
| **Nightly schedule** | e2e (`go-e2e-test`), load (`go-load-test`), chaos suites against a kind/staging environment | Too slow and environment-hungry for every PR |

Nightly failures page nobody at 3 a.m. — they open an issue and block the next promotion until green (`cd-pipeline` checks the nightly status).

---

## Caching and Frugality

GitHub Actions minutes are the budget; caching is how CI stays inside it:

- **Go**: `actions/setup-go@v5` with `cache: true` — module and build caches keyed on `go.sum`. A warm build of estate-scanner drops from ~6 min to ~90 s.
- **npm**: `actions/setup-node` with `cache: npm` keyed on `package-lock.json`; always `npm ci`, never `npm install`.
- **Docker**: BuildKit cache mounts inside the Dockerfile (`go-dockerfile` already orders layers for this); `docker/build-push-action` adds registry-backed layer cache (`cache-from`/`cache-to: type=gha`) when build times justify it.
- **Concurrency groups** cancel superseded runs — no paying for a build of a commit that was already force-pushed over.

All tooling is open-source (Trivy, Cosign, golangci-lint, govulncheck) on the free GitHub Actions tier — no paid CI products.

---

## Least-Privilege GITHUB_TOKEN

The workflow default is `permissions: {}` — deny everything, then each job requests only what it needs. The gates job can read contents and nothing else; only the publish job can write packages; `id-token: write` exists solely so Cosign can sign keylessly against GitHub's OIDC provider (no long-lived signing keys to store, rotate, or leak — the `secrets-management` posture applied to the pipeline itself).

---

## Worked Example — Compliance Platform

The product's three Go services (estate-scanner, entity-extractor, compliance-engine) plus the React compliance dashboard each get a five-line caller workflow pointing at the shared reusable workflow. A PR touching only `services/entity-extractor/**` runs only that service's gates — path filters keep a Bounded Context's pipeline scoped to its Bounded Context. On merge to main, four signed images land in `ghcr.io`, each addressed by digest; the nightly workflow spins up kind, installs all four charts (`helm-chart`), and runs the e2e suite against the assembled system. The digests — never tags — are what `cd-pipeline` promotes through dev → staging → per-tenant production.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| One path | Every service ships via the same reusable workflow | A service with bespoke steps or a skipped gate |
| Delegation | CI calls `make ci` / `npm run ci` | CI YAML re-listing raw `go`/`npm` commands |
| All gates present | build → lint → race → coverage → vuln → scan → sign → push | Any gate missing or advisory-only |
| Digest output | Images pushed and referenced by `sha256` digest | Promotion by mutable tag (`latest`, branch names) |
| Scan blocks | Trivy HIGH/CRITICAL fails the build | Scan runs but `exit-code: 0` |
| Signed images | Cosign keyless on every published digest | Unsigned images, or stored signing keys |
| Least privilege | `permissions: {}` default, per-job opt-in | Default token permissions, or `write-all` |
| Trigger split | PR fast suites; main publishes; nightly slow suites | e2e on every PR, or nightly suites that never run |
| Concurrency | Groups cancel superseded runs | Stale builds racing to publish |

---

## Anti-Patterns

- **CI as a second implementation of the Makefile** — re-listing `go test`, `go vet` in YAML drifts from `make ci` the first week. CI invokes the engineers' entry point, nothing else.
- **A bypass lane** — "hotfix" workflows that skip the scan or sign step. The one path exists precisely for the day someone is in a hurry; an unsigned emergency image is how supply-chain incidents start.
- **Promotion by tag** — `:latest` or `:main` can silently move. A digest cannot. If CD consumes tags, provenance is theatre.
- **Rebuilding per environment** — one image per environment breaks the build-once/promote-everywhere guarantee and voids the signature. Build once on main; every environment runs the same digest.
- **Advisory scanning** — a Trivy report uploaded as an artifact but not failing the build gates nothing. `exit-code: "1"` or it doesn't exist.
- **e2e on every PR** — slow suites on the PR loop trains engineers to ignore CI. Fast on PR, thorough nightly, per the test-strategist's split.
- **`write-all` token because "it's easier"** — a compromised third-party action then owns the repo. Deny by default; each job justifies its permissions.

---

## Output Format

Produces workflow files in the product repository:

```markdown
---
name: ci-pipeline-[product]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [date]
---

# CI Pipeline — [product]

## Files
.github/workflows/reusable-go-ci.yml
.github/workflows/reusable-react-ci.yml
.github/workflows/[service]-ci.yml        (one caller per service)
.github/workflows/nightly-suites.yml

## Gate Sequence
[Table: gate → tool → failure condition, per the sequence above]

## Trigger Map
[PR / main / nightly → suites run, per the test-strategist's split]

## Traceability
[NFR IDs and security gates (security-engineer) this pipeline enforces]
```
