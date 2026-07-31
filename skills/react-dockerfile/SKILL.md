---
name: react-dockerfile
description: >
  Teaches how to containerise this repo's Vite/React micro-frontend shell
  and every remote — one Dockerfile per app (react-project-structure),
  identical shape across all of them: a Node builder stage running
  npm ci && npm run build, and a minimal nginx-unprivileged (or
  static-web-server) final stage serving only the built /dist bundle,
  never the Node toolchain, node_modules, or source. Covers the
  build-time-vs-runtime environment-variable problem specific to Vite
  (import.meta.env.VITE_* is baked into the bundle at build time, breaking
  "build once, promote the same artifact") and its fix, a
  window.__APP_CONFIG__ runtime-injected config.js populated by an
  entrypoint script at container start; image-size optimisation
  (node_modules never reaching the final stage, gzip/brotli compression);
  cross-origin CORS headers a remote's remoteEntry.js needs that a
  standalone SPA does not; and non-root hardening plus vulnerability
  scanning consistent with go-dockerfile's standard. Produces the
  deployable frontend image(s). Used by frontend-engineer during
  Implement; deployment manifests are platform-engineer's domain.
version: 2.0.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, docker, multi-stage, nginx, vite, microfrontend, security, static]
related: [go-dockerfile, react-project-structure, microfrontend-architecture, react-api-client, secrets-management, security-architecture]
---

# React Dockerfile

## Purpose

A Vite/React app builds to static assets — there is no Node server at
runtime. Per `react-project-structure`'s Output Format, **every app gets
its own Dockerfile**: `apps/shell/Dockerfile` and one
`apps/<fragment>/Dockerfile` per remote, identical in shape. This is not
duplication — it's what `microfrontend-architecture`'s independent
deployability requires: each app builds, scans, and ships on its own
schedule, with no other app's toolchain in its image.

This skill produces that image. The CDN/ingress, TLS, and Kubernetes
manifests are `platform-engineer`'s domain; this image is built to drop
cleanly into them.

---

## Multi-Stage Build

A Node builder stage runs the full toolchain (`npm ci && npm run build`);
a minimal final stage — `nginxinc/nginx-unprivileged` by default, or
`static-web-server` where an even smaller image matters more than nginx's
familiarity — serves **only** `/dist`. The builder, `node_modules`, and
the source tree never reach the final stage. This is the identical
underlying principle `go-dockerfile` applies to a Go binary (toolchain
stage discarded, minimal non-root final stage) applied to a static-asset
build instead of a compiled binary — the shape differs, the discipline
does not. Full Dockerfile for both the shell and a remote (which needs
one additional serving rule — see CORS below):
`references/multi-stage-build-standard.md`.

| Choice | Why |
|---|---|
| `npm ci` (not `install`) | Reproducible install from the lockfile — same discipline as `go mod download` |
| Two stages | Node, `node_modules`, and source never reach production |
| `nginx-unprivileged` | Serves static files; **non-root by default** (uid 101) |
| Lockfile layer before source | Dependency layer reused when only source changes |

---

## Build-Time vs. Runtime Environment Variables

Vite bakes every `import.meta.env.VITE_*` value into the built JS bundle
**at `npm run build` time** — a `.env` file's values become literal
strings in the shipped files. This means the same built artifact cannot
move from staging to production with a different API URL without a
rebuild, which breaks the build-once-promote-the-same-artifact principle
every other image in this plugin follows (`go-dockerfile`'s own image is
built once and promoted by digest, never rebuilt per environment).

The fix is **never** a rebuild per environment. It is a runtime-injected
`config.js` — an entrypoint script that runs at container **start**,
reads the real environment variables the platform sets, and writes
`window.__APP_CONFIG__` before the app needs it. The bundle references
`window.__APP_CONFIG__` at call sites, never `import.meta.env` for
anything that varies post-build. `microfrontend-architecture`'s dynamic
remote loading reuses this exact principle one layer up — resolving
which remote URL to mount per tenant from a runtime-fetched manifest
rather than a build-time `remotes` map. Full entrypoint script, the
generated `config.js` shape, and what may/may not go in it:
`references/runtime-config-injection.md`.

---

## Image Size and Serving Optimisation

The builder stage's `node_modules` is routinely hundreds of MB; none of
it belongs in the final image — only `/dist`'s output does. At the
serving layer, compression is not optional: nginx's own `gzip on` (or a
brotli module) for text assets, or pre-compressed `.br`/`.gz` files
served directly where the build pipeline already produces them. Caching
is the other half of serving correctly: content-hashed assets under
`/assets/` are immutable and cached forever; `index.html` is never
cached, so a new deploy is visible immediately instead of resolving to
chunk hashes that no longer exist. Full nginx config, the immutable/
no-cache split, and the SPA `try_files` fallback:
`references/multi-stage-build-standard.md`.

A remote's `remoteEntry.js` and exposed chunks are fetched **cross-origin**
by the shell (and by any other consumer) — something a standalone SPA
never needs. The remote's nginx config must set
`Access-Control-Allow-Origin` on those paths, or the shell's federation
runtime fails to load the remote in production despite working in local
dev (same-origin during `vite dev`). Full CORS rule:
`references/multi-stage-build-standard.md`.

---

## Non-Root, Hardening, and Vulnerability Scanning

Consistent with `go-dockerfile`'s standard, adapted to a static-asset
image: `nginx-unprivileged` already runs as a non-root uid (101) and is
compatible with a `readOnlyRootFilesystem` pod SecurityContext (nginx
writes only to a mounted tmp — the platform-engineer wires this).
Base images are pinned by tag/digest; the image is **Cosign-signed** in
CI and **Trivy-scanned** with no HIGH/CRITICAL CVEs shipping — the exact
CI gate `go-dockerfile` runs on the backend image, applied identically
here. The frontend bundle is downloaded by every browser, so it is fully
public: no API keys or tokens belong in the build or the image — there is
no such thing as a "frontend secret" (`secrets-management`). Full CSP,
security-header block, and the no-secrets rule in detail:
`references/image-size-and-security-standard.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Multi-stage | Node, `node_modules`, source stay in the builder stage | Any of them shipped in the final image |
| One Dockerfile per app | Shell and every remote each build/scan/ship independently | A shared image built once for multiple apps |
| Non-root | `nginx-unprivileged` (uid 101); FS-write-minimal | Root nginx; writable root filesystem |
| Runtime config | `window.__APP_CONFIG__` injected at container start; build once, deploy many | Any per-environment value rebaked via `import.meta.env` per environment |
| No secrets in bundle | Only public config (URLs, flags) in the built JS or `config.js` | An API key, token, or credential anywhere in the build |
| Compression | gzip/brotli active for text assets at the serving layer | Uncompressed JS/CSS served to every client |
| Cache strategy | Immutable hashed `/assets/`; no-cache `index.html` | Cached `index.html` (stale deploys) or uncached hashed assets |
| SPA fallback | `try_files … /index.html` | Deep-link route refresh 404s |
| CORS on remotes | `Access-Control-Allow-Origin` set for `remoteEntry.js` and exposed chunks | Shell fails to load a remote in production only |
| Pinned & signed | Base pinned by digest; image Cosign-signed; Trivy-clean | Floating `latest` tag; unsigned; unscanned |

---

## Anti-Patterns

- **`npm run dev` in a container as "production"** — ships the full Vite dev server and toolchain, disables optimisations, and is not hardened.
- **Single-stage image** — Node, `node_modules`, and source shipped alongside three folders of static output: hundreds of MB of unnecessary attack surface.
- **Rebuilding per environment to change `VITE_API_URL`** — one image per environment breaks build-once-promote-the-same-artifact; inject `window.__APP_CONFIG__` at container start instead.
- **A shared image for the shell and every remote** — defeats the independent-deployability guarantee `microfrontend-architecture` requires; each app ships its own image on its own schedule.
- **No CORS header on a remote's `remoteEntry.js`** — works in local dev (same-origin), then fails silently in production the moment the shell fetches it cross-origin.
- **Caching `index.html`** — the one file that must always be fresh; a cached copy references chunk hashes a new deploy has already removed.
- **A "frontend secret"** — any credential in the bundle, the `config.js`, or the image is published to every browser; there is no such thing.
- **Unpinned or unscanned base image** — the same failure `go-dockerfile` names for the backend image, on the frontend side.

---

## Output Format

Produces the image build and serving configuration, once per app:

```
apps/<app>/Dockerfile
apps/<app>/nginx.conf                      (caching, compression, SPA fallback, CORS for remotes)
apps/<app>/docker-entrypoint.d/40-env.sh    (runtime window.__APP_CONFIG__ injection)
apps/<app>/.dockerignore
```
