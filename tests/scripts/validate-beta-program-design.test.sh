#!/bin/bash
# Tests skills/beta-program-design/scripts/validate-beta-program-design.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/beta-program-design/scripts/validate-beta-program-design.sh"
SCAFFOLD="$REPO_ROOT/skills/beta-program-design/scripts/scaffold-beta-program-design.sh"

cd "$SCRATCH_DIR"

FRESH="$("$SCAFFOLD" acme classification-pipeline)"

# A fresh scaffold fails exactly the two placeholder-sensitive checks (Stage,
# Participants) while the three purely-structural checks pass, since the
# unfilled bracket placeholders already mention SOC 2 CC6/CC7/A1 and both
# Graduation Criteria dimensions as instructional text.
OUTPUT0="$("$VALIDATE" "$FRESH" 2>&1)"
if echo "$OUTPUT0" | grep -q "FAIL: Stage is a real value" \
   && echo "$OUTPUT0" | grep -q "FAIL: Participants section is filled in" \
   && echo "$OUTPUT0" | grep -q "PASS: Data Handling Statement" \
   && echo "$OUTPUT0" | grep -q "PASS: Graduation Criteria: Quantitative" \
   && echo "$OUTPUT0" | grep -q "PASS: Graduation Criteria: Qualitative" \
   && echo "$OUTPUT0" | grep -q "2 check(s) failed"; then
  _pass "validate-beta-program-design: a fresh scaffold fails exactly the two placeholder-sensitive checks"
else
  _fail "validate-beta-program-design: a fresh scaffold fails exactly the two placeholder-sensitive checks" "expected exactly Stage + Participants to FAIL, the other three to PASS"
fi

# Filling in Stage and Participants makes it pass all checks.
sed -i \
  -e 's/\[Closed alpha \/ Closed beta \/ Open beta \/ GA\]/Closed beta/' \
  -e 's/\[Names, companies, ICP-fit rationale, named contact\]/Northwind Compliance Co. (Maya Chen)/' \
  "$FRESH"
if "$VALIDATE" "$FRESH" >/dev/null 2>&1; then
  _pass "validate-beta-program-design: filling in Stage and Participants passes all checks"
else
  _fail "validate-beta-program-design: filling in Stage and Participants passes all checks" "expected exit 0 once Stage and Participants are filled in"
fi

# Each of the four independently-breakable checks fails on its own trigger
# without false-failing the others.
sed 's/^Closed beta$/Some Weird Stage/' "$FRESH" > "$SCRATCH_DIR/broken_stage.md"
OUTPUT1="$("$VALIDATE" "$SCRATCH_DIR/broken_stage.md" 2>&1)"
if echo "$OUTPUT1" | grep -q "FAIL: Stage is a real value" && echo "$OUTPUT1" | grep -q "1 check(s) failed"; then
  _pass "validate-beta-program-design: catches an invalid Stage value"
else
  _fail "validate-beta-program-design: catches an invalid Stage value" "expected exactly 1 failed check naming Stage"
fi

sed '/^## Participants$/{n; s/.*//}' "$FRESH" > "$SCRATCH_DIR/broken_participants.md"
OUTPUT2="$("$VALIDATE" "$SCRATCH_DIR/broken_participants.md" 2>&1)"
if echo "$OUTPUT2" | grep -q "FAIL: Participants section is filled in" && echo "$OUTPUT2" | grep -q "1 check(s) failed"; then
  _pass "validate-beta-program-design: catches an empty Participants section"
else
  _fail "validate-beta-program-design: catches an empty Participants section" "expected exactly 1 failed check naming Participants"
fi

sed 's/\[Confirmation of unchanged SOC 2 CC6\/CC7\/A1 posture\]/[Same posture as always]/' "$FRESH" > "$SCRATCH_DIR/broken_soc2.md"
OUTPUT3="$("$VALIDATE" "$SCRATCH_DIR/broken_soc2.md" 2>&1)"
if echo "$OUTPUT3" | grep -q "FAIL: Data Handling Statement" && echo "$OUTPUT3" | grep -q "1 check(s) failed"; then
  _pass "validate-beta-program-design: catches a Data Handling Statement missing the SOC 2 control codes"
else
  _fail "validate-beta-program-design: catches a Data Handling Statement missing the SOC 2 control codes" "expected exactly 1 failed check naming Data Handling Statement"
fi

sed '/^- Qualitative:/d' "$FRESH" > "$SCRATCH_DIR/broken_qual.md"
OUTPUT4="$("$VALIDATE" "$SCRATCH_DIR/broken_qual.md" 2>&1)"
if echo "$OUTPUT4" | grep -q "FAIL: Graduation Criteria: Qualitative" \
   && echo "$OUTPUT4" | grep -q "PASS: Graduation Criteria: Quantitative" \
   && echo "$OUTPUT4" | grep -q "1 check(s) failed"; then
  _pass "validate-beta-program-design: catches a missing Qualitative Graduation Criteria bullet without false-failing Quantitative"
else
  _fail "validate-beta-program-design: catches a missing Qualitative Graduation Criteria bullet without false-failing Quantitative" "expected FAIL only for Qualitative"
fi

# Missing file argument -> exit 2, distinct from exit 1 validation failure.
"$VALIDATE" /no/such/file.md >/dev/null 2>&1
ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 2 ]; then
  _pass "validate-beta-program-design: a nonexistent file exits 2 (usage/file error, distinct from 1)"
else
  _fail "validate-beta-program-design: a nonexistent file exits 2 (usage/file error, distinct from 1)" "got exit $ACTUAL_EXIT"
fi

smoke_test_summary
