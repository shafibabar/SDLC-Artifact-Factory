# Call Shapes, Errors, Deadlines and Metadata

Reference for `grpc-contract-design` steps 5 to 8. Grounded in `grpc-up-and-running` (the four patterns, the status-code model, deadlines, metadata, interceptors). Design level only: the server and client code, the interceptors and the status writer are `go-grpc-handler` and `python-grpc-handler`. `.proto` fragments are the contract.

## The four call shapes

The shape is chosen per method with the `stream` keyword on the request, the response or both.

```protobuf
service ShipmentService {
  rpc GetShipmentStatus(GetShipmentStatusRequest) returns (ShipmentStatus);                       // unary
  rpc WatchShipments(WatchShipmentsRequest) returns (stream ShipmentEvent);                       // server streaming
  rpc UploadManifest(stream ManifestChunk) returns (UploadReceipt);                               // client streaming
  rpc TrackLive(stream TrackPing) returns (stream TrackUpdate);                                   // bidirectional
}
```

| Shape | Choose when | Example | Cost |
|---|---|---|---|
| **Unary** (1 to 1) | request and response, point reads, commands: the default | `GetShipmentStatus` | none |
| **Server streaming** (1 to N) | a large or open-ended result the client benefits from as it is produced | a feed of shipment events | the client handles partial results and mid-stream errors |
| **Client streaming** (N to 1) | a large request assembled server-side | a chunked manifest upload | the server holds partial state until the client finishes |
| **Bidirectional** (N to N) | both sides send independently over one long connection | a live tracking channel | hardest to balance and retry; needs explicit flow control |

**Default to unary.** A method earns a stream only when the data flow *is* a stream: a very large or unbounded result, a chunked upload or a live channel. Streaming complicates retries (a half-consumed stream cannot be blindly repeated), load balancing and back-pressure. Paging a list through repeated unary calls is usually simpler than streaming it.

## The status-code model

Every call ends with a status: a **code**, a message and optional details. It is transport-independent and finer than HTTP status.

| Code | Meaning | Retryable |
|---|---|---|
| `OK` | success | n/a |
| `CANCELLED` | the caller cancelled | no |
| `UNKNOWN` | an error surfaced without a code | no |
| `INVALID_ARGUMENT` | wrong regardless of system state | no |
| `DEADLINE_EXCEEDED` | the deadline passed before completion | maybe, if idempotent |
| `NOT_FOUND` | the entity does not exist | no |
| `ALREADY_EXISTS` | a create conflicts with an existing entity | no |
| `PERMISSION_DENIED` | authenticated, not authorised | no |
| `RESOURCE_EXHAUSTED` | quota or rate limit | maybe, with backoff |
| `FAILED_PRECONDITION` | the system is not in the required state | no, fix the state first |
| `ABORTED` | a concurrency conflict | yes, retry the whole transaction |
| `OUT_OF_RANGE` | past the valid range | no |
| `UNIMPLEMENTED` | the method is not supported | no |
| `INTERNAL` | a genuine bug: an invariant broke | no |
| `UNAVAILABLE` | transient: down or overloaded | yes, with backoff |
| `DATA_LOSS` | unrecoverable loss or corruption | no |
| `UNAUTHENTICATED` | credentials missing or invalid | no |

**`INVALID_ARGUMENT` versus `FAILED_PRECONDITION` versus `OUT_OF_RANGE`** all become `400` in REST, but here they differ and clients act on the difference: `INVALID_ARGUMENT` is wrong in every state (retrying the same request always fails); `FAILED_PRECONDITION` would be fine in another state (the client can succeed once the state changes); `OUT_OF_RANGE` is a specific "past the end" a client can detect and stop on.

**One mapping place.** Domain errors map to codes in a single place, as the REST edge maps to HTTP status through one error writer. A domain condition gets a specific code; `INTERNAL` is for genuine bugs, and an unexpected error returns a generic message while the detail goes to logs. Internal error text never crosses the boundary.

## Structured error details

Beyond code and message, a status carries machine-readable details (`google.rpc.Status` with typed detail messages):

| Detail | Carries |
|---|---|
| `ErrorInfo` | a stable `reason` string, a `domain` and a metadata map: the primary machine-readable "why" |
| `BadRequest` | field violations: the analogue of REST's `details` array |
| `PreconditionFailure` | what state check failed; pairs with `FAILED_PRECONDITION` |
| `QuotaFailure` | which quota; pairs with `RESOURCE_EXHAUSTED` |
| `RetryInfo` | how long to wait before retrying |
| `RequestInfo` | a request id for support and tracing |

Prefer `ErrorInfo.reason` as the stable programmatic contract; the human message may be reworded freely.

## Deadlines

A **deadline** is an absolute time the client sets and gRPC propagates to the server, which can see it and stop work. It is not a client-local timeout, which the server never learns about.
- Every client call carries a deadline.
- The server derives every downstream call (database, another service) from the incoming context, so the deadline and cancellation flow through.
- A finished context is a hard stop: abandon long loops and streaming sends.
- A server never starts a new timeout that outlives the incoming deadline: that orphans work no one is waiting for.

## Metadata

Metadata is the key and value header and trailer channel, where the credential, tenancy and tracing ride.

| Key | Carries | Notes |
|---|---|---|
| `authorization` | the bearer token | verified by an interceptor in every service; the method reads claims from the verified context |
| a tenant key | the tenant claim | only for a multi-tenant product; taken from the verified token, never from the request body |
| `traceparent`, `tracestate` | trace context | propagated so spans join across services |
| keys ending `-bin` | binary values | base64-encoded on the wire |

Cross-cutting concerns (token verification, logging, metrics, tracing, panic recovery) belong in interceptors, so each method stays thin: decode, validate, apply the domain, encode.
