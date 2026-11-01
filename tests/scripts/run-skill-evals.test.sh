#!/bin/bash
# tests/scripts/run-skill-evals.test.sh — contract for tests/run-skill-evals.sh
# (Fresh-Eyes A6, #1228). No model calls: the verdict logic is exercised with
# synthetic aggregate-result.json files via --verdict-only, and the usage
# guards are exercised with arguments that stop before the runner starts.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

RUNNER="$REPO_ROOT/tests/run-skill-evals.sh"

result() {  # result <file> <total> <passed> <meanDelta|null>
  printf '{"costUsd":0.42,"aggregates":{"casesTotal":%s,"casesPassed":%s,"meanDelta":%s}}' \
    "$2" "$3" "$4" > "$1"
}

expect() {  # expect <label> <want-exit> <want-substring> <cmd...>
  local label="$1" want_rc="$2" want="$3"; shift 3
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [[ $rc -eq $want_rc && "$out" == *"$want"* ]]; then
    _pass "run-skill-evals ($label)"
  else
    _fail "run-skill-evals ($label)" "want exit $want_rc + '$want', got exit $rc: ${out:0:200}"
  fi
}

result "$SCRATCH_DIR/pass.json" 3 3 0.67
expect "all cases pass + positive delta -> PASS" 0 "VERDICT: PASS — 3/3 cases passed, mean delta +0.67, \$0.42" \
  "$RUNNER" --verdict-only "$SCRATCH_DIR/pass.json"

result "$SCRATCH_DIR/case-fail.json" 3 2 0.50
expect "a failed case -> FAIL" 1 "1 of 3 case(s) failed" \
  "$RUNNER" --verdict-only "$SCRATCH_DIR/case-fail.json"

result "$SCRATCH_DIR/no-delta.json" 2 2 0
expect "zero delta (no better than baseline) -> FAIL even with all cases passing" 1 "does not beat the no-plugin baseline" \
  "$RUNNER" --verdict-only "$SCRATCH_DIR/no-delta.json"

result "$SCRATCH_DIR/neg-delta.json" 2 2 -0.25
expect "negative delta -> FAIL" 1 "mean delta -0.25" \
  "$RUNNER" --verdict-only "$SCRATCH_DIR/neg-delta.json"

result "$SCRATCH_DIR/no-arm.json" 2 2 null
expect "missing baseline arm -> FAIL" 1 "no baseline arm" \
  "$RUNNER" --verdict-only "$SCRATCH_DIR/no-arm.json"

result "$SCRATCH_DIR/empty.json" 0 0 0
expect "zero cases -> FAIL" 1 "no cases ran" \
  "$RUNNER" --verdict-only "$SCRATCH_DIR/empty.json"

echo "not json" > "$SCRATCH_DIR/garbage.json"
expect "unreadable result -> ERROR exit 2" 2 "VERDICT: ERROR" \
  "$RUNNER" --verdict-only "$SCRATCH_DIR/garbage.json"

expect "no arguments -> usage, exit 2" 2 "usage:" "$RUNNER"
expect "unknown skill -> exit 2" 2 "no such skill" "$RUNNER" no-such-skill-xyz
# Point the suite root at a location that never holds suites, so this guard is
# tested without depending on any real skill lacking evals (and never starts a
# billed run if a skill gains a suite — which is how this test once launched one).
expect "skill without a suite -> exit 2 naming the expected path" 2 "no-suites-here/adr-authoring/<case>/prompt.md" \
  env SKILL_EVALS_ROOT=no-suites-here "$RUNNER" adr-authoring
expect "unknown option -> exit 2 (before any run starts)" 2 "unknown option" "$RUNNER" adr-authoring --bogus 1

# Freeze status (separate authorship + grader-change rule). A throwaway git repo
# holds a copy of the runner, so the freeze commit is real but never this repo's.
FZ="$SCRATCH_DIR/freeze-repo"
mkdir -p "$FZ/tests" "$FZ/evals/demo/case-a/graders"
cp "$RUNNER" "$FZ/tests/run-skill-evals.sh"
echo "prompt" > "$FZ/evals/demo/case-a/prompt.md"
echo "grader v1" > "$FZ/evals/demo/case-a/graders/g.md"
git -C "$FZ" init -q
git -C "$FZ" -c user.name=t -c user.email=t@t add -A
git -C "$FZ" -c user.name=t -c user.email=t@t commit -qm "Add runner"
expect "no freeze commit -> FREEZE: none" 0 "FREEZE: none" \
  "$FZ/tests/run-skill-evals.sh" --freeze-status demo
git -C "$FZ" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "Freeze evals: demo"
expect "frozen and untouched -> unchanged" 0 "suite unchanged since the freeze" \
  "$FZ/tests/run-skill-evals.sh" --freeze-status demo
echo "grader v2" > "$FZ/evals/demo/case-a/graders/g.md"
expect "grader edited after the freeze -> listed" 0 "evals/demo/case-a/graders/g.md" \
  "$FZ/tests/run-skill-evals.sh" --freeze-status demo
mkdir -p "$FZ/evals/demo/case-b" && echo "new" > "$FZ/evals/demo/case-b/prompt.md"
expect "case added after the freeze (untracked) -> listed" 0 "evals/demo/case-b/prompt.md" \
  "$FZ/tests/run-skill-evals.sh" --freeze-status demo
expect "freeze-status with no skill -> usage, exit 2" 2 "usage:" "$RUNNER" --freeze-status

smoke_test_summary
