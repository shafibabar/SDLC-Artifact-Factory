#!/bin/bash
# Tests skills/acceptance-sign-off/scripts/validate-signoff.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here from a fresh scaffold, never from the skill's
# examples, so the test does not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/acceptance-sign-off/scripts/validate-signoff.sh"
SCAFFOLD="$REPO_ROOT/skills/acceptance-sign-off/scripts/scaffold-signoff.sh"

cd "$SCRATCH_DIR"

# Output only; the exit code is swallowed so pipefail does not mask grep.
run_validate() { "$VALIDATE" "$1" 2>&1 || true; }

# A fresh scaffold has five unfilled fields (product owner, customer rep,
# Decision, Residual Risk, Rollout Action) -- must fail exactly those five.
FRESH="$("$SCAFFOLD" acme "2026-08 classification v2")"
OUTPUT="$("$VALIDATE" "$FRESH" 2>&1)"
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 1 ]; then
  _pass "validate-signoff: a fresh scaffold with unfilled fields fails"
else
  _fail "validate-signoff: a fresh scaffold with unfilled fields fails" "got exit $EXIT_CODE"
fi

if echo "$OUTPUT" | grep -q "5 check(s) failed"; then
  _pass "validate-signoff: reports exactly 5 failed checks on a fresh scaffold"
else
  _fail "validate-signoff: reports exactly 5 failed checks on a fresh scaffold" "expected '5 check(s) failed'; got: $(echo "$OUTPUT" | grep FAIL)"
fi

if echo "$OUTPUT" | grep -q "PASS: Sign-Off Criteria Checklist section present" && echo "$OUTPUT" | grep -q "PASS: checklist has at least one item"; then
  _pass "validate-signoff: does not false-fail the structural checks on a fresh scaffold"
else
  _fail "validate-signoff: does not false-fail the structural checks on a fresh scaffold" "expected checklist checks to pass"
fi

# Fill a two-party full sign-off.
fill_two_party() {
  sed -i 's/^- \[Name\] (product owner).*/- Ines Duarte (product owner) — agreed 2026-08-20, review/' "$1"
  sed -i 's/\[Name, role, company\] (customer representative).*/Arjun Patel, ops lead, Acme Corp (customer representative) — agreed 2026-08-20, email/' "$1"
  sed -i 's/\[What is knowingly accepted.*/FB-3 (Low) accepted by Ines Duarte./' "$1"
  sed -i 's/\[canary-deployment widen\/hold\/revert instruction; feature-flag-design scope change\]/canary-deployment widens to 100% and terminates./' "$1"
  sed -i 's/^- \[ \]/- [x]/' "$1"
}
set_decision() {
  sed -i -E "s/^## Decision: .*/## Decision: $2/" "$1"
}

cp "$FRESH" full.md
fill_two_party full.md
set_decision full.md "FULL SIGN-OFF"
if "$VALIDATE" full.md >/dev/null 2>&1; then
  _pass "validate-signoff: a filled two-party full sign-off passes"
else
  _fail "validate-signoff: a filled two-party full sign-off passes" "$("$VALIDATE" full.md | grep FAIL)"
fi

# A malformed Decision line must fail that specific check.
cp full.md bad-decision.md
set_decision bad-decision.md "MOSTLY GOOD TO GO"
if run_validate bad-decision.md | grep -q "FAIL: Decision line names exactly one valid outcome"; then
  _pass "validate-signoff: catches a Decision line that isn't one of the three valid outcomes"
else
  _fail "validate-signoff: catches a Decision line that isn't one of the three valid outcomes" "expected a FAIL line for the Decision check"
fi

# Defect rule: a sign-off with the Critical line unchecked fails; a NO-GO with it unchecked does not.
cp full.md critical.md
sed -i 's/^- \[x\] Zero open Critical/- [ ] Zero open Critical/' critical.md
if run_validate critical.md | grep -q "FAIL: no full or conditional sign-off while open Critical"; then
  _pass "validate-signoff: a full sign-off with open Critical defects fails"
else
  _fail "validate-signoff: a full sign-off with open Critical defects fails" "expected the Critical check to fail"
fi
set_decision critical.md "NO-GO"
if run_validate critical.md | grep -q "PASS: no full or conditional sign-off while open Critical"; then
  _pass "validate-signoff: a no-go with open Critical defects passes the Critical check"
else
  _fail "validate-signoff: a no-go with open Critical defects passes the Critical check" "expected PASS on a no-go"
fi

# Solo-operator exception: no customer rep, but a filled Exception passes.
cp "$FRESH" solo.md
fill_two_party solo.md
sed -i '/(customer representative)/d' solo.md
set_decision solo.md "FULL SIGN-OFF"
if run_validate solo.md | grep -q "FAIL: customer representative named, or a filled solo-operator Exception"; then
  _pass "validate-signoff: no representative and an unfilled Exception fails"
else
  _fail "validate-signoff: no representative and an unfilled Exception fails" "expected the authority check to fail"
fi
python3 - solo.md <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
block = """## Exception: solo operator
- Executor and accepting authority: Ines Duarte
- Independence level (ISTQB): none
- Why no second party: no customer can take part this release
- Evidence: per-scenario screenshots, kept in evidence/r1/
- Borrowed session: none available, because the club is closed

"""
s = re.sub(r"## Exception: solo operator\n.*?(?=## Decision)", block, s, flags=re.S)
open(p, "w").write(s)
PY
if "$VALIDATE" solo.md >/dev/null 2>&1; then
  _pass "validate-signoff: a filled solo-operator Exception passes without a representative"
else
  _fail "validate-signoff: a filled solo-operator Exception passes without a representative" "$("$VALIDATE" solo.md | grep FAIL)"
fi
sed -i 's/Independence level (ISTQB): none/Independence level (ISTQB): within team/' solo.md
if run_validate solo.md | grep -q "FAIL: customer representative named, or a filled solo-operator Exception"; then
  _pass "validate-signoff: an Exception that does not declare independence 'none' fails"
else
  _fail "validate-signoff: an Exception that does not declare independence 'none' fails" "expected the authority check to fail"
fi

# Conditional: conditions need owner + target date; a High needs workaround + re-test.
cp full.md cond.md
set_decision cond.md "CONDITIONAL SIGN-OFF"
sed -i 's/^- \[Issue ID, severity\].*/- FB-7 (High) — workaround: use the Replies tab — owner: backend-engineer — target date: 2026-09-01 — re-test: UAT-4b/' cond.md
if "$VALIDATE" cond.md >/dev/null 2>&1; then
  _pass "validate-signoff: a complete High condition passes"
else
  _fail "validate-signoff: a complete High condition passes" "$("$VALIDATE" cond.md | grep FAIL)"
fi
sed -i 's/ — re-test: UAT-4b//' cond.md
if run_validate cond.md | grep -q "FAIL: every High condition names a workaround and a re-test"; then
  _pass "validate-signoff: a High condition with no re-test fails"
else
  _fail "validate-signoff: a High condition with no re-test fails" "expected the High check to fail"
fi
sed -i 's/ — target date: 2026-09-01//' cond.md
if run_validate cond.md | grep -q "FAIL: every condition names an owner and a target date"; then
  _pass "validate-signoff: a condition with no target date fails"
else
  _fail "validate-signoff: a condition with no target date fails" "expected the condition check to fail"
fi
cp full.md cond-empty.md
set_decision cond-empty.md "CONDITIONAL SIGN-OFF"
if run_validate cond-empty.md | grep -q "FAIL: every condition names an owner and a target date"; then
  _pass "validate-signoff: a conditional sign-off with only the placeholder condition fails"
else
  _fail "validate-signoff: a conditional sign-off with only the placeholder condition fails" "expected the condition check to fail"
fi

# Missing file argument -> exit 2, distinct from exit 1 validation failure
"$VALIDATE" /no/such/file.md >/dev/null 2>&1
ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 2 ]; then
  _pass "validate-signoff: a nonexistent file exits 2 (usage/file error, distinct from 1)"
else
  _fail "validate-signoff: a nonexistent file exits 2 (usage/file error, distinct from 1)" "got exit $ACTUAL_EXIT"
fi

smoke_test_summary
