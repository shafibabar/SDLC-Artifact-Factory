# Example 2 — Standard: An Internal Unary Service and a Server-Streaming Feed

Self-contained. **Fleetline** is a delivery-tracking product for regional couriers. **Standard** profile, separate services. **Tracking** keeps each parcel's status and events; **Dispatch** and the operations dashboard's backend call it. Both callers are internal services owned by other teams.

## Input

> **User:** "Make the Tracking contract gRPC. Dispatch reads one parcel's status; the ops dashboard wants every parcel event live. Return `INTERNAL` if the parcel is missing, and put a 2-second timeout in the Dispatch client."

## Working it

- **Boundary:** an internal service-to-service call with a strict typed contract wanted by two other teams, and one genuine live feed. gRPC is justified for these calls; the ops dashboard's browser front end still reaches Tracking through its own backend over REST.
- **Call shapes:** `GetParcel` is **unary**, the default. The live event feed is a real stream (open-ended, produced over time), so `WatchParcelEvents` is **server streaming**. Nothing else streams.
- **Errors:** a missing parcel is `NOT_FOUND`, not `INTERNAL`; `INTERNAL` is for a real bug and would hide missing parcels among genuine failures. A malformed parcel id is `INVALID_ARGUMENT`. A request for a parcel the caller may not see is `PERMISSION_DENIED`. One place maps domain errors to codes; the `ErrorInfo` reason (`PARCEL_NOT_FOUND`) carries the machine-readable why, and no database text crosses the boundary.
- **Deadline, not a timeout:** every Dispatch call carries a deadline, which Tracking sees and honours by passing the incoming context to its database call. A client-local 2-second timeout is invisible to the server, which keeps working after Dispatch gave up.
- **Identity:** Tracking verifies the bearer token in metadata itself; the mesh is only a first check, and the caller's identity comes from the verified token.
- **Compatibility:** field numbers are permanent, the package is `fleetline.tracking.v1`, and a breaking-change check runs against main in CI. Fleetline's `Dispatch` and the dashboard backend are registered as consumers of the contract.
- **Balancing:** one long HTTP/2 connection pins a client to one Tracking pod under connection-level balancing; per-request balancing is a platform requirement, handed to the platform engineer.

## Output: `design/tracking/tracking.proto`

````protobuf
syntax = "proto3";

package fleetline.tracking.v1;

import "google/protobuf/timestamp.proto";

// INTERNAL: called by Dispatch and the dashboard backend. Browsers use REST (api-contract-design).
service TrackingService {
  // Unary: one parcel's status.
  rpc GetParcel(GetParcelRequest) returns (GetParcelResponse);

  // Server streaming: parcel events as they happen (an open-ended live feed).
  rpc WatchParcelEvents(WatchParcelEventsRequest) returns (stream WatchParcelEventsResponse);
}

message Parcel {
  string parcel_id = 1;
  string route_id = 2;
  ParcelState state = 3;
  google.protobuf.Timestamp updated_at = 4;
  optional string held_reason = 5;   // unset means "not held", which differs from ""
}

enum ParcelState {
  PARCEL_STATE_UNSPECIFIED = 0;
  PARCEL_STATE_PICKED_UP = 1;
  PARCEL_STATE_IN_TRANSIT = 2;
  PARCEL_STATE_DELIVERED = 3;
}

message ParcelEvent {
  string parcel_id = 1;
  ParcelState state = 2;
  google.protobuf.Timestamp occurred_at = 3;
}

message GetParcelRequest { string parcel_id = 1; }
message GetParcelResponse { Parcel parcel = 1; }

message WatchParcelEventsRequest { string route_id = 1; }
message WatchParcelEventsResponse { ParcelEvent event = 1; }
````

> **Reply summary:** gRPC for this internal boundary; `GetParcel` is unary and the live feed is the only stream; a missing parcel is `NOT_FOUND` with an `ErrorInfo` reason, never `INTERNAL`; every call carries a deadline that Tracking honours; Tracking verifies the token itself; field numbers are permanent and a breaking-change check gates the proto in CI; per-request balancing is a platform requirement; the reply contains no implementation code.
