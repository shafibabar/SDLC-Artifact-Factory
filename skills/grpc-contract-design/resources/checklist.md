# Checklist: gRPC Contract

Resource for `grpc-contract-design`. Run after `./scripts/validate-proto.sh` is clean (with the baseline when editing an existing proto); the script checks structure, this list checks judgement.

## The boundary
- [ ] The boundary is a service-to-service call with a named reason (a strict typed contract, streaming, throughput); no gRPC inside one deployable.
- [ ] Browser, public and partner callers stay on REST and OpenAPI.
- [ ] The Integration Design records the contract's strictness (a strict typed contract couples producer and consumer more tightly).

## The contract
- [ ] The proto is written first; names come from the Ubiquitous Language, not storage columns.
- [ ] The package ends in a major version (`.vN`); a breaking redesign is a new package beside the old.
- [ ] Every field number is permanent: none reused, none renumbered; a removed field's number and name are `reserved`.
- [ ] Hot fields use 1 to 15; `optional` is used where unset differs from the zero value.
- [ ] Every enum has a `*_UNSPECIFIED = 0` zero value.
- [ ] Each method has its own request and response message.
- [ ] A type change is a new field with a fresh number, or a new package; never in place.

## Calls and errors
- [ ] Every method is unary unless the data flow is genuinely a stream (large, open-ended, chunked or live).
- [ ] Domain errors map to specific status codes through one place; `INTERNAL` only for a real bug; no internal error text crosses the boundary.
- [ ] Machine-readable reasons are carried as structured details.
- [ ] Every client call has a deadline, and servers pass the incoming context on.

## Identity and platform
- [ ] Every service verifies the token itself; a mesh or gateway is only a first check.
- [ ] Identity, and the tenant if the product is multi-tenant, come from the verified token, never the request body.
- [ ] Per-request load balancing is stated as a platform requirement and handed to the platform skills.

## Gate and scope
- [ ] A breaking-change check against the main branch runs in CI.
- [ ] No implementation code appears in the contract or the answer; the code is `go-grpc-handler` and `python-grpc-handler`.
