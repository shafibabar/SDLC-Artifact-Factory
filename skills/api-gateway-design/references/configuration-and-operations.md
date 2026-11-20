# Configuration and Operations

Reference for `api-gateway-design` steps 8 and 9. Grounded in `api-gateway-patterns` (declarative configuration, a stateless gateway, edge telemetry into the existing stack). Design level only: product-specific files are in `./kong-example.md`.

## Configuration is files in version control

The gateway's whole routing and policy surface is declared in files that live in version control: routes, upstreams, plugins or policies, credentials' references (never the secrets). A change is a pull request. It is never a live edit in an admin interface or a call to the gateway's admin API, because a live edit is unreviewed, unrecorded, and lost or overwritten at the next deployment.

- **The reviewed diff.** Before a change ships, a diff of the proposed files against the running gateway is produced in CI and reviewed, the way an infrastructure plan is reviewed: the reviewer sees the exact edge-policy delta.
- **One source of truth.** The files are reconciled to the gateway by the same delivery flow as the platform's other configuration (`gitops-workflow`), so the gateway can always be rebuilt from the repository.
- **Secrets by reference.** Keys and certificates are injected from the secrets store; the files hold references, not values (`secrets-management`).

## During an incident

The same path, faster: an expedited review of a change to the files, or a rollback to the previous reviewed files. A live edit in the admin interface is still not the incident tool; it leaves the running gateway different from the repository, so the next deployment silently undoes the fix or the repository is wrong.

## A stateless gateway

Run the gateway so that a pod carries no state a restore plan must cover: configuration is loaded from the declarative files at start, and a pod can be killed and replaced. Where the product has a database-backed mode, prefer its file-based, database-less mode. Shared counters for rate limits live in a store designed for them, not in the gateway process (`./rate-limiting.md`).

## The gateway is a single entry point

Because all client traffic passes through it, the gateway is a point of failure: run more than one instance behind the load balancer, and roll out configuration changes gradually where the product allows it (one instance or region first, with a quick rollback to the previous reviewed files). State the replica count and the rollback in the design document; an enterprise product states it per region.

## Edge telemetry into the existing stack

Do not build a separate pane for the edge. Send request logs, latency, status-code rates (4xx and 5xx) and throughput per caller to the observability stack the services already use (`opentelemetry-instrumentation`), with the trace id propagated so an edge request can be followed into the services. Alert on the 5xx rate, the `429` rate and the latency at the edge.

## Change checklist

1. The change is a pull request against the gateway files; no live edit was made.
2. A diff against the running gateway was produced and reviewed.
3. Authentication still only validates; no authorization or business rule was added.
4. Any new limit names its algorithm, key, layer and store.
5. Telemetry still covers the new route.
6. The previous reviewed files are the rollback.
