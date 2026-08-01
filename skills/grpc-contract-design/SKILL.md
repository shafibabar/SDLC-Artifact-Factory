---
name: grpc-contract-design
description: >
  Teaches the enterprise-architect to design gRPC service contracts —
  protobuf3 service and message definition, field numbering and the
  backward/forward compatibility rules (never reuse or renumber a field
  number, reserved, optional/repeated presence), the four communication
  patterns (unary, server-streaming, client-streaming, bidirectional) and
  when each fits, the gRPC status/error code model versus HTTP status,
  deadlines and metadata, and the "gRPC internal vs REST public" boundary.
  The contract-first gRPC analog of api-contract-design (which owns
  REST/OpenAPI). Covers .proto authoring, enum/oneof/well-known-types,
  breaking-vs-nonbreaking change classification, and CI breaking-change
  linting. Used during Design for internal service-to-service gRPC APIs.
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-07-31
tags: [design, architecture, grpc, protobuf, contract-first, streaming, api]
produces: grpc-service-contract
domain: architecture
status: stable
related: [api-contract-design, go-grpc-handler, go-openapi-codegen, integration-design]
---

# gRPC Contract Design

## Purpose

gRPC is contract-first by construction: the API *is* a `.proto` file. `service` blocks declare RPC methods, `message` blocks declare request/response types, and both server stubs and client stubs are generated from it by `protoc`. The generated code cannot drift from the schema because it is compiled from the schema — a breaking proto change surfaces as a compile break, not a production error.

This is the gRPC analog of `api-contract-design`, which owns REST/OpenAPI. Where OpenAPI is *authored as* the contract and handlers are hand-written against it, the proto is the single source of truth and the strongly-typed Go client/server is generated. Use this skill during Design for **internal service-to-service** APIs; keep public and browser-facing surfaces on REST+OpenAPI (see the boundary section).

---

## Write the Proto First

Author `service` + `message` before any implementation. Every proto declares `syntax = "proto3";`, a `package`, and `option go_package`. Message field names come from the Ubiquitous Language (`tenant_id`, `data_asset`, `sensitivity_level`), never from storage columns.

```protobuf
syntax = "proto3";
package dataestate.asset.v1;
option go_package = "github.com/acme/dataestate/gen/asset/v1;assetv1";

service DataAssetService {
  rpc GetDataAsset(GetDataAssetRequest) returns (DataAsset);
}

message GetDataAssetRequest {
  string tenant_id = 1;
  string data_asset_id = 2;
}
```

The proto is reviewed with the same seriousness as an OpenAPI spec — field numbering is treated as permanent from the first review. Full worked `DataAssetService`, enum/oneof/well-known-types, and the versioning package convention: `references/protobuf-design-and-compat.md`.

---

## Field Numbers Are the Wire Contract

The integer tag on each field — `string tenant_id = 2;` — is the actual wire identifier. The **name** is not encoded; the number is. Every compatibility rule follows from this:

| Rule | Why |
|---|---|
| **Never reuse** a field number for a different field | Old clients decode the new field into the old field's slot — silent data corruption |
| **Never renumber** an existing field | Changes its wire identity; every deployed peer breaks |
| **Never change a field's type** except within the wire-compatible set | The decoder mis-parses the bytes |
| **`reserved`** the number (and name) of any removed field | Prevents a future edit from silently re-homing that number |
| **Add new fields with fresh numbers** and a sane zero-value | Unknown fields are preserved on the wire → forward compatibility; new fields default cleanly → backward compatibility |

House rule: reserve field numbers 1–15 (one wire byte) for hot, frequently-set fields; leave intentional gaps. proto3 scalars are non-presence-tracking by default — `optional` restores explicit presence (distinguish set-to-zero from unset), `repeated` denotes a list. The full breaking-vs-nonbreaking change table and the `reserved` mechanics live in `references/protobuf-design-and-compat.md`.

---

## Choose the Communication Pattern from the Data Flow

gRPC exposes exactly four method shapes, selected per method with the `stream` keyword:

| Pattern | Shape | Use when | Data-estate example |
|---|---|---|---|
| **Unary** | 1 req → 1 resp | Request/response commands, point reads. The default. | `GetDataAsset`, `ClassifyDataAsset` |
| **Server streaming** | 1 req → stream of resp | Large or open-ended result sets emitted as produced | Estate scan streaming assets as discovered |
| **Client streaming** | stream of req → 1 resp | Large uploads assembled server-side | Chunked document ingest |
| **Bidirectional** | independent read + write streams | Live, concurrent progress or control channels | Live scan-progress channel |

Default to unary unless streaming earns its keep — streaming complicates load balancing and retries. Worked proto for each pattern and the selection reasoning: `references/streaming-and-errors.md`.

---

## The Status-Code Model Is gRPC's Own, Not HTTP's

Every call completes with a gRPC status **code** (an enum), a message, and optional structured details. These are transport-independent and finer-grained than HTTP status — `INVALID_ARGUMENT`, `FAILED_PRECONDITION`, and `OUT_OF_RANGE` all collapse to `400` in REST but are distinct here.

| gRPC code | Use for |
|---|---|
| `OK` | Success |
| `INVALID_ARGUMENT` | Malformed request, independent of system state |
| `FAILED_PRECONDITION` | Request invalid for the current system state |
| `NOT_FOUND` | Resource does not exist |
| `ALREADY_EXISTS` | Create conflicts with an existing resource |
| `PERMISSION_DENIED` | Authenticated but not authorized |
| `UNAUTHENTICATED` | Missing/invalid credentials |
| `RESOURCE_EXHAUSTED` | Quota / rate limit |
| `DEADLINE_EXCEEDED` | Deadline passed before completion |
| `UNAVAILABLE` | Transient — client may retry with backoff |
| `INTERNAL` | Genuine server bug (reserve for this) |

Map domain errors to codes through **one** status writer, never leaking internal error strings; reserve `INTERNAL` for real bugs and prefer `INVALID_ARGUMENT`/`FAILED_PRECONDITION`/`NOT_FOUND` for domain conditions. The full code taxonomy, structured error details (`google.rpc.Status`/`ErrorInfo`), and deadline/metadata conventions: `references/streaming-and-errors.md`.

---

## Deadlines and Metadata Are Part of the Call

- **Deadline** — an absolute time propagated to the server, which sees `DEADLINE_EXCEEDED` and should stop work. Set one on every client call; honor it server-side by deriving downstream `context.Context` from the incoming one so cancellation propagates. A deadline is not an ad-hoc client-local timeout.
- **Metadata** — the key/value header/trailer channel (the analog of HTTP headers) carrying the auth token, the tenant claim, and OpenTelemetry trace context. Read and written via context.

---

## gRPC Internal vs REST Public — the Boundary

| Use gRPC when | Use REST + OpenAPI when |
|---|---|
| Internal service-to-service traffic | Public or browser-facing API |
| Streaming (any of the four patterns) is needed | Simple request/response over the public edge |
| Strong typing across a Go↔Go boundary matters | Third-party/partner consumers expect JSON |
| High-throughput internal chatter | A human or PM must review the contract as a spec |

Browsers cannot speak native gRPC without a gRPC-Web proxy; this product's external/data-estate API stays REST+OpenAPI (`api-contract-design`). Adopt gRPC per-boundary where typing/streaming earns its cost — not as a wholesale migration. **Mesh caveat:** gRPC multiplexes many requests over one long-lived HTTP/2 connection, so a plain Kubernetes `Service` (L4/connection balancing) pins all traffic to one backend pod. Linkerd's proxy does per-*request* L7 balancing over HTTP/2 — this is precisely why the mesh matters for gRPC.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Ubiquitous Language messages | Message/field names from domain language | Storage column names |
| Field numbers permanent | No reuse/renumber; removed fields `reserved` | A number silently re-homed |
| Presence explicit where it matters | `optional` used where set-vs-unset differs from zero | Zero-value ambiguity on a meaningful field |
| Pattern fits the data flow | Streaming only where it earns its keep; unary default | Streaming by habit; unary for an open-ended result set |
| Errors mapped deliberately | Domain errors → specific gRPC codes via one writer | `INTERNAL` for domain conditions; leaked error strings |
| Deadlines honored | Downstream context derived from incoming; done = hard stop | Ad-hoc timeouts; ignored cancellation |
| Boundary respected | gRPC internal, REST public/browser | Public browser API on native gRPC |
| Breaking changes gated | Buf (or equivalent) breaking-change lint in CI | Compatibility remembered, not enforced |

---

## Codify Compatibility as a CI Check

Run a schema-diff/breaking-change linter (e.g. **Buf** — `buf lint` and `buf breaking` against the `main` baseline) in CI so the field-number rules are enforced, not remembered. The per-edit checklist — reuse/renumber? reserved on removal? type change within the wire-compatible set? additive with a sane default? — and the exact Buf rule categories are in `references/protobuf-design-and-compat.md`.

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Renumbering to "tidy" fields** | Field numbers are the wire identity; every peer breaks | Numbers are permanent; only append with fresh numbers |
| **Reusing a removed field's number** | Old clients decode into the wrong slot — silent corruption | `reserved` the number and name on removal |
| **Streaming by default** | Complicates balancing, retries, backpressure for no gain | Unary unless the data flow genuinely streams |
| **HTTP status thinking** | Collapses `INVALID_ARGUMENT`/`FAILED_PRECONDITION`/`OUT_OF_RANGE` into `400`, losing RPC semantics | Map domain errors to specific gRPC codes |
| **`INTERNAL` for domain errors** | Hides real bugs among expected conditions; clients can't react | Reserve `INTERNAL` for bugs; use domain-specific codes |
| **Client-local timeout instead of deadline** | Server keeps working after the client gave up | Set a deadline; propagate context; stop on cancellation |
| **gRPC on the public browser edge** | Browsers need a gRPC-Web proxy; partners expect JSON | REST+OpenAPI for public/browser; gRPC internal |
| **Plain K8s Service for gRPC** | L4 balancing pins one HTTP/2 connection to one pod | Linkerd per-request L7 balancing (or a gRPC-aware LB) |

---

## References

- `references/protobuf-design-and-compat.md` — worked `.proto` for a `DataAssetService`, field-numbering and `reserved` mechanics, the breaking-vs-nonbreaking change classification table, `enum`/`oneof`/well-known-types, package/versioning convention, and the Buf CI lint rule categories.
- `references/streaming-and-errors.md` — the four communication patterns with worked proto and a selection guide, the full gRPC status-code taxonomy, structured error details (`google.rpc.Status`, `ErrorInfo`), and the deadline/metadata conventions with Go snippets.
