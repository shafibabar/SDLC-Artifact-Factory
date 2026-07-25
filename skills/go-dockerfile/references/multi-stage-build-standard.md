# Multi-Stage Build Standard — Full Reference

Self-contained reference for `go-dockerfile`. Covers the complete Dockerfile, the layer-caching
order rule with a before/after comparison, the static-binary build in full, the non-root numeric
UID rule, the PID-1/signal-forwarding gotcha, and the `.dockerignore` contents. Read this when
producing the actual `Dockerfile` for a Go service, not just when reasoning about the pattern.

---

## The Full Dockerfile

```dockerfile
# syntax=docker/dockerfile:1

# ---- Build stage: full Go toolchain, never shipped ----
FROM golang:1.23-bookworm AS build
ARG VERSION=dev
WORKDIR /src

# 1) Dependency layer — copied and resolved BEFORE any application source.
#    A cache mount persists the module download across builds and across CI runs
#    that share a BuildKit cache backend (see image-size-and-security-standard.md).
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod,id=gomod go mod download

# 2) Source layer — copied only after the dependency layer is resolved, so an
#    application-code-only change reuses the (expensive) dependency layer untouched.
COPY . .

# 3) Static, stripped, reproducible build. CGO_ENABLED=0 is what makes the binary
#    loadable on a scratch/distroless final stage with no dynamic linker present.
RUN --mount=type=cache,target=/root/.cache/go-build,id=gobuild \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
      -trimpath \
      -ldflags="-s -w -X main.version=${VERSION}" \
      -o /out/server ./cmd/server

# ---- Final stage: only the binary, nothing else ----
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/server /server

# distroless:nonroot pre-provisions uid:gid 65532:65532 (its own /etc/passwd entry
# named "nonroot"); on scratch, or any distroless variant without that entry, use
# the bare numeric form instead — see "Non-Root Numeric UID Rule" below.
USER nonroot:nonroot

EXPOSE 8080

# Exec form — the binary itself becomes PID 1 and receives SIGTERM directly.
# See "PID 1 and Signal Forwarding" below; a shell-form ENTRYPOINT is a
# production-availability defect, not a style choice.
ENTRYPOINT ["/server"]
```

---

## Layer-Caching Order Rule — Before and After

**Wrong** — a single `COPY . .` before dependency resolution busts the dependency layer on
every source-code edit, however small:

```dockerfile
FROM golang:1.23-bookworm AS build
WORKDIR /src
COPY . .                                  # any file change invalidates everything below
RUN go mod download                       # re-runs — re-downloads every module — on every build
RUN CGO_ENABLED=0 go build -o /out/server ./cmd/server
```

**Right** — `go.mod`/`go.sum` copied and resolved first; only a dependency change invalidates
that layer:

```dockerfile
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download   # cached unless go.mod/go.sum change
COPY . .                                                     # only this layer changes on a code edit
RUN CGO_ENABLED=0 go build -o /out/server ./cmd/server
```

Docker's layer cache keys each `RUN`/`COPY` instruction on the hash of its inputs (the prior
layer plus the copied files' contents). Reordering so the rarely-changing input (`go.mod`/
`go.sum`) comes first, and the frequently-changing input (application source) comes last, is the
entire mechanism — no special Docker feature is required, only instruction order.

---

## Static Binary Build — Full Explanation

`CGO_ENABLED=0` disables cgo, which forces the Go compiler to use its own pure-Go
implementations of anything that would otherwise call into libc (notably DNS resolution and
`os/user`) and produces a **statically linked** binary with no dynamic library dependencies.
This is not an optimization — it is a **hard requirement** for a scratch or
`distroless/static` final stage: neither image contains a dynamic linker (`ld-linux.so`) or
`libc.so`, so a `CGO_ENABLED=1` binary built with default settings fails to start at all
(`exec format error` or a missing shared-library error, depending on the failure mode) on
either base. Verify a build is actually static before it ships:

```bash
file /out/server
# ELF 64-bit LSB executable, ... statically linked, ...   <- correct
# ELF 64-bit LSB executable, ... dynamically linked, ...  <- CGO leaked in; fix and rebuild
```

`-trimpath` strips the local build-machine's absolute filesystem paths from the compiled
binary — without it, `/home/ci-runner/build/src/...` leaks into every panic stack trace and
the binary is not byte-for-byte reproducible across two different build hosts. `-ldflags="-s
-w"` strips the DWARF debug-symbol table and symbol table respectively — commonly a
20-30% binary-size reduction — traded deliberately against losing `delve`-debuggability of the
production binary; debug a symbol-complete build in staging, never in the shipped image.
`GOOS=linux GOARCH=amd64` (or `arm64` for an ARM node pool) pins the target platform
explicitly rather than relying on the build host's own OS/arch, which matters the moment CI
runs on a different architecture than the deployment target.

---

## Non-Root Numeric UID Rule — Full Explanation

A container's `USER` instruction must name a **numeric UID**, never a username string, unless
that username is guaranteed to resolve inside the exact final-stage image being built. This is
a correctness requirement, not a preference:

- **`scratch` has no `/etc/passwd` at all.** `USER appuser` fails outright — there is no name
  to resolve. `USER 65532:65532` works because the Linux kernel's `setuid`/`setgid` syscalls
  operate on numeric IDs; a name lookup is only needed by tools that print or resolve
  usernames (`ps`, `whoami`), none of which exist in a minimal final stage anyway.
- **`gcr.io/distroless/static-debian12:nonroot`** ships its own `/etc/passwd` with exactly one
  non-root entry — `nonroot`, uid/gid `65532:65532` — so `USER nonroot:nonroot` resolves
  correctly *in that specific image*. The instant the final-stage image changes (e.g., to
  `gcr.io/distroless/static-debian12` without the `:nonroot` tag, or to `scratch`), that name
  no longer resolves and the build fails or silently falls back to root, depending on the
  Docker version. The numeric form (`USER 65532:65532`) is portable across all of these and
  is the form to prefer whenever the final stage might ever change.
- **Never omit `USER` and rely on a Kubernetes `securityContext.runAsUser` override alone.**
  Defense in depth: the image should refuse to run as root even outside Kubernetes (a local
  `docker run`, a CI integration-test container, a different orchestrator) — the platform-layer
  `runAsNonRoot: true` + `runAsUser: 65532` setting the platform-engineer applies is a second,
  independent enforcement of the same invariant, not a substitute for setting `USER` in the
  image itself.

---

## PID 1 and Signal Forwarding — Full Explanation

The process a container's `ENTRYPOINT`/`CMD` starts becomes **PID 1** inside that container's
PID namespace. PID 1 has different kernel semantics from every other process: it does not get
Linux's default signal disposition, so a process running as PID 1 that has not explicitly
registered a handler for a given signal simply **ignores** that signal rather than being killed
by it in the usual way.

Docker instructions have two forms, and they produce different PID-1 processes:

```dockerfile
# Shell form — WRONG for a signal-sensitive service.
# /bin/sh -c "/server" runs sh as PID 1; /server is sh's CHILD, not PID 1 itself.
# sh does not forward signals to child processes by default. SIGTERM sent by
# Kubernetes at pod termination reaches sh, which ignores it (default PID-1
# behavior), and the container idles until the terminationGracePeriodSeconds
# budget expires and Kubernetes escalates to SIGKILL — every deploy, every
# rolling update, every pod eviction hard-kills instead of draining.
ENTRYPOINT /server

# Exec form — CORRECT.
# /server itself is PID 1 and receives SIGTERM directly. go-service-skeleton's
# signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM) call
# only ever fires if the SIGTERM actually reaches the Go binary's process — this
# is the container-side half of that contract.
ENTRYPOINT ["/server"]
```

On a `scratch` or `distroless/static` final stage there is no `/bin/sh` at all, so the shell
form fails immediately and loudly at container start (`exec: "/bin/sh": stat /bin/sh: no such
file or directory`) rather than silently swallowing signals — a useful fail-fast property of
the minimal base, but exec form is the correct rule regardless of which final-stage image is in
use, including any future final stage that does happen to carry a shell.

A Go service that never spawns child processes of its own does not need a full init system
(`tini`, `dumb-init`) for zombie-process reaping — that concern applies to PID-1 processes that
themselves fork children, which a typical `net/http` server does not. Adding one anyway is
unneeded final-stage weight; do not add it unless the service genuinely forks subprocesses.

---

## `.dockerignore`

Keeps the build context small and prevents anything sensitive or irrelevant from ever being
uploaded to the Docker daemon (and therefore from ever being copiable into a layer by accident):

```
.git
.github
*.md
Makefile
bin/
coverage.out
*.env
*.env.*
.envrc
tmp/
dist/
node_modules/
**/*_test.go
```

Test files are excluded from the build context entirely — they are compiled and run by `make
test` (`go-makefile`), never by the container build, so they have no reason to cross into the
Docker daemon's build context at all.
