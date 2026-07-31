---
name: go-dockerfile
description: >
  Teaches the standard for containerising a Go service for production: the
  exact multi-stage build (full-toolchain builder stage, minimal
  distroless/scratch final stage), the CGO_ENABLED=0 static-binary build and
  why it is required for the final stage to run at all, the layer-caching
  order (go.mod/go.sum resolved before source, so a source-only change never
  re-downloads dependencies), the non-root numeric-UID standard (never a named
  user that doesn't resolve in a distroless/scratch image), the PID-1 /
  exec-form ENTRYPOINT rule that lets a container's SIGTERM actually reach the
  Go binary's own signal.NotifyContext handler, concrete image-size numbers
  (~15-40MB distroless vs. ~800MB-1GB single-stage) and BuildKit cache-mount
  build-time optimization, and the Trivy image-vulnerability-scanning gate
  that complements (not duplicates) go-makefile's govulncheck target. Full
  Dockerfile listing and layer-order/UID/PID-1 detail in
  references/multi-stage-build-standard.md; size numbers, cache-mount
  mechanics, and the scanning gate in
  references/image-size-and-security-standard.md. Used by the backend-engineer
  during Implement.
version: 2.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, docker, multi-stage, distroless, non-root, security, container, image-size, buildkit]
related: [go-service-skeleton, go-makefile, kubernetes-manifest, security-architecture, secrets-management]
---

# Go Dockerfile

## Purpose

The container image is the deployable unit. For a Go service it must be tiny, contain only the
static binary and its certificates, run as a non-root numeric UID, forward `SIGTERM` correctly to
the process actually running as PID 1, carry no build tools or shell, and minimize both its own
footprint (memory/disk/pull time) and the time it takes to build. A minimal image is also a
minimal attack surface — the first workload-layer control from `security-architecture`.

This skill produces the production `Dockerfile` and `.dockerignore`. Deployment manifests are
`kubernetes-manifest`'s domain; the `make docker`/`make vuln` targets that invoke this build are
`go-makefile`'s domain.

---

## Multi-Stage Build Standard

Two stages, always: a `build` stage with the full Go toolchain, and a final stage containing
only the compiled binary. The toolchain, module cache, and source tree never reach the shipped
image. Full annotated Dockerfile: `references/multi-stage-build-standard.md`.

```dockerfile
FROM golang:1.23-bookworm AS build            # full toolchain — this stage only
# ...(deps, then source, then build — see Layer-Caching Order below)...
FROM gcr.io/distroless/static-debian12:nonroot   # final stage — binary only
COPY --from=build /out/server /server
USER nonroot:nonroot
ENTRYPOINT ["/server"]
```

`distroless/static:nonroot` (or bare `scratch`) is the default final base: no shell, no package
manager, no dynamic linker. `scratch` saves distroless's last ~2MB (CA certs + the `nonroot`
user entry) — prefer `distroless/static:nonroot` unless the service makes no outbound TLS calls.

---

## Static Binary Build Standard

`CGO_ENABLED=0` is a **hard requirement**, not an optimization: neither `scratch` nor
`distroless/static` ships a dynamic linker or `libc.so`, so a cgo-linked binary fails to start
on either at all. Pair it with `-trimpath` (no build-host paths leak into panics; reproducible
across build hosts) and `-ldflags="-s -w"` (strips debug symbols, typically 20-30% smaller —
debug a symbol-complete build in staging, never in the shipped image):

```dockerfile
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server
```

Verify statically: `file /out/server` must read `statically linked`, never `dynamically
linked`. Full explanation and the failure modes of getting this wrong:
`references/multi-stage-build-standard.md`.

---

## Layer-Caching Order Standard

`go.mod`/`go.sum` are copied and `go mod download`'d **before** the rest of the source is
copied. Docker's layer cache keys each instruction on its inputs; reordering so the
rarely-changing input (dependencies) precedes the frequently-changing one (application code)
means a source-only change reuses the dependency layer untouched instead of re-downloading every
module:

```dockerfile
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download   # cached unless go.mod/go.sum change
COPY . .                                                     # only this busts on a code edit
```

Before/after comparison and the exact caching mechanics: `references/multi-stage-build-standard.md`.

---

## Non-Root Numeric UID Standard

`USER` must be a **numeric UID**, never a named user that doesn't resolve in the exact
final-stage image. `scratch` has no `/etc/passwd` at all — `USER appuser` fails outright.
`distroless/static:nonroot` provisions exactly one entry (`nonroot`, uid/gid `65532:65532`),
resolvable only in that specific tag. The numeric form (`USER 65532:65532`) is portable across
any final-stage image and is the form to prefer whenever the base might ever change. This is
defense in depth alongside — never a substitute for — the platform-layer
`runAsNonRoot`/`runAsUser` `securityContext` `kubernetes-manifest` sets. Full rule and failure
modes: `references/multi-stage-build-standard.md`.

---

## PID 1 and Signal Forwarding (exec-form `ENTRYPOINT`)

`ENTRYPOINT`/`CMD` must use **exec form** (`ENTRYPOINT ["/server"]`), never shell form
(`ENTRYPOINT /server`). Shell form runs `/bin/sh -c "/server"`, making `sh` — not the Go
binary — PID 1; `sh` does not forward `SIGTERM` to its child by default, so Kubernetes' pod
termination signal is silently ignored until `terminationGracePeriodSeconds` expires and
Kubernetes escalates to `SIGKILL`, on **every** rolling deploy and pod eviction. Exec form makes
the Go binary itself PID 1, so `go-service-skeleton`'s
`signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)` handler actually
receives the signal it's written to catch — this Dockerfile rule is the container-side half of
that skill's shutdown contract; neither works without the other. Full explanation:
`references/multi-stage-build-standard.md`.

---

## Image-Size and Build-Time Optimization

A single-stage `golang:1.23` image runs **~800MB-1GB+**; a multi-stage `distroless/static` image
with a stripped static binary runs **~15-40MB** — roughly one to two orders of magnitude
smaller, the concrete target "minimal" means here. `-ldflags="-s -w"` alone typically cuts
20-30% off the binary. BuildKit `--mount=type=cache` mounts for the module and build caches
(`/go/pkg/mod`, `/root/.cache/go-build`) persist outside the image entirely — never counted in
size, never shipped — and make repeated builds fast by skipping re-downloads and recompiles of
unchanged dependencies; wire `cache-from`/`cache-to: type=gha` in CI so the cache survives across
GitHub Actions runs, not just locally. Full numbers table and cache-mount CI wiring:
`references/image-size-and-security-standard.md`.

---

## Security Scanning Gate

**Trivy** (open-source, no license cost — the frugal choice) scans the **built image's
filesystem** for known-vulnerable OS packages and embedded files — a different, complementary
surface from `go-makefile`'s `make vuln` (`govulncheck`, which scans reachable Go source only
and never inspects the OS layer). Both run; neither replaces the other:

```bash
make docker                                                    # go-makefile builds $(IMAGE)
trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed "$IMAGE"
```

`--exit-code 1` makes this a merge-blocking gate, not an ignored report; `--ignore-unfixed`
avoids gating permanently on a CVE with no available fix. Rebuild and rescan on a schedule
(weekly) even absent a code change — base-image CVEs are disclosed against unchanged layers.
Full rationale and base-image-drift handling: `references/image-size-and-security-standard.md`.

---

## No Secrets in Layers, Reproducibility, and Provenance

Every layer is extractable, including one a later layer deletes from — layers are append-only.
No secrets are ever `COPY`'d in, even temporarily, and no build-time secret env vars (they leak
into `docker history`). A genuinely needed build-time secret (e.g., a private module token) uses
a BuildKit secret mount, which never persists in a layer:

```dockerfile
RUN --mount=type=secret,id=netrc,target=/root/.netrc GOPRIVATE=git.example.com go mod download
```

This aligns with `secrets-management`'s non-negotiables. Separately: pin base images by tag and
digest (`@sha256:...`) so a build cannot be silently changed by an upstream re-tag — `-trimpath`
plus a pinned Go version make the binary itself reproducible. The image is signed with Cosign in
CI and verified at admission (`security-architecture`) — only signed images run in production.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Multi-stage | Toolchain confined to the `build` stage | Go toolchain shipped in the final image |
| Minimal base | `distroless`/`scratch`; ~15-40MB shipped | `ubuntu`/`alpine` in prod; image in the hundreds of MB |
| Static binary | `CGO_ENABLED=0`; `file` reports statically linked | Dynamically linked binary on scratch/distroless |
| `-trimpath` + `-ldflags="-s -w"` | Build-host paths absent; symbols stripped | Local paths in panics; unstripped binary shipped |
| Layer-caching order | `go.mod`/`go.sum` + `go mod download` before `COPY . .` | Single `COPY . .` busting the dep cache every build |
| Cache mounts | `--mount=type=cache` on module + build cache, `id=` set | No cache mount; every build re-downloads/recompiles |
| Non-root numeric UID | `USER <uid>:<gid>`, resolves in the exact final image | Named user absent from that image's `/etc/passwd`, or root |
| Exec-form `ENTRYPOINT` | `ENTRYPOINT ["/server"]` — binary is PID 1 | Shell-form `ENTRYPOINT`/`CMD` swallows `SIGTERM` |
| No secrets in layers | No copied secrets; BuildKit secret mounts only | Secrets in layers or build-time env vars |
| Vulnerability-scanned | `trivy image` HIGH/CRITICAL-clean, wired as a CI gate | Unscanned image, or scan result not gating |
| Pinned & signed | Base pinned by digest; image Cosign-signed | Floating `latest` base; unsigned image |

---

## Anti-Patterns

- **Single-stage image** — shipping the toolchain, source tree, and module cache multiplies
  both attack surface and image size by an order of magnitude over multi-stage.
- **`FROM golang:latest`** — an unpinned base means yesterday's green build and today's broken
  one built "the same" Dockerfile. Pin by tag, prefer digest.
- **Shell-form `ENTRYPOINT`/`CMD`** — makes `sh` PID 1 instead of the binary; `SIGTERM` never
  reaches `go-service-skeleton`'s handler; every deploy hard-kills instead of draining.
- **A named `USER` that doesn't resolve in the final image** — silently runs as root, or fails
  the build, depending on the Docker version; use the numeric UID form.
- **`COPY . .` before `go mod download`** — every source edit re-downloads every module in CI.
- **Deleting a secret in a later layer** — `COPY key.pem` + `RUN rm key.pem` still leaves the
  key extractable from the earlier layer.
- **Skipping the image scan, or not gating on it** — a report nobody reads gates nothing;
  `--exit-code 1` must actually fail the build.
- **Adding `tini`/`dumb-init` to a service with no child processes** — unnecessary final-stage
  weight solving a zombie-reaping problem this service doesn't have.

---

## Output Format

**`Dockerfile`** — must contain, in order: a `build` stage on a pinned `golang` tag; `COPY
go.mod go.sum ./` + cache-mounted `go mod download` before any other `COPY`; `COPY . .`; a
cache-mounted, `CGO_ENABLED=0`, `-trimpath`, `-ldflags="-s -w"` build; a final stage on a pinned
`distroless`/`scratch` tag; `COPY --from=build` of only the binary; a numeric-UID `USER`; and an
exec-form `ENTRYPOINT`. Full listing: `references/multi-stage-build-standard.md`.

**`.dockerignore`** — excludes `.git`, `.github`, docs, `Makefile`, local build output
(`bin/`, `coverage.out`), env files, and `**/*_test.go`. Full listing:
`references/multi-stage-build-standard.md`.
