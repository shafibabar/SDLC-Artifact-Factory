---
name: go-dockerfile
description: >
  Teaches how to containerise a Go service for production — a multi-stage build
  producing a minimal, non-root, distroless (or scratch) image, static linking,
  build-cache-friendly layer ordering, reproducible builds with pinned versions,
  no secrets in layers, and image hardening for the Zero Trust workload layer.
  Implements the security-architecture workload controls. Used by the
  backend-engineer during Implement.
version: 1.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, docker, multi-stage, distroless, non-root, security, container]
---

# Go Dockerfile

## Purpose

The container image is the deployable unit. For a Go service it should be tiny, contain only the static binary and its certificates, run as a non-root user, and carry no build tools, no shell, and no secrets. A minimal image has a minimal attack surface — it is the first of the workload-layer controls from the security `security-architecture` skill.

This skill produces the production Dockerfile. The deployment manifests that run it are the platform-engineer's domain.

---

## Multi-Stage Build

Two stages: a builder with the Go toolchain, and a final image with only the binary. The toolchain never ships to production.

```dockerfile
# syntax=docker/dockerfile:1

# ---- Build stage ----
FROM golang:1.23-bookworm AS build
ARG VERSION=dev
WORKDIR /src

# Cache deps separately from source so dependency layers reuse across builds.
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

# Now copy source and build.
COPY . .
# Static, stripped, reproducible binary. CGO off ⇒ no libc dependency ⇒ runs on scratch/distroless.
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build \
      -trimpath \
      -ldflags="-s -w -X main.version=${VERSION}" \
      -o /out/server ./cmd/server

# ---- Final stage ----
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/server /server
# distroless:nonroot already runs as uid 65532 and includes CA certs + tzdata.
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
```

| Choice | Why |
|---|---|
| `distroless/static:nonroot` | No shell, no package manager, runs non-root by default — minimal attack surface |
| `CGO_ENABLED=0` | Fully static binary; no glibc → works on distroless/scratch; reproducible |
| `-trimpath` | Removes local filesystem paths from the binary — reproducible, no info leak |
| `-ldflags="-s -w"` | Strips debug symbols → smaller image (keep symbols out of prod; profile in staging) |
| `--mount=type=cache` | BuildKit caches modules and build output → fast incremental CI builds |
| Layer ordering | `go.mod`/`go.sum` before source → dependency layer reused when only source changes |

---

## Non-Root and Read-Only

The image runs as a non-root user (`nonroot`, uid 65532). At deploy time the platform-engineer sets the matching pod SecurityContext (`runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`) — the image is built to be compatible: it writes nothing to the filesystem at runtime (secrets are read from a mounted in-memory volume — see `secrets-management`; logs go to stdout).

---

## No Secrets in Layers

Every layer of an image is extractable. Therefore:

- **No secrets copied in** — not even temporarily; a deleted file in a later layer is still present in the earlier layer.
- **No build-time secret env vars** — they leak into image history (`docker history`).
- Build-time secrets that are genuinely needed (e.g., a private module token) use BuildKit secret mounts, which never persist in a layer:

```dockerfile
# .netrc with the module token is mounted for this one RUN only — it never lands in a layer.
RUN --mount=type=secret,id=netrc,target=/root/.netrc \
    GOPRIVATE=git.example.com go mod download
```

This aligns with the security `secrets-management` non-negotiables (no secrets in images, no build-time env var secrets).

---

## Reproducibility and Provenance

- **Pin base images** by tag and ideally digest (`@sha256:...`) so a build is reproducible and not silently changed by an upstream re-tag.
- **`-trimpath` + pinned Go version** make the binary reproducible.
- The image is **signed with Cosign** in CI and verified at admission (see `security-architecture`) — only signed images run in production.
- A **vulnerability scan (Trivy)** gates the build: no HIGH/CRITICAL CVEs ship (CI gate; see platform CI pipeline).

---

## Health and Observability Compatibility

- The binary exposes liveness/readiness endpoints (see observability `health-check-design`); the platform-engineer wires the probes.
- Logs go to **stdout/stderr** as JSON (see `structured-logging-design`) — the container never writes log files.
- The pprof admin endpoint, if enabled, binds to a separate internal port (see `go-performance-optimization`) — never exposed in the service's published port.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Multi-stage | Toolchain stays in the build stage | Go toolchain shipped in the final image |
| Minimal base | distroless/scratch; no shell or package manager | `ubuntu`/`alpine` with extra tooling in prod |
| Non-root | Runs as non-root uid; FS-write-free at runtime | Runs as root; writes to root filesystem |
| Static binary | `CGO_ENABLED=0`, `-trimpath` | Dynamically linked / non-reproducible build |
| No secrets in layers | No copied secrets; BuildKit secret mounts only | Secrets in layers or build-time env vars |
| Cache-friendly layers | deps layer before source | Single `COPY . .` busting the dep cache every build |
| Pinned & signed | Base pinned by digest; image Cosign-signed; Trivy-clean | Floating `latest` base; unsigned; unscanned |

---

## Anti-Patterns

- **Single-stage image** — shipping the Go toolchain, source tree, and git history to production multiplies the attack surface and the image size by an order of magnitude.
- **`FROM golang:latest`** — an unpinned base means yesterday's green build and today's broken one built "the same" Dockerfile. Pin by tag, prefer digest.
- **Deleting a secret in a later layer** — `COPY key.pem` + `RUN rm key.pem` still leaves the key extractable from the earlier layer. Layers are append-only.
- **`apk add` / `apt-get install` debugging tools in the final stage** — a shell and curl in production is a gift to an attacker who lands in the container. Debug with ephemeral containers at the platform layer instead.
- **Baking configuration or environment into the image** — one image per environment breaks provenance. Build once, sign once, promote the same digest; configuration comes from the platform.
- **`COPY . .` before `go mod download`** — every source edit busts the dependency cache and re-downloads all modules in CI.

---

## Output Format

Produces the Dockerfile and a `.dockerignore`:

```
Dockerfile
.dockerignore        (excludes tests, .git, local artifacts from the build context)
```
