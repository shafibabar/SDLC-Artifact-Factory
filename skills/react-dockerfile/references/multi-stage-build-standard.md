# Multi-Stage Build Standard: Shell and Remote Dockerfiles

Full Dockerfile and nginx configuration for a Vite/React app in this
plugin's micro-frontend architecture. Self-contained — loadable without
the parent `SKILL.md` body already in context. Per
`react-project-structure`'s Output Format, every app (`apps/shell/` and
each `apps/<fragment>/`) gets its own copy of this Dockerfile — identical
in shape, with one additional serving rule for a remote (CORS, below).

---

## The Dockerfile

```dockerfile
# syntax=docker/dockerfile:1

# ---- Build stage ----
FROM node:20-alpine AS build
WORKDIR /app

# Cache deps separately from source: the lockfile layer is reused
# across builds unless a dependency actually changed.
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci

COPY . .
RUN npm run build            # tsc + vite build → /app/dist (static assets only)

# ---- Runtime stage ----
FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime
# nginx-unprivileged already runs as a non-root user (uid 101) by default.
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY docker-entrypoint.d/ /docker-entrypoint.d/   # runtime env injection — see runtime-config-injection.md
EXPOSE 8080
```

| Choice | Why |
|---|---|
| `node:20-alpine` builder | Small builder base; only used to produce `/dist` — its size doesn't ship |
| `npm ci` (not `install`) | Reproducible install from the lockfile, identical guarantee to `go mod download` |
| `--mount=type=cache` | BuildKit caches `npm`'s download cache across builds → faster CI |
| Lockfile copied before source | Dependency layer is reused when only source changes, not busted every commit |
| `nginxinc/nginx-unprivileged` | Serves static files; **non-root by default** — no `USER` directive needed |
| Two stages | The build stage — Node, `node_modules`, and the full source tree — never reaches the final image |

**Why not ship a Node server in production at all.** A React app builds
to static HTML/JS/CSS; there is no server-side rendering in this repo's
default stack. Running `node server.js` or `vite preview` in production
means paying for and exposing a full JavaScript runtime to serve files
nginx (or an equivalent static server) does more simply, with a smaller
attack surface and no dependency-vulnerability surface of its own at
runtime.

**Alternative final-stage base:**
[`static-web-server`](https://github.com/static-web-server/static-web-server)
is a single, few-MB Rust static-file binary — a smaller final image than
even `nginx-unprivileged`'s alpine base, at the cost of losing nginx's
broad, familiar configuration surface (this repo's teams already know
nginx). Use it where the last few MB of image size matter more than
config-language familiarity; the multi-stage shape and every rule below
apply identically either way — only the final-stage `FROM` line and its
config file's syntax change.

---

## nginx.conf: Caching, Compression, SPA Fallback

```nginx
server {
  listen 8080;
  root /usr/share/nginx/html;

  # Hashed assets (content hash in the filename) are immutable → cache forever.
  location /assets/ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }

  # index.html must NEVER be cached — it is what makes a new deploy visible
  # immediately. A cached index.html references chunk hashes a new deploy
  # has already removed, producing a white screen for returning users.
  location = /index.html {
    add_header Cache-Control "no-cache";
  }

  # SPA fallback: any client-side route resolves to index.html so a deep-link
  # refresh (e.g. /data-assets/42) doesn't 404 at the server (see react-routing).
  location / {
    try_files $uri /index.html;
  }

  gzip on;
  gzip_types text/css application/javascript application/json image/svg+xml;
  gzip_min_length 1024;
}
```

The cache split — **immutable hashed assets, never-cached `index.html`**
— is what lets a deploy take effect instantly without breaking
long-cached chunks a returning user's browser already holds. Getting this
backwards in either direction is a real production failure mode: caching
`index.html` produces a white screen after deploys; failing to cache
hashed assets means refetching megabytes of already-immutable JS on every
visit.

---

## CORS: The One Rule a Remote Needs That a Standalone SPA Doesn't

The shell (and, in an omnidirectional federation topology, any other
consuming app) fetches a remote's `remoteEntry.js` and its exposed chunks
**cross-origin** — the remote is served from its own image, its own
origin. This works transparently in local dev because `vite dev` often
serves everything from `localhost` on adjacent ports that the browser
treats permissively in practice, then fails **only in production**, where
the shell's origin and the remote's origin are genuinely different, the
first time a real deployment separates them. Add this to a remote's
`nginx.conf` (not needed on the shell, which nothing else federates from):

```nginx
location ~* \.(js|json)$ {
  add_header Access-Control-Allow-Origin "*" always;
  # Narrow this to the shell's actual origin(s) once they're known and
  # stable, rather than a permanent wildcard, if the deployment topology allows it.
}
```

A missing CORS header here is a silent, environment-specific failure —
correct locally, broken only after deploy — which is exactly the kind of
bug that a Dockerfile/nginx-config review should catch before a remote
ships, not the kind a functional test run in isolation will surface.

---

## .dockerignore

```
node_modules
dist
.git
.env*
*.log
coverage
```

Excluding `node_modules` and `.env*` from the build context matters even
before the multi-stage split helps: a large local `node_modules` slows
every `docker build`'s context upload, and a stray `.env` file in the
build context is one accidental `COPY . .` away from landing in an image
layer permanently (see `image-size-and-security-standard.md`'s no-secrets
rule).
