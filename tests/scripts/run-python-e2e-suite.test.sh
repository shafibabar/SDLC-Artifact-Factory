#!/bin/bash
# Test for python-e2e-test's suite runner. Part one uses a stand-in for the
# Python interpreter that plays back canned results, so it needs no pytest,
# Docker or cluster. Part two runs the real pytest when one can be imported,
# and says so clearly when it cannot.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/python-e2e-test/scripts/run-python-e2e-suite.sh"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0

mkdir -p "$TMP/bin"
# The stand-in writes the canned events of its Nth call ($FAKE/events.N, or
# $FAKE/events.every) to the file the runner's plugin would write, records its arguments and what the
# runner handed over, and exits with $FAKE/rc.N (0 when absent).
cat > "$TMP/bin/fakepy" <<'FAKE'
#!/bin/bash
n=$(( $(cat "$FAKE/count" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$FAKE/count"
echo "$*" >> "$FAKE/calls"
echo "keep=$E2E_RUNNER_KEEP drop=$E2E_RUNNER_DROP addopts=${PYTEST_ADDOPTS:-unset}" >> "$FAKE/handed"
if [ -f "$FAKE/events.$n" ]; then cat "$FAKE/events.$n" > "$E2E_RUNNER_EVENTS"
elif [ -f "$FAKE/events.every" ]; then cat "$FAKE/events.every" > "$E2E_RUNNER_EVENTS"; fi
if [ -f "$FAKE/hang" ]; then exec python3 -I -c 'import time; time.sleep(60)'; fi
exit "$(cat "$FAKE/rc.$n" 2>/dev/null || echo 0)"
FAKE
chmod +x "$TMP/bin/fakepy"

A="tests/e2e/journeys/test_journey_a.py::test_journey_a"
B="tests/e2e/journeys/test_journey_b.py::test_journey_b"
S="tests/e2e/smoke/test_smoke.py::test_smoke_reads"
# collected <id>...; report <id> <when> <outcome> [trace id] [refused]
collected() {
  local ids="" id
  for id in "$@"; do ids="$ids\"$id\","; done
  printf '{"event": "collected", "ids": [%s]}\n' "${ids%,}"
}
report() {
  printf '{"event": "report", "id": "%s", "when": "%s", "outcome": "%s", "refused": %s, "trace": "%s"}\n' "$1" "$2" "$3" "${5:-false}" "${4:-}"
}
passed() { report "$1" setup passed; report "$1" call passed; report "$1" teardown passed; }
# every: the events on stdin are played back on every later call of this scenario
every() { rm -f "$FAKE"/events.* "$FAKE"/rc.* "$FAKE/count" "$FAKE/handed"; cat > "$FAKE/events.every"; }

# scenario <name>: a fresh product folder with the two test folders
scenario() {
  export FAKE="$TMP/$1"
  mkdir -p "$FAKE/product/tests/e2e/journeys" "$FAKE/product/tests/e2e/smoke"
  export E2E_RESULTS_DIR="$FAKE/results" E2E_TODAY="2026-11-28" E2E_PYTHON="$TMP/bin/fakepy"
  unset E2E_PY_QUARANTINE_FILE E2E_PY_TIMEOUT E2E_PY_DIR
}

# check <label> <expected exit> <output pattern or -> <args...>
check() {
  local label="$1" want="$2" pattern="$3"; shift 3
  local rc
  OUT="$(cd "$FAKE/product" && PYTEST_ADDOPTS="--reruns 5" bash "$SCRIPT" "$@" 2>&1)"; rc=$?
  if [[ $rc -eq $want ]] && { [[ "$pattern" == "-" ]] || grep -qE -- "$pattern" <<<"$OUT"; }; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (exit $rc, wanted $want, pattern $pattern)"; echo "$OUT"; FAILURES=$((FAILURES + 1))
  fi
}
expect() {
  if grep -qE -- "$2" "$3" 2>/dev/null; then echo "PASS: $1"; else
    echo "FAIL: $1 (no '$2' in $3)"; cat "$3" 2>/dev/null; FAILURES=$((FAILURES + 1)); fi
}
refuse() {
  if grep -qE -- "$2" "$3" 2>/dev/null; then
    echo "FAIL: $1 ('$2' found in $3)"; FAILURES=$((FAILURES + 1)); else echo "PASS: $1"; fi
}

# -------------------------------------------------------------------- usage
scenario usage
check "no arguments is a usage error" 2 "usage"
check "unknown mode" 2 "usage" everything
check "extra arguments are refused, so nothing can narrow the selection" 2 "usage" smoke -k one
scenario nofolder
rm -rf "$FAKE/product/tests/e2e/smoke"
check "a missing folder is a selection that ran nothing" 3 "ran no test" smoke

# --------------------------------------------------------------------- pass
scenario pass
{ collected "$A" "$B"; passed "$A"; passed "$B"; } > "$FAKE/events.1"
check "all pass" 0 "python journeys: 2 ran, 2 passed first time, 0 flaky, 0 failed" journeys
expect "the journey command: folder, marker, cleared addopts, no rerun plugin" \
  "^-m pytest tests/e2e/journeys -m e2e and not smoke -o addopts= -p e2e_runner_plugin -p no:rerunfailures -p no:flaky -p no:cacheprovider -v --junitxml=" "$FAKE/calls"
expect "PYTEST_ADDOPTS does not reach pytest" "addopts=unset" "$FAKE/handed"
expect "one pytest process only" "^1$" "$FAKE/count"
expect "summary written" '"ran": 2' "$FAKE/results/python-journeys-summary.json"

# -------------------------------------------------------------------- flaky
scenario flaky
{ collected "$A" "$B"; passed "$A"; report "$B" setup passed; report "$B" call failed 4bf92f3577b34da6a3ce929d0e0e4736; report "$B" teardown passed; } > "$FAKE/events.1"
echo 1 > "$FAKE/rc.1"
{ collected "$A" "$B"; passed "$B"; } > "$FAKE/events.2"
check "failed then passed is flaky, exit 0, and is not called green" 0 "FLAKY $B: .*trace_id=4bf92f3577b34da6a3ce929d0e0e4736\). Not green" journeys
expect "the retry names only the failed test, by exact node id" "^keep=\[\"$B\"\] drop=\[\]" "$FAKE/handed"
expect "two pytest processes, no third" "^2$" "$FAKE/count"
expect "flaky record in the summary" '"attempt_2": "pass"' "$FAKE/results/python-journeys-summary.json"

scenario twice
{ collected "$A" "$B"; report "$A" setup failed; report "$A" teardown passed; report "$B" setup passed; report "$B" call passed; report "$B" teardown failed; } > "$FAKE/events.1"
echo 1 > "$FAKE/rc.1"
{ collected "$A" "$B"; passed "$A"; report "$B" setup passed; report "$B" call failed aaaabbbbccccddddeeeeffff00001111; report "$B" teardown passed; } > "$FAKE/events.2"
echo 1 > "$FAKE/rc.2"
check "failed twice fails" 1 "FAIL $B: failed twice \(trace_id=aaaabbbbccccddddeeeeffff00001111\)" journeys
expect "a setup error and a failed cleanup both count as failures and are retried" "keep=\[\"$A\", \"$B\"\]" "$FAKE/handed"
expect "no third attempt" "^2$" "$FAKE/count"
if grep -qE "FLAKY $A" <<<"$OUT"; then echo "PASS: the other test is reported flaky"; else echo "FAIL: flaky line missing"; FAILURES=$((FAILURES + 1)); fi

# ------------------------------------------------------- a run that broke
scenario refused
{ collected "$A" "$B"; report "$A" setup failed "" true; report "$B" setup failed "" true; } > "$FAKE/events.1"
echo 1 > "$FAKE/rc.1"
check "a refusal by the guard is not retried" 1 "python journeys: 0 ran.*" journeys
if grep -q "the guard refused the target. Not retried" <<<"$OUT"; then echo "PASS: says the guard refused"; else echo "FAIL: refusal message"; FAILURES=$((FAILURES + 1)); fi
expect "one pytest process only after a refusal" "^1$" "$FAKE/count"
scenario collection-error
echo 2 > "$FAKE/rc.1"
check "a collection error is a broken run, not a retry" 1 "the run broke: pytest exited 2" journeys
expect "one pytest process only after a collection error" "^1$" "$FAKE/count"
scenario usage-error
echo 4 > "$FAKE/rc.1"
check "a usage error is a broken run" 1 "the run broke: pytest exited 4" smoke
scenario exit1-no-failure
{ collected "$A"; passed "$A"; } > "$FAKE/events.1"
echo 1 > "$FAKE/rc.1"
check "exit 1 with no failed test is a broken run" 1 "the run broke" journeys
scenario time-limit
touch "$FAKE/hang"
E2E_PY_TIMEOUT=1 check "the time limit stops pytest and nothing is retried" 1 "the run broke: the time limit of 1s was reached" journeys
expect "one pytest process only at the time limit" "^1$" "$FAKE/count"

# ------------------------------------------------- selections that prove nothing
scenario none
collected > "$FAKE/events.1"
echo 5 > "$FAKE/rc.1"
check "nothing collected or everything deselected (pytest exit 5)" 3 "the smoke selection ran no test \(pytest exited 5\)" smoke
expect "the smoke command: its own folder and marker" "^-m pytest tests/e2e/smoke -m smoke " "$FAKE/calls"
scenario all-skipped
{ collected "$S"; report "$S" setup skipped; report "$S" teardown passed; } > "$FAKE/events.1"
check "every test skipped: pytest exits 0, the runner does not" 3 "0 ran, .* 1 skipped.*" smoke

# --------------------------------------------------------------- quarantine
scenario quarantine
Q="$FAKE/product/tests/e2e/quarantine-python.txt"
printf '# node id | issue | deadline\n\n%s | https://github.com/o/r/issues/7 | 2026-12-12\n' "$B" > "$Q"
{ collected "$A" "$B"; passed "$A"; } | every
check "journeys leave the quarantined test out and say it proves nothing" 0 "QUARANTINED $B: left out here, proves nothing \(issue https://github.com/o/r/issues/7, deadline 2026-12-12\)" journeys
expect "the quarantined node id is handed to pytest for deselection" "^keep=null drop=\[\"$B\"\]" "$FAKE/handed"
E2E_TODAY=2026-12-13 check "red from the day after the deadline" 1 "quarantine deadline 2026-12-12 has passed for $B" journeys
E2E_TODAY=2026-12-12 check "not yet red on the deadline itself" 0 "QUARANTINED" journeys
{ collected "$A" "$B"; report "$B" setup passed; report "$B" call failed; report "$B" teardown passed; } | every
echo 1 > "$FAKE/rc.1"
check "the quarantine run does not block on a failing quarantined test" 0 "QUARANTINED $B: fail .*not blocking, and not counted as passed" quarantine
expect "the quarantine run selects only the listed tests" "^keep=\[\"$B\"\] drop=\[\]" "$FAKE/handed"
expect "the quarantine run does not retry" "^1$" "$FAKE/count"
{ collected "$S"; passed "$S"; } | every
E2E_TODAY=2026-12-13 check "the smoke selection ignores the quarantine list" 0 "python smoke: 1 ran, 1 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined" smoke
{ collected "$A"; passed "$A"; } | every
printf '%s | https://github.com/o/r/issues/7 | 2026-12-12\n%s | https://github.com/o/r/issues/8 | 2026-12-12\n' "$A" "$B" > "$Q"
check "a quarantined node id that matches no test fails the quarantine run" 1 "quarantined but not found in tests/e2e/journeys: $B" quarantine
printf '%s | 2026-12-12\n' "$B" > "$Q"
check "an entry without an issue is refused" 2 "want 'tests/e2e/journeys/<file>.py::<test> \| issue URL \| YYYY-MM-DD'" journeys
printf '%s | https://github.com/o/r/issues/7 | next week\n' "$B" > "$Q"
check "an entry without a real date is refused" 2 "quarantine-python.txt:1" journeys
printf 'TestJourney_BulkImport | https://github.com/o/r/issues/7 | 2026-12-12\n' > "$Q"
check "a Go test name (go-e2e-test's list format) is refused: the two lists stay separate" 2 "got: TestJourney_BulkImport" journeys
printf '%s | https://github.com/o/r/issues/7 | 2026-12-12\n' "$S" > "$Q"
check "a smoke test cannot be quarantined" 2 "want 'tests/e2e/journeys/" journeys
rm -f "$Q" "$FAKE/count"
check "an empty quarantine list runs nothing and passes" 0 "the list is empty; nothing to run" quarantine
if [[ ! -f "$FAKE/count" ]]; then echo "PASS: no pytest process for an empty quarantine list"; else echo "FAIL: pytest was started"; FAILURES=$((FAILURES + 1)); fi

# The Go twin's runner must refuse a pytest node id in its list, which is why
# the Python list is a separate file with a separate variable.
GO_RUNNER="$REPO_ROOT/skills/go-e2e-test/scripts/run-go-e2e-suite.sh"
printf '%s | https://github.com/o/r/issues/7 | 2026-12-12\n' "$B" > "$TMP/shared.txt"
OUT="$(E2E_QUARANTINE_FILE="$TMP/shared.txt" E2E_RESULTS_DIR="$TMP/go-results" bash "$GO_RUNNER" journeys 2>&1)"; rc=$?
if [[ $rc -eq 2 ]] && grep -q "want 'TestName" <<<"$OUT"; then echo "PASS: go-e2e-test's runner refuses a pytest node id (exit 2)"; else
  echo "FAIL: go runner on a node id (exit $rc)"; echo "$OUT"; FAILURES=$((FAILURES + 1)); fi

# ------------------------------------------------------------ the real pytest
if python3 -c 'import pytest' 2>/dev/null; then
  REAL="$TMP/real"
  mkdir -p "$REAL/tests/e2e/journeys" "$REAL/tests/e2e/smoke"
  touch "$REAL/tests/__init__.py" "$REAL/tests/e2e/__init__.py" "$REAL/tests/e2e/journeys/__init__.py" "$REAL/tests/e2e/smoke/__init__.py"
  printf '[pytest]\naddopts = -k nothing_matches_this\n' > "$REAL/pytest.ini"
  cat > "$REAL/tests/e2e/conftest.py" <<'PY'
import pytest


def pytest_configure(config):
    config.addinivalue_line("markers", "e2e: journey")
    config.addinivalue_line("markers", "smoke: read-only")


def pytest_collection_modifyitems(config, items):
    for item in items:
        item.add_marker(pytest.mark.smoke if "/smoke/" in str(item.path) else pytest.mark.e2e)


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    report = outcome.get_result()
    if report.failed:
        report.sections.append(("trace", "trace_id=0123456789abcdef0123456789abcdef"))
PY
  cat > "$REAL/tests/e2e/journeys/test_journey_real.py" <<'PY'
import os
import pathlib

import pytest


def test_journey_steady():
    assert True


def test_journey_fails_once():
    flag = pathlib.Path(os.environ["REAL_FLAG"])
    if not flag.exists():
        flag.write_text("x")
        raise AssertionError("first attempt")


def test_journey_always_fails():
    assert os.environ.get("REAL_ALWAYS") != "1", "always"


@pytest.fixture
def refused():
    if os.environ.get("REAL_REFUSE") == "1":
        pytest.fail("REFUSED: not this run's cluster", pytrace=False)


def test_journey_guarded(refused):
    assert True
PY
  printf 'import pytest\n\n\n@pytest.mark.skip(reason="lab")\ndef test_smoke_skipped():\n    pass\n' > "$REAL/tests/e2e/smoke/test_smoke_real.py"
  real() {
    local label="$1" want="$2" pattern="$3"; shift 3
    local rc
    OUT="$(cd "$REAL" && E2E_PYTHON=python3 E2E_RESULTS_DIR="$REAL/results" REAL_FLAG="$REAL/flag" bash "$SCRIPT" "$@" 2>&1)"; rc=$?
    if [[ $rc -eq $want ]] && grep -qE -- "$pattern" <<<"$OUT"; then echo "PASS: real pytest: $label"; else
      echo "FAIL: real pytest: $label (exit $rc, wanted $want, pattern $pattern)"; echo "$OUT"; FAILURES=$((FAILURES + 1)); fi
  }
  ID="tests/e2e/journeys/test_journey_real.py"
  unset E2E_PY_QUARANTINE_FILE E2E_PY_TIMEOUT E2E_PY_DIR
  real "a test that fails once is flaky, with its trace id; the product's addopts is ignored" 0 \
    "FLAKY $ID::test_journey_fails_once: failed, then passed on the one retry \(trace_id=0123456789abcdef0123456789abcdef\)" journeys
  if grep -q "python journeys: 4 ran, 3 passed first time, 1 flaky, 0 failed" <<<"$OUT"; then echo "PASS: real pytest: counts"; else echo "FAIL: real pytest: counts"; echo "$OUT"; FAILURES=$((FAILURES + 1)); fi
  if grep -qE "1 passed, 3 deselected" <<<"$OUT"; then echo "PASS: real pytest: the retry ran exactly one test"; else echo "FAIL: real pytest: retry selection"; echo "$OUT"; FAILURES=$((FAILURES + 1)); fi
  if [[ -f "$REAL/results/python-journeys-attempt2.xml" ]]; then echo "PASS: real pytest: a JUnit file per attempt"; else echo "FAIL: no JUnit file for the retry"; FAILURES=$((FAILURES + 1)); fi
  REAL_ALWAYS=1 real "a test that always fails is retried once and fails the run" 1 "FAIL $ID::test_journey_always_fails: failed twice" journeys
  REAL_REFUSE=1 real "a refusal is reported once and not retried" 1 "the guard refused the target. Not retried" journeys
  real "every smoke test skipped is a selection that ran nothing" 3 "python smoke: 0 ran, .* 1 skipped" smoke
  printf '%s::test_journey_always_fails | https://github.com/o/r/issues/9 | 2026-12-12\n' "$ID" > "$REAL/tests/e2e/quarantine-python.txt"
  REAL_ALWAYS=1 real "a quarantined failing test does not fail the journeys" 0 "3 ran, 3 passed first time, 0 flaky, 0 failed, 0 skipped, 1 quarantined" journeys
  REAL_ALWAYS=1 real "the quarantine run runs it and does not block" 0 "QUARANTINED $ID::test_journey_always_fails: fail" quarantine
else
  echo "SKIP: pytest cannot be imported by python3 here, so the cases that run the real pytest were not run"
fi

if [[ $FAILURES -eq 0 ]]; then echo "PASS: run-python-e2e-suite"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
