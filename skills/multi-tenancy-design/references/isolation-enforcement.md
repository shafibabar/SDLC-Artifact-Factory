# Isolation Enforcement

Reference for `multi-tenancy-design`. Self-contained: how each deployment model is enforced at each layer, the tenant-context rule, and the cross-tenant test. Rules, with short PostgreSQL and Kubernetes snippets for the default stack; service code is backend-engineer's (`go-*` skills) and follows the stack in `sdlc-config.json`.

**The governing rule:** the model declared for a resource must be enforced at every layer that touches it. The system's isolation is its weakest layer. A **leak** is a layer that enforces less than the declared model; it is not a shared component as such. A pooled broker in a pooled model is correct; a pooled broker in front of siloed databases is a leak.

Deployment model and isolation are separate decisions (Golding, `research/software-architecture/building-multi-tenant-saas-golding.md`): a silo is not isolated just by existing, and a pool is acceptable only when a mechanism enforces it.

## 1. Tenant Context (Every Model)

- A user belongs to one tenant, bound once at onboarding in the identity provider. The token carries the **tenant id**, and usually the **tier** and role, as claims (Golding's SaaS identity).
- Each request resolves **tenant context** from the verified token, once, at the edge of the service, and carries it to the data layer, outgoing calls and events.
- **Never** from a query parameter, a body field or an unverified header. A server that honours `?tenant=` lets any authenticated user read another tenant (a cross-tenant IDOR).
- In a silo, also check the token's tenant against the tenant the request was routed to (host or path); a mismatch is refused.
- The tenant check is the first authorization check (`access-control-model`); in a pool it is a primary control, not a backstop.
- No tenant in context means **refuse**, never fall back to a default tenant or a default connection.

## 2. Database

### Pool: forced row-level security

```sql
-- Every tenant table: tenant key, RLS enabled AND forced.
ALTER TABLE invoice ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice FORCE ROW LEVEL SECURITY;   -- the table owner bypasses RLS otherwise
CREATE POLICY tenant_isolation ON invoice
  USING (tenant_id = current_setting('app.tenant_id')::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id')::uuid);

-- The application connects as a role that does not own the tables.
-- Inside each transaction:
--   SET LOCAL app.tenant_id = '<tenant from the token>';
-- SET LOCAL ends with the transaction, so a pooled connection
-- cannot carry one tenant's setting into the next request.
```

- Policies on every tenant table, including join and lookup tables; a table without one is a leak. A fitness function lists tenant tables without a forced policy and fails the build.
- `WITH CHECK` stops writes into another tenant.
- Functions declared `SECURITY DEFINER`, superuser connections and migrations run outside RLS: keep them out of request paths.
- The tenant id leads indexes and partition keys (see `deployment-models.md` § 3).

### Bridge

One schema per tenant; the connection uses a per-tenant role whose privileges cover only its schema, and sets `search_path` to it. Migrations run per schema. The shared instance remains the blast radius.

### Silo

A database or instance per tenant with its own credentials (and, where the contract asks, its own encryption key, from `secrets-management`). The connection is chosen from the tenant in context; an unknown tenant fails closed.

## 3. Broker and Events

- **Every event carries the tenant** (the CloudEvents `tenantid` extension, `event-schema-design`), for routing, audit and replay in every model.
- **Pool:** shared topics; per-service or per-tenant principals; topic ACLs give produce rights to the publisher only; consumers that act for a tenant set tenant context from the event before touching data.
- **Topic per tenant** (still a pooled cluster): when a consumer must be separated per tenant, or a tenant's stream must be deletable as a unit.
- **Silo:** a broker namespace or cluster per tenant; no topic or consumer group spans tenants.

## 4. Network

- **Pool and bridge:** the network is not the isolation boundary; isolation lives in the token, the data layer and the broker. Normal zero-trust rules apply (`zero-trust-design`).
- **Silo:** a default-deny network policy between tenant namespaces, so a pod in one tenant cannot reach another's services or database:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-cross-tenant, namespace: tenant-a }
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress: [ { from: [ { namespaceSelector: { matchLabels: { tenant: a } } } ] } ]
  egress:  [ { to:   [ { namespaceSelector: { matchLabels: { tenant: a } } } ] } ]
  # plus explicit egress to DNS and the tenant's own data stores
```

  A dedicated ingress per tenant only where a contract asks for it. Linkerd's mutual TLS secures traffic inside the mesh; it is not a tenant boundary by itself.

## 5. Telemetry

- Tenant id and tier as attributes on spans and structured logs, from the first service (`opentelemetry-instrumentation`).
- Metrics: per tier, plus bounded per-tenant series (top N, or only for siloed tenants); a label per tenant across thousands of tenants explodes cardinality.
- Usage events the control plane turns into metering and cost per tenant.
- A shared telemetry store is fine for a pool; for a silo whose contract excludes shared processing, telemetry stays in the silo too.

## 6. The Cross-Tenant Test (a Release Gate)

For every model, automated and run before release:
1. Tenant A's token against tenant B's resource ids at each API: expect `403` or `404`, never data.
2. At the data layer, with the app's role and tenant A set: a query for B's rows returns nothing; an insert with B's id is refused.
3. A request with no tenant in context: refused.
4. A tenant-supplied tenant id (parameter, body, header): ignored.
5. For silos: a pod in tenant A's namespace cannot connect to tenant B's database.

## 7. Summary

| Layer | Pool | Bridge | Silo | Leak |
|---|---|---|---|---|
| Tenant context | Token claim | Token claim | Token claim + routed tenant | Client-supplied tenant |
| Database | Forced RLS, non-owner role, `SET LOCAL` | Schema + per-tenant role | Own database, own credentials | A pooled table without forced RLS; a silo with a default connection |
| Broker | Principals + ACLs, tenant on events | as pool | Own namespace or cluster | A shared broker when the model silos it |
| Network | Zero trust | Zero trust | Default-deny between tenants | A flat network across silos |
| Telemetry | Tenant attributes, bounded metrics | as pool | Scoped per silo | Raw tenant data pooled when a contract forbids it |
