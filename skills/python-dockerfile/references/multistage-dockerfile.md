# Multi-Stage Python Dockerfile — Full Reference

Self-contained reference for `python-dockerfile`. Covers the complete `Dockerfile` in both the
`uv` (default) and `pip` variants, the layer-caching order with a before/after comparison, the
deterministic-install rule in full (including pip's hash-enforcing mode), the non-root numeric-UID
rule, the PID-1/`uvicorn`-signal gotcha, the deliberate omission of `HEALTHCHECK`, and the
`.dockerignore` contents. Read this when producing the actual `Dockerfile` for a FastAPI service,
not just when reasoning about the pattern.

---

## The Full Dockerfile — `uv` Variant (Default)

```dockerfile
# syntax=docker/dockerfile:1

# ---- Build stage: resolver + wheel-build toolchain, never shipped ----
FROM python:3.12-slim AS build
ARG VERSION=dev

# uv is copied in from its official published image at a pinned version — no curl|sh,
# no floating install. This is the deps stage's only extra tool.
COPY --from=ghcr.io/astral-sh/uv:0.5.11 /uv /uvx /bin/

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/app/.venv
WORKDIR /app

# Some wheels have no manylinux prebuild and compile from source at install time; the
# toolchain they need lives ONLY in this stage and never reaches the runtime image.
RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

# 1) Dependency layer — lockfile + manifest copied and installed BEFORE app source.
#    --frozen fails the build if uv.lock is stale vs pyproject.toml (no silent re-resolve).
#    --no-install-project installs ONLY dependencies here, so the heavy dependency layer
#    is cached independently of application-code churn.
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv,id=uvcache \
    uv sync --frozen --no-install-project --no-dev

# 2) Source layer — copied only after dependencies are resolved.
COPY ./app ./app

# 3) Install the project itself into the same venv (fast — deps already present).
RUN --mount=type=cache,target=/root/.cache/uv,id=uvcache \
    uv sync --frozen --no-dev

# ---- Runtime stage: interpreter + venv + source only ----
FROM python:3.12-slim
WORKDIR /app

# Copy the fully-built virtualenv and the application source from the build stage.
# Nothing else — no uv, no build-essential, no apt caches — crosses this boundary.
COPY --from=build /app/.venv /app/.venv
COPY --from=build /app/app /app/app

# Put the venv's bin first so `uvicorn` and the interpreter resolve to it.
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

EXPOSE 8080

# Numeric non-root UID — resolves regardless of the base's /etc/passwd contents.
USER 65532:65532

# Exec form — uvicorn itself becomes PID 1 and receives SIGTERM directly. See
# "PID 1 and Signal Forwarding" below; a shell-form ENTRYPOINT is an availability defect.
ENTRYPOINT ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

---

## The Full Dockerfile — `pip` Variant (Fallback)

Used when a product has not adopted `uv`. Determinism comes from a **compiled, hash-pinned**
`requirements.txt` produced by `pip-compile` (from `pip-tools`) and committed to the repo:

```bash
# Run once (and whenever a top-level dependency changes); commit the output.
pip-compile --generate-hashes --output-file=requirements.txt pyproject.toml
```

```dockerfile
# syntax=docker/dockerfile:1

# ---- Build stage ----
FROM python:3.12-slim AS build
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

# Build a self-contained venv exactly as the uv variant does, so the runtime copy is identical.
RUN python -m venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

# 1) Dependency layer FIRST. --require-hashes makes pip refuse to install any package
#    whose downloaded artifact does not match a hash pinned in requirements.txt — a
#    tampered or drifted wheel fails the build instead of silently installing. It also
#    forces EVERY requirement to be hash-pinned, so an unpinned line is a build error too.
#    --no-deps is implied safe here because pip-compile already flattened the full graph.
COPY requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip,id=pipcache \
    pip install --require-hashes --no-cache-dir -r requirements.txt

# 2) Source layer.
COPY ./app ./app

# ---- Runtime stage ----
FROM python:3.12-slim
WORKDIR /app
COPY --from=build /app/.venv /app/.venv
COPY --from=build /app/app /app/app
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1
EXPOSE 8080
USER 65532:65532
ENTRYPOINT ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

The `--require-hashes` flag is the pip world's equivalent of `uv sync --frozen`: it converts the
committed lockfile from documentation into an enforced invariant. Without it, a compromised or
yanked-and-republished wheel on the index installs silently.

---

## Layer-Caching Order — Before and After

**Wrong** — a single `COPY . .` before the install busts the dependency layer on every source
edit, however small:

```dockerfile
FROM python:3.12-slim AS build
WORKDIR /app
COPY . .                                     # any file change invalidates everything below
RUN uv sync --frozen                         # re-resolves + re-downloads every wheel every build
```

**Right** — lockfile + manifest copied and installed first; only a lock change invalidates that
layer:

```dockerfile
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv uv sync --frozen --no-install-project
COPY ./app ./app                             # only this layer changes on a code edit
```

Docker's layer cache keys each `RUN`/`COPY` on the hash of its inputs (the prior layer plus the
copied files' contents). Reordering so the rarely-changing input (`uv.lock` /
`requirements.txt`) comes first and the frequently-changing input (application source) comes
last is the entire mechanism — no special Docker feature is required, only instruction order.
The `--mount=type=cache` on the resolver cache is a *second*, independent speedup: it persists
the wheel cache **outside the image entirely** (never shipped, never counted in size) so even
when the lock *does* change, only the newly-added wheels are downloaded, not the whole set.

---

## Deterministic Install — Full Explanation

Python, unlike Go, has no single static binary whose bytes are reproducible from source alone.
The deployed artifact is the interpreter plus an installed dependency tree, and that tree is only
reproducible if the resolver is pinned. Two enforced mechanisms, one per tool:

- **`uv sync --frozen`** — installs exactly the versions in the committed `uv.lock`. `--frozen`
  makes uv error out if `uv.lock` is out of date relative to `pyproject.toml`, rather than
  re-resolving to newer versions at build time. Pair with `--no-dev` so test/lint-only
  dependencies (`pytest`, `ruff`, `mypy`) never enter the production image.
- **`pip install --require-hashes -r requirements.txt`** — installs only artifacts whose hashes
  match the pinned values `pip-compile --generate-hashes` wrote. Any hash mismatch, or any
  requirement left un-pinned, is a hard build failure.

Both turn the lockfile from advisory into load-bearing. This is the honest packaging-maturity gap
versus Go's `go.sum`-checked module graph: Python's landscape (`pip`/`pipenv`/`poetry`/`conda`)
is more fragmented, so the skill picks one enforced default (`uv`) and one enforced fallback
(`pip` + hashes) rather than leaving install determinism to chance.

---

## Non-Root Numeric UID — Full Explanation

`USER` names a **numeric UID** (`USER 65532:65532`), not a username, for portability across
whichever runtime base is in use:

- A **`python:3.12-slim`** base *does* ship `/etc/passwd`, so — unlike Go on `scratch`, where a
  named user simply cannot resolve — you *could* `RUN useradd` and reference the name. The
  numeric form is still preferred: it matches the `securityContext.runAsUser: 65532`
  `kubernetes-manifest` applies and the platform allowlist in `dockerfile-patterns`, and it keeps
  the image identical if the base later swaps to distroless.
- **`gcr.io/distroless/python3-debian12:nonroot`** pre-provisions uid/gid `65532:65532`, so
  `USER 65532:65532` (or `USER nonroot`) resolves there without any `useradd`.
- **File readability matters here in a way it does not for a single Go binary.** The runtime
  process reads the whole venv (`/app/.venv`) and the source tree at import time. Ensure both are
  world-readable (the default when `COPY`'d) or owned by `65532` — a venv copied with root-only
  permissions makes the non-root process fail at import, not at `USER` switch. If you need to fix
  ownership, `COPY --chown=65532:65532 --from=build /app/.venv /app/.venv`.
- **Never rely on the Kubernetes `runAsNonRoot` override alone.** The image should refuse root
  even under a bare `docker run` or a CI test container — defense in depth, the platform setting
  being a second independent enforcement, not a substitute.

---

## PID 1 and Signal Forwarding — Full Explanation

The process a container's `ENTRYPOINT` starts becomes **PID 1** in that container's PID
namespace. PID 1 has special kernel semantics: it does not get the default signal disposition, so
a PID-1 process with no registered handler for a signal simply **ignores** it.

```dockerfile
# Shell form — WRONG for a signal-sensitive service.
# /bin/sh -c "uvicorn ..." runs sh as PID 1; uvicorn is sh's CHILD. sh does not forward
# SIGTERM to children, so Kubernetes' pod-termination signal is ignored until
# terminationGracePeriodSeconds expires and Kubernetes escalates to SIGKILL — every deploy,
# every rolling update, every eviction hard-kills instead of draining in-flight requests.
ENTRYPOINT uvicorn app.main:app --host 0.0.0.0 --port 8080

# Exec form — CORRECT.
# uvicorn itself is PID 1 and receives SIGTERM directly.
ENTRYPOINT ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

**What happens after the signal arrives is where Python differs from Go.** Go's
`go-service-skeleton` explicitly installs `signal.NotifyContext(context.Background(),
os.Interrupt, syscall.SIGTERM)` to catch the signal. In Python you write **no such handler** —
`uvicorn` already installs its own `SIGTERM`/`SIGINT` handlers and runs the ASGI lifespan
shutdown: it stops accepting new connections, lets in-flight requests finish (up to its timeout),
then runs FastAPI's `lifespan` teardown, which closes the `asyncpg` pool and the Kafka consumer
in reverse startup order (`python-service-skeleton`'s domain). Exec form is precisely what lets
`uvicorn` receive the signal it already knows how to handle — the container-side half of that
shutdown contract.

**One `uvicorn` per PID 1.** Do not run `gunicorn -k uvicorn.workers.UvicornWorker -w N` as PID 1
and assume clean signal semantics: gunicorn's master forwards signals to workers, but the
per-container init/reaping story gets subtle, and this platform scales horizontally with
Kubernetes replicas, not with in-container worker processes. Run a single `uvicorn`; let the
Deployment's `replicas` provide parallelism. A service that genuinely forks child subprocesses
would need `tini`/`dumb-init` for zombie reaping — a single `uvicorn` process does not, so do not
add one.

---

## Why No `HEALTHCHECK` Instruction

This platform deliberately ships images **without** a Dockerfile `HEALTHCHECK`. Liveness and
readiness are Kubernetes probes defined in the Deployment (`kubernetes-manifest`), not baked into
the image — a single source of truth for health, owned by the platform layer, tunable without
rebuilding the image. A baked `HEALTHCHECK` would run redundantly (and on a different schedule)
alongside the kubelet's probes, and is invisible to Kubernetes' scheduling decisions anyway. This
matches `dockerfile-patterns`' cross-service standard; it is an intentional omission, not an
oversight.

---

## `.dockerignore`

Keeps the build context small and prevents anything sensitive or irrelevant from being uploaded
to the Docker daemon (and thus from being copiable into a layer by accident):

```
.git
.github
*.md
docs/
.venv/
__pycache__/
**/*.pyc
.pytest_cache/
.mypy_cache/
.ruff_cache/
.coverage
htmlcov/
*.env
*.env.*
.envrc
tests/
tmp/
dist/
build/
```

`.venv/` is excluded so a **host-built** virtualenv can never leak into the build context — the
venv must be built inside the `build` stage against the image's own platform, never copied from
the developer's machine (host wheels may be the wrong OS/arch). `tests/`, `__pycache__/`, and the
tool caches are excluded because they are run by `pytest`/`ruff`/`mypy` (`python-tooling`), never
by the container build, and have no reason to cross into the Docker daemon's context.

---

## Anti-Patterns

- **Single-stage `pip install`** — ships `build-essential`, the resolver, and caches; multiplies size and attack surface.
- **`FROM python:3.12` (full) in production** — ~1GB where slim gets the same runtime in ~120–200MB.
- **Unpinned / un-hashed install** — a build that resolves differently tomorrow than today; the lockfile exists precisely to prevent this.
- **`COPY . .` before installing dependencies** — every source edit re-resolves and re-downloads every wheel.
- **Shell-form `ENTRYPOINT`** — `sh` becomes PID 1; `uvicorn` never receives `SIGTERM`; every deploy hard-kills instead of draining.
- **`gunicorn`-with-workers as PID 1 expecting clean signals** — either run one `uvicorn`, or add an init; do not assume multi-worker + single-PID signal correctness for free.
- **A `HEALTHCHECK` instruction in the image** — this platform deliberately omits it; liveness and readiness are Kubernetes probes (`kubernetes-manifest`), not baked into the image (`dockerfile-patterns`).
- **Copying a `.venv` built on the host** — a host venv may hold wrong-platform wheels; always build the venv inside the `build` stage.
