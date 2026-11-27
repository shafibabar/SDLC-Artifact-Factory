#!/bin/bash
# Synthetic-input test for python-contract-test's own copy of the event schema
# gate. A small fake schema registry on a loopback port stands in for the real
# one, so no registry and no Docker is needed.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/python-contract-test/scripts/check-event-compatibility.sh"
TMP="$(mktemp -d)"
SERVER_PID=""
trap 'if [[ -n "$SERVER_PID" ]]; then kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null; fi; rm -rf "$TMP"' EXIT
FAILURES=0

# The fake registry: a version is incompatible when a field changed type, or
# when the earlier schema is closed (additionalProperties false) and one of its
# fields is gone. TRANSITIVE modes compare with every earlier version.
cat > "$TMP/registry.py" <<'PY'
import json, sys, http.server, urllib.parse, socketserver

subjects, modes = {}, {}
KNOWN = {"BACKWARD", "BACKWARD_TRANSITIVE", "FORWARD", "FORWARD_TRANSITIVE", "FULL", "FULL_TRANSITIVE", "NONE"}

def clash(old, new):
    for name, spec in old.get("properties", {}).items():
        if name not in new.get("properties", {}):
            if old.get("additionalProperties") is False:
                return f"PROPERTY_REMOVED_FROM_CLOSED_CONTENT_MODEL {name}"
        elif new["properties"][name].get("type") != spec.get("type"):
            return f"TYPE_CHANGED {name}"
        elif clash(spec, new["properties"][name]):
            return clash(spec, new["properties"][name])
    return None

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass
    def reply(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/vnd.schemaregistry.v1+json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def body(self):
        return json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))) or b"{}")
    def do_PUT(self):
        subject = urllib.parse.unquote(self.path.split("/")[2])
        mode = self.body().get("compatibility")
        if mode not in KNOWN:
            return self.reply(422, {"message": "bad mode"})
        modes[subject] = mode
        self.reply(200, {"compatibility": mode})
    def do_POST(self):
        parts = self.path.split("?")[0].split("/")
        schema = json.loads(self.body()["schema"])
        if parts[1] == "subjects":
            subject = urllib.parse.unquote(parts[2])
            subjects.setdefault(subject, []).append(schema)
            return self.reply(200, {"id": len(subjects[subject])})
        subject = urllib.parse.unquote(parts[3])
        earlier = subjects.get(subject, [])
        if not modes.get(subject, "").endswith("_TRANSITIVE"):
            earlier = earlier[-1:]
        problems = [p for p in (clash(old, schema) for old in earlier) if p]
        self.reply(200, {"is_compatible": not problems, "messages": problems})

class LoopbackServer(http.server.HTTPServer):
    # HTTPServer.server_bind looks up the host's full name (socket.getfqdn),
    # which takes tens of seconds on a macOS machine with no reverse DNS (the
    # GitHub macOS runner): the port file then arrives after the deadline.
    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]

server = LoopbackServer(("127.0.0.1", 0), Handler)
with open(sys.argv[1], "w") as handle:
    handle.write(str(server.server_address[1]))
server.serve_forever()
PY
python3 -I "$TMP/registry.py" "$TMP/port" &
SERVER_PID=$!
python3 -I - "$TMP/port" <<'PY'
import os, sys, time
deadline = time.time() + 20
while time.time() < deadline and not (os.path.exists(sys.argv[1]) and open(sys.argv[1]).read().strip()):
    time.sleep(0.05)
PY
PORT="$(cat "$TMP/port" 2>/dev/null)"
if [[ -z "$PORT" ]]; then echo "FAIL: the fake registry did not start"; exit 1; fi
REGISTRY="http://127.0.0.1:$PORT"

# tree <name> <mode> <version 1 properties> [<version 2 properties> ...]: one event's schema folder
tree() {
  python3 -I - "$TMP/$1" "$2" "${@:3}" <<'PY'
import json, os, sys
root, mode, versions = sys.argv[1], sys.argv[2], sys.argv[3:]
folder = os.path.join(root, "bookings", "booking-confirmed")
os.makedirs(folder, exist_ok=True)
for number, names in enumerate(versions, 1):
    properties = {}
    for name in names.split(","):
        field, _, kind = name.partition(":")
        properties[field] = {"type": kind or "string"}
    with open(os.path.join(folder, f"{number}.json"), "w") as handle:
        json.dump({"type": "object", "properties": properties, "required": ["bookingId"]}, handle)
if mode != "-":
    with open(os.path.join(root, "modes.txt"), "w") as handle:
        handle.write(f"# from the event design\nbookings/booking-confirmed {mode}\n")
PY
}

# check <label> <expected exit> <output pattern or -> <script arguments...>
check() {
  local label="$1" want="$2" pattern="$3"; shift 3
  local out rc
  out="$(bash "$SCRIPT" "$@" 2>&1)"; rc=$?
  if [[ $rc -eq $want ]] && { [[ "$pattern" == "-" ]] || grep -qE -- "$pattern" <<<"$out"; }; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (exit $rc, wanted $want, pattern $pattern)"; echo "$out"; FAILURES=$((FAILURES + 1))
  fi
}

tree deployed BACKWARD "bookingId,nights:integer,diet"
tree added BACKWARD "bookingId,nights:integer,diet" "bookingId,nights:integer,diet,pickupWindow"
tree removed BACKWARD "bookingId,nights:integer,diet" "bookingId,nights:integer"
tree renamed FULL_TRANSITIVE "bookingId,nights:integer,diet" "bookingId,nights:integer,food"
tree retyped BACKWARD "bookingId,nights:integer,diet" "bookingId,nights:string,diet"
tree edited BACKWARD "bookingId,nights:integer"
tree none NONE "bookingId,nights:integer,diet"
tree unknown SOMETIMES "bookingId,nights:integer,diet"
tree nomode - "bookingId,nights:integer,diet"
tree later BACKWARD "bookingId,nights:integer,diet" "bookingId,nights:integer,diet,a" "bookingId,nights:integer,a"
tree gap BACKWARD "bookingId,nights:integer,diet"
mv "$TMP/gap/bookings/booking-confirmed/1.json" "$TMP/gap/bookings/booking-confirmed/2.json"
mkdir -p "$TMP/dropped/bookings/other" && cp "$TMP/deployed/bookings/booking-confirmed/1.json" "$TMP/dropped/bookings/other/1.json"
echo "bookings/other BACKWARD" > "$TMP/dropped/modes.txt"
mkdir -p "$TMP/nothing"

check "no arguments is a usage error" 2 "usage"
check "baseline and first-release together" 2 "exactly one" --schemas "$TMP/added" --baseline "$TMP/deployed" --first-release --registry "$REGISTRY"
check "a registry that is not on loopback is refused" 2 "not a loopback address" --schemas "$TMP/added" --baseline "$TMP/deployed" --registry "http://registry.example.com:8081"
check "no registry answering is not a pass" 2 "no schema registry answered" --schemas "$TMP/added" --baseline "$TMP/deployed" --registry "http://127.0.0.1:1"
check "missing baseline folder is a failure" 2 "does not exist" --schemas "$TMP/added" --baseline "$TMP/absent" --registry "$REGISTRY"
check "no schema files" 2 "nothing was checked" --schemas "$TMP/nothing" --baseline "$TMP/deployed" --registry "$REGISTRY"

check "added optional field passes both passes" 0 "ok bookings/booking-confirmed \[add-only, BACKWARD_TRANSITIVE\]: 2 version" --schemas "$TMP/added" --baseline "$TMP/deployed" --registry "$REGISTRY"
check "removed field passes the declared mode" 1 "ok bookings/booking-confirmed \[declared, BACKWARD\]" --schemas "$TMP/removed" --baseline "$TMP/deployed" --registry "$REGISTRY"
check "removed field fails the add-only pass" 1 "FAIL bookings/booking-confirmed/2.json \[add-only, BACKWARD_TRANSITIVE\].*PROPERTY_REMOVED" --schemas "$TMP/removed" --baseline "$TMP/deployed" --registry "$REGISTRY"
check "renamed field fails the add-only pass" 1 "FAIL bookings/booking-confirmed/2.json \[add-only" --schemas "$TMP/renamed" --baseline "$TMP/deployed" --registry "$REGISTRY"
check "a changed mode is pointed out" 1 "WARN bookings/booking-confirmed: mode changed from BACKWARD to FULL_TRANSITIVE" --schemas "$TMP/renamed" --baseline "$TMP/deployed" --registry "$REGISTRY"
check "type change fails the declared mode" 1 "FAIL bookings/booking-confirmed/2.json \[declared, BACKWARD\].*TYPE_CHANGED" --schemas "$TMP/retyped" --baseline "$TMP/deployed" --registry "$REGISTRY"
check "removal in a later version is compared with every earlier one" 1 "FAIL bookings/booking-confirmed/3.json \[add-only" --schemas "$TMP/later" --baseline "$TMP/deployed" --registry "$REGISTRY"

check "deployed version edited in place" 1 "1.json: deployed version was edited in place" --schemas "$TMP/edited" --baseline "$TMP/deployed" --registry "$REGISTRY"
check "deployed event deleted" 1 "deployed event is missing" --schemas "$TMP/dropped" --baseline "$TMP/deployed" --registry "$REGISTRY"
check "mode NONE fails" 1 "mode NONE switches the check off" --schemas "$TMP/none" --first-release --registry "$REGISTRY"
check "unknown mode fails" 1 "unknown mode SOMETIMES" --schemas "$TMP/unknown" --first-release --registry "$REGISTRY"
check "missing mode list fails" 1 "modes.txt is missing" --schemas "$TMP/nomode" --first-release --registry "$REGISTRY"
check "version numbers with a gap fail" 1 "are not 1\.\.1" --schemas "$TMP/gap" --first-release --registry "$REGISTRY"
check "first release is stated" 0 "first release: no deployed schemas" --schemas "$TMP/deployed" --first-release --registry "$REGISTRY"

# The closed copy reaches nested objects.
python3 -I - "$TMP" <<'PY'
import json, os, sys
root = sys.argv[1]
def write(name, versions):
    folder = os.path.join(root, name, "stays", "stay-ended")
    os.makedirs(folder, exist_ok=True)
    for number, schema in enumerate(versions, 1):
        json.dump(schema, open(os.path.join(folder, f"{number}.json"), "w"))
    open(os.path.join(root, name, "modes.txt"), "w").write("stays/stay-ended BACKWARD\n")
pet = lambda *fields: {"type": "object", "properties": {f: {"type": "string"} for f in fields}}
write("nested", [{"type": "object", "properties": {"pet": pet("name", "chip")}},
                 {"type": "object", "properties": {"pet": pet("name")}}])
PY
check "a field removed from a nested object fails the add-only pass" 1 "FAIL stays/stay-ended/2.json \[add-only.*PROPERTY_REMOVED_FROM_CLOSED_CONTENT_MODEL chip" --schemas "$TMP/nested" --first-release --registry "$REGISTRY"

# The program is language-neutral and shared with go-contract-test: each skill
# owns its copy, and the two must stay the same. Change both together.
if python3 -I - "$SCRIPT" "$REPO_ROOT/skills/go-contract-test/scripts/check-event-compatibility.sh" <<'PY'
import sys
body = lambda path: open(path, encoding="utf-8").read().split("<<'PY'\n", 1)[1]
sys.exit(0 if body(sys.argv[1]) == body(sys.argv[2]) else 1)
PY
then echo "PASS: the program is identical to go-contract-test's copy"; else echo "FAIL: check-event-compatibility.sh differs from go-contract-test's copy; change both together"; FAILURES=$((FAILURES + 1)); fi

if [[ $FAILURES -eq 0 ]]; then echo "PASS: python-contract-test check-event-compatibility"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
