---
name: python-dockerfile
description: >
  Teaches the backend-engineer to write a production Python Dockerfile for a
  FastAPI service — a multi-stage build (deps stage with uv or pip, slim
  runtime), non-root user, a minimal/distroless-python base, deterministic
  dependency install from a lockfile, and the kind load docker-image local
  workflow. The Python analog of go-dockerfile (see also dockerfile-patterns).
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, fastapi, docker, multi-stage, uv, slim, distroless, non-root, security, container, image-size, lockfile, kind]
related: [go-dockerfile, dockerfile-patterns, python-service-skeleton]
tools: [Bash]
---

# Python Dockerfile

## Purpose

The container image is the deployable unit. For a FastAPI service it must be as small as the
Python runtime honestly allows, install its dependencies **deterministically from a lockfile**,
run as a non-root user, forward `SIGTERM` to the ASGI server so `uvicorn` can drain in-flight
requests, and carry no build tools, compilers, or secrets. A minimal image is also a minimal
attack surface — the first workload-layer control from `security-architecture`.

This skill produces the production `Dockerfile` and `.dockerignore` for a FastAPI + `asyncpg`
service. Deployment manifests are `kubernetes-manifest`'s domain; the cross-service image
conformance rules this file must satisfy are `dockerfile-patterns`' domain.

**The one honest divergence from `go-dockerfile` that shapes everything below:** Python has **no
static-binary equivalent**. Go ships a single self-contained binary onto `scratch`; a Python
image must ship the CPython interpreter plus every installed dependency (`site-packages`), the
same gap the Node roster names for `node_modules`. So the final base is never `scratch` or
`distroless/static` — it is `python:3.x-slim` or `gcr.io/distroless/python3-debian12`, and the
realistic shipped size is **~80–200MB**, not Go's ~15–40MB. "Minimal" here means slim/distroless,
not full `python:3.x` — a real 3–5x reduction, not two orders of magnitude. Full size tradeoff:
`references/local-and-security.md`.

---

## Multi-Stage Build Standard

Two stages, always: a `build` stage that resolves and installs dependencies into a self-contained
virtualenv (`/app/.venv`), and a final stage that copies **only that venv plus the application
source** onto a slim/distroless runtime. The lockfile resolver, any C-build toolchain
(`build-essential`, needed by some wheels), and package-manager caches never reach the shipped
image. Full annotated Dockerfile, both the `uv` and `pip` variants: `references/multistage-dockerfile.md`.

```dockerfile
FROM python:3.12-slim AS build            # resolver + any wheel-build toolchain — this stage only
# ...(lockfile install into /app/.venv — see Layer-Caching Order below)...
FROM python:3.12-slim                      # runtime stage — interpreter + venv + source only
COPY --from=build /app/.venv /app/.venv
COPY ./app /app/app
ENV PATH="/app/.venv/bin:$PATH"
USER 65532:65532
ENTRYPOINT ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

`python:3.12-slim` (Debian slim, ~45MB base) is the default runtime base; `gcr.io/distroless/
python3-debian12:nonroot` is the hardened alternative (no shell, no package manager — copy the
venv in, it has no `pip`). Prefer `slim` for its debuggability unless the threat model demands
distroless. The comparison is in `references/local-and-security.md`.

---

## Deterministic Lockfile Install Standard

The build is only reproducible if two builds of the same commit install byte-identical
dependency trees. That determinism comes from a **committed lockfile**, not from the resolver's
mood at build time — the Python analog of Go's reproducible static compile.

- **`uv` (default, per `python-tooling`):** commit `uv.lock`; install with `uv sync --frozen`.
  `--frozen` fails the build if `uv.lock` is out of date with `pyproject.toml` instead of
  silently re-resolving — the guarantee that CI installs exactly what was committed.
- **`pip` fallback:** compile a fully-pinned, hash-bearing `requirements.txt` (via `pip-compile`
  from `pip-tools`), commit it, and install it with pip's hash-enforcing mode so a tampered or
  drifted wheel fails the build. Exact flags and the `pip-compile` invocation:
  `references/multistage-dockerfile.md`.

Never install unpinned (`pip install fastapi`) or from an un-hashed `requirements.txt` in a
production image — that is the packaging-maturity gap Python honestly carries versus `go.sum`,
and the lockfile is how this skill closes it.

---

## Layer-Caching Order Standard

Dependency-manifest files (`pyproject.toml` + `uv.lock`, or the compiled `requirements.txt`) are
copied and installed **before** the application source is copied. Docker keys each layer on its
inputs; putting the rarely-changing input (dependencies) ahead of the frequently-changing one
(app code) means a source-only edit reuses the dependency layer untouched instead of
re-resolving and re-downloading every wheel:

```dockerfile
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv uv sync --frozen --no-install-project   # cached unless the lock changes
COPY ./app ./app                                                                      # only this busts on a code edit
```

The `--no-install-project` split (dependencies first, the project itself in a later step) keeps
the heavy dependency layer cacheable independently of source churn; BuildKit `--mount=type=cache`
on the resolver cache persists outside the image entirely. Before/after and the pip-variant
equivalent: `references/multistage-dockerfile.md`.

---

## Non-Root Numeric UID Standard

`USER` is a **numeric UID** (`USER 65532:65532`), portable across whichever runtime base is in
use. Unlike Go on `scratch` (no `/etc/passwd`), a `slim` base *does* have `/etc/passwd` so a named
user could be created — but the numeric form matches `dockerfile-patterns`' platform standard and
the `securityContext.runAsUser: 65532` `kubernetes-manifest` sets, so the image refuses root even
outside Kubernetes. On distroless-python `:nonroot`, `65532:65532` is pre-provisioned. Ensure the
copied venv and app dir are readable by that UID (`COPY --chown=65532:65532` if needed). Full rule:
`references/multistage-dockerfile.md`.

---

## PID 1 and Signal Forwarding (exec-form `ENTRYPOINT`)

`ENTRYPOINT` must use **exec form** (`ENTRYPOINT ["uvicorn", ...]`), never shell form. Shell form
runs `/bin/sh -c "uvicorn ..."`, making `sh` — not `uvicorn` — PID 1; `sh` does not forward
`SIGTERM` to its child, so Kubernetes' termination signal is ignored until
`terminationGracePeriodSeconds` expires and it escalates to `SIGKILL` on every rolling deploy.

**Honest Python/Go difference in what happens once the signal *does* arrive:** Go's
`go-service-skeleton` hand-rolls `signal.NotifyContext(...)` to catch `SIGTERM`. In Python you do
**not** write that handler — `uvicorn` installs its own `SIGTERM`/`SIGINT` handler and drives
graceful shutdown, which triggers FastAPI's `lifespan` teardown (closing the `asyncpg` pool and
Kafka consumer in reverse order — `python-service-skeleton`'s domain). Exec form is what lets
`uvicorn` receive the signal it already knows how to handle; it is the container-side half of that
skill's shutdown contract. Run **one** `uvicorn` process as PID 1 — do not wrap it in `gunicorn`
with multiple workers and expect single-PID signal semantics without an init; scale with replicas,
not in-container workers. Full explanation: `references/multistage-dockerfile.md`.

---

## Image-Size and Local Workflow

`python:3.12` (full) runs **~1GB**; `python:3.12-slim` + venv for a typical FastAPI service runs
**~120–200MB**; distroless-python trims another ~15–25MB. The concrete numbers table and the
CPython-can't-be-stripped-like-a-Go-binary explanation are in `references/local-and-security.md`.
Set `UV_COMPILE_BYTECODE=1` (pre-compile `.pyc` at build) and `--mount=type=cache` on the resolver
cache. For a local Kubernetes loop, load the built image straight into a `kind` node — **no
registry push needed**; the exact `kind load docker-image` workflow (and the `imagePullPolicy`
gotcha that makes the node actually use the loaded image) is in `references/local-and-security.md`.

---

## Security Scanning Gate

Two complementary open-source scans, both run, neither replaces the other (frugality-aligned — no
paid scanner without approval):

- **`pip-audit`** (`python-tooling`'s target) scans the **declared Python dependency graph** for
  known-vulnerable packages — source-level, like Go's `govulncheck`.
- **Trivy** scans the **built image's filesystem** — OS packages in the slim base plus the
  installed `site-packages` — a surface `pip-audit` never sees (it does not inspect the Debian
  layer).

```bash
trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed "$IMAGE"
```

`--exit-code 1` makes it a merge-blocking gate. Pin the base by digest (`@sha256:...`), rebuild
and rescan weekly for base-image CVE drift. Full rationale and the digest-pin workflow:
`references/local-and-security.md`.

---

## No Secrets in Layers

Layers are append-only and individually extractable, so a secret `COPY`'d in and `rm`'d later is
still recoverable. Never `COPY` a secret and never pass one via `ENV`/`ARG` (it leaks into
`docker history`); a build-time credential uses a BuildKit secret mount, which never persists. The
mount syntax and rationale (aligned with `secrets-management`): `references/local-and-security.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Multi-stage | Resolver/toolchain confined to `build`; only venv + source ship | `pip install` in a single stage with build tools shipped |
| Minimal base | `python:3.x-slim` or distroless-python; ~80–200MB | Full `python:3.x` (~1GB) in production |
| Deterministic install | `uv sync --frozen` or hash-pinned compiled `requirements.txt` | `pip install fastapi` / unpinned or un-hashed requirements |
| Layer-caching order | Lock/manifest installed before `COPY ./app` | Single `COPY . .` busting the dependency layer every build |
| Resolver cache mount | `--mount=type=cache` on the uv/pip cache | Every build re-downloads every wheel |
| Non-root numeric UID | `USER 65532:65532`; venv/app readable by it | Runs as root, or a UID that can't read the venv |
| Exec-form `ENTRYPOINT` | `ENTRYPOINT ["uvicorn", ...]` — uvicorn is PID 1 | Shell-form entrypoint swallows `SIGTERM` |
| Single PID-1 server | One `uvicorn` process; scale via replicas | `gunicorn` multi-worker without init + broken signals |
| No secrets in layers | BuildKit secret mounts only | Tokens in `ENV`/`ARG` or copied files |
| Scanned & pinned | `trivy image` + `pip-audit` clean; base pinned by digest | Unscanned image; floating `latest` base |

---

## Anti-Patterns

The full anti-pattern list with rationale (single-stage installs, full base in production,
unpinned installs, `COPY . .` before deps, shell-form `ENTRYPOINT`, `gunicorn`-as-PID-1, baked-in
`HEALTHCHECK`, host-built `.venv`): `references/multistage-dockerfile.md`.

---

## Output Format

**`Dockerfile`** — a `build` stage (pinned `python:3.x-slim`) that installs deps from the lockfile
**before** copying source, then a final pinned slim/distroless stage that `COPY --from=build`s the
venv, prepends it to `PATH`, sets a numeric-UID `USER`, and runs an exec-form `uvicorn`
`ENTRYPOINT`. Full listing (uv and pip variants): `references/multistage-dockerfile.md`.

**`.dockerignore`** — excludes VCS, docs, `.venv`, Python caches, env files, and `tests/`; full
listing in `references/multistage-dockerfile.md`.
