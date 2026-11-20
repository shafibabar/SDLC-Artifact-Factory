# One Worked Example: Kong

Reference for `api-gateway-design`. Kong is one gateway product, used here because its documentation is the research the skill draws on (`api-gateway-patterns`, a synthesis of Kong's documentation, Newman and Xu). It is **not** the plugin's default: the tech-stack defaults name no gateway, so Kong is the choice only when it is the agreed product, or a proposal pending an ADR. The role generalises to any gateway (Envoy-based, Traefik, NGINX ingress, Gateway-API implementations); choose the lighter one if it meets the same edge-policy and declarative-config needs. No version numbers or benchmarks are asserted; every feature named is a long-standing, documented Kong capability.

## The plugin model

Kong's core is a thin reverse proxy; all behaviour is plugins, units of policy that are configured, not coded. A plugin attaches to one of four scopes, broadest to narrowest: global, a service (one upstream), a route (one path or host), or a consumer (one identified caller). The narrower scope wins where they overlap.

| Family | Examples | Use for |
|---|---|---|
| Authentication | `key-auth`, `jwt`, `oauth2`, `openid-connect` | validate the credential and set the consumer; never authorization |
| Traffic control | `rate-limiting`, `request-size-limiting`, `proxy-cache` | protect shared edge capacity |
| Transformation | `request-transformer`, `response-transformer` | generic hygiene only (a request id, stripped internal headers) |

A consumer is an identified caller (an API key or a partner). Scope a plugin to a consumer for a per-caller limit; model consumers per tenant only when the product is multi-tenant.

## Database-less and declarative

Run Kong without its control-plane database, loading its configuration from a declarative file at start: no stateful gateway datastore to back up, the file is the source of truth, and a pod is disposable.

Out of the cluster, **decK** manages the whole configuration as one file, diffed and synced against a running gateway: a `diff` in CI is the reviewable edge-policy delta, a `sync` applies it, a `validate` checks the file. In a cluster, the **Kong Ingress Controller** takes configuration as Kubernetes resources (an `Ingress` or `HTTPRoute`, plus plugin and consumer resources) reconciled from Git by the same flow as the rest of the platform.

## A declarative sketch (decK form)

```yaml
_format_version: "3.0"
services:
  - name: orders-api
    url: http://orders-api.internal:8080
    routes:
      - name: orders-route
        paths: ["/v1/orders"]
    plugins:
      - name: jwt                    # validates who; authorization stays in the service
      - name: rate-limiting          # an edge limit; the service has its own endpoint limits
        config:
          minute: 600
          policy: redis              # a shared store, so the limit holds across gateway instances
plugins:
  - name: prometheus                 # edge metrics into the existing stack
    config:
      status_code_metrics: true
      latency_metrics: true
      per_consumer: true
```

The rate-limiting `policy: redis` line is the shared-store decision from `./rate-limiting.md` expressed in this product; a `local` policy would make each gateway instance enforce its own count.

## In-cluster, as resources

A plugin is a Kubernetes resource bound to an ingress or service by annotation, and a consumer is a resource too; both live in Git and are reconciled, so a new route or a changed limit is a reviewed diff. TLS terminates at the gateway through the ingress's certificate.

## Checklist for this product

- the database-less mode is on, and the declarative file is the source of truth;
- every route and plugin exists in Git (resources or a decK file), with no admin-API mutation;
- a diff is the reviewed change before merge;
- the authentication plugin validates and rejects anonymous traffic and carries no authorization logic;
- consumers and consumer-scoped limits are per caller, per tenant only for a multi-tenant product;
- the metrics plugin is on and traces are exported to the tracing backend.
