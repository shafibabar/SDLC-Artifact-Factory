# Enforcement Layers — Per-Layer Isolation Rules

Reference for `multi-tenancy-design`. Self-contained: how each isolation model is
enforced at each of the four layers, the exact tenant-resolution rule, the
connection-routing mechanism, and the specific leaky-layer failure mode for each
tier. Examples are in this repo's stack (Go + `chi` + `pgx` + Redpanda,
Kubernetes + Helm, per-tenant physical isolation) and the DataAsset Management /
Compliance / Reporting Bounded Contexts.

**The governing rule: the chosen isolation model must hold at every layer.** A
single leaky layer breaks the guarantee for the whole system — the strongest
boundary is only as strong as its weakest side channel. What follows is, for each
layer, how the stamp model enforces isolation, how the weaker models enforce it,
and the concrete failure mode when that layer leaks.

---

## Layer 1 — Infrastructure (cluster / namespace / network)

**Stamp model.** One Kubernetes namespace per tenant (`tenant-<id>`), or a
dedicated cluster / cloud account for the highest-sensitivity tenants. The
critical control is a **default-deny NetworkPolicy** so there is no network path
between tenant namespaces — a pod in `tenant-acme` cannot open a socket to a pod
or database in `tenant-globex`. Each tenant has its own ingress; there is no
shared load balancer whose misconfiguration could route across tenants. Linkerd
enforces mTLS *within* a tenant's namespace; it is not a cross-tenant boundary.

```yaml
# Default-deny: nothing enters a tenant namespace except its own ingress.
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-cross-tenant
  namespace: tenant-acme
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels: { tenant: acme }   # same-tenant traffic only
  egress:
    - to:
        - namespaceSelector:
            matchLabels: { tenant: acme }
    # plus explicit egress to the tenant's own DNS, and nothing else cross-tenant
```

**Weaker models.** Shared-schema and shared-everything share a namespace and
network by design; infrastructure is not their isolation boundary, so the burden
shifts entirely to the database and API layers.

**Leaky-layer failure mode.** A shared ingress or a flat pod network (no
NetworkPolicy, or an allow-all one) means a compromised or buggy pod in one
tenant can reach another tenant's services and database directly, bypassing every
higher-layer control. Physical stamps with a flat network are isolation theatre.

---

## Layer 2 — Database

**Stamp model.** A separate PostgreSQL instance per tenant, with separate
credentials and a separate connection pool. **The connection is routed by tenant
— never a single shared pool that filters by `tenant_id`.** The routing mechanism
resolves the tenant (from the request context, layer 4), looks up that tenant's
DSN, and uses that tenant's pool. Because the instance itself is tenant-scoped, no
`tenant_id` column is needed for isolation; `tenant_id` is still carried for audit
and traceability, not for filtering.

```go
// Per-tenant pgxpool, keyed by tenant. There is no shared pool.
type TenantDB struct {
    pools map[string]*pgxpool.Pool // tenant id -> that tenant's instance pool
}

func (t *TenantDB) Pool(ctx context.Context) (*pgxpool.Pool, error) {
    tenant, ok := TenantFromContext(ctx) // set by the API middleware, layer 4
    if !ok {
        return nil, ErrNoTenantInContext // fail closed — never fall back to a default
    }
    p, ok := t.pools[tenant.ID]
    if !ok {
        return nil, fmt.Errorf("no database provisioned for tenant %s", tenant.ID)
    }
    return p, nil // this tenant's own instance; a query here cannot see another's
}
```

**Weaker models.** Shared-schema routes the connection to the tenant's *schema*
(`SET search_path TO tenant_<id>`) within one shared instance. Shared-everything
uses one pool and relies on a `tenant_id` filter, ideally enforced by Row-Level
Security so the database, not the developer, applies it:

```sql
-- shared-everything only: make the filter non-optional.
ALTER TABLE compliance_finding ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON compliance_finding
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

**Leaky-layer failure mode.** In a shared instance, one DB-engine breach, one
compromised superuser, or one migration that touches the wrong schema exposes
every tenant. In shared-everything without RLS, a single missing `WHERE
tenant_id = $1` is a cross-tenant breach — application discipline is not an
isolation boundary. In the stamp model, the failure mode is a *routing* bug:
falling back to a "default" pool when the tenant is unresolved. The fix above is
**fail closed** — no tenant in context means the query is refused, never served
from a default database.

---

## Layer 3 — Event / Broker (Redpanda)

**Stamp model.** A dedicated Redpanda namespace or cluster per tenant. Topics are
not shared across tenants, so a `DataAssetDiscovered` event produced in
`tenant-acme` physically cannot be consumed from `tenant-globex`. The tenant
context still travels on **every event** — in a header or envelope field — but for
audit, replay, and traceability, **not** as the isolation mechanism. Consumer
groups are tenant-scoped.

```go
// Every event carries tenant context for audit — it is NOT what isolates it.
// Isolation comes from the broker being this tenant's own cluster/namespace.
type EventEnvelope struct {
    TenantID    string    `json:"tenant_id"`   // audit + replay, not isolation
    BoundedCtx  string    `json:"bounded_context"` // e.g. "compliance"
    EventName   string    `json:"event_name"`  // e.g. "ComplianceFindingRaised"
    OccurredAt  time.Time `json:"occurred_at"`
    Payload     json.RawMessage `json:"payload"`
}
```

**Weaker models.** A shared cluster with tenant-prefixed topics
(`<tenant>.<context>.<event>`) and per-tenant ACLs. This is acceptable *only* for
a product whose declared model is logical — for a physical-isolation product it is
a leak (see below).

**Leaky-layer failure mode.** A single shared Redpanda cluster with tenant-prefixed
topics for a physical-isolation product reintroduces exactly the cross-tenant path
the stamp removed: a broker-level bug, a mis-scoped ACL, or a compromised consumer
with cluster-wide read can consume another tenant's events. "Shared broker just for
efficiency" is the most common way a physically-isolated system silently loses its
guarantee — the broker must match the declared model.

---

## Layer 4 — API (tenant resolution)

**This is the layer with the single most important rule in multi-tenancy:**

> **The tenant identity is resolved from the authenticated request context — the
> routing host and the verified JWT claim — and it must NEVER come from a
> client-supplied parameter (a query string, a request-body field, or an
> unverified header).**

A client-supplied `?tenant=` or `{"tenant_id": "..."}` that the server trusts is a
direct cross-tenant read primitive: any authenticated user simply names another
tenant's id and reads its data. In the stamp model, tenant is implied by the
routing host (`acme.api.example.com` reaches only `tenant-acme`'s services), and
the JWT `tenant_id` claim is validated against that host as defence in depth. A
tenant-scoping middleware puts the resolved, verified tenant into the request
context and **rejects any mismatch** — that context is the only source layers 2
and 3 trust.

```go
// chi middleware: resolve tenant from auth context, reject client-supplied claims.
func TenantScope(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        claims, ok := ClaimsFromJWT(r) // already verified upstream
        if !ok {
            http.Error(w, "unauthenticated", http.StatusUnauthorized)
            return
        }
        // Defence in depth: the JWT tenant must match the routing host's tenant.
        routed := TenantFromHost(r.Host) // e.g. "acme" from acme.api.example.com
        if claims.TenantID == "" || claims.TenantID != routed {
            http.Error(w, "tenant mismatch", http.StatusForbidden)
            return
        }
        // IGNORE any r.URL.Query().Get("tenant") / body tenant_id entirely —
        // a client-supplied tenant is never consulted for authorization.
        ctx := WithTenant(r.Context(), Tenant{ID: claims.TenantID})
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

**Weaker models.** Shared-schema and shared-everything resolve the tenant the same
way (from auth context, never from a client parameter) — the rule is identical.
The difference is only what the resolved tenant then selects: a schema, an RLS GUC,
or a per-tenant pool. The resolution rule does not weaken with the model.

**Leaky-layer failure mode.** Trusting any client-supplied tenant identifier for
authorization. This is the classic multi-tenant IDOR: the request authenticates
correctly but names a tenant the caller does not own, and the server honours it.
The middleware above is the boundary — tenant comes from the verified token and
the routing host, and a mismatch is a `403`, never a silent override.

---

## Cross-Layer Summary

| Layer | Stamp enforcement | The rule that must not bend | Leak = |
|---|---|---|---|
| Infrastructure | Namespace/cluster per tenant; default-deny NetworkPolicy; per-tenant ingress | No network path between tenants | Flat network / shared ingress → pod-to-pod cross-tenant reach |
| Database | Per-tenant instance; per-tenant pool; routed by tenant; fail closed | Never a shared pool filtered by `tenant_id`; never fall back to a default DB | Shared instance breach or missing `WHERE` exposes all tenants |
| Event/Broker | Per-tenant Redpanda namespace/cluster; tenant on every event for audit only | The broker matches the declared model | Shared cluster + prefixed topics → ACL/consumer crosses boundary |
| API | Tenant from routing host + verified JWT claim; scoping middleware rejects mismatch | Tenant NEVER from a client-supplied parameter | Trusted `?tenant=` param → cross-tenant IDOR |

Every layer enforces the *same* model. The moment one layer enforces a weaker
model than the others, the whole system's isolation collapses to that weakest
layer.
