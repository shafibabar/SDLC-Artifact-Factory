---
name: grpc-contract-design
description: >
  Decide whether a service boundary should be gRPC at all, then design its
  contract first as a protobuf3 file: gRPC chosen per boundary for a named
  reason (internal service-to-service, a strictly typed contract, streaming,
  throughput) with REST and OpenAPI kept for browser, public and partner
  callers and no gRPC inside one deployable; field numbers as the permanent
  wire identity (never reuse or renumber, reserved on removal, new fields with
  fresh numbers, optional where set differs from zero); a package that carries
  the major version; unary by default and a streaming shape only when the data
  flow is a stream; gRPC's own status codes mapped from domain errors in one
  place; a deadline on every call; the token verified by every service; and a
  breaking-change check that gates the proto in CI. Use when designing,
  reviewing or changing a .proto contract or choosing gRPC over REST. Used by
  enterprise-architect.
version: 2.0.0
phase: design
owner: enterprise-architect
created: 2026-07-31
tags: [design, architecture, grpc, protobuf, contract-first, streaming, compatibility]
produces: grpc-service-contract
domain: architecture
status: stable
related: [api-contract-design, integration-design, container-diagram, go-grpc-handler, python-grpc-handler, multi-tenancy-design, api-gateway-design, glossary-management, methodology-review]
sources:
  - research/software-architecture/grpc-up-and-running.md
  - research/software-architecture/software-architecture-hard-parts-ford.md
---

# gRPC Contract Design

## Purpose

A gRPC API is a `.proto` file: the service and message definitions are the contract, and the client and server stubs are generated from it, so code cannot drift from the schema. The strictness cuts both ways: a typed contract couples producer and consumer more tightly than loose JSON (Ford's static coupling), and a careless edit to a field number silently corrupts deployed peers. This skill decides whether a boundary should be gRPC, then makes the contract a reviewed, gated artifact. **Readers:** enterprise-architect, backend-engineer, the product owner (what a contract change costs its callers). **Question:** for this boundary, is gRPC justified, and what may and may not change in the contract?

The output is `design/<service>/<name>.proto` per service that exposes gRPC (`./templates/service.proto`); it is optional, and normally absent at lean. REST with OpenAPI is `api-contract-design`; the server and client code are `go-grpc-handler` and `python-grpc-handler`.

| Profile | What this holds |
|---|---|
| Lean | Normally nothing: one deployable has no service boundary, so a plain call is enough. A proto only if a boundary really is separate, and then one short service |
| Standard | A proto for each internal service that earns gRPC, with the call pattern and error mapping for each method |
| Enterprise | As standard, plus the compatibility gate in CI, the version policy per package, and the consumers that must be told of a change |

## Procedure

1. **Read** the container diagram (which arrows cross a service boundary and who calls them), the Integration Design (its contract strictness column), the Command Catalog and Read Models, the NFR specification (throughput, latency), and `sdlc-config.json`.
2. **Decide whether the boundary is gRPC** (`./references/when-grpc-and-boundaries.md`): REST is the default; gRPC only for an internal service-to-service call with a named reason (a strict typed contract, streaming, throughput). Browser, public and partner callers stay on REST and OpenAPI. Inside one deployable there is no boundary. Record the contract's strictness in the Integration Design.
3. **Write the proto first.** `syntax = "proto3"`, a package ending `.vN`, services and messages named from the Ubiquitous Language, not storage columns (`./references/protobuf-design-and-compat.md`).
4. **Number the fields deliberately:** the number is the wire identity and permanent from the first review. 1 to 15 for hot fields, gaps left on purpose, `optional` where "not set" differs from the zero value, an `_UNSPECIFIED` zero value on every enum.
5. **Choose each method's shape** (`./references/streaming-and-errors.md`): unary unless the data flow is a stream (a large or open-ended result, a chunked upload, a live channel).
6. **Map errors** to gRPC status codes from one place: `INVALID_ARGUMENT` for a request wrong in any state, `FAILED_PRECONDITION` for the wrong state, `NOT_FOUND`, `ALREADY_EXISTS`, `PERMISSION_DENIED`; `INTERNAL` only for a real bug. Structured details carry the machine-readable reason; internal error text never crosses the boundary.
7. **Set deadlines:** every client call has a deadline, and a server honours it by passing the incoming context on; a deadline is not a client-local timeout.
8. **Identity:** metadata carries the token and trace context; every service verifies the token itself (a mesh or gateway is only the first check), and the caller's identity, and tenant if the product is multi-tenant, come from the verified token, never the request body.
9. **Gate compatibility:** a breaking-change check against the main branch in CI (Buf is the example tool). A breaking redesign is a new `.v2` package beside `.v1`.
10. **Validate and loop:** run `./scripts/validate-proto.sh <file.proto> [baseline.proto]`, fix every FAIL, re-run until clean; then `./resources/checklist.md`.
11. **Present** with the reason for every request declined (§ Gotchas). Always state: the proto is the contract, written first; field numbers are permanent (never reused or renumbered, `reserved` on removal); gRPC is for internal boundaries and REST for browser and public callers; a strict typed contract couples producer and consumer more tightly than loose JSON read by a tolerant reader (static coupling), so compatibility is enforced by a breaking-change check in CI, naming the consuming teams or services it protects; domain errors map to status codes through one place, with a stable `ErrorInfo` reason in the details and no internal text; and no implementation code appears in the answer. Answering in a reply: the declined requests and their reasons once, then the proto fragments once.

Examples: `./examples/01-lean-gift-registry-declined.md` (two modules in one deployable asking for gRPC), `./examples/02-standard-order-tracking-unary-and-stream.md` (an internal unary service plus a server-streaming feed), `./examples/03-enterprise-mixed-rest-and-grpc.md` (a public REST API over internal gRPC, a field removed safely and a breaking redesign as `.v2`).

## Gotchas

- **"Renumber field 3 to tidy the file."** *Reason:* the number is the wire identity; every deployed peer keeps decoding the old number into the old meaning. *Instead:* never renumber; only append with a fresh number.
- **"Delete the field; nobody uses it."** *Reason:* a later edit can reuse its number and silently corrupt old peers. *Instead:* delete it and `reserved` its number and its name.
- **"Change the field's type in place."** *Reason:* an incompatible type breaks decoding, and even a wire-compatible one can truncate values. *Instead:* a new field with a fresh number, or a new `.v2` package for a breaking redesign.
- **"Return INTERNAL for not-found."** *Reason:* it hides real bugs among expected conditions and tells the client nothing it can act on. *Instead:* `NOT_FOUND`; `INTERNAL` only for a genuine bug.
- **"Set a 2-second timeout in the client."** *Reason:* the server never learns it, and keeps working after the caller gave up. *Instead:* a deadline on the call, honoured server-side.
- **"Make every list call a streaming RPC."** *Reason:* streaming complicates retries, load balancing and back-pressure. *Instead:* unary by default; a stream only for a genuinely large, open-ended or live flow.
- **"Use gRPC for the browser app and the partner API."** *Reason:* browsers need a gRPC-Web proxy and partners expect JSON. *Instead:* REST and OpenAPI for public callers; gRPC internally.
- **"gRPC between the modules; it's faster."** *Reason:* modules of one deployable are one process, not a service boundary; a plain call has none of the cost. *Instead:* a plain call; revisit when a module becomes its own service.
- **"The metadata tenant key drives isolation."** *Reason:* isolation is not a plugin requirement, and a tenant taken from the request body can be forged. *Instead:* take identity and any tenant from the verified token, only for a multi-tenant product (`multi-tenancy-design`).
- **"The mesh balances gRPC for us."** *Reason:* gRPC keeps one long HTTP/2 connection, so connection-level balancing pins all traffic to one backend. *Instead:* per-request balancing is a platform requirement; state it in the design and hand it to the platform skills.

## References

| Question | File |
|---|---|
| Choosing gRPC over REST, boundaries, contract strictness, balancing and identity | `./references/when-grpc-and-boundaries.md` |
| Authoring the proto, field numbers, presence, breaking versus non-breaking, packages, the CI gate | `./references/protobuf-design-and-compat.md` |
| Call shapes, status codes, error details, deadlines, metadata | `./references/streaming-and-errors.md` |
| The artifact | `./templates/service.proto` |
| Checking before hand-off | `./resources/checklist.md` |
