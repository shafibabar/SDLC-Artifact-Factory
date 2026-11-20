# Protobuf Design and Compatibility

Reference for `grpc-contract-design` steps 3, 4 and 9. Grounded in `grpc-up-and-running` (protobuf3, field numbers as the wire contract, the compatibility checklist, a schema-diff linter in CI). The `.proto` fragments below are the contract itself, not implementation code.

## A worked contract

```protobuf
syntax = "proto3";

package shop.orders.v1;

import "google/protobuf/timestamp.proto";

// An INTERNAL service-to-service API. Public and browser callers use REST (api-contract-design).
service OrderService {
  rpc GetOrder(GetOrderRequest) returns (GetOrderResponse);
  rpc CancelOrder(CancelOrderRequest) returns (CancelOrderResponse);
}

message Order {
  string order_id = 1;            // 1 to 15 take one wire byte: hot fields go here
  string customer_id = 2;
  OrderStatus status = 3;
  google.protobuf.Timestamp placed_at = 4;
  repeated OrderLine lines = 5;
  optional string cancel_reason = 6;   // optional: unset differs from ""

  // 7 was `legacy_ref` (string), removed. Never reuse it.
  reserved 7;
  reserved "legacy_ref";
}

enum OrderStatus {
  ORDER_STATUS_UNSPECIFIED = 0;   // the zero value is a safe "unknown"
  ORDER_STATUS_PLACED = 1;
  ORDER_STATUS_SHIPPED = 2;
  ORDER_STATUS_CANCELLED = 3;
}

message OrderLine {
  string sku = 1;
  int32 quantity = 2;
}

message GetOrderRequest { string order_id = 1; }
message GetOrderResponse { Order order = 1; }
message CancelOrderRequest { string order_id = 1; string reason = 2; }
message CancelOrderResponse { Order order = 1; }
```

The messages are named from the Ubiquitous Language, not storage columns. Each method has its own request and response message so it can grow without a break. A language-specific option (a Go package path, a Java package) is added per stack by the code skills, not decided here.

## Field numbers are permanent

The number after `=` is the wire identifier: a field is encoded as its number and wire type, and the name never appears on the wire. So:
- a peer keys entirely on the number; if a number's meaning changes, every deployed peer mis-decodes;
- a number a peer does not recognise is an unknown field, preserved so it can be re-emitted, which gives forward compatibility.

Numbering conventions: 1 to 15 encode in one byte, so keep them for hot, always-set fields; 16 to 2047 take two; 19000 to 19999 are reserved by protobuf and never used; leave deliberate gaps between logical groups.

**`reserved`:** when a field is removed, reserve its number and its name in the same message. The number stops a later edit from re-homing that tag onto a new field (corrupting old peers); the name stops the old name returning with a new number and breaking source and JSON consumers.

## Presence

| Declaration | Tracks presence | Use for |
|---|---|---|
| `string x = 1;` | No (unset equals `""`) | the zero value is a fine default |
| `optional string x = 1;` | Yes | "not set" means something different from the zero value |
| `repeated string x = 1;` | n/a | lists (empty list equals unset) |
| `map<string, string> x = 1;` | n/a | keyed collections |

Adding or removing `optional` on a scalar is wire-compatible but changes generated code: a source-compatibility review, not a wire break.

## Breaking or not

| Change | Breaking? | Notes |
|---|---|---|
| Add a field with a fresh number | No | old peers treat it as unknown |
| Add a method to a service | No | old clients never call it |
| Add an enum value | Usually no | old peers map it to the zero value; make the zero value a safe "unknown" |
| Remove a field and `reserved` its number and name | No on the wire | coordinate if a consumer required it |
| Rename a field (same number) | No on the wire, yes in source and JSON | the wire keys on the number |
| Reuse a removed or reserved number | **Yes** | old peers decode new bytes into the old field: silent corruption |
| Renumber a field | **Yes** | changes the wire identity |
| Change a type incompatibly (`string` to `int32`) | **Yes** | the decoder mis-parses |
| Change among varint types (`int32`, `int64`, `uint32`, `bool`) | Value-risky | same wire type but truncation and sign surprises; treat as breaking unless proven safe |
| Move a field into or out of a `oneof` | **Yes** | changes presence semantics |
| Delete a method | **Yes** | callers break |
| Change a method's request or response type | **Yes** | signature change |

Wire families, for judging an incompatible type change: varint (`int32`, `int64`, `uint32`, `uint64`, `sint*`, `bool`, enums), 64-bit (`fixed64`, `sfixed64`, `double`), length-delimited (`string`, `bytes`, messages, `repeated`), 32-bit (`fixed32`, `sfixed32`, `float`).

## Enums, oneof, well-known types

- **Enum:** declare a zero value named `*_UNSPECIFIED` so an unset or unknown value is a safe default, not an accidental real state; prefix values with the enum name.
- **`oneof`:** at most one member set; member numbers share the message's number space; moving a field in or out is breaking.
- **Well-known types:** prefer `Timestamp` for instants (never a raw epoch integer), `Duration` for spans, `FieldMask` for partial updates, and use `Struct` or `Any` only for a genuinely dynamic shape, since they defeat static typing.

## Packages and versions

The package carries the major version as its last segment (`shop.orders.v1`). A breaking redesign is a new package, `shop.orders.v2`, run beside `v1` until `v1` is retired. Within a major version only additive, non-breaking changes are allowed; anything marked breaking above forces a new package. One service per file is the default, and shared messages go in their own file and are imported. Generated code is never hand-edited.

## The CI gate

Compatibility is enforced, not remembered. A breaking-change check runs in CI against the main branch's protos and fails the build on a breaking change; **Buf** is the example tool (a lint step for style and a `breaking` step against the baseline, with rule categories from strictest, which flags source breaks and renames, to loosest, wire breaks only). A strict category is the safe default for an internal API with many consumers.

Per-edit checklist: (1) reusing or renumbering a field number: forbidden; (2) a removed field's number and name reserved: required; (3) a type change: only within a wire family and only if values are proven safe; (4) a new field additive, with a fresh number and a sane zero value; (5) the breaking-change check passes against main.
