# When gRPC, and Where It Stops

Reference for `grpc-contract-design` step 2 and step 8. Grounded in `grpc-up-and-running` (contract-first protobuf, internal gRPC with REST kept for public and browser callers, the HTTP/2 balancing caveat) and Ford's *The Hard Parts* (static coupling: a strict typed contract couples producer and consumer more than a loose one). Design level only; the server and client code are `go-grpc-handler` and `python-grpc-handler`.

## REST is the default; gRPC is chosen per boundary

The plugin's default interface is REST with an OpenAPI contract (`api-contract-design`). gRPC is adopted for one boundary at a time, for a named reason, not as a wholesale migration.

| gRPC fits | REST and OpenAPI fit |
|---|---|
| Internal service-to-service traffic | A public, browser-facing or partner-facing API |
| A strict typed contract across services is wanted | Consumers expect JSON and a human-readable spec |
| Streaming (server, client or bidirectional) is a real need | Simple request and response at the edge |
| High-throughput internal calls | A product owner must review the contract as a document |

- **Inside one deployable there is no boundary.** Modules of a lean modular monolith are one process; a plain call has none of gRPC's cost, so no gRPC there. Revisit when a module becomes its own service.
- **Browsers** cannot speak native gRPC without a gRPC-Web proxy, and partners expect JSON, so public callers stay on REST. A service may expose both: REST at the edge, gRPC between services.
- **Name the reason** in the Integration Design row for the boundary. "It is faster" with no measured need is not a reason.

## Contract strictness (static coupling)

A Protobuf contract is a strict, typed contract. It catches a break at compile time, but it also couples every producer and consumer pair to the same schema (Ford). Record that in the Integration Design's contract strictness column, and accept the obligations it brings:
- field numbers are permanent and removals are `reserved`;
- a breaking redesign is a new major package run beside the old;
- compatibility is gated by a breaking-change check in CI, not by memory.

A loose JSON contract with a tolerant reader evolves more freely and is riskier at runtime; neither is better in general. The choice is a trade-off recorded, not a default.

## Retries and call shape

A unary call that is safe to repeat can be retried on `UNAVAILABLE` with backoff; one that is not idempotent needs an idempotency key in the request or no automatic retry. A half-consumed stream cannot simply be retried: the client must resume from a known point. Streaming is chosen only when the data flow is a stream (`./streaming-and-errors.md`).

## Load balancing

gRPC multiplexes many requests over one long-lived HTTP/2 connection. Connection-level (layer 4) balancing therefore pins all of a client's traffic to one backend. gRPC needs per-request balancing, from a mesh proxy or a gRPC-aware balancer. This is a platform concern: state the requirement in the design and hand it to the platform skills; do not design it here.

## Identity

Metadata carries the credential and trace context. The credential is verified by every service itself; a mesh or gateway is only the first check, because a request can reach a service without passing through it. The caller's identity, and the tenant if the product is multi-tenant, are taken from the verified token, never from a field in the request body, which a caller can forge. Tenancy is mentioned only for a multi-tenant product and follows `multi-tenancy-design`.
