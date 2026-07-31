# Gateway vs. Mesh, Placement, and BFF

Reference material for `api-gateway-design`. This file goes deep on the two-plane model
(north-south vs east-west), the concrete placement topology for this repo (gateway = ingress in
front of the Linkerd mesh), the TLS-termination-then-mTLS-handoff flow, and the gateway-vs-BFF
boundary with a worked example. The SKILL.md body states the distinction; this file is the
extended treatment the platform-engineer applies to a specific system.

## 1. The Two Planes

Every request in a Kubernetes microservices system belongs to exactly one of two planes. The
whole point of this skill is that they are governed by **different objects** and must never be
conflated.

### North-South — the gateway's domain

North-south traffic **crosses the outer boundary**: a client (browser, mobile app, partner
system) reaching into the cluster. It is untrusted by default — an anonymous, unauthenticated,
plaintext-TLS request arriving from the public internet. The gateway is the first thing it
touches. Everything the gateway does is a north-south concern:

- Terminate the client's TLS.
- Match the request path/host and **route** it to the correct upstream service.
- **Authenticate** — validate the JWT or API key; reject anonymous traffic here, at the edge.
- **Rate limit** per client/tenant so one caller cannot exhaust shared edge capacity.
- **Transform** generically — normalize headers, strip internal headers, add a request id.
- **Observe** — emit request logs, latency, and status-code metrics for all ingress.

### East-West — the mesh's domain

East-west traffic is **service-to-service**, already **inside** the cluster: pod A calling pod B.
By the time traffic is east-west it has already crossed the gateway and been authenticated. The
mesh (Linkerd here) governs this plane:

- **mTLS** — every pod-to-pod call is mutually authenticated and encrypted by the sidecar, with
  a cryptographic workload identity, independent of the client's original TLS.
- **Retries / timeouts** — transient inter-service failures are absorbed by the mesh.
- **Per-call telemetry** — golden metrics (success rate, latency, throughput) between pods.

### The comparison table

| Dimension | North-South (gateway) | East-West (mesh / Linkerd) |
|---|---|---|
| Traffic | client → cluster | service → service |
| Trust at entry | untrusted, anonymous | already authenticated at the edge |
| Identity | client identity via JWT/API key | workload identity via mTLS certificate |
| TLS | terminates the **client's** TLS | establishes **new** pod-to-pod mTLS |
| Auth concern | authentication (prove who) | transport identity (which workload) |
| Reliability | rate limit, quota | retries, timeouts |
| Config surface | routes + plugins (KIC CRDs / decK) | mesh policy (Linkerd resources) |
| Enforced by | the gateway workload | the Linkerd sidecar per pod |

### The two category errors this table prevents

1. **"We have Linkerd, so we don't need a gateway."** Wrong. The mesh never sees anonymous
   client traffic correctly — it authenticates *workloads*, not *users*, and it does not terminate
   client TLS or rate-limit external callers. Skipping the gateway leaves the north-south boundary
   unguarded.
2. **"We have a gateway, so we don't need the mesh."** Wrong. The gateway does not give pod-to-pod
   mTLS identity or inter-service retries. Skipping the mesh leaves the east-west plane in
   plaintext with no workload identity.

Equally wrong at the plugin level: doing **edge authn in the mesh sidecar**, or trying to do
**inter-service mTLS in the gateway**. Each is a plane doing the other plane's job.

## 2. Placement — the Gateway *Is* the Ingress in Front of the Mesh

In this repo's Kubernetes + Linkerd topology the gateway is not a separate box bolted on beside
the ingress — the gateway **is** the ingress controller. Kong runs as a Kong Ingress Controller
(KIC) workload. The flow, outermost to innermost:

```
                 ┌─────────────────────────── Kubernetes cluster ───────────────────────────┐
                 │                                                                            │
 client ──TLS──► │  ┌────────────────────┐        ┌── Linkerd mesh (east-west, mTLS) ──┐     │
 (north-south)   │  │  Kong (KIC)         │        │                                    │     │
                 │  │  = ingress          │  mTLS  │   ┌────────┐      ┌────────┐        │     │
                 │  │  - TLS termination  ├───────►│   │ svc A  ├─────►│ svc B  │        │     │
                 │  │  - authn (jwt/OIDC) │        │   └────────┘      └────────┘        │     │
                 │  │  - rate limit       │        │        pod-to-pod mTLS + retries    │     │
                 │  │  - transform        │        └────────────────────────────────────┘     │
                 │  └────────────────────┘                                                     │
                 │        ▲ default-deny NetworkPolicy: ingress-gateway is the one allowed     │
                 │          north-south peer                                                    │
                 └────────────────────────────────────────────────────────────────────────────┘
```

Key placement facts:

- **The gateway is the outermost trust-boundary crossing.** It is where an untrusted client
  becomes an authenticated request. Everything behind it is inside the trust boundary the gateway
  established.
- **The mesh is the internal identity fabric.** Once traffic is handed off, Linkerd re-encrypts it
  with mTLS and manages east-west calls with workload identity — independent of the client's TLS.
- **Resolving the `kubernetes-manifest` "ingress-gateway" peer.** That skill's default-deny
  `NetworkPolicy` names an opaque `ingress-gateway` as the single allowed north-south source. That
  opaque box **is this gateway** — the Kong Ingress Controller workload, with its own config,
  plugins, and TLS-termination responsibility. The two skills reference one coherent object: the
  gateway is the NetworkPolicy peer *and* the edge-policy enforcement point.

## 3. TLS Termination Then Edge-Auth Handoff to App ABAC

The handoff chain is the concrete expression of "edge proves *who*, mesh carries identity, app
decides *what*":

1. **Client TLS terminates at the gateway.** The gateway holds the public-facing certificate;
   the client's encrypted channel ends here.
2. **The gateway authenticates.** A jwt/OIDC plugin validates the token signature, expiry, and
   issuer, and rejects anonymous or invalid traffic with a `401` before it ever reaches a service.
3. **Verified claims are forwarded downstream** as trusted headers (e.g., a validated subject /
   tenant claim). Downstream services trust these because they can only arrive via the gateway
   (enforced by the default-deny NetworkPolicy — no other north-south path exists).
4. **The mesh re-encrypts pod-to-pod with mTLS.** Linkerd gives the *workload* a cryptographic
   identity for the east-west hop; this is orthogonal to the *user* identity in the forwarded
   claims.
5. **The application makes the authorization decision.** ABAC / tenant-scoping happens in
   application code using the forwarded claims — **not** in the gateway. The gateway thinned the
   attack surface (anonymous traffic is already gone); the app is the authorization authority.

**Why authz must not move to the gateway.** Pushing ABAC/tenant decisions into gateway plugins:

- splits the authorization model across two layers (gateway plugins + app code) that can drift;
- recreates the "smart gateway" anti-pattern — a monolithic, hard-to-change edge;
- couples per-tenant policy to edge config, when this repo's per-tenant physical isolation and
  ABAC already live in the application.

The rule is bright-line: **the gateway validates *who*; the application decides *what they may
do*.** (See `zero-trust-design` and `access-control-model`.)

## 4. Rate Limiting as Defense in Depth

With this repo's physical per-tenant isolation, per-namespace resource limits already bound a
tenant's interior footprint. A **per-Consumer edge rate limit at the gateway** is a *second*,
outer quota: it stops a single tenant (or a single leaked API key) from exhausting shared edge
capacity before traffic ever reaches that tenant's namespace. Two layers — edge quota + namespace
resource limit — are defense in depth at the front door. The concrete Kong Consumer + rate-limit
plugin wiring is in `kong-configuration.md`.

## 5. Gateway vs. BFF (Backend-for-Frontend)

The gateway and a BFF are frequently conflated because both sit "near the edge." They are
different objects with different change cadences.

| | Gateway | BFF |
|---|---|---|
| Audience | **all** clients (client-agnostic) | **one** client experience (web, or mobile) |
| Concern | cross-cutting edge policy | client-specific aggregation + payload shaping |
| Examples | authn, rate limit, TLS, routing | stitch 3 service calls into one screen's payload |
| Changes when | an edge policy changes | that one frontend's screen changes |
| Where it sits | the outer front door | a service **behind** the gateway |
| Owned by | platform-engineer | the frontend team for that experience |

**Rule of thumb (Newman):** put cross-cutting, client-agnostic concerns (authn, rate limit, TLS)
in the **gateway**; put client-specific aggregation and payload shaping in a **BFF behind** it.

### Worked example — do NOT put this in the gateway

The React app's data-estate dashboard needs one payload combining a `DataAsset` summary, its
compliance status, and its owning team — three downstream services. The wrong instinct is a Kong
`response-transformer` stitching three upstream responses. That overloads the gateway with
client-specific shaping. The right shape is a small BFF service behind the gateway:

```go
// bff/dashboard.go — a per-frontend aggregation service, NOT a gateway plugin.
// It sits behind the gateway (already-authenticated traffic) and inside the mesh
// (mTLS to the three upstreams). The gateway routed /bff/dashboard here; it did
// not do the composition.
func (h *DashboardHandler) AssetOverview(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    tenant := TenantFromClaims(r) // forwarded, gateway-validated claim

    asset, err := h.assets.Get(ctx, tenant, chi.URLParam(r, "id"))
    if err != nil { writeErr(w, err); return }

    // Composition that is specific to THIS frontend's screen — belongs here,
    // never in a gateway response-transformer plugin.
    compliance, _ := h.compliance.Status(ctx, tenant, asset.ID)
    owner, _ := h.directory.Team(ctx, tenant, asset.OwnerTeamID)

    writeJSON(w, DashboardView{
        Asset:      asset,
        Compliance: compliance,
        OwnerTeam:  owner,
    })
}
```

The gateway's job for this request was small and generic: authenticate, rate-limit, and route
`/bff/dashboard` to the BFF. The **shaping** is the BFF's job. Keeping the gateway's plugin set
small and generic is what stops the edge from becoming a monolith.

## 6. Checklist for the Container Diagram

- Exactly **one** north-south arrow: client → gateway/ingress.
- Every in-cluster arrow is **east-west** and carried by the mesh.
- No edge concern (authn, rate limit, TLS termination) appears on an east-west arrow.
- No internal concern (inter-service mTLS, retries) appears on the north-south arrow.
- The `ingress-gateway` NetworkPolicy peer and the "gateway" box are the **same** object.
- Any BFF appears **behind** the gateway, inside the mesh — never as gateway response-transform
  rules.
