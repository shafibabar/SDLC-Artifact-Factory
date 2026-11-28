#!/bin/bash
# Synthetic-input test for go-load-test's report writer. Needs no k6 and runs nothing but the script.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/go-load-test/scripts/write-load-report.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0

python3 -I - "$TMP" <<'PY'
import json, os, sys
tmp = sys.argv[1]
who = {"decided_by": "product owner, 2026-11-28", "reason": "length of one | evening peak"}
base = {
    "verdict": "PASS", "reasons": [], "tier": "verdict", "type": "average-load", "k6_exit": 0, "k6": "k6 v2.4.0 (fake)",
    "commit": "0123456789abcdef0123456789abcdef01234567", "started": "2026-11-28T04:00:00Z", "ended": "2026-11-28T04:03:00Z",
    "product": "parcel-lockers",
    "target": {"tier": "verdict", "base_url": "https://perf.lockers.example", "environment": "designated performance environment perf-1",
               "designation": {"designation_id": "perf-1", "approved_by": "Product owner", "approved_on": "2026-11-20",
                               "expires_on": "2026-12-20", "sizing": "3 replicas of 1 CPU", "data": "200,000 parcels",
                               "generator": "one runner of 4 CPU", "token_max_minutes": 180}},
    "nfr": {"id": "NFR-PERF-01", "level": "Must", "environment": "Weekday 17:00-19:00 peak: 24 lookups a second"},
    "slo": {"availability": {"id": "R-01", "objective": 0.995, "good_statuses": [{"min": 200, "max": 499}]},
            "latency": {"id": "R-02", "percentile": 95, "under_ms": 300}},
    "limiter": {"per_subject_per_second": 10, "burst": 20, "source": "charts/lockers/values.yaml"},
    "data": dict(description="200,000 parcels", distinct_items=500, **who),
    "shape": dict(rate_per_second=24, ramp_up="20s", hold="2m", virtual_users=40, warm_up="excluded", **who), "subjects": 4,
    "thresholds": [
        {"metric": "http_req_duration{expected_response:true,scenario:hold}", "threshold": "p(95)<300", "ok": True,
         "values": {"p(95)": 41.25, "max": 80.0, "count": 2880}},
        {"metric": "http_req_failed{scenario:hold}", "threshold": "rate<0.005000", "ok": True, "values": {"rate": 0.0, "passes": 0, "fails": 2880}},
    ],
    "requests": 3120, "request_rate": 22.3, "latency": {"p(95)": 41.25, "max": 80.0}, "latency_metric": "http_req_duration{expected_response:true,scenario:hold}",
    "validity": {"dropped_iterations": 0, "generator_cpu_share": 0.031, "generator_cpus": 4, "retries": 0},
    "comparable_on": {}, "comparison": None,
    "does_not_prove": ["The rolling SLO window: one run shows the targets held at this load for this run's length, not for 28 days."],
}
def write(name, **change):
    data = json.loads(json.dumps(base))
    data.update(change)
    json.dump(data, open(os.path.join(tmp, name + ".json"), "w"))
write("pass")
failed = json.loads(json.dumps(base["thresholds"]))
failed[0]["ok"] = False
write("fail", verdict="FAIL", k6_exit=99, type="overload", thresholds=failed, reasons=["crossed: http_req_duration: p(95)<300"])
write("invalid", verdict="INVALID", type="stress", reasons=["7 iterations were dropped"],
      validity={"dropped_iterations": 7, "generator_cpu_share": 0.4, "generator_cpus": 4, "retries": 0})
target = {"tier": "indicative", "base_url": "http://127.0.0.1:49315", "environment": "throwaway kind cluster e2e-run-1, created and deleted by this run"}
write("indicative", tier="indicative", verdict="INDICATIVE PASS", target=target,
      comparison={"with": "load-baseline/x.json", "metric": "p(95)", "now_ms": 1.89, "previous_ms": 1.87, "change_percent": 1.2,
                  "tolerance_percent": 30, "outcome": "within tolerance"},
      does_not_prove=["Capacity, and whether any stated target (NFR or SLO) is met: this tier never shows either."])
write("othercommit", commit="ffff456789abcdef0123456789abcdef01234567")
statement = {"statement_id": "verify-search-1", "product": "parcel-lockers", "base_url": "https://api.staging.lockers.example",
             "purpose": "verify the pickup-code fix holds at the evening peak", "test_type": "average-load",
             "profile_limit": {"rate_per_second": 24, "peak_rate_per_second": 24, "duration_seconds": 180},
             "data_written": "none: lookups only", "data_removal": "nothing to remove",
             "impact": {"other_users": "testers on staging may see lookups slow for 3 minutes", "other_teams": "courier app team, told on 2026-11-27",
                        "dependent_systems": "none", "third_parties": "none: the SMS gateway is a stand-in", "cost": "none"},
             "how_to_stop": "Ctrl-C in the runner's terminal", "watched_by": "test-strategist and the staging on-call",
             "window_start": "2026-11-28T04:00:00Z", "window_end": "2026-11-28T05:00:00Z",
             "marker": "cannot be served: the staging gateway belongs to another team", "token_max_minutes": 30,
             "approved_by": "Product owner", "approved_on": "2026-11-27", "single_use_run_id": "gh-4242"}
write("verification", target={"tier": "verdict", "base_url": "https://api.staging.lockers.example", "verification": True,
                              "environment": "api.staging.lockers.example, named in impact statement verify-search-1: a verification, not a designated environment",
                              "statement": statement},
      does_not_prove=["Capacity: this run went to a system named in an impact statement, not a designated performance environment."])
open(os.path.join(tmp, "notresult.json"), "w").write('{"verdict": "PASS"}')
open(os.path.join(tmp, "broken.json"), "w").write("{")
PY

# check <label> <expected exit> <pattern or -> <files...>
check() {
  local label="$1" want="$2" pattern="$3"; shift 3
  local out rc
  out="$(bash "$SCRIPT" "$@" 2>&1)"; rc=$?
  if [[ $rc -eq $want ]] && { [[ "$pattern" == "-" ]] || python3 -I -c 'import re, sys
sys.exit(0 if re.search(sys.argv[1], sys.stdin.read(), re.S) else 1)' "$pattern" <<<"$out"; }; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (exit $rc, wanted $want, pattern $pattern)"; echo "$out"; FAILURES=$((FAILURES + 1))
  fi
}

check "no arguments is a usage error" 2 "usage"
check "a missing file" 2 "not a result file" "$TMP/none.json"
check "a file that is not JSON" 2 "not a result file" "$TMP/broken.json"
check "a JSON file that is not a result" 2 "not a result file" "$TMP/notresult.json"
check "results of two tiers" 2 "differ in tier" "$TMP/pass.json" "$TMP/indicative.json"
check "results of two commits" 2 "differ in commit" "$TMP/pass.json" "$TMP/othercommit.json"
check "artifact frontmatter comes first" 0 "\A---\nname: load-test-report-2026-11-28\nversion: 1.0.0\nphase: quality\nowner: test-strategist\ncreated: 2026-11-28\nsummary: [^\n]{20,200}\ntraces-to: [^\n]*NFR-PERF-01[^\n]*R-01, R-02[^\n]*\n---\n" "$TMP/pass.json"
check "a verdict report names the designation and its sign-off" 0 "\*\*PASS\*\* \(verdict tier\).*perf-1: approved by Product owner on 2026-11-20, expires 2026-12-20.*3 replicas of 1 CPU.*one runner of 4 CPU.*\| Retries \| 0 \|" "$TMP/pass.json"
check "targets carry their ids" 0 "\| NFR \| NFR-PERF-01 \(Must\) \|.*\| SLO, errors \| R-01 \|.*\| SLO, latency \| R-02 \| p\(95\) under 300 ms \|" "$TMP/pass.json"
check "judgement calls name who decided, and a bar in a cell is escaped" 0 "product owner, 2026-11-28 \| length of one \\\\\| evening peak \|" "$TMP/pass.json"
check "thresholds are listed as held" 0 "\| .p\(95\)<300. \| held \| count 2880, max 80.00, p\(95\) 41.25 \|" "$TMP/pass.json"
check "the worst verdict leads, a crossed threshold is marked" 0 "\*\*FAIL\*\* \(verdict tier\). average-load PASS, overload FAIL.*\*\*crossed\*\*" "$TMP/pass.json" "$TMP/fail.json"
check "an invalid run outranks a failed one" 0 "\*\*INVALID\*\* \(verdict tier\).*stress: 7 iterations were dropped.*\| stress \| 7 \| 40.0% of 4 \| INVALID \|" "$TMP/fail.json" "$TMP/invalid.json"
check "an indicative report says what it does not prove" 0 "\*\*INDICATIVE PASS\*\* \(indicative tier\).*\*\*Indicative only.\*\*.*proves nothing about capacity.*Designation record \| none.*Comparison with the previous run.*now 1.89 ms, previous 1.87 ms, change 1.2% \(tolerance 30%\). Outcome: within tolerance" "$TMP/indicative.json"
check "the summary of an indicative report says so too" 0 "summary: Indicative load check for parcel-lockers[^\n]*Proves nothing about capacity\." "$TMP/indicative.json"
check "a verification report records the signed statement" 0 "\*\*PASS\*\* \(verdict tier, verification under signed impact statement verify-search-1\).*\*\*Verification only.\*\*.*not a capacity verdict.*\| Designation record \| none: a verification.*\| Impact statement \| verify-search-1: signed by Product owner on 2026-11-27.*\| Tokens \| issued for the run, at most 30 minutes.*## Signed impact statement.*\| Address \| https://api.staging.lockers.example \|.*\| Purpose \| verify the pickup-code fix.*\| Profile allowed \| rate 24/s, peak 24/s, at most 180 seconds \|.*\| Other teams \| courier app team.*\| Cost \| none \|.*\| How to stop it \| Ctrl-C.*\| Marker \| cannot be served: .*\| Signed by \| Product owner on 2026-11-27 \|.*\| Lapses \| single run gh-4242 \|.*Verbatim:\n\n.{3}json\n\{\n \"approved_by\": \"Product owner\".*\"statement_id\": \"verify-search-1\"" "$TMP/verification.json"
check "the summary of a verification report says it is not a capacity verdict" 0 "summary: Verification load run, not a capacity verdict, for parcel-lockers under impact statement verify-search-1 at commit 0123456789ab: average-load PASS\.\n" "$TMP/verification.json"
check "a designation report has no impact statement" 0 "\A(?!.*Signed impact statement)" "$TMP/pass.json"
check "a verdict report has no comparison section" 0 "\A(?!.*Comparison with the previous run)" "$TMP/pass.json"
check "approval is left to the product owner" 0 "## Approval\n\n\| Product owner \| Decision \| Date \| Comments \|\n\|---\|---\|---\|---\|\n\| \| approved / rejected \| \| \|\s*\Z" "$TMP/pass.json"

if [[ $FAILURES -eq 0 ]]; then echo "PASS: write-load-report"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
