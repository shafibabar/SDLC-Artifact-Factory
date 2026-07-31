# Local Workflow, Image Size, and Security — Full Reference

Self-contained reference for `python-dockerfile`. Covers the `kind load docker-image` local
Kubernetes loop (and the `imagePullPolicy` gotcha that trips it), concrete image-size numbers
that make "minimal" checkable, the honest CPython-vs-slim-vs-distroless size tradeoff, base-image
digest pinning, and the two complementary vulnerability scans (`trivy image` + `pip-audit`). Read
this when wiring the local dev loop or the CI scan stage, not just when reasoning about the
pattern in the abstract.

---

## `kind load docker-image` — Local Kubernetes Loop

For a local development loop against a Kubernetes cluster, use `kind` (Kubernetes IN Docker,
open-source — the frugal choice, no cloud registry cost). The key move is that a locally-built
image can be loaded **directly onto the kind node's container runtime** with no registry push,
pull, or credentials in the loop at all:

```bash
# 1) Build the image locally with a concrete, non-latest tag.
docker build -t dataasset-api:dev .

# 2) Load it straight into the kind cluster's node(s). This copies the image into the
#    node's containerd image store — NO registry involved.
kind load docker-image dataasset-api:dev --name dataasset-local

# 3) Reference that exact tag in the Deployment and roll it out.
kubectl set image deployment/dataasset-api api=dataasset-api:dev
kubectl rollout restart deployment/dataasset-api
```

**The `imagePullPolicy` gotcha — this is the step most people miss.** If the Deployment's
container uses `imagePullPolicy: Always`, the kubelet ignores the image you just loaded onto the
node and tries to pull `dataasset-api:dev` from a registry — which either fails (no such
registry) or, worse, pulls a stale remote image of the same tag. Kubernetes also defaults an
image tagged `:latest` to `Always`. So for the kind loop:

- Tag with a concrete label (`:dev`), never `:latest`, so the default policy is `IfNotPresent`.
- Set `imagePullPolicy: IfNotPresent` (or `Never`) explicitly on the container in the local
  overlay, so the kubelet uses the loaded node image instead of reaching for a registry.

```yaml
# local overlay only — production uses a digest-pinned image from the registry
containers:
  - name: api
    image: dataasset-api:dev
    imagePullPolicy: IfNotPresent
```

This gives a full build → load → rollout loop against a real Kubernetes cluster with zero
registry round-trips — fast, offline-capable, and free. Multi-node kind clusters load the image
onto every node automatically; verify with `docker exec <node> crictl images | grep dataasset`.

---

## Image Size — Concrete Numbers

Exact bytes vary by Python version, the dependency graph, and platform, but the order of
magnitude is stable and worth stating so "minimal" is a checkable target, not a vibe:

| Image | Approximate size | Contents |
|---|---|---|
| `python:3.12` (naive single-stage, full Debian) | ~1.0–1.1GB | Full Debian userland, build toolchain, headers, the interpreter, plus app + deps |
| `python:3.12-slim` (base, before venv) | ~45–55MB | Trimmed Debian + CPython interpreter; no compilers, no headers |
| `python:3.12-slim` + a typical FastAPI/`asyncpg` venv | ~120–200MB | slim base + interpreter + `site-packages` (FastAPI, Starlette, Pydantic, uvicorn, asyncpg, ...) |
| `gcr.io/distroless/python3-debian12:nonroot` (base, before venv) | ~50MB | CPython + CA certs + `nonroot` user; **no shell, no apt, no pip** |
| distroless-python + the same venv | ~105–180MB | ~15–25MB smaller than slim — the shell/apt/coreutils are gone |

**The honest CPython-vs-Go tradeoff.** Go's `-ldflags="-s -w"` strips a binary's symbol tables to
shed 20–30%, and the whole program is one static file that drops onto `scratch` for a ~15–40MB
image. **None of that applies to Python.** There is no symbol-stripping step for an interpreted
program: the shipped artifact is CPython plus the *source* (and optionally pre-compiled `.pyc`) of
every dependency in `site-packages`. So the realistic floor for a Python FastAPI image is
**~100–200MB**, an order of magnitude larger than the Go floor, and no Dockerfile trick closes
that gap — it is intrinsic to shipping an interpreter and a dependency tree rather than a static
binary. What the Dockerfile *can* do is the 3–5x reduction from full `python:3.12` (~1GB) down to
slim/distroless (~100–200MB), which is exactly what the multi-stage build achieves. Set
`UV_COMPILE_BYTECODE=1` (or leave `PYTHONDONTWRITEBYTECODE` unset in the venv) so `.pyc` files are
generated at build time rather than lazily on the first request — this trades a small image-size
increase for a faster cold start, usually the right call for a request-serving service.

**`slim` vs. distroless-python — which default:** prefer `python:3.12-slim` for its shell and
`apt` (you can `kubectl exec` in and debug, and some observability sidecars expect a shell).
Reach for `gcr.io/distroless/python3-debian12` when the threat model wants no shell and no package
manager in the running container — remember it has **no `pip`**, so the multi-stage "build the
venv in slim, copy it into distroless" pattern is mandatory there, not optional.

---

## Base-Image Digest Pinning

Pin the base by **both** tag and digest so a build cannot be silently changed by an upstream
re-tag of the same version string:

```dockerfile
FROM python:3.12-slim@sha256:1e8...redacted...9af AS build
# ...
FROM python:3.12-slim@sha256:1e8...redacted...9af
```

Resolve the current digest with `docker buildx imagetools inspect python:3.12-slim`. Treat a
digest bump as a reviewed PR — let a dependency-update bot (Renovate or Dependabot, both
free/open-source) open it when a new patched `python:3.12-slim` is published. This is the same
"pin by digest, treat a bump as a reviewed change" discipline the lockfile applies to application
dependencies, extended to the base image.

---

## Security Scanning — Two Complementary Gates

Two open-source scanners cover two different surfaces; **both run, neither replaces the other**
(frugality-aligned per CLAUDE.md — no paid scanner without explicit approval):

| Scanner | Surface | Where it runs | Owned by |
|---|---|---|---|
| `pip-audit` | The **declared Python dependency graph** — flags known-vulnerable packages by version against the PyPI advisory / OSV databases; source-level, like Go's `govulncheck` | `make`/`uv run` audit target, every commit (local + CI) | `python-tooling` |
| `trivy image` | The **built image's filesystem** — OS packages in the slim/distroless base **plus** the installed `site-packages` in the venv, including base-image CVEs `pip-audit` cannot see because it never inspects the Debian layer | A CI stage, run against the artifact the build just produced | this skill (add the stage) |

`pip-audit` sees a vulnerable `cryptography` version pinned in `uv.lock`; Trivy additionally sees
a CVE in the slim base's `libssl` that no Python tool inspects. Wire Trivy as a gate after the
image is built:

```bash
docker build -t "$IMAGE" .
trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed "$IMAGE"
```

- `--exit-code 1` fails the CI job on a match — a gate, not a report nobody reads.
- `--severity HIGH,CRITICAL` — the blocking threshold; LOW/MEDIUM findings appear in the report
  but do not block a merge, keeping the gate meaningful (a gate that blocks on every LOW finding
  trains reviewers to override it).
- `--ignore-unfixed` — do not fail on a CVE with no upstream fix yet; a gate that can never turn
  green again gets bypassed permanently, defeating it. Track unfixed CVEs; do not gate on them.

**Base-image drift:** even with zero application-code changes, a slim/distroless base accumulates
newly-disclosed CVEs in its own unchanged layers. Rebuild and rescan on a schedule (weekly is a
reasonable default) independent of any code change, and let the dependency-update bot open the
digest-bump PR when a patched base is published — the same discipline the digest pin already
establishes.

---

## Putting It Together — The Local Inner Loop

```bash
# Rebuild, load into kind, roll out, tail logs — the full local iteration.
docker build -t dataasset-api:dev .
kind load docker-image dataasset-api:dev --name dataasset-local
kubectl rollout restart deployment/dataasset-api
kubectl rollout status deployment/dataasset-api
kubectl logs -f deployment/dataasset-api
```

No registry, no credentials, no cloud cost — a complete FastAPI-on-Kubernetes dev loop that runs
entirely on the developer's machine, with the exact same image shape (multi-stage, slim,
non-root, lockfile-installed) that ships to production.
