# Kong Configuration — Plugins, decK, KIC, DB-less

Reference material for `api-gateway-design`. This file is the concrete configuration reference:
Kong's plugin model and the three plugin families that matter, declarative config via **decK**
(out-of-cluster) and the **Kong Ingress Controller** CRDs (in-cluster), **DB-less** mode, and
per-tenant Consumer rate limiting — all reconciled GitOps-style, the same way this repo manages
Helm/OpenTofu state.

Kong is named because the platform named it; the *pattern* generalizes to any gateway. No version
numbers or benchmarks are asserted — every feature named below is a long-standing documented Kong
capability.

## 1. The Plugin Model — Edge Policy Attached to Objects

Kong's core is a thin reverse proxy. **All** behavior is plugins. A **plugin** is a unit of edge
policy that is *configured, not coded* — the gateway equivalent of "declare the behavior, don't
reimplement it per service." A plugin attaches to one of four scopes, from broadest to narrowest:

| Scope | Attaches to | Use for |
|---|---|---|
| Global | every request | org-wide policy (e.g., request-id, global rate ceiling) |
| Service | one upstream service | policy for all routes of a service |
| Route | one route (path/host) | policy for a specific endpoint |
| Consumer | one identified caller | per-tenant/per-key policy (e.g., that tenant's rate limit) |

Narrower scope wins where they overlap. A **Consumer** is the identity — an API key or a tenant —
that a plugin like `rate-limiting` is scoped to.

## 2. The Three Plugin Families That Matter

### Auth — validate credentials, set the Consumer

These validate the caller and set the authenticated Consumer. They implement **authentication
offload**: validate once at the edge, reject anonymous traffic, forward verified identity
downstream. They do **not** make authorization decisions.

| Plugin | What it validates |
|---|---|
| `key-auth` | an API key header/query param |
| `jwt` | a signed JWT (signature, expiry, registered claims) |
| `oauth2` | OAuth2 flows issued/validated by Kong |
| `openid-connect` (OIDC) | tokens from an external IdP via OIDC discovery |

For this repo the `jwt` / `openid-connect` plugin validates the user token and rejects anonymous
callers; the verified claims are forwarded downstream and the **application** does ABAC. Never put
tenant/ABAC logic in these plugins.

### Traffic control — protect shared edge capacity

| Plugin | What it does |
|---|---|
| `rate-limiting` | request-count caps per second/minute/hour, scopable to a Consumer |
| `request-size-limiting` | reject oversized request bodies at the edge |
| `proxy-cache` | cache upstream responses to shed repeat load |

### Transformations — reshape generically at the edge

| Plugin | What it does |
|---|---|
| `request-transformer` | add/remove/rename/replace request headers, query args, body fields |
| `response-transformer` | add/remove/rename response headers and body fields |

Keep these **generic** (normalize headers, strip internal headers, inject a request id).
Client-specific aggregation belongs in a **BFF**, not a `response-transformer` — see
`gateway-vs-mesh-and-placement.md`.

## 3. DB-less Mode — the Stateless-Edge Default

Kong can run **without** its control-plane database (Postgres/Cassandra), loading its full config
from a declarative YAML at boot (and via decK). DB-less is the natural fit for a GitOps,
immutable-infrastructure shop:

- **No stateful gateway datastore** to back up, restore, or run per tenant.
- **Config is the manifest** — the declarative file *is* the source of truth.
- **The gateway pod is disposable** and reproducible: kill it, a new one boots from the same file.

DB-less removes an entire stateful dependency from the edge tier — aligning the gateway with this
repo's per-tenant physical isolation and immutable delivery. Set it in `kong.conf` /
environment:

```
KONG_DATABASE=off
KONG_DECLARATIVE_CONFIG=/kong/declarative/kong.yaml
```

## 4. Declarative Config with decK (Out-of-Cluster)

**decK** manages the full declarative state of a Kong instance as one YAML file, diffed and synced
against a running Kong — never live admin-UI clicks. The core workflow:

- `deck gone dump` / `deck dump` — export current running config to YAML (bootstrap from existing).
- `deck diff` — show what a config file change *would* alter against the running gateway (the
  review artifact in a PR).
- `deck sync` — reconcile the running gateway to match the file.
- `deck validate` — check the file's shape before applying.

A `deck diff` in CI is the gateway equivalent of a Terraform/OpenTofu plan: the reviewer sees the
exact edge-policy delta before it ships.

```yaml
# kong.yaml — the whole edge surface as one reviewed, version-controlled file.
_format_version: "3.0"

services:
  - name: data-asset-api
    url: http://data-asset-api.default.svc:8080
    routes:
      - name: data-asset-route
        paths: ["/v1/assets"]
    plugins:
      - name: jwt                     # authn offload — validate, reject anonymous
      - name: rate-limiting           # service-wide ceiling
        config:
          minute: 6000
          policy: local

consumers:
  - username: tenant-acme
    keyauth_credentials:
      - key: <injected-from-secret>
    plugins:
      - name: rate-limiting           # per-tenant edge quota — defense in depth
        config:
          minute: 600
          policy: local
```

The per-Consumer `rate-limiting` block is the concrete "rate-limit per tenant" pattern: each
tenant is a Consumer with its own edge quota, so one tenant cannot exhaust shared edge capacity —
a second, outer limit complementing the per-namespace resource limits of physical isolation.

## 5. Declarative Config with the Kong Ingress Controller (In-Cluster)

On Kubernetes, Kong runs as an **Ingress Controller (KIC)**: gateway config is expressed as
**Kubernetes resources** and reconciled from Git — the same GitOps model the rest of the platform
uses. Routing is a standard `Ingress` (or Gateway API `HTTPRoute`); plugins and consumers are Kong
CRDs.

### A plugin as a CRD, bound to an Ingress

```yaml
# KongPlugin — the rate-limiting plugin as a first-class Kubernetes object.
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: edge-rate-limit
config:
  minute: 600
  policy: local
plugin: rate-limiting
---
# Bind it by annotating the Ingress (or a Service).
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: data-asset-ingress
  annotations:
    konghq.com/plugins: edge-rate-limit,edge-jwt
spec:
  ingressClassName: kong
  tls:
    - hosts: ["api.example.com"]
      secretName: api-tls           # gateway terminates client TLS here
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /v1/assets
            pathType: Prefix
            backend:
              service:
                name: data-asset-api
                port:
                  number: 8080
```

### A tenant as a KongConsumer

```yaml
# KongConsumer — a tenant modeled as a Kong Consumer, so a per-Consumer
# rate-limit plugin can be scoped to it.
apiVersion: configuration.konghq.com/v1
kind: KongConsumer
metadata:
  name: tenant-acme
  annotations:
    konghq.com/plugins: tenant-acme-rate-limit
username: tenant-acme
```

Both the CRDs and the Ingress live in Git and are reconciled by the same GitOps flow (see
`gitops-workflow`) that manages Helm and OpenTofu — a new route or a changed rate limit is a
**reviewed PR diff**, never a live admin-API mutation.

## 6. Edge Telemetry Into the Existing Stack

Kong exposes request logging and metrics; wire them into this repo's existing observability rather
than a separate pane:

- **Prometheus** — the `prometheus` plugin exposes per-route/per-Consumer request counts, latency
  histograms, and status-code metrics on a metrics endpoint Prometheus scrapes.
- **Tempo (traces)** — export spans via OpenTelemetry so edge latency joins interior traces.
- **Grafana** — edge latency, 4xx/5xx rates, and per-Consumer throughput land in the same Grafana
  the mesh and services already use — one pane, edge plus interior.

```yaml
# Prometheus metrics as a global plugin (decK form).
plugins:
  - name: prometheus
    config:
      status_code_metrics: true
      latency_metrics: true
      per_consumer: true          # per-tenant throughput visibility
```

## 7. Configuration Checklist

- `KONG_DATABASE=off` — DB-less; the declarative file is the source of truth.
- Every route + plugin exists as a KIC CRD or a decK YAML entry in Git — no admin-API mutation.
- A `deck diff` (or the CRD PR diff) is the reviewed edge-policy delta before merge.
- Auth plugin validates + rejects anonymous; forwards claims; carries **no** ABAC logic.
- Each tenant is a `KongConsumer` with a Consumer-scoped `rate-limiting` plugin.
- `prometheus` plugin enabled with `per_consumer: true`; traces exported to Tempo.
- Client TLS terminates at the gateway (`tls` on the Ingress / cert on the gateway); the mesh
  handles east-west mTLS separately.
