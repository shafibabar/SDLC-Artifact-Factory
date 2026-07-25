# Image Size, Build-Time Optimization, and Security Scanning — Full Reference

Self-contained reference for `go-dockerfile`. Covers concrete size numbers that make "minimal"
checkable rather than aspirational, the BuildKit cache-mount mechanics that make repeated builds
fast, and the vulnerability-scanning gate that governs what ships. Read this when sizing a build
pipeline or wiring the CI scan stage, not just when reasoning about the pattern in the abstract.

---

## Image Size — Concrete Numbers

Exact bytes vary by Go version, module graph, and platform, but the order of magnitude is
stable and worth stating so "minimal" is a checkable target, not a vibe:

| Image | Approximate size | Contents |
|---|---|---|
| `golang:1.23-bookworm` (naive single-stage, toolchain shipped) | ~800MB–1GB+ | Full Debian userland, Go toolchain, module cache, source tree, compiled binary |
| `golang:1.23-alpine` (builder only, never shipped) | ~250–350MB | Alpine userland + Go toolchain — exists only inside the build stage |
| `gcr.io/distroless/static-debian12:nonroot` (final-stage base, before the binary is added) | ~2MB | CA certificates, `/etc/passwd` (one `nonroot` entry), timezone data — nothing else |
| `scratch` (final-stage base) | 0 bytes | Literally nothing; not even CA certs or `/etc/passwd` |
| Stripped static Go binary for a typical mid-size API service | ~10–30MB | Depends on the module graph; `-ldflags="-s -w"` typically removes 20-30% versus an unstripped build |
| **Total shipped image (distroless/static + binary)** | **~15–40MB** | The only thing that actually reaches production |

The naive single-stage image and the multi-stage distroless image differ by roughly **one to
two orders of magnitude** (20–50x smaller) — this is the concrete target the Quality Criteria's
"minimal base" row is checking, not an approximation offered for color. A pull that used to take
tens of seconds on a cold node takes a fraction of a second; a node's image cache holds many
more service versions before eviction; the attack surface shrinks from an entire Debian
userland plus a Go toolchain to a CA-certificate bundle and one static binary.

**`scratch` vs. `distroless/static:nonroot`:** `scratch` saves the last ~2MB `distroless`
carries, but that 2MB is exactly CA certificates and a non-root user entry — the two things
nearly every real service needs (outbound HTTPS calls, running as non-root without a
platform-layer override). Prefer `distroless/static:nonroot` by default; reach for bare
`scratch` only for a service that makes no outbound TLS calls, or that manually `COPY`s
`/etc/ssl/certs/ca-certificates.crt` from the builder stage — at which point the size
difference is moot and the added Dockerfile complexity usually isn't worth it.

---

## Build-Time Optimization — BuildKit Cache Mounts

Two independent caches make repeated builds fast, and both must be `--mount=type=cache`, not
baked into a layer (a layer-baked cache is invalidated by the same `COPY . .` problem the
layer-ordering rule already solves — it would grow every layer instead of persisting *outside*
the layer graph entirely):

```dockerfile
# Module download cache — survives across builds even when go.mod/go.sum changes,
# since only the changed modules are re-fetched, not the whole set.
RUN --mount=type=cache,target=/go/pkg/mod,id=gomod go mod download

# Compiler build cache — survives across builds; an unchanged package is not
# recompiled even when a different package in the same module changed.
RUN --mount=type=cache,target=/root/.cache/go-build,id=gobuild \
    CGO_ENABLED=0 go build -o /out/server ./cmd/server
```

`--mount=type=cache` caches are **BuildKit-managed and persist outside the resulting image
entirely** — they never appear in a layer, never ship to production, and never count against
image size. This is a different mechanism from Docker's ordinary layer cache (which the
layer-ordering rule exploits) — cache mounts persist even when the layer they're used in would
otherwise be invalidated by a change earlier in the `COPY . .` step, because module downloads
and compiled package objects are keyed by their own content hashes inside the cache mount, not
by the Dockerfile layer graph.

The `id=` parameter scopes a cache mount so concurrent builds (e.g., two CI jobs building
different branches at once) don't corrupt each other's cache — always set it explicitly rather
than relying on the default derived from the mount target path alone.

**Persisting the cache across CI runs (GitHub Actions default):** a cache mount only survives
within a single BuildKit instance's lifetime unless the CI runner's BuildKit cache backend
itself is persisted. With the tech-stack default (GitHub Actions), wire `docker/build-push-action`
with `cache-from`/`cache-to` pointed at the GitHub Actions cache backend:

```yaml
- uses: docker/build-push-action@v6
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

Without this, every CI run starts from an empty BuildKit cache and the mount's benefit is
limited to local development loops — worth wiring explicitly, not assuming cache mounts alone
solve CI build time.

---

## Security Scanning Gate

**Tool: Trivy** (open-source, Apache-2.0, no license cost — the frugality-aligned choice per
CLAUDE.md's Budget and Frugality constraint; no paid scanner is added without explicit
approval). Trivy scans a **built image's filesystem** for known-vulnerable OS packages and
embedded dependency files — a different scan surface from `go-makefile`'s `vuln` target.

**These two scans are complementary, not redundant — both run:**

| Scanner | Surface | Where it runs | Already exists? |
|---|---|---|---|
| `govulncheck` (`go-makefile`'s `make vuln` target) | Go source: flags only vulnerabilities in functions actually reachable from the call graph — low false-positive, source-level | `make ci` (every commit, local + CI) | Yes — `go-makefile` |
| `trivy image` | The built container image's filesystem: OS packages and any files present in the final layer, including base-image CVEs `govulncheck` cannot see because it never inspects the OS layer | A new CI pipeline stage, run against the artifact `make docker` produces | No — add this stage |

Wire it as a CI stage that runs **after** `go-makefile`'s `docker` target, against the image
that target just built:

```bash
make docker                                                  # builds $(IMAGE), from go-makefile
trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed "$IMAGE"
```

- `--exit-code 1` fails the CI job on a match — this is a gate, not a report nobody reads.
- `--severity HIGH,CRITICAL` — the blocking threshold; LOW/MEDIUM findings are visible in the
  scan report but do not block a merge, keeping the gate meaningful (a gate that blocks on
  every LOW finding trains reviewers to override it).
- `--ignore-unfixed` — do not fail the build for a CVE with no upstream fix available yet; a
  gate that can never turn green again for a fixable-by-nobody reason gets bypassed
  permanently, which defeats it. Track unfixed CVEs; don't gate on them.

**Base-image drift:** even with zero application-code changes, a distroless or Alpine base
image can accumulate newly-disclosed CVEs over time in its own unchanged layers. Rebuild and
rescan on a schedule (weekly is a reasonable default) independent of any code change, and let a
dependency-update bot (Renovate or Dependabot, both free/open-source) open a PR bumping the
base image's pinned digest when a new patched version is published — the same "pin by digest,
treat a bump as a reviewed PR" discipline this skill already applies to reproducibility.
