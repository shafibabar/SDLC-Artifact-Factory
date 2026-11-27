#!/bin/bash
# Tests skills/grpc-contract-design/scripts/validate-proto.sh — a skill-owned
# script exercised directly with file-path CLI args.
# Fixtures are built here, never from the skill's examples or template, so the
# test does not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/grpc-contract-design/scripts/validate-proto.sh"
cd "$SCRATCH_DIR"

expect() { # expect <label> <exit> <substring> <args...>
  local label="$1" want="$2" sub="$3"; shift 3
  local out code
  out="$("$VALIDATE" "$@" 2>&1)"; code=$?
  # A here-string, not `echo "$out" | grep -q`: grep -q exits at the first match,
  # echo can then die on the closed pipe, and under `pipefail` the match counts
  # as a failure (seen on the macOS CI runner, #1489).
  if [ "$code" -eq "$want" ] && { [ -z "$sub" ] || grep -qF -- "$sub" <<<"$out"; }; then
    _pass "validate-proto: $label"
  else
    _fail "validate-proto: $label" "exit $code; $(echo "$out" | grep -E 'FAIL|WARN' | head -5)"
  fi
}

mutate() { # mutate <src> <name> <old> <new>: copy src with one replacement
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import sys
src, name, old, new = sys.argv[1:5]
t = open(src).read()
assert old in t, "fixture missing: " + old
open(name, "w").write(t.replace(old, new, 1))
PY
}

cat > good.proto <<'EOF'
// A small internal service.
syntax = "proto3";

package stock.items.v1;

import "google/protobuf/timestamp.proto";

service ItemService {
  rpc GetItem(GetItemRequest) returns (GetItemResponse);
  rpc ReserveItem(ReserveItemRequest) returns (ReserveItemResponse);
}

message Item {
  string item_id = 1;
  string name = 2;
  ItemState state = 3;
  google.protobuf.Timestamp added_at = 4;
  optional string note = 5;
  oneof location {
    string shelf = 6;
    string bin = 7;
  }
  reserved 8, 10 to 12;
  reserved "legacy_code";

  message Tag {
    string label = 1;
  }
}

enum ItemState {
  ITEM_STATE_UNSPECIFIED = 0;
  ITEM_STATE_IN_STOCK = 1;
}

message GetItemRequest { string item_id = 1; }
message GetItemResponse { Item item = 1; }
message ReserveItemRequest { string item_id = 1; int32 quantity = 2; }
message ReserveItemResponse { Item item = 1; }
EOF

expect "a complete contract passes" 0 "0 check(s) failed" good.proto
expect "missing file is a usage error" 2 "" nosuch.proto
expect "no arguments is a usage error" 2 ""
expect "a missing baseline file is a usage error" 2 "" good.proto nosuch.proto

mutate good.proto v2syn.proto 'syntax = "proto3";' 'syntax = "proto2";'
expect "proto2 fails" 1 "syntax is proto3" v2syn.proto

mutate good.proto nover.proto "package stock.items.v1;" "package stock.items;"
expect "a package without a version fails" 1 "package ends in a major version" nover.proto

mutate good.proto badsvc.proto "service ItemService" "service Items"
expect "a service without the Service suffix fails" 1 "suffix Service" badsvc.proto

mutate good.proto sharedreq.proto "rpc ReserveItem(ReserveItemRequest)" "rpc ReserveItem(GetItemRequest)"
expect "a request message shared by two methods fails" 1 "belongs to one method" sharedreq.proto

mutate good.proto dupnum.proto "string name = 2;" "string name = 1;"
expect "a duplicate field number fails" 1 "no duplicate field numbers" dupnum.proto

mutate good.proto reservednum.proto "string name = 2;" "string name = 8;"
expect "a reserved field number fails" 1 "is not reserved" reservednum.proto

mutate good.proto reservedrange.proto "string name = 2;" "string name = 11;"
expect "a number inside a reserved range fails" 1 "is not reserved" reservedrange.proto

mutate good.proto reservedname.proto "string name = 2;" "string legacy_code = 2;"
expect "a reserved name fails" 1 "name is not reserved" reservedname.proto

mutate good.proto bigband.proto "string name = 2;" "string name = 19500;"
expect "a number in the protobuf-reserved band fails" 1 "outside 19000-19999" bigband.proto

mutate good.proto zero.proto "string name = 2;" "string name = 0;"
expect "field number zero fails" 1 "positive and in range" zero.proto

mutate good.proto camel.proto "string name = 2;" "string displayName = 2;"
expect "a camelCase field name fails" 1 "lower_snake_case" camel.proto

mutate good.proto enumzero.proto "ITEM_STATE_UNSPECIFIED = 0;" "ITEM_STATE_NONE = 0;"
expect "an enum zero value not named _UNSPECIFIED fails" 1 "named *_UNSPECIFIED" enumzero.proto

mutate good.proto enumfirst.proto "ITEM_STATE_UNSPECIFIED = 0;
  ITEM_STATE_IN_STOCK = 1;" "ITEM_STATE_IN_STOCK = 1;"
expect "an enum whose first value is not zero fails" 1 "first value is zero" enumfirst.proto

mutate good.proto stream.proto "rpc GetItem(GetItemRequest) returns (GetItemResponse);" "rpc GetItem(GetItemRequest) returns (stream GetItemResponse);"
expect "a streaming method warns but passes" 0 "WARN: ItemService.GetItem is a streaming method" stream.proto

# --- baseline mode ---
cp good.proto base.proto
expect "an unchanged contract passes against its baseline" 0 "0 check(s) failed" good.proto base.proto

mutate good.proto addfield.proto "optional string note = 5;" "optional string note = 5;
  string extra = 9;"
python3 - <<'PY'
t = open("addfield.proto").read()
open("addfield.proto", "w").write(t.replace("reserved 8, 10 to 12;", "reserved 13;"))
PY
expect "a new field with a fresh number passes" 0 "0 check(s) failed" addfield.proto base.proto

mutate good.proto renum.proto "string name = 2;" "string name = 9;"
expect "a renumbered field fails against the baseline" 1 "keeps its number" renum.proto base.proto

mutate good.proto retype.proto "string name = 2;" "int32 name = 2;"
expect "a type change fails against the baseline" 1 "the type is unchanged" retype.proto base.proto

mutate good.proto rmnoreserve.proto "  optional string note = 5;
" ""
expect "a removal without reserved fails against the baseline" 1 "removed, so its number is reserved" rmnoreserve.proto base.proto

python3 - <<'PY'
t = open("good.proto").read()
t = t.replace("  optional string note = 5;\n", "").replace("reserved 8, 10 to 12;", "reserved 5, 8, 10 to 12;").replace('reserved "legacy_code";', 'reserved "legacy_code", "note";')
open("rmreserved.proto", "w").write(t)
PY
expect "a removal with number and name reserved passes" 0 "0 check(s) failed" rmreserved.proto base.proto

mutate good.proto rmrpc.proto "  rpc ReserveItem(ReserveItemRequest) returns (ReserveItemResponse);
" ""
expect "a removed method fails against the baseline" 1 "still exists" rmrpc.proto base.proto

mutate good.proto retyperpc.proto "rpc GetItem(GetItemRequest) returns (GetItemResponse);" "rpc GetItem(GetItemRequest) returns (stream GetItemResponse);"
expect "a changed streaming shape fails against the baseline" 1 "keeps its request, response and streaming shape" retyperpc.proto base.proto

mutate good.proto newpkg.proto "package stock.items.v1;" "package stock.items.v2;"
expect "a changed package fails against the baseline" 1 "package is unchanged" newpkg.proto base.proto

mutate good.proto enumnum.proto "ITEM_STATE_IN_STOCK = 1;" "ITEM_STATE_IN_STOCK = 2;"
expect "a renumbered enum value fails against the baseline" 1 "keeps its number" enumnum.proto base.proto

smoke_test_summary
