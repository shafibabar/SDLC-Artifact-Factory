#!/bin/bash
# Tests skills/beta-program-design/scripts/validate-beta-program-design.sh — a
# skill-owned script exercised directly with a file-path CLI arg.
# Fixtures are built here from a fresh scaffold, never from the skill's
# examples, so the test does not pin the live skill's prose.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
smoke_test_scratch_init

VALIDATE="$REPO_ROOT/skills/beta-program-design/scripts/validate-beta-program-design.sh"
SCAFFOLD="$REPO_ROOT/skills/beta-program-design/scripts/scaffold-beta-program-design.sh"

cd "$SCRATCH_DIR"

# Output only; the exit code is swallowed so pipefail does not mask grep.
run_validate() { "$VALIDATE" "$1" 2>&1 || true; }

# A fresh scaffold has eight unfilled checks (Stage, Participants, frameworks
# and telemetry, four graduation dimensions, Decision); the no-relaxation
# sentence and the Pivot check pass from the template as written.
FRESH="$("$SCAFFOLD" acme classification-pipeline)"
OUTPUT="$("$VALIDATE" "$FRESH" 2>&1)"
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 1 ] && echo "$OUTPUT" | grep -q "8 check(s) failed"; then
  _pass "validate-beta-program-design: a fresh scaffold fails exactly the 8 unfilled checks"
else
  _fail "validate-beta-program-design: a fresh scaffold fails exactly the 8 unfilled checks" "exit $EXIT_CODE; $(echo "$OUTPUT" | grep FAIL)"
fi

if echo "$OUTPUT" | grep -q "PASS: Data Handling Statement says no control is relaxed"; then
  _pass "validate-beta-program-design: does not false-fail the no-relaxation sentence on a fresh scaffold"
else
  _fail "validate-beta-program-design: does not false-fail the no-relaxation sentence on a fresh scaffold" "expected PASS"
fi

# Fill a closed-beta record whose frameworks are not SOC 2.
fill() {
  sed -i \
    -e 's|^\[Closed alpha / Closed beta / Open beta / GA\]$|Closed beta|' \
    -e 's|^\[Names, companies, ICP-fit rationale, named contact\]$|Three screened design partners.|' \
    -e 's#^| \[name, company\] .*#| Ferris \& Lowe | y | y | y | Dana Ferris | merged-firm spreadsheet | y | in |#' \
    -e 's|^- Frameworks: .*|- Frameworks: UK GDPR; SRA confidentiality duties|' \
    -e 's|^- Telemetry: .*|- Telemetry: none beyond GA|' \
    -e 's|^- Quality: .*|- Quality: all Must UAT scenarios pass|' \
    -e 's|^- Traction: .*|- Traction: 80% of new matters checked per firm, weeks 4-6|' \
    -e 's|^- Behaviour and commitment: .*|- Behaviour and commitment: a recent check described; six-week commitment|' \
    -e 's|^- Repeatability and operations: .*|- Repeatability and operations: onboarded from the guide alone|' \
    -e 's|^Decision: .*|Decision: Pending|' \
    -e 's|^Suspect hypothesis: .*|Suspect hypothesis: none|' \
    "$1"
}

cp "$FRESH" filled.md
fill filled.md
if "$VALIDATE" filled.md >/dev/null 2>&1; then
  _pass "validate-beta-program-design: a filled record with non-SOC-2 frameworks passes"
else
  _fail "validate-beta-program-design: a filled record with non-SOC-2 frameworks passes" "$(run_validate filled.md | grep FAIL)"
fi

# Each check fails on its own trigger without false-failing the others.
expect_one() {
  local label="$1" file="$2" pattern="$3"
  local out; out="$(run_validate "$file")"
  if echo "$out" | grep -q "FAIL: $pattern" && echo "$out" | grep -q "1 check(s) failed"; then
    _pass "validate-beta-program-design: $label"
  else
    _fail "validate-beta-program-design: $label" "expected exactly one FAIL for '$pattern'; got: $(echo "$out" | grep FAIL)"
  fi
}

sed 's/^Closed beta$/Some Weird Stage/' filled.md > bad-stage.md
expect_one "catches an invalid Stage value" bad-stage.md "Stage is a real value"

sed 's/^Three screened design partners\.$/[Names, companies, ICP-fit rationale, named contact]/' filled.md > bad-participants.md
expect_one "catches the unfilled Participants placeholder" bad-participants.md "Participants section is filled in"

sed '/^No control is relaxed/d' filled.md > bad-relax.md
expect_one "catches a Data Handling Statement without the no-relaxation sentence" bad-relax.md "Data Handling Statement says no control is relaxed"

sed 's/^- Frameworks: .*/- Frameworks: [the product'"'"'s own]/' filled.md > bad-frameworks.md
expect_one "catches unfilled frameworks" bad-frameworks.md "Data Handling Statement names the product's own frameworks"

sed '/^- Traction:/d' filled.md > bad-traction.md
expect_one "catches a missing Traction dimension" bad-traction.md "Graduation Criteria: Traction dimension filled"

sed 's/^Decision: Pending$/Decision: Ship it/' filled.md > bad-decision.md
expect_one "catches an invalid Decision" bad-decision.md "Graduation Record decision"

sed 's/^Decision: Pending$/Decision: Pivot/' filled.md > pivot-none.md
expect_one "catches a Pivot with no suspect hypothesis" pivot-none.md "a Pivot names its suspect hypothesis"

sed -e 's/^Decision: Pending$/Decision: Pivot/' -e 's/^Suspect hypothesis: none$/Suspect hypothesis: segment — Customer Segments/' filled.md > pivot-ok.md
if "$VALIDATE" pivot-ok.md >/dev/null 2>&1; then
  _pass "validate-beta-program-design: a Pivot naming its suspect hypothesis passes"
else
  _fail "validate-beta-program-design: a Pivot naming its suspect hypothesis passes" "$(run_validate pivot-ok.md | grep FAIL)"
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
