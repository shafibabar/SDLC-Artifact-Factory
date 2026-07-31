# protobuf3 Design and Compatibility

Reference material for `grpc-contract-design`. Covers a full worked `.proto` for a data-estate `DataAssetService`, the field-numbering and `reserved` mechanics, the breaking-vs-nonbreaking change classification, `enum`/`oneof`/well-known-types, the package/versioning convention, and the Buf CI lint rule categories.

---

## Worked Proto — `DataAssetService`

```protobuf
syntax = "proto3";

package dataestate.asset.v1;

option go_package = "github.com/acme/dataestate/gen/asset/v1;assetv1";

import "google/protobuf/timestamp.proto";
import "google/protobuf/field_mask.proto";

// DataAssetService is an INTERNAL service-to-service API. Public and
// browser-facing traffic stays on REST+OpenAPI (see api-contract-design).
service DataAssetService {
  // Unary: point read.
  rpc GetDataAsset(GetDataAssetRequest) returns (DataAsset);

  // Unary: command. Returns the updated aggregate.
  rpc ClassifyDataAsset(ClassifyDataAssetRequest) returns (DataAsset);

  // Server streaming: emit assets as an estate scan discovers them.
  rpc StreamEstateScan(StreamEstateScanRequest) returns (stream DataAsset);
}

// A DataAsset is the aggregate root of the asset bounded context.
message DataAsset {
  string data_asset_id = 1;   // 1-15 => one wire byte; hot fields go here
  string tenant_id = 2;
  string display_name = 3;
  SensitivityLevel sensitivity_level = 4;
  StorageLocation location = 5;
  repeated string tags = 6;
  google.protobuf.Timestamp classified_at = 7;

  // optional restores explicit presence: distinguishes "no reviewer yet"
  // (unset) from the empty string (set to zero value).
  optional string last_reviewed_by = 8;

  // 9 was `legacy_owner_email` (string), removed 2026-07. Never reuse.
  reserved 9;
  reserved "legacy_owner_email";
}

enum SensitivityLevel {
  // proto3 enums MUST have a zero value; make it the safe/unknown default.
  SENSITIVITY_LEVEL_UNSPECIFIED = 0;
  SENSITIVITY_LEVEL_PUBLIC = 1;
  SENSITIVITY_LEVEL_INTERNAL = 2;
  SENSITIVITY_LEVEL_CONFIDENTIAL = 3;
  SENSITIVITY_LEVEL_RESTRICTED = 4;
}

// oneof: exactly one storage backend identifies an asset's location.
message StorageLocation {
  oneof backend {
    GoogleDriveLocation google_drive = 1;
    S3Location s3 = 2;
  }
}

message GoogleDriveLocation {
  string file_id = 1;
  string drive_id = 2;
}

message S3Location {
  string bucket = 1;
  string key = 2;
}

message GetDataAssetRequest {
  string tenant_id = 1;
  string data_asset_id = 2;
}

message ClassifyDataAssetRequest {
  string tenant_id = 1;
  string data_asset_id = 2;
  SensitivityLevel sensitivity_level = 3;
  // Partial update: only the paths named in update_mask are written.
  google.protobuf.FieldMask update_mask = 4;
}

message StreamEstateScanRequest {
  string tenant_id = 1;
  string storage_source_id = 2;
}
```

---

## Field Numbers Are Permanent

The field number — the integer after `=` — is the wire identifier. protobuf encodes each field as a tag `(field_number << 3) | wire_type`; the field **name** never appears on the wire. Two consequences drive every rule below:

1. A peer decoding a message keys entirely on the number. If a number's meaning changes, every already-deployed peer silently mis-decodes.
2. A number it does not recognize is an *unknown field* — preserved (not dropped) so it can be re-emitted. This is what gives proto3 its forward compatibility.

### Numbering conventions

- **1–15** encode in one byte — reserve them for the hot, always-present fields.
- **16–2047** encode in two bytes — everything else.
- **19000–19999** are reserved by protobuf itself; never use them.
- Leave intentional gaps between logical groups so related fields can be added contiguously later.

### `reserved`

When a field is removed, add its number **and** its name to a `reserved` statement in the same message:

```protobuf
reserved 9, 11, 12 to 15;
reserved "legacy_owner_email", "old_status";
```

Reserving the **number** stops a future edit from re-homing that tag onto a new field (which would corrupt old peers). Reserving the **name** stops a future edit from re-introducing the old name with a new number (which breaks source-level consumers and JSON mappings). Reserve both.

---

## Presence: default vs `optional` vs `repeated`

| Declaration | Presence tracking | Zero value | Use for |
|---|---|---|---|
| `string x = 1;` (proto3 default) | No — cannot tell unset from zero | `""` / `0` / `false` | Fields where the zero value is a fine default |
| `optional string x = 1;` | Yes — `has_x()` distinguishes unset | `""` but `has_x()==false` | Fields where "not set" is semantically different from the zero value |
| `repeated string x = 1;` | N/A (list) | empty list | Lists; an empty list and "unset" are the same |
| `map<string,string> x = 1;` | N/A (map) | empty map | Keyed collections |

Adding `optional` to an existing non-optional scalar (or removing it) is **wire-compatible** but changes generated code — treat as a source-compatibility review, not a wire break.

---

## Breaking vs Non-Breaking Change Classification

| Change | Breaking? | Notes |
|---|---|---|
| Add a new field with a fresh number | **No** | Old peers treat it as an unknown field |
| Add a new method to a service | **No** | Old clients simply do not call it |
| Add a value to an `enum` | **No (usually)** | Old peers map it to the field's default/unknown; ensure the zero value is a safe unknown |
| Remove a field (and `reserved` its number+name) | **No, on the wire** | Old peers see the field as unset; coordinate if a consumer required it |
| Rename a field (same number) | **No, on the wire** / **Yes, in source** | Wire keys on the number; generated code and JSON names change |
| Reuse a `reserved`/removed number for a new field | **YES** | Old peers decode new bytes into the old field — silent corruption |
| Renumber an existing field | **YES** | Changes wire identity for every peer |
| Change a field's type incompatibly | **YES** | e.g. `string` → `int32`; decoder mis-parses |
| Change `int32` ↔ `int64` ↔ `uint32` ↔ `bool` (all varint) | **Wire-compatible, value-risky** | Same wire type but truncation/sign surprises; treat as breaking unless proven safe |
| Change a singular field to `repeated` of the same type | **Wire-compatible** | Decodes as a length-1 list; still review consumers |
| Move a field into/out of a `oneof` | **YES** | Changes presence/wire semantics |
| Delete a service method | **YES** | Callers break |
| Change a method's request/response message type | **YES** | Signature change |

Wire-type families (for judging "incompatible type change"): **varint** (`int32/int64/uint32/uint64/sint*/bool/enum`), **64-bit** (`fixed64/sfixed64/double`), **length-delimited** (`string/bytes/message/repeated`), **32-bit** (`fixed32/sfixed32/float`). A type change *within the same family* is wire-safe but may change values; a change *across families* is always a hard break.

---

## Enums, oneof, and Well-Known Types

- **`enum`** — must declare a zero value (proto3 requirement); make it `*_UNSPECIFIED = 0` so an unset or unknown value is a safe default rather than an accidental real state. Enum value names are conventionally prefixed with the enum name (protobuf does not scope them). Adding values is non-breaking; never renumber existing values.
- **`oneof`** — at most one member field is set; setting one clears the others. Field numbers inside a oneof share the message's number space. Moving a field in or out of a oneof is a breaking change.
- **Well-known types** — prefer the standard imports over ad-hoc fields:
  - `google.protobuf.Timestamp` for instants (never a raw `int64` epoch).
  - `google.protobuf.Duration` for spans.
  - `google.protobuf.FieldMask` for partial updates (the gRPC analog of the REST field-mask pattern in `api-contract-design`).
  - `google.protobuf.Struct` / `Any` only when the shape is genuinely dynamic — they defeat static typing, so justify them.

---

## Package and Versioning Convention

- Package name carries the **major version** as the last segment: `dataestate.asset.v1`. A breaking redesign becomes `dataestate.asset.v2` — a *new* package that can run in parallel with `v1`, exactly like the `/v1` → `/v2` REST path bump in `api-contract-design`.
- `option go_package = ".../gen/asset/v1;assetv1"` — the path before `;` is the import path of the generated code; the token after `;` is the Go package name.
- One service per file is the default; co-locate the messages it owns. Shared messages go in their own `.proto` and are `import`ed.
- Generated Go is checked in (or built in CI) under a `gen/` tree, never hand-edited.

Within a major version, **only additive, non-breaking changes are allowed** — the same additive-only discipline OpenAPI evolution follows. Anything in the "breaking" column above forces a new `vN` package.

---

## Buf CI Lint Rule Categories

Enforce the rules mechanically with [Buf](https://buf.build) so compatibility is gated, not remembered. Two commands run in CI:

- **`buf lint`** — style/structure rules. Relevant categories:
  - `MINIMAL` — the smallest set (e.g. package defined, no C++/Java keyword collisions).
  - `BASIC` — adds naming: `ENUM_ZERO_VALUE_SUFFIX` (zero value ends `_UNSPECIFIED`), `FIELD_LOWER_SNAKE_CASE`, `SERVICE_SUFFIX` (services end `Service`).
  - `STANDARD` (default) — adds `PACKAGE_VERSION_SUFFIX` (package ends `.vN`), `ENUM_VALUE_PREFIX`, `RPC_REQUEST_RESPONSE_UNIQUE`, `RPC_REQUEST_STANDARD_NAME` / `RPC_RESPONSE_STANDARD_NAME` (`GetFooRequest`/`GetFooResponse`).
- **`buf breaking --against '.git#branch=main'`** — diffs the current protos against the `main` baseline and fails on any breaking change. Categories:
  - `FILE` (strictest — flags wire *and* generated-source breaks, including field renames and file/package moves).
  - `PACKAGE` (wire + source within a package, tolerant of file moves).
  - `WIRE_JSON` (wire and JSON compatibility).
  - `WIRE` (loosest — only wire-format breaks; permits renames).

A typical `buf.yaml` uses `lint: use: [STANDARD]` and `breaking: use: [FILE]`. Wiring `buf breaking` into the PR check is what turns "never reuse a field number" from a code-review hope into an enforced gate — the field-number rules become a red build, not a production incident.

Per-edit checklist (run before every proto PR):

1. Am I reusing or renumbering an existing field number? → forbidden.
2. Did I `reserved` the number **and** name of anything I removed? → required.
3. Am I changing a field's type? → only within the same wire-type family, and only if values are proven safe.
4. Is every new field additive with a fresh number and a sane zero-value default?
5. Does `buf breaking` pass against `main`? → the build gate, not a memory test.
