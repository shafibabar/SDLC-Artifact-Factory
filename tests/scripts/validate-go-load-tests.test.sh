#!/bin/bash
# Synthetic-input test for go-load-test's validator. Needs no k6, Docker or cluster.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/go-load-test/scripts/validate-go-load-tests.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0

# check <label> <expected exit> <expected output pattern or -> <path...>
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

# file_case <name> <pattern> <exit> <path under the case folder> <content>
file_case() {
  local name="$1" pattern="$2" want="$3" path="$4" body="$5"
  mkdir -p "$TMP/$name/$(dirname "$path")"
  printf '%s\n' "$body" > "$TMP/$name/$path"
  check "$name" "$want" "$pattern" "$TMP/$name"
}
js_case() { file_case "$1" "$2" "$3" "tests/load/case.js" "$4"; }
mk_case() { file_case "$1" "$2" "$3" "Makefile" "$4"; }
wf_case() { file_case "$1" "$2" "$3" ".github/workflows/load.yml" "$4"; }

check "no arguments is a usage error" 2 "usage"
check "missing path" 2 "no such path" "$TMP/none"
mkdir -p "$TMP/empty" && echo "package x" > "$TMP/empty/main.go"
check "nothing to check" 2 "nothing was checked" "$TMP/empty"

GATED="import { rampAndHold, steadyThresholds, trendStats } from './lib/gate.js';"
js_case clean-script ": 0 FAIL, 0 WARN" 0 "$GATED
// A comment may say http://staging.example.com, check( and vus: 5 without being code.
export const options = { scenarios: rampAndHold('average-load'), thresholds: steadyThresholds('average-load') };
export default function () {}"
js_case no-guard "FAIL NOGUARD" 1 "import http from 'k6/http';
export const options = { scenarios: { s: { executor: 'constant-arrival-rate', rate: 5, duration: '1m', preAllocatedVUs: 5 } }, thresholds: { dropped_iterations: ['count==0'] } };
export default function () { http.get(\`\${BASE}/v1/items\`); }"
js_case staging-address "FAIL TARGET .*https://staging.internal" 1 "$GATED
export const options = { scenarios: rampAndHold('soak'), thresholds: steadyThresholds('soak') };
export default function () { http.get('https://staging.internal/compliance-engine/v1/items'); }"
js_case address-from-env "FAIL TARGET .*__ENV.BASE" 1 "$GATED
export const options = { scenarios: rampAndHold('soak'), thresholds: steadyThresholds('soak') };
export default function () { http.get(\`\${__ENV.BASE}/v1/items\`); }"
js_case check-only "FAIL CHECKONLY" 1 "$GATED
import { check } from 'k6';
export const options = { scenarios: rampAndHold('stress'), thresholds: steadyThresholds('stress') };
export default function () { const r = http.get(u); check(r, { '429 carries Retry-After': (x) => x.status !== 429 || x.headers['Retry-After'] }); }"
js_case check-with-threshold ": 0 FAIL" 0 "$GATED
import { check } from 'k6';
export const options = { scenarios: rampAndHold('stress'), thresholds: Object.assign(steadyThresholds('stress'), { 'checks{rule:shed}': ['rate==1'] }) };
export default function () { const r = http.get(u); check(r, { 'sheds': (x) => x.status === 429 }, { rule: 'shed' }); }"
js_case closed-model "FAIL CLOSED" 1 "$GATED
export const options = { scenarios: { ramp: { executor: 'ramping-vus', stages: [{ duration: '2m', target: 50 }] } }, thresholds: steadyThresholds('stress') };
export default function () {}"
js_case closed-top-level "FAIL CLOSED" 1 "$GATED
export const options = {
  vus: 50,
  duration: '5m',
  thresholds: steadyThresholds('stress'),
};
export default function () {}"
js_case closed-with-reason ": 0 FAIL" 0 "$GATED
export const options = { scenarios: { pool: { executor: 'constant-vus', vus: 8, duration: '5m' } }, thresholds: steadyThresholds('stress') }; // closed-model: eight batch workers, each waits for its answer
export default function () {}"
js_case smoke-iterations ": 0 FAIL" 0 "$GATED
export const options = { scenarios: { smoke: { executor: 'shared-iterations', vus: 1, iterations: 10 } }, thresholds: { wrong_answer: ['rate==0'] } };
export default function () {}"
js_case no-dropped-threshold "FAIL NODROP" 1 "import { BASE_URL } from './lib/gate.js';
export const options = { scenarios: { s: { executor: 'constant-arrival-rate', rate: 5, duration: '1m', preAllocatedVUs: 5 } }, thresholds: { http_req_failed: ['rate<0.01'] } };
export default function () {}"
js_case stored-token "FAIL CREDENTIALS" 1 "$GATED
const headers = { Authorization: 'Bearer-eyJhbGciOiJIUzI1NiJ9' };
export const options = { scenarios: rampAndHold('soak'), thresholds: steadyThresholds('soak') };
export default function () {}"
js_case request-retry "FAIL RETRY" 1 "$GATED
export const options = { scenarios: rampAndHold('soak'), thresholds: steadyThresholds('soak') };
export default function () { for (let attempt = 0; attempt < 3; attempt++) { if (http.get(u).status === 200) break; } }"

file_case subjects-in-repo "FAIL CREDENTIALS .*subjects file" 1 "tests/load/subjects.json" '[{"id": "s0", "token": "abc"}]'
file_case staging-designation "FAIL TARGET .*shared staging or production" 1 "tests/load/designation.json" '{"designation_id": "x", "base_url": "https://api.staging.example.com"}'
file_case production-designation "FAIL TARGET" 1 "tests/load/designation.json" '{"designation_id": "x", "base_url": "https://prod-eu.example.com:8443"}'
file_case clean-designation ": 0 FAIL" 0 "tests/load/designation.json" '{"designation_id": "x", "base_url": "https://perf.lockers.example"}'
STATEMENT='{"statement_id": "verify-1", "product": "x", "base_url": "https://api.staging.example.com", "purpose": "verify the search fix",
 "test_type": "smoke", "profile_limit": {"rate_per_second": 1, "peak_rate_per_second": 10, "duration_seconds": 30},
 "data_written": "none", "data_removal": "nothing to remove",
 "impact": {"other_users": "none", "other_teams": "none", "dependent_systems": "none", "third_parties": "none", "cost": "none"},
 "how_to_stop": "Ctrl-C", "watched_by": "test-strategist", "window_start": "2026-12-01T09:00:00Z", "window_end": "2026-12-01T10:00:00Z",
 "marker": "served", "token_max_minutes": 30, "approved_by": "Product owner", "approved_on": "2026-11-28", "expires_on": "2026-12-02"}'
file_case covered-staging ": 0 FAIL, 0 WARN" 0 "tests/load/statements/verify-1.json" "$STATEMENT"
mkdir -p "$TMP/covered-designation/tests/load/statements"
printf '%s\n' "$STATEMENT" > "$TMP/covered-designation/tests/load/statements/verify-1.json"
file_case covered-designation ": 0 FAIL" 0 "tests/load/designation.json" '{"designation_id": "x", "base_url": "https://api.staging.example.com"}'
file_case uncovered-staging "FAIL TARGET .*no signed impact statement covers that address" 1 "tests/load/statements/verify-1.json" "$(printf '%s\n' "$STATEMENT" | sed 's/"approved_by": "Product owner"/"approved_by": ""/')"
file_case unsigned-statement "FAIL STATEMENT .*no product-owner sign-off" 1 "tests/load/statements/verify-2.json" "$(printf '%s\n' "$STATEMENT" | sed 's/"approved_by": "Product owner"/"approved_by": "<product owner>"/')"
file_case statement-missing-impact "FAIL STATEMENT .*has no impact" 1 "tests/load/statements/verify-3.json" "$(printf '%s\n' "$STATEMENT" | sed 's/"impact": {[^}]*},//')"
mkdir -p "$TMP/other-address/tests/load/statements"
printf '%s\n' "$STATEMENT" > "$TMP/other-address/tests/load/statements/verify-1.json"
file_case other-address "FAIL TARGET .*prod-eu.example.com" 1 "tests/load/designation.json" '{"designation_id": "x", "base_url": "https://prod-eu.example.com"}'
file_case increase-on-gauge "FAIL GAUGEFN .*pipeline_dlq_depth" 1 "tests/load/verify-async-slos.sh" '#!/bin/bash
QUERY="1 - sum(increase(pipeline_dlq_depth[2h])) / sum(increase(pipeline_documents_processed_total[2h]))"'
file_case rate-on-gauge "FAIL GAUGEFN .*db_pool_in_use" 1 "tests/load/queries.promql" 'rate(db_pool_in_use[5m])'
file_case counters-and-gauges-right ": 0 FAIL" 0 "tests/load/queries.promql" 'sum by (code) (increase(http_server_requests_total[180s]))
histogram_quantile(0.95, sum by (le) (rate(http_server_request_duration_seconds_bucket[180s])))
max_over_time(pipeline_consumer_lag[180s])
delta(container_memory_working_set_bytes[180s])'
file_case annotation-push "FAIL PUSH" 1 "tests/load/annotate.sh" '#!/bin/bash
curl -s -X POST "$GRAFANA_URL/api/annotations" -d "{}"'

GOOD_MK='load-verdict:
	./tests/load/run-load-test.sh --tier verdict --type smoke --designation tests/load/designation.json --subjects-cmd ./tests/load/issue-subjects.sh'
mk_case clean-makefile ": 0 FAIL, 0 WARN" 0 "$GOOD_MK"
mk_case masked-or-true "FAIL MASKED" 1 "$GOOD_MK || true"
mk_case masked-dash "FAIL MASKED" 1 'load-verdict:
	-./tests/load/run-load-test.sh --tier verdict --type smoke'
mk_case masked-pipe "FAIL MASKED .*pipe" 1 "$GOOD_MK | tee load.log"
mk_case no-thresholds "FAIL MASKED" 1 'load:
	k6 run --no-thresholds tests/load/smoke.js'
mk_case direct-k6 "FAIL DIRECTK6" 1 'load-soak:
	k6 run tests/load/soak.js'
mk_case direct-k6-staging "FAIL TARGET .*https://staging.internal" 1 'load-soak:
	k6 run tests/load/soak.js --env BASE=https://staging.internal/compliance-engine'
mk_case deprecated-output "FAIL OUTPUT .*experimental-prometheus-rw" 1 'load-soak:
	k6 run --out experimental-prometheus-rw tests/load/soak.js'
mk_case metrics-pushed "FAIL PUSH" 1 'load-soak:
	k6 run --out opentelemetry tests/load/soak.js'
mk_case json-output-is-a-file "FAIL DIRECTK6" 1 'load-soak:
	k6 run --out json=results.json tests/load/soak.js'
mk_case rerun-until-green "FAIL RETRY" 1 'load-verdict:
	until ./tests/load/run-load-test.sh --tier verdict --type smoke; do echo again; done'
mk_case rerun-on-failure "FAIL RETRY" 1 "$GOOD_MK || ./tests/load/run-load-test.sh --tier verdict --type smoke"
mk_case other-tool "FAIL TOOL .*vegeta" 1 'load-spot:
	echo "GET http://127.0.0.1:8080/" | vegeta attack -rate=50 -duration=30s
	./tests/load/run-load-test.sh --tier verdict --type smoke'
mk_case paid-service "FAIL PAID" 1 'load-cloud:
	k6 cloud tests/load/soak.js'
mk_case unpinned-image "WARN UNPINNED" 1 'load:
	docker run --rm -i grafana/k6 run - < tests/load/smoke.js'
file_case masked-in-e2e-conf "FAIL MASKED" 1 "tests/e2e/e2e.conf" 'E2E_SUITES="
./tests/load/run-load-test.sh --tier indicative --type smoke --endpoint api || true
"'
file_case remote-write-setting "FAIL OUTPUT .*K6_PROMETHEUS_RW_SERVER_URL" 1 "tests/load/env.sh" 'export K6_PROMETHEUS_RW_SERVER_URL=http://127.0.0.1:9090/api/v1/write'

GOOD_WF='name: load-verdict
on:
  workflow_dispatch:
  workflow_call:
permissions:
  contents: read
jobs:
  load:
    runs-on: ubuntu-26.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - run: make load-verdict
      - if: ${{ always() }}
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2'
wf_case clean-workflow ": 0 FAIL, 0 WARN" 0 "$GOOD_WF"
wf_case pull-request-trigger "FAIL PRTRIGGER" 1 "$(printf '%s\n' "$GOOD_WF" | sed 's/^  workflow_call:/  pull_request:/')"
wf_case release-trigger "FAIL RELEASE" 1 "$(printf '%s\n' "$GOOD_WF" | sed 's/^  workflow_call:/  release:/')"
wf_case stored-secret "FAIL CREDENTIALS .*secrets.LOAD_TEST_TOKEN" 1 "$GOOD_WF
        env:
          TOKEN: \${{ secrets.LOAD_TEST_TOKEN }}"
wf_case continue-on-error "FAIL MASKED .*continue-on-error" 1 "$GOOD_WF
        continue-on-error: true"
wf_case retry-action "FAIL RETRY" 1 "$GOOD_WF
      - uses: nick-fields/retry@ce71cc2ab81d554ebbe88c79ab5975992d79ba08
        with:
          command: make load-verdict"
wf_case staging-in-workflow "FAIL TARGET .*https://staging.internal" 1 "$GOOD_WF
      - run: k6 run load/scenarios/ramp.js --env BASE=https://staging.internal/compliance-engine"
wf_case unpinned-action "WARN UNPINNED .*actions/checkout@v4" 0 "$(printf '%s\n' "$GOOD_WF" | sed 's/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1/checkout@v4/')"
wf_case upload-skipped-on-failure "WARN NOALWAYS" 0 "$(printf '%s\n' "$GOOD_WF" | grep -v 'always()' | sed 's/^        uses: actions.upload/      - uses: actions\/upload/')"
mkdir -p "$TMP/other-wf/.github/workflows"
printf 'on:\n  pull_request:\njobs:\n  ci:\n    steps:\n      - run: make ci\n' > "$TMP/other-wf/.github/workflows/ci.yml"
check "a workflow that runs no load test is not read" 2 "nothing was checked" "$TMP/other-wf"

# The shipped scripts, templates and examples must satisfy the validator.
python3 -I - "$REPO_ROOT/skills/go-load-test" "$TMP/shipped" <<'PY'
import os, re, shutil, sys
skill, out = sys.argv[1:]
count = 0
for folder in ("templates", "examples"):
    for name in sorted(os.listdir(os.path.join(skill, folder))):
        text = open(os.path.join(skill, folder, name), encoding="utf-8").read()
        for path, lang, body in re.findall(r"^#{2,4} `([\w./-]+)`\n\n```(javascript|json|yaml|makefile|bash)\n(.*?)^```", text, re.M | re.S):
            target = os.path.join(out, name[:-3], path)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            open(target, "w", encoding="utf-8").write(body)
            count += 1
assert count >= 15, f"only {count} shipped blocks extracted"
os.makedirs(os.path.join(out, "scripts", "tests", "load"))
for script in ("run-load-test.sh", "validate-go-load-tests.sh", "write-load-report.sh"):
    shutil.copy(os.path.join(skill, "scripts", script), os.path.join(out, "scripts", "tests", "load", script))
PY
check "shipped scripts, templates and examples are clean" 0 ": 0 FAIL, 0 WARN" "$TMP/shipped"

if [[ $FAILURES -eq 0 ]]; then echo "PASS: validate-go-load-tests"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
