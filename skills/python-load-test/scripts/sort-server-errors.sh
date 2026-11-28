#!/bin/bash
# sort-server-errors.sh <type>-k6-summary.json...
#
# Prints, as a Markdown table for the load-test report, how the answers the SLI
# counted as failed divide up, from the k6 summaries a run wrote (the Python
# journey.js records the three counters):
#   server_shed       uvicorn's own 503 at --limit-concurrency (body "Service
#                     Unavailable", text/plain): the application never saw it
#   app_server_error  any other 5xx: the application's own answer, or a proxy's
#   no_answer         status 0: refused, reset or timed out
# It changes no verdict: each of these already counts against the SLI. A
# counter that never fired is absent from the summary and is printed as 0.
# Exit 0 = table printed; 2 = usage or a file that is not a k6 summary of gate.js.
set -uo pipefail
if [ "$#" -eq 0 ]; then
  echo "usage: sort-server-errors.sh <type>-k6-summary.json..." >&2
  exit 2
fi
exec python3 -I - "$@" << 'PY'
import json, sys

rows = []
for path in sys.argv[1:]:
    try:
        data = json.load(open(path, encoding="utf-8"))
        metrics = data["metrics"]
        requests = int(metrics["http_reqs"]["values"]["count"])
        failed = int(metrics["http_req_failed"]["values"]["passes"])
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(f"ERROR: {path} is not a k6 summary written by lib/gate.js ({exc!r})", file=sys.stderr)
        sys.exit(2)
    count = lambda name: int(((metrics.get(name) or {}).get("values") or {}).get("count") or 0)
    shed, app, none = count("server_shed"), count("app_server_error"), count("no_answer")
    rows.append((data.get("type") or path, requests, failed, shed, app, none))

print("| Test type | Requests | Counted failed by the SLI | uvicorn's own 503 (concurrency limit) | Other 5xx (application or proxy) | No answer (status 0) |")
print("|---|---|---|---|---|---|")
for kind, requests, failed, shed, app, none in rows:
    print(f"| {kind} | {requests} | {failed} | {shed} | {app} | {none} |")
print("")
print("Every column after the third is already inside \"Counted failed by the SLI\": the split says where to look, not whether the run passed.")
PY
