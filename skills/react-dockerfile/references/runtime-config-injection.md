# Runtime Config Injection: Build-Time vs. Runtime Environment Variables

The precise statement of the Vite environment-variable problem, why it
breaks this plugin's CI/CD principle, and the `window.__APP_CONFIG__` fix
this repo standardizes on. Self-contained — loadable without the parent
`SKILL.md` body already in context.

---

## The Problem, Stated Precisely

Vite exposes environment variables prefixed `VITE_` via
`import.meta.env.VITE_*`. These are not read at runtime by the deployed
app — they are substituted as **literal string constants** into the
built JavaScript at `npm run build` time, the same way a compiler
constant-folds a `#define`. A `.env` file containing
`VITE_API_URL=https://api-staging.example.com` produces a bundle whose
JS files contain that exact string, baked in, indistinguishable from a
hardcoded value once the build finishes.

The consequence: the **same built artifact** — the same `dist/` output,
the same container image — cannot be deployed to staging and then to
production with a different API URL, because the URL isn't a runtime
input at all; it's compiled in. The only way to get a different value is
to rerun `npm run build` with a different `.env`, producing a
**different** artifact for each environment.

## Why This Breaks CI/CD, Specifically

This plugin's tech stack (`CLAUDE.md`, GitHub Actions CI/CD) and
`go-dockerfile`'s own standard both assume **build once, promote the same
artifact** — a single image is built, scanned, signed, and the identical
digest is promoted from staging to production. That principle exists
because it's the only way to be certain "what we tested in staging is
exactly what's running in production," rather than "something built from
the same source, but not the same bytes." A build-time-only environment
variable defeats this for the frontend specifically: rebuilding per
environment means staging and production are never actually running the
same artifact, only the same source at two different build times —
reintroducing exactly the class of environment-drift bug immutable,
promoted-by-digest deployment exists to eliminate.

## The Fix: Inject at Container Start, Not at Build Time

Anything that varies per environment or per tenant (API base URL, OTLP
collector endpoint, feature-flag service URL, the app's own release
version string for error-report tagging) must **never** be read from
`import.meta.env` in code that ships to more than one environment. It is
written to a small runtime file by an entrypoint script that runs when
the **container starts**, not when the image is **built**:

```sh
# docker-entrypoint.d/40-env.sh
# Runs at container start (nginx's docker-entrypoint.d convention picks
# up any executable script here automatically before nginx itself starts).
cat > /usr/share/nginx/html/config.js <<EOF
window.__APP_CONFIG__ = {
  apiBaseUrl: "${API_BASE_URL}",
  otlpEndpoint: "${OTLP_ENDPOINT}",
  release: "${APP_VERSION}"
};
EOF
```

`index.html` loads this file before the app's own bundle:

```html
<script src="/config.js"></script>
<script type="module" src="/assets/index-a1b2c3.js"></script>
```

Application code reads `window.__APP_CONFIG__.apiBaseUrl` wherever it
would otherwise have read `import.meta.env.VITE_API_URL` — the one
change that makes the value a genuine runtime input instead of a
build-time constant. The **same image**, unmodified, produces a
different `config.js` in every environment because the entrypoint script
reads whatever the platform actually set as real environment variables
for that specific running container — staging's container gets
staging's values, production's gets production's, from one built image.

## What Belongs in `config.js` — and What Never Does

Only **public, non-secret** configuration belongs here: URLs, feature
flags, a release/version string. This file is served to every browser
exactly like the rest of the static bundle — it has no more
confidentiality than `main.js` does. A JWT, an API key, or any credential
must never appear in it; those come from the authentication flow at
request time, never from the image or its runtime config (see
`react-api-client`'s auth-token standard, `secrets-management`). Putting
a secret in `config.js` because "it's not baked into the JS bundle
itself" misses the point — it is still shipped to, and readable by,
every visitor's browser.

## The Same Principle One Layer Up: Dynamic Remote Resolution

`microfrontend-architecture`'s dynamic remote loading section applies
this exact same "build once, inject at runtime" principle to a different
value: which URL a shell should fetch a given remote's `remoteEntry.js`
from. Rather than hardcoding a fixed `remotes` map in the shell's Vite
config at build time (one shell build per set of remote URLs), the shell
resolves those URLs from a runtime-fetched manifest — letting one shell
image serve different per-tenant or per-environment remote bundles. It is
the identical mechanism this file describes, extended from "what value
does the app read" to "which remote does the host even mount" — read
that skill's dynamic remote loading section for the manifest shape
itself; this file owns the underlying config-injection mechanism both
uses.

## Anti-Pattern Detail

- **`VITE_API_URL` read directly in application code that ships to more
  than one environment** — the moment it's read anywhere other than a
  single-environment local-dev convenience, it has silently become a
  per-environment rebuild requirement nobody decided on purpose.
- **A secret in `config.js` "because it's not in the JS bundle"** — still
  public; the file is served to every browser with no additional
  protection over any other static asset.
- **Baking a value in for "just this one environment, temporarily"** —
  the temporary rebuild-per-environment habit is exactly what erodes the
  single-build-promoted-everywhere guarantee; there is no environment
  where reintroducing it is actually safe.
