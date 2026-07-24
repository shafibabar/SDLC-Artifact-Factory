#!/bin/bash
# scripts/validate-criteria.sh — skill-owned script for skills/acceptance-criteria.
# Purpose: mechanically check an acceptance-criteria doc against the parts of
#          this skill's Quality Criteria table that are actually checkable by
#          a script -- testability red-flag words, Golden Triangle coverage,
#          and a traceable Derived-From link. Judgment calls (is this Then
#          actually observable, is the example real-feeling) stay with the
#          requirements-analyst's own review.
# Usage:   validate-criteria.sh <path-to-criteria.md>
# Output:  one PASS/FAIL line per check to stdout.
# Contract: plain CLI arg, not a hook's stdin-JSON contract -- advisory only.
#           Exit 0 if every check passes, 1 if any check fails, 2 on a
#           usage/file error.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: validate-criteria.sh <path-to-criteria.md>" >&2
  exit 2
fi

FILE="$1"
FAIL_COUNT=0

if [ ! -f "$FILE" ]; then
  echo "error: file not found: $FILE" >&2
  exit 2
fi

_check() {
  local label="$1" ok="$2"
  if [ "$ok" = "1" ]; then
    echo "PASS: $label"
  else
    echo "FAIL: $label"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

CONTENT="$(cat "$FILE")"

# Testability red-flag words -- per this skill's own Quality Criteria table,
# any criterion containing these words fails the testability check outright.
if printf '%s\n' "$CONTENT" | grep -qiE '\b(should|easily|properly|\bwell\b)\b'; then
  _check "no testability red-flag words (should/easily/properly/well)" 0
else
  _check "no testability red-flag words (should/easily/properly/well)" 1
fi

# Golden Triangle coverage: each of the three angles has its section heading
# present, and at least one gherkin block or Rule block actually follows it
# (not left as an empty section).
for section in "## Happy Path" "## Error / Negative Scenarios" "## Boundary / Edge Cases"; do
  if printf '%s\n' "$CONTENT" | grep -qF "$section"; then
    _check "Golden Triangle: '$section' present" 1
  else
    _check "Golden Triangle: '$section' present" 0
  fi
done

if printf '%s\n' "$CONTENT" | grep -qF '```gherkin'; then
  _check "at least one Gherkin criterion present" 1
else
  _check "at least one Gherkin criterion present" 0
fi

# Derived From: the section must exist and must not still contain the
# unfilled template placeholder ("EM-[ID]").
if printf '%s\n' "$CONTENT" | grep -qF '## Derived From'; then
  if printf '%s\n' "$CONTENT" | grep -A1 '## Derived From' | grep -qE 'EM-[A-Za-z0-9]+' && ! printf '%s\n' "$CONTENT" | grep -A1 '## Derived From' | grep -qF 'EM-[ID]'; then
    _check "Derived From links a real example map (not the unfilled placeholder)" 1
  else
    _check "Derived From links a real example map (not the unfilled placeholder)" 0
  fi
else
  _check "Derived From links a real example map (not the unfilled placeholder)" 0
fi

echo "---"
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "$FAIL_COUNT check(s) failed."
  exit 1
fi
