#!/bin/bash
# Synthetic-input test for go-load-test's runner and target guard. Needs no k6,
# kubectl, Docker or cluster: k6 and kubectl are fakes on the PATH and the
# designated environment is a local HTTP server.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/go-load-test/scripts/run-load-test.sh"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
SERVER_PID=""
trap '[ -z "$SERVER_PID" ] || kill "$SERVER_PID" 2>/dev/null; rm -rf "$TMP"' EXIT
FAILURES=0

mkdir -p "$TMP/bin" "$TMP/product/tests/load/lib" "$TMP/home"
cat > "$TMP/bin/k6" <<'SH'
#!/bin/bash
# Fake k6: answers `version`, and on `run` records its arguments, copies a canned summary and exits as told.
if [ "$1" = "version" ]; then echo "k6 ${FAKE_K6_VERSION:-v2.4.0} (commit/fake, go1.27.3, linux/amd64)"; exit 0; fi
summary="" subjects=""
for arg in "$@"; do
  case "$arg" in
    LOAD_SUMMARY=*) summary="${arg#LOAD_SUMMARY=}" ;;
    LOAD_SUBJECTS_FILE=*) subjects="${arg#LOAD_SUBJECTS_FILE=}" ;;
  esac
done
printf '%s\n' "$@" > "$FAKE_DIR/k6-args"
printf '%s\n' "$subjects" > "$FAKE_DIR/subjects-path"
[ -f "$subjects" ] && cp "$subjects" "$FAKE_DIR/subjects-seen"
if [ -n "${FAKE_K6_SUMMARY:-}" ]; then cp "$FAKE_DIR/$FAKE_K6_SUMMARY.json" "$summary"; fi
if [ -n "${FAKE_K6_WAIT:-}" ]; then
  exec python3 -I -c 'import signal, sys, time
signal.signal(signal.SIGINT, lambda *a: sys.exit(105))
open(sys.argv[1], "w").write("started")
time.sleep(30)' "$FAKE_DIR/k6-started"
fi
exit "${FAKE_K6_EXIT:-0}"
SH
cat > "$TMP/bin/kubectl" <<'SH'
#!/bin/bash
# Fake kubectl: a kubeconfig view and the run marker, shaped by FAKE_* variables.
case " $* " in
  *" config view "*)
    printf '{"contexts":[{"name":"%s","context":{"cluster":"c"}}],"clusters":[{"name":"c","cluster":{"server":"https://%s"}}]}\n' \
      "${FAKE_CONTEXT:-kind-e2e-run-1}" "${FAKE_SERVER:-127.0.0.1:6443}" ;;
  *" get configmap e2e-run-marker "*)
    if [ -n "${FAKE_NO_MARKER:-}" ]; then echo 'Error from server (NotFound): configmaps "e2e-run-marker" not found' >&2; exit 1; fi
    printf '{"data":{"run-id":"%s","endpoint.api":"%s"}}\n' "${FAKE_MARKER_RUN:-run-1}" "${FAKE_ENDPOINT:-$(cat "$FAKE_DIR/addr")}" ;;
  *) echo "fake kubectl: unexpected $*" >&2; exit 1 ;;
esac
SH
chmod +x "$TMP/bin/k6" "$TMP/bin/kubectl"

# The "environment": answers / and serves a designation marker read from a file (a JSON object as it is, any other
# text as the designation id); with a URL in the file "redirect" it redirects the marker there. Counts every other request.
cat > "$TMP/server.py" <<'PY'
import http.server, json, os, socketserver, sys
folder = sys.argv[1]

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.path == "/.well-known/load-test-designation":
            redirect = open(os.path.join(folder, "redirect")).read().strip()
            if redirect:
                self.send_response(302)
                self.send_header("Location", redirect)
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
            marker = open(os.path.join(folder, "marker")).read().strip()
            if not marker:
                self.send_error(404)
                return
            body = (marker if marker.startswith("{") else json.dumps({"designation_id": marker})).encode()
        elif self.path == "/":
            body = b"ok"
        else:
            with open(os.path.join(folder, "other-requests"), "a") as handle:
                handle.write(self.path + "\n")
            body = b"{}"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

class LoopbackServer(http.server.HTTPServer):
    # HTTPServer.server_bind looks up the host's full name (socket.getfqdn),
    # which takes tens of seconds on a macOS machine with no reverse DNS.
    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]

server = LoopbackServer(("127.0.0.1", 0), Handler)
with open(os.path.join(folder, "port"), "w") as handle:
    handle.write(str(server.server_address[1]))
server.serve_forever()
PY
echo "perf-1" > "$TMP/marker"
: > "$TMP/redirect"
python3 -I "$TMP/server.py" "$TMP" &
SERVER_PID=$!
python3 -I - "$TMP/port" <<'PY'
import os, sys, time
deadline = time.time() + 20
while time.time() < deadline and not (os.path.exists(sys.argv[1]) and open(sys.argv[1]).read().strip()):
    time.sleep(0.05)
PY
PORT="$(cat "$TMP/port" 2>/dev/null)"
if [[ -z "$PORT" ]]; then echo "FAIL: the fake environment did not start"; exit 1; fi
printf '127.0.0.1:%s' "$PORT" > "$TMP/addr"

# Fixtures: a product folder, canned k6 summaries, designation records, subject commands.
python3 -I - "$TMP" "$PORT" <<'PY'
import datetime, json, os, sys
tmp, port = sys.argv[1], sys.argv[2]
load = os.path.join(tmp, "product", "tests", "load")
for name in ("smoke", "average-load", "stress", "soak", "spike", "breakpoint", "overload"):
    open(os.path.join(load, name + ".js"), "w").write("// placeholder: the fake k6 does not read it\n")
open(os.path.join(load, "lib", "gate.js"), "w").write("// placeholder\n")
who = {"decided_by": "product owner, 2026-11-28", "reason": "fits the nightly run"}
shape = dict(rate_per_second=5, ramp_up="5s", hold="30s", virtual_users=10, warm_up="excluded", **who)
profile = {
    "product": "tide-tables",
    "nfr": {"id": "NFR-PERF-01", "level": "Must", "environment": "Saturday 06:00 peak, 40 requests a second"},
    "slo": {"availability": {"id": "R-01", "objective": 0.995, "good_statuses": [{"min": 200, "max": 499}]},
            "latency": {"id": "R-02", "percentile": 95, "under_ms": 400}},
    "limiter": {"per_subject_per_second": 10, "burst": 20, "source": "go-middleware default"},
    "data": {"description": "500 tide stations seeded through the public API", "distinct_items": 500, **who},
    "indicative": {"smoke": dict(iterations=10, max_duration="30s", **who), "average-load": dict(shape, tolerance_percent=25),
                   "overload": dict(rate_per_second=40, seconds=10, virtual_users=20, **who)},
    "verdict": {kind: dict(shape) for kind in ("smoke", "average-load", "soak", "spike", "breakpoint", "overload")},
}
json.dump(profile, open(os.path.join(load, "profile.json"), "w"))
bad = json.loads(json.dumps(profile))
del bad["verdict"]["average-load"]["decided_by"]
del bad["data"]["decided_by"]
bad["nfr"]["id"] = "the performance requirement"
os.makedirs(os.path.join(tmp, "badprofile", "lib"))
for name in ("average-load.js", "lib/gate.js"):
    open(os.path.join(tmp, "badprofile", name), "w").write("//\n")
json.dump(bad, open(os.path.join(tmp, "badprofile", "profile.json"), "w"))

latency = "http_req_duration{expected_response:true,scenario:hold}"
def summary(p95=120.0, ok=True, dropped=0, requests=300, thresholds=True, extra=None):
    metrics = {
        "http_reqs": {"type": "counter", "values": {"count": requests, "rate": 30.0}},
        latency: {"type": "trend", "values": {"p(95)": p95, "max": p95 * 2, "count": requests},
                  "thresholds": {"p(95)<400": {"ok": ok}} if thresholds else {}},
        "http_req_failed{scenario:hold}": {"type": "rate", "values": {"rate": 0, "passes": 0, "fails": requests},
                                           "thresholds": {"rate<0.005000": {"ok": True}} if thresholds else {}},
        "dropped_iterations": {"type": "counter", "values": {"count": dropped, "rate": 0},
                               "thresholds": {"count==0": {"ok": dropped == 0}} if thresholds else {}},
    }
    metrics.update(extra or {})
    return {"tier": "x", "type": "x", "metrics": metrics, "duration_ms": 10000}
cases = {
    "pass": summary(), "slower": summary(p95=180.0), "fail": summary(p95=650.0, ok=False), "dropped": summary(dropped=7),
    "nothresholds": summary(thresholds=False), "norequests": summary(requests=0),
    "breakpoint": summary(p95=450.0, ok=False, extra={"offered_rate": {"type": "gauge", "values": {"value": 22.4, "min": 5, "max": 22.4}}}),
}
for name, data in cases.items():
    json.dump(data, open(os.path.join(tmp, name + ".json"), "w"))

today = datetime.datetime.now(datetime.timezone.utc).date()
day = lambda n: str(today + datetime.timedelta(days=n))
record = {"designation_id": "perf-1", "product": "tide-tables", "base_url": f"http://127.0.0.1:{port}",
          "approved_by": "Product owner", "approved_on": day(0), "expires_on": day(30),
          "sizing": "3 replicas of 2 CPU, as NFR-PERF-01 states", "data": "2 million rows, as NFR-PERF-01 states", "generator": "one self-hosted runner, 4 CPU",
          "test_types": ["smoke", "average-load", "soak", "spike", "breakpoint", "overload"], "token_max_minutes": 60}
variants = {
    "record": {}, "nosign": {"approved_by": ""}, "placeholder": {"approved_by": "<product owner>"},
    "expired": {"approved_on": day(-40), "expires_on": day(-1)}, "future": {"approved_on": day(2)},
    "staging": {"base_url": "https://api.staging.example.com"}, "prod": {"base_url": "https://prod-eu.example.com"},
    "plainhttp": {"base_url": "http://perf.example.com"}, "withpath": {"base_url": f"http://127.0.0.1:{port}/v1"},
    "noserver": {"base_url": "http://127.0.0.1:9"}, "smokeonly": {"test_types": ["smoke"]}, "nodata": {"data": ""}, "nogenerator": {"generator": ""},
}
for name, change in variants.items():
    json.dump(dict(record, **change), open(os.path.join(tmp, name + ".json"), "w"))

# Signed impact statements: load on another system, for verification only.
now = datetime.datetime.now(datetime.timezone.utc)
moment = lambda minutes: (now + datetime.timedelta(minutes=minutes)).strftime("%Y-%m-%dT%H:%M:%SZ")
statement = {"statement_id": "verify-1", "product": "tide-tables", "base_url": f"http://127.0.0.1:{port}",
             "purpose": "verify that the station-search fix holds at the Saturday peak",
             "test_type": "average-load", "profile_limit": {"rate_per_second": 5, "peak_rate_per_second": 5, "duration_seconds": 60},
             "data_written": "none: the journey only reads", "data_removal": "nothing to remove",
             "impact": {"other_users": "searches may slow by up to 0.4 s for 1 minute", "other_teams": "none", "dependent_systems": "none",
                        "third_parties": "none: the tide feed is a stand-in", "cost": "none"},
             "how_to_stop": "Ctrl-C in the runner's terminal; k6 stops within a second", "watched_by": "test-strategist, at the terminal",
             "window_start": moment(-60), "window_end": moment(120), "marker": "served",
             "approved_by": "Product owner", "approved_on": day(0), "expires_on": day(1), "token_max_minutes": 60}
other_side = "cannot be served: the staging gateway belongs to another team and serves no marker"
impact_without_cost = {k: v for k, v in statement["impact"].items() if k != "cost"}
statements = {
    "stmt": {}, "stmt-staging": {"base_url": "https://api.staging.example.com", "marker": other_side},
    "stmt-nopurpose": {"purpose": ""}, "stmt-noimpact": {"impact": impact_without_cost}, "stmt-unsigned": {"approved_by": ""},
    "stmt-undated": {"approved_on": ""}, "stmt-expired": {"approved_on": day(-5), "expires_on": day(-1)},
    "stmt-nolapse": {"expires_on": ""}, "stmt-once": {"expires_on": "", "single_use_run_id": "gh-4242"},
    "stmt-otheraddress": {"base_url": "http://127.0.0.1:9"}, "stmt-smoke": {"test_type": "smoke"},
    "stmt-rate": {"profile_limit": {"rate_per_second": 4, "peak_rate_per_second": 4, "duration_seconds": 60}},
    "stmt-length": {"profile_limit": {"rate_per_second": 5, "peak_rate_per_second": 5, "duration_seconds": 20}},
    "stmt-window": {"window_end": moment(0)}, "stmt-marker": {"marker": "not now"},
}
for name, change in statements.items():
    json.dump(dict(statement, **change), open(os.path.join(tmp, name + ".json"), "w"))

soon = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=30)).isoformat()
late = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=90)).isoformat()
past = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(minutes=5)).isoformat()
def subjects(name, entries):
    path = os.path.join(tmp, name)
    open(path, "w").write("#!/bin/bash\ncat > \"$LOAD_SUBJECTS_FILE\" <<'JSON'\n" + json.dumps(entries) + "\nJSON\n")
    os.chmod(path, 0o755)
subjects("subjects.sh", [{"id": f"s{i}", "token": f"t{i}", "expires_at": soon} for i in range(4)])
subjects("subjects-noexpiry.sh", [{"id": "s0", "token": "t0"}])
subjects("subjects-standing.sh", [{"id": "s0", "token": "t0", "expires_at": late}])
subjects("subjects-expired.sh", [{"id": "s0", "token": "t0", "expires_at": past}])
subjects("subjects-empty.sh", [])
open(os.path.join(tmp, "kubeconfig"), "w").write("apiVersion: v1\n")
PY

# matches <pattern>: the pattern is found in standard input; "." also matches a line break
matches() {
  python3 -I -c 'import re, sys
sys.exit(0 if re.search(sys.argv[1], sys.stdin.read(), re.S) else 1)' "$1"
}

# run <label> <expected exit> <pattern or -> [VAR=value...] -- <runner arguments...>
run() {
  local label="$1" want="$2" pattern="$3"; shift 3
  local vars=()
  while [ "$1" != "--" ]; do vars+=("$1"); shift; done
  shift
  rm -f "$TMP/k6-args" "$TMP/subjects-seen" "$TMP/other-requests"
  OUT="$(cd "$TMP/product" && env -u KUBECONFIG -u E2E_RUN_ID -u E2E_KUBECONFIG -u E2E_RESULTS_DIR -u LOAD_K6 -u LOAD_K6_VERSION \
    HOME="$TMP/home" PATH="$TMP/bin:$PATH" FAKE_DIR="$TMP" ${vars[@]+"${vars[@]}"} bash "$SCRIPT" --out "$TMP/out" "$@" 2>&1)"
  RC=$?
  if [[ $RC -eq $want ]] && { [[ "$pattern" == "-" ]] || matches "$pattern" <<<"$OUT"; }; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (exit $RC, wanted $want, pattern $pattern)"; echo "$OUT"; FAILURES=$((FAILURES + 1))
  fi
}
# expect <label> <command...>: a follow-up condition on the last run
expect() {
  local label="$1"; shift
  if "$@"; then echo "PASS: $label"; else echo "FAIL: $label"; FAILURES=$((FAILURES + 1)); fi
}
never_started() { [ ! -e "$TMP/k6-args" ] && [ ! -e "$TMP/other-requests" ]; }

V=(--tier verdict --type average-load --subjects-cmd "$TMP/subjects.sh")
I=(--tier indicative --type average-load --endpoint api --subjects-cmd "$TMP/subjects.sh")
CLUSTER=("E2E_RUN_ID=run-1" "E2E_KUBECONFIG=$TMP/kubeconfig")

# --- usage and profile
run "no arguments is a usage error" 2 "usage" --
run "unknown tier" 2 "usage" -- --tier staging --type smoke --subjects-cmd true
run "unknown test type" 2 "unknown test type" -- --tier verdict --type hammer --subjects-cmd true
run "missing script folder" 2 "missing" -- --tier verdict --type smoke --subjects-cmd true --dir "$TMP/none"
run "profile with no NFR id and an unowned number" 2 "PROFILE ERROR.*nfr.id.*data.decided_by.*verdict.average-load.decided_by" -- "${V[@]}" --dir "$TMP/badprofile" --designation "$TMP/record.json"
run "a test type the profile does not plan" 2 "verdict.stress: this test type is not planned" -- --tier verdict --type stress --subjects-cmd "$TMP/subjects.sh" --designation "$TMP/record.json"

# --- verdict tier: the designation record
run "no designation record" 3 "REFUSED: the verdict tier needs --designation" -- "${V[@]}"
expect "nothing was started or requested" never_started
run "record without sign-off" 3 "REFUSED: .*no approved_by.*sign-off" -- "${V[@]}" --designation "$TMP/nosign.json"
run "record with a placeholder for the approver" 3 "REFUSED: .*no approved_by" -- "${V[@]}" --designation "$TMP/placeholder.json"
run "expired record" 3 "REFUSED: the designation expired" -- "${V[@]}" --designation "$TMP/expired.json"
run "record dated in the future" 3 "REFUSED: .*in the future" -- "${V[@]}" --designation "$TMP/future.json"
run "record without the data statement" 3 "REFUSED: .*no data" -- "${V[@]}" --designation "$TMP/nodata.json"
run "record without the generator statement" 3 "REFUSED: .*no generator" -- "${V[@]}" --designation "$TMP/nogenerator.json"
run "staging address" 3 "REFUSED: .*named like a shared staging or production" -- "${V[@]}" --designation "$TMP/staging.json"
run "production address" 3 "REFUSED: .*named like a shared staging or production" -- "${V[@]}" --designation "$TMP/prod.json"
run "plain http to another machine" 3 "REFUSED: base_url must be https" -- "${V[@]}" --designation "$TMP/plainhttp.json"
run "base_url with a path" 3 "REFUSED: .*nothing after it" -- "${V[@]}" --designation "$TMP/withpath.json"
run "test type the record does not allow" 3 "REFUSED: the designation does not allow the average-load test" -- "${V[@]}" --designation "$TMP/smokeonly.json"
run "address that serves no marker" 3 "REFUSED: .*does not serve a designation marker" -- "${V[@]}" --designation "$TMP/noserver.json"
echo "another-environment" > "$TMP/marker"
run "environment serves another designation" 3 "REFUSED: .*serves designation \"another-environment\"" -- "${V[@]}" --designation "$TMP/record.json"
expect "nothing was started or requested" never_started
: > "$TMP/marker"
run "environment serves no marker (404)" 3 "REFUSED: .*does not serve a designation marker" -- "${V[@]}" --designation "$TMP/record.json"
echo "perf-1" > "$TMP/marker"

# --- verdict tier: tokens
run "token with no expiry" 3 "REFUSED: .*states no expires_at" -- --tier verdict --type average-load --subjects-cmd "$TMP/subjects-noexpiry.sh" --designation "$TMP/record.json"
run "standing token" 3 "REFUSED: .*at most 60 minutes" -- --tier verdict --type average-load --subjects-cmd "$TMP/subjects-standing.sh" --designation "$TMP/record.json"
run "token already expired" 3 "REFUSED: .*must be valid now" -- --tier verdict --type average-load --subjects-cmd "$TMP/subjects-expired.sh" --designation "$TMP/record.json"
expect "k6 was not started" never_started
# --- verdict tier: a signed impact statement for another system
S=(--tier verdict --type average-load --subjects-cmd "$TMP/subjects.sh")
run "staging without a statement is still refused" 3 "REFUSED: .*named like a shared staging or production.*only with.*signed impact statement" -- "${S[@]}" --designation "$TMP/staging.json"
run "statement without a purpose" 3 "REFUSED: the impact statement has no purpose" -- "${S[@]}" --statement "$TMP/stmt-nopurpose.json"
run "statement without the cost of its impact" 3 "REFUSED: .*no impact.cost" -- "${S[@]}" --statement "$TMP/stmt-noimpact.json"
run "statement not signed" 3 "REFUSED: .*no approved_by: it carries no product-owner sign-off" -- "${S[@]}" --statement "$TMP/stmt-unsigned.json"
run "statement with no date of sign-off" 3 "REFUSED: .*no approved_on: it carries no product-owner sign-off" -- "${S[@]}" --statement "$TMP/stmt-undated.json"
run "expired statement" 3 "REFUSED: the impact statement expired on" -- "${S[@]}" --statement "$TMP/stmt-expired.json"
run "statement that never lapses" 3 "REFUSED: .*neither expires_on nor single_use_run_id" -- "${S[@]}" --statement "$TMP/stmt-nolapse.json"
run "single-use statement, another run" 3 "REFUSED: .*for run \"gh-4242\" only; this run is \"gh-1\"" LOAD_RUN_ID=gh-1 -- "${S[@]}" --statement "$TMP/stmt-once.json"
run "statement for another test type" 3 "REFUSED: the impact statement allows the smoke test, not average-load" -- "${S[@]}" --statement "$TMP/stmt-smoke.json"
run "profile above the statement's rate" 3 "REFUSED: the run's peak rate \(5, .*exceeds the 4" -- "${S[@]}" --statement "$TMP/stmt-rate.json"
run "profile longer than the statement allows" 3 "REFUSED: the run's length in seconds \(35.0, .*exceeds the 20" -- "${S[@]}" --statement "$TMP/stmt-length.json"
run "run that would not end inside the window" 3 "REFUSED: the run would not fit inside the statement's window" -- "${S[@]}" --statement "$TMP/stmt-window.json"
run "marker field neither served nor explained" 3 "REFUSED: .*marker must be \"served\"" -- "${S[@]}" --statement "$TMP/stmt-marker.json"
run "statement for another address than the designation" 3 "REFUSED: the designation names .*, the impact statement http://127.0.0.1:9: one run has one address" -- "${S[@]}" --designation "$TMP/record.json" --statement "$TMP/stmt-otheraddress.json"
expect "nothing was started or requested" never_started
run "statement whose system serves another marker" 3 "REFUSED: .*serves statement \"None\", the impact statement says \"verify-1\"" -- "${S[@]}" --statement "$TMP/stmt.json"
printf 'http://api.staging.example.com/.well-known/load-test-designation' > "$TMP/redirect"
run "a redirect off the stated host" 3 "REFUSED: .*answers its marker with a redirect to http://api.staging.example.com" -- "${S[@]}" --statement "$TMP/stmt.json"
expect "nothing was started or requested" never_started
: > "$TMP/redirect"
printf '{"statement_id": "verify-1"}' > "$TMP/marker"
run "statement with its marker served runs" 0 "== PASS: verdict average-load.*Verification under impact statement verify-1: .*not a capacity verdict" FAKE_K6_SUMMARY=pass -- "${S[@]}" --statement "$TMP/stmt.json"
run "single-use statement, its own run" 0 "== PASS" LOAD_RUN_ID=gh-4242 FAKE_K6_SUMMARY=pass -- "${S[@]}" --statement "$TMP/stmt-once.json"
echo "perf-1" > "$TMP/marker"
run "statement-covered staging address runs" 0 "target https://api.staging.example.com .*== PASS: verdict average-load.*not a capacity verdict" FAKE_K6_SUMMARY=pass -- "${S[@]}" --statement "$TMP/stmt-staging.json"
expect "k6 got the stated address and follows no redirect" python3 -I - "$TMP/k6-args" <<'PY'
import sys
args = open(sys.argv[1]).read().split("\n")
sys.exit(0 if "LOAD_BASE_URL=https://api.staging.example.com" in args and args[args.index("--max-redirects") + 1] == "0" else 1)
PY
expect "the result records the statement verbatim and what it does not prove" python3 -I - "$TMP/out/average-load-result.json" "$TMP/stmt-staging.json" <<'PY'
import json, sys
r, signed = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
ok = (r["target"]["statement"] == signed and r["target"]["verification"] is True and "designation" not in r["target"]
      and "not a designated environment" in r["target"]["environment"] and r["does_not_prove"][0].startswith("Capacity: this run went to a system named"))
sys.exit(0 if ok else 1)
PY
run "subjects command writes nothing usable" 2 "did not write a JSON list" -- --tier verdict --type average-load --subjects-cmd "$TMP/subjects-empty.sh" --designation "$TMP/record.json"

# --- verdict tier: reading k6's exit status and summary
run "wrong k6 version" 2 "this script needs k6 v2.4.0" FAKE_K6_VERSION=v1.9.0 -- "${V[@]}" --designation "$TMP/record.json"
run "all thresholds held" 0 "== PASS: verdict average-load test \(k6 exit 0\)" FAKE_K6_SUMMARY=pass -- "${V[@]}" --designation "$TMP/record.json"
expect "k6 got the address of the record and a proof of it" python3 -I - "$TMP" "$PORT" <<'PY'
import hashlib, sys
tmp, port = sys.argv[1:]
args = dict(a.split("=", 1) for a in open(tmp + "/k6-args").read().split("\n") if "=" in a)
base = f"http://127.0.0.1:{port}"
proof = hashlib.sha256(f"{args['LOAD_NONCE']}|verdict|{base}".encode()).hexdigest()
sys.exit(0 if args["LOAD_BASE_URL"] == base and args["LOAD_TARGET_PROOF"] == proof and "--no-thresholds" not in args else 1)
PY
expect "the subjects file existed during the run and is gone after it" bash -c '[ -s "$0/subjects-seen" ] && [ ! -e "$(cat "$0/subjects-path")" ]' "$TMP"
expect "the result file records verdict, ids and zero retries" python3 -I - "$TMP/out/average-load-result.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
ok = (r["verdict"] == "PASS" and r["nfr"]["id"] == "NFR-PERF-01" and r["slo"]["latency"]["id"] == "R-02" and r["validity"]["retries"] == 0
      and r["target"]["designation"]["approved_by"] == "Product owner" and r["shape"]["decided_by"] and r["started"].endswith("Z")
      and len(r["thresholds"]) == 3 and r["subjects"] == 4)
sys.exit(0 if ok else 1)
PY
run "k6 exit 99 is FAIL" 1 "== FAIL: .*\(k6 exit 99\).*crossed: http_req_duration.*p\(95\)<400" FAKE_K6_SUMMARY=fail FAKE_K6_EXIT=99 -- "${V[@]}" --designation "$TMP/record.json"
run "dropped iterations are INVALID, not passed" 4 "== INVALID.*7 iterations were dropped" FAKE_K6_SUMMARY=dropped FAKE_K6_EXIT=99 -- "${V[@]}" --designation "$TMP/record.json"
run "dropped iterations with exit 0 are still INVALID" 4 "== INVALID" FAKE_K6_SUMMARY=dropped -- "${V[@]}" --designation "$TMP/record.json"
run "exit 0 with no thresholds is INVALID" 4 "== INVALID.*declares no threshold" FAKE_K6_SUMMARY=nothresholds -- "${V[@]}" --designation "$TMP/record.json"
run "exit 0 with no requests is INVALID" 4 "== INVALID.*no request was sent" FAKE_K6_SUMMARY=norequests -- "${V[@]}" --designation "$TMP/record.json"
run "script exception (107) is INVALID" 4 "== INVALID.*k6 exited 107: script exception" FAKE_K6_EXIT=107 -- "${V[@]}" --designation "$TMP/record.json"
run "exit 0 without a summary is INVALID" 4 "== INVALID.*wrote no summary" -- "${V[@]}" --designation "$TMP/record.json"
run "interrupted k6 (105) is ABORTED" 130 "== ABORTED" FAKE_K6_SUMMARY=pass FAKE_K6_EXIT=105 -- "${V[@]}" --designation "$TMP/record.json"
run "breakpoint reports the rate reached" 0 "== MEASURED.*stopped at about 22.4 requests per second" FAKE_K6_SUMMARY=breakpoint FAKE_K6_EXIT=99 -- --tier verdict --type breakpoint --subjects-cmd "$TMP/subjects.sh" --designation "$TMP/record.json"

# --- a signal reaches k6 and the run ends as interrupted
rm -f "$TMP/k6-started"
(cd "$TMP/product" && exec env -u KUBECONFIG HOME="$TMP/home" PATH="$TMP/bin:$PATH" FAKE_DIR="$TMP" FAKE_K6_WAIT=1 \
  bash "$SCRIPT" --out "$TMP/out" "${V[@]}" --designation "$TMP/record.json" > "$TMP/signal.out" 2>&1) &
RUNNER=$!
python3 -I - "$TMP/k6-started" <<'PY'
import os, sys, time
deadline = time.time() + 30
while time.time() < deadline and not os.path.exists(sys.argv[1]):
    time.sleep(0.05)
PY
kill -TERM "$RUNNER" 2>/dev/null
wait "$RUNNER"; RC=$?
if [[ $RC -eq 130 ]] && grep -q "== ABORTED" "$TMP/signal.out"; then echo "PASS: SIGTERM stops k6 and exits 130"; else echo "FAIL: SIGTERM (exit $RC)"; cat "$TMP/signal.out"; FAILURES=$((FAILURES + 1)); fi

# --- indicative tier: only the run's own throwaway cluster
run "started by hand, nothing set" 3 "REFUSED: E2E_RUN_ID and E2E_KUBECONFIG are not set" -- "${I[@]}"
run "no endpoint named" 2 "needs --endpoint" "${CLUSTER[@]}" -- --tier indicative --type smoke --subjects-cmd "$TMP/subjects.sh"
run "a designation in the indicative tier" 2 "belongs to the verdict tier" "${CLUSTER[@]}" -- "${I[@]}" --designation "$TMP/record.json"
run "the caller's own kubeconfig" 3 "REFUSED: E2E_KUBECONFIG is the caller's own kubeconfig" "${CLUSTER[@]}" "KUBECONFIG=$TMP/kubeconfig" -- "${I[@]}"
run "kubeconfig without the run's context" 3 "REFUSED: the kubeconfig has no context kind-e2e-run-1" "${CLUSTER[@]}" FAKE_CONTEXT=kind-other -- "${I[@]}"
run "API server on another machine" 3 "REFUSED: .*10.20.30.40:6443\) is not on this machine" "${CLUSTER[@]}" FAKE_SERVER=10.20.30.40:6443 -- "${I[@]}"
run "cluster with no run marker" 3 "REFUSED: .*NotFound" "${CLUSTER[@]}" FAKE_NO_MARKER=1 -- "${I[@]}"
run "marker of another run" 3 "REFUSED: .*says run \"someone-else\", this run is \"run-1\"" "${CLUSTER[@]}" FAKE_MARKER_RUN=someone-else -- "${I[@]}"
run "endpoint that is a host name" 3 "REFUSED: .*no loopback address.*api.staging.example:443" "${CLUSTER[@]}" FAKE_ENDPOINT=api.staging.example:443 -- "${I[@]}"
expect "k6 was not started" never_started
run "stress is refused in the indicative tier" 3 "REFUSED: a stress test is not allowed in the indicative tier" "${CLUSTER[@]}" -- --tier indicative --type stress --endpoint api --subjects-cmd "$TMP/subjects.sh"
run "soak is refused in the indicative tier" 3 "REFUSED: a soak test is not allowed" "${CLUSTER[@]}" -- --tier indicative --type soak --endpoint api --subjects-cmd "$TMP/subjects.sh"
run "indicative pass says what it does not prove" 0 "== INDICATIVE PASS.*no previous result.*proves nothing about capacity" "${CLUSTER[@]}" FAKE_K6_SUMMARY=pass -- "${I[@]}"
expect "the address came from the run marker" grep -q "^LOAD_BASE_URL=http://127.0.0.1:$PORT\$" "$TMP/k6-args"
run "test identities of the throwaway cluster need no expiry" 0 "== INDICATIVE PASS" "${CLUSTER[@]}" FAKE_K6_SUMMARY=pass -- --tier indicative --type smoke --endpoint api --subjects-cmd "$TMP/subjects-noexpiry.sh"
run "average-load again, for the comparison baseline" 0 "== INDICATIVE PASS" "${CLUSTER[@]}" FAKE_K6_SUMMARY=pass -- "${I[@]}"
cp "$TMP/out/average-load-result.json" "$TMP/previous.json"
run "same result as the previous run" 0 "comparison with the previous run: within tolerance" "${CLUSTER[@]}" FAKE_K6_SUMMARY=pass -- "${I[@]}" --previous "$TMP/previous.json"
run "slower than the tolerance allows" 1 "== FAIL.*rose 50.0% against the previous run .*more than the 25%" "${CLUSTER[@]}" FAKE_K6_SUMMARY=slower -- "${I[@]}" --previous "$TMP/previous.json"
python3 -I - "$TMP/previous.json" "$TMP/other-runner.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
data["comparable_on"]["cpus"] += 2
json.dump(data, open(sys.argv[2], "w"))
PY
run "a previous run on another runner size is not compared" 0 "not comparable with the previous run: cpus changed" "${CLUSTER[@]}" FAKE_K6_SUMMARY=slower -- "${I[@]}" --previous "$TMP/other-runner.json"
run "indicative results go under E2E_RESULTS_DIR" 0 "result in $TMP/results/load/smoke-result.json" "${CLUSTER[@]}" "E2E_RESULTS_DIR=$TMP/results" FAKE_K6_SUMMARY=pass -- --tier indicative --type smoke --endpoint api --subjects-cmd "$TMP/subjects.sh" --out ""

if [[ $FAILURES -eq 0 ]]; then echo "PASS: run-load-test"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
