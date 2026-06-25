---
name: react-dockerfile
description: >
  Teaches how to containerise a React + TypeScript app for production — a multi-stage
  build (Node build stage → minimal static-serving runtime), serving the built
  static assets with correct caching and compression, runtime environment injection
  without rebuilding, non-root hardening, the Content-Security-Policy and security
  headers, and keeping secrets out of the bundle. Produces the deployable frontend
  image. Used by the frontend-engineer during Implement; deployment is the
  platform-engineer's domain.
version: 1.0.0
phase: implement
owner: frontend-engineer
tags: [implement, frontend, react, docker, multi-stage, nginx, csp, static, security]
---

# React Dockerfile

## Purpose

A React app builds to static assets (HTML, JS, CSS) — there is no Node server at runtime unless SSR is used. The production image should build the bundle with the full toolchain, then ship **only** the static output behind a tiny, hardened static server. The result is small, fast, non-root, and secret-free.

This skill produces the image. The CDN/ingress, TLS, and deployment manifests are the platform-engineer's domain — this image is built to drop cleanly into them.

---

## Multi-Stage Build

Stage 1 builds with Node; stage 2 serves the static output with nginx-unprivileged (or Caddy). The Node toolchain never ships to production.

```dockerfile
# syntax=docker/dockerfile:1

# ---- Build stage ----
FROM node:22-bookworm-slim AS build
WORKDIR /app

# Cache deps separately from source: lockfile layer reused unless deps change.
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci

COPY . .
RUN npm run gen:api          # generate API types from the OpenAPI contract (react-api-client)
RUN npm run build            # tsc + vite build → /app/dist (static assets)

# ---- Runtime stage ----
FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime
# nginx-unprivileged already runs as a non-root user (uid 101).
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY docker-entrypoint.d/ /docker-entrypoint.d/   # runtime env injection (below)
EXPOSE 8080
```

| Choice | Why |
|---|---|
| `npm ci` (not `install`) | Reproducible install from the lockfile |
| Build-cache mount | Fast incremental CI builds |
| `nginx-unprivileged` | Serves static files; runs **non-root** by default |
| Two stages | Node + node_modules never reach production |
| Lockfile layer first | Dependency layer reused when only source changes |

---

## Serving: Caching, Compression, SPA Fallback

The nginx config gets three things right that matter for a SPA:

```nginx
server {
  listen 8080;
  root /usr/share/nginx/html;

  # Hashed assets are immutable → cache forever.
  location /assets/ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }

  # index.html must NOT be cached → users get new deploys immediately.
  location = /index.html {
    add_header Cache-Control "no-cache";
  }

  # SPA fallback: client-side routes resolve to index.html (see react-routing).
  location / {
    try_files $uri /index.html;
  }

  gzip on;          # (or brotli) — compress text assets
  gzip_types text/css application/javascript application/json image/svg+xml;
}
```

The cache split — **immutable hashed assets, never-cached `index.html`** — is what makes deploys take effect instantly without breaking long-cached chunks.

---

## Runtime Environment Injection (No Rebuild Per Environment)

A static bundle is built once and deployed to many environments (staging, each tenant). Environment-specific values (API base URL, OTLP endpoint) must be injectable **at container start**, not baked at build time — otherwise you rebuild per environment.

```sh
# docker-entrypoint.d/40-env.sh — writes a small runtime config the app reads at boot
cat > /usr/share/nginx/html/config.js <<EOF
window.__APP_CONFIG__ = {
  apiBaseUrl: "${API_BASE_URL}",
  otlpEndpoint: "${OTLP_ENDPOINT}",
  release: "${APP_VERSION}"
};
EOF
```

The app reads `window.__APP_CONFIG__` at startup. **Only non-secret config** goes here (URLs, feature flags) — never secrets; the JWT comes from the auth flow, not the image (see `react-api-client`, `secrets-management`).

---

## Security Headers and CSP

The static server sets the security headers and the Content-Security-Policy. CSP is the frontend's primary defence against XSS — it restricts where scripts, styles, and connections may come from.

```nginx
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self' https://otlp.example.com; frame-ancestors 'none'; base-uri 'self'" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header Referrer-Policy "no-referrer" always;
```

`connect-src` must allow the API origin and the OTLP/RUM endpoint (so `react-observability` can report). This complements the backend's own security headers (`security-implementation`) — both tiers set them; the browser enforces the strictest.

---

## No Secrets in the Bundle

A frontend bundle is downloaded by every user — it is fully public. Therefore:
- **No secrets in the build** — any value in `import.meta.env` baked at build time ships to every browser. Only **public** config belongs there.
- **No API keys, no tokens** in the code or the image — there is no such thing as a "frontend secret."
- Runtime config (above) carries only non-sensitive values.

This is the frontend echo of the backend's secrets rule (`secrets-management`): the only difference is that a frontend "secret" is even more exposed.

---

## Hardening and Provenance

- **Non-root** (nginx-unprivileged, uid 101); compatible with a `readOnlyRootFilesystem` pod SecurityContext (nginx writes only to mounted tmp).
- **Pin** base images by tag/digest; **Cosign-sign** the image; **Trivy-scan** with no HIGH/CRITICAL (CI gate — platform pipeline).
- Sourcemaps are built for production error symbolication (`react-observability`) but served **privately** to the error backend, not exposed publicly.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Multi-stage | Node toolchain stays in the build stage | Shipping node_modules / Node in production |
| Non-root | nginx-unprivileged; FS-write-minimal | Root nginx; writable root FS |
| Cache strategy | Immutable hashed assets; no-cache index.html | Cached index.html (stale deploys) or uncached assets |
| Runtime config | Env injected at start; build once, deploy many | Rebuild per environment; config baked in |
| CSP + headers | Strict CSP and security headers set | No CSP; XSS surface wide open |
| No secrets | Only public config in the bundle/image | API keys/tokens in the build |
| SPA fallback | `try_files … /index.html` | Deep-link refresh 404s |

---

## Output Format

Produces the image build and serving configuration:

```
Dockerfile
nginx.conf                         (caching, compression, SPA fallback, CSP/headers)
docker-entrypoint.d/40-env.sh       (runtime non-secret config injection)
.dockerignore
```
