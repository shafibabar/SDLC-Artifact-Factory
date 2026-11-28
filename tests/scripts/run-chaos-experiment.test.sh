#!/bin/bash
# Synthetic-input test for go-chaos-test's runner and target guard. Needs no
# Docker, Go, Toxiproxy, kubectl or cluster: kubectl and go are fakes on the
# PATH, and one local HTTP server plays the product and the Toxiproxy API.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/go-chaos-test/scripts/run-chaos-experiment.sh"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
SERVER_PID=""
trap '[ -z "$SERVER_PID" ] || kill "$SERVER_PID" 2>/dev/null; rm -rf "$TMP"' EXIT
FAILURES=0
mkdir -p "$TMP/bin" "$TMP/p/tests/chaos" "$TMP/state" "$TMP/home"

cat > "$TMP/bin/kubectl" <<'SH'
#!/bin/bash
# Fake kubectl: the run's kubeconfig view and marker, and a Chaos Mesh object kept as a file.
S="$FAKE_DIR/state"
args=" $* "
case "$args" in
  *" config view "*)
    printf '{"contexts":[{"name":"%s","context":{"cluster":"c"}}],"clusters":[{"name":"c","cluster":{"server":"https://%s"}}]}\n' \
      "${FAKE_CONTEXT:-kind-e2e-run-1}" "${FAKE_SERVER:-127.0.0.1:6443}" ;;
  *" get configmap e2e-run-marker "*)
    if [ -n "${FAKE_NO_MARKER:-}" ]; then echo 'Error from server (NotFound): configmaps "e2e-run-marker" not found' >&2; exit 1; fi
    printf '{"data":{"run-id":"%s","endpoint.api":"%s","endpoint.toxiproxy":"%s"}}\n' \
      "${FAKE_MARKER_RUN:-run-1}" "${FAKE_ENDPOINT:-$(cat "$FAKE_DIR/addr")}" "$(cat "$FAKE_DIR/addr")" ;;
  *" create --dry-run=client "*) cat "${@: -1}" ;;
  *" apply -f "*)
    [ -z "${FAKE_APPLY_FAIL:-}" ] || { echo "error: admission webhook denied" >&2; exit 1; }
    touch "$S/mesh"; echo "applied" ;;
  *" get PodChaos "* | *" get NetworkChaos "*)
    if [ -f "$S/mesh" ]; then
      status=True; [ -z "${FAKE_NOT_INJECTED:-}" ] || status=False
      printf '{"status":{"conditions":[{"type":"Selected","status":"True"},{"type":"AllInjected","status":"%s"}]}}\n' "$status"
    else
      echo 'Error from server (NotFound): not found' >&2; exit 1
    fi ;;
  *" delete PodChaos "* | *" delete NetworkChaos "*)
    [ -n "${FAKE_DELETE_STUCK:-}" ] || rm -f "$S/mesh"; echo deleted ;;
  *) echo "fake kubectl: unexpected $*" >&2; exit 1 ;;
esac
SH
cat > "$TMP/bin/go" <<'SH'
#!/bin/bash
# Fake go: prints what FAKE_GO asks for and exits as a go test would.
case "${FAKE_GO:-pass}" in
  pass) echo "ok  	example.com/p/internal/tides	1.2s"; exit 0 ;;
  fail) echo "--- FAIL: TestChaos_BreakerTransitions (0.8s)"; echo "    x_test.go:9: after 5 consecutive failures: breaker is closed, want open"; exit 1 ;;
  invalid) echo "    x_test.go:9: CHAOS-INVALID: adding toxic \"t\" to \"tides\": AddToxic: HTTP 400: invalid toxic type (no fault was injected)"; exit 1 ;;
  left) echo "    x_test.go:9: CHAOS-FAULT-LEFT: toxic \"t\" is still listed on \"tides\" after removal"; exit 1 ;;
  none) echo "ok  	example.com/p/internal/tides	0.1s [no tests to run]"; exit 0 ;;
esac
SH
chmod +x "$TMP/bin/kubectl" "$TMP/bin/go"

# One server: the product's endpoint (good, bad, or bad while a fault is active), the Toxiproxy API and the statement marker.
cat > "$TMP/server.py" <<'PY'
import http.server, json, os, socketserver, sys
folder = sys.argv[1]
toxics = []

def setting(name):
    path = os.path.join(folder, name)
    return open(path).read().strip() if os.path.exists(path) else ""

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, code, body):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/v1/window":
            mode = setting("mode")
            active = bool(toxics) or os.path.exists(os.path.join(folder, "state", "mesh"))
            if mode == "degrade" and active:
                self.send_response(200)
                self.send_header("X-Degraded", "stale")
                self.send_header("Content-Length", "2")
                self.end_headers()
                self.wfile.write(b"{}")
                return
            self.reply(503 if mode == "bad" or (mode == "bad-when-fault" and active) else 200, b"{}")
        elif self.path == "/.well-known/chaos-statement":
            marker = setting("marker")
            self.reply(200, {"statement_id": marker}) if marker else self.reply(404, b"no")
        elif self.path.endswith("/toxics"):
            self.reply(200, toxics)
        elif self.path == "/proxies":
            self.reply(200, {"tides": {"name": "tides", "toxics": toxics}})
        else:
            self.reply(404, b"no")

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))) or b"null")
        if self.path == "/reset":
            toxics.clear()
            self.reply(204, b"")
            return
        with open(os.path.join(folder, "posts"), "a") as handle:
            handle.write(self.path + "\n")
        if setting("toxic-reject"):
            self.reply(400, {"error": "invalid toxic type", "status": 400})
            return
        toxics.append(body)
        self.reply(200, body)

    def do_DELETE(self):
        if not setting("delete-stuck"):
            toxics[:] = [t for t in toxics if not self.path.endswith("/" + t["name"])]
        self.reply(204, b"")

class LoopbackServer(http.server.HTTPServer):
    # HTTPServer.server_bind looks up the host's full name (socket.getfqdn),
    # which takes tens of seconds on a macOS machine with no reverse DNS.
    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]

server = LoopbackServer(("127.0.0.1", 0), Handler)
open(os.path.join(folder, "port"), "w").write(str(server.server_address[1]))
server.serve_forever()
PY
echo good > "$TMP/mode"
python3 -I "$TMP/server.py" "$TMP" &
SERVER_PID=$!
python3 -I - "$TMP/port" <<'PY'
import os, sys, time
deadline = time.time() + 20
while time.time() < deadline and not (os.path.exists(sys.argv[1]) and open(sys.argv[1]).read().strip()):
    time.sleep(0.05)
PY
PORT="$(cat "$TMP/port" 2>/dev/null)"
if [[ -z "$PORT" ]]; then echo "FAIL: the fake server did not start"; exit 1; fi
printf '127.0.0.1:%s' "$PORT" > "$TMP/addr"

# Fixtures: experiments, manifests (JSON, which kubectl reads too), statements.
python3 -I - "$TMP" "$PORT" <<'PY'
import datetime, json, os, sys
tmp, port = sys.argv[1], sys.argv[2]
d = os.path.join(tmp, "p")
steady = {"slo_id": "SLO-01", "sli": "share of window requests answered 200 in under 800 ms", "endpoint": "api", "path": "/v1/window",
          "good_statuses": [200], "under_ms": 800, "objective": 0.99, "probe_per_second": 20, "window_seconds": 1}
base = {"experiment_id": "toxic", "pattern": "graceful-degradation", "hypothesis": "users still get a window", "blast_radius": "the tides proxy",
        "steady_state": steady, "fault_seconds": 2, "abort": {"sli_below": 0.9, "over_seconds": 1, "max_seconds": 10},
        "recovery": {"within_seconds": 4},
        "fault": {"tool": "toxiproxy", "endpoint": "toxiproxy", "proxy": "tides",
                  "toxic": {"name": "tides-latency", "type": "latency", "stream": "downstream", "attributes": {"latency": 2000}}}}
def write(name, data):
    json.dump(data, open(os.path.join(d, name), "w"))
write("toxic.json", base)
write("marked.json", dict(base, experiment_id="marked", steady_state=dict(steady, fault_header="X-Degraded")))
write("slow.json", dict(base, fault_seconds=30, abort={"sli_below": 0.9, "over_seconds": 1, "max_seconds": 40}))
mesh = {"apiVersion": "chaos-mesh.org/v1alpha1", "kind": "PodChaos", "metadata": {"name": "kill", "namespace": "harbour"},
        "spec": {"action": "pod-kill", "mode": "one", "selector": {"namespaces": ["harbour"], "labelSelectors": {"app": "harbour"}}}}
write("mesh.json", dict(base, experiment_id="mesh", fault={"tool": "chaos-mesh", "manifest": os.path.join(d, "kill.json")}))
write("kill.json", mesh)
bad = json.loads(json.dumps(mesh)); bad["spec"]["scheduler"] = {"cron": "@once"}; write("old.json", bad)
write("mesh-old.json", dict(base, experiment_id="old", fault={"tool": "chaos-mesh", "manifest": os.path.join(d, "old.json")}))
wide = json.loads(json.dumps(mesh)); wide["spec"]["selector"]["namespaces"] = ["harbour", "tenant-acme"]; write("wide.json", wide)
write("mesh-wide.json", dict(base, experiment_id="wide", fault={"tool": "chaos-mesh", "manifest": os.path.join(d, "wide.json")}))
net = json.loads(json.dumps(mesh)); net["kind"] = "NetworkChaos"; net["spec"]["action"] = "delay"; write("net.json", net)
write("mesh-net.json", dict(base, experiment_id="net", fault={"tool": "chaos-mesh", "manifest": os.path.join(d, "net.json")}))
go = {"experiment_id": "patterns", "pattern": "circuit-breaker", "hypothesis": "h", "blast_radius": "the go test process",
      "abort": {"max_seconds": 60}, "fault": {"tool": "go-test", "command": "go test -tags chaos -count=1 ./internal/...", "reset_toxiproxy": "toxiproxy"}}
write("go.json", go)
write("go-cached.json", dict(go, fault={"tool": "go-test", "command": "go test -tags chaos ./internal/..."}))
write("go-retried.json", dict(go, fault={"tool": "go-test", "command": "gotestsum --rerun-fails -- go test -tags chaos -count=1 ./..."}))
now = datetime.datetime.now(datetime.timezone.utc)
statement = {"statement_id": "verify-1", "product": "p", "base_url": f"http://127.0.0.1:{port}", "toxiproxy_api": f"http://127.0.0.1:{port}",
             "purpose": "verify the fallback", "blast_radius": "the tides proxy",
             "faults": [{"tool": "toxiproxy", "proxy": "tides", "type": "latency", "max_attributes": {"latency": 2000}}],
             "abort": {"sli_below": 0.9, "over_seconds": 1, "max_seconds": 10},
             "impact": {k: "none" for k in ("other_users", "other_teams", "dependent_systems", "third_parties", "data", "cost")},
             "how_to_stop": "Ctrl-C", "watched_by": "test-strategist",
             "window_start": (now - datetime.timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%SZ"),
             "window_end": (now + datetime.timedelta(hours=1)).strftime("%Y-%m-%dT%H:%M:%SZ"),
             "marker": "served", "approved_by": "Product owner", "approved_on": str(now.date()), "expires_on": str(now.date())}
def st(name, **change):
    data = json.loads(json.dumps(statement)); data.update(change); write(name, data)
st("statement.json")
st("unsigned.json", approved_by="")
st("expired.json", expires_on=str(now.date() - datetime.timedelta(days=1)))
st("lapseless.json", expires_on="")
st("single.json", expires_on="", single_use_run_id="run-77")
st("narrow.json", faults=[{"tool": "toxiproxy", "proxy": "tides", "type": "latency", "max_attributes": {"latency": 500}}])
st("other-type.json", faults=[{"tool": "toxiproxy", "proxy": "tides", "type": "timeout", "max_attributes": {"timeout": 1}}])
st("strict.json", abort={"sli_below": 0.95, "over_seconds": 1, "max_seconds": 10})
st("closed.json", window_end=(now + datetime.timedelta(seconds=30)).strftime("%Y-%m-%dT%H:%M:%SZ"))
st("noimpact.json", impact={"other_users": "none"})
st("remote.json", base_url="http://api.staging.example.com")
PY
printf '{}' > "$TMP/kubeconfig"

# run <name> <expected exit> <expected regex> [VAR=value ...] -- <runner arguments>
run() {
  local name="$1" want="$2" pattern="$3"; shift 3
  local envs=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  local out code
  out="$(cd "$TMP/p" && env -i PATH="$TMP/bin:/usr/bin:/bin" HOME="$TMP/home" FAKE_DIR="$TMP" ${envs[@]+"${envs[@]}"} \
         /bin/bash "$SCRIPT" "$@" --out "$TMP/out" 2>&1)"
  code=$?
  if [ "$code" -eq "$want" ] && grep -E "$pattern" > /dev/null <<<"$out"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (exit $code, want $want; pattern '$pattern')"
    printf '%s\n' "$out" | sed 's/^/    /' | head -12
    FAILURES=$((FAILURES + 1))
  fi
}
expect() {
  local name="$1"; shift
  if "$@"; then echo "PASS: $name"; else echo "FAIL: $name"; FAILURES=$((FAILURES + 1)); fi
}
no_toxic_posted() { [ ! -s "$TMP/posts" ]; }
no_toxic_left() { python3 -I -c 'import json, sys, urllib.request
sys.exit(0 if json.load(urllib.request.urlopen(sys.argv[1])) == [] else 1)' "http://127.0.0.1:$PORT/proxies/tides/toxics"; }
no_mesh_left() { [ ! -f "$TMP/state/mesh" ]; }
CLUSTER=(E2E_RUN_ID=run-1 "E2E_KUBECONFIG=$TMP/kubeconfig")
X="$TMP/p"

# --- where: only this run's throwaway cluster, by default
run "started by hand, nothing set" 3 "REFUSED: E2E_RUN_ID and E2E_KUBECONFIG are not set" -- --experiment "$X/toxic.json"
run "the caller's own kubeconfig" 3 "REFUSED: E2E_KUBECONFIG is the caller's own kubeconfig" "${CLUSTER[@]}" "KUBECONFIG=$TMP/kubeconfig" -- --experiment "$X/toxic.json"
run "kubeconfig of another cluster" 3 "REFUSED: the kubeconfig has no context kind-e2e-run-1" "${CLUSTER[@]}" FAKE_CONTEXT=kind-staging -- --experiment "$X/toxic.json"
run "API server on another machine" 3 "REFUSED: .*10.0.0.8:6443\) is not on this machine" "${CLUSTER[@]}" FAKE_SERVER=10.0.0.8:6443 -- --experiment "$X/toxic.json"
run "cluster with no run marker" 3 "REFUSED: the cluster's run marker says run \"None\"" "${CLUSTER[@]}" FAKE_NO_MARKER=1 -- --experiment "$X/toxic.json"
run "marker of another run" 3 "REFUSED: .*says run \"someone-else\", this run is \"run-1\"" "${CLUSTER[@]}" FAKE_MARKER_RUN=someone-else -- --experiment "$X/toxic.json"
run "endpoint that is a host name" 3 "REFUSED: .*no loopback address for endpoint \"api\"" "${CLUSTER[@]}" FAKE_ENDPOINT=api.staging.example:443 -- --experiment "$X/toxic.json"
expect "nothing was injected by any refusal" no_toxic_posted

# --- the experiment and the manifest
run "a cached go test is no run" 2 "must carry -count=1" "${CLUSTER[@]}" -- --experiment "$X/go-cached.json"
run "a retried go test" 2 "never retried" "${CLUSTER[@]}" -- --experiment "$X/go-retried.json"
run "the removed scheduler field" 2 "spec.scheduler was removed in Chaos Mesh 2.0" "${CLUSTER[@]}" -- --experiment "$X/mesh-old.json"
run "a selector reaching a tenant namespace" 2 "must be exactly the experiment's own namespace" "${CLUSTER[@]}" -- --experiment "$X/mesh-wide.json"
run "a sustained fault with no duration" 2 "spec.duration is required" "${CLUSTER[@]}" -- --experiment "$X/mesh-net.json"

# --- verdicts
echo bad > "$TMP/mode"
run "steady state does not hold before injection" 4 "did not hold before injection.*nothing was injected" "${CLUSTER[@]}" -- --experiment "$X/toxic.json"
expect "no toxic was posted for it" no_toxic_posted
echo good > "$TMP/mode"
echo yes > "$TMP/toxic-reject"
run "toxic rejected: never injected" 4 "the fault was never injected: Toxiproxy answered 400" "${CLUSTER[@]}" -- --experiment "$X/toxic.json"
rm -f "$TMP/toxic-reject"
run "toxiproxy pass, removal verified" 0 "Fault removal: DELETE answered 204; the proxy no longer lists the toxic" "${CLUSTER[@]}" -- --experiment "$X/toxic.json"
expect "no toxic left after the pass" no_toxic_left
expect "the result records no retry" grep -q '"retries": 0' "$TMP/out/toxic-result.json"
run "fault never reached the measured path" 4 "no answer during the fault carried X-Degraded" "${CLUSTER[@]}" -- --experiment "$X/marked.json"
echo degrade > "$TMP/mode"
run "fault reached the measured path" 0 "== PASS: chaos experiment marked" "${CLUSTER[@]}" -- --experiment "$X/marked.json"
expect "the degraded answers were counted" grep -q '"during": [1-9]' "$TMP/out/marked-result.json"
echo bad-when-fault > "$TMP/mode"
run "abort fires, fault removed" 1 "abort condition: .* below 0.9; the fault was removed at once" "${CLUSTER[@]}" -- --experiment "$X/slow.json"
expect "no toxic left after the abort" no_toxic_left
echo good > "$TMP/mode"
echo yes > "$TMP/delete-stuck"
run "removal that cannot be verified" 5 "THE FAULT MAY STILL BE ACTIVE" "${CLUSTER[@]}" -- --experiment "$X/toxic.json"
rm -f "$TMP/delete-stuck"
python3 -I -c 'import urllib.request, sys; urllib.request.urlopen(urllib.request.Request(sys.argv[1], method="POST", data=b"{}"))' "http://127.0.0.1:$PORT/reset"

# interruption while the fault is active
( cd "$X" && env -i PATH="$TMP/bin:/usr/bin:/bin" HOME="$TMP/home" FAKE_DIR="$TMP" "${CLUSTER[@]}" \
    /bin/bash "$SCRIPT" --experiment "$X/slow.json" --out "$TMP/out" > "$TMP/int.log" 2>&1 ) &
RUNNER=$!
python3 -I - "$TMP/int.log" <<'PY'
import sys, time
deadline = time.time() + 30
while time.time() < deadline and "fault confirmed active" not in open(sys.argv[1]).read():
    time.sleep(0.1)
PY
pkill -INT -f "$X/slow.json" 2>/dev/null
wait "$RUNNER"
CODE=$?
expect "interrupted: exit 130" test "$CODE" -eq 130
expect "interrupted: removal verified" grep -q "interrupted while the fault was active" "$TMP/int.log"
expect "no toxic left after the interruption" no_toxic_left

# --- Chaos Mesh
run "chaos mesh pass, object gone" 0 "Fault removal: kubectl delete exit 0; the object is gone \(Chaos Mesh recovers" "${CLUSTER[@]}" -- --experiment "$X/mesh.json"
expect "no chaos object left" no_mesh_left
run "chaos mesh never reports AllInjected" 4 "the fault was never confirmed active" "${CLUSTER[@]}" FAKE_NOT_INJECTED=1 -- --experiment "$X/mesh.json"
expect "the unconfirmed object was still removed" no_mesh_left
run "chaos mesh apply refused" 4 "the fault was never injected: error: admission webhook denied" "${CLUSTER[@]}" FAKE_APPLY_FAIL=1 -- --experiment "$X/mesh.json"
run "chaos mesh object that will not go" 5 "THE FAULT MAY STILL BE ACTIVE.*kubectl delete PodChaos kill -n harbour" "${CLUSTER[@]}" FAKE_DELETE_STUCK=1 -- --experiment "$X/mesh.json"
rm -f "$TMP/state/mesh"

# --- go test
run "go test passes" 0 "== PASS: chaos experiment patterns" "${CLUSTER[@]}" -- --experiment "$X/go.json"
run "go test assertion fails" 1 "go test exited 1: a pattern assertion failed" "${CLUSTER[@]}" FAKE_GO=fail -- --experiment "$X/go.json"
run "go test reports its fault never injected" 4 "^   adding toxic .*AddToxic: HTTP 400" "${CLUSTER[@]}" FAKE_GO=invalid -- --experiment "$X/go.json"
run "go test reports a fault left" 5 "could not verify its fault's removal" "${CLUSTER[@]}" FAKE_GO=left -- --experiment "$X/go.json"
run "go test that ran nothing" 4 "ran no test" "${CLUSTER[@]}" FAKE_GO=none -- --experiment "$X/go.json"

# --- another system: only under the product owner's signed chaos statement
rm -f "$TMP/posts"
echo verify-1 > "$TMP/marker"
S=(--experiment "$X/toxic.json" --statement)
run "statement: unsigned" 3 "REFUSED: the chaos statement has no approved_by" -- "${S[@]}" "$X/unsigned.json"
run "statement: expired" 3 "REFUSED: the chaos statement expired on" -- "${S[@]}" "$X/expired.json"
run "statement: never lapses" 3 "neither expires_on nor single_use_run_id" -- "${S[@]}" "$X/lapseless.json"
run "statement: for another run" 3 "for run \"run-77\" only" CHAOS_RUN_ID=run-1 -- "${S[@]}" "$X/single.json"
run "statement: impact not stated" 3 "has no impact.other_teams" -- "${S[@]}" "$X/noimpact.json"
run "statement: fault beyond what was signed" 3 "latency \(2000\) exceeds what the chaos statement allows \(500\)" -- "${S[@]}" "$X/narrow.json"
run "statement: fault type not signed" 3 "does not allow a latency toxic" -- "${S[@]}" "$X/other-type.json"
run "statement: abort looser than signed" 3 "abort conditions are looser" -- "${S[@]}" "$X/strict.json"
run "statement: run does not fit the window" 3 "would not fit inside the statement's window" -- "${S[@]}" "$X/closed.json"
run "statement: plain http to another host" 3 "must be https" -- "${S[@]}" "$X/remote.json"
run "statement: chaos mesh is refused outside the throwaway cluster" 3 "runs only in the run's own throwaway cluster" -- --experiment "$X/mesh.json" --statement "$X/statement.json"
echo someone-else > "$TMP/marker"
run "statement: marker names another statement" 3 "serves statement \"someone-else\"" -- "${S[@]}" "$X/statement.json"
expect "nothing was injected by any statement refusal" no_toxic_posted
echo verify-1 > "$TMP/marker"
run "statement: signed, within limits" 0 "== PASS: chaos experiment toxic .*named in chaos statement verify-1" -- "${S[@]}" "$X/statement.json"
expect "the statement is recorded verbatim" grep -q '"statement_id": "verify-1"' "$TMP/out/toxic-result.json"

if [[ $FAILURES -eq 0 ]]; then echo "PASS: run-chaos-experiment"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
