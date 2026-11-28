#!/bin/bash
# Synthetic-input test for python-load-test's own scripts: check-python-profile.sh
# (workers, replicas and the per-process rate limiter in a load profile) and
# sort-server-errors.sh (uvicorn's own 503 told apart from other 5xx in a k6
# summary). Needs no k6, Docker, cluster or Python packages.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
CHECK="$REPO_ROOT/skills/python-load-test/scripts/check-python-profile.sh"
SORT="$REPO_ROOT/skills/python-load-test/scripts/sort-server-errors.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0

# run <label> <expected exit> <pattern or -> <script> <args...>
run() {
  local label="$1" want="$2" pattern="$3"; shift 3
  local out rc
  out="$(bash "$@" 2>&1)"; rc=$?
  if [[ $rc -eq $want ]] && { [[ "$pattern" == "-" ]] || grep -qE -- "$pattern" <<<"$out"; }; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (exit $rc, wanted $want, pattern $pattern)"; echo "$out"; FAILURES=$((FAILURES + 1))
  fi
}

# The shipped profile of ../templates/profile.md, and variants of it.
python3 -I - "$REPO_ROOT/skills/python-load-test/templates/profile.md" "$TMP" <<'PY'
import json, os, re, sys
text = open(sys.argv[1], encoding="utf-8").read()
body = re.search(r"^### `tests/load/profile.json`\n\n```json\n(.*?)^```", text, re.M | re.S).group(1)
base = json.loads(body)
def write(name, change):
    data = json.loads(json.dumps(base))
    change(data)
    json.dump(data, open(os.path.join(sys.argv[2], name + ".json"), "w"))
write("shipped", lambda d: None)
write("not-multiplied", lambda d: d["limiter"].update(per_subject_per_second=10, burst=20))
write("no-server", lambda d: d.pop("server"))
write("no-limit-key", lambda d: d["server"].pop("limit_concurrency"))
write("no-per-process", lambda d: d["limiter"].pop("per_process_per_second"))
write("overload-too-low", lambda d: d["verdict"]["overload"].update(rate_per_second=20))
write("gunicorn-limit", lambda d: d["server"].update(runtime="gunicorn 27.0.1 with uvicorn-worker"))
write("old-worker", lambda d: (d["server"].update(runtime="gunicorn -k uvicorn.workers.UvicornWorker", limit_concurrency=None)))
write("low-limit", lambda d: d["server"].update(limit_concurrency=50))
write("four-workers", lambda d: (d["server"].update(workers=4, replicas=1), d["limiter"].update(per_subject_per_second=40, burst=80),
                                 d["verdict"]["overload"].update(rate_per_second=60)))
open(os.path.join(sys.argv[2], "broken.json"), "w").write("{ not json")
PY

run "no arguments is a usage error" 2 "usage" "$CHECK"
run "an unreadable profile" 2 "cannot read" "$CHECK" "$TMP/broken.json"
run "a bad --subjects value" 2 "usage" "$CHECK" "$TMP/shipped.json" --subjects none
run "the shipped profile passes with five subjects" 0 "2 process\(es\).*" "$CHECK" "$TMP/shipped.json" --subjects 5
run "the shipped profile names the rate at which 429 begins" 0 "answered 429 only above about 20/s \(burst 40\)" "$CHECK" "$TMP/shipped.json"
run "four subjects are too few for 45 a second" 1 "FAIL verdict.stress: 45/s over 4 subject\(s\) is 11.25/s each, above one process's 10/s; use at least 5" "$CHECK" "$TMP/shipped.json" --subjects 4
run "a limiter copied from one process is refused" 1 "FAIL limiter.per_subject_per_second is 10, but 10 per process x 1 worker\(s\) x 2 replica\(s\) is 20" "$CHECK" "$TMP/not-multiplied.json"
run "the burst is multiplied too" 1 "FAIL limiter.burst is 20, but .* is 40" "$CHECK" "$TMP/not-multiplied.json"
run "no server block" 1 "FAIL server: missing" "$CHECK" "$TMP/no-server.json"
run "limit_concurrency must be stated, null included" 1 "FAIL server.limit_concurrency: null when" "$CHECK" "$TMP/no-limit-key.json"
run "no per-process rate" 1 "FAIL limiter.per_process_per_second" "$CHECK" "$TMP/no-per-process.json"
run "an overload that cannot exceed the processes' total" 1 "FAIL verdict.overload: 20/s on one subject does not exceed 20/s" "$CHECK" "$TMP/overload-too-low.json"
run "Gunicorn with --limit-concurrency" 1 "FAIL server: --limit-concurrency is not supported when uvicorn runs under Gunicorn" "$CHECK" "$TMP/gunicorn-limit.json"
run "the deprecated uvicorn.workers module is a warning" 0 "WARN server.runtime: the uvicorn.workers module is deprecated" "$CHECK" "$TMP/old-worker.json"
run "virtual users at or above --limit-concurrency is a warning" 0 "WARN k6 may hold 120 connections .* --limit-concurrency 50" "$CHECK" "$TMP/low-limit.json"
run "four workers in one replica multiply like replicas" 0 "answered 429 only above about 40/s \(burst 80\)" "$CHECK" "$TMP/four-workers.json"

# sort-server-errors.sh on k6 summaries shaped like lib/gate.js's handleSummary.
python3 -I - "$TMP" <<'PY'
import json, os, sys
def summary(name, kind, reqs, failed, extra):
    metrics = {"http_reqs": {"type": "counter", "values": {"count": reqs, "rate": 24.0}},
               "http_req_failed": {"type": "rate", "values": {"rate": failed / reqs, "passes": failed, "fails": reqs - failed}}}
    for metric, count in extra.items():
        metrics[metric] = {"type": "counter", "values": {"count": count, "rate": 1.0}}
    json.dump({"tier": "verdict", "type": kind, "metrics": metrics}, open(os.path.join(sys.argv[1], name), "w"))
summary("shed.json", "average-load", 324, 252, {"server_shed": 252})
summary("mixed.json", "overload", 400, 30, {"server_shed": 10, "app_server_error": 15, "no_answer": 5})
summary("clean.json", "smoke", 10, 0, {})
open(os.path.join(sys.argv[1], "other.json"), "w").write('{"metrics": {}}')
PY
run "no arguments is a usage error" 2 "usage" "$SORT"
run "a file that is not a k6 summary" 2 "is not a k6 summary" "$SORT" "$TMP/other.json"
run "uvicorn's 503 counted apart" 0 "\| average-load \| 324 \| 252 \| 252 \| 0 \| 0 \|" "$SORT" "$TMP/shed.json"
run "each kind of failure in its own column" 0 "\| overload \| 400 \| 30 \| 10 \| 15 \| 5 \|" "$SORT" "$TMP/mixed.json"
run "a counter that never fired is 0" 0 "\| smoke \| 10 \| 0 \| 0 \| 0 \| 0 \|" "$SORT" "$TMP/clean.json"
run "the table says the split changes no verdict" 0 "not whether the run passed" "$SORT" "$TMP/shed.json" "$TMP/clean.json"

if [[ $FAILURES -eq 0 ]]; then echo "PASS: python-load-profile"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
