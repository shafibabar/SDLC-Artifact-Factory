---
name: dockerfile-patterns
description: >
  Teaches the cross-service container image standards every per-service
  Dockerfile must conform to — multi-stage builds, the minimal base-image
  allowlist, non-root UIDs, no secrets in layers, OCI provenance labels,
  deterministic builds with digest-pinned bases, image size budgets, why
  images carry no HEALTHCHECK, and the scan/sign gates — with a conformance
  checklist services are audited against. Per-service Dockerfile contents
  remain with go-dockerfile and react-dockerfile. Used by the
  platform-engineer during Deploy.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, container, oci, distroless, provenance, image-standards, conformance]
---

# Dockerfile Patterns

## Purpose

Every container image on this platform — regardless of language or Bounded Context — must satisfy one set of standards, because every image passes through the same CI gates (`ci-pipeline`), runs under the same pod SecurityContext (`kubernetes-manifest`), and carries the same provenance obligations. This skill owns those **cross-service standards** and the audit checklist that enforces them.

It deliberately does **not** own Dockerfile contents. The backend-engineer's `go-dockerfile` and the frontend-engineer's `react-dockerfile` define *how* each service builds its image; this skill defines *what any conforming image must look like* when it arrives at the platform boundary. When a per-service file and this standard disagree, the standard wins and the defect is escalated to the owning engineer — the platform-engineer never edits a service's Dockerfile.

---

## The Standards

### 1. Multi-Stage, Toolchain Never Ships

Every image is a multi-stage build: build tools, source trees, and package managers stay in the build stage; the final stage carries only the runtime artifact. `go-dockerfile` (static binary onto distroless) and `react-dockerfile` (bundle onto unprivileged nginx) both already implement this — the standard exists so the *next* service (a Python ML sidecar, a data-engineer job image) is held to it too.

### 2. Base Image Allowlist

Final-stage bases come from a short, digest-pinned allowlist. Anything else requires an ADR:

| Base | For | Runs as | Why allowed |
|---|---|---|---|
| `gcr.io/distroless/static-debian12:nonroot` | Static Go binaries (all backend services) | uid 65532 | No shell, no package manager, CA certs + tzdata included |
| `gcr.io/distroless/base-debian12:nonroot` | Binaries needing glibc (rare; justify why not static) | uid 65532 | Same posture, plus libc |
| `nginxinc/nginx-unprivileged:<pinned>-alpine` | React frontend bundles | uid 101 | Non-root nginx, no privileged ports |
| `scratch` | Static binaries where even distroless is too much | explicit `USER` | Empty; certs/tzdata must be copied in deliberately |

**Not on the list**: `ubuntu`, `debian`, `alpine` (bare), `golang`, `node` as final stages. A shell in production is a gift to an attacker who lands in the container — debugging uses ephemeral containers at the platform layer (`kubectl debug`), never tooling baked into the image.

### 3. Non-Root, Read-Only Compatible

Every image declares a non-root `USER` (numeric UID, so `runAsNonRoot` can verify it) and writes nothing to its filesystem at runtime — logs to stdout, secrets from mounted in-memory volumes, temp files only in mounted `emptyDir`s. This is what lets `kubernetes-manifest` mandate `runAsNonRoot: true` and `readOnlyRootFilesystem: true` fleet-wide without per-service exceptions.

### 4. No Secrets in Any Layer

Layers are append-only and extractable; a secret copied then deleted is still shipped. No secret files, no secret build `ARG`s or `ENV`s (both persist in image history). Genuinely needed build-time credentials use BuildKit secret mounts (`--mount=type=secret`), which never persist — the mechanics live in `go-dockerfile`; the *rule* is fleet-wide and audited here.

### 5. OCI Labels — Provenance Is Metadata

Every image answers "where did you come from?" without external lookups. Required labels, populated by CI (`ci-pipeline` passes them to `docker/build-push-action`):

```dockerfile
LABEL org.opencontainers.image.title="estate-scanner" \
      org.opencontainers.image.description="Scans connected sources and emits DocumentDiscovered events" \
      org.opencontainers.image.vendor="acme" \
      org.opencontainers.image.licenses="Proprietary"
# Set by CI at build time — never hardcoded:
#   org.opencontainers.image.source   = repository URL
#   org.opencontainers.image.revision = git commit SHA
#   org.opencontainers.image.version  = semver or git describe
#   org.opencontainers.image.created  = RFC 3339 build timestamp
```

`source` + `revision` are the load-bearing pair: given any running digest, `kubectl get pod -o jsonpath` → labels → the exact commit that produced it. Incident forensics without a spreadsheet.

### 6. Deterministic Builds

- **Bases pinned by digest**: `FROM gcr.io/distroless/static-debian12:nonroot@sha256:…`. A tag is a mutable pointer; a digest is a fact. Base bumps are explicit PRs (Renovate/Dependabot proposes them — reviewed, not automatic).
- **Toolchains pinned**: Go version from `go.mod`, Node version from `.nvmrc`/`engines` — never `latest`.
- **Reproducible artifacts**: `-trimpath`, stripped symbols, lockfile-driven installs (`npm ci`), so the same commit yields the same binary.

### 7. Image Size Budgets

Size is attack surface, pull latency (× replicas × tenants), and registry cost. Budgets are enforced as a CI warning at 80% and a failure at 100%:

| Image class | Budget | Typical actual |
|---|---|---|
| Go service (distroless/static) | 40 MB | 15–25 MB |
| React frontend (nginx-unprivileged) | 80 MB | 50–60 MB |
| Job images (migrations, purge jobs) | 60 MB | 20–40 MB |

A budget breach is a design signal — embedded assets, an accidental debug dependency, a wrong base — not a number to raise quietly.

### 8. No HEALTHCHECK Instruction

Images carry **no** Dockerfile `HEALTHCHECK`. Kubernetes ignores it entirely and runs its own probes; a `HEALTHCHECK` would only add a container-runtime health loop that fights the orchestrator's view. Liveness/readiness/startup semantics live in the service's endpoints (`health-check-design`) and are wired by `kubernetes-manifest` — one authority for health, not two.

### 9. Scan and Sign Are Part of the Image Contract

An image is not "built" until it is Trivy-clean (no HIGH/CRITICAL) and Cosign-signed — both enforced in `ci-pipeline`. Admission in the cluster verifies the signature (`security-architecture`); an unsigned digest cannot run in any environment. Base image CVEs surface here too: a Trivy failure on an unchanged Dockerfile means the pinned base needs a bump PR.

---

## Conformance Checklist

Every service image is audited against this table — at introduction, and re-audited when its Dockerfile changes. The audit is mechanical; each row is checkable from the image alone (`docker inspect`, `dive`, Trivy):

| # | Check | How verified |
|---|---|---|
| 1 | Multi-stage; no toolchain in final stage | `dive` / layer listing shows no compiler, shell, or package manager |
| 2 | Final base on the allowlist, pinned by digest | `FROM` line inspection |
| 3 | Non-root numeric USER | `docker inspect --format '{{.Config.User}}'` |
| 4 | No filesystem writes at runtime | Runs green under `readOnlyRootFilesystem: true` in kind |
| 5 | No secrets in layers or history | `docker history --no-trunc` + secret-scanner pass over layers |
| 6 | Required OCI labels present, revision matches commit | `docker inspect` labels vs git SHA |
| 7 | Within size budget | `docker images` vs budget table |
| 8 | No HEALTHCHECK instruction | `docker inspect --format '{{.Config.Healthcheck}}'` is nil |
| 9 | Trivy-clean, Cosign-signed | CI gate status for the digest |
| 10 | Logs to stdout/stderr only | No log-file paths configured; verified in kind |

A failed row is a defect filed against the owning engineer's Dockerfile skill (`go-dockerfile` / `react-dockerfile`) — with the row number, so the fix is unambiguous.

---

## Worked Example — Auditing the Fleet

The compliance platform ships four images. The audit table, as it appears in the platform's conformance record:

| Image | Base | UID | Size | Labels | HC | Signed | Verdict |
|---|---|---|---|---|---|---|---|
| estate-scanner | distroless/static@sha256:… | 65532 | 21 MB | ✓ | none | ✓ | Pass |
| entity-extractor | distroless/static@sha256:… | 65532 | 24 MB | ✓ | none | ✓ | Pass |
| compliance-engine | distroless/static@sha256:… | 65532 | 19 MB | ✓ | none | ✓ | Pass |
| compliance-dashboard | nginx-unprivileged:1.27-alpine@sha256:… | 101 | 54 MB | ✓ | none | ✓ | Pass |

Every image runs under the same pod SecurityContext in every tenant's namespace; every digest resolves to a commit via its `revision` label. When entity-extractor later gains a PDF-parsing native dependency and its image jumps to 55 MB, check 7 fails CI — the resolution (distroless/base + justification ADR, or budget revision) is a reviewed decision, not silent growth.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Standards vs contents | This skill states rules; per-service files implement | Duplicated Dockerfile instructions maintained in two places |
| Allowlist enforced | Final bases from the table, by digest | Ad-hoc bases, floating tags |
| Non-root fleet-wide | Numeric non-root USER in every image | Any image running as root, or symbolic-only user |
| Provenance | source + revision labels resolve any digest to a commit | Unlabelled images; forensics via spreadsheet |
| Determinism | Same commit → same image; base bumps are PRs | `latest` anywhere; builds that differ by day |
| Budgets gate | Size failure blocks CI | Budgets documented but unenforced |
| Health authority | No HEALTHCHECK; probes own health | Dockerfile HEALTHCHECK competing with K8s probes |
| Audit trail | Conformance table current for every image | Services introduced without an audit row |

---

## Anti-Patterns

- **Duplicating the per-service skills** — restating `go-dockerfile`'s build stages here means two sources of truth that will diverge. Standards here, implementation there; reference, never copy.
- **The allowlist exception that becomes the rule** — one "temporary" `alpine` final stage with curl for debugging normalises shells in production. Exceptions are ADRs with expiry dates.
- **Provenance by convention** — "we always deploy from main" is not provenance. Only the `revision` label baked into the digest survives an incident's timeline questions.
- **Tag-pinned "pinning"** — `distroless/static:nonroot` without the digest still moves when upstream re-tags. Pin the digest; let a bot propose bumps.
- **HEALTHCHECK "for local docker"** — it ships to production where it duplicates and contradicts probe semantics. Local compose files can define healthchecks *outside* the image.
- **Size budget as a dashboard** — an unenforced budget is a graph nobody looks at until pulls are slow across forty tenant namespaces. Gate it in CI.
- **Auditing once** — a fleet audited at launch and never re-audited converges on non-conformance one Dockerfile edit at a time. Re-audit on change; the checklist is cheap by design.

---

## Output Format

Produces the standards document and the per-image conformance record:

```markdown
---
name: container-standards-[product]
version: 1.0.0
phase: deploy
owner: platform-engineer
created: [date]
---

# Container Image Standards — [product]

## Base Image Allowlist
[Table: base@digest → permitted use → runs-as UID]

## Required OCI Labels
[Label → source (static / CI-injected)]

## Size Budgets
[Image class → budget → enforcement point]

## Conformance Record
| Image | Base | UID | Size | Labels | HEALTHCHECK | Signed | Last audited | Verdict |
|---|---|---|---|---|---|---|---|---|

## Exceptions
[ADR references, scope, expiry — empty is the goal]
```
