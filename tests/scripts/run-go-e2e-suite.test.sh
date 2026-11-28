#!/bin/bash
# Test for go-e2e-test's suite runner, with a fake `go` on the PATH: no Go
# toolchain, Docker or cluster is needed.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/go-e2e-test/scripts/run-go-e2e-suite.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILURES=0

mkdir -p "$TMP/bin"
# The fake prints the canned output of its Nth call ($FAKE/out.N) and exits
# with $FAKE/rc.N (0 when absent); it records its arguments in $FAKE/calls.
cat > "$TMP/bin/go" <<'FAKE'
#!/bin/bash
n=$(( $(cat "$FAKE/count" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$FAKE/count"
echo "$*" >> "$FAKE/calls"
[ -f "$FAKE/out.$n" ] && cat "$FAKE/out.$n"
exit "$(cat "$FAKE/rc.$n" 2>/dev/null || echo 0)"
FAKE
chmod +x "$TMP/bin/go"

ev() { printf '{"Action":"%s","Package":"p","Test":"%s"}\n' "$1" "$2"; }
out() { printf '{"Action":"output","Package":"p","Test":"%s","Output":"%s\\n"}\n' "$1" "$2"; }

# scenario <name>: a fresh fake directory and results directory
scenario() {
  export FAKE="$TMP/$1"
  mkdir -p "$FAKE"
  export E2E_RESULTS_DIR="$FAKE/results" E2E_QUARANTINE_FILE="$FAKE/quarantine.txt" E2E_TODAY="2026-11-28"
}

# check <label> <expected exit> <output pattern or -> <args...>
check() {
  local label="$1" want="$2" pattern="$3"; shift 3
  local rc
  OUT="$(PATH="$TMP/bin:$PATH" bash "$SCRIPT" "$@" 2>&1)"; rc=$?
  if [[ $rc -eq $want ]] && { [[ "$pattern" == "-" ]] || grep -qE -- "$pattern" <<<"$OUT"; }; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (exit $rc, wanted $want, pattern $pattern)"; echo "$OUT"; FAILURES=$((FAILURES + 1))
  fi
}

# expect <label> <pattern> <file>
expect() {
  if grep -qE -- "$2" "$3" 2>/dev/null; then echo "PASS: $1"; else
    echo "FAIL: $1 (no '$2' in $3)"; cat "$3" 2>/dev/null; FAILURES=$((FAILURES + 1)); fi
}

scenario usage
check "no arguments is a usage error" 2 "usage"
check "unknown mode" 2 "usage" everything
check "arguments without --" 2 "usage" smoke -tenant=x

scenario pass
{ ev pass TestJourney_A; ev pass TestJourney_B; } > "$FAKE/out.1"
check "all pass" 0 "journeys: 2 ran, 2 passed first time, 0 flaky, 0 failed" journeys
expect "journey command" "^test -tags e2e -count=1 -timeout 20m -json -run \^Test \./tests/e2e/$" "$FAKE/calls"
expect "one go call only" "^1$" "$FAKE/count"
expect "summary written" '"ran": 2' "$FAKE/results/journeys-summary.json"

scenario flaky
{ ev pass TestJourney_A; out TestJourney_B "    trace_test.go:37: trace_id=4bf92f3577b34da6a3ce929d0e0e4736"; ev fail TestJourney_B; } > "$FAKE/out.1"
echo 1 > "$FAKE/rc.1"
ev pass TestJourney_B > "$FAKE/out.2"
check "failed then passed is flaky, exit 0" 0 "FLAKY TestJourney_B: .*trace_id=4bf92f3577b34da6a3ce929d0e0e4736" journeys
expect "the retry names only the failed test, exactly" "^test -tags e2e .* -run \^\(TestJourney_B\)\\$ \./tests/e2e/$" "$FAKE/calls"
expect "two go calls, no third" "^2$" "$FAKE/count"
expect "flaky record in the summary" '"attempt_2": "pass"' "$FAKE/results/journeys-summary.json"

scenario twice
{ ev pass TestJourney_A; ev fail TestJourney_B; ev fail TestJourney_C/with_subtest; ev fail TestJourney_C; } > "$FAKE/out.1"
echo 1 > "$FAKE/rc.1"
{ ev pass TestJourney_B; ev fail TestJourney_C; } > "$FAKE/out.2"
echo 1 > "$FAKE/rc.2"
check "failed twice fails" 1 "FAIL TestJourney_C: failed twice" journeys
expect "subtests are retried by their top-level name" "\^\(TestJourney_B\|TestJourney_C\)\\$" "$FAKE/calls"
expect "no third attempt" "^2$" "$FAKE/count"

scenario broke
printf '{"Action":"build-output","Output":"tests/e2e/x_test.go:3: undefined: y\\n"}\n{"Action":"fail","Package":"p"}\n' > "$FAKE/out.1"
echo 1 > "$FAKE/rc.1"
check "a build failure is not retried" 1 "the run broke" journeys
expect "one go call only after a broken run" "^1$" "$FAKE/count"

scenario zero
printf '{"Action":"output","Package":"p","Output":"testing: warning: no tests to run\\n"}\n{"Action":"pass","Package":"p"}\n' > "$FAKE/out.1"
check "a selection that runs no test fails" 3 "ran no test" smoke
expect "smoke command" "^test -tags smoke -count=1 -timeout 20m -json -run \^TestSmoke \./tests/e2e/$" "$FAKE/calls"

scenario all-skipped
ev skip TestSmoke_A > "$FAKE/out.1"
check "every test skipped counts as nothing run" 3 "ran no test" smoke

scenario smoke-args
ev pass TestSmoke_A > "$FAKE/out.1"
check "arguments after -- reach the test binary" 0 "smoke: 1 ran" smoke -- -tenant=acme-drill
expect "-args passed" " \./tests/e2e/ -args -tenant=acme-drill$" "$FAKE/calls"

scenario quarantined
echo "# test | issue | deadline" > "$FAKE/quarantine.txt"
echo "TestJourney_Q | https://example.test/issues/7 | 2026-12-05" >> "$FAKE/quarantine.txt"
ev pass TestJourney_A > "$FAKE/out.1"
check "journeys leave quarantined tests out and say so" 0 "QUARANTINED TestJourney_Q: skipped here, proves nothing .*deadline 2026-12-05" journeys
expect "-skip names the quarantined test" " -run \^Test -skip \^\(TestJourney_Q\)\\$ " "$FAKE/calls"

scenario quarantine-run
echo "TestJourney_Q | https://example.test/issues/7 | 2026-12-05" > "$FAKE/quarantine.txt"
ev fail TestJourney_Q > "$FAKE/out.1"
echo 1 > "$FAKE/rc.1"
check "the quarantine run does not block" 0 "QUARANTINED TestJourney_Q: fail .*not blocking" quarantine
expect "it selects only the quarantined test" " -run \^\(TestJourney_Q\)\\$ " "$FAKE/calls"
expect "no retry in the quarantine run" "^1$" "$FAKE/count"

scenario overdue
echo "TestJourney_Q | https://example.test/issues/7 | 2026-11-27" > "$FAKE/quarantine.txt"
ev pass TestJourney_A > "$FAKE/out.1"
check "a passed deadline turns the journeys run red" 1 "quarantine deadline 2026-11-27 has passed for TestJourney_Q" journeys
scenario overdue-smoke
echo "TestJourney_Q | https://example.test/issues/7 | 2026-11-27" > "$FAKE/quarantine.txt"
ev pass TestSmoke_A > "$FAKE/out.1"
check "the smoke run ignores the journey quarantine list" 0 "smoke: 1 ran, .* 0 quarantined" smoke

scenario stale
echo "TestJourney_Gone | https://example.test/issues/9 | 2026-12-05" > "$FAKE/quarantine.txt"
printf '{"Action":"pass","Package":"p"}\n' > "$FAKE/out.1"
check "a quarantined name that matches nothing fails" 3 "ran no test" quarantine

scenario malformed
echo "TestJourney_Q | flaky, look later" > "$FAKE/quarantine.txt"
check "an entry without issue and deadline is refused" 2 "want 'TestName \| issue URL \| YYYY-MM-DD'" journeys
if [[ ! -f "$FAKE/count" ]]; then echo "PASS: go was not called"; else echo "FAIL: go was called"; FAILURES=$((FAILURES + 1)); fi

scenario empty-quarantine
check "an empty quarantine list runs nothing and passes" 0 "the list is empty" quarantine

if [[ $FAILURES -eq 0 ]]; then echo "PASS: run-go-e2e-suite"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
