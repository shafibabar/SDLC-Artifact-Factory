# Example 3 — Enterprise: A Public REST API over Internal gRPC, and a Safe Contract Change

Self-contained. **Dockside** is a port-berth booking platform. **Enterprise** profile, about a dozen services. Shipping lines book berths through a partner-facing API; internally the **Booking** service calls the **Berths** service. The Berths contract is live as `dockside.berths.v1` with three consuming teams.

## Input

> **User:** "Make the partner API gRPC too. Stream every list call. In `Berth`, delete `legacy_zone_code`, and change field 4, `length_m`, from int32 to a double so we can store 182.5 metres. Do it in place. The mesh authenticates callers, so services don't need to check tokens."

## Working it

- **Partner API:** stays REST with OpenAPI (`api-contract-design`): partners integrate with JSON tooling and browsers need a proxy for gRPC. gRPC is the Booking-to-Berths call only. Contract strictness is recorded in the Integration Design: a strict typed contract couples the three consuming teams to one schema.
- **Streaming every list call:** declined. Unary with pagination is the default; a bounded list of berths is unary. Only the live berth-occupancy feed is a genuine stream.
- **Delete `legacy_zone_code`:** allowed, with its number (3) **and** its name reserved in the same change, so no later edit re-homes the tag.
- **Field 4 type change in place:** declined as breaking. `int32` to `double` changes the wire type, and the three consumers would mis-decode. Instead, a **new field** `length_metres = 9` (double) is added with a fresh number; field 4 stays until consumers move, is then removed and reserved. A wholesale redesign would be `dockside.berths.v2` beside `v1`.
- **"The mesh authenticates":** declined. Every service verifies the token itself from metadata, because a request can reach a service without passing the mesh; the mesh is only the first check.
- **Gate:** the breaking-change check runs against main in CI, with a strict rule category, and the compatibility check of this change is shown below.
- **No tenant metadata key** is assumed: Dockside's tenancy, if any, comes from `multi-tenancy-design`.

## Output: `design/berths/berths.proto` (v1, edited safely)

````protobuf
syntax = "proto3";

package dockside.berths.v1;

// INTERNAL: called by Booking and two other services. The partner API is REST.
service BerthService {
  rpc GetBerth(GetBerthRequest) returns (GetBerthResponse);
  rpc ListBerths(ListBerthsRequest) returns (ListBerthsResponse);
  // The only stream: a live feed of berth occupancy.
  rpc WatchOccupancy(WatchOccupancyRequest) returns (stream WatchOccupancyResponse);
}

message Berth {
  string berth_id = 1;
  string name = 2;
  // 3 was `legacy_zone_code`, removed. Never reuse the number or the name.
  reserved 3;
  reserved "legacy_zone_code";
  int32 length_m = 4;             // kept for existing consumers; deprecated in favour of length_metres
  BerthStatus status = 5;
  double length_metres = 9;       // new: a fresh number, never a type change in place
}

enum BerthStatus {
  BERTH_STATUS_UNSPECIFIED = 0;
  BERTH_STATUS_FREE = 1;
  BERTH_STATUS_OCCUPIED = 2;
}

message GetBerthRequest { string berth_id = 1; }
message GetBerthResponse { Berth berth = 1; }

message ListBerthsRequest { string page_token = 1; int32 page_size = 2; }
message ListBerthsResponse { repeated Berth berths = 1; string next_page_token = 2; }

message WatchOccupancyRequest { string terminal_id = 1; }
message WatchOccupancyResponse { string berth_id = 1; BerthStatus status = 2; }
````

````markdown
Compatibility against main (`validate-proto.sh berths.proto baseline.proto`, and Buf in CI): the type of field 4 is unchanged; field 3 is removed with its number and name reserved; field 9 is new. No breaking change.

Consumers to notify (registry): Booking, Invoicing, Port Operations. `length_m` is removed and reserved only after all three have moved to `length_metres`; a redesign would be a new `dockside.berths.v2` package run beside `v1`.
````

> **Reply summary:** the partner API stays REST; unary is the default and only the occupancy feed streams; `legacy_zone_code` is removed with its number and name reserved; the type change becomes a new field with a fresh number, never in place; every service verifies the token itself and the mesh is only a first check; a breaking-change check gates the proto in CI, tied to the strictness of the contract; per-request balancing is a platform requirement; no implementation code.
