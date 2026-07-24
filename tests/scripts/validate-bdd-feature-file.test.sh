#!/bin/bash
# Tests skills/bdd-feature-file/scripts/validate-bdd-feature-file.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/bdd-feature-file/scripts/validate-bdd-feature-file.sh"
SCAFFOLD="$REPO_ROOT/skills/bdd-feature-file/scripts/scaffold-bdd-feature-file.sh"

cd "$SCRATCH_DIR"

# A fresh scaffold passes all checks -- none of the three are placeholder-
# sensitive by design (they check structural/mechanical properties, not
# whether bracket placeholders have been filled in).
FRESH="$("$SCAFFOLD" "Classify a data asset")"
if "$VALIDATE" "$FRESH" >/dev/null 2>&1; then
  _pass "validate-bdd-feature-file: a fresh scaffold passes all checks"
else
  _fail "validate-bdd-feature-file: a fresh scaffold passes all checks" "expected exit 0 on the unmodified template output"
fi

# Removing a Golden Triangle tag fails exactly that check, not the others.
sed 's/# edge//' "$FRESH" > "$SCRATCH_DIR/broken_tag.feature"
OUTPUT1="$("$VALIDATE" "$SCRATCH_DIR/broken_tag.feature" 2>&1)"
if echo "$OUTPUT1" | grep -q "FAIL: Golden Triangle: '# edge' tag present" \
   && echo "$OUTPUT1" | grep -q "PASS: Golden Triangle: '# happy' tag present" \
   && echo "$OUTPUT1" | grep -q "PASS: Golden Triangle: '# negative' tag present"; then
  _pass "validate-bdd-feature-file: catches a missing Golden Triangle tag without false-failing the others present"
else
  _fail "validate-bdd-feature-file: catches a missing Golden Triangle tag without false-failing the others present" "expected FAIL only for the missing # edge tag"
fi

# Injecting an HTTP verb into step text fails exactly the imperative-leakage check.
sed 's/When \[the single action under test\]/When she sends a PATCH request/' "$FRESH" > "$SCRATCH_DIR/broken_http.feature"
OUTPUT2="$("$VALIDATE" "$SCRATCH_DIR/broken_http.feature" 2>&1)"
if echo "$OUTPUT2" | grep -q "FAIL: no imperative/HTTP-mechanics leakage in step text" \
   && echo "$OUTPUT2" | grep -q "PASS: no Scenario with more than one When step"; then
  _pass "validate-bdd-feature-file: catches imperative/HTTP-mechanics leakage in step text"
else
  _fail "validate-bdd-feature-file: catches imperative/HTTP-mechanics leakage in step text" "expected FAIL for the leakage check, PASS for the unrelated multi-When check"
fi

# Injecting a second When step into one Scenario fails exactly the
# multi-When check. Regression test for a real bug caught while building
# this script: gawk's \b means a literal backspace, not a word-boundary
# assertion, so the original check silently matched nothing regardless of
# input -- fixed to match "When" followed by whitespace instead.
awk '/Scenario: \[Happy path/{print; getline; print; print "    When she also does something else"; next}1' "$FRESH" > "$SCRATCH_DIR/broken_multiwhen.feature"
OUTPUT3="$("$VALIDATE" "$SCRATCH_DIR/broken_multiwhen.feature" 2>&1)"
if echo "$OUTPUT3" | grep -q "FAIL: no Scenario with more than one When step" \
   && echo "$OUTPUT3" | grep -q "PASS: no imperative/HTTP-mechanics leakage in step text"; then
  _pass "validate-bdd-feature-file: catches a Scenario with more than one When step"
else
  _fail "validate-bdd-feature-file: catches a Scenario with more than one When step" "expected FAIL for the multi-When check -- if this regresses, check for the gawk \\b-means-backspace bug returning"
fi

# Missing file argument -> exit 2, distinct from exit 1 validation failure.
"$VALIDATE" /no/such/file.feature >/dev/null 2>&1
ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 2 ]; then
  _pass "validate-bdd-feature-file: a nonexistent file exits 2 (usage/file error, distinct from 1)"
else
  _fail "validate-bdd-feature-file: a nonexistent file exits 2 (usage/file error, distinct from 1)" "got exit $ACTUAL_EXIT"
fi

smoke_test_summary
