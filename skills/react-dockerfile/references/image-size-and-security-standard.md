# Image Size, Compression, and Security Scanning Standard

Full detail on why `node_modules` must never reach the final image,
brotli/gzip compression options at the serving layer, the CSP and
security-header block, the no-secrets rule, and vulnerability scanning —
kept consistent with `go-dockerfile`'s exact standard, adapted from a
compiled binary to a static-asset build. Self-contained — loadable
without the parent `SKILL.md` body already in context.

---

## Why `node_modules` Must Never Reach the Final Image

A real `node_modules` tree for a Vite/React app — every dependency, every
transitive dependency, every dev-only tool (the TypeScript compiler,
ESLint, test runners, Vite itself) — routinely runs to hundreds of MB,
often exceeding the size of the actual `dist/` output by one to two
orders of magnitude. None of it is needed to serve the built app: `dist/`
is plain HTML, JS, and CSS; nginx needs nothing from `node_modules` to
serve those files. The multi-stage build (`multi-stage-build-standard.md`)
is what guarantees this split — `COPY --from=build /app/dist ...` copies
only the build stage's output, never its `node_modules`, into the
runtime stage. A single-stage image (`FROM node:20-alpine` straight
through to `CMD`) ships the entire builder tree — toolchain, dev
dependencies, and source — alongside the three folders of static files
actually being served, multiplying both image size and attack surface for
no runtime benefit.

## Compression at the Serving Layer

Two ways to compress text assets (JS, CSS, JSON, SVG) before they reach
the browser, both legitimate:

1. **On-the-fly `gzip`** — nginx's built-in `gzip on;` module
   (`multi-stage-build-standard.md`'s `nginx.conf`) compresses responses
   as they're served. Simple, zero build-pipeline change, slightly more
   CPU per request (negligible for static text assets at typical
   traffic).
2. **Pre-compressed `.br`/`.gz` assets served directly** — a build-time
   plugin (e.g. `vite-plugin-compression`) emits a `.br` and/or `.gz`
   sibling next to each built asset; nginx's `gzip_static on;` (or an
   equivalent brotli directive, since nginx's brotli support is a
   separate module not compiled in by default on most base images) serves
   the pre-compressed file directly with zero request-time CPU cost.
   Brotli typically compresses 15-25% smaller than gzip for JS/CSS at
   the same quality trade-off, at the cost of a slower one-time build-time
   compression step.

Default to on-the-fly `gzip` for its zero-config simplicity; move to
pre-compressed brotli once bundle size or request volume makes the
request-time CPU cost or the extra compression ratio worth the added
build step. Either choice is a real answer — shipping **neither** and
serving uncompressed JS/CSS is the actual anti-pattern, wasting bandwidth
and slowing first paint for every visitor for no reason.

## Content-Security-Policy and Security Headers

The static server — not the application — sets the Content-Security-Policy
and security headers. CSP is the frontend's primary defence against XSS:
it restricts where scripts, styles, and network connections may
originate from.

```nginx
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self' https://otlp.example.com; frame-ancestors 'none'; base-uri 'self'" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header Referrer-Policy "no-referrer" always;
```

`connect-src` must list the API origin and the OTLP/RUM collector
endpoint so `react-observability` can report telemetry — both values
typically come from the same runtime `window.__APP_CONFIG__`
(`runtime-config-injection.md`) the app itself reads, so the CSP's
allow-list and the app's actual runtime targets stay in sync by
construction rather than by manually keeping two configs aligned. This
complements the backend's own security headers (`security-implementation`)
— both tiers set them independently; the browser enforces whichever is
strictest.

**Never add `unsafe-inline` or `unsafe-eval`** to make a broken CSP "work"
— doing so neutralises CSP's actual XSS defence. Vite emits no inline
scripts by default; if something triggers a CSP violation, fix the
inline script or style, don't loosen the policy that exists to catch it.

## No Secrets, Anywhere in the Image

A frontend image and everything inside it is downloaded, in effect, by
every user who loads the app — there is no private layer of a frontend
deployment the way a backend service has a private network segment.
Therefore:

- **No secrets baked into the build** — anything in `import.meta.env` at
  build time, or written into `window.__APP_CONFIG__` at runtime
  (`runtime-config-injection.md`), must be public-safe by definition. If
  it needs to stay confidential, it does not belong in either mechanism.
- **No API keys or tokens in the code, the image, or any layer** — a JWT
  comes from the authentication flow at request time (`react-api-client`'s
  auth-token standard), never from a value shipped in the image.
- **Sourcemaps are built for production error symbolication**
  (`react-observability`) but uploaded **privately** to the error-tracking
  backend, never served publicly alongside the bundle — a public
  sourcemap hands an attacker the fully readable original source.

This is the frontend echo of the backend's `secrets-management`
non-negotiables — the only difference is that a frontend "secret" is
even more exposed than a backend one, since there is no private network
boundary protecting it at all.

## Non-Root and Vulnerability Scanning, Consistent with `go-dockerfile`

`go-dockerfile`'s standard for the backend image: pin base images by
tag/ideally digest, run as a non-root user with a read-only-compatible
filesystem, Cosign-sign the image in CI, and gate the build on a
Trivy scan with no HIGH/CRITICAL CVEs. The frontend image applies the
identical standard:

| Control | Backend (`go-dockerfile`) | Frontend (this skill) |
|---|---|---|
| Non-root | `distroless/static:nonroot`, uid 65532 | `nginx-unprivileged`, uid 101 |
| Read-only-FS compatible | Binary writes nothing at runtime | nginx writes only to a mounted tmp; the platform sets `readOnlyRootFilesystem` |
| Pinned base | Tag/digest-pinned `golang`/`distroless` | Tag/digest-pinned `node`/`nginx-unprivileged` |
| Signed | Cosign-signed in CI | Cosign-signed in CI, same pipeline shape |
| Scanned | Trivy, no HIGH/CRITICAL (CI gate) | Trivy, no HIGH/CRITICAL (CI gate) |

The scan target matters: Trivy should scan the **final** runtime-stage
image, not the builder stage — the builder's `node_modules` will always
carry more (often irrelevant, dev-only) findings than the handful of
packages nginx-unprivileged's final layer actually ships, and scanning
the wrong stage either produces noisy false urgency or, worse, misses a
real finding in a base image that did make it to production.
