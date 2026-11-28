#!/bin/bash
# Synthetic-input test for python-chaos-test's validator: a clean product passes,
# and each defect found in python-chaos-test 1.2.0 or forbidden by the product
# owner's decisions of 2026-11-28 is flagged. Needs no Python package, Docker or
# cluster. The checks it shares with go-chaos-test's validator (manifests, Chaos
# Mesh, workflows) are held identical by python-chaos-copies.test.sh; a few of
# them are run here too, on a Python product.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/python-chaos-test/scripts/validate-python-chaos-tests.sh"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0

python3 -I - "$TMP/clean" <<'PY'
import json, os, sys
root = sys.argv[1]
def put(path, text):
    full = os.path.join(root, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, "w").write(text)
put("tests/chaos/run-chaos-experiment.sh", "#!/bin/bash\n")
put("tests/chaos/conftest.py", '''import os
import pytest
def pytest_configure(config):
    config.addinivalue_line("markers", "chaos: a chaos experiment")
def pytest_collection_modifyitems(config, items):
    for item in items:
        item.add_marker(pytest.mark.chaos)
@pytest.fixture(autouse=True)
def _guard():
    if not os.environ.get("CHAOS_EXPERIMENT_ID"):
        pytest.fail("CHAOS-REFUSED: started only by run-chaos-experiment.sh", pytrace=False)
''')
put("tests/chaos/support/chaostest.py", "import httpx\n")
put("tests/chaos/test_stations_client.py", '''from tests.chaos.support.chaostest import Dependency

async def test_breaker_opens_at_the_threshold_and_recovers(dependency):
    await expect_state(client, "closed", "steady state")
    await expect_state(client, "opened", "after the threshold")
    want = ["opened", "half-opened", "closed"]
    if client.transitions != want:
        raise AssertionError(client.transitions)
''')
put("app/downstream.py", '''import asyncio
from tenacity import AsyncRetrying, stop_after_attempt, wait_random_exponential

async def call():
    async for attempt in AsyncRetrying(stop=stop_after_attempt(3), wait=wait_random_exponential(multiplier=0.1, max=5)):
        with attempt:
            await asyncio.sleep(0)
''')
put("app/main.py", '''import asyncio, hashlib

async def usage_report():
    return await asyncio.to_thread(hashlib.sha256, b"x")
''')
put("tests/chaos/mesh/pod-kill.yaml", """apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-kill-docks
  namespace: docks
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces: [docks]
    labelSelectors: {app: docks}
""")
put("tests/chaos/chaos-e2e.conf", 'E2E_RELEASES="\nchaos-mesh|tests/chaos/charts/chaos-mesh-2.8.8.tgz|tests/chaos/chaos-mesh-values.yaml\n"\n')
put("tests/chaos/experiments/patterns.json", json.dumps({
    "experiment_id": "patterns-in-process", "pattern": "circuit-breaker", "hypothesis": "h", "blast_radius": "the pytest process",
    "fault": {"tool": "pytest", "command": "python -m pytest tests/chaos -m chaos -p no:cacheprovider -p no:rerunfailures -o addopts=\"\" --tb=short"},
    "abort": {"max_seconds": 600}}))
put(".github/workflows/chaos.yml", "name: chaos\non:\n  schedule:\n    - cron: '30 2 * * *'\n  workflow_dispatch:\njobs:\n  chaos:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: make chaos\n")
put("Makefile", "test:\n\tuv run bash scripts/check-python-coverage.sh --source src/docks --skip-suite e2e \\\n\t\t--skip-suite chaos --skip-suite load\nchaos:\n\t./tests/e2e/run-e2e-environment.sh --config tests/chaos/chaos-e2e.conf\n")
put("scripts/check-python-coverage.sh", "#!/bin/bash\n# check-python-coverage.sh [--source dir]...\n")
PY

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
case_ "chaos test outside tests/chaos" 1 "tests/unit/test_breaker_chaos.py:1: a chaos test outside tests/chaos/" \
  "put('tests/unit/test_breaker_chaos.py', 'def test_x():\n    pass\n')"
case_ "conftest without the marker" 1 "must register the chaos marker" \
  "edit('tests/chaos/conftest.py', 'config.addinivalue_line(\"markers\", \"chaos: a chaos experiment\")', 'pass')"
case_ "conftest without the guard" 1 "must refuse \(CHAOS-REFUSED\)" \
  "edit('tests/chaos/conftest.py', 'CHAOS_EXPERIMENT_ID', 'HOME')"
case_ "coverage gate collects the chaos suite" 1 "Makefile:2: the coverage gate without --skip-suite chaos" \
  "edit('Makefile', '--skip-suite chaos ', '')"
case_ "toxiproxy-python client" 1 "test_stations_client.py:1: the toxiproxy-python client" \
  "edit('tests/chaos/test_stations_client.py', 'from tests.chaos.support.chaostest import Dependency', 'from toxiproxy import Toxiproxy')"
case_ "the 1.2.0 one-call breaker test" 1 "test_breaker_opens_on_severed_db_link does not assert the breaker's states" \
  "put('tests/chaos/test_old.py', 'import pytest\n\nasync def test_breaker_opens_on_severed_db_link(chaos_stack):\n    with pytest.raises(ServiceUnavailableError):\n        await classify()\n')"
case_ "breaker test missing half-open" 1 "does not assert the breaker's states \(found \['closed', 'open'\]\)" \
  "edit('tests/chaos/test_stations_client.py', '\"half-opened\", ', '')"
case_ "retry with no stop" 1 "app/downstream.py:5: a tenacity AsyncRetrying with no stop" \
  "edit('app/downstream.py', 'stop=stop_after_attempt(3), ', '')"
case_ "bare @retry" 1 "a bare tenacity @retry" \
  "put('app/sync.py', 'from tenacity import retry\n\n@retry\ndef fetch():\n    pass\n')"
case_ "blocking call inside async def" 0 "WARN: app/main.py:4: time.sleep inside async def usage_report" \
  "edit('app/main.py', 'return await asyncio.to_thread(hashlib.sha256, b\"x\")', 'time.sleep(1)')"
case_ "chaos test that can skip" 0 "WARN: tests/chaos/test_stations_client.py:1: a chaos test that can skip" \
  "edit('tests/chaos/test_stations_client.py', 'async def', 'import pytest\n\n@pytest.mark.skipif(True, reason=\"no proxy\")\nasync def')"
case_ "reruns in the pytest settings" 1 "pyproject.toml:2: reruns in the pytest settings" \
  "put('pyproject.toml', '[tool.pytest.ini_options]\naddopts = \"--reruns 2\"\n')"
case_ "pytest experiment without the cache switch" 1 "missing: -p no:cacheprovider" \
  "edit('tests/chaos/experiments/patterns.json', '-p no:cacheprovider ', '')"
case_ "pytest experiment retried" 1 "the pytest command needs" \
  "edit('tests/chaos/experiments/patterns.json', '--tb=short', '--tb=short --reruns 2')"
case_ "pytest experiment selecting everything but chaos" 1 "the pytest command needs" \
  "edit('tests/chaos/experiments/patterns.json', '-m chaos', '-m \\\\\"not chaos\\\\\"')"
case_ "tenant namespace in a manifest (shared check)" 1 "pod-kill.yaml:[0-9]+: a tenant, shared, platform or production namespace" \
  "edit('tests/chaos/mesh/pod-kill.yaml', 'namespaces: [docks]', 'namespaces: [tenant-acme]')"
case_ "chaos on a pull request (shared check)" 1 "chaos.yml:1: a chaos run on a pull request" \
  "edit('.github/workflows/chaos.yml', '  workflow_dispatch:\n', '  workflow_dispatch:\n  pull_request:\n')"
case_ "Chaos Mesh from an unpinned chart (shared check)" 1 "the Chaos Mesh release is not the pinned" \
  "edit('tests/chaos/chaos-e2e.conf', 'charts/chaos-mesh-2.8.8.tgz', 'charts/chaos-mesh')"
case_ "runner missing" 1 "run-chaos-experiment.sh: missing" \
  "os.remove(os.path.join(root, 'tests/chaos/run-chaos-experiment.sh'))"
out="$(/bin/bash "$SCRIPT" 2>&1)"; code=$?
if [ "$code" -eq 2 ]; then echo "PASS: usage"; else echo "FAIL: usage (exit $code)"; FAILURES=$((FAILURES + 1)); fi

if [[ $FAILURES -eq 0 ]]; then echo "PASS: validate-python-chaos-tests"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
