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
version: 1.1.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, ci, github-actions, pipeline-of-pipelines, trivy, cosign, gates, trunk-based-development, dora]
related: [feature-flag-design, dora-metrics, cd-pipeline, test-pyramid]
---

# CI Pipeline

## Purpose

There is exactly **one path to production**: every service — Go or React — ships through the same automated gate sequence, and no gate has a bypass lane. The CI pipeline does not re-invent what the engineers built; it *invokes* it. The backend-engineer's `go-makefile` defines `make ci`, the frontend-engineer defines `npm run ci` — CI calls those single entry points, then adds the platform-owned gates the engineers cannot run alone: container image scan, signing, and publication by immutable digest.

If CI is green, the change satisfies every standard this plugin holds. If a step is skipped, the pipeline is broken — not the rule.

Full workflow YAML and the worked compliance-platform example live in `references/gate-specifications.md`.

---

## Trunk-Based Development Policy

**This is not a suggestion — it is enforced policy:**

1. **Branches merge to `main` within one calendar day.** A branch older than one day is a violation, not a style choice.
2. **Long-lived feature branches are explicitly not allowed.** The mechanism for committing unfinished work to trunk safely is a feature flag (`feature-flag-design`), not a branch. Feature flags decouple deploy from release; branches only defer integration pain.
3. **Every successful main-branch run is a deployment-frequency event.** The rate at which commits reach `main` and pass CI is the DORA Deployment Frequency metric (`dora-metrics`).

Source: *Continuous Delivery* Ch. 3 (Humble/Farley) — "commit to mainline at least once a day"; *Accelerate* Ch. 4 (Forsgren/Humble/Kim) — trunk-based development is a statistically validated capability predictor, not a cultural preference.

---

## Andon Cord — Stop the Line

**A broken commit-stage build is the team's highest priority. No new work begins until it is fixed.**

This is the Andon Cord principle from the Toyota Production System, applied to software (The DevOps Handbook, Ch. 5–6): any defect that reaches the pipeline is halted immediately, and the whole team swarms to fix it before resuming other work. A red build that sits for hours while engineers continue feature work turns one broken commit into many; integration cost compounds linearly with time.

Operationally:
- The breaking commit's author is the responsible party; the platform-engineer unblocks them if needed.
- No PRs merge to `main` while the commit-stage build is red.
- Nightly failures do not apply the Andon Cord — they open a GitHub issue and block the next promotion (`cd-pipeline`), but they do not halt feature work during the day.

---

## Commit-Stage Time Budget

The commit stage (gates 1–6, the engineer-owned `make ci` / `npm run ci` block) must complete in **single-digit minutes**. This is not an aspiration — it is a quality criterion with teeth:

- **Any gate that consistently exceeds 5 minutes on its own is a nightly-candidate, not a PR gate.** Move it to `nightly-suites.yml` and replace it with a faster proxy (sampling, subset, or time-boxed variant) for the PR loop.
- The warm-build target for a Go service is ≤ 90 seconds (module + build cache via `actions/setup-go` with `cache: true`).
- If the commit stage regularly exceeds 5 minutes total, apply the Theory of Constraints: identify the single slowest gate, optimize it first, then reassess.

Source: *Continuous Delivery* Ch. 7 — "keep the commit stage in single-digit minutes"; a gate that forces engineers to context-switch while waiting trains them to ignore CI.

---

## Deployment Frequency Counter

Every successful push to `main` emits a deployment-frequency event. This is how `dora-metrics` computes Deployment Frequency without a separate data-collection step.

Add this step to the `image` job in `reusable-go-ci.yml` and `reusable-react-ci.yml`, after a successful push:

```yaml
- name: Emit deployment-frequency event
  if: success()
  uses: actions/github-script@v7
  with:
    script: |
      await github.rest.repos.createRelease({
        owner: context.repo.owner,
        repo: context.repo.repo,
        tag_name: `deploy-freq-${{ inputs.service }}-${Date.now()}`,
        name: `[deploy-freq] ${{ inputs.service }} @ ${{ github.sha.substring(0,7) }}`,
        body: `service=${{ inputs.service }} sha=${{ github.sha }} ts=${new Date().toISOString()}`,
        draft: false,
        prerelease: true
      });
```

GitHub Release events are queryable via the API and carry a timestamp, service name, and SHA — exactly the data `dora-metrics` needs. Alternative: post to a lightweight counter endpoint (`curl -sf -X POST $DEPLOY_FREQ_ENDPOINT`) if a release-event-per-deploy volume is a concern.

---

## CI Tool Selection

**Default: GitHub Actions.** Use it unless the conditions below are met.

**Concourse CI** (resource/task/job/pipeline primitives, no shared agent state) is the alternative when:
- Reproducibility across workers is critical — Concourse runs every task in a fresh container from a pinned image; there is no shared filesystem or warm tool cache between tasks unless explicitly declared via a cache resource. This eliminates "works on my worker" failures that GitHub Actions runner state can introduce.
- Complex multi-repo fan-in dependency graphs are required — Concourse's `passed:` constraint and fan-in model natively express "run this job only when commits from repo A, repo B, and repo C have all passed their individual unit-test jobs," without a separate orchestration layer.
- Custom resource types are needed for internal systems — the Concourse resource interface (check/get/put) is a standard extension point for any versioned external system.

The `sdlc-config.json` `ci_cd` field selects the CI system. When `ci_cd: concourse`, the platform-engineer uses Concourse resource/task/job/pipeline primitives rather than GitHub Actions YAML; the gate sequence and trunk-based development policy are unchanged — only the implementation format differs.

---

## The Gate Sequence

Every merge to `main` passes these gates, in order. Gates 1–6 run inside `make ci` / `npm run ci` (engineer-owned); gates 7–10 are platform-owned:

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

The image is pushed **once**, identified by digest (`sha256:…`), and never rebuilt per environment.

Full YAML for the reusable Go workflow: `references/gate-specifications.md`.

---

## Pipeline of Pipelines

Each service owns a thin caller workflow; the gates live in **one reusable workflow** per language:

```
.github/workflows/
├── reusable-go-ci.yml          # gates, Go services (workflow_call)
├── reusable-react-ci.yml       # gates, React frontends (workflow_call)
├── estate-scanner-ci.yml       # caller: path-filtered to services/estate-scanner
├── entity-extractor-ci.yml     # caller: path-filtered to services/entity-extractor
├── compliance-engine-ci.yml    # caller: path-filtered to services/compliance-engine
└── nightly-suites.yml          # e2e / load / chaos on a schedule
```

A PR touching only `services/entity-extractor/**` runs only that service's gates — path filters keep a Bounded Context's pipeline scoped to its Bounded Context. Caller workflow pattern and full reusable workflow YAML: `references/gate-specifications.md`.

---

## Trigger Split — What Runs When

| Trigger | Runs | Why |
|---|---|---|
| **Pull request** | `make ci` (unit + integration, race, coverage, vuln, lint) | Fast, hermetic feedback — minutes |
| **Push to main** | PR gates + image build, Trivy, Cosign, push by digest + deployment-frequency event | Only merged code produces a deployable artifact |
| **Nightly schedule** | e2e, load, chaos suites against kind/staging | Too slow and environment-hungry for every PR |

---

## Least-Privilege GITHUB_TOKEN

Default is `permissions: {}` — deny everything; each job requests only what it needs. The gates job reads contents only; only the publish job writes packages; `id-token: write` exists solely for Cosign keyless signing via GitHub OIDC (no long-lived signing keys to store, rotate, or leak).

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
| Trunk-based | All branches merge to main within 1 calendar day | Branch older than 1 day still open |
| Commit-stage budget | Commit stage completes in single-digit minutes | Any PR gate consistently exceeds 5 min individually |
| Deployment frequency | Every successful main-branch run emits a deploy-freq event | No event emitted; dora-metrics has no data source |

---

## Anti-Patterns

- **CI as a second implementation of the Makefile** — re-listing `go test`, `go vet` in YAML drifts from `make ci` the first week.
- **A bypass lane** — "hotfix" workflows that skip the scan or sign step. An unsigned emergency image is how supply-chain incidents start.
- **Promotion by tag** — `:latest` or `:main` can silently move. A digest cannot.
- **Rebuilding per environment** — one image per environment breaks build-once/promote-everywhere and voids the signature.
- **Advisory scanning** — a Trivy report uploaded as an artifact but not failing the build gates nothing. `exit-code: "1"` or it doesn't exist.
- **e2e on every PR** — slow suites on the PR loop trains engineers to ignore CI.
- **`write-all` token because "it's easier"** — a compromised third-party action then owns the repo.
- **Long-lived branches** — a branch open for more than a day is a deferred merge conflict; use `feature-flag-design` instead.
- **Ignoring a red build** — continuing feature work while the commit stage is broken is the anti-pattern Andon Cord policy prevents.

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
