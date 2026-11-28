#!/bin/bash
# Synthetic-input test for go-chaos-test's validator: a clean product passes,
# and each defect found in go-chaos-test 2.1.0 or forbidden by the product
# owner's decisions of 2026-11-28 is flagged. Needs no Go, Docker or cluster.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/go-chaos-test/scripts/validate-go-chaos-tests.sh"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0

# A clean product, written by one Python program so the fixtures need no GNU tool.
python3 -I - "$TMP/clean" <<'PY'
import json, os, sys
root = sys.argv[1]
def put(path, text):
    full = os.path.join(root, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, "w").write(text)
put("tests/chaos/run-chaos-experiment.sh", "#!/bin/bash\n")
put("internal/tides/client_chaos_test.go", """//go:build chaos

package tides_test

func TestChaos_BreakerTransitions(t *testing.T) {
	expectState(t, c, "closed", "steady")
	expectState(t, c, "open", "after the threshold")
	waitState(t, c, "half-open", reset)
	if _, err := proxy.AddToxic("l", "latency", "downstream", 1, nil); err != nil {
		t.Fatal(err)
	}
	remove := chaostest.AddToxic(t, toxi, "tides", "l", "latency", "downstream", nil)
	remove()
}
""")
put("internal/test/chaostest/chaostest.go", "//go:build chaos\n\npackage chaostest\n")
put("internal/roster/hook_chaos.go", "//go:build chaos\n\npackage roster\n")
put("internal/roster/roster.go", "package roster\n")
put("tests/chaos/mesh/pod-kill.yaml", """apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-kill-harbour
  namespace: harbour
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces: [harbour]
    labelSelectors: {app: harbour}
""")
put("tests/chaos/chaos-mesh-values.yaml", "chaosDaemon:\n  runtime: containerd\n  socketPath: /run/containerd/containerd.sock\n")
put("tests/chaos/chaos-e2e.conf", 'E2E_RELEASES="\nchaos-mesh|tests/chaos/charts/chaos-mesh-2.8.8.tgz|tests/chaos/chaos-mesh-values.yaml\n"\n')
put("tests/chaos/experiments/pod-kill.json", json.dumps({
    "experiment_id": "pod-kill-harbour", "pattern": "redundancy", "hypothesis": "h", "blast_radius": "one pod",
    "steady_state": {"slo_id": "SLO-1", "sli": "share of requests answered 200 in under 800 ms", "endpoint": "api", "path": "/x",
                     "good_statuses": [200], "under_ms": 800, "objective": 0.99, "window_seconds": 20, "probe_per_second": 5},
    "fault": {"tool": "chaos-mesh", "manifest": "tests/chaos/mesh/pod-kill.yaml"}, "fault_seconds": 30,
    "abort": {"sli_below": 0.5, "over_seconds": 10, "max_seconds": 60}, "recovery": {"within_seconds": 60}}))
put(".github/workflows/chaos.yml", "name: chaos\non:\n  schedule:\n    - cron: '30 2 * * *'\n  workflow_dispatch:\njobs:\n  chaos:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: make chaos\n")
put("Makefile", "chaos:\n\t./tests/e2e/run-e2e-environment.sh --config tests/chaos/chaos-e2e.conf\n")
PY

# case <name> <expected exit> <expected regex> <python that breaks a copy of the clean product>
case_() {
  local name="$1" want="$2" pattern="$3" change="$4"
  rm -rf "$TMP/p"
  cp -R "$TMP/clean" "$TMP/p"
  python3 -I - "$TMP/p" "$change" <<'PY'
import os, sys
root, change = sys.argv[1], sys.argv[2]
def put(path, text):
    full = os.path.join(root, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, "w").write(text)
def edit(path, old, new):
    full = os.path.join(root, path)
    text = open(full).read()
    assert old in text, (path, old)
    open(full, "w").write(text.replace(old, new))
exec(change)
PY
  local out code
  out="$(/bin/bash "$SCRIPT" "$TMP/p" 2>&1)"
  code=$?
  if [ "$code" -eq "$want" ] && grep -E "$pattern" > /dev/null <<<"$out"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (exit $code, want $want; pattern '$pattern')"
    printf '%s\n' "$out" | sed 's/^/    /' | head -10
    FAILURES=$((FAILURES + 1))
  fi
}

case_ "clean product" 0 "^0 FAIL, 0 WARN" "pass"
case_ "untagged chaos test" 1 "client_chaos_test.go:1: a chaos file without //go:build chaos" \
  "edit('internal/tides/client_chaos_test.go', '//go:build chaos\n\n', '')"
case_ "untagged chaos hook" 1 "hook_chaos.go:1: a chaos file without //go:build chaos" \
  "edit('internal/roster/hook_chaos.go', '//go:build chaos\n\n', '')"
case_ "test importing the chaos package without the tag" 1 "roster_test.go:1: a chaos file without" \
  "put('internal/roster/roster_test.go', 'package roster_test\n\nimport \"example.com/p/internal/test/chaostest\"\n')"
case_ "dropped AddToxic error" 1 "client_chaos_test.go:[0-9]+: a Toxiproxy call whose error is dropped" \
  "edit('internal/tides/client_chaos_test.go', 'if _, err := proxy.AddToxic(\"l\", \"latency\", \"downstream\", 1, nil); err != nil {\n\t\tt.Fatal(err)\n\t}', '_, _ = proxy.AddToxic(\"l\", \"latency\", \"downstream\", 1, nil)')"
case_ "dropped RemoveToxic error in a cleanup" 1 "a Toxiproxy call whose error is dropped" \
  "edit('internal/tides/client_chaos_test.go', 'remove()', 't.Cleanup(func() { _ = proxy.RemoveToxic(\"l\") })')"
case_ "breaker test with one call and no state" 1 "TestCircuitBreaker_OpensOnLatency does not assert the breaker's states" \
  "put('tests/chaos/old_chaos_test.go', '//go:build chaos\n\npackage chaos_test\n\nfunc TestCircuitBreaker_OpensOnLatency(t *testing.T) {\n\terr := classify(t)\n\trequire.ErrorIs(t, err, ErrServiceUnavailable)\n}\n')"
case_ "tenant namespace in a manifest" 1 "pod-kill.yaml:[0-9]+: a tenant, shared, platform or production namespace" \
  "edit('tests/chaos/mesh/pod-kill.yaml', 'namespaces: [harbour]', 'namespaces: [tenant-acme]')"
case_ "shared broker namespace" 1 "a tenant, shared, platform or production namespace" \
  "edit('tests/chaos/mesh/pod-kill.yaml', 'namespaces: [harbour]', 'namespaces: [platform-messaging]')"
case_ "selector wider than its own namespace" 1 "the selector reaches namespaces \['harbour', 'billing'\]" \
  "edit('tests/chaos/mesh/pod-kill.yaml', 'namespaces: [harbour]', 'namespaces: [harbour, billing]')"
case_ "removed scheduler field" 1 "pod-kill.yaml:[0-9]+: spec.scheduler was removed in Chaos Mesh 2.0" \
  "edit('tests/chaos/mesh/pod-kill.yaml', '    labelSelectors: {app: harbour}\n', '    labelSelectors: {app: harbour}\n  scheduler:\n    cron: \"@once\"\n')"
case_ "sustained fault without duration" 0 "WARN: .*a NetworkChaos with no duration" \
  "edit('tests/chaos/mesh/pod-kill.yaml', 'kind: PodChaos', 'kind: NetworkChaos')"
case_ "Chaos Mesh installed by hand" 1 "Makefile:[0-9]+: Chaos Mesh installed by hand" \
  "edit('Makefile', 'chaos:\n', 'chaos-install:\n\thelm install chaos-mesh chaos-mesh/chaos-mesh -n chaos-mesh\nchaos:\n')"
case_ "Chaos Mesh from an unpinned chart" 1 "chaos-e2e.conf:2: the Chaos Mesh release is not the pinned" \
  "edit('tests/chaos/chaos-e2e.conf', 'charts/chaos-mesh-2.8.8.tgz', 'charts/chaos-mesh')"
case_ "manifest applied outside the runner" 1 "a chaos manifest applied outside run-chaos-experiment.sh" \
  "edit('Makefile', 'chaos:\n', 'chaos-kill:\n\tkubectl apply -f tests/chaos/mesh/pod-kill.yaml\nchaos:\n')"
case_ "chaos on a pull request" 1 "chaos.yml:1: a chaos run on a pull request" \
  "edit('.github/workflows/chaos.yml', '  workflow_dispatch:\n', '  workflow_dispatch:\n  pull_request:\n')"
case_ "masked exit status" 1 "chaos.yml:[0-9]+: the exit status is masked" \
  "edit('.github/workflows/chaos.yml', 'run: make chaos', 'run: make chaos || true')"
case_ "retried in the workflow" 1 "a retried chaos run" \
  "edit('.github/workflows/chaos.yml', '      - run: make chaos\n', '      - uses: nick-fields/retry@v3\n        with: {command: make chaos, max_attempts: 3}\n')"
case_ "retried experiment command" 1 "a retried or repeated experiment" \
  "put('tests/chaos/experiments/go.json', '{\"experiment_id\": \"g\", \"pattern\": \"p\", \"hypothesis\": \"h\", \"blast_radius\": \"b\", \"abort\": {\"max_seconds\": 9}, \"fault\": {\"tool\": \"go-test\", \"command\": \"go test -tags chaos -count=3 ./...\"}}')"
case_ "experiment with no abort numbers" 1 "abort needs sli_below, over_seconds and max_seconds" \
  "edit('tests/chaos/experiments/pod-kill.json', '\"sli_below\": 0.5, ', '')"
case_ "steady state as a percentile" 0 "WARN: .*reads like a percentile" \
  "edit('tests/chaos/experiments/pod-kill.json', 'share of requests answered 200 in under 800 ms', 'p99 latency < 800ms')"
case_ "runner missing" 1 "run-chaos-experiment.sh: missing" \
  "os.remove(os.path.join(root, 'tests/chaos/run-chaos-experiment.sh'))"
out="$(/bin/bash "$SCRIPT" 2>&1)"; code=$?
if [ "$code" -eq 2 ]; then echo "PASS: usage"; else echo "FAIL: usage (exit $code)"; FAILURES=$((FAILURES + 1)); fi

if [[ $FAILURES -eq 0 ]]; then echo "PASS: validate-go-chaos-tests"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
