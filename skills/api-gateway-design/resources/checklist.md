# Checklist: API Gateway Design

Resource for `api-gateway-design`. Run after `./scripts/validate-api-gateway-design.sh` is clean; the script checks structure, this list checks judgement.

## Need and placement
- [ ] The design starts from the container diagram's gateway section; it does not redo placement.
- [ ] A single application has no gateway: the ingress routes to it and it validates tokens itself; the condition that would change this is named.
- [ ] The gateway product is the agreed one, or a proposal pending an ADR; no default is assumed.

## Edge policy
- [ ] Every route names its upstream, owner and auth requirement from the API contract.
- [ ] Authentication only validates who the caller is and rejects anonymous traffic.
- [ ] No authorization, no business rule and no aggregation of several services sits in the gateway; aggregation is a backend-for-frontend behind it.
- [ ] Transforms are generic: a request id, stripped internal headers, an oversized-body rejection.
- [ ] The gateway and the mesh are both present where both exist; neither is offered as a substitute for the other.

## Zero trust
- [ ] Every service verifies identity and decides authorization itself.
- [ ] A header the gateway adds is never trusted on its own.

## Rate limits
- [ ] Each limit names its algorithm and why, its key, its number and burst, and its layer.
- [ ] Limits exist at the edge and, for endpoint-specific cases, at the service.
- [ ] A distributed limit names the shared store and the single atomic operation; the failure behaviour of the store is stated.
- [ ] A rejection returns `429` with a retry hint.
- [ ] Limits are per caller or key; per tenant only for a multi-tenant product.

## Operation
- [ ] Configuration is declarative, in version control, with a diff reviewed before a change ships.
- [ ] The gateway is stateless; replicas and rollback are stated (per region at enterprise).
- [ ] No live edit in an admin interface or API; an incident uses an expedited review or a rollback.
- [ ] Telemetry goes into the existing observability stack, with alerts on the 5xx rate, the 429 rate and latency.

## Scope
- [ ] No implementation code appears in the design or the answer.
